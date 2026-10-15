import assert from "node:assert/strict";
import { buildCatalog } from "./catalog.ts";
import { assessCandidate } from "./workshop.ts";
import { marketAvailability } from "./market_availability.ts";
import { ConversationReader } from "./conversation_tools.ts";
import {
  type ConversationPlan,
  initialIntent,
  rememberTurn,
} from "./conversation_memory.ts";
import { requestedCompetitions } from "./conversation_scope.ts";
import { context, intent, now, source } from "./evaluation_cases.ts";
import { obj, rows, type State } from "./contracts.ts";

Deno.test("old publications and prices remain readable and composable with original dates; invalid or future dates still fail", () => {
  const s = source();
  s.capturedAt = "2026-10-01T00:00:00Z";
  rows(obj(s.payload.raw).odds).forEach((q) =>
    q.update = "2026-10-02T00:00:00Z"
  );
  const cat = buildCatalog([s], context, intent.date, now);
  assert.ok(cat.candidates.length > 0);
  const c = cat.candidates[0];
  assert.equal(c.oddsAt, "2026-10-02T00:00:00Z");
  assert.equal(c.evidence[0].asOf, s.capturedAt);
  const assessment = assessCandidate(c, now);
  assert.deepEqual(assessment.exclusions, []);
  assert.match(
    assessment.warnings.join(" "),
    /Publication analytique ancienne/,
  );
  assert.match(assessment.warnings.join(" "), /Cote ancienne/);
  const availability = marketAvailability(
    {
      sport: c.sport,
      kickoff: c.kickoff,
      status: "NS",
      capturedAt: s.capturedAt,
    },
    "stale",
    1,
    now,
  );
  assert.equal(availability.prematchEligible, true);
  assert.deepEqual(availability.reasons, []);
  for (const oddsAt of ["invalid", "2026-10-12T00:00:00Z"]) {
    assert.ok(
      assessCandidate({ ...c, oddsAt }, now).exclusions.includes(
        "invalid_quote_date",
      ),
    );
  }
  const absent = structuredClone(s);
  delete obj(absent.payload.raw).odds;
  assert.equal(
    buildCatalog([absent], context, intent.date, now).candidates.length,
    0,
  );
});
Deno.test("explicit competition counts are separate from eight total matches; an explanation does not replace the scope", () => {
  assert.deepEqual(
    requestedCompetitions(
      "4 matchs d’Europa League et 4 de Conférence League uniquement",
    ),
    [
      { sport: "football", id: "3", selections: 4 },
      { sport: "football", id: "848", selections: 4 },
    ],
  );
  assert.equal(
    requestedCompetitions("Pourquoi pas la Champions League ?"),
    null,
  );
  assert.deepEqual(requestedCompetitions("Toutes les compétitions"), []);
});
Deno.test("clear focus cannot broaden an exclusive competition request: search, calculation and a follow-up preserve four plus four with old quotes", async () => {
  const s = source();
  s.capturedAt = "2026-10-01T00:00:00Z";
  const raw = obj(s.payload.raw),
    base = rows(raw.fixtures)[0],
    price = rows(raw.odds)[0],
    reading = rows(obj(s.payload.computed).fixtures)[0];
  raw.fixtures = [];
  raw.odds = [];
  obj(s.payload.computed).fixtures = [];
  for (let i = 1; i <= 9; i++) {
    const f = structuredClone(base);
    obj(f.fixture).id = i;
    obj(f.league).id = i <= 4 ? 3 : i <= 8 ? 848 : 253;
    obj(f.league).name = i <= 4
      ? "UEFA Europa League"
      : i <= 8
      ? "UEFA Conference League"
      : "MLS";
    obj(obj(f.teams).home).id = i * 2;
    obj(obj(f.teams).away).id = i * 2 + 1;
    (raw.fixtures as unknown[]).push(f);
    const q = structuredClone(price);
    obj(q.fixture).id = i;
    q.update = "2026-10-02T00:00:00Z";
    (raw.odds as unknown[]).push(q);
    const r = structuredClone(reading);
    r.fixture_id = i;
    rows(r.readings).forEach((e) =>
      e.subject_team_id = e.side === "home" ? i * 2 : i * 2 + 1
    );
    (obj(s.payload.computed).fixtures as unknown[]).push(r);
  }
  const ctx = {
    ...context,
    scope: "discovery" as const,
    configurationPolicy: "request" as const,
  };
  const r = new ConversationReader({
    context: ctx,
    date: intent.date,
    now,
    state: null,
    id: "age-scope",
    message:
      "Deux variantes avec 4 matchs d’Europa League et 4 de Conference League uniquement. 30€ chacune.",
  }, { sources: () => Promise.resolve([s]) });
  const q = obj(
    await r.execute("search_matches", {
      date: intent.date,
      sports: ["football"],
      view: "all",
      radarKind: "teams",
      query: null,
      offset: 0,
      limit: 60,
    }),
  );
  assert.equal(q.total, 8);
  assert.ok(
    rows(q.matches).every((m) =>
      ["3", "848"].includes(String(m.competitionId))
    ),
  );
  const p: ConversationPlan = {
    intent: {
      ...initialIntent(ctx, intent.date),
      action: "generate",
      sports: ["football"],
      view: "all",
      tickets: [0, 1].map(() => ({
        stake: 30,
        minimum: null,
        maximum: null,
        kind: "unspecified",
        minSelections: 8,
        maxSelections: 8,
      })),
    },
    changedFields: ["sports", "view", "tickets"],
    newTask: false,
    focusMode: "clear",
    focusKeys: [],
  };
  const res = obj(await r.execute("read_composition_options", { plan: p }));
  const preview = r.previews.get(String(res.projectionId))!;
  assert.equal(preview.next.tickets.length, 2);
  for (const t of preview.next.tickets) {
    for (const id of ["3", "848"]) {
      assert.equal(t.picks.filter((c) => c.competitionId === id).length, 4);
    }
  }
  rememberTurn(preview.next, null, preview.intent, [], []);
  const follow = new ConversationReader({
    context: ctx,
    date: intent.date,
    now,
    state: preview.next,
    id: "follow",
    message: "Change les marchés du deuxième ticket.",
  }, { sources: () => Promise.resolve([s]) });
  assert.deepEqual(
    follow.activeIntent().competitionScope,
    preview.intent.competitionScope,
  );
  const correction = new ConversationReader({
    context: ctx,
    date: intent.date,
    now,
    state: preview.next,
    id: "correction",
    message: "Uniquement Europa League et Conference League.",
  }, { sources: () => Promise.resolve([s]) });
  assert.deepEqual(
    correction.activeIntent().competitionScope,
    preview.intent.competitionScope,
  );
  const oldState = {
    ...preview.next,
    conversation: undefined,
    intent: {
      ...preview.intent,
      competitionScope: undefined,
      message: "4 matchs d’Europa League et 4 de Conference League.",
    },
  } as State;
  const oldSession = new ConversationReader({
    context: ctx,
    date: intent.date,
    now,
    state: oldState,
    id: "migration-free",
    message: "Uniquement Europa League et Conference League.",
  }, { sources: () => Promise.resolve([s]) });
  assert.deepEqual(
    oldSession.activeIntent().competitionScope,
    preview.intent.competitionScope,
  );
});
