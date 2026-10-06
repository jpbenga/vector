import assert from "node:assert/strict";
import { compactHockeyGames, type SportPublication } from "./hockey_feed.ts";
import {
  enrichHockeyPlayers,
  hockeyContributions,
} from "./hockey_player_radar.ts";
import type { HockeyMeeting } from "./hockey_enrichment.ts";
const now = new Date("2026-10-04T10:00:00Z");
const envelope = (response: unknown[]) => ({
  errors: [],
  results: response.length,
  response,
});
const team = (id: number) => ({ id, name: `Team ${id}`, logo: null });
const raw = (id: number, status = "FT") => ({
  id,
  date: `2026-10-0${id}T08:00:00Z`,
  league: { id: 35, name: "KHL", season: 2026 },
  teams: { home: team(1), away: team(2) },
  status: { short: status },
  scores: { home: status === "AP" ? 3 : 2, away: 1 },
  periods: { first: "1-0", second: "1-1", third: "0-0" },
  events: true,
});
const games = compactHockeyGames(envelope([raw(1), raw(2), raw(3)]), {
  season: "2026",
  capturedAt: now.toISOString(),
  collectionId: "test",
  timezone: "Europe/Paris",
  windowStart: "2026-10-01",
  windowEnd: "2026-10-17",
}, 35);
const events = (gameId: number) =>
  envelope([
    {
      game_id: gameId,
      period: "P1",
      minute: "05",
      team: team(1),
      type: "goal",
      players: ["A. Player"],
      assists: ["B. Player"],
    },
    {
      game_id: gameId,
      period: "P2",
      minute: "05",
      team: team(1),
      type: "goal",
      players: ["C. Player"],
      assists: [],
    },
    {
      game_id: gameId,
      period: "P2",
      minute: "06",
      team: team(2),
      type: "goal",
      players: ["A. Player"],
      assists: [],
    },
  ]);
function publication(): SportPublication {
  return {
    ...games,
    competitions: [{
      id: "35",
      name: "KHL",
      season: "2026",
      logoUrl: null,
      country: "Russia",
      formPhaseVerified: true,
      tables: [{
        stage: "Regular Season",
        group: "East",
        rows: [1, 2].map((id) => ({
          team: { id: String(id), name: `Team ${id}`, logoUrl: null },
          rank: id,
          played: 3,
          points: 3,
          wins: 3,
          losses: 0,
          overtimeWins: 0,
          overtimeLosses: 0,
          form: games.items.map((g) => ({
            id: g.id,
            startsAt: g.startsAt,
            opponent: id === 1 ? "Team 2" : "Team 1",
            home: id === 1,
            scored: id === 1 ? 2 : 1,
            conceded: id === 1 ? 1 : 2,
            outcome: id === 1 ? "win" as const : "loss" as const,
            providerStatus: "FT",
          })),
        })),
      }],
    }],
  };
}
Deno.test("player collection uses three team games, shared game cache and team-scoped event names", async () => {
  const calls: string[] = [];
  const result = await enrichHockeyPlayers(
    publication(),
    new Map([["35", envelope([raw(1), raw(2), raw(3)])]]),
    {
      request: (_path, p) => {
        calls.push(p.game);
        return Promise.resolve(events(Number(p.game)));
      },
    },
    now,
  );
  assert.deepEqual(calls, ["1", "2", "3"]);
  assert.equal(result.playerRadar!.profiles.length, 4);
  assert.equal(
    result.playerRadar!.coverage.filter((c) => c.status === "complete").length,
    2,
  );
  const sameNames = result.playerRadar!.profiles.filter((p) =>
    p.name === "A. Player"
  );
  assert.notEqual(sameNames[0].id, sameNames[1].id);
  assert.deepEqual(sameNames[0].activity.map((m) => m.goals), [1, 1, 1]);
  assert.deepEqual(
    result.playerRadar!.profiles.find((p) => p.name === "B. Player")!.activity
      .map((m) => m.assists),
    [1, 1, 1],
  );
});
Deno.test("missing scorers or incomplete goal ledger exclude teams instead of inventing zero contributions", async () => {
  for (
    const incomplete of [
      envelope([]),
      envelope(
        (events(1).response as Record<string, unknown>[]).map((e) => ({
          ...e,
          players: [],
        })),
      ),
    ]
  ) {
    const result = await enrichHockeyPlayers(
      publication(),
      new Map([["35", envelope([raw(1), raw(2), raw(3)])]]),
      {
        request: () => Promise.resolve(incomplete),
      },
      now,
    );
    assert.equal(result.playerRadar!.profiles.length, 0);
    assert.ok(
      result.playerRadar!.coverage.every((c) =>
        c.status === "incomplete_events"
      ),
    );
  }
});
Deno.test("unavailable events and unverified phases cannot feed player radar", async () => {
  const p = publication();
  p.competitions![0].formPhaseVerified = false;
  const result = await enrichHockeyPlayers(
    p,
    new Map([["35", envelope([raw(1), raw(2), raw(3)])]]),
    {
      request: () => {
        throw new Error("must not request preseason");
      },
    },
    now,
  );
  assert.equal(result.playerRadar!.profiles.length, 0);
  const absent = await enrichHockeyPlayers(
    publication(),
    new Map([[
      "35",
      envelope([1, 2, 3].map((i) => ({ ...raw(i), events: false }))),
    ]]),
    {
      request: () => {
        throw new Error("no events advertised");
      },
    },
    now,
  );
  assert.equal(absent.playerRadar!.profiles.length, 0);
  assert.ok(
    absent.playerRadar!.coverage.every((c) =>
      c.status === "events_unavailable"
    ),
  );
});
Deno.test("shootout deciding score does not count as a player goal and crossed event identities are rejected", () => {
  const game = {
    ...games.items[0],
    providerStatus: "AP",
    scores: { ...games.items[0].scores, final: { home: 3, away: 1 } },
    events: [],
    eventsCollected: true,
  } as HockeyMeeting;
  assert.ok(hockeyContributions(events(1), game));
  assert.equal(
    hockeyContributions(events(1), { ...game, providerStatus: "FT" }),
    null,
  );
  assert.throws(() => hockeyContributions(events(2), game));
});

