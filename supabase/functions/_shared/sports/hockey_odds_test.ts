import assert from "node:assert/strict";
import { hockeyQuoteRecords } from "./hockey_odds.ts";
import { type PublicFixture } from "./hockey_feed.ts";
export const quoteAt = "2026-10-09T10:00:00Z";
export const quotedFixture = {
  id: "100",
  competitionId: "35",
  competitionName: "KHL",
  season: "2026",
  status: "scheduled",
  startsAt: "2026-10-09T18:00:00Z",
  calendarDate: "2026-10-09",
  home: { id: "2", name: "Home" },
  away: { id: "3", name: "Away" },
  scores: {},
} as PublicFixture;
export const oddsPayload = () => ({
  errors: [],
  results: 1,
  response: [{
    league: { id: 35, season: 2026 },
    game: {
      id: 100,
      date: quotedFixture.startsAt,
      teams: { home: { id: 2 }, away: { id: 3 } },
    },
    bookmakers: [{
      id: 1,
      name: "Book",
      bets: [
        {
          id: 1,
          name: "3Way Result",
          values: [{ value: "Home", odd: "2.20" }, {
            value: "Draw",
            odd: "4.1",
          }, { value: "Away", odd: "2.5" }],
        },
        {
          id: 9,
          name: "Double Chance",
          values: [{ value: "Home/Draw", odd: "1.5" }],
        },
        {
          id: 52,
          name: "Over/Under (Reg Time)",
          values: [{ value: "Over 5.5", odd: "1.9" }, {
            value: "Over 5",
            odd: "2",
          }],
        },
        { id: 2, name: "Home/Away", values: [{ value: "Home", odd: "1.8" }] },
        {
          id: 4,
          name: "Over/Under",
          values: [{ value: "Over 5.5", odd: "1.8" }],
        },
      ],
    }],
  }],
});
Deno.test("hockey quotes retain explicit regulation scope and observation time, exclude ambiguous/integer lines", () => {
  const records = hockeyQuoteRecords(
    oddsPayload(),
    [quotedFixture],
    "35",
    "2026",
    quoteAt,
  );
  assert.equal(records[0].quotes.length, 5);
  assert.ok(
    records[0].quotes.every((q) =>
      q.scope === "regulation" && q.capturedAt === quoteAt
    ),
  );
  assert.equal(records[0].quotes.at(-1)?.line, 5.5);
  const swapped = oddsPayload();
  swapped.response[0].game.teams.home.id = 3;
  assert.equal(
    hockeyQuoteRecords(swapped, [quotedFixture], "35", "2026", quoteAt)[0]
      .quotes.length,
    0,
  );
  assert.throws(() =>
    hockeyQuoteRecords(
      { ...oddsPayload(), errors: { quota: "limit" } },
      [quotedFixture],
      "35",
      "2026",
      quoteAt,
    )
  );
  assert.equal(
    hockeyQuoteRecords(
      oddsPayload(),
      [{ ...quotedFixture, status: "finished" }],
      "35",
      "2026",
      quoteAt,
    ).length,
    0,
  );
});
