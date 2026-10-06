import assert from "node:assert/strict";
type Obj = Record<string, any>;
Deno.test("future feed drops season-total venue readings while historical announcements remain unchanged", async () => {
  const originalServe = Deno.serve, originalFetch = globalThis.fetch;
  const keys = [
    "SUPABASE_URL",
    "SUPABASE_SERVICE_ROLE_KEY",
    "API_FOOTBALL_SYNC_SECRET",
  ];
  const previous = keys.map((k) => Deno.env.get(k));
  let handler: (r: Request) => Promise<Response> = () =>
    Promise.reject(new Error("Missing handler"));
  let stored: Obj | null = null;
  const json = (value: unknown) =>
    new Response(JSON.stringify(value), {
      headers: { "content-type": "application/json" },
    });
  const fact = (
    fixture: number,
    id: string,
    version: string,
    source = "older-source",
  ) => ({
    fixture_id: fixture,
    reading_id: id,
    reading_label: id,
    subject_side: "home",
    subject_team_id: "api-team-1",
    engine_version: version,
    source_snapshot_id: source,
    evidence: [],
    sample_size: 3,
    outcome_rule: "team_win",
  });
  try {
    keys.forEach((k) =>
      Deno.env.set(
        k,
        k === "SUPABASE_URL"
          ? "https://venue-materialization.invalid"
          : "test-secret",
      )
    );
    Deno.serve = ((h: typeof handler) => {
      handler = h;
      return {};
    }) as typeof Deno.serve;
    await import("../analyze-match-feed-snapshot/index.ts");
    Deno.serve = originalServe;
    globalThis.fetch =
      (async (input: RequestInfo | URL, init?: RequestInit) => {
        const url = new URL(String(input));
        assert.equal(url.hostname, "venue-materialization.invalid");
        if (url.pathname === "/functions/v1/publish-reading-announcements") {
          return json({ ok: true });
        }
        if (url.pathname.endsWith("match_feed_snapshots")) {
          return json([{
            id: "current",
            captured_at: "2026-10-07T04:00:00Z",
            timezone: "Europe/Paris",
            payload: {
              raw: {
                fixtures: [{
                  fixture: { id: 1, date: "2026-10-08T20:00:00Z" },
                  league: { id: 61 },
                  teams: {
                    home: { id: 1, name: "Atlas" },
                    away: { id: 2, name: "Rivage" },
                  },
                }, {
                  fixture: { id: 2, date: "2026-10-06T20:00:00Z" },
                  league: { id: 61 },
                  teams: {
                    home: { id: 1, name: "Atlas" },
                    away: { id: 2, name: "Rivage" },
                  },
                }],
              },
            },
          }]);
        }
        if (url.pathname.endsWith("match_reading_announcements")) {
          return json([
            fact(1, "strong_home_team", "server_level_form_venue_v1"),
            fact(1, "strong_home_team", "server_venue_momentum_v2"),
            fact(1, "weak_away_team", "server_level_form_venue_v1"),
            fact(1, "home_winning_streak", "server_victory_series_v1"),
            fact(1, "winning_streak", "server_victory_series_v1"),
            fact(2, "strong_home_team", "server_level_form_venue_v1"),
          ]);
        }
        if (url.pathname.endsWith("match_feed_analysis_snapshots")) {
          if (init?.method === "POST") {
            stored = JSON.parse(String(init.body))[0];
            return json([{ id: "compact" }]);
          }
          return json([]);
        }
        throw new Error(`Unexpected endpoint ${url.pathname}`);
      }) as typeof fetch;
    const response = await handler(
      new Request("https://venue-materialization.invalid", {
        method: "POST",
        headers: {
          authorization: "Bearer test-secret",
          "content-type": "application/json",
        },
        body: JSON.stringify({ snapshot_id: "current" }),
      }),
    );
    assert.equal(response.status, 200, await response.text());
    const fixtures = (stored as unknown as Obj).payload.computed.fixtures;
    assert.deepEqual(
      fixtures.find((f: Obj) => f.fixture_id === 1).readings.map((r: Obj) =>
        r.id
      ),
      ["strong_home_team", "winning_streak"],
    );
    assert.deepEqual(
      fixtures.find((f: Obj) => f.fixture_id === 2).readings.map((r: Obj) =>
        r.id
      ),
      ["strong_home_team"],
    );
  } finally {
    Deno.serve = originalServe;
    globalThis.fetch = originalFetch;
    keys.forEach((k, i) =>
      previous[i] === undefined
        ? Deno.env.delete(k)
        : Deno.env.set(k, previous[i]!)
    );
  }
});
