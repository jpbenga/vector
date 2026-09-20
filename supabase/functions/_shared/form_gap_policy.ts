export type FormGapAssessment = {
  stronger: "home" | "away";
  strongerPoints: number;
  weakerPoints: number;
  gap: number;
};

const formPoints = (results: readonly string[]): number =>
  results.reduce(
    (total, result) => total + (result === "W" ? 3 : result === "D" ? 1 : 0),
    0,
  );

/**
 * Compares exactly the same five-match form window for both teams.
 * A form gap is significant only from nine points out of fifteen.
 */
export function assessFormGap(
  homeResults: readonly string[],
  awayResults: readonly string[],
): FormGapAssessment | null {
  if (homeResults.length !== 5 || awayResults.length !== 5) return null;
  if (
    [...homeResults, ...awayResults].some((result) =>
      result !== "W" && result !== "D" && result !== "L"
    )
  ) return null;

  const homePoints = formPoints(homeResults);
  const awayPoints = formPoints(awayResults);
  const gap = Math.abs(homePoints - awayPoints);
  if (gap < 9 || homePoints === awayPoints) return null;

  return homePoints > awayPoints
    ? {
      stronger: "home",
      strongerPoints: homePoints,
      weakerPoints: awayPoints,
      gap,
    }
    : {
      stronger: "away",
      strongerPoints: awayPoints,
      weakerPoints: homePoints,
      gap,
    };
}
