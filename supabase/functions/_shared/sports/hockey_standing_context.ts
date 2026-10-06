import type { PublicCompetition, PublicFixture } from "./hockey_feed.ts";
import { calculateHockeyVenueStandings } from "./hockey_venue_standings.ts";

export type GroupResults = {
  played: number;
  points: number;
  goalsFor: number;
  goalsAgainst: number;
};
export type HockeyStandingContext = {
  source: "reconciled-season-games";
  phase: string;
  collectedAt: string;
  maximumPoints: number | null;
  groups: {
    tableIndex: number;
    kind: "conference" | "division" | "league";
    parentTableIndex: number | null;
    all: GroupResults | null;
    home: GroupResults | null;
    away: GroupResults | null;
  }[];
};

/** One reconciliation and one season/game inclusion policy for all standings
 * views. A percentage is published ONLY when games reproduce official totals.
 * Group membership comes from official tables, never from guessed geography. */
export function calculateHockeyStandingContext(
  competition: PublicCompetition,
  games: PublicFixture[],
  at: string,
) {
  let selected: PublicFixture[] = [], maximumPoints: number | null = null;
  const venueStandings = calculateHockeyVenueStandings(
    competition,
    games,
    at,
    (rows, maximum, reconciled) => {
      maximumPoints = maximum;
      if (reconciled) selected = rows;
    },
  );
  const phase = venueStandings.phase;
  const tables = competition.tables.map((t, tableIndex) => ({
    ...t,
    tableIndex,
    members: new Set(t.rows.map((r) => r.team.id)),
  })).filter((t) => t.stage === phase && t.rows.length > 0);
  const empty = (): GroupResults => ({
    played: 0,
    points: 0,
    goalsFor: 0,
    goalsAgainst: 0,
  });
  const standingContext: HockeyStandingContext = {
    source: "reconciled-season-games",
    phase,
    collectedAt: at,
    maximumPoints,
    groups: tables.map((table) => {
      const parents = tables.filter((t) =>
        t.members.size > table.members.size &&
        [...table.members].every((id) => t.members.has(id))
      )
        .sort((a, b) => a.members.size - b.members.size);
      // Structural hierarchy handles named KHL divisions as well as NHL.
      const hasChildren = tables.some((t) =>
        t.members.size < table.members.size &&
        [...t.members].every((id) => table.members.has(id))
      );
      const kind = /conference/i.test(table.group)
        ? "conference"
        : /division/i.test(table.group)
        ? "division"
        : table.members.size === venueStandings.home.length
        ? "league"
        : hasChildren
        ? "conference"
        : parents.length
        ? "division"
        : "league";
      const results = { all: empty(), home: empty(), away: empty() };
      for (const game of selected) {
        const home = table.members.has(game.home.id),
          away = table.members.has(game.away.id);
        if (home === away) continue; // Neither member, or an intra-group match.
        const score = game.scores.final;
        const scored = home ? score.home : score.away;
        const conceded = home ? score.away : score.home;
        const extra = game.providerStatus !== "FT";
        const points = scored > conceded
          ? (extra ? 2 : maximumPoints!)
          : extra
          ? 1
          : 0;
        for (const row of [results.all, home ? results.home : results.away]) {
          row.played++;
          row.points += points;
          row.goalsFor += scored;
          row.goalsAgainst += conceded;
        }
      }
      const verified = venueStandings.status === "reconciled";
      return {
        tableIndex: table.tableIndex,
        kind,
        parentTableIndex: parents[0]?.tableIndex ?? null,
        all: verified ? results.all : null,
        home: verified ? results.home : null,
        away: verified ? results.away : null,
      };
    }),
  };
  // A peer comparison requires disjoint memberships at the same level.
  // Ambiguous provider groups still remain browsable, without a rate.
  for (const group of standingContext.groups) {
    const own = tables.find((t) => t.tableIndex === group.tableIndex)!;
    const overlapping = standingContext.groups.some((peer) =>
      peer !== group && peer.kind === group.kind &&
      tables.find((t) => t.tableIndex === peer.tableIndex)!.rows.some((r) =>
        own.members.has(r.team.id)
      )
    );
    if (overlapping) group.all = group.home = group.away = null;
  }
  return { venueStandings, standingContext };
}
