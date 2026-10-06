import assert from "node:assert/strict";
import {
  collectHockey,
  compactHockeyCollection,
  hockeyLeagueIds,
} from "./hockey_feed.ts";
const now = new Date("2026-10-04T10:00:00Z");
const envelope = <T>(response: T[]) => ({
  errors: [],
  results: response.length,
  response,
});
function raw(id: number) {
  const league = {
    id,
    name: `League ${id}`,
    season: 2026,
    logo: null,
    country: {
      name: "Country",
      code: "FR",
      flag: "https://media.api-sports.io/flags/fr.svg",
    },
    seasons: [{ season: 2026, current: true }],
  };
  const team = (n: number) => ({ id: n, name: `Team ${n}`, logo: null });
  const games = Array.from({ length: 7 }, (_, i) => ({
    id: id * 100 + i,
    date: `2026-10-${String(i + 1).padStart(2, "0")}T08:00:00Z`,
    league,
    teams: { home: team(id * 10), away: team(id * 10 + 1) },
    status: { short: i === 6 ? "NS" : "FT" },
    scores: { home: 2, away: 1 },
    periods: { first: "1-0", second: "1-0", third: "0-1" },
  }));
  const row = {
    league,
    team: team(id * 10),
    position: 1,
    stage: "Regular Season",
    group: { name: "East" },
    games: {
      played: 6,
      win: { total: 6 },
      win_overtime: { total: 0 },
      lose: { total: 0 },
      lose_overtime: { total: 0 },
    },
    points: 18,
  };
  return {
    leagueId: id,
    leagues: envelope([league]),
    games: envelope(games),
    standings: envelope([[row]]),
  };
}
Deno.test("all seven leagues publish atomically with 21 calls, no standings timezone and no future form", async () => {
  let published: unknown;
  const queries: { path: string; params: Record<string, string> }[] = [];
  const result = await collectHockey(
    {
      request: (path, params) => {
        queries.push({ path, params });
        const r = raw(Number(params.id ?? params.league));
        return Promise.resolve(
          path === "leagues"
            ? r.leagues
            : path === "games"
            ? r.games
            : r.standings,
        );
      },
      saveRaw: () => Promise.resolve(),
      publish: (p) => {
        published = p;
        return Promise.resolve();
      },
    },
    now,
    "test",
  );
  assert.equal(result.competitions?.length, 7);
  assert.equal(queries.length, 21);
  assert.equal(result.competitions![0].countryCode, "FR");
  assert.equal(
    result.competitions![0].countryFlagUrl,
    "https://media.api-sports.io/flags/fr.svg",
  );
  assert.deepEqual(published, result);
  assert.ok(
    queries.filter((q) => q.path === "standings").every((q) =>
      !("timezone" in q.params)
    ),
  );
  for (const game of result.items) {
    for (const form of [...game.recentForm!.home, ...game.recentForm!.away]) {
      assert.ok(form.startsAt < game.startsAt);
      assert.ok(form.startsAt < now.toISOString());
      assert.notEqual(form.id, game.id);
    }
  }
  const altered = raw(57);
  altered.standings.response[0][0].stage = "NHL - Pre-season";
  const mixed = compactHockeyCollection([altered], now, "test");
  assert.equal(mixed.competitions![0].formPhaseVerified, false);
  assert.deepEqual(mixed.items[0].recentForm, { home: [], away: [] });
});
Deno.test("failure in any competition cannot replace the last complete seven-league publication", async () => {
  let published = false;
  await assert.rejects(() =>
    collectHockey(
      {
        request: (path, params) => {
          if (params.league === "47" && path === "standings") {
            return Promise.resolve({
              errors: { requests: "rate limit" },
              results: 0,
              response: [],
            });
          }
          const r = raw(Number(params.id ?? params.league));
          return Promise.resolve(
            path === "leagues"
              ? r.leagues
              : path === "games"
              ? r.games
              : r.standings,
          );
        },
        saveRaw: () => Promise.resolve(),
        publish: () => {
          published = true;
          return Promise.resolve();
        },
      },
      now,
      "test",
    )
  );
  assert.equal(published, false);
  assert.throws(() =>
    compactHockeyCollection([raw(57), raw(57)], now, "duplicate")
  );
  assert.equal(hockeyLeagueIds.length, 7);
});

Deno.test("official points, rank and optional goals survive standings compaction", () => {
  const source = raw(35);
  Object.assign(source.standings.response[0][0], {
    goals: { for: 31, against: 20 },
    description: " Playoffs ",
    points: 17,
  });
  const compact = compactHockeyCollection([source], now, "points");
  const row = compact.competitions![0].tables[0].rows[0];
  assert.equal(row.points, 17);
  assert.equal(row.rank, 1);
  assert.equal(row.goalsFor, 31);
  assert.equal(row.goalsAgainst, 20);
  assert.equal(row.description, "Playoffs");
  const absent =
    compactHockeyCollection([raw(35)], now, "missing").competitions![0]
      .tables[0].rows[0];
  assert.equal(absent.goalsFor, null);
  assert.equal(absent.goalsAgainst, null);
});

Deno.test("team radar keeps completed season history while fixture form stays five", () => {
  const r = raw(35);
  const template = r.games.response[0];
  r.games = envelope(Array.from({ length: 13 }, (_, i) => ({
    ...template,
    id: 3500 + i,
    date: `2026-09-${String(i + 1).padStart(2, "0")}T08:00:00Z`,
    status: { short: i === 12 ? "P2" : "FT" },
  })));
  r.games.response.push({
    ...template,
    id: 3599,
    date: "2026-10-05T08:00:00Z",
    status: { short: "NS" },
  });
  r.games.results = r.games.response.length;
  const p = compactHockeyCollection([r], now, "history");
  const row = p.competitions![0].tables[0].rows[0];
  assert.equal(row.formHistory!.length, 12);
  assert.equal(row.form.length, 5);
  assert.equal(p.items[0].recentForm!.home.length, 5);
  assert.deepEqual(row.formHistory!.slice(-5), row.form);
  assert.ok(
    row.formHistory!.every((g) =>
      g.providerStatus === "FT" && g.startsAt < now.toISOString()
    ),
  );
  assert.equal(new Set(row.formHistory!.map((g) => g.id)).size, 12);
  r.standings.response[0][0].stage = "Pre-season";
  const mixed = compactHockeyCollection([r], now, "unverified");
  assert.deepEqual(mixed.competitions![0].tables.flatMap((t) => t.rows), []);
});
