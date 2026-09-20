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

/**
 * Finds dominance from exactly the six latest completed meetings between the
 * two teams in the current competition. Other competitions never contribute.
 */
export function assessHeadToHeadDominance({
  meetings,
  competitionId,
  homeTeamId,
  awayTeamId,
}: {
  meetings: readonly HeadToHeadMeeting[];
  competitionId: number;
  homeTeamId: number;
  awayTeamId: number;
}): HeadToHeadDominanceAssessment[] {
  const scoped = meetings
    .filter((meeting) =>
      meeting.competitionId === competitionId &&
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
