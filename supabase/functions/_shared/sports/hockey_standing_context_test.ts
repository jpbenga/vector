import assert from "node:assert/strict";
import { calculateHockeyStandingContext } from "./hockey_standing_context.ts";
import type {
  PublicCompetition,
  PublicFixture,
  PublicStanding,
} from "./hockey_feed.ts";
const at = "2026-10-06T00:00:00Z";
const team = (id: number) => ({
  id: String(id),
  name: `Team ${id}`,
  logoUrl: null,
});
function sample(league = "57", three = false) {
  const rows: PublicStanding[] = [
    {
      team: team(1),
      rank: 1,
      played: 2,
      points: three ? 5 : 4,
      wins: 1,
      losses: 0,
      overtimeWins: 1,
      overtimeLosses: 0,
      goalsFor: 5,
      goalsAgainst: 2,
      form: [],
    },
    {
      team: team(2),
      rank: 2,
      played: 2,
      points: 0,
      wins: 0,
      losses: 2,
      overtimeWins: 0,
      overtimeLosses: 0,
      goalsFor: 3,
      goalsAgainst: 7,
      form: [],
    },
    {
      team: team(3),
      rank: 1,
      played: 2,
      points: 3,
      wins: 0,
      losses: 0,
      overtimeWins: 1,
      overtimeLosses: 1,
      goalsFor: 3,
      goalsAgainst: 3,
      form: [],
    },
    {
      team: team(4),
      rank: 2,
      played: 2,
      points: three ? 4 : 3,
      wins: 1,
      losses: 0,
      overtimeWins: 0,
      overtimeLosses: 1,
      goalsFor: 5,
      goalsAgainst: 4,
      form: [],
    },
  ];
  const c: PublicCompetition = {
    id: league,
    name: "League",
    season: "2026",
    logoUrl: null,
    country: "Country",
    formPhaseVerified: true,
    tables: [
      { stage: "Regular Season", group: "Western Conference", rows },
      {
        stage: "Regular Season",
        group: "Pacific Division",
        rows: rows.slice(0, 2),
      },
      {
        stage: "Regular Season",
        group: "Central Division",
        rows: rows.slice(2),
      },
    ],
  };
  function game(
    id: number,
    home: number,
    away: number,
    h: number,
    a: number,
    status = "FT",
  ): PublicFixture {
    return {
      id: String(id),
      competitionId: league,
      competitionName: "League",
      season: "2026",
      home: team(home),
      away: team(away),
      startsAt: `2026-10-0${id}T10:00:00Z`,
      calendarDate: `2026-10-0${id}`,
      status: "finished",
      providerStatus: status,
      scores: { final: { home: h, away: a } },
    };
  }
  return {
    c,
    games: [
      game(1, 1, 2, 3, 1),
      game(2, 1, 3, 2, 1, "AOT"),
      game(3, 4, 2, 4, 2),
      game(4, 3, 4, 2, 1, "AP"),
    ],
  };
}
Deno.test("inter-division results exclude intra-group games and count each group-side once", () => {
  const { c, games } = sample(),
    { standingContext, venueStandings } = calculateHockeyStandingContext(
      c,
      games,
      at,
    );
  assert.equal(venueStandings.status, "reconciled");
  assert.equal(standingContext.maximumPoints, 2);
  const [conference, pacific, central] = standingContext.groups;
  assert.equal(conference.kind, "conference");
  assert.equal(conference.all!.played, 0);
  assert.equal(pacific.parentTableIndex, 0);
  assert.equal(pacific.kind, "division");
  assert.deepEqual(pacific.all, {
    played: 2,
    points: 2,
    goalsFor: 4,
    goalsAgainst: 5,
  });
  assert.equal(pacific.home!.points, 2);
  assert.equal(pacific.away!.points, 0);
  assert.equal(central.all!.played, 2);
  assert.equal(central.all!.points, 3);
  assert.equal(
    central.home!.points + central.away!.points,
    central.all!.points,
  );
});
Deno.test("three-point leagues use their regulation barème while overtime remains 2/1", () => {
  const { c, games } = sample("47", true),
    { standingContext } = calculateHockeyStandingContext(c, games, at);
  assert.equal(standingContext.maximumPoints, 3);
  assert.equal(standingContext.groups[1].all!.points, 2);
  assert.equal(standingContext.groups[2].all!.points, 4);
});
Deno.test("partial, unsupported and contradictory standings publish no inter-group comparison", () => {
  const { c, games } = sample();
  assert.equal(
    calculateHockeyStandingContext(c, games.slice(1), at).standingContext
      .groups[1].all,
    null,
  );
  c.season = "2027";
  const unknown = calculateHockeyStandingContext(c, [], at).standingContext;
  assert.equal(unknown.maximumPoints, null);
  assert.equal(unknown.groups[1].all, null);
  c.season = "2026";
  c.tables[1].rows = structuredClone(c.tables[1].rows);
  c.tables[1].rows[0].points++;
  assert.equal(
    calculateHockeyStandingContext(c, games, at).standingContext.groups[1].all,
    null,
  );
});
Deno.test("hierarchy derives named divisions by membership and does not guess absent conferences", () => {
  const { c, games } = sample();
  c.tables[1].group = "Bobrov";
  c.tables[2].group = "Tarasov";
  const result = calculateHockeyStandingContext(c, games, at).standingContext;
  assert.equal(result.groups[1].kind, "division");
  assert.equal(result.groups[2].parentTableIndex, 0);
  c.tables.shift();
  c.tables[0].group = "Atlantic Division";
  c.tables[1].group = "Central Division";
  const flat = calculateHockeyStandingContext(c, games, at).standingContext;
  assert.deepEqual(flat.groups.map((g) => g.parentTableIndex), [null, null]);
});
Deno.test("unplayed or live games and standings lag never enter group comparisons", () => {
  const { c, games } = sample();
  const newer = { ...games[1], id: "99", startsAt: "2026-10-05T00:00:00Z" };
  const live = { ...games[2], id: "100", status: "live" };
  const result = calculateHockeyStandingContext(c, [...games, newer, live], at)
    .standingContext;
  assert.equal(result.groups[1].all!.played, 2);
  assert.throws(
    () => calculateHockeyStandingContext(c, [...games, games[0]], at),
    /Duplicate/,
  );
});

Deno.test("league/conference/division levels stay distinct and overlapping peers publish no rates", () => {
  const { c, games } = sample();
  const league = { ...c.tables[0], group: "General" };
  c.tables.unshift(league);
  const result = calculateHockeyStandingContext(c, games, at).standingContext;
  assert.deepEqual(result.groups.map((g) => g.kind), [
    "league",
    "conference",
    "division",
    "division",
  ]);
  c.tables.push({
    stage: "Regular Season",
    group: "Overlapping Division",
    rows: c.tables[0].rows.slice(0, 3),
  });
  const invalid = calculateHockeyStandingContext(c, games, at).standingContext;
  assert.equal(invalid.groups[2].all, null);
  assert.equal(invalid.groups[4].all, null);
});
