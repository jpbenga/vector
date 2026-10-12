import { strict as assert } from "node:assert";
import {
  buildEuropeanComparisons,
  resolveEuropeanDomesticContexts,
} from "./european_fixture_comparison.ts";
// Deliberately synthetic contracts; never published as application data.
const at = "2026-10-13T19:00:00Z";
const team = (id: number) => ({ id, name: `Team ${id}`, logo: null });
const fixture = (
  id: number,
  league = 2,
  season = 2026,
  date = "2026-10-01T18:00:00Z",
  home = 1,
  away = 9,
  h = 2,
  a = 0,
  round = "League Stage - 1",
) => ({
  fixture: { id, date, status: { short: "FT" } },
  league: { id: league, name: `League ${league}`, season, round },
  teams: { home: team(home), away: team(away) },
  goals: { home: h, away: a },
});
const standing = (
  teamId: number,
  id: number,
  season: number,
  observed_at = "2026-10-12T09:00:00Z",
) => ({
  observed_at,
  league: {
    id,
    name: `League ${id}`,
    country: "Portugal",
    season,
    standings: [[{
      team: team(teamId),
      rank: 2,
      points: 18,
      all: {
        played: 8,
        win: 6,
        draw: 0,
        lose: 2,
        goals: { for: 15, against: 7 },
      },
      goalsDiff: 8,
    }]],
  },
});
const context = (id: number, league: number, season = 2026) => ({
  fixture_id: 100,
  team: team(id),
  league: { id: league, name: `League ${league}`, country: "Portugal", season },
  season_start: `${season}-07-01`,
  season_end: `${season + 1}-06-30`,
});
function payload(games: unknown[] = [], round = "League Stage - 1") {
  return {
    captured_at: "2026-10-12T09:00:00Z",
    raw: {
      fixtures: [fixture(100, 2, 2026, at, 1, 2, 0, 0, round)],
      league_fixtures: games,
      domestic_team_contexts: [context(1, 94), context(2, 140)],
      standings: [
        standing(1, 94, 2026),
        standing(2, 140, 2026),
        standing(1, 2, 2026),
      ],
      context_sources: [{
        endpoint: "/fixtures",
        query_params: { league: 2, season: 2026 },
        fetched_at: "2026-10-12T09:00:00Z",
      }],
      head_to_head: [],
    },
  };
}
const first = (p: ReturnType<typeof payload>) =>
  buildEuropeanComparisons(p)[0] as any;
