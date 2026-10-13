import assert from "node:assert/strict";
import { mixedDay } from "./match_evaluation_cases.ts";
import { intent, now } from "./evaluation_cases.ts";
import { ConversationReader } from "./conversation_tools.ts";
import { type DayEvaluation, evaluateMatches } from "./match_evaluation.ts";
import {
  buildExplorationReport,
  explainExplorationChoice,
  explorationCriterion,
} from "./exploration.ts";
import { compareExploration } from "./exploration_continuity.ts";
import { evaluateFixture, modelResponse } from "./exploration_cases.ts";
import { buildCatalog } from "./catalog.ts";
import { applyIntent, resolveIntent } from "./service.ts";
import { obj, rows } from "./contracts.ts";

Deno.test("hockey C/D: exploration, comparison, explanations, resume, targeted refresh and regulation composition", async () => {
  const fixture = await mixedDay();
  const context = {
    ...fixture.context,
    preferences: { hockey: fixture.context.preferences.hockey! },
  };
  let publication = structuredClone(fixture.sources[1]);
  publication.payload.items = rows(publication.payload.items).slice(0, 6);
  let saved: DayEvaluation | undefined, calls = 0;
  const options = {
    model: "gpt-6-luna",
    key: "controlled",
    deadline: performance.now() + 110000,
    fetcher: (async (_url, init) => {
      calls++;
      return modelResponse(evaluateFixture(JSON.parse(String(init?.body))));
    }) as typeof fetch,
    onEvaluation: async (r: DayEvaluation) => {
      saved = structuredClone(r);
    },
  };
  const reader = (previous?: DayEvaluation) =>
    new ConversationReader(
      {
        id: "hockey-release",
        context,
        date: "2026-10-10",
        now,
        state: null,
        message: "Six rencontres de hockey selon les lectures publiées",
      },
      {
        sources: async () => [publication],
        evaluation: async () => previous ?? saved ?? null,
      },
      async () => {},
      options,
    );
  const q = await reader().query("2026-10-10", ["hockey"], "all", "teams");
  assert.equal(q.matches.length, 6);
  assert.ok(q.catalog.candidates.every((c) => c.scope === "regulation"));
  const criterion = explorationCriterion({
    query: q,
    request: "Six rencontres",
    criteria: "lectures publiées",
    observationCount: 6,
    useProfileReadings: true,
    formScope: "competition",
  });
  const initial = await evaluateMatches({
    id: crypto.randomUUID(),
    query: q,
    criteria: criterion.criteria,
    exploration: criterion,
    now,
    deadline: options.deadline,
  }, options);
  initial.rows = initial.rows.slice(0, 2);
  initial.evaluated = 2;
  initial.complete = false;
  initial.failed = [{
    keys: initial.snapshot!.sheets.slice(2).map((s) => s.key),
    reason: "Interruption locale contrôlée",
  }];
  initial.exploration = await buildExplorationReport(
    initial,
    initial.snapshot!.sheets,
    criterion,
    now,
  );
  const frozen = JSON.stringify(initial), before = calls;
  const keys = initial.rows.map((r) => r.key);
  assert.equal(compareExploration(initial, keys).comparisons.length, 2);
  assert.ok(explainExplorationChoice(initial, keys[0]).decision);
  assert.equal(calls, before); // archive read must not bill an AI call
  await reader(initial).execute("continue_match_evaluation", {
    evaluationId: initial.id,
  });
  const resumed = saved!;
  assert.equal(resumed.evaluated, 6);
  assert.equal(resumed.reused, 2);
  assert.equal(
    compareExploration(resumed, resumed.rows.slice(0, 4).map((r) => r.key))
      .comparisons.length,
    4,
  );
  publication = structuredClone(publication);
  publication.id = "new-hockey-publication";
  rows(rows(publication.payload.items)[0].readings)[0].explanation =
    "Quatre victoires finales sur cinq matchs publiés.";
  await reader(resumed).execute("reevaluate_exploration", {
    evaluationId: resumed.id,
  });
  assert.equal(saved!.reused, 5);
  assert.deepEqual(saved!.version!.changedKeys, ["hockey:1"]);
  assert.equal(JSON.stringify(initial), frozen);
  const catalog = buildCatalog([publication], context, "2026-10-10", now);
  const request = {
    ...intent,
    sports: ["hockey" as const],
    tickets: [{
      stake: 20,
      minimum: null,
      maximum: null,
      kind: "unspecified" as const,
    }],
    goalMode: "unconstrained" as const,
    maxSelections: 3,
  };
  const result = applyIntent({
    state: null,
    id: "hockey-release",
    context,
    sources: [publication],
    intent: resolveIntent(request, null),
    catalog,
    now,
    message: "Trois sélections de hockey, règlement à 60 minutes",
    workshop: true,
  });
  assert.ok(result.tickets.length > 0);
  assert.ok(result.tickets[0].picks.length > 0);
  assert.ok(
    result.tickets[0].picks.every((p) =>
      p.scope === "regulation" && p.sport === "hockey"
    ),
  );
  assert.equal(
    result.tickets[0].totalOdds,
    Math.round(result.tickets[0].picks.reduce((n, p) => n * p.odds, 1) * 100) /
      100,
  );
  const stale = buildCatalog(
    [publication],
    context,
    "2026-10-10",
    new Date(now.getTime() + 37 * 3600000),
  );
  assert.equal(stale.candidates.length, 0); // quote availability cannot override 36h sports freshness
});
