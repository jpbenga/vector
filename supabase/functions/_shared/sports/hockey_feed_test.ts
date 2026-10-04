import assert from "node:assert/strict";
import raw from "../../../../test/fixtures/sports/nhl_raw.json" with {
  type: "json",
};
import expected from "../../../../test/fixtures/sports/nhl_compact.json" with {
  type: "json",
};
import {
  calendarDate,
  collectNhl,
  compactNhlGames,
  currentNhlSeason,
  providerRows,
} from "./hockey_feed.ts";
const now = new Date(expected.capturedAt);
const metadata = {
  season: "2026",
  capturedAt: now.toISOString(),
  windowStart: "2026-09-27",
  windowEnd: "2026-10-17",
  timezone: "Europe/Paris",
  collectionId: "nhl-contract-example",
};
Deno.test("real NHL response -> raw -> compact public contract consumed by Flutter", async () => {
  const stored = new Map<string, unknown>();
  const queries: unknown[] = [];
  let published: unknown;
  const result = await collectNhl(
    {
      request: (path, parameters) => {
        queries.push([path, parameters]);
        return Promise.resolve(path === "leagues" ? raw.leagues : raw.games);
      },
      saveRaw: (kind, payload) => {
        stored.set(kind, payload);
        return Promise.resolve();
      },
      publish: (value) => {
        published = value;
        return Promise.resolve();
      },
    },
    now,
    "nhl-contract-example",
  );
  assert.deepEqual(result, expected);
  assert.deepEqual(published, expected);
  assert.equal(stored.get("games"), raw.games);
  assert.deepEqual(queries, [["leagues", { id: "57" }], ["games", {
    league: "57",
    season: "2026",
    timezone: "Europe/Paris",
  }]]);
  assert.deepEqual(result.items[0].scores.regulation, { home: 3, away: 3 });
  assert.deepEqual(result.items[0].scores.final, { home: 3, away: 4 });
});
Deno.test("HTTP-200 provider errors, duplicates and crossed competition never replace publication", async () => {
  const errors = {
    errors: { requests: "Too many requests" },
    results: 0,
    response: [],
  };
  assert.throws(() => providerRows(errors));
  assert.throws(() =>
    compactNhlGames({
      ...raw.games,
      results: 2,
      response: [...raw.games.response, ...raw.games.response],
    }, metadata)
  );
  assert.throws(() =>
    compactNhlGames({
      ...raw.games,
      response: [{
        ...raw.games.response[0],
        league: { id: 58, season: 2026 },
      }],
    }, metadata)
  );
  let publication: unknown = expected;
  const saved: string[] = [];
  await assert.rejects(() =>
    collectNhl(
      {
        request: (path) =>
          Promise.resolve(path === "leagues" ? raw.leagues : errors),
        saveRaw: (kind) => {
          saved.push(kind);
          return Promise.resolve();
        },
        publish: (value) => {
          publication = value;
          return Promise.resolve();
        },
      },
      now,
      "failed-run",
    )
  );
  assert.equal(publication, expected);
  assert.deepEqual(saved, ["leagues", "games"]);
  assert.throws(() =>
    currentNhlSeason({ ...raw.leagues, response: [{ id: 57, seasons: [] }] })
  );
});
Deno.test("empty calendars are publishable and inclusive Paris dates handle midnight and DST", () => {
  assert.equal(
    compactNhlGames({ errors: [], results: 0, response: [] }, metadata).items
      .length,
    0,
  );
  assert.equal(calendarDate(new Date("2026-10-03T22:30:00Z")), "2026-10-04");
  assert.equal(calendarDate(new Date("2026-10-25T23:30:00Z")), "2026-10-26");
  const game = raw.games.response[0];
  const envelope = (date: string) => ({
    errors: [],
    results: 1,
    response: [{ ...game, date }],
  });
  assert.equal(
    compactNhlGames(envelope("2026-10-17T21:59:00Z"), metadata).items.length,
    1,
  );
  assert.equal(
    compactNhlGames(envelope("2026-10-17T22:00:00Z"), metadata).items.length,
    0,
  );
  assert.equal(
    compactNhlGames(envelope("2026-09-26T22:00:00Z"), metadata).items.length,
    1,
  );
});
Deno.test("shootouts finish; scheduled zeroes and missing periods never invent results", () => {
  const game = raw.games.response[0];
  const normalize = (extra: object) =>
    compactNhlGames({
      errors: [],
      results: 1,
      response: [{ ...game, ...extra }],
    }, metadata).items[0];
  assert.equal(normalize({ status: { short: "AP" } }).status, "finished");
  assert.deepEqual(
    normalize({
      status: { short: "NS" },
      scores: { home: 0, away: 0 },
      periods: null,
    }).scores,
    {},
  );
  assert.equal(normalize({ periods: null }).scores.regulation, undefined);
  assert.deepEqual(normalize({ periods: null }).scores.final, {
    home: 3,
    away: 4,
  });
  assert.equal(
    normalize({ status: { short: "FUTURE_STATUS" } }).status,
    "unknown",
  );
});
