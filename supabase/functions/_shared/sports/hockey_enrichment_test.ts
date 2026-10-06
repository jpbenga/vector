import assert from "node:assert/strict";
import {
  compactHockeyEvents,
  compactHockeyHistory,
  compactVenueStatistics,
  enrichHockeyPublication,
  hockeyMeetingKind,
  selectHockeyHistory,
} from "./hockey_enrichment.ts";
import { type PublicFixture, type SportPublication } from "./hockey_feed.ts";
const now = new Date("2026-10-04T10:00:00Z");
const team = (id: number) => ({
  id: String(id),
  name: `Team ${id}`,
  logoUrl: null,
});
const fixture: PublicFixture = {
  id: "999",
  competitionId: "57",
  competitionName: "NHL",
  season: "2026",
  home: team(1),
  away: team(2),
  startsAt: "2026-10-06T10:00:00Z",
  calendarDate: "2026-10-06",
  status: "scheduled",
  providerStatus: "NS",
  scores: {},
};
const envelope = (response: unknown[]) => ({
  errors: [],
  results: response.length,
  response,
});
function game(id = 100, date = "2026-10-01T10:00:00Z", league = 57) {
  return {
    id,
    date,
    league: { id: league, season: 2026, name: "League" },
    teams: {
      home: { id: 1, name: "One", logo: null },
      away: { id: 2, name: "Two", logo: null },
    },
    status: { short: "AOT" },
    scores: { home: 2, away: 3 },
    periods: { first: "1-0", second: "0-1", third: "1-1", overtime: "0-1" },
    events: true,
  };
}
function statistics() {
  return {
    errors: [],
    results: 5,
    response: {
      league: { id: 57, season: 2026 },
      team: { id: 1 },
      games: {
        played: { home: 2, away: 0 },
        wins: { home: { total: 1 }, away: { total: 0 } },
        loses: { home: { total: 1 }, away: { total: 0 } },
      },
      goals: {
        for: { total: { home: 5, away: 0 } },
        against: { total: { home: 6, away: 0 } },
      },
    },
  };
}
Deno.test("venue aggregates preserve provider wins and goals without inventing NHL points or overtime splits", () => {
  const rows = compactVenueStatistics(statistics(), "57", "2026", team(1))!;
  assert.equal(rows.home.played, 2);
  assert.equal(rows.home.wins, 1);
  assert.equal(rows.home.goalsAgainst, 6);
  assert.equal(rows.away.played, 0);
  assert.ok(!("points" in rows.home));
  assert.equal(
    compactVenueStatistics(envelope([]), "57", "2026", team(1)),
    null,
  );
  assert.throws(() =>
    compactVenueStatistics(statistics(), "47", "2026", team(1))
  );
  assert.throws(() =>
    compactVenueStatistics(
      { ...statistics(), errors: { requests: "rate limit" } },
      "57",
      "2026",
      team(1),
    )
  );
});
Deno.test("history excludes future, current and too-old games, keeps both venue directions and independent six-match scopes", () => {
  const history = compactHockeyHistory(
    envelope([
      ...Array.from(
        { length: 10 },
        (_, i) =>
          game(100 + i, `2026-01-${String(i + 1).padStart(2, "0")}T10:00:00Z`),
      ),
      ...Array.from({ length: 6 }, (_, i) =>
        game(
          200 + i,
          `2026-09-${String(i + 15).padStart(2, "0")}T10:00:00Z`,
          58,
        )),
      game(999, "2026-10-06T10:00:00Z"),
      game(300, "2022-10-01T10:00:00Z"),
    ]),
    ["1", "2"],
    now,
  );
  const selected = selectHockeyHistory(history, fixture, now);
  assert.equal(selected.length, 12);
  assert.equal(selected.filter((g) => g.competitionId === "57").length, 6);
  assert.ok(!selected.some((g) => g.id === "999" || g.id === "300"));
  assert.equal(selected[0].scores.regulation.home, 2);
  assert.equal(selected[0].scores.final.away, 3);
  assert.throws(() =>
    compactHockeyHistory(envelope([game()]), ["1", "7"], now)
  );
  assert.throws(() =>
    compactHockeyHistory(envelope([game(), game()]), ["1", "2"], now)
  );
});
Deno.test("hockey event clocks use period offsets and never turn a missing minute into minute zero", () => {
  const match = compactHockeyHistory(envelope([game()]), ["1", "2"], now)[0];
  const event = {
    game_id: 100,
    team: { id: 1 },
    period: "P2",
    minute: "01",
    type: "goal",
    players: ["Player"],
    assists: [],
    comment: null,
  };
  const events = compactHockeyEvents(
    envelope([event, { ...event, period: "P3", minute: null }, {
      ...event,
      period: "OT",
      minute: "08",
    }]),
    match,
  );
  assert.equal(events[0].elapsed, 21);
  assert.equal(events[1].elapsed, null);
  assert.equal(events[1].minute, null);
  assert.equal(events[2].elapsed, 68);
  assert.throws(() =>
    compactHockeyEvents(envelope([{ ...event, game_id: 101 }]), match)
  );
  assert.throws(() =>
    compactHockeyEvents(envelope([{ ...event, team: { id: 7 } }]), match)
  );
});
Deno.test("enrichment deduplicates unordered pairs, ignores absent event coverage, and leaves input unchanged on a rejected request", async () => {
  const input: SportPublication = {
    schemaVersion: 1,
    sport: "hockey",
    provider: "api-hockey",
    competitionId: "multi",
    season: "multi",
    capturedAt: now.toISOString(),
    collectionId: "test",
    windowStart: "2026-10-01",
    windowEnd: "2026-10-17",
    timezone: "Europe/Paris",
    items: [fixture, {
      ...fixture,
      id: "998",
      home: fixture.away,
      away: fixture.home,
    }],
  };
  const calls: string[] = [];
  const output = await enrichHockeyPublication(input, {
    request: async (path) => {
      calls.push(path);
      return path === "games/h2h"
        ? envelope([game(), { ...game(101), events: false }])
        : envelope([]);
    },
  }, now);
  assert.deepEqual(calls, ["games/h2h", "games/events"]);
  assert.ok(!("headToHead" in input.items[0]));
  const h = output.items[0] as typeof fixture & {
    headToHead: { meetings: { eventsCollected: boolean }[] };
  };
  assert.equal(h.headToHead.meetings.length, 2);
  assert.equal(h.headToHead.meetings[0].eventsCollected, true);
  assert.equal(h.headToHead.meetings[1].eventsCollected, false);
  await assert.rejects(() =>
    enrichHockeyPublication(input, {
      request: () =>
        Promise.resolve({
          errors: { requests: "quota" },
          results: 0,
          response: [],
        }),
    }, now)
  );
  assert.ok(!("headToHead" in input.items[0]));
});
Deno.test("inconsistent optional events stay quarantined while the real score remains usable", async () => {
  const pub: SportPublication = {
    schemaVersion: 1,
    sport: "hockey",
    provider: "api-hockey",
    competitionId: "57",
    season: "2026",
    capturedAt: now.toISOString(),
    collectionId: "test",
    windowStart: "2026-10-01",
    windowEnd: "2026-10-17",
    timezone: "Europe/Paris",
    items: [fixture],
  };
  const output = await enrichHockeyPublication(pub, {
    request: (path) =>
      Promise.resolve(
        path === "games/h2h" ? envelope([game()]) : envelope([{
          game_id: 100,
          team: { id: 7 },
          period: "P1",
          minute: "02",
          type: "goal",
          players: [],
          assists: [],
        }]),
      ),
  }, now);
  const history = (output.items[0] as typeof fixture & {
    headToHead: {
      meetings: {
        scores: { final: { home: number; away: number } };
        events: unknown[];
        eventsCollected: boolean;
        eventDataIssue?: string;
      }[];
    };
  }).headToHead;
  assert.deepEqual(history.meetings[0].scores.final, { home: 2, away: 3 });
  assert.deepEqual(history.meetings[0].events, []);
  assert.equal(history.meetings[0].eventsCollected, false);
  assert.equal(history.meetings[0].eventDataIssue, "identity_or_clock");
});

