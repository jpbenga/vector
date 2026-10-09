import { PGlite } from "npm:@electric-sql/pglite@0.5.8";
import assert from "node:assert/strict";
Deno.test("Radar RPC reads pinned publications, preserves evidence IDs and stays server-only when hockey is absent", async () => {
  const db = new PGlite();
  try {
    await db.exec(
      `create role anon; create role authenticated; create role service_role;
   create table match_feed_analysis_snapshots(id uuid,captured_at timestamptz,payload jsonb);
   create table sport_feed_publications(run_id uuid,sport text,captured_at timestamptz,payload jsonb);`,
    );
    await db.exec(
      await Deno.readTextFile(
        "supabase/migrations/20261009143000_lector_generator_radar_scope.sql",
      ),
    );
    const old = "11111111-1111-4111-8111-111111111111",
      newer = "22222222-2222-4222-8222-222222222222";
    const at = new Date(Date.now() - 60000).toISOString();
    const fixture = (id: number, team: number) => ({
      fixture: { id, date: "2026-10-10T18:00:00Z", status: { short: "NS" } },
      teams: { home: { id: team }, away: { id: team + 1 } },
    });
    const payload = {
      raw: {
        fixtures: [fixture(1, 2), fixture(2, 4)],
        odds: [{ fixture: { id: 1 }, update: at }, {
          fixture: { id: 2 },
          update: at,
        }],
        recent_league_matches: [{
          team: { id: 2 },
          matches: [{ fixture: { id: 10, date: at }, result: "W" }],
        }],
        player_form_radar: [{
          player: { id: 7 },
          team: { id: 2 },
          activity: [{ fixture_id: 10, played_at: at, goals: 2, assists: 0 }],
        }],
      },
      computed: {
        fixtures: [{ fixture_id: 1, readings: [{ id: "positive_streak" }] }, {
          fixture_id: 2,
          readings: [],
        }],
      },
    };
    await db.query(
      "insert into match_feed_analysis_snapshots values($1,$2,$3),($4,now(),$5)",
      [old, at, payload, newer, { raw: { fixtures: [fixture(1, 2)] } }],
    );
    const read = async (radar: unknown) =>
      (await db.query<{ v: any }>(
        "select public.lector_generator_radar_sources($1,$2,$3) v",
        ["2026-10-10", "Europe/Paris", radar],
      )).rows[0].v;
    const scope = {
      football: { sourceIds: [old], teams: [{ teamId: "2" }], players: [] },
    };
    const result = await read(scope);
    assert.equal(result.length, 1);
    assert.equal(result[0].id, old);
    assert.deepEqual(
      result[0].payload.raw.fixtures.map((f: any) => f.fixture.id),
      [1],
    );
    assert.equal(result[0].payload.raw.odds.length, 1);
    assert.equal(
      result[0].payload.raw.recent_league_matches[0].matches[0].fixture.id,
      10,
    );
    assert.equal(
      result[0].payload.raw.player_form_radar[0].activity[0].fixture_id,
      10,
    );
    assert.equal(result[0].payload.computed.fixtures.length, 1);
    assert.deepEqual(
      await read({
        football: { sourceIds: [], teams: [{ teamId: "2" }], players: [] },
      }),
      [],
    );
    const acl =
      (await db.query<{ anon: boolean; member: boolean; server: boolean }>(
        `select
   has_function_privilege('anon','lector_generator_radar_sources(date,text,jsonb)','execute') anon,
   has_function_privilege('authenticated','lector_generator_radar_sources(date,text,jsonb)','execute') member,
   has_function_privilege('service_role','lector_generator_radar_sources(date,text,jsonb)','execute') server`,
      )).rows[0];
    assert.deepEqual(acl, { anon: false, member: false, server: true });
    const hockey = {
      sport: "hockey",
      capturedAt: at,
      items: [{
        id: "100",
        competitionId: "35",
        status: "scheduled",
        startsAt: "2026-10-10T18:00:00Z",
        home: { id: "2" },
        away: { id: "3" },
      }],
      competitions: [{
        id: "35",
        formPhaseVerified: true,
        tables: [{
          rows: [{
            team: { id: "2" },
            formHistory: [{ id: "10", startsAt: at, outcome: "win" }],
          }],
        }],
      }],
      playerRadar: { profiles: [] },
    };
    await db.query("insert into sport_feed_publications values($1,$2,$3,$4)", [
      old,
      "hockey",
      at,
      hockey,
    ]);
    const h = {
      hockey: { capturedAt: at, teams: [{ teamId: "2" }], players: [] },
    };
    const hockeyResult = await read(h);
    assert.equal(
      hockeyResult[0].payload.competitions[0].tables[0].rows[0].formHistory[0]
        .id,
      "10",
    );
    assert.deepEqual(
      await read({
        hockey: { ...h.hockey, capturedAt: "2020-01-01T00:00:00Z" },
      }),
      [],
    );
    await db.exec("drop table sport_feed_publications");
    assert.deepEqual(await read(h), []);
    assert.equal((await read({ ...scope, ...h }))[0].id, old);
  } finally {
    await db.close();
  }
});
