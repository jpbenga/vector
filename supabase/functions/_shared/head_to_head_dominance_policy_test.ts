import {
  assessHeadToHeadDominance,
  type HeadToHeadMeeting,
} from "./head_to_head_dominance_policy.ts";

const home = 1;
const away = 2;
const competition = 39;

function meeting({
  index,
  host = home,
  winner = home,
  competitionId = competition,
}: {
  index: number;
  host?: number;
  winner?: number | null;
  competitionId?: number;
}): HeadToHeadMeeting {
  const visitor = host === home ? away : home;
  const homeGoals = winner === null ? 1 : winner === host ? 2 : 0;
  const awayGoals = winner === null ? 1 : winner === visitor ? 2 : 0;
  return {
    competitionId,
    playedAt: index,
    homeTeamId: host,
    awayTeamId: visitor,
    homeGoals,
    awayGoals,
  };
}

Deno.test("classifies six wins, five wins and one draw, then five wins and one loss", () => {
  const total = assessHeadToHeadDominance({
    meetings: Array.from({ length: 6 }, (_, index) => meeting({ index })),
    competitionId: competition,
    homeTeamId: home,
    awayTeamId: away,
  });
  if (
    total.length !== 1 || total[0].variant !== "total" || total[0].wins !== 6
  ) {
    throw new Error("Six wins must be a total dominance.");
  }

  const unbeaten = assessHeadToHeadDominance({
    meetings: [
      ...Array.from({ length: 5 }, (_, index) => meeting({ index })),
      meeting({ index: 6, winner: null }),
    ],
    competitionId: competition,
    homeTeamId: home,
    awayTeamId: away,
  });
  if (unbeaten.length !== 1 || unbeaten[0].variant !== "unbeaten") {
    throw new Error("Five wins and one draw must be an unbeaten dominance.");
  }

  const net = assessHeadToHeadDominance({
    meetings: [
      ...Array.from({ length: 5 }, (_, index) => meeting({ index })),
      meeting({ index: 6, winner: away }),
    ],
    competitionId: competition,
    homeTeamId: home,
    awayTeamId: away,
  });
  if (net.length !== 1 || net[0].variant !== "net" || net[0].losses !== 1) {
    throw new Error(
      "Five wins and one loss must remain an explicit net dominance.",
    );
  }
});

Deno.test("reports an away-only dominance and never leaks another competition", () => {
  const awayOnly = assessHeadToHeadDominance({
    meetings: [
      ...Array.from(
        { length: 3 },
        (_, index) => meeting({ index, host: home, winner: away }),
      ),
      ...Array.from(
        { length: 3 },
        (_, index) => meeting({ index: index + 3, host: away, winner: home }),
      ),
    ],
    competitionId: competition,
    homeTeamId: home,
    awayTeamId: away,
  });
  if (
    awayOnly.length !== 2 ||
    !awayOnly.some((entry) =>
      entry.teamId === away && entry.variant === "away_unbeaten"
    ) ||
    !awayOnly.some((entry) =>
      entry.teamId === home && entry.variant === "away_unbeaten"
    )
  ) {
    throw new Error("Each team must surface its own three away wins.");
  }

  const mixedCompetition = assessHeadToHeadDominance({
    meetings: [
      ...Array.from({ length: 5 }, (_, index) => meeting({ index })),
      meeting({ index: 6, competitionId: 48 }),
    ],
    competitionId: competition,
    homeTeamId: home,
    awayTeamId: away,
  });
  if (mixedCompetition.length !== 0) {
    throw new Error(
      "A cup or friendly must never complete a league TAT sample.",
    );
  }
});
