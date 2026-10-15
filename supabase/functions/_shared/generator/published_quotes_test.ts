import assert from "node:assert/strict";
import {
  footballPublishedQuotes,
  footballQuoteAvailability,
} from "./published_quotes.ts";
import { refreshPublishedOdds } from "../refresh_published_odds.ts";
import { marketAvailability } from "./market_availability.ts";
import { buildCatalog } from "./catalog.ts";
import { context, source } from "./evaluation_cases.ts";
import { ConversationReader } from "./conversation_tools.ts";

Deno.test("all football competitions expose dated prices even when stale or unsupported for a candidate", async () => {
  const now = new Date("2026-10-13T00:00:00Z");
  for (const league of [2, 3, 848, 40, 61, 128]) {
    const s = source();
    s.capturedAt = now.toISOString();
    const raw = s.payload.raw as any;
    raw.fixtures = raw.fixtures.slice(0, 1);
    raw.fixtures[0].fixture.date = "2026-10-13T18:00:00Z";
    raw.fixtures[0].league = { id: league, name: "Compétition " + league };
    raw.odds = raw.odds.slice(0, 1);
    raw.odds[0].update = "2026-10-10T03:57:23Z";
    raw.odds[0].bookmakers = [{
      id: 8,
      name: "Bet365",
      bets: [{
        id: 1,
        name: "Match Winner",
        values: [
          { value: "Home", odd: "2.50" },
          { value: "Draw", odd: "3.70" },
          { value: "Away", odd: "2.50" },
        ],
      }, {
        id: 99,
        name: "Other market",
        values: [{ value: "Under 4.5", odd: "1.25" }],
      }],
    }];
    const ctx = {
      ...context,
      view: "all" as const,
      scope: "discovery" as const,
      configurationPolicy: "request" as const,
    };
    const cat = buildCatalog([s], ctx, "2026-10-13", now, {
      includePastAndLive: true,
    });
    assert.equal(cat.matches![0].quoteAvailability, "stale");
    assert.equal(cat.candidates.length, 2);
    assert.equal(footballPublishedQuotes(raw.odds, "1")[0].odds, 2.5);
    assert.equal(footballPublishedQuotes(raw.odds, "1").length, 4);
    assert.equal(footballPublishedQuotes(raw.odds, "999").length, 0);
    const reader = new ConversationReader({
      context: ctx,
      state: null,
      id: "test",
      message: "combine",
      date: "2026-10-13",
      now,
    }, { sources: async () => [s] } as any);
    const q = await reader.execute("search_matches", {
      date: "2026-10-13",
      sports: ["football"],
      view: "all",
      radarKind: "teams",
      query: null,
      offset: 0,
      limit: 20,
    }) as any;
    const detail = await reader.execute("read_matches", {
      queryId: q.queryId,
      matchKeys: ["football:1"],
    }) as any;
    assert.equal(detail[0].publishedQuotes[0].bookmaker, "Bet365");
    assert.equal(detail[0].marketAvailability.prematchEligible, true);
    assert.equal(detail[0].marketAvailability.reasons.length, 0);
    assert.match(detail[0].marketAvailability.warnings.join(" "), /anciennes/);
  }
});
Deno.test("newer cache prices replace old publications without refreshing provider observation dates or admitting other fixtures", () => {
  const raw = {
    fixtures: [{ fixture: { id: 1 }, league: { id: 2, season: 2026 } }],
    odds: [{ fixture: { id: 1 }, update: "2026-10-10T03:57:23Z" }],
  };
  const cached = [{
    endpoint: "/odds",
    query_params: { league: "2", season: "2026" },
    fetched_at: "2026-10-12T01:27:00Z",
    response_body: {
      response: [{
        fixture: { id: 1 },
        update: "2026-10-12T01:20:00Z",
        bookmakers: [{
          id: 8,
          name: "Bet365",
          bets: [{ id: 1, values: [{ value: "Home", odd: "2.60" }] }],
        }],
      }, { fixture: { id: 999 }, update: "2026-10-12T01:20:00Z" }],
    },
  }];
  const quotes = refreshPublishedOdds(raw, cached);
  assert.equal(quotes.length, 1);
  assert.equal(quotes[0].update, "2026-10-12T01:20:00Z");
  assert.equal(
    footballQuoteAvailability(quotes, "1", new Date("2026-10-13T00:00:00Z")),
    "recent",
  );
  assert.deepEqual(
    refreshPublishedOdds(raw, [{
      ...cached[0],
      query_params: { league: "3", season: "2026" },
    }]),
    raw.odds,
  );
  assert.deepEqual(
    refreshPublishedOdds(raw, [{
      ...cached[0],
      query_params: { league: "2", season: "2025" },
    }]),
    raw.odds,
  );
  assert.equal(
    marketAvailability(
      {
        sport: "football",
        kickoff: "2026-10-13T18:00:00Z",
        status: "NS",
        capturedAt: "2026-10-12T01:27:00Z",
      },
      "recent",
      0,
      new Date("2026-10-13T00:00:00Z"),
    ).reasons[0].code,
    "no_supported_candidate",
  );
});
