import { PGlite } from "npm:@electric-sql/pglite@0.5.8";
import assert from "node:assert/strict";
Deno.test("hockey prices join both public and Generator views without renewing facts or football", async () => {
  const db = new PGlite();
  try {
    await db.exec(
      `create role anon; create role authenticated; create role service_role;
      create function lector_generator_sources_filtered(date,text,text[],text[],text[],text[]) returns jsonb language sql as $$select '[{"sport":"football","id":"unchanged"}]'::jsonb$$;
      create function lector_generator_radar_sources(date,text,jsonb) returns jsonb language sql as $$select '[]'::jsonb$$;`,
    );
    await db.exec(
      await Deno.readTextFile(
        "supabase/migrations/20261009170000_shared_sport_publications.sql",
      ),
    );
    await db.exec(
      (await Deno.readTextFile(
        "supabase/migrations/20261009210000_hockey_market_quotes.sql",
      )).split("-- Hosted scheduler")[0],
    );
    const time = new Date(Date.now() - 60000).toISOString(),
      day = new Date(Date.now() + 86400000).toISOString().slice(0, 10);
    const f = {
      id: "100",
      competitionId: "35",
      competitionName: "KHL",
      season: "2026",
      startsAt: day + "T18:00:00Z",
      calendarDate: day,
      status: "scheduled",
      home: { id: "2", name: "Home" },
      away: { id: "3", name: "Away" },
      readings: [{ id: "winning_streak" }],
    };
    const payload = {
      schemaVersion: 1,
      sport: "hockey",
      provider: "api-hockey",
      collectionId: "source",
      capturedAt: time,
      windowStart: day,
      windowEnd: day,
      items: [f],
      competitions: [{ id: "35", season: "2026" }],
      readingRulesVersion: "native",
    };
    await db.query("select publish_sport_feed($1,$1)", [payload]);
    const token =
      (await db.query<{ v: { token: string } }>("select hockey_odds_claim() v"))
        .rows[0].v.token;
    assert.deepEqual(
      (await db.query<{ v: any }>("select hockey_odds_claim() v")).rows[0].v,
      {},
    );
    const q = {
      marketCode: "result_regulation",
      selectionCode: "home",
      scope: "regulation",
      bookmaker: "Book",
      bookmakerId: "1",
      decimalOdds: 2.2,
      capturedAt: time,
    };
    const r = {
      matchId: "100",
      competitionId: "35",
      season: "2026",
      homeId: "2",
      awayId: "3",
      collectedAt: time,
      quotes: [q],
    };
    await assert.rejects(
      db.query("select hockey_odds_publish($1,$2)", [token, [{
        ...r,
        homeId: "3",
      }]]),
    );
    await assert.rejects(
      db.query("select hockey_odds_publish($1,$2)", [token, [{
        ...r,
        quotes: [{ ...q, scope: "final" }],
      }]]),
    );
    await assert.rejects(
      db.query("select hockey_odds_publish($1,$2)", [token, [{
        ...r,
        quotes: [{ ...q, marketCode: null }],
      }]]),
    );
    await db.query("select hockey_odds_publish($1,$2)", [token, [r]]);
    const read = (await db.query<{ v: any }>(
      "select read_sport_feed('hockey',$1,'day') v",
      [day],
    )).rows[0].v;
    assert.equal(read.capturedAt, time);
    assert.deepEqual(read.items[0].quotes, [q]);
    const sources = (await db.query<{ v: any }>(
      "select lector_generator_shared_sources($1,'Europe/Paris',array['football','hockey']) v",
      [day],
    )).rows[0].v;
    assert.deepEqual(sources[0], { sport: "football", id: "unchanged" });
    assert.deepEqual(sources[1].payload.items[0].quotes, [q]);
    assert.deepEqual(
      (await db.query<{ payload: any }>(
        "select payload from sport_feed_snapshots",
      )).rows[0].payload,
      payload,
    );
    await db.exec("set role anon");
    await db.query("select read_sport_feed('hockey',$1,'day')", [day]);
    await assert.rejects(db.query("select * from hockey_market_quotes"));
    await assert.rejects(db.query("select hockey_odds_claim()"));
    await db.exec("reset role");
    await db.query("select hockey_odds_finish($1,1,null)", [token]);
    await assert.rejects(
      db.query("select hockey_odds_publish($1,$2)", [token, [r]]),
    );
  } finally {
    await db.close();
  }
});
