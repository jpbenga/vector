import assert from "node:assert/strict";
import { collectHockeyLive } from "./hockey_live.ts";
const game = (status = "FT") => ({
  id: 430525,
  date: "2026-10-05T14:00:00+00:00",
  league: { id: 35, name: "KHL", season: 2026 },
  teams: {
    home: { id: 1487, name: "Magnitogorsk", logo: null },
    away: { id: 831, name: "Vladivostok", logo: null },
  },
  status: { short: status },
  scores: { home: 2, away: 5 },
  periods: {
    first: "0-0",
    second: "1-4",
    third: "1-1",
    overtime: null,
    penalties: null,
  },
});
const envelope = (rows: unknown[]) => ({
  errors: [],
  results: rows.length,
  response: rows,
});
Deno.test("grouped hockey collection: real KHL final, venue order, periods and whitelist", async () => {
  let requests = 0;
  const foreign = {
    ...game(),
    id: 999,
    league: { id: 99, name: "Unknown", season: 2026 },
  };
  const result = await collectHockeyLive(["2026-10-05"], {
    reserve: async () => true,
    request: async () => {
      requests++;
      return envelope([game(), foreign]);
    },
  }, "2026-10-05T18:00:00Z");
  assert.equal(requests, 1);
  assert.equal(result.states.length, 1);
  const f = result.states[0].fixture;
  assert.equal(f.status, "finished");
  assert.equal(f.away.name, "Vladivostok");
  assert.deepEqual(f.scores.final, { home: 2, away: 5 });
  assert.deepEqual(f.scores.second, { home: 1, away: 4 });
  assert.equal(result.states[0].capturedAt, "2026-10-05T18:00:00Z");
});
Deno.test("hockey never invents a live match from kickoff; errors/partial envelopes cannot publish", async () => {
  const ports = {
    reserve: async () => true,
    request: async () => envelope([game("NS")]),
  };
  const result = await collectHockeyLive(
    ["2026-10-05"],
    ports,
    "2026-10-05T18:00:00Z",
  );
  assert.equal(result.states[0].fixture.status, "scheduled");
  assert.equal(result.states[0].fixture.scores.final, undefined);
  await assert.rejects(() =>
    collectHockeyLive(["2026-10-05"], {
      ...ports,
      request: async () => ({
        errors: { rateLimit: "Reached" },
        results: 0,
        response: [],
      }),
    }, "2026-10-05T18:00:00Z")
  );
  await assert.rejects(() =>
    collectHockeyLive(["2026-10-05"], {
      ...ports,
      request: async () => ({ errors: [], results: 2, response: [game()] }),
    }, "2026-10-05T18:00:00Z")
  );
});
Deno.test("revoked quota prevents external requests and collection remains deferred", async () => {
  let calls = 0;
  const result = await collectHockeyLive(["2026-10-05", "2026-10-04"], {
    reserve: async () => false,
    request: async () => {
      calls++;
      return envelope([]);
    },
  }, "2026-10-05T18:00:00Z");
  assert.equal(calls, 0);
  assert.equal(result.deferred, true);
  assert.deepEqual(result.states, []);
  await assert.rejects(() =>
    collectHockeyLive(["2026-10-06"], {
      reserve: async () => true,
      request: async () => envelope([]),
    }, "2026-10-05T18:00:00Z")
  );
});
