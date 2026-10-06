import type {
  PublicCompetition,
  PublicFixture,
  PublicStanding,
} from "./hockey_feed.ts";

/** Versioned regular-season policy, matching the supported reading seasons.
 * Unknown seasons/competitions have no implicit NHL scoring fallback. */
const policies: Record<string, { start: string; end: string; win: number }> = {
  "57": { start: "2026-09-29", end: "2027-03-01", win: 2 },
  "58": { start: "2026-10-02", end: "2027-03-01", win: 2 },
  "35": { start: "2026-09-05", end: "2027-03-20", win: 2 },
  "10": { start: "2026-09-15", end: "2027-03-05", win: 3 },
  "18": { start: "2026-09-15", end: "2027-03-02", win: 3 },
  "16": { start: "2026-09-01", end: "2027-03-01", win: 3 },
  "47": { start: "2026-09-19", end: "2027-03-16", win: 3 },
};
export type CalculatedHockeyVenueRow = {
  team: PublicFixture["home"];
  rank: number;
  played: number;
  wins: number;
  losses: number;
  overtimeWins: number;
  overtimeLosses: number;
  goalsFor: number;
  goalsAgainst: number;
  points: number;
};
export type CalculatedHockeyVenueStandings = {
  source: "season-games";
  status: "reconciled" | "partial" | "unsupported";
  rulesVersion: "hockey-regular-2026-v1";
  phase: string;
  collectedAt: string;
  home: CalculatedHockeyVenueRow[];
  away: CalculatedHockeyVenueRow[];
  unavailableTeams: string[];
};

/** Rebuild both venues from the SAME completed-game set. All season games are
 * already collected; no team/player/API request is needed here. */
export function calculateHockeyVenueStandings(
  competition: PublicCompetition,
  games: PublicFixture[],
  at: string,
  onEvidence?: (
    games: PublicFixture[],
    maximumPoints: number,
    reconciled: boolean,
  ) => void,
): CalculatedHockeyVenueStandings {
  const regular = competition.tables.filter((t) =>
    /regular season/i.test(t.stage)
  );
  const reference = new Map<string, PublicStanding>();
  const inconsistent = new Set<string>();
  for (const row of regular.flatMap((t) => t.rows)) {
    const other = reference.get(row.team.id);
    if (
      other &&
      [
        "played",
        "points",
        "wins",
        "losses",
        "overtimeWins",
        "overtimeLosses",
        "goalsFor",
        "goalsAgainst",
      ].some((k) =>
        other[k as keyof PublicStanding] !== row[k as keyof PublicStanding]
      )
    ) inconsistent.add(row.team.id);
    reference.set(row.team.id, row);
  }
  const result: CalculatedHockeyVenueStandings = {
    source: "season-games",
    status: "unsupported",
    rulesVersion: "hockey-regular-2026-v1",
    phase: regular[0]?.stage ?? "Regular Season",
    collectedAt: at,
    home: [],
    away: [],
    unavailableTeams: [...reference.keys()],
  };
  const policy = competition.season === "2026"
    ? policies[competition.id]
    : undefined;
  if (
    !policy || !reference.size ||
    new Set(regular.map((t) => t.stage)).size !== 1
  ) return result;
  const ids = new Set<string>();
  const completed = games.filter((g) => {
    if (g.competitionId !== competition.id || g.season !== competition.season) {
      throw new Error("Crossed venue competition or season");
    }
    if (ids.has(g.id)) throw new Error("Duplicate venue game");
    ids.add(g.id);
    return g.status === "finished" && g.startsAt < at &&
      g.calendarDate >= policy.start && g.calendarDate <= policy.end &&
      ["FT", "AOT", "AP", "APEN"].includes(g.providerStatus) &&
      g.scores.final && g.scores.final.home !== g.scores.final.away &&
      reference.has(g.home.id) && reference.has(g.away.id);
  }).sort((a, b) =>
    a.startsAt.localeCompare(b.startsAt) || a.id.localeCompare(b.id)
  );

  const empty = (r: PublicStanding): CalculatedHockeyVenueRow => ({
    team: r.team,
    rank: 0,
    played: 0,
    wins: 0,
    losses: 0,
    overtimeWins: 0,
    overtimeLosses: 0,
    goalsFor: 0,
    goalsAgainst: 0,
    points: 0,
  });
  function add(
    row: CalculatedHockeyVenueRow,
    game: PublicFixture,
    home: boolean,
  ) {
    const score = game.scores.final,
      scored = home ? score.home : score.away,
      conceded = home ? score.away : score.home,
      won = scored > conceded,
      extra = game.providerStatus !== "FT";
    row.played++;
    row.goalsFor += scored;
    row.goalsAgainst += conceded;
    if (won) {
      row.wins++;
      if (extra) row.overtimeWins++;
    } else {
      row.losses++;
      if (extra) row.overtimeLosses++;
    }
    row.points += won ? (extra ? 2 : policy!.win) : (extra ? 1 : 0);
  }
  // Standings may lag the game endpoint. Reconcile the earliest N games with
  // the official N played, rather than assigning newer games to an older table.
  const included = new Map<string, Set<string>>();
  const issues = new Set(inconsistent);
  for (const [id, official] of reference) {
    const history = completed.filter((g) =>
      g.home.id === id || g.away.id === id
    );
    const prefix = history.slice(0, official.played), sum = empty(official);
    for (const g of prefix) add(sum, g, g.home.id === id);
    included.set(id, new Set(prefix.map((g) => g.id)));
    if (
      sum.played !== official.played || sum.points !== official.points ||
      sum.wins - sum.overtimeWins !== official.wins ||
      sum.overtimeWins !== official.overtimeWins ||
      sum.losses - sum.overtimeLosses !== official.losses ||
      sum.overtimeLosses !== official.overtimeLosses ||
      (official.goalsFor != null && sum.goalsFor !== official.goalsFor) ||
      (official.goalsAgainst != null &&
        sum.goalsAgainst !== official.goalsAgainst)
    ) issues.add(id);
  }
  for (const g of completed) {
    if (
      included.get(g.home.id)!.has(g.id) !== included.get(g.away.id)!.has(g.id)
    ) {
      issues.add(g.home.id);
      issues.add(g.away.id);
    }
  }
  const matched = issues.size === 0;
  const selected = matched
    ? completed.filter((g) => included.get(g.home.id)!.has(g.id))
    : completed;
  onEvidence?.(selected, policy.win, matched);
  const home = new Map([...reference].map(([id, row]) => [id, empty(row)]));
  const away = new Map([...reference].map(([id, row]) => [id, empty(row)]));
  for (const g of selected) {
    add(home.get(g.home.id)!, g, true);
    add(away.get(g.away.id)!, g, false);
  }
  function ranked(rows: CalculatedHockeyVenueRow[]) {
    const criteria = (
      a: CalculatedHockeyVenueRow,
      b: CalculatedHockeyVenueRow,
    ) =>
      b.points - a.points ||
      (b.goalsFor - b.goalsAgainst) - (a.goalsFor - a.goalsAgainst) ||
      b.goalsFor - a.goalsFor;
    rows.sort((a, b) =>
      criteria(a, b) || a.team.name.localeCompare(b.team.name)
    );
    rows.forEach((r, i) =>
      r.rank = i && criteria(rows[i - 1], r) === 0 ? rows[i - 1].rank : i + 1
    );
    return rows;
  }
  return {
    ...result,
    status: matched ? "reconciled" : "partial",
    unavailableTeams: [...issues],
    home: ranked([...home.values()]),
    away: ranked([...away.values()]),
  };
}
