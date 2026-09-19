export type StructuralGapAssessment = {
  comparedMatches: number;
  minimumPointsPerGameGap: number;
  phase: "early" | "established";
};

/// Returns the minimum PPG difference needed to call an observed standings
/// gap structural. Early rankings are volatile, so the threshold relaxes only
/// as both teams accumulate comparable competitive evidence.
export function assessStructuralGap(
  superior: { rank: number; points: number; played: number },
  opponent: { rank: number; points: number; played: number },
): StructuralGapAssessment | null {
  const comparedMatches = Math.min(superior.played, opponent.played);
  if (comparedMatches < 5 || opponent.rank - superior.rank < 6) {
    return null;
  }

  const minimumPointsPerGameGap = minimumPointsPerGameGapFor(
    comparedMatches,
  );
  const actualPointsPerGameGap = superior.points / superior.played -
    opponent.points / opponent.played;
  if (actualPointsPerGameGap < minimumPointsPerGameGap) {
    return null;
  }

  return {
    comparedMatches,
    minimumPointsPerGameGap,
    phase: comparedMatches < 12 ? "early" : "established",
  };
}

export function minimumPointsPerGameGapFor(comparedMatches: number): number {
  if (comparedMatches <= 6) return 1.0;
  if (comparedMatches === 7) return 0.9;
  if (comparedMatches === 8) return 0.8;
  if (comparedMatches === 9) return 0.7;
  if (comparedMatches === 10) return 0.6;
  if (comparedMatches === 11) return 0.5;
  return 0.4;
}
