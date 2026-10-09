import { PGlite } from "npm:@electric-sql/pglite@0.5.8";
import assert from "node:assert/strict";
Deno.test("Shared sport publications are immutable, isolated, pinned and preserve reading/history facts", async () => {
  const db = new PGlite();
  try {
    await db.exec(
      `create role anon; create role authenticated; create role service_role;
      create function lector_generator_sources_filtered(date,text,text[],text[],text[],text[]) returns jsonb language sql as $$select '[{"sport":"football","id":"unchanged"}]'::jsonb$$;
      create function lector_generator_radar_sources(date,text,jsonb) returns jsonb language sql as $$select case when $3 ? 'football' then '[{"sport":"football","id":"pinned-football"}]'::jsonb else '[]'::jsonb end$$;`,
    );
    await db.exec(
      await Deno.readTextFile(
        "supabase/migrations/20261009170000_shared_sport_publications.sql",
      ),
    );
    const at = new Date(Date.now() - 3600000).toISOString(),
      later = new Date(Date.now() - 60000).toISOString();
    const fixture = (id: string, home: string) => ({
      id,
      competitionId: "35",
      competitionName: "KHL",
      season: "2026",
      status: "scheduled",
      startsAt: "2026-10-10T18:00:00Z",
      calendarDate: "2026-10-10",
      home: { id: home, name: "Home" },
      away: { id: "3", name: "Away" },
      readings: [{
        id: "winning_streak",
        subject_team_id: home,
        explanation: "Three wins",
        sample_size: 3,
      }],
    });
    const payload = {
      schemaVersion: 1,
      sport: "hockey",
      provider: "api-hockey",
      collectionId: "collection",
      capturedAt: at,
      windowStart: "2026-10-03",
      windowEnd: "2026-10-23",
      items: [fixture("100", "2"), fixture("101", "4")],
      competitions: [{
        id: "35",
        season: "2026",
        formPhaseVerified: true,
        tables: [{
          rows: [{
            team: { id: "2" },
            formHistory: [{ id: "9", outcome: "win", startsAt: at }],
          }],
        }],
      }],
      playerRadar: { profiles: [], coverage: [] },
      readingRulesVersion: "native",
    };
    const publish = async (v: any) =>
      (await db.query<{ v: any }>("select publish_sport_feed($1,$2) v", [v, v]))
        .rows[0].v;
    const original = await publish(payload);
    assert.deepEqual(await publish(payload), original);
    await assert.rejects(publish({ ...payload, items: [] }));
    await assert.rejects(publish({ ...payload, sport: "football" }));
    await assert.rejects(
      publish({
        ...payload,
        capturedAt: new Date(Date.now() + 600000).toISOString(),
      }),
    );
    await publish({
      ...payload,
      capturedAt: later,
      items: [fixture("100", "4")],
    });
    const read = async (
      section: string,
      captured: string | null,
      sport = "hockey",
    ) =>
      (await db.query<{ v: any }>(
        "select read_sport_feed($1,'2026-10-10',$2,'100',$3) v",
        [sport, section, captured],
      )).rows[0].v;
    assert.equal((await read("day", null)).capturedAt, later);
    assert.equal((await read("match", at)).items[0].home.id, "2");
    assert.equal(await read("day", null, "basketball"), null);
    const scope = {
      hockey: { capturedAt: at, teams: [{ teamId: "2" }], players: [] },
    };
    const radar = (await db.query<{ v: any }>(
      "select lector_generator_shared_radar_sources('2026-10-10','Europe/Paris',$1) v",
      [scope],
    )).rows[0].v;
    assert.equal(radar.length, 1);
    assert.equal(radar[0].id, original.id);
    assert.deepEqual(radar[0].payload.items.map((v: any) => v.id), ["100"]);
    assert.equal(radar[0].payload.items[0].readings[0].sample_size, 3);
    assert.equal(
      radar[0].payload.competitions[0].tables[0].rows[0].formHistory[0].id,
      "9",
    );
    const missing = (await db.query<{ v: any }>(
      "select lector_generator_shared_radar_sources('2026-10-10','Europe/Paris',$1) v",
      [{ hockey: { ...scope.hockey, capturedAt: "2020-01-01" } }],
    )).rows[0].v;
    assert.deepEqual(missing, []);
    const profile = async (competitions: any, readings: any) =>
      (await db.query<{ v: any }>(
        "select lector_generator_shared_sources('2026-10-10','Europe/Paris',array['hockey'],$1,$2,null) v",
        [competitions, readings],
      )).rows[0].v;
    assert.equal(
      (await profile(["hockey:api-hockey:competition:35"], ["winning_streak"]))[
        0
      ].payload.items.length,
      1,
    );
    assert.equal(
      (await profile(["hockey:api-hockey:competition:57"], ["winning_streak"]))[
        0
      ].payload.items.length,
      0,
    );
    assert.equal(
      (await profile(null, ["strong_home_team"]))[0].payload.items.length,
      0,
    );
    const football = (await db.query<{ v: any }>(
      "select lector_generator_shared_sources('2026-10-10','Europe/Paris',array['football'],null,null,null) v",
    )).rows[0].v;
    assert.deepEqual(football, [{ sport: "football", id: "unchanged" }]);
    const a = (await db.query<{ v: any }>(`select jsonb_build_object(
      'write',has_function_privilege('anon','publish_sport_feed(jsonb,jsonb)','execute'),
      'read',has_function_privilege('anon','read_sport_feed(text,date,text,text,timestamptz)','execute'),
      'analysis',has_function_privilege('authenticated','lector_generator_shared_radar_sources(date,text,jsonb)','execute'),
      'raw',has_table_privilege('anon','sport_feed_snapshots','select'),
      'server',has_function_privilege('service_role','lector_generator_shared_radar_sources(date,text,jsonb)','execute')) v`))
      .rows[0].v;
    assert.deepEqual(a, {
      write: false,
      read: true,
      analysis: false,
      raw: false,
      server: true,
    });
  } finally {
    await db.close();
  }
});
