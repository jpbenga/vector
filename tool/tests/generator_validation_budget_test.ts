import assert from "node:assert/strict";
import { ValidationCallBudget } from "../generator_validation_budget.ts";
Deno.test("validation rejects a call before dispatch at its money or call bound and keeps unknown usage reserved", () => {
  const request = JSON.stringify({
    input: "Publication",
    max_output_tokens: 6000,
  });
  const budget = new ValidationCallBudget(1, 1, 1, 1),
    first = budget.admit(request);
  assert.ok(first > 0);
  assert.throws(() => budget.admit(request));
  assert.equal(budget.calls, 1);
  assert.equal(budget.reservedUsd, first);
  const tiny = new ValidationCallBudget(.000001, 20, 1, 1);
  assert.throws(() => tiny.admit(request));
  assert.equal(tiny.calls, 0);
  assert.throws(() => new ValidationCallBudget(NaN, 1, 1, 1));
  assert.throws(() => new ValidationCallBudget(1, 50, 1, 1));
  assert.throws(() =>
    new ValidationCallBudget(1, 1, 1, 1).admit(
      JSON.stringify({ max_output_tokens: 7000 }),
    )
  );
});
