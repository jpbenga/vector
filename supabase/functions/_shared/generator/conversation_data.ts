import { footballPublishedQuotes } from "./published_quotes.ts";
import { obj, rows } from "./contracts.ts";

// Fixed PostgREST projection: no raw provider envelopes, user tables or arbitrary SQL.
export const footballDetailColumns = [
  "id",
  "captured_at",
  "fixtures:payload->raw->fixtures",
  "computed:payload->computed->fixtures",
  "odds:payload->raw->odds",
  "standings:payload->raw->standings",
  "team_statistics:payload->raw->team_statistics",
  "recent_league_matches:payload->raw->recent_league_matches",
  "head_to_head:payload->raw->head_to_head",
  "european_comparisons:payload->raw->european_comparisons",
].join(",");

/** Convert the legacy football publication into a single, pinned read object. */
export function projectFootballMatch(
  row: unknown,
  sourceId: string,
  capturedAt: string,
  matchId: string,
) {
  const source = obj(row);
  if (
    source.id !== sourceId ||
    Date.parse(String(source.captured_at)) !== Date.parse(capturedAt)
  ) return null;
  const fixture = rows(source.fixtures).find((f) =>
    String(obj(f.fixture).id) === matchId
  );
  if (!fixture) return null;
  const teams = obj(fixture.teams), league = obj(fixture.league);
  const teamIds = new Set([
    String(obj(teams.home).id),
    String(obj(teams.away).id),
  ]);
  const sameLeague = (r: Record<string, unknown>) =>
    String(obj(r.league).id) === String(league.id);
  const sameTeam = (r: Record<string, unknown>) =>
    teamIds.has(String(obj(r.team).id));
  const resultFacts = (v: unknown) => {
    const r = obj(v);
    return {
      fixture: r.fixture,
      date: r.date,
      league: r.league,
      teams: r.teams,
      goals: r.goals,
      score: r.score,
      result: r.result,
      venue: r.venue,
      opponent: r.opponent,
    };
  };
  const computed = rows(source.computed).find((r) =>
    String(r.fixture_id) === matchId
  );
  const european = [2, 3, 848].includes(Number(league.id));
  const dossier =
    rows(source.european_comparisons).find((d) =>
      String(d.fixtureId) === matchId && d.schemaVersion === 1 &&
      Date.parse(String(d.kickoffAt)) ===
        Date.parse(String(obj(fixture.fixture).date))
    ) ?? null;
  return {
    sport: "football",
    capturedAt,
    sourceId,
    items: [{
      id: matchId,
      fixture,
      europeanComparison: dossier,
      quotes: footballPublishedQuotes(source.odds, matchId),
      readings: computed?.readings ?? [],
      scenarios: computed?.scenarios ?? [],
      tiers: european ? null : computed?.tier_snapshot ?? null,
      standings: european ? [] : rows(source.standings).filter(sameLeague),
      teamStatistics: european
        ? []
        : rows(source.team_statistics).filter((r) =>
          sameLeague(r) && sameTeam(r)
        ),
      recentForm: european
        ? []
        : rows(source.recent_league_matches).filter((r) =>
          sameLeague(r) && sameTeam(r)
        ).map((r) => ({ ...r, matches: rows(r.matches).map(resultFacts) })),
      headToHead: european
        ? []
        : rows(source.head_to_head).filter((r) =>
          String(obj(r.fixture).id) === matchId
        ).map((r) => ({
          fixture: r.fixture,
          matches: rows(r.matches).map(resultFacts),
        })),
    }],
    competitions: [],
    playerRadar: {},
  };
}
