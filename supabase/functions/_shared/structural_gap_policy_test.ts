import {
  assessStructuralGap,
  minimumPointsPerGameGapFor,
} from "./structural_gap_policy.ts";

Deno.test("requires a decisive gap after six matchdays", () => {
  const earlyButNarrow = assessStructuralGap(
    { rank: 10, points: 7, played: 6 },
    { rank: 17, points: 4, played: 6 },
  );

  if (earlyButNarrow !== null) {
    throw new Error("A three-point gap after six matchdays must be rejected.");
  }

  const decisive = assessStructuralGap(
    { rank: 1, points: 18, played: 6 },
    { rank: 7, points: 0, played: 6 },
  );
  if (decisive?.phase !== "early") {
    throw new Error("A six-win versus six-loss gap must remain detectable.");
  }
});

Deno.test("relaxes the threshold as a championship matures", () => {
  if (minimumPointsPerGameGapFor(5) !== 1.0) {
    throw new Error("Five matches require a 1.00 PPG gap.");
  }
  if (minimumPointsPerGameGapFor(11) !== 0.5) {
    throw new Error("Eleven matches require a 0.50 PPG gap.");
  }
  if (minimumPointsPerGameGapFor(12) !== 0.4) {
    throw new Error("Twelve matches restore the established threshold.");
  }
});

Deno.test("never treats a first-versus-second match as structural", () => {
  const assessment = assessStructuralGap(
    { rank: 1, points: 18, played: 6 },
    { rank: 2, points: 0, played: 6 },
  );

  if (assessment !== null) {
    throw new Error("One rank of separation must never be structural.");
  }
});

Deno.test("accepts only the exact points-per-game threshold", () => {
  const atThreshold = assessStructuralGap(
    { rank: 1, points: 16, played: 8 },
    { rank: 7, points: 9.6, played: 8 },
  );
  if (atThreshold?.minimumPointsPerGameGap !== 0.8) {
    throw new Error("Eight matches must accept exactly 0.80 PPG difference.");
  }

  const belowThreshold = assessStructuralGap(
    { rank: 1, points: 16, played: 8 },
    { rank: 7, points: 9.61, played: 8 },
  );
  if (belowThreshold !== null) {
    throw new Error(
      "An 0.79875 PPG difference must be rejected after eight matches.",
    );
  }
});
