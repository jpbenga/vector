import { PGlite } from "npm:@electric-sql/pglite@0.5.8";
import assert from "node:assert/strict";
import { archiveWork } from "../../supabase/functions/_shared/generator/work_storage.ts";
import type {
  State,
  Ticket,
} from "../../supabase/functions/_shared/generator/contracts.ts";

const user = "11111111-1111-4111-8111-111111111111",
  other = "22222222-2222-4222-8222-222222222222",
  id = "33333333-3333-4333-8333-333333333333";
Deno.test("work storage survives large repeated analyses, tiny follow-up, old references, retry, privacy and expiry", async () => {
  const db = new PGlite();
  try {
    await db.exec(
      `create role anon;create role authenticated;create role service_role;create schema auth;create table auth.users(id uuid primary key);create function auth.uid() returns uuid language sql as $$select null::uuid$$;insert into auth.users values('${user}'),('${other}');create table match_result_snapshots(id uuid,fixture_id integer,status text,home_goals integer,away_goals integer,score jsonb,captured_at timestamptz,created_at timestamptz);`,
    );
    for (
      const file of [
        "20261008120000_lector_generator.sql",
        "20261008170000_lector_generator_conversation_controls.sql",
        "20261008210000_lector_generator_workshop.sql",
        "20261009120000_lector_generator_decisions.sql",
        "20261011200000_lector_generator_work_storage.sql",
      ]
    ) await db.exec(await Deno.readTextFile(`supabase/migrations/${file}`));
    await db.query("select lector_generator_session($1,$2,true)", [user, id]);
    const read = async (full = false) =>
      (await db.query<{ v: State }>(
        "select lector_generator_work_read($1,$2,$3) v",
        [user, id, full],
      )).rows[0].v;
    const commit = async (state: State, known = new Set<string>()) => {
      const work = archiveWork(
        state,
        known,
        new Set(state.messages.slice(0, -2).flatMap((m) => m.id ? [m.id] : [])),
      );
      return (await db.query<{ v: State }>(
        "select lector_generator_work_commit($1,$2,$3,$4,$5,$6,$7) v",
        [
          user,
          id,
          state.revision,
          work.state,
          work.tickets,
          work.messages,
          work.turns,
        ],
      )).rows[0].v;
    };
    let state = {
      id,
      revision: 0,
      context: {
        origin: "profile",
        scope: "discovery",
        timezone: "Europe/Paris",
        budget: 100,
        preferences: {},
      },
      intent: null,
      tickets: [],
      versions: [],
      pending: null,
      drafts: [],
      messages: [],
      saved: false,
      updatedAt: new Date().toISOString(),
    } as State;
    let first = "", firstAnalysis = "", firstPick = "";
    for (let n = 0; n < 12; n++) {
      const ticket = {
        id: crypto.randomUUID(),
        number: n + 1,
        stake: 50,
        context: state.context,
        picks: [{
          id: "pick-" + n,
          matchId: "api-fixture-" + n,
          sport: "football",
          home: "A",
          away: "B",
          selection: "A gagne",
          odds: 1.4,
          evidence: [{
            id: "fact-" + n,
            text: "Exact evidence ".repeat(26000),
          }],
        }],
      } as unknown as Ticket;
      if (!n) {
        first = ticket.id;
        firstPick = ticket.picks[0].id;
      }
      const known = new Set(state.drafts?.map((t) => t.id));
      state.drafts = [...state.drafts ?? [], ticket];
      const messageId = crypto.randomUUID();
      if (!n) firstAnalysis = messageId;
      state.messages.push({
        id: crypto.randomUUID(),
        role: "user",
        text: "Analyse",
        at: new Date().toISOString(),
      }, {
        id: messageId,
        role: "assistant",
        text: "Composition",
        ticketIds: [ticket.id],
        analysis: {
          text: "Analyse exacte",
          selections: [{
            candidate: ticket.picks[0],
            reason: "Série",
            vigilance: "Limite",
            references: [],
          }],
          context: {
            date: "2026-10-11",
            view: "all",
            sports: ["football"],
            matchCount: 500,
            candidateCount: 500,
          },
          comparedMatchIds: Array.from(
            { length: 500 },
            (_, i) => "football:" + i,
          ),
          limitations: [],
        },
      });
      const stored = await commit(state, known);
      assert.ok(
        JSON.stringify(stored).length < 15000,
        "working state independent of evidence size",
      );
      state = await read();
      assert.equal(state.messages.at(-1)?.analysis, undefined);
    }
    const before = state.revision;
    state.messages.push({ role: "user", text: "Merci" }, {
      role: "assistant",
      text: "Avec plaisir",
    });
    await commit(state, new Set(state.drafts!.map((t) => t.id)));
    assert.equal((await read()).revision, before + 1);
    const page = (await db.query<{ v: any }>(
      "select lector_generator_work_history($1,$2,20,20) v",
      [user, id],
    )).rows[0].v;
    assert.equal(page.messages[1].id, firstAnalysis);
    assert.equal(page.messages[1].analysis.context.matchCount, 500);
    const original = (await db.query<{ ticket: any }>(
      "select ticket from lector_generator_ticket_drafts where id=$1",
      [first],
    )).rows[0].ticket;
    assert.equal(
      original.picks[0].evidence[0].text,
      "Exact evidence ".repeat(26000),
    );
    const decision = (await db.query<{ v: any }>(
      "select lector_generator_keep($1,$2,'selection',$3,'follow') v",
      [user, id, firstPick],
    )).rows[0].v;
    assert.equal(decision.snapshot.analysis.text, "Analyse exacte");
    assert.equal(
      decision.snapshot.picks[0].evidence[0].text,
      original.picks[0].evidence[0].text,
    );
    await assert.rejects(
      db.query("select lector_generator_work_read($1,$2)", [other, id]),
      /Unauthorized/,
    );
    await assert.rejects(
      db.query("select lector_generator_work_history($1,$2)", [other, id]),
      /Unauthorized/,
    );
    const work = archiveWork(await read());
    await assert.rejects(
      db.query("select lector_generator_work_commit($1,$2,0,$3,$4,$5,$6)", [
        user,
        id,
        work.state,
        work.tickets,
        work.messages,
        work.turns,
      ]),
      /Conversation changed/,
    );
    assert.equal(
      (await db.query<{ n: number }>(
        "select count(*)::int n from lector_generator_messages",
      )).rows[0].n,
      26,
    );
    for (const role of ["anon", "authenticated"]) {
      const acl = (await db.query<{ v: boolean }>(
        "select has_function_privilege($1,'lector_generator_work_read(uuid,uuid,boolean,jsonb)','execute') v",
        [role],
      )).rows[0].v;
      assert.equal(acl, false);
    }
    await db.exec(
      `alter table lector_generator_conversations disable trigger generator_session_guard;update lector_generator_conversations set expires_at=now()-interval '1 minute' where id='${id}';alter table lector_generator_conversations enable trigger generator_session_guard;`,
    );
    await assert.rejects(read(), /Session expired/);
    await db.query("select lector_generator_cleanup()");
    assert.equal(
      (await db.query<{ n: number }>(
        "select count(*)::int n from lector_generator_messages",
      )).rows[0].n,
      0,
    );
    assert.equal(
      (await db.query<{ n: number }>(
        "select count(*)::int n from lector_generator_decisions",
      )).rows[0].n,
      1,
    );
  } finally {
    await db.close();
  }
});
