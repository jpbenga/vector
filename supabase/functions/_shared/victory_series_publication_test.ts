import { strict as assert } from "node:assert";
type Obj = Record<string, unknown>;
Deno.test("real publisher uses current venue runs and rejects aggregates or draws", async () => {
  const originalServe = Deno.serve, originalFetch = globalThis.fetch;
  const keys = [
    "SUPABASE_URL",
    "SUPABASE_SERVICE_ROLE_KEY",
    "API_FOOTBALL_SYNC_SECRET",
  ];
  const previous = keys.map((k) => Deno.env.get(k));
  let handler: (request: Request) => Promise<Response> = () =>
    Promise.reject(new Error("Handler missing"));
  const inserted: Obj[] = [];
  const json = (value: unknown) =>
    new Response(JSON.stringify(value), {
      headers: { "content-type": "application/json" },
    });
  try {
    keys.forEach((k) =>
      Deno.env.set(
        k,
        k === "SUPABASE_URL" ? "https://series-test.invalid" : "mock-secret",
      )
    );
    Deno.serve = ((h: typeof handler) => {
      handler = h;
      return {};
    }) as typeof Deno.serve;
    await import("../publish-reading-announcements/index.ts");
    Deno.serve = originalServe;
    const history = (id: number, results: string[], venues: string[]) => ({
      league: { id: 61 },
      team: { id },
      matches: results.map((result, i) => ({
        fixture: { id: id * 100 + i, date: `2026-10-0${5 - i}T12:00:00Z` },
        result,
        venue: venues[i],
      })),
    });
    let histories = [
      history(1, ["W", "L", "W", "L", "W"], [
        "home",
        "away",
        "home",
        "away",
        "home",
      ]),
      history(2, ["W", "W", "W"], ["away", "away", "away"]),
    ];
    globalThis.fetch =
      (async (input: RequestInfo | URL, init?: RequestInit) => {
        const url = new URL(String(input));
        assert.equal(
          url.hostname,
          "series-test.invalid",
          "No external request is permitted in this test.",
        );
        if (url.pathname.endsWith("match_feed_snapshots")) {
          return json([{
            id: "source",
            captured_at: "2026-10-06T04:00:00Z",
            timezone: "Europe/Paris",
            payload: {
              raw: {
                fixtures: [{
                  fixture: { id: 999, date: "2026-10-07T20:00:00Z" },
                  league: { id: 61 },
                  teams: {
                    home: { id: 1, name: "Atlas" },
                    away: { id: 2, name: "Rivage" },
                  },
                }],
                recent_league_matches: histories,
                // Deliberately favourable aggregates cannot activate a run.
                team_statistics: [{
                  league: { id: 61 },
                  team: { id: 1 },
                  fixtures: {
                    played: { home: 20, away: 20 },
                    wins: { home: 12, away: 12 },
                    loses: { home: 3, away: 3 },
                  },
                }, {
                  league: { id: 61 },
                  team: { id: 2 },
                  fixtures: {
                    played: { home: 20, away: 20 },
                    wins: { home: 2, away: 2 },
                    loses: { home: 15, away: 15 },
                  },
                }],
              },
            },
          }]);
        }
        if (
          url.pathname.endsWith("match_reading_announcements") &&
          (init?.method ?? "GET") === "POST"
        ) {
          inserted.push(...JSON.parse(String(init!.body)));
          return json([]);
        }
        throw new Error(`Unexpected mocked endpoint: ${url.pathname}`);
      }) as typeof fetch;
    const response = await handler(
      new Request("https://series-test.invalid", {
        method: "POST",
        headers: {
          authorization: "Bearer mock-secret",
          "content-type": "application/json",
        },
        body: JSON.stringify({ snapshot_id: "source" }),
      }),
    );
    assert.equal(response.status, 200, await response.text());
    assert.deepEqual(
      inserted.filter((r) => r.outcome_rule !== null).map((r) =>
        `${r.subject_side}:${r.reading_id}`
      ).sort(),
      ["away:strong_away_team", "away:winning_streak", "home:strong_home_team"],
    );
    assert.equal(
      inserted.some((r) =>
        String(r.reading_id).includes("winning_streak") &&
        r.reading_id !== "winning_streak"
      ),
      false,
    );
    for (const row of inserted.filter((r) => r.outcome_rule !== null)) {
      assert.equal(row.outcome_rule, "team_win");
      const value = (row.evidence as Obj[])[0].value as Obj;
      assert.equal(value.consecutiveResults ?? value.consecutiveWins, 3);
      assert.equal(
        row.engine_version,
        row.reading_id === "winning_streak"
          ? "server_victory_series_v1"
          : "server_venue_momentum_v2",
      );
    }
    async function publish() {
      inserted.length = 0;
      const response = await handler(
        new Request("https://series-test.invalid", {
          method: "POST",
          headers: {
            authorization: "Bearer mock-secret",
            "content-type": "application/json",
          },
          body: JSON.stringify({ snapshot_id: "source" }),
        }),
      );
      assert.equal(response.status, 200, await response.text());
      return new Set(inserted.map((r) => r.reading_id));
    }
    histories = [
      history(1, ["W", "W", "W"], ["home", "home", "home"]),
      history(2, ["L", "L", "L"], ["away", "away", "away"]),
    ];
    let ids = await publish();
    assert.ok(
      ids.has("strong_home_team") && ids.has("weak_away_team") &&
        ids.has("home_away_advantage"),
    );
    assert.equal(ids.has("away_home_advantage"), false);
    assert.equal(
      inserted.find((r) => r.reading_id === "weak_away_team")!.outcome_rule,
      "team_loss",
    );
    histories = [
      history(1, ["W", "W", "W"], ["home", "home", "home"]),
      history(2, ["D", "L", "L"], ["away", "away", "away"]),
    ];
    ids = await publish();
    assert.equal(ids.has("weak_away_team"), false);
    assert.equal(ids.has("home_away_advantage"), false);
    histories = [
      history(1, ["L", "L", "L"], ["home", "home", "home"]),
      history(2, ["W", "W", "W"], ["away", "away", "away"]),
    ];
    ids = await publish();
    assert.ok(ids.has("away_home_advantage"));
    assert.equal(ids.has("strong_home_team"), false);
    histories = [];
    ids = await publish();
    assert.equal(ids.has("strong_home_team"), false);
    assert.equal(ids.has("weak_away_team"), false);
    assert.equal(ids.has("home_away_advantage"), false);
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
