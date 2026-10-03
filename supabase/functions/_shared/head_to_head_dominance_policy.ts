export type HeadToHeadMeeting = {
  competitionId: number;
  playedAt: number;
  homeTeamId: number;
  awayTeamId: number;
  homeGoals: number;
  awayGoals: number;
};

export type HeadToHeadDominanceVariant =
  | "total"
  | "unbeaten"
  | "net"
  | "home_unbeaten"
  | "away_unbeaten";

export type HeadToHeadDominanceAssessment = {
  teamId: number;
  variant: HeadToHeadDominanceVariant;
  wins: number;
  draws: number;
  losses: number;
  venue: "home" | "away" | null;
  meetings: number;
};

/** Senior national-team competitions treated as official by Lector. */
export const officialInternationalCompetitionIds = new Set([
  1, // World Cup
  4, // Euro Championship
  5, // UEFA Nations League
  6, // African Nations Championship
  7, // AFC Asian Cup
  8, // World Cup qualifiers
  9, // Copa America
  22, // Confederations Cup
  32, // CONCACAF Gold Cup
  536, // Olympic Games
]);

export function isOfficialInternationalCompetition(
  competitionId: number,
): boolean {
  return officialInternationalCompetitionIds.has(competitionId);
}

/**
 * Finds dominance from exactly the six latest completed meetings between the
 * two teams. Club competitions retain their exact-competition scope. National
 * teams use official international matches from the three years before the
 * fixture, excluding friendlies while allowing World Cup, Euro and Nations
 * League meetings to be compared together.
 */
export function assessHeadToHeadDominance({
  meetings,
  competitionId,
  homeTeamId,
  awayTeamId,
  fixtureKickoff,
  officialInternationalScope = false,
}: {
  meetings: readonly HeadToHeadMeeting[];
  competitionId: number;
  homeTeamId: number;
  awayTeamId: number;
  fixtureKickoff?: number;
  officialInternationalScope?: boolean;
}): HeadToHeadDominanceAssessment[] {
  const threeYearsBefore = fixtureKickoff === undefined
    ? Number.NEGATIVE_INFINITY
    : fixtureKickoff - 3 * 365 * 24 * 60 * 60 * 1000;
  const scoped = meetings
    .filter((meeting) =>
      (officialInternationalScope
        ? isOfficialInternationalCompetition(meeting.competitionId) &&
          meeting.playedAt >= threeYearsBefore
        : meeting.competitionId === competitionId) &&
      ((meeting.homeTeamId === homeTeamId &&
        meeting.awayTeamId === awayTeamId) ||
        (meeting.homeTeamId === awayTeamId &&
          meeting.awayTeamId === homeTeamId))
    )
    .sort((left, right) => right.playedAt - left.playedAt)
    .slice(0, 6);
  if (scoped.length !== 6) return [];

  const assessments: HeadToHeadDominanceAssessment[] = [];
  for (const teamId of [homeTeamId, awayTeamId]) {
    const overall = recordFor(teamId, scoped);
    const overallVariant = overall.wins === 6
      ? "total"
      : overall.wins === 5 && overall.losses === 0
      ? "unbeaten"
      : overall.wins === 5 && overall.losses === 1
      ? "net"
      : null;
    if (overallVariant !== null) {
      assessments.push({
        teamId,
        variant: overallVariant,
        ...overall,
        venue: null,
        meetings: scoped.length,
      });
      continue;
    }

    for (const venue of ["home", "away"] as const) {
      const venueMeetings = scoped.filter((meeting) =>
        venue === "home"
          ? meeting.homeTeamId === teamId
          : meeting.awayTeamId === teamId
      );
      const record = recordFor(teamId, venueMeetings);
      if (
        venueMeetings.length >= 3 && record.losses === 0 && record.wins >= 2
      ) {
        assessments.push({
          teamId,
          variant: venue === "home" ? "home_unbeaten" : "away_unbeaten",
          ...record,
          venue,
          meetings: venueMeetings.length,
        });
      }
    }
  }
  return assessments;
}

function recordFor(teamId: number, meetings: readonly HeadToHeadMeeting[]) {
  let wins = 0;
  let draws = 0;
  let losses = 0;
  for (const meeting of meetings) {
    const goalsFor = meeting.homeTeamId === teamId
      ? meeting.homeGoals
      : meeting.awayGoals;
    const goalsAgainst = meeting.homeTeamId === teamId
      ? meeting.awayGoals
      : meeting.homeGoals;
    if (goalsFor > goalsAgainst) wins += 1;
    else if (goalsFor < goalsAgainst) losses += 1;
    else draws += 1;
  }
  return { wins, draws, losses };
}
