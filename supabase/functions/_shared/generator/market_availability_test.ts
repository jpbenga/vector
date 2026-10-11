import assert from "node:assert/strict";
import { marketAvailability } from "./market_availability.ts";
import { ConversationReader } from "./conversation_tools.ts";
import { context } from "./evaluation_cases.ts";
import type { Source } from "./catalog.ts";

const now = new Date("2026-10-11T16:35:01.977Z");

Deno.test("price presence survives kickoff; stale scheduled status cannot admit a prematch selection in either sport", () => {
  for (const sport of ["hockey", "football"] as const) {
    const match = {
      sport,
      kickoff: "2026-10-11T16:30:00Z",
      status: sport === "hockey" ? "scheduled" : "NS",
      capturedAt: "2026-10-11T03:34:18.269Z",
    };
    const actual = marketAvailability(match, "recent", 0, now);
    assert.equal(actual.quoteAvailability, "recent");
    assert.equal(actual.prematchEligible, false);
    assert.deepEqual(actual.reasons.map((r) => r.code), ["kickoff_passed"]);
    const future = { ...match, kickoff: "2026-10-11T19:00:00Z" };
    assert.equal(
      marketAvailability(future, "recent", 2, now).prematchEligible,
      true,
    );
    assert.deepEqual(
      marketAvailability(future, "recent", 0, now).reasons.map((r) => r.code),
      ["no_supported_candidate"],
    );
    assert.deepEqual(
      marketAvailability(future, "not_collected", 0, now).reasons.map((r) =>
        r.code
      ),
      ["quotes_not_collected"],
    );
    // A reread within the same eligibility window must not break the cache.
    assert.deepEqual(
      marketAvailability(future, "recent", 2, new Date(now.getTime() + 1000)),
      marketAvailability(future, "recent", 2, now),
    );
  }
});

Deno.test("the 18:35 hockey request exposes collected Czech prices and their time exclusion to search, details and evaluation", async () => {
  const fixture = (
    id: string,
    home: string,
    away: string,
    kickoff: string,
  ) => ({
    id,
    competitionId: "10",
    competitionName: "Extraliga",
    season: "2026",
    status: "scheduled",
    startsAt: kickoff,
    home: { id: "2", name: home },
    away: { id: "3", name: away },
    quotesCollectedAt: "2026-10-11T12:17:04.196Z",
    quotes: [{
      marketCode: "result_regulation",
      selectionCode: "home",
      scope: "regulation",
      bookmaker: "Book",
      bookmakerId: "1",
      decimalOdds: 2.13,
      capturedAt: "2026-10-11T12:17:04.196Z",
    }],
    readings: [{
      id: "winning_streak",
      subject_team_id: "2",
      sample_size: 3,
      explanation: "Trois victoires finales",
    }],
  });
  const publication: Source = {
    id: "published",
    sport: "hockey",
    capturedAt: "2026-10-11T03:34:18.269Z",
    payload: {
      items: [
        fixture(
          "426325",
          "Ceske Budejovice",
          "Liberec",
          "2026-10-11T15:00:00Z",
        ),
        fixture("426323", "Pardubice", "Trinec", "2026-10-11T16:30:00Z"),
        fixture("434678", "Calgary", "Bakersfield", "2026-10-11T19:00:00Z"),
        fixture("434679", "Hartford", "Laval", "2026-10-11T19:00:00Z"),
      ],
    },
  };
  const reader = new ConversationReader({
    message: "Trois prochaines rencontres",
    context: { ...context, configurationPolicy: "request" },
    date: "2026-10-11",
    id: "33333333-3333-4333-8333-333333333333",
    now,
    state: null,
  }, { sources: async () => [publication] });
  const found = await reader.execute("search_matches", {
    date: "2026-10-11",
    sports: ["hockey"],
    view: "all",
    radarKind: "teams",
    query: null,
    offset: 0,
    limit: 20,
  }) as any;
  const details = await reader.execute("read_matches", {
    queryId: found.queryId,
    matchKeys: found.matches.map((m: any) => m.key),
  }) as any[];
  assert.equal(details.length, 4);
  for (const [i, detail] of details.entries()) {
    assert.equal(detail.marketAvailability.quoteAvailability, "recent");
    assert.deepEqual(
      detail.marketAvailability,
      found.matches[i].marketAvailability,
    );
    assert.equal(detail.marketAvailability.prematchEligible, i >= 2);
    assert.equal(detail.candidates.length > 0, i >= 2);
    if (i < 2) {
      assert.deepEqual(
        detail.marketAvailability.reasons.map((r: any) => r.code),
        ["kickoff_passed"],
      );
    }
  }
  const sheets = reader.matchSheets(reader.queries.get(found.queryId)!);
  assert.deepEqual(
    sheets[1].match.marketAvailability,
    details[1].marketAvailability,
  );
});
