import { PGlite } from "npm:@electric-sql/pglite@0.5.8";
import assert from "node:assert/strict";
import {
  buildCatalog,
  type Source,
} from "../../supabase/functions/_shared/generator/catalog.ts";
import { ConversationReader } from "../../supabase/functions/_shared/generator/conversation_tools.ts";
import {
  type Context,
  obj,
  rows,
} from "../../supabase/functions/_shared/generator/contracts.ts";
import {
  type DaySourcePort,
  loadDaySources,
} from "../../supabase/functions/_shared/generator/day_sources.ts";

const day = "2026-10-10", timezone = "Europe/Paris";
const footballId = "11111111-1111-4111-8111-111111111111";
const hockeyId = "22222222-2222-4222-8222-222222222222";
const newerId = "33333333-3333-4333-8333-333333333333";
const context: Context = {
  origin: "profile",
  scope: "discovery",
  view: "all",
  timezone,
  budget: 50,
  preferences: {
    football: {
      competitions: ["61"],
      readings: ["strong_home_team"],
      scenarios: [],
      markets: ["matchResult"],
    },
    hockey: {
      competitions: ["hockey:api-hockey:competition:35"],
      readings: ["winning_streak"],
      scenarios: [],
      markets: ["matchResult"],
    },
  },
};
const timed = (at: string, i: number) =>
  i % 2 ? `${day}T17:00:00Z` : `${day}T23:30:00Z`;