Deno.test("provider errors cannot replace the existing player publication with empty data", async () => {
  const original = publication();
  const unchanged = structuredClone(original);
  await assert.rejects(
    enrichHockeyPlayers(
      original,
      new Map([["35", envelope([raw(1), raw(2), raw(3)])]]),
      {
        request: () =>
          Promise.resolve({
            errors: { rateLimit: "limit" },
            results: 0,
            response: [],
          }),
      },
      now,
    ),
  );
  assert.deepEqual(original, unchanged);
});

function seasonPublication() {
  const later = new Date("2026-10-07T10:00:00Z");
  const rawSeason = envelope([1, 2, 3, 4, 5, 6].map((id) => raw(id)));
  const full = compactHockeyGames(rawSeason, {
    season: "2026",
    capturedAt: later.toISOString(),
    collectionId: "season",
    timezone: "Europe/Paris",
    windowStart: "2026-10-01",
    windowEnd: "2026-10-17",
  }, 35);
  const p = publication();
  p.capturedAt = later.toISOString();
  for (const row of p.competitions![0].tables[0].rows) {
    row.form = full.items.slice(-5).map((game) => ({
      id: game.id,
      startsAt: game.startsAt,
      opponent: row.team.id === "1" ? "Team 2" : "Team 1",
      home: row.team.id === "1",
      scored: row.team.id === "1" ? 2 : 1,
      conceded: row.team.id === "1" ? 1 : 2,
      outcome: row.team.id === "1" ? "win" as const : "loss" as const,
      providerStatus: "FT",
    }));
  }
  return { later, rawSeason, p };
}

Deno.test("full collected season survives beyond the five-game form window; opponents share one ledger per game", async () => {
  const { later, rawSeason, p } = seasonPublication();
  const calls: string[] = [];
  const result = await enrichHockeyPlayers(p, new Map([["35", rawSeason]]), {
    request: (_path, parameters) => {
      calls.push(parameters.game);
      return Promise.resolve(events(Number(parameters.game)));
    },
  }, later);
  assert.deepEqual(calls, ["4", "5", "6", "1", "2", "3"]);
  assert.equal(new Set(calls).size, 6);
  assert.deepEqual(result.playerRadar!.profiles[0].activity.map((r) => r.id), [
    "1",
    "2",
    "3",
    "4",
    "5",
    "6",
  ]);
  assert.equal(result.playerRadar!.coverage[0].history!.length, 6);
  assert.equal(
    result.playerRadar!.profiles[0].activity.filter((r) => r.goals === 1)
      .length,
    6,
  );
});

Deno.test("unavailable older contributions remain unknown and do not invalidate the verified recent window", async () => {
  const { later, rawSeason, p } = seasonPublication();
  const result = await enrichHockeyPlayers(p, new Map([["35", rawSeason]]), {
    request: (_path, parameters) =>
      Promise.resolve(
        parameters.game === "3"
          ? envelope([])
          : events(Number(parameters.game)),
      ),
  }, later);
  assert.ok(result.playerRadar!.coverage.every((c) => c.status === "complete"));
  for (const profile of result.playerRadar!.profiles) {
    assert.equal(profile.activity[2].goals, null);
    assert.equal(profile.activity[2].assists, null);
    assert.ok(
      profile.activity.slice(-3).every((r) =>
        r.goals !== null && r.assists !== null
      ),
    );
  }
});

Deno.test("older available games never replace an incomplete latest game to qualify a player", async () => {
  const { later, rawSeason, p } = seasonPublication();
  const result = await enrichHockeyPlayers(p, new Map([["35", rawSeason]]), {
    request: (_path, parameters) =>
      Promise.resolve(
        parameters.game === "6"
          ? envelope([])
          : events(Number(parameters.game)),
      ),
  }, later);
  assert.equal(result.playerRadar!.profiles.length, 0);
  assert.ok(
    result.playerRadar!.coverage.every((c) => c.status === "incomplete_events"),
  );
});
