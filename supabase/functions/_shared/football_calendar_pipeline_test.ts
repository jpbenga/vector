import { strict as assert } from "node:assert";
import expected from "../../../test/fixtures/football_calendar_14_days_compact.json" with {
  type: "json",
};
type Obj = Record<string, any>;
type Handler = (request: Request) => Promise<Response>;
Deno.test("real collector -> raw snapshot -> compact publication retains day 14 and all odds pages", async () => {
  const originalFetch = globalThis.fetch;
  const originalServe = Deno.serve;
  const keys = [
    "SUPABASE_URL",
    "SUPABASE_SERVICE_ROLE_KEY",
    "API_FOOTBALL_KEY",
    "API_FOOTBALL_SYNC_SECRET",
  ];
  const environment = keys.map((key) => Deno.env.get(key));
  const handlers: Handler[] = [];
  const cache: Obj[] = [];
  const requests: URL[] = [];
  let reservations = 0;
  let rawSnapshot: Obj | undefined;
  let compactSnapshot: Obj | undefined;
  const fixtureOutsideWindow = {
    ...expected.raw.fixtures[0],
    fixture: {
      ...expected.raw.fixtures[0].fixture,
      id: 14,
      date: "2030-10-18T18:00:00+00:00",
    },
  };
  let allFixtures = [...expected.raw.fixtures, fixtureOutsideWindow];
  let providerOdds: Obj[] = [...expected.raw.odds];
  const json = (body: unknown) =>
    new Response(JSON.stringify(body), {
      headers: { "content-type": "application/json" },
    });
  try {
    keys.forEach((key) =>
      Deno.env.set(
        key,
        key === "SUPABASE_URL"
          ? "https://calendar-test.invalid"
          : "local-test-only",
      )
    );
    Deno.serve = ((handler: Handler) => {
      handlers.push(handler);
      return {};
    }) as typeof Deno.serve;
    await import("../api-football-sync/index.ts");
    await import("../build-match-feed-snapshot/index.ts");
    await import("../publish-reading-announcements/index.ts");
    await import("../analyze-match-feed-snapshot/index.ts");
    Deno.serve = originalServe;
    const [collect, build, publish, analyze] = handlers;
    assert.equal(handlers.length, 4);
    globalThis.fetch =
      (async (input: RequestInfo | URL, init?: RequestInit) => {
        const url = new URL(String(input));
        const body = init?.body ? JSON.parse(String(init.body)) : null;
        const method = init?.method ?? "GET";
        if (url.hostname === "v3.football.api-sports.io") {
          requests.push(url);
          const query = url.searchParams;
          let response: unknown[] = [];
          let pages = 1;
          if (url.pathname === "/leagues") {
            response = [{
              league: { id: 61 },
              seasons: [{
                year: 2030,
                start: "2030-07-01",
                end: "2031-06-30",
                current: true,
              }],
            }];
          }
          if (url.pathname === "/fixtures" && !query.has("h2h")) {
            response = query.has("date")
              ? allFixtures.filter((f) =>
                f.fixture.date.startsWith(query.get("date")!)
              )
              : allFixtures;
          }
          if (url.pathname === "/odds" && query.get("date") === "2030-10-17") {
            pages = 2;
            response = query.get("page") === "2"
              ? providerOdds.slice(10)
              : providerOdds.slice(0, 10);
          }
          return json({
            errors: [],
            response,
            paging: { current: Number(query.get("page") ?? 1), total: pages },
          });
        }
        assert.equal(
          url.hostname,
          "calendar-test.invalid",
          "Unexpected network destination; test never calls production.",
        );
        if (url.pathname === "/functions/v1/publish-reading-announcements") {
          return await publish(new Request(url, init));
        }
        if (url.pathname.endsWith("/rpc/reserve_api_football_request")) {
          assert.equal(body.p_daily_limit, 75000);
          assert.equal(body.p_minute_limit, 280);
          reservations++;
          return json([{ allowed: true }]);
        }
        if (url.pathname.endsWith("/api_football_sync_runs")) {
          return json(method === "POST" ? [{ id: "test-run" }] : []);
        }
        if (url.pathname.endsWith("/api_football_cached_responses")) {
          if (method === "POST") {
            for (const row of body) {
              const old = cache.findIndex((r) =>
                r.query_hash === row.query_hash
              );
              if (old >= 0) cache.splice(old, 1);
              cache.unshift(row);
            }
            return json([]);
          }
          return json(
            cache.filter((row) =>
              [...url.searchParams].every(([key, value]) => {
                if (key.startsWith("query_params->>")) {
                  return String(row.query_params[key.slice(15)]) ===
                    value.slice(3);
                }
                if (["source", "endpoint", "query_hash"].includes(key)) {
                  return row[key] === value.slice(3);
                }
                return true;
              })
            ),
          );
        }
        if (url.pathname.endsWith("/match_feed_snapshots")) {
          if (method === "POST") {
            rawSnapshot = { ...body[0], id: "raw-test" };
            return json([rawSnapshot]);
          }
          return json(
            rawSnapshot && url.searchParams.has("id") ? [rawSnapshot] : [],
          );
        }
        if (
          url.pathname.endsWith("/match_feed_snapshot_fixtures") ||
          url.pathname.endsWith("/match_feed_snapshot_sources")
        ) {
          return json([]);
        }
        if (url.pathname.endsWith("/match_reading_announcements")) {
          return json([]);
        }
        if (url.pathname.endsWith("/match_feed_analysis_snapshots")) {
          if (method === "POST") {
            compactSnapshot = body[0];
            return json([{ ...compactSnapshot, id: "compact-test" }]);
          }
          return json([]);
        }
        throw new Error(`Unhandled mocked database endpoint: ${url.pathname}`);
      }) as typeof fetch;
    const invoke = async (handler: Handler, payload: Obj) => {
      const response = await handler(
        new Request("https://calendar-test.invalid", {
          method: "POST",
          headers: {
            authorization: "Bearer local-test-only",
            "content-type": "application/json",
          },
          body: JSON.stringify(payload),
        }),
      );
      const body = await response.json();
      assert.equal(response.status, 200, JSON.stringify(body));
      assert.equal(body.ok, true, JSON.stringify(body));
      return body;
    };
    const options = {
      league_ids: [61],
      season: 2030,
      window_start: expected.window_start,
      window_end: expected.window_end,
      timezone: expected.timezone,
    };
    await invoke(collect, {
      ...options,
      api_request_delay_ms: 0,
      include_team_statistics: false,
      include_recent_form: false,
      include_expected_goals: false,
      include_recent_player_performances: false,
    });
    assert.equal(
      requests.filter((url) =>
        url.pathname === "/fixtures" && url.searchParams.has("date")
      ).length,
      4,
      "Far calendar reuses the season request.",
    );
    assert.equal(
      requests.filter((url) => url.pathname === "/odds").length,
      3,
      "Only match dates are queried, with both pages on day 14.",
    );
    await invoke(build, {
      ...options,
      as_of: expected.captured_at,
      force_rebuild: true,
    });
    assert.equal(
      reservations,
      requests.length,
      "Every additional odds page still reserves the shared provider quota.",
    );
    assert.equal(rawSnapshot!.date_window.length, 14);
    assert.deepEqual(rawSnapshot!.payload.raw.fixtures, expected.raw.fixtures);
    assert.deepEqual(rawSnapshot!.payload.raw.odds, expected.raw.odds);
    await invoke(analyze, { snapshot_id: "raw-test" });
    assert.equal(compactSnapshot!.source_snapshot_id, "raw-test");
    assert.deepEqual(
      JSON.parse(JSON.stringify(compactSnapshot!.payload)),
      expected,
      "Same public payload is consumed by the Flutter regression test.",
    );
    // On the next daily collection, expire the simulated provider cache.
    // Yesterday leaves the window, a new day enters, and odds appear for a
    // previously unpriced fixture. Publication must reflect the new state.
    cache.length = 0;
    providerOdds.push({ ...expected.raw.odds[0], fixture: { id: 13 } });
    const tomorrow = {
      ...options,
      window_start: "2030-10-05",
      window_end: "2030-10-18",
    };
    await invoke(collect, {
      ...tomorrow,
      api_request_delay_ms: 0,
      include_team_statistics: false,
      include_recent_form: false,
      include_expected_goals: false,
      include_recent_player_performances: false,
    });
    await invoke(build, {
      ...tomorrow,
      as_of: "2030-10-05T04:00:00Z",
      force_rebuild: true,
    });
    await invoke(analyze, { snapshot_id: "raw-test" });
    const updated = compactSnapshot!.payload;
    assert.equal(updated.window_end, "2030-10-18");
    assert.equal(
      updated.raw.fixtures.some((f: Obj) => f.fixture.id === 1),
      false,
    );
    assert.equal(
      updated.raw.fixtures.some((f: Obj) => f.fixture.id === 14),
      true,
    );
    assert.equal(updated.raw.odds.some((o: Obj) => o.fixture.id === 13), true);
    // An inactive competition is a successful empty calendar, including the
    // compact publication. It must not be confused with absent collection.
    cache.length = 0;
    allFixtures = [];
    providerOdds = [];
    await invoke(collect, {
      ...tomorrow,
      api_request_delay_ms: 0,
      include_team_statistics: false,
      include_recent_form: false,
      include_expected_goals: false,
      include_recent_player_performances: false,
    });
    await invoke(build, {
      ...tomorrow,
      as_of: "2030-10-05T05:00:00Z",
      force_rebuild: true,
    });
    await invoke(analyze, { snapshot_id: "raw-test" });
    assert.deepEqual(compactSnapshot!.payload.raw.fixtures, []);
    assert.equal(compactSnapshot!.payload.window_end, tomorrow.window_end);
  } finally {
    globalThis.fetch = originalFetch;
    Deno.serve = originalServe;
    keys.forEach((key, i) =>
      environment[i] === undefined
        ? Deno.env.delete(key)
        : Deno.env.set(key, environment[i]!)
    );
  }
});