Deno.test("day source SQL reads a complete large multisport day, keeps scope and versions, and projects only relevant facts", async () => {
  const db = new PGlite();
  try {
    await db.exec(
      `create role anon; create role authenticated; create role service_role;
      create table match_feed_analysis_snapshots(id uuid primary key,scope_key text,as_of timestamptz,captured_at timestamptz,window_start date,window_end date,payload jsonb);
      create table sport_feed_snapshots(id uuid primary key,sport text,captured_at timestamptz,window_start date,window_end date,overview jsonb);
      create function with_hockey_market_quotes(jsonb) returns jsonb language sql stable as $$select $1$$;`,
    );
    await db.exec(
      await Deno.readTextFile(
        "supabase/migrations/20261010090000_lector_generator_day_sources.sql",
      ),
    );
    const at = new Date(Date.now() - 120000).toISOString();
    const footballFixtures = Array.from({ length: 1000 }, (_, i) => ({
      fixture: { id: i + 1, date: timed(at, i + 1), status: { short: "NS" } },
      league: { id: i % 4 < 2 ? 61 : 62, name: "League" },
      teams: {
        home: { id: i * 2 + 1, name: `Home ${i}` },
        away: { id: i * 2 + 2, name: `Away ${i}` },
      },
    }));
    const football: Source = {
      id: footballId,
      sport: "football",
      capturedAt: at,
      payload: {
        raw: {
          fixtures: footballFixtures,
          unrelated_provider_response: "irrelevant".repeat(250000),
          odds: footballFixtures.map((f) => ({
            fixture: { id: f.fixture.id },
            update: at,
            bookmakers: [{
              id: 1,
              name: "Bookmaker",
              bets: [{ id: 1, values: [{ value: "Home", odd: "1.5" }] }, {
                id: 999,
                values: [{ value: "Unused", odd: "2" }],
              }],
            }],
          })),
          player_form_radar: [{
            player: { id: 1, name: "Relevant" },
            team: { id: 1 },
            activity: [{
              fixture_id: 5001,
              played_at: at,
              goals: 2,
              assists: 0,
              minutes: 90,
            }],
          }, {
            player: { id: 2 },
            team: { id: 99999 },
            activity: [],
            unwanted: "foreign".repeat(250000),
          }],
          recent_league_matches: [{
            team: { id: 1 },
            league: { id: 61 },
            matches: [{ fixture: { id: 5001, date: at }, result: "W" }],
          }],
        },
        computed: {
          fixtures: footballFixtures.map((f) => ({
            fixture_id: f.fixture.id,
            readings: [{
              id: "strong_home_team",
              side: "home",
              subject_team_id: f.teams.home.id,
              sample_size: 5,
              evidence: [],
            }],
            scenarios: [],
          })),
        },
      },
    };
    const hockeyFixtures = Array.from({ length: 100 }, (_, i) => ({
      id: String(i + 1),
      startsAt: timed(at, i + 1),
      status: "scheduled",
      competitionId: i % 4 < 2 ? "35" : "57",
      competitionName: "Hockey league",
      season: "2026",
      home: { id: String(i * 2 + 1), name: `Hockey home ${i}` },
      away: { id: String(i * 2 + 2), name: `Hockey away ${i}` },
      readings: [{
        id: "winning_streak",
        sample_size: 5,
        side: "home",
        subject_team_id: String(i * 2 + 1),
      }],
      recentForm: { home: [], away: [] },
      quotesCollectedAt: at,
      quotes: [],
    }));
    const hockey: Source = {
      id: hockeyId,
      sport: "hockey",
      capturedAt: at,
      payload: {
        sport: "hockey",
        provider: "api-hockey",
        capturedAt: at,
        readingRulesVersion: "native",
        items: hockeyFixtures,
        playerRadar: {
          profiles: [{
            id: "1",
            name: "Relevant",
            competitionId: "35",
            team: { id: "1" },
            activity: [],
          }, {
            id: "2",
            team: { id: "99999" },
            activity: [],
            unwanted: "foreign".repeat(250000),
          }],
        },
        competitions: ["35", "57"].map((id) => ({
          id,
          formPhaseVerified: true,
          tables: [{
            rows: Array.from(
              { length: 200 },
              (_, i) => ({
                team: { id: String(i + 1), name: "Team" },
                formHistory: [{
                  id: `history-${i}`,
                  startsAt: at,
                  outcome: "win",
                }],
              }),
            ),
          }],
        })),
      },
    };
    await db.query(
      "insert into match_feed_analysis_snapshots values($1,'football',now(),$2,$3,$4,$5)",
      [footballId, at, day, "2026-10-11", football.payload],
    );
    await db.query(
      "insert into sport_feed_snapshots values($1,'hockey',$2,$3,$4,$5)",
      [hockeyId, at, day, "2026-10-11", hockey.payload],
    );
    const port: DaySourcePort = {
      manifest: async (p) =>
        (await db.query<{ v: unknown }>(
          "select lector_generator_day_manifest($1,$2,$3,$4,$5,$6,$7) v",
          [
            p.p_date,
            p.p_timezone,
            p.p_sports,
            p.p_competitions,
            p.p_readings,
            p.p_scenarios,
            p.p_radar,
          ],
        )).rows[0].v,
      page: async (p) =>
        (await db.query<{ v: unknown }>(
          "select lector_generator_day_page($1,$2,$3,$4) v",
          [p.p_date, p.p_timezone, p.p_sources, p.p_matches],
        )).rows[0].v,
    };
    const started = performance.now();
    const loaded = await loadDaySources(
      context,
      day,
      ["football", "hockey"],
      port,
    );
    const elapsedMs = Math.round(performance.now() - started);
    assert.equal(loaded.manifest.total, 550);
    assert.deepEqual({ ...loaded.coverage, bytes: 0 }, {
      expected: 550,
      loaded: 550,
      pages: 11,
      bytes: 0,
      complete: true,
    });
    assert.equal(rows(obj(loaded.sources[0].payload.raw).fixtures).length, 500);
    assert.equal(rows(loaded.sources[1].payload.items).length, 50);
    assert.ok(JSON.stringify([football, hockey]).length > 5000000);
    assert.ok(loaded.coverage.bytes < 1000000);
    assert.ok(!JSON.stringify(loaded.sources).includes("foreign"));
    assert.ok(
      !JSON.stringify(loaded.sources).includes("unrelated_provider_response"),
    );
    assert.equal(
      rows(
        rows(obj(loaded.sources[0].payload.raw).player_form_radar)[0].activity,
      )[0].fixture_id,
      5001,
    );
    assert.equal(
      rows(obj(loaded.sources[1].payload.playerRadar).profiles).length,
      1,
    );
    assert.equal(
      rows(rows(rows(loaded.sources[1].payload.competitions)[0].tables)[0].rows)
        .length,
      100,
    );
    const now = new Date(at);
    const expectedCatalog = buildCatalog(
      [football, hockey],
      context,
      day,
      now,
      { includePastAndLive: true },
    );
    const actualCatalog = buildCatalog(loaded.sources, context, day, now, {
      includePastAndLive: true,
    });
    const comparable = (v: unknown) =>
      JSON.parse(
        JSON.stringify(v, (key, value) =>
          key === "asOf" ? new Date(value).toISOString() : value),
      );
    assert.deepEqual(
      actualCatalog.candidates.map((c) => c.id).sort(),
      expectedCatalog.candidates.map((c) => c.id).sort(),
    );
    for (const candidate of expectedCatalog.candidates) {
      assert.deepEqual(
        comparable(actualCatalog.candidates.find((c) => c.id === candidate.id)),
        comparable(candidate),
      );
    }
    assert.equal(
      actualCatalog.matches?.length,
      expectedCatalog.matches?.length,
    );
    for (const match of expectedCatalog.matches ?? []) {
      assert.deepEqual(
        comparable(
          actualCatalog.matches?.find((m) =>
            m.sport === match.sport && m.id === match.id
          ),
        ),
        comparable(match),
      );
    }
    // The calendar boundary includes 23:30 UTC in the following Paris day.
    const tomorrow = await loadDaySources(context, "2026-10-11", [
      "football",
      "hockey",
    ], port);
    assert.equal(tomorrow.coverage.loaded, 550);
    assert.ok(
      !tomorrow.manifest.matches.some((r) =>
        loaded.manifest.matches.some((m) => r.key === m.key)
      ),
    );
    const strict = {
      ...context,
      view: "profile" as const,
      scope: "strict" as const,
    };
    const profile = await loadDaySources(
      strict,
      day,
      ["football", "hockey"],
      port,
    );
    assert.equal(profile.coverage.loaded, 275);
    const radar = {
      ...context,
      view: "radar" as const,
      radarKind: "teams" as const,
      radar: {
        football: {
          version: 1,
          includeWomen: false,
          includeYouth: false,
          competitionId: null,
          sourceIds: [footballId],
          capturedAt: at,
          mode: "teams",
          category: "club",
          teams: [{ id: "1", teamId: "1", rank: 1, matchIds: ["5001"] }],
          players: [],
        },
        hockey: {
          version: 1,
          includeWomen: false,
          includeYouth: false,
          competitionId: null,
          sourceIds: [hockeyId],
          capturedAt: at,
          mode: "teams",
          category: "club",
          teams: [{ id: "1", teamId: "1", rank: 1, matchIds: ["history-0"] }],
          players: [],
        },
      },
    } as Context;
    assert.equal(
      (await loadDaySources(radar, day, ["football", "hockey"], port)).manifest
        .total,
      2,
    );
    assert.equal(
      (await loadDaySources({ ...radar, radar: {} }, day, [
        "football",
        "hockey",
      ], port)).manifest.total,
      0,
    );
    // An analysis head arriving between pages must not alter the pinned read.
    let replaced = false;
    const pinned = await loadDaySources(context, day, ["football", "hockey"], {
      ...port,
      page: async (p) => {
        if (!replaced) {
          replaced = true;
          await db.query(
            "insert into match_feed_analysis_snapshots values($1,'football',now()+interval '1 second',now()-interval '1 second',$2,$3,$4)",
            [newerId, day, "2026-10-11", {
              raw: { fixtures: footballFixtures.slice(0, 1) },
            }],
          );
        }
        return await port.page(p);
      },
    });
    assert.equal(pinned.coverage.loaded, 550);
    assert.ok(pinned.sources.every((s) => s.id !== newerId));
    assert.equal(
      (await loadDaySources(context, day, ["football", "hockey"], port))
        .manifest.total,
      51,
    );
    const missing = {
      ...pinned.manifest.matches[0],
      id: newerId,
      capturedAt: at,
    };
    await assert.rejects(
      port.page({
        p_date: day,
        p_timezone: timezone,
        p_sources: [{ id: newerId, sport: "football", capturedAt: at }],
        p_matches: [missing],
      }),
      /Pinned publication/,
    );
    const acl = (await db.query<{ v: unknown }>(`select jsonb_build_object(
      'anon_manifest',has_function_privilege('anon','lector_generator_day_manifest(date,text,text[],text[],text[],text[],jsonb)','execute'),
      'user_page',has_function_privilege('authenticated','lector_generator_day_page(date,text,jsonb,jsonb)','execute'),
      'server_page',has_function_privilege('service_role','lector_generator_day_page(date,text,jsonb,jsonb)','execute')) v`))
      .rows[0].v;
    assert.deepEqual(acl, {
      anon_manifest: false,
      user_page: false,
      server_page: true,
    });
    console.log(
      JSON.stringify({
        fixture: "synthetic-large-day",
        matches: loaded.coverage.loaded,
        pages: loaded.coverage.pages,
        bytes: loaded.coverage.bytes,
        elapsedMs,
        paidModelCalls: 0,
      }),
    );
  } finally {
    await db.close();
  }
});

