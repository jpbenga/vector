import { obj, rows } from "./contracts.ts";

// Fixed PostgREST projection: no raw provider envelopes, user tables or arbitrary SQL.
export const footballDetailColumns = [
  "id",
  "captured_at",
  "fixtures:payload->raw->fixtures",
  "computed:payload->computed->fixtures",
  "standings:payload->raw->standings",
  "team_statistics:payload->raw->team_statistics",
  "recent_league_matches:payload->raw->recent_league_matches",
  "head_to_head:payload->raw->head_to_head",
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
  return {
    sport: "football",
    capturedAt,
    sourceId,
    items: [{
      id: matchId,
      fixture,
      readings: computed?.readings ?? [],
      scenarios: computed?.scenarios ?? [],
      tiers: computed?.tier_snapshot ?? null,
      standings: rows(source.standings).filter(sameLeague),
      teamStatistics: rows(source.team_statistics).filter((r) =>
        sameLeague(r) && sameTeam(r)
      ),
      recentForm: rows(source.recent_league_matches).filter((r) =>
        sameLeague(r) && sameTeam(r)
      ).map((r) => ({ ...r, matches: rows(r.matches).map(resultFacts) })),
      headToHead: rows(source.head_to_head).filter((r) =>
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
