import {
  eligibleHeadToHeadFixtureIds,
  eligibleHeadToHeadMeetings,
  maxHeadToHeadMeetings,
} from "./head_to_head_history.ts";

const reference = "2026-09-27T20:00:00Z";

function meeting({
  id,
  date,
  leagueName = "La Liga",
  status = "FT",
}: {
  id: number;
  date: string;
  leagueName?: string;
  status?: string;
}) {
  return {
    fixture: { id, date, status: { short: status } },
    league: { name: leagueName, type: "League", country: "Spain" },
  };
}

Deno.test("keeps only official completed meetings inside the previous three years", () => {
  const result = eligibleHeadToHeadMeetings([
    meeting({ id: 1, date: "2023-09-26T19:00:00Z" }),
    meeting({ id: 2, date: "2023-09-28T19:00:00Z" }),
    meeting({
      id: 3,
      date: "2025-03-01T19:00:00Z",
      leagueName: "International Friendlies",
    }),
    meeting({ id: 4, date: "2026-09-26T19:00:00Z", status: "NS" }),
    meeting({ id: 5, date: "2026-09-28T19:00:00Z" }),
    meeting({ id: 6, date: "2026-05-01T19:00:00Z" }),
  ], reference);

  const ids = result.map((value) => (value.fixture as { id: number }).id);
  if (ids.length !== 2 || ids[0] !== 6 || ids[1] !== 2) {
    throw new Error(`Unexpected eligible meetings: ${ids.join(", ")}`);
  }
});

Deno.test("limits the history to the six most recent eligible meetings", () => {
  const values = Array.from({ length: 8 }, (_, index) =>
    meeting({
      id: index + 1,
      date: `2026-0${index + 1}-01T19:00:00Z`,
    }));
  const result = eligibleHeadToHeadMeetings(values, reference);
  const ids = result.map((value) => (value.fixture as { id: number }).id);
  if (
    result.length !== maxHeadToHeadMeetings || ids.join(",") !== "8,7,6,5,4,3"
  ) {
    throw new Error(
      `Expected the six newest meetings, received ${ids.join(", ")}`,
    );
  }
});

Deno.test("selects only eligible historical fixture ids for timeline enrichment", () => {
  const ids = eligibleHeadToHeadFixtureIds([
    meeting({ id: 1, date: "2026-09-26T19:00:00Z" }),
    meeting({ id: 2, date: "2026-09-25T19:00:00Z", status: "NS" }),
    meeting({
      id: 3,
      date: "2026-09-24T19:00:00Z",
      leagueName: "International Friendlies",
    }),
    meeting({ id: 4, date: "2022-09-24T19:00:00Z" }),
  ], reference);

  if (ids.join(",") !== "1") {
    throw new Error(`Unexpected timeline fixtures: ${ids.join(", ")}`);
  }
});

Deno.test("league and cup samples are independent instead of cups starving the league view", () => {
  const values = [
    ...Array.from(
      { length: 3 },
      (_, i) => meeting({ id: i + 1, date: `2025-01-0${i + 1}T19:00:00Z` }),
    ),
    ...Array.from(
      { length: 7 },
      (_, i) => ({
        ...meeting({ id: i + 10, date: `2026-09-${i + 10}T19:00:00Z` }),
        league: { id: 99, name: "National Cup", type: "Cup" },
      }),
    ),
  ];
  const selected = eligibleHeadToHeadMeetings(values, reference);
  if (
    selected.length !== 9 ||
    selected.filter((r) => (r.league as { id: number }).id === 99).length !== 6
  ) throw new Error("Official scopes were mixed or starved");
});
