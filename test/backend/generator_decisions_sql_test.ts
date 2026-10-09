import { PGlite } from "npm:@electric-sql/pglite@0.5.8";
import assert from "node:assert/strict";
const user = "11111111-1111-4111-8111-111111111111",
  other = "22222222-2222-4222-8222-222222222222",
  conversation = "33333333-3333-4333-8333-333333333333",
  ticketId = "44444444-4444-4444-8444-444444444444";
const pick = {
  id: "football:123:1:Home:6:snapshot",
  matchId: "api-fixture-123",
  sport: "football",
  marketId: "matchResult",
  home: "A",
  away: "B",
  odds: 1.4,
  oddsAt: "2026-10-09T01:00:00Z",
  bookmaker: "Bookmaker",
  evidence: [{ text: "Original evidence" }],
};
async function setup() {
  const db = new PGlite();
  await db.exec(
    `create role anon;create role authenticated;create role service_role;create schema auth;create table auth.users(id uuid primary key);create function auth.uid() returns uuid language sql as $$select null::uuid$$;insert into auth.users values('${user}'),('${other}');create table match_result_snapshots(id uuid,fixture_id integer,status text,home_goals integer,away_goals integer,score jsonb,captured_at timestamptz,created_at timestamptz);`,
  );
  for (
    const file of [
      "20261008120000_lector_generator.sql",
      "20261008170000_lector_generator_conversation_controls.sql",
      "20261008210000_lector_generator_workshop.sql",
      "20261009120000_lector_generator_decisions.sql",
    ]
  ) await db.exec(await Deno.readTextFile(`supabase/migrations/${file}`));
  await db.query("select lector_generator_session($1,$2,true)", [
    user,
    conversation,
  ]);
  const ticket = {
    id: ticketId,
    number: 1,
    stake: 50,
    picks: [pick],
    context: { origin: "profile" },
    totalOdds: 1.4,
  };
  await db.query("select lector_generator_commit($1,$2,0,$3)", [
    user,
    conversation,
    {
      id: conversation,
      tickets: [ticket],
      pending: null,
      messages: [],
      context: { origin: "profile" },
    },
  ]);
  return db;
}
async function keep(
  db: PGlite,
  kind = "ticket",
  source = ticketId,
  action = "save",
  owner = user,
) {
  return (await db.query<{ v: any }>(
    "select lector_generator_keep($1,$2,$3,$4,$5) v",
    [owner, conversation, kind, source, action],
  )).rows[0].v;
}
Deno.test("durable choices preserve snapshots, distinct intentions, ownership, idempotence and survive session removal", async () => {
  const db = await setup();
  try {
    await assert.rejects(
      keep(db, "ticket", ticketId, "save", other),
      /Unauthorized/,
    );
    await assert.rejects(
      keep(db, "selection", "forged", "follow"),
      /Unknown selection/,
    );
    const feedback = await keep(db, "selection", pick.id, "relevant");
    const listed = (await db.query<{ v: any }>(
      "select lector_generator_decision_list($1,0) v",
      [user],
    )).rows[0].v;
    assert.equal(listed.counts.feedback, 1);
    assert.equal(listed.decisions[0].summaryOnly, true);
    assert.equal(listed.decisions[0].snapshot.picks[0].evidence, undefined);
    assert.equal(
      (await db.query<{ v: any }>(
        "select lector_generator_decision_list($1,0) v",
        [other],
      )).rows[0].v.decisions.length,
      0,
    );
    assert.equal(feedback.relevant, true);
    assert.equal(feedback.followed_at, null);
    assert.equal(feedback.played_at, null);
    const followed = await keep(db, "selection", pick.id, "follow");
    assert.equal(followed.id, feedback.id);
    assert.ok(followed.followed_at);
    assert.equal(followed.saved_at, null);
    assert.equal(followed.played_at, null);
    const ticket = await keep(db);
    const duplicate = await keep(db);
    assert.equal(ticket.id, duplicate.id);
    assert.equal(
      (await db.query<{ n: number }>(
        "select count(*)::int n from lector_generator_decision_events where action='save'",
      )).rows[0].n,
      1,
    );
    await db.exec(
      `update lector_generator_ticket_drafts set ticket=jsonb_set(ticket,'{picks,0,odds}','9.9')`,
    );
    assert.equal((await keep(db)).snapshot.picks[0].odds, 1.4);
    await assert.rejects(
      db.query("select lector_generator_decision_action($1,$2,'played')", [
        other,
        ticket.id,
      ]),
      /Unauthorized/,
    );
    await db.query("select lector_generator_decision_action($1,$2,'played')", [
      user,
      ticket.id,
    ]);
    assert.ok(
      (await db.query<{ played_at: any }>(
        "select played_at from lector_generator_decisions where id=$1",
        [ticket.id],
      )).rows[0].played_at,
    );
    await db.exec(
      `delete from lector_generator_conversations where id='${conversation}'`,
    );
    assert.equal(
      (await db.query<{ n: number }>(
        "select count(*)::int n from lector_generator_decisions",
      )).rows[0].n,
      2,
    );
    assert.equal(
      (await db.query<{ n: number }>(
        "select count(*)::int n from lector_generator_ticket_drafts",
      )).rows[0].n,
      0,
    );
    await db.query("select lector_generator_decision_action($1,$2,'delete')", [
      user,
      ticket.id,
    ]);
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
Deno.test("saved modifications are versioned and an analysis-only selection can be followed", async () => {
  const db = await setup();
  try {
    const initial = await keep(db);
    const version = "77777777-7777-4777-8777-777777777777";
    const candidate = {
      ...pick,
      id: "football:124:1:Away:6:snapshot",
      matchId: "api-fixture-124",
    };
    await db.query("select lector_generator_commit($1,$2,1,$3)", [
      user,
      conversation,
      {
        id: conversation,
        intent: { action: "replace", referenceTicketId: ticketId },
        tickets: [{ id: version, number: 2, picks: [candidate], stake: 50 }],
        messages: [{
          role: "assistant",
          analysis: {
            text: "Original analytical explanation",
            selections: [{
              candidate,
              reason: "Specific reason",
              vigilance: "Known contradiction",
            }],
          },
        }],
        context: { origin: "explorer" },
      },
    ]);
    const updated = await keep(db, "ticket", version, "save");
    assert.equal(updated.supersedes, initial.id);
    assert.equal(
      (await db.query<{ snapshot: any }>(
        "select snapshot from lector_generator_decisions where id=$1",
        [initial.id],
      )).rows[0].snapshot.picks[0].odds,
      1.4,
    );
    const selection = await keep(db, "selection", candidate.id, "follow");
    assert.equal(
      selection.snapshot.analysis.text,
      "Original analytical explanation",
    );
    assert.equal(selection.snapshot.context.origin, "explorer");
    assert.equal(
      (await db.query<{ n: number }>(
        "select count(*)::int n from lector_generator_proposal_audit",
      )).rows[0].n,
      2,
    );
  } finally {
    await db.close();
  }
});

Deno.test("24h sessions cap at seven days, cannot resume/commit after expiration; cleanup keeps receipt-only audit", async () => {
  const db = await setup();
  try {
    await db.exec(
      `update lector_generator_conversations set created_at=now()-interval '6 days 23 hours',updated_at=now() where id='${conversation}'`,
    );
    const seconds = (await db.query<{ seconds: number }>(
      "select extract(epoch from expires_at-now())::int seconds from lector_generator_conversations",
    )).rows[0].seconds;
    assert.ok(seconds <= 3600 && seconds > 3500);
    await db.exec(
      `update lector_generator_conversations set created_at=now()-interval '8 days' where id='${conversation}'`,
    );
    assert.equal(
      (await db.query<{ v: any }>(
        "select lector_generator_session($1,$2,false) v",
        [user, conversation],
      )).rows[0].v.expired,
      true,
    );
    await assert.rejects(keep(db), /expired/);
    await assert.rejects(
      db.query("select lector_generator_commit($1,$2,1,$3)", [
        user,
        conversation,
        { id: conversation },
      ]),
      /expired/,
    );
    await db.exec(
      `insert into lector_generator_turns(request_id,user_id,conversation_id,status,response,usage) values('${ticketId}','${user}','${conversation}','complete','{"secret":"message"}','{"ai":[{"inputTokens":20}],"summary":"private summary"}')`,
    );
    await db.exec("select lector_generator_cleanup()");
    const audit = (await db.query<{ usage: any }>(
      "select usage from lector_generator_session_audit",
    )).rows[0].usage;
    assert.equal(audit.ai[0].inputTokens, 20);
    assert.equal(audit.summary, undefined);
    assert.equal(
      (await db.query<{ n: number }>(
        "select count(*)::int n from lector_generator_conversations",
      )).rows[0].n,
      0,
    );
  } finally {
    await db.close();
  }
});
Deno.test("settlement uses regulation score, known market value and final official evidence, never reading verdicts", async () => {
  const db = await setup();
  try {
    const settle = async (p: any, r: any) =>
      (await db.query<{ v: any }>(
        "select lector_generator_settle_pick($1,$2) v",
        [p, r],
      )).rows[0].v;
    assert.equal(
      (await settle(pick, { status: "2H", home_goals: 5, away_goals: 0 }))
        .status,
      "pending",
    );
    assert.equal(
      (await settle(pick, { status: "FT", home_goals: 0, away_goals: 1 }))
        .status,
      "lost",
    );
    assert.equal(
      (await settle(pick, {
        status: "AET",
        home_goals: 3,
        away_goals: 1,
        score: { fulltime: { home: 1, away: 1 } },
      })).status,
      "lost",
    );
    assert.equal(
      (await settle(pick, { status: "PEN", home_goals: 3, away_goals: 1 }))
        .status,
      "unverifiable",
    );
    for (
      const [market, value, home, away, expected] of [
        ["matchResult", "Away", 0, 1, "won"],
        ["doubleChance", "Home/Draw", 1, 1, "won"],
        ["doubleChance", "Draw/Away", 2, 0, "lost"],
        ["goalsTotal", "Over 2.5", 2, 1, "won"],
        ["goalsTotal", "Under 2.5", 1, 0, "won"],
        ["bothTeamsScore", "Yes", 1, 0, "lost"],
        ["bothTeamsScore", "Yes", 1, 1, "won"],
      ]
    ) {
      assert.equal(
        (await settle({
          ...pick,
          marketId: market,
          id: `football:123:1:${value}:6:snapshot`,
        }, { status: "FT", home_goals: home, away_goals: away })).status,
        expected,
      );
    }
    assert.equal(
      (await settle({ ...pick, marketId: "playerScorer" }, {
        status: "FT",
        home_goals: 2,
        away_goals: 0,
      })).status,
      "unverifiable",
    );
    assert.equal(
      (await settle(pick, { status: "CANC" })).status,
      "unverifiable",
    );
    const saved = await keep(db);
    await db.exec(
      "insert into match_result_snapshots values('55555555-5555-4555-8555-555555555555',123,'FT',0,1,'{}',now(),now());select lector_generator_verify();",
    );
    const result = (await db.query<{ result: any }>(
      "select result from lector_generator_decisions where id=$1",
      [saved.id],
    )).rows[0].result;
    assert.equal(result.status, "lost");
    assert.equal(result.picks[0].awayGoals, 1);
    await db.exec(
      "insert into match_result_snapshots values('66666666-6666-4666-8666-666666666666',123,'FT',2,1,'{}',now()+interval '1 second',now());select lector_generator_verify();",
    );
    assert.equal(
      (await db.query<{ result: any }>(
        "select result from lector_generator_decisions where id=$1",
        [saved.id],
      )).rows[0].result.status,
      "won",
    );
  } finally {
    await db.close();
  }
});