Deno.test("before J1: empty European phase is informative, never a zero balance", () => {
  const d = first(payload());
  assert.equal(d.home.europeanSummary, null);
  assert.equal(d.home.europeanCoverageComplete, true);
});
Deno.test("after two games: limited sample and chronological order", () => {
  const d = first(
    payload([fixture(2, 2, 2026, "2026-10-10T18:00:00Z"), fixture(1)]),
  );
  assert.deepEqual(d.home.europeanRecentMatches.map((m: any) => m.fixtureId), [
    1,
    2,
  ]);
  assert.equal(d.home.europeanSummary.played, 2);
  assert.ok(d.notices.some((n: any) => n.kind === "limit"));
});
Deno.test("later rounds: phase totals use all results, deduplicate and exclude future/wrong season", () => {
  const games = [1, 2, 3, 4, 5, 6].map((i) =>
    fixture(i, 2, 2026, `2026-09-${String(i).padStart(2, "0")}T18:00:00Z`)
  );
  const d = first(
    payload([
      ...games,
      games[0],
      fixture(40, 2, 2025),
      fixture(41, 2, 2026, "2026-10-14T18:00:00Z"),
    ], "League Stage - 7"),
  );
  assert.equal(d.home.europeanSummary.played, 6);
  assert.equal(d.home.europeanSummary.points, 18);
});
Deno.test("knockout: qualifiers and league stay separate; first-leg aggregate excludes return", () => {
  const d = first(
    payload([
      fixture(1),
      fixture(2, 2, 2026, "2026-09-10T18:00:00Z", 1, 8, 1, 0, "Qualifying - 1"),
      fixture(
        3,
        2,
        2026,
        "2026-10-01T18:00:00Z",
        2,
        1,
        1,
        2,
        "Quarter-finals - 1",
      ),
    ], "Quarter-finals - 2"),
  );
  assert.equal(d.home.europeanSummary.played, 1);
  assert.equal(d.home.europeanRecentMatches.length, 3);
  assert.equal(d.firstLeg.fixtureId, 3);
  assert.equal(d.aggregate.homeGoals, 2);
  assert.equal(d.aggregate.awayGoals, 1);
  assert.equal(d.home.europeanStanding, null);
});
Deno.test("different domestic leagues: no universal comparison of ordinal ranks", () => {
  const d = first(
    payload([
      fixture(11, 94),
      fixture(12, 140, 2026, "2026-10-01T18:00:00Z", 2),
    ]),
  );
  assert.equal(d.home.domesticCompetition.id, 94);
  assert.equal(d.away.domesticCompetition.id, 140);
  assert.equal(d.home.domesticStanding.rank, 2);
  assert.ok(d.notices.every((n: any) => !n.text.includes("plus forte")));
});
Deno.test("short domestic history: actual denominator; never pad to five", () => {
  const d = first(
    payload([fixture(11, 94), fixture(12, 94, 2026, "2026-10-02T18:00:00Z")]),
  );
  assert.equal(d.home.domesticRecentMatches.length, 2);
  assert.equal(d.home.domesticSummary.played, 2);
  assert.ok(d.notices.some((n: any) => n.text.includes("6/6 points")));
});
Deno.test("historical view: current standing/statistics excluded, including same-day uncertified end", () => {
  const p = payload([fixture(1), fixture(2, 2, 2026, "2026-10-13T18:00:00Z")]);
  p.captured_at = "2026-10-15T09:00:00Z";
  p.raw.standings = [standing(1, 94, 2026, "2026-10-15T09:00:00Z")];
  p.raw.context_sources[0].fetched_at = p.captured_at;
  const d = first(p);
  assert.equal(d.home.domesticStanding, null);
  assert.equal(d.home.europeanRecentMatches.length, 1);
  assert.ok(
    d.dataQuality.limitations.some((x: string) => x.includes("historique")),
  );
});
Deno.test("partial API data: absent scores/contexts/unknown seasons are absent, not losses", () => {
  const p = payload([fixture(1)]);
  p.raw.domestic_team_contexts = [];
  p.raw.context_sources = [];
  (p.raw.league_fixtures[0] as any).goals.home = null;
  const d = first(p);
  assert.equal(d.home.domesticSummary, null);
  assert.equal(d.home.europeanSummary, null);
  assert.equal(d.home.domesticState, "missing");
  assert.equal(d.home.europeanCoverageComplete, false);
});
Deno.test("domestic calendar may use a different year from Europe; ambiguous or missing dates rejected", () => {
  const f = fixture(100, 2, 2025, "2026-04-01T18:00:00Z", 1, 2);
  const response = standing(1, 103, 2026);
  const cache = (endpoint: string, body: unknown) => ({
    endpoint,
    query_params: {},
    fetched_at: "2026-03-31T09:00:00Z",
    as_of: "2026-03-31T09:00:00Z",
    response_body: { response: body },
  });
  const s = cache("/standings", [response]);
  const l = cache("/leagues", [{
    league: { id: 103, type: "League" },
    seasons: [{ year: 2026, start: "2026-03-01", end: "2026-11-30" }],
  }]);
  const r = resolveEuropeanDomesticContexts([f], [s], [l]);
  assert.equal((r.contexts[0].league as any).season, 2026);
  assert.equal(r.contexts.length, 1);
  assert.equal(
    resolveEuropeanDomesticContexts([f], [s], []).contexts.length,
    0,
  );
});
Deno.test("standing observation belongs to the row, never another cached response", () => {
  const p = payload();
  p.raw.standings = [standing(1, 94, 2026, "2026-10-14T09:00:00Z")];
  p.raw.context_sources.push({
    endpoint: "/standings",
    query_params: { league: 94, season: 2026 },
    fetched_at: "2026-10-12T09:00:00Z",
  });
  assert.equal(first(p).home.domesticStanding, null);
});

Deno.test("domestic break: retain completed season for European final, never after next season begins", () => {
  const f = fixture(100, 2, 2025, "2026-05-30T18:00:00Z", 1, 2, 0, 0, "Final");
  const cache = (endpoint: string, response: unknown) => ({
    endpoint,
    query_params: {},
    fetched_at: "2026-05-29T09:00:00Z",
    as_of: "2026-05-29T09:00:00Z",
    response_body: { response },
  });
  const standings = cache("/standings", [
    standing(1, 94, 2025, "2026-05-29T09:00:00Z"),
  ]);
  const leagues = cache("/leagues", [{
    league: { id: 94, type: "League" },
    seasons: [
      { year: 2025, start: "2025-08-01", end: "2026-05-24" },
      { year: 2026, start: "2026-08-01", end: "2027-05-24" },
    ],
  }]);
  const resolved = resolveEuropeanDomesticContexts([f], [standings], [leagues]);
  assert.equal(resolved.contexts.length, 1);
  const p = payload();
  p.raw.fixtures = [f];
  p.raw.domestic_team_contexts = resolved.contexts as any;
  p.raw.standings = resolved.standings as any;
  p.raw.league_fixtures = [fixture(11, 94, 2025, "2026-05-20T18:00:00Z")];
  const d = first(p);
  assert.equal(d.home.domesticCompetition.season, 2025);
  assert.equal(d.home.domesticSeasonEnded, true);
  assert.equal(d.home.domesticRecentMatches.length, 1);
  const later = {
    ...f,
    fixture: { ...f.fixture, date: "2026-08-15T18:00:00Z" },
  };
  assert.equal(
    resolveEuropeanDomesticContexts([later], [standings], [leagues]).contexts
      .length,
    0,
  );
});