Deno.test("an incomplete page fails the whole day read and retrieval never marks a match as AI-examined", async () => {
  const capturedAt = "2026-10-10T09:00:00Z";
  const matches = Array.from(
    { length: 500 },
    (_, i) => ({
      key: `hockey:${i + 1}`,
      matchId: String(i + 1),
      id: hockeyId,
      sport: "hockey",
      capturedAt,
    }),
  );
  const source = { id: hockeyId, sport: "hockey", capturedAt };
  const port: DaySourcePort = {
    manifest: async () => ({
      version: 1,
      date: day,
      timezone,
      total: matches.length,
      sources: [source],
      matches,
    }),
    page: async (p) => ({
      sources: [{
        ...source,
        payload: {
          items: (p.p_matches as typeof matches).map((r) => ({
            id: r.matchId,
            startsAt: `${day}T17:00:00Z`,
            status: "scheduled",
            home: { id: "1", name: "Home" },
            away: { id: "2", name: "Away" },
            readings: [],
          })),
        },
      }],
    }),
  };
  const reader = new ConversationReader({
    context,
    date: day,
    state: null,
    now: new Date(capturedAt),
    id: newerId,
    message: "Examine les rencontres",
  }, {
    sources: async () => {
      throw new Error("Unpaged source must not be loaded");
    },
    daySources: (c, d, s, progress) => loadDaySources(c, d, s, port, progress),
  });
  const search = (offset: number) =>
    reader.execute("search_matches", {
      date: day,
      sports: ["hockey"],
      view: "all",
      radarKind: "teams",
      query: null,
      offset,
      limit: 60,
    }) as Promise<any>;
  const keys: string[] = [];
  let offset: number | null = 0;
  while (offset !== null) {
    const page = await search(offset);
    assert.equal(page.total, 500);
    assert.equal(page.coverage.complete, true);
    keys.push(...page.matches.map((r: any) => r.key));
    offset = page.nextOffset;
  }
  assert.equal(new Set(keys).size, 500);
  assert.equal(reader.detailsRead.size, 0);
  assert.equal(reader.consultations()[0].coverage?.loaded, 500);
  const progress: boolean[] = [];
  await assert.rejects(
    loadDaySources(context, day, ["hockey"], {
      ...port,
      page: async (p) => {
        const result = await port.page(p) as any;
        result.sources[0].payload.items.pop();
        return result;
      },
    }, async (r) => {
      progress.push(r.complete);
    }),
    /incomplète/,
  );
  assert.ok(!progress.includes(true));
  await assert.rejects(
    loadDaySources(context, day, ["hockey"], {
      ...port,
      manifest: async () => ({
        version: 1,
        date: day,
        timezone,
        total: 501,
        sources: [source],
        matches,
      }),
    }),
    /incomplet/,
  );
});
