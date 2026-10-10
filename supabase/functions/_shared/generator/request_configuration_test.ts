import assert from "node:assert/strict";
import {
  type Context,
  contextFrom,
  type Intent,
  intentFrom,
  obj,
  rows,
  type State,
  validateIntent,
} from "./contracts.ts";
import { buildCatalog } from "./catalog.ts";
import { ConversationReader } from "./conversation_tools.ts";
import { resolvePlan, validatePlan } from "./conversation_memory.ts";
import { applyIntent } from "./service.ts";
import { context, intent, now, source } from "./evaluation_cases.ts";

const requestContext: Context = {
  ...context,
  budget: 100,
  configurationPolicy: "request",
  preferences: {
    football: { competitions: ["61"], readings: [], markets: [] },
  },
};
const targets = [[25, 8], [50, 6], [100, 3]].map(([stake, count]) => ({
  stake,
  minimum: null,
  maximum: null,
  kind: "unspecified" as const,
  minSelections: count,
  maxSelections: count,
}));
const requested: Intent = {
  ...intent,
  tickets: targets,
  maxSelections: 10,
  minSelections: null,
  goalMode: "unconstrained",
};
function tenMatchSource() {
  const s = source();
  const raw = obj(s.payload.raw);
  raw.fixtures = Array.from({ length: 12 }, (_, i) => ({
    ...rows(raw.fixtures)[0],
    fixture: { ...obj(rows(raw.fixtures)[0].fixture), id: i + 1 },
    teams: {
      home: { id: (i + 1) * 2, name: `Home ${i + 1}` },
      away: { id: (i + 1) * 2 + 1, name: `Away ${i + 1}` },
    },
  }));
  raw.odds = Array.from({ length: 12 }, (_, i) => ({
    fixture: { id: i + 1 },
    update: now.toISOString(),
    bookmakers: [{
      id: 1,
      name: "Test",
      bets: [{ id: 1, values: [{ value: "Home", odd: "1.50" }] }],
    }],
  }));
  obj(s.payload.computed).fixtures = Array.from({ length: 12 }, (_, i) => ({
    fixture_id: i + 1,
    readings: [{
      id: "strong_home_team",
      side: "home",
      subject_team_id: (i + 1) * 2,
      label: "Solide à domicile",
      sample_size: 5,
      evidence: [{ label: "Cinq victoires", value: "5" }],
    }],
  }));
  return s;
}
Deno.test("demo explicit stakes supersede the implicit 100-euro profile budget; production keeps its policy", () => {
  assert.equal(validateIntent(requested, requestContext, now), null);
  assert.match(
    validateIntent(requested, {
      ...requestContext,
      configurationPolicy: undefined,
    }, now)!,
    /plafond/,
  );
  assert.equal(contextFrom(requestContext).configurationPolicy, undefined);
  assert.equal(intentFrom(requested).tickets[0].maxSelections, 8);
  assert.throws(
    () =>
      intentFrom({
        ...requested,
        tickets: [{ ...targets[0], maxSelections: 21 }],
      }),
    /invalide/,
  );
});
Deno.test("empty reading and market settings do not hide verified choices; profile competition scope remains exact", () => {
  const source = tenMatchSource();
  assert.equal(
    buildCatalog([source], requestContext, intent.date, now).matchCount,
    12,
  );
  assert.equal(
    buildCatalog([source], requestContext, intent.date, now).candidates.length,
    12,
  );
  assert.equal(
    buildCatalog(
      [source],
      {
        ...requestContext,
        preferences: {
          football: { competitions: ["62"], readings: [], markets: [] },
        },
      },
      intent.date,
      now,
    ).matchCount,
    0,
  );
  obj(source.payload.raw).odds = [];
  assert.equal(
    buildCatalog([source], requestContext, intent.date, now).candidates.length,
    0,
  );
});
Deno.test("a top ten is the pool for three tickets with exactly eight, six and three matches and stakes of 25, 50 and 100", () => {
  const focus = Array.from(
    { length: 10 },
    (_, i) => ({
      sport: "football" as const,
      matchId: `api-fixture-${i + 1}`,
      match: `Home ${i + 1} — Away ${i + 1}`,
    }),
  );
  const previous: State = {
    id: "session",
    revision: 1,
    context,
    intent: requested,
    tickets: [],
    versions: [],
    pending: null,
    saved: false,
    updatedAt: now.toISOString(),
    messages: [],
    conversation: {
      version: 1,
      workingIntent: requested,
      focus,
      turns: [],
      olderTurns: 0,
      consultations: [],
    },
  };
  const resolved = resolvePlan(
    validatePlan({
      intent: requested,
      changedFields: ["tickets"],
      newTask: false,
      focusMode: "keep",
      focusKeys: [],
    }),
    previous,
    requestContext,
    intent.date,
  );
  assert.equal(resolved.preserveFixtures, false);
  const state = applyIntent({
    state: previous,
    context: requestContext,
    intent: resolved,
    sources: [tenMatchSource()],
    message: "Créer mes tickets",
    now,
    id: "session",
    workshop: true,
    conversationResolved: true,
  });
  assert.equal(state.tickets.length, 3);
  assert.deepEqual(state.tickets.map((t) => [t.stake, t.picks.length]), [
    [25, 8],
    [50, 6],
    [100, 3],
  ]);
  assert.equal(state.tickets.reduce((sum, t) => sum + t.stake, 0), 175);
  for (const t of state.tickets) {
    assert.ok(
      t.picks.every((p) => Number(p.matchId.replace("api-fixture-", "")) <= 10),
    );
    assert.equal(t.constraints!.minSelections, t.picks.length);
    assert.equal(t.constraints!.maxSelections, t.picks.length);
  }
});
Deno.test("conversation composition consultation returns distinct ticket counts without profile writes or a model call", async () => {
  const reader = new ConversationReader({
    context: requestContext,
    state: null,
    date: intent.date,
    now,
    id: "session",
    message: "Trois tickets",
  }, { sources: async () => [tenMatchSource()] });
  const before = structuredClone(requestContext);
  const response: any = await reader.execute("read_composition_options", {
    plan: {
      intent: requested,
      changedFields: ["tickets", "maxSelections", "sports", "date"],
      newTask: true,
      focusMode: "clear",
      focusKeys: [],
    },
  });
  assert.equal(response.clarification, null);
  assert.deepEqual(
    response.tickets.map((t: any) => [t.stake, t.picks.length]),
    [[25, 8], [50, 6], [100, 3]],
  );
  assert.deepEqual(requestContext, before);
  const profile: any = await reader.execute("read_profile", {});
  assert.equal(profile.budget, null);
  assert.equal(profile.savedBudgetHint, 100);
});

Deno.test("reducing a ticket conversationally overrides its original per-ticket count without changing its stake", () => {
  const working = {
    ...requested,
    tickets: [targets[0]],
    minSelections: null,
    maxSelections: 8,
  };
  const state: State = {
    id: "session",
    revision: 1,
    context: requestContext,
    intent: working,
    tickets: [],
    versions: [],
    pending: null,
    messages: [],
    saved: false,
    updatedAt: now.toISOString(),
  };
  const reduced = resolvePlan(
    {
      intent: { ...working, maxSelections: 5 },
      changedFields: ["maxSelections"],
      newTask: false,
      focusMode: "keep",
      focusKeys: [],
    },
    state,
    requestContext,
    intent.date,
  );
  assert.equal(reduced.tickets[0].stake, 25);
  assert.equal(reduced.tickets[0].maxSelections, 5);
  assert.equal(reduced.tickets[0].minSelections, null);
  assert.equal(validateIntent(reduced, requestContext, now), null);
});