Deno.test("selected finished game retains its own events without including them in its prematch history", async () => {
  const finished = compactHockeyHistory(envelope([game()]), ["1", "2"], now)[0];
  const pub: SportPublication = {
    schemaVersion: 1,
    sport: "hockey",
    provider: "api-hockey",
    competitionId: "57",
    season: "2026",
    capturedAt: now.toISOString(),
    collectionId: "test",
    windowStart: "2026-10-01",
    windowEnd: "2026-10-17",
    timezone: "Europe/Paris",
    items: [finished],
  };
  const calls: string[] = [];
  const output = await enrichHockeyPublication(pub, {
    request: async (path) => {
      calls.push(path);
      return path === "games/h2h" ? envelope([game()]) : envelope([{
        game_id: 100,
        team: { id: 1 },
        period: "P2",
        minute: "02",
        type: "goal",
        players: ["Player"],
        assists: [],
      }]);
    },
  }, now);
  const enriched = output.items[0] as typeof finished & {
    matchEvents: { events: { teamId: string; elapsed: number }[] };
    headToHead: { meetings: unknown[] };
  };
  assert.deepEqual(calls, ["games/h2h", "games/events"]);
  assert.equal(enriched.matchEvents.events[0].elapsed, 22);
  assert.equal(enriched.matchEvents.events[0].teamId, "1");
  assert.equal(enriched.headToHead.meetings.length, 0);
  assert.ok(!("matchEvents" in pub.items[0]));
});

Deno.test("three-year H2H sampling excludes friendlies and preserves both official scopes", () => {
  const oldLeague = [1, 2, 3].map((i) => ({
    ...game(i, `2025-01-0${i}T10:00:00Z`),
    league: { id: 57, season: 2024, name: "NHL" },
  }));
  const cups = [4, 5, 6, 7, 8, 9, 10].map((i) => ({
    ...game(i, `2026-09-${String(i).padStart(2, "0")}T10:00:00Z`),
    league: {
      id: 99,
      season: 2026,
      name: "Champions Hockey League",
      type: "Cup",
    },
  }));
  const friendly = {
    ...game(100, "2026-10-01T10:00:00Z"),
    league: { id: 57, season: 2026, name: "NHL Pre-Season" },
  };
  const selected = selectHockeyHistory(
    compactHockeyHistory(envelope([...oldLeague, ...cups, friendly]), [
      "1",
      "2",
    ], now),
    fixture,
    now,
  );
  assert.equal(
    selected.filter((g) => g.competitionKind === "league").length,
    3,
  );
  assert.equal(selected.filter((g) => g.competitionKind === "cup").length, 6);
  assert.ok(selected.every((g) => g.id !== "100"));
});

Deno.test("client and collector share verified phase scenarios, including legacy NHL preseason", () => {
  const cases = JSON.parse(
    Deno.readTextFileSync(
      new URL(
        "../../../../test/fixtures/sports/hockey_meeting_phases.json",
        import.meta.url,
      ),
    ),
  );
  for (const c of cases) {
    assert.equal(
      hockeyMeetingKind(
        { name: c.name, stage: c.phase },
        c.id,
        c.date,
        c.declared,
      ),
      c.expected,
      JSON.stringify(c),
    );
  }
});
