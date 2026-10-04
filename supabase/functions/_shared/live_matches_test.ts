import assert from "node:assert/strict";
import {
  collectLiveMatches,
  finalResult,
  liveObject,
  liveState,
  providerRows,
} from "./live_matches.ts";

export function fixture(id = 1, status = "2H", home = 1, away = 2) {
  return {
    fixture: {
      id,
      date: "2026-10-04T19:00:00Z",
      status: { short: status, elapsed: 67, extra: null },
    },
    league: { id: 140 },
    teams: { home: { id: 1, name: "Club A" }, away: { id: 2, name: "Club B" } },
    goals: { home, away },
    score: { halftime: { home: 0, away: 1 }, fulltime: { home, away } },
  };
}
Deno.test("live collection groups leagues, reconciles missing finals, and never invents scores", async () => {
  const queries: string[] = [];
  const statistics = [{
    team: { id: 1 },
    statistics: [{ type: "Total Shots", value: 0 }],
  }];
  const result = await collectLiveMatches([140, 39, 140], [2, 3], {
    reserve: () => Promise.resolve(true),
    fetchFixtures: (q) => {
      queries.push(q);
      return Promise.resolve({
        response: q.startsWith("live=")
          ? [fixture(1), { ...fixture(100), league: { id: 61 } }]
          : [{ ...fixture(2, "FT"), statistics }],
      });
    },
  }, "2026-10-04T20:07:00Z");
  assert.deepEqual(queries, ["live=140-39", "ids=2-3"]);
  assert.deepEqual(result.states.map((s) => s.fixture_id), [1, 2]);
  assert.deepEqual(result.checked, [2, 3]);
  assert.equal(result.results.length, 1);
  assert.equal(result.requests, 2);
  assert.deepEqual(result.states[1].statistics, statistics);
  assert.equal(result.states[1].statistics_captured_at, "2026-10-04T20:07:00Z");
  assert.equal(result.states[0].statistics, null);
  assert.equal(result.states[0].statistics_captured_at, null);
  assert.equal(
    liveState(
      { ...fixture(), goals: { home: null, away: null } },
      "2026-10-04T20:00:00Z",
    )?.home_goals,
    null,
  );
  assert.equal(
    await finalResult({
      ...fixture(3, "FT"),
      goals: { home: null, away: null },
    }, "2026-10-04T20:00:00Z"),
    null,
  );
});
Deno.test("shared quota refusal preserves live rows and postpones the bounded final batch", async () => {
  let calls = 0;
  const result = await collectLiveMatches(
    [140],
    Array.from({ length: 40 }, (_, i) => i + 1),
    {
      reserve: () => Promise.resolve(++calls === 1),
      fetchFixtures: () => Promise.resolve({ response: [fixture()] }),
    },
    "2026-10-04T20:07:00Z",
  );
  assert.equal(result.deferred, true);
  assert.equal(result.requests, 1);
  assert.equal(result.states.length, 1);
  assert.deepEqual(result.checked, []);
  const queries: string[] = [];
  await collectLiveMatches([140], Array.from({ length: 40 }, (_, i) => i + 1), {
    reserve: () => Promise.resolve(true),
    fetchFixtures: (q) => {
      queries.push(q);
      return Promise.resolve({ response: [] });
    },
  }, "2026-10-04T20:07:00Z");
  assert.equal(queries[1].split("-").length, 20);
});
Deno.test("final identity is idempotent and distinguishes corrections and incomplete player coverage", async () => {
  const noEvents = await finalResult(fixture(1, "FT"), "2026-10-04T21:00:00Z");
  const again = await finalResult(fixture(1, "FT"), "2026-10-04T21:05:00Z");
  assert.equal(noEvents?.content_hash, again?.content_hash);
  assert.equal(
    liveObject(liveObject(noEvents?.source_payload).computed)
      .player_events_complete,
    false,
  );
  const corrected = await finalResult(
    fixture(1, "FT", 1, 3),
    "2026-10-04T21:06:00Z",
  );
  assert.notEqual(noEvents?.content_hash, corrected?.content_hash);
  const detailed = await finalResult({
    ...fixture(1, "FT", 1, 0),
    events: [{
      type: "Goal",
      detail: "Normal Goal",
      player: { id: 7 },
      assist: { id: 8 },
    }],
  }, "2026-10-04T21:00:00Z");
  const computed = liveObject(liveObject(detailed?.source_payload).computed);
  assert.equal(computed.player_events_complete, true);
  assert.deepEqual(computed.player_decisive, { "7": true, "8": true });
  assert.throws(
    () =>
      providerRows({
        errors: { rateLimit: "Too many requests" },
        response: [],
      }),
    /Too many/,
  );
  assert.throws(() => providerRows({}), /réponse invalide/);
});
Deno.test("a final-detail API outage still publishes healthy live scores and retains retry backlog", async () => {
  let calls = 0;
  const result = await collectLiveMatches([140], [2], {
    reserve: () => Promise.resolve(true),
    fetchFixtures: () => {
      if (++calls === 2) throw new Error("API-Football HTTP 429");
      return Promise.resolve({ response: [fixture()] });
    },
  }, "2026-10-04T20:07:00Z");
  assert.equal(result.states.length, 1);
  assert.equal(result.results.length, 0);
  assert.deepEqual(result.checked, []);
  assert.equal(result.deferred, true);
  assert.match(result.issue ?? "", /429/);
  assert.equal(result.requests, 2);
});
