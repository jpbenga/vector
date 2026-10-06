import assert from "node:assert/strict";
import { calculateHockeyVenueStandings } from "./hockey_venue_standings.ts";
import {
  type PublicCompetition,
  type PublicFixture,
  type PublicStanding,
} from "./hockey_feed.ts";

const team = (id: string) => ({ id, name: `Team ${id}`, logoUrl: null });
function game(
  id: number,
  league = "57",
  status = "FT",
  swap = false,
): PublicFixture {
  return {
    id: String(id),
    competitionId: league,
    competitionName: "League",
    season: "2026",
    home: team(swap ? "2" : "1"),
    away: team(swap ? "1" : "2"),
    startsAt: `2026-10-0${id}T10:00:00Z`,
    calendarDate: `2026-10-0${id}`,
    status: "finished",
    providerStatus: status,
    scores: { final: { home: 3, away: 2 } },
  };
}
function competition(league = "57", three = false): PublicCompetition {
  const rows: PublicStanding[] = [
    {
      team: team("1"),
      rank: 1,
      played: 3,
      points: three ? 6 : 5,
      wins: 1,
      overtimeWins: 1,
      losses: 0,
      overtimeLosses: 1,
      goalsFor: 8,
      goalsAgainst: 7,
      form: [],
    },
    {
      team: team("2"),
      rank: 2,
      played: 3,
      points: 3,
      wins: 0,
      overtimeWins: 1,
      losses: 1,
      overtimeLosses: 1,
      goalsFor: 7,
      goalsAgainst: 8,
      form: [],
    },
  ];
  return {
    id: league,
    name: "League",
    season: "2026",
    logoUrl: null,
    country: "Country",
    formPhaseVerified: true,
    tables: [{ stage: "Regular Season", group: "General", rows }],
  };
}
const at = "2026-10-05T00:00:00Z";
const games = (
  league = "57",
) => [game(1, league), game(2, league, "AOT"), game(3, league, "AP", true)];

Deno.test("venue points distinguish regulation, overtime and shootout for all supported leagues", () => {
  for (const league of ["57", "58", "35", "10", "18", "16", "47"]) {
    const three = ["10", "18", "16", "47"].includes(league);
    // AHL regular-season window starts October 2: shift the same sequence.
    const input = games(league).map((g, i) => ({
      ...g,
      startsAt: `2026-10-0${i + 2}T10:00:00Z`,
      calendarDate: `2026-10-0${i + 2}`,
    }));
    const c = competition(league, three),
      result = calculateHockeyVenueStandings(c, input, at);
    assert.equal(result.status, "reconciled");
    const h = result.home.find((r) => r.team.id === "1")!;
    const a = result.away.find((r) => r.team.id === "1")!;
    assert.equal(h.points, three ? 5 : 4);
    assert.equal(a.points, 1);
    assert.equal(h.overtimeWins, 1);
    assert.equal(a.overtimeLosses, 1);
    for (const official of c.tables[0].rows) {
      const home = result.home.find((r) => r.team.id === official.team.id)!;
      const away = result.away.find((r) => r.team.id === official.team.id)!;
      assert.equal(home.points + away.points, official.points);
      assert.equal(home.played + away.played, official.played);
      assert.equal(home.goalsFor + away.goalsFor, official.goalsFor);
    }
    assert.equal(result.home[0].team.id, "1");
    assert.equal(result.away[0].team.id, "1");
  }
});
Deno.test("late games do not alter reconciled official venue totals; preseason, live and future games are excluded", () => {
  const c = competition(),
    old = game(4),
    future = { ...game(5), startsAt: "2026-10-06T10:00:00Z" };
  const pre = {
    ...game(6),
    startsAt: "2026-09-20T10:00:00Z",
    calendarDate: "2026-09-20",
  };
  const live = { ...game(7), status: "live" };
  const result = calculateHockeyVenueStandings(c, [
    ...games(),
    old,
    future,
    pre,
    live,
  ], at);
  assert.equal(result.status, "reconciled");
  assert.equal(result.home.reduce((n, r) => n + r.played, 0), 3);
});
Deno.test("missing results or adjusted official points make coverage partial; unknown seasons never default to NHL", () => {
  const c = competition();
  const partial = calculateHockeyVenueStandings(c, games().slice(0, 2), at);
  assert.equal(partial.status, "partial");
  assert.deepEqual(partial.unavailableTeams, ["1", "2"]);
  c.tables[0].rows[0].points--;
  assert.equal(calculateHockeyVenueStandings(c, games(), at).status, "partial");
  c.season = "2027";
  const unknown = calculateHockeyVenueStandings(c, [], at);
  assert.equal(unknown.status, "unsupported");
  assert.deepEqual(unknown.home, []);
});
Deno.test("duplicate games and crossed league/season cannot become a venue table", () => {
  assert.throws(
    () =>
      calculateHockeyVenueStandings(competition(), [...games(), game(1)], at),
    /Duplicate/,
  );
  assert.throws(
    () => calculateHockeyVenueStandings(competition(), games("47"), at),
    /Crossed/,
  );
});
Deno.test("conference/division duplicates are not summed and contradictory copies cannot claim reconciliation", () => {
  const c = competition();
  c.tables.push({
    ...c.tables[0],
    group: "Division",
    rows: structuredClone(c.tables[0].rows),
  });
  assert.equal(calculateHockeyVenueStandings(c, games(), at).home.length, 2);
  c.tables[1].rows[0].points++;
  assert.equal(calculateHockeyVenueStandings(c, games(), at).status, "partial");
});
