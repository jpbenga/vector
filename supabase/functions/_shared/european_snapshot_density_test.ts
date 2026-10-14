import assert from "node:assert/strict";
type Obj = Record<string, any>;
type Handler = (r: Request) => Promise<Response>;
Deno.test("real European snapshot builder loads and appends shared domestic history once; provider error statistics remain absent", async () => {
  const fetchBefore = globalThis.fetch, serveBefore = Deno.serve;
  const keys = [
    "SUPABASE_URL",
    "SUPABASE_SERVICE_ROLE_KEY",
    "API_FOOTBALL_SYNC_SECRET",
  ];
  const saved = keys.map((k) => Deno.env.get(k));
  let handler: Handler = () => Promise.reject(Error("Handler not registered"));
  const cache: Obj[] = [], queries: URL[] = [];
  let published: Obj;
  const json = (body: unknown) => new Response(JSON.stringify(body));
  const fixture = (
    id: number,
    league: number,
    date: string,
    status: string,
  ) => ({
    fixture: { id, date, status: { short: status } },
    league: { id: league, season: 2030 },
    teams: { home: { id: 10, name: "Home" }, away: { id: 11, name: "Away" } },
    goals: { home: 1, away: 0 },
  });
  function add(
    endpoint: string,
    query_params: Obj,
    response: Obj[],
    errors: Obj | unknown[] = [],
  ) {
    cache.push({
      source: "api-football",
      endpoint,
      query_hash: String(cache.length),
      query_params,
      response_status: 200,
      response_body: { response, errors },
      fetched_at: "2030-10-14T12:00:00Z",
      as_of: "2030-10-14T12:00:00Z",
      sync_run_id: null,
    });
  }
  const matches = Array.from(
    { length: 10 },
    (_, i) => fixture(i + 1, 2, "2030-10-14T19:00:00Z", "NS"),
  );
  add("/leagues", { id: "2" }, [{
    league: { id: 2, type: "Cup" },
    seasons: [{ year: 2030, start: "2030-07-01", end: "2031-06-30" }],
  }]);
  add("/leagues", { id: "61" }, [{
    league: { id: 61, type: "League" },
    seasons: [{ year: 2030, start: "2030-07-01", end: "2031-06-30" }],
  }]);
  add(
    "/fixtures",
    { league: "2", season: "2030", timezone: "Europe/Paris" },
    matches,
  );
  add("/fixtures", {
    league: "2",
    season: "2030",
    date: "2030-10-14",
    timezone: "Europe/Paris",
  }, matches);
  add("/standings", { league: "61", season: "2030" }, [{
    league: {
      id: 61,
      season: 2030,
      country: "France",
      standings: [[{ team: { id: 10 } }, { team: { id: 11 } }]],
    },
  }]);
  add(
    "/fixtures",
    { league: "61", season: "2030", timezone: "Europe/Paris" },
    Array.from(
      { length: 300 },
      (_, i) => fixture(i + 100, 61, "2030-10-01T19:00:00Z", "FT"),
    ),
  );
  for (const team of ["10", "11"]) {
    add("/teams/statistics", { league: "2", season: "2030", team }, [], {
      bug: "5xEr",
    });
  }
  try {
    keys.forEach((k) =>
      Deno.env.set(
        k,
        k === "SUPABASE_URL" ? "https://snapshot-test.invalid" : "local-only",
      )
    );
    Deno.serve = ((h: Handler) => {
      handler = h;
      return {};
    }) as typeof Deno.serve;
    await import("../build-match-feed-snapshot/index.ts");
    Deno.serve = serveBefore;
    globalThis.fetch =
      (async (input: RequestInfo | URL, init?: RequestInit) => {
        const url = new URL(String(input));
        assert.equal(url.hostname, "snapshot-test.invalid");
        const body = init?.body ? JSON.parse(String(init.body)) : null;
        if (url.pathname.endsWith("/api_football_cached_responses")) {
          queries.push(url);
          return json(
            cache.filter((r) =>
              [...url.searchParams].every(([k, v]) =>
                k === "endpoint"
                  ? r.endpoint === v.slice(3)
                  : k.startsWith("query_params->>")
                  ? (v.startsWith("in.")
                    ? v.slice(4, -1).split(",").includes(
                      String(r.query_params[k.slice(15)]),
                    )
                    : String(r.query_params[k.slice(15)]) === v.slice(3))
                  : true
              )
            ),
          );
        }
        if (url.pathname.endsWith("/match_feed_snapshots")) {
          if (init?.method === "POST") {
            published = body[0];
            return json([{ ...published, id: "snapshot" }]);
          }
          return json([]);
        }
        if (
          url.pathname.endsWith("/match_feed_snapshot_fixtures") ||
          url.pathname.endsWith("/match_feed_snapshot_sources")
        ) return json([]);
        throw Error("Unexpected local request " + url.pathname);
      }) as typeof fetch;
    const response = await handler(
      new Request("https://snapshot-test.invalid", {
        method: "POST",
        headers: {
          authorization: "Bearer local-only",
          "content-type": "application/json",
        },
        body: JSON.stringify({
          league_ids: [2],
          season: 2030,
          window_start: "2030-10-14",
          window_end: "2030-10-27",
          timezone: "Europe/Paris",
          as_of: "2030-10-14T12:00:00Z",
          force_rebuild: true,
        }),
      }),
    );
    const result = await response.json();
    assert.equal(response.status, 200, JSON.stringify(result));
    assert.equal(published!.payload.raw.fixtures.length, 10);
    assert.equal(
      published!.payload.raw.league_fixtures.filter((f: Obj) =>
        f.league.id === 61
      ).length,
      300,
      "not twenty copies of 300 rows",
    );
    assert.equal(
      queries.filter((q) =>
        q.searchParams.get("endpoint") === "eq./fixtures" &&
        q.searchParams.get("query_params->>league") === "eq.61" &&
        !q.searchParams.has("query_params->>team")
      ).length,
      1,
    );
    assert.equal(
      published!.payload.raw.team_statistics.length,
      0,
      "unavailable statistics are absent, never zero",
    );
  } finally {
    globalThis.fetch = fetchBefore;
    Deno.serve = serveBefore;
    keys.forEach((k, i) =>
      saved[i] === undefined ? Deno.env.delete(k) : Deno.env.set(k, saved[i]!)
    );
  }
});
