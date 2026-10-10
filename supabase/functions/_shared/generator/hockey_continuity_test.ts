import assert from "node:assert/strict";
import { buildCatalog, type Source } from "./catalog.ts";
import { applyIntent, resolveIntent } from "./service.ts";
import { validateAnalysis } from "./analysis.ts";
import { type Analysis, type Context, type State } from "./contracts.ts";
import {
  context as footballContext,
  intent,
  now as footballNow,
  source as footballSource,
} from "./evaluation_cases.ts";
import { hockeyQuoteRecords } from "../sports/hockey_odds.ts";
import {
  oddsPayload,
  quoteAt,
  quotedFixture,
} from "../sports/hockey_odds_test.ts";

const now = new Date(quoteAt), at = "2026-10-09T10:01:00Z";
const context: Context = {
  origin: "profile",
  scope: "strict",
  timezone: "Europe/Paris",
  budget: 50,
  preferences: {
    hockey: {
      competitions: ["hockey:api-hockey:competition:35"],
      readings: ["winning_streak"],
      markets: ["result_regulation", "double_chance_regulation"],
    },
  },
};
const source = (): Source => ({
  id: "publication",
  sport: "hockey",
  capturedAt: quoteAt,
  payload: {
    items: [{
      ...quotedFixture,
      quotesCollectedAt: quoteAt,
      quotes: hockeyQuoteRecords(
        oddsPayload(),
        [quotedFixture],
        "35",
        "2026",
        quoteAt,
      )[0].quotes,
      readings: [{
        id: "winning_streak",
        subject_team_id: "2",
        explanation: "Three final wins",
        sample_size: 3,
      }],
    }],
  },
});
const request = {
  ...intent,
  date: "2026-10-09",
  sports: ["hockey" as const],
  tickets: [{
    stake: 20,
    minimum: null,
    maximum: null,
    kind: "unspecified" as const,
  }],
  goalMode: "unconstrained" as const,
  maxSelections: 3,
  referenceAnalysisAt: at,
};
function state(analysis: Analysis): State {
  return {
    id: "s",
    revision: 1,
    context,
    intent: { ...request, action: "analyze", tickets: [] },
    tickets: [],
    versions: [],
    pending: null,
    messages: [{ role: "assistant", at, text: analysis.text, analysis }],
    saved: false,
    updatedAt: at,
  };
}
function observed(): Analysis {
  const catalog = buildCatalog([source()], context, request.date, now),
    m = catalog.matches![0];
  return validateAnalysis({
    text: "Home — Away retained",
    selections: [],
    observations: [{
      matchId: m.id,
      reason: "Série positive",
      references: [m.evidence[0].id],
    }],
    comparedMatchIds: [m.id],
    limitations: [],
  }, {
    context: {
      date: request.date,
      view: "profile",
      sports: ["hockey"],
      matchCount: 1,
      candidateCount: 2,
    },
    byMatch: new Map([[m.id, m]]),
    byCandidate: new Map(catalog.candidates.map((c) => [c.id, c])),
    detailsRead: new Set([m.id]),
    limit: 3,
    missing: [],
  });
}
Deno.test("hockey markets require opt-in, real fresh quotes and direct subject support", () => {
  const catalog = buildCatalog([source()], context, request.date, now);
  assert.equal(catalog.candidates.length, 2);
  assert.ok(
    catalog.candidates.every((c) =>
      c.scope === "regulation" && c.selection.includes("60 minutes")
    ),
  );
  assert.equal(catalog.matches![0].quoteAvailability, "recent");
  const noMarkets = structuredClone(context);
  noMarkets.preferences.hockey!.markets = [];
  assert.equal(
    buildCatalog([source()], noMarkets, request.date, now).candidates.length,
    0,
  );
  const stale = source();
  (stale.payload.items as any[])[0].quotes.forEach((
    q: { capturedAt: string },
  ) => q.capturedAt = "2026-10-01T10:00:00Z");
  assert.equal(
    buildCatalog([stale], context, request.date, now).candidates.length,
    0,
  );
  const negative = source();
  (negative.payload.items as any[])[0].readings.push({
    id: "negative_streak",
    subject_team_id: "2",
    sample_size: 5,
  });
  const pref = structuredClone(context);
  pref.preferences.hockey!.readings.push("negative_streak");
  assert.equal(
    buildCatalog([negative], pref, request.date, now).candidates.length,
    0,
  );
});
Deno.test("analysis → first hockey ticket, including a stake clarification, keeps retained fixtures only", () => {
  const before = state(observed());
  const clarification = resolveIntent({
    ...request,
    action: "clarify",
    tickets: [{ ...request.tickets[0], stake: null }],
  }, before);
  assert.equal(clarification.fixtureFocus![0].matchId, "100");
  before.pendingIntent = clarification;
  const result = applyIntent({
    state: before,
    context,
    intent: request,
    sources: [source()],
    message: "20 euros",
    now,
    id: "s",
    workshop: true,
  });
  assert.equal(result.tickets.length, 1);
  assert.deepEqual(result.tickets[0].picks.map((p) => p.matchId), ["100"]);
  assert.equal(result.tickets[0].stake, 20);
  const missing = source();
  const other = structuredClone((missing.payload.items as any[])[0]);
  other.id = "101";
  other.home = { id: "4", name: "Other home" };
  other.away = { id: "5", name: "Other away" };
  other.readings[0].subject_team_id = "4";
  (missing.payload.items as any[]).push(other);
  (missing.payload.items as any[])[0].quotes = [];
  const failed = applyIntent({
    state: before,
    context,
    intent: request,
    sources: [missing],
    message: "20 euros",
    now,
    id: "s",
    workshop: true,
  });
  assert.equal(failed.tickets.length, 0);
  assert.match(failed.messages.at(-1)!.text, /Home — Away/);
  assert.match(failed.messages.at(-1)!.text, /n’ajoute pas d’autres matchs/);
  assert.equal(
    resolveIntent({ ...request, date: "2026-10-10" }, before).action,
    "clarify",
  );
  assert.equal(
    resolveIntent({ ...request, referenceAnalysisAt: null }, before)
      .fixtureFocus,
    undefined,
  );
});
Deno.test("football analysis → ticket preserves choices, not every examined match", () => {
  const catalog = buildCatalog(
      [footballSource()],
      footballContext,
      intent.date,
      footballNow,
    ),
    c = catalog.candidates[0];
  const analysis: Analysis = {
    context: {
      date: intent.date,
      view: "profile",
      sports: ["football"],
      matchCount: 4,
      candidateCount: 8,
    },
    text: "One retained",
    selections: [{
      candidate: c,
      reason: "Supported",
      vigilance: "Check",
      references: [c.evidence[0].id],
    }],
    comparedMatchIds: ["1", "2", "3", "4"],
    limitations: [],
  };
  const before = { ...state(analysis), context: footballContext };
  const result = applyIntent({
    state: before,
    context: footballContext,
    intent: {
      ...intent,
      tickets: [{
        stake: 20,
        minimum: null,
        maximum: null,
        kind: "unspecified",
      }],
      goalMode: "unconstrained",
      referenceAnalysisAt: at,
    },
    sources: [footballSource()],
    message: "Ticket là-dessus",
    now: footballNow,
    id: "s",
    workshop: true,
  });
  assert.deepEqual(result.tickets[0].picks.map((p) => p.matchId), [c.matchId]);
});

Deno.test("demo hockey uses published readings and supported quotes without market or reading opt-in", () => {
  const unconfigured: Context = {
    ...context,
    configurationPolicy: "request",
    scope: "discovery",
    view: "all",
    preferences: { hockey: { competitions: [], readings: [], markets: [] } },
  };
  const catalog = buildCatalog([source()], unconfigured, request.date, now);
  assert.equal(catalog.candidates.length, 2);
  assert.equal(catalog.matchCount, 1);
  const expired = source();
  (expired.payload.items as any[])[0].quotes.forEach((q: any) =>
    q.capturedAt = "2026-10-01T10:00:00Z"
  );
  assert.equal(
    buildCatalog([expired], unconfigured, request.date, now).candidates.length,
    0,
  );
});
