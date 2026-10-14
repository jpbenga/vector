import assert from "node:assert/strict";
import {
  collectEuropeanBatch,
  type EuropeanCursor,
} from "./european_collection.ts";
const now = new Date("2030-10-14T16:00:00Z");
function fixture(
  id: number,
  home: number,
  away: number,
  date = "2030-10-14T19:00:00Z",
  status = "NS",
) {
  return {
    fixture: { id, date, status: { short: status } },
    league: { id: 2, season: 2030 },
    teams: { home: { id: home }, away: { id: away } },
  };
}
Deno.test("all three UEFA collectors resume bounded requests, paginate quotes and omit unavailable statistics without zeroes", async () => {
  for (const leagueId of [2, 3, 848]) {
    const calls: string[] = [], missing: string[] = [], recorded: string[] = [];
    let cursor: Record<string, any> = {}, finished = false, passes = 0;
    const port = {
      season: () => 2030,
      record: (kind: string) => recorded.push(kind),
      missingStatistics: (id: string) => missing.push(id),
      fetch: async (r: any) => {
        calls.push(r.endpoint + JSON.stringify(r.query));
        if (r.endpoint === "/teams/statistics") {
          throw Error("API-Football error for /teams/statistics: bug: 5xEr");
        }
        const response =
          r.endpoint === "/fixtures" && !r.query.date && !r.query.team
            ? [
              fixture(1, 10, 11),
              fixture(2, 12, 13),
              fixture(99, 88, 89, "2030-08-01T19:00:00Z", "FT"),
            ]
            : [];
        return {
          body: { response, paging: { total: r.endpoint === "/odds" ? 2 : 1 } },
          fromCache: false,
          fetchedAt: now.toISOString(),
        };
      },
    };
    while (!finished) {
      const result = await collectEuropeanBatch({
        leagueId,
        runId: "run",
        timezone: "Europe/Paris",
        windowStart: "2030-10-14",
        windowEnd: "2030-10-27",
        recentDays: 180,
        cursor,
        now,
      }, port);
      assert.ok(result.calls <= 10);
      cursor = result.cursor;
      finished = result.done;
      assert.ok(++passes < 15);
    }
    assert.ok(passes > 1);
    assert.deepEqual(missing, ["10", "11", "12", "13"]);
    assert.equal(recorded.includes("statistics"), false);
    assert.ok(calls.some((c) => c.includes('"page":"2"')));
    assert.equal(calls.filter((c) => c.startsWith("/leagues")).length, 1);
    assert.ok(
      !calls.some((c) =>
        c.includes('"team":"88"') || c.includes('"team":"89"')
      ),
    );
    assert.equal(
      new Set(calls).size,
      calls.length,
      "no completed request replayed",
    );
  }
});
Deno.test("quota errors and foreign checkpoints fail, never become missing statistics", async () => {
  const cursor: EuropeanCursor = {
    version: 1,
    run_id: "run",
    season: 2030,
    offset: 0,
    tasks: [{
      endpoint: "/teams/statistics",
      query: { league: "2", season: "2030", team: "10" },
      kind: "statistics",
      ttlSeconds: 3600,
    }],
  };
  const input = {
    leagueId: 2,
    runId: "run",
    timezone: "Europe/Paris",
    windowStart: "2030-10-14",
    windowEnd: "2030-10-27",
    recentDays: 180,
    cursor,
    now,
  };
  let missing = false;
  const port = {
    season: () => 2030,
    record: () => {},
    missingStatistics: () => {
      missing = true;
    },
    fetch: () =>
      Promise.reject(Error("API-Football quota 429 for /teams/statistics")),
  };
  await assert.rejects(() => collectEuropeanBatch(input, port), /quota/);
  assert.equal(missing, false);
  await assert.rejects(
    () => collectEuropeanBatch({ ...input, runId: "other" }, port),
    /checkpoint/,
  );
  await assert.rejects(
    () => collectEuropeanBatch({ ...input, leagueId: 61 }, port),
    /restricted/,
  );
});
