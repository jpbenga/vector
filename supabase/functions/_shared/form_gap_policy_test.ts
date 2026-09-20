import { assessFormGap } from "./form_gap_policy.ts";

Deno.test("detects an exact nine-point form gap on five matches", () => {
  const assessment = assessFormGap(
    ["W", "W", "W", "D", "D"],
    ["L", "L", "L", "D", "D"],
  );
  if (
    assessment?.stronger !== "home" || assessment.strongerPoints !== 11 ||
    assessment.weakerPoints !== 2 || assessment.gap !== 9
  ) {
    throw new Error("An 11/15 versus 2/15 form gap must be detected.");
  }
});

Deno.test("rejects an eight-point form gap and incomplete windows", () => {
  if (
    assessFormGap(["W", "W", "W", "D", "L"], ["L", "L", "L", "D", "D"]) !== null
  ) {
    throw new Error("An eight-point form gap must not be detected.");
  }
  if (assessFormGap(["W", "W", "W", "W"], ["L", "L", "L", "L", "L"]) !== null) {
    throw new Error("Both teams need exactly five form results.");
  }
});
