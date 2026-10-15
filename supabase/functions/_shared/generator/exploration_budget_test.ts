import assert from "node:assert/strict";
import {
  ExplorationBudget,
  explorationBudgetConfig,
  explorationBudgetFromEnvironment,
} from "./exploration_budget.ts";
Deno.test("exploration budgets are configurable, validated and not read from process env in domain code", () => {
  const config = explorationBudgetFromEnvironment((key) =>
    ({
      LECTOR_EXPLORATION_INTERNAL_MS: "360000",
      LECTOR_EXPLORATION_EVALUATION_MS: "165000",
      LECTOR_EXPLORATION_DEEPENING_MS: "75000",
      LECTOR_EXPLORATION_MAX_DEEPENED: "2",
    } as Record<string, string>)[key]
  );
  assert.equal(config.internalMs, 360000);
  assert.equal(config.maxDeepened, 2);
  for (
    const bad of [
      { evaluationMs: NaN },
      { internalMs: 500 },
      { maxDeepened: 5 },
      { evaluationMs: 270000 },
      { finalizationMs: 330000 },
      { extraBatchCalls: -1 },
    ]
  ) {
    assert.throws(() => explorationBudgetConfig(bad));
  }
});
Deno.test("phase deadlines never consume the finalization reserve, and denied calls remain measured", () => {
  let now = 0;
  const budget = new ExplorationBudget({}, () => now);
  assert.equal(budget.evaluationDeadline(600000), 135000);
  assert.equal(budget.workDeadline, 225000);
  for (let i = 0; i < 7; i++) assert.equal(budget.claimBatch(7), true);
  assert.equal(budget.claimBatch(7), false);
  assert.equal(budget.snapshot().evaluationCalls, 7);
  now = 225000;
  assert.equal(budget.claimBatch(20), false);
  assert.equal(
    budget.admitDeepening("football:1", "explicit_comparison", true),
    false,
  );
  assert.equal(budget.snapshot().deepened, 0);
});
Deno.test("only four justified distinct deepenings fit one exchange and a new exchange receives its own budget", () => {
  let now = 100;
  const budget = new ExplorationBudget({}, () => now);
  assert.equal(
    budget.admitDeepening("football:0", "boundary_tie", false),
    false,
  );
  for (let i = 1; i <= 4; i++) {
    assert.equal(
      budget.admitDeepening(`football:${i}`, "relevant_conflict", true),
      true,
    );
  }
  assert.equal(
    budget.admitDeepening("football:5", "explicit_comparison", true),
    false,
  );
  assert.equal(budget.snapshot().deepened, 4);
  now += 60001;
  assert.equal(
    budget.admitDeepening("hockey:8", "missing_decisive_fact", true),
    false,
  );
  const next = new ExplorationBudget({}, () => now);
  assert.equal(
    next.admitDeepening("football:5", "explicit_comparison", true),
    true,
  );
  assert.equal(next.snapshot().evaluationCalls, 0);
});
