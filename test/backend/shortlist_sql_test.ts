import { PGlite } from "npm:@electric-sql/pglite@0.5.8";
import assert from "node:assert/strict";
const a = "11111111-1111-4111-8111-111111111111",
  b = "22222222-2222-4222-8222-222222222222";
Deno.test("Shortlist SQL owns sessions, serializes mutations, preserves expiry, recovers and cleans without ticket deletion", async () => {
  const db = new PGlite();
  try {
    await db.exec(
      `create role anon;create role authenticated;create role service_role;
   create schema auth;create table auth.users(id uuid primary key);insert into auth.users values('${a}'),('${b}');
   create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
   create schema cron;create function cron.schedule(text,text,text) returns bigint language sql as $$select 1::bigint$$;
   create table match_feed_analysis_snapshots(id uuid primary key,captured_at timestamptz,window_start date,window_end date,payload jsonb);
   create table sport_feed_snapshots(id uuid primary key,sport text,captured_at timestamptz,window_start date,window_end date,overview jsonb);
   create table match_live_states(fixture_id integer,status text,captured_at timestamptz);
   create table sport_live_states(sport text,provider text,fixture_id text,payload jsonb,captured_at timestamptz);
   create table saved_ticket_proof(id int primary key);insert into saved_ticket_proof values(1);`,
    );
    await db.exec(
      await Deno.readTextFile(
        "supabase/migrations/20261011160000_lector_shortlist.sql",
      ),
    );
    await db.exec(
      await Deno.readTextFile(
        "supabase/migrations/20261011220000_lector_shortlist_display.sql",
      ),
    );
    const day = new Date(Date.now() + 86400000).toISOString().slice(0, 10),
      kickoff = day + "T18:00:00Z";
    await db.query(
      `insert into match_feed_analysis_snapshots values(gen_random_uuid(),now(),$1,$1,$2)`,
      [day, {
        computed: {
          fixtures: [{
            fixture_id: 1,
            readings: [
              {
                id: "positive_streak",
                label: "Dynamique positive",
                evidence: [{ large: "not copied" }],
              },
              { id: "head_to_head_dominance", label: "Retired" },
            ],
          }],
        },
        raw: {
          fixtures: [1, 2, 3].map((id) => ({
            fixture: { id, date: kickoff, status: { short: "NS" } },
            teams: {
              home: { name: "Home " + id },
              away: { name: "Away " + id },
            },
            league: { name: "Football", flag: "https://example.test/fr.svg" },
          })),
        },
      }],
    );
    await db.query(
      `insert into sport_feed_snapshots values(gen_random_uuid(),'hockey',now(),$1,$1,$2)`,
      [day, {
        provider: "api-hockey",
        items: [{
          id: 1,
          startsAt: kickoff,
          status: "scheduled",
          home: { name: "Hockey home" },
          away: { name: "Hockey away" },
          competitionName: "Hockey league",
          readings: [
            { id: "positive_streak", status: "detected" },
            { id: "negative_streak", status: "notDetected" },
          ],
        }],
      }],
    );
    const display = (await db.query<{ f: any }>(
      `select lector_shortlist_fixture('football','1',$1) f`,
      [day],
    )).rows[0].f;
    assert.equal(display.countryFlag, "https://example.test/fr.svg");
    assert.deepEqual(display.readings.map((r: any) => r.id), [
      "positive_streak",
    ]);
    assert.equal(display.readings[0].evidence, undefined);
    const hockeyDisplay = (await db.query<{ f: any }>(
      `select lector_shortlist_fixture('hockey','1',$1) f`,
      [day],
    )).rows[0].f;
    assert.deepEqual(hockeyDisplay.readings.map((r: any) => r.id), [
      "positive_streak",
    ]);
    await db.exec(`set role authenticated;set request.jwt.claim.sub='${a}'`);
    const action = async (
      name: string,
      session: string | null = null,
      sport: string | null = null,
      id: string | null = null,
      until: string | null = null,
      revision: number | null = null,
    ) => {
      const result = await db.query<{ state: any }>(
        `select lector_shortlist($1,$2,$3,$4,$5,$6,'Europe/Paris',$7) state`,
        [name, session, sport, id, id ? day : null, until, revision],
      );
      return result.rows[0].state;
    };
    const first = await action("add", null, "football", "1");
    const session = first.sessions[0];
    assert.equal(session.items.length, 1);
    const duplicate = await action("add", session.id, "football", "1");
    assert.equal(duplicate.sessions[0].revision, session.revision);
    assert.equal(duplicate.sessions[0].expiresAt, session.expiresAt);
    const hockey = await action("add", session.id, "hockey", "1");
    assert.equal(hockey.sessions[0].items.length, 2);
    assert.notEqual(
      hockey.sessions[0].items[0].key,
      hockey.sessions[0].items[1].key,
    );
    const read = await action("read");
    assert.equal(read.sessions[0].revision, hockey.sessions[0].revision);
    assert.equal(read.sessions[0].expiresAt, hockey.sessions[0].expiresAt);
    const until = new Date(Date.now() + 6 * 86400000).toISOString();
    const extended = await action("extend", session.id, null, null, until);
    const removed = await action("remove", session.id, "hockey", "1");
    assert.equal(removed.sessions[0].expiresAt, extended.sessions[0].expiresAt);
    assert.equal(removed.sessions[0].status, "extended");
    const cleared = await action("clear", session.id);
    assert.equal(cleared.sessions[0].items.length, 0);
    const undone = await action(
      "undo_clear",
      session.id,
      null,
      null,
      null,
      cleared.sessions[0].revision,
    );
    assert.equal(undone.sessions[0].items.length, 1);
    const clearedAgain = await action("clear", session.id);
    await action("add", session.id, "football", "2");
    await assert.rejects(
      () =>
        action(
          "undo_clear",
          session.id,
          null,
          null,
          null,
          clearedAgain.sessions[0].revision,
        ),
      /autre appareil/,
    );
    await assert.rejects(
      () => db.query(`select lector_shortlist_read($1)`, [b]),
      /permission denied/,
    );
    await db.exec(`set request.jwt.claim.sub='${b}'`);
    assert.equal((await action("read")).sessions.length, 0);
    await assert.rejects(
      () => action("remove", session.id, "football", "2"),
      /indisponible/,
    );
    await db.exec(
      `reset role;update lector_shortlist_sessions set created_at=now()-interval '2 days',expires_at=now()-interval '1 hour' where id='${session.id}';set role authenticated;set request.jwt.claim.sub='${a}'`,
    );
    const expired = await action("read");
    assert.equal(expired.sessions[0].status, "expired");
    await assert.rejects(
      () => action("remove", session.id, "football", "2"),
      /expiré/,
    );
    const newState = await action("new");
    assert.equal(newState.sessions.length, 2);
    await assert.rejects(() => action("restore", session.id), /fusion/);
    const merged = await action("merge", session.id);
    assert.equal(merged.sessions.length, 1);
    assert.equal(merged.sessions[0].items.length, 1);
    await db.exec(
      `reset role;update lector_shortlist_sessions set created_at=now()-interval '4 days',expires_at=now()-interval '2 days';`,
    );
    const result = await db.query<{ removed: number }>(
      `select lector_shortlist_cleanup() removed`,
    );
    assert.equal(Number(result.rows[0].removed), 1);
    assert.equal(
      (await db.query(`select * from saved_ticket_proof`)).rows.length,
      1,
    );
    const acl = await db.query<{ allowed: boolean }>(
      `select has_function_privilege('anon','lector_shortlist(text,uuid,text,text,date,timestamptz,text,bigint)','execute') allowed`,
    );
    assert.equal(acl.rows[0].allowed, false);
  } finally {
    await db.close();
  }
});
