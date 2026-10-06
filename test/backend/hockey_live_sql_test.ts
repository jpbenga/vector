import { PGlite } from "npm:@electric-sql/pglite@0.5.8";
import assert from "node:assert/strict";
Deno.test("hockey SQL: public read only, atomic quotas, fenced publication, failure retains scores and no football changes", async () => {
  const db = new PGlite();
  try {
    await db.exec(
      `create role anon;create role authenticated;create role service_role;
  create schema cron;create function cron.schedule(text,text,text) returns bigint language sql as $$select 1::bigint$$;
  create table ops_configuration(singleton boolean,base_url text,sync_secret text);
  insert into ops_configuration values(true,'https://example.supabase.co','private-secret');
  create table match_live_states(fixture_id integer);insert into match_live_states values(123);`,
    );
    await db.exec(
      await Deno.readTextFile(
        "supabase/migrations/20261005180000_hockey_live_collection.sql",
      ),
    );
    const one = async (sql: string) =>
      (await db.query<{ v: any }>(sql)).rows[0]?.v;
    assert.equal(await one("select (hockey_live_claim()->>'token') v"), null);
    await db.exec("select hockey_live_set_enabled(true)");
    const token = await one("select hockey_live_claim()->>'token' v");
    assert.ok(token);
    assert.equal(await one("select hockey_live_claim()->>'token' v"), null);
    assert.equal(
      await one(`select hockey_live_reserve('${token}',true)->'allowed' v`),
      true,
    );
    assert.equal(
      await one(
        "select hockey_live_reserve('00000000-0000-0000-0000-000000000000',true)->'allowed' v",
      ),
      false,
    );
    const fixture = {
      id: "430525",
      competitionId: "35",
      competitionName: "KHL",
      season: "2026",
      calendarDate: "2026-10-05",
      startsAt: "2026-10-05T14:00:00Z",
      status: "finished",
      providerStatus: "FT",
      home: { id: "1487", name: "Magnitogorsk", logoUrl: null },
      away: { id: "831", name: "Vladivostok", logoUrl: null },
      scores: { final: { home: 2, away: 5 } },
    };
    const states = () =>
      JSON.stringify([{ fixture, capturedAt: new Date().toISOString() }]);
    await db.query("select hockey_live_publish($1,$2,1,false)", [
      token,
      states(),
    ]);
    assert.equal(
      await one(
        "select payload#>>'{scores,final,away}' v from sport_live_states",
      ),
      "5",
    );
    await db.exec("set role anon");
    assert.equal(await one("select count(*)::int v from sport_live_states"), 1);
    await assert.rejects(
      () => db.exec("select * from hockey_live_configuration"),
      /permission denied/,
    );
    await assert.rejects(
      () => db.exec("select hockey_live_claim()"),
      /permission denied/,
    );
    await assert.rejects(
      () => db.exec("delete from sport_live_states"),
      /permission denied/,
    );
    await db.exec("reset role");
    await assert.rejects(
      () =>
        db.query("select hockey_live_publish($1,$2,1,false)", [
          token,
          states(),
        ]),
      /revoked/,
    );
    await db.exec(
      "update hockey_live_configuration set last_started_at=now()-interval '60 seconds'",
    );
    const next = await one("select hockey_live_claim()->>'token' v");
    await db.query("select hockey_live_fail($1,$2,1)", [
      next,
      "provider error",
    ]);
    assert.equal(
      await one(
        "select payload#>>'{scores,final,away}' v from sport_live_states",
      ),
      "5",
    );
    await db.exec(
      "update hockey_live_configuration set last_started_at=now()-interval '60 seconds'",
    );
    const stopped = await one("select hockey_live_claim()->>'token' v");
    await db.exec("select hockey_live_set_enabled(false)");
    assert.equal(
      await one(`select hockey_live_reserve('${stopped}',true)->'allowed' v`),
      false,
    );
    await assert.rejects(
      () =>
        db.query("select hockey_live_publish($1,$2,1,false)", [
          stopped,
          states(),
        ]),
      /revoked/,
    );
    await db.exec(
      "delete from hockey_api_reservations;insert into hockey_api_reservations(live,reserved_at) select false,now() from generate_series(1,200)",
    );
    assert.equal(
      await one("select hockey_live_reserve(null,false)->'allowed' v"),
      false,
    );
    assert.equal(await one("select count(*)::int v from match_live_states"), 1);
  } finally {
    await db.close();
  }
});
