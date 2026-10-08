import assert from "node:assert/strict";
import { type State } from "./contracts.ts";
import { applyIntent } from "./service.ts";
import { compositionKey } from "./engine.ts";
import { interpret } from "./openai.ts";
import { type ModelReceipt, receiptFor } from "./models.ts";
import {
  attachReview,
  buildReviewBrief,
  fallbackReview,
  validateReview,
} from "./review.ts";
import { reviseWorkshop } from "./compositions.ts";
import { generatorHandler } from "./handler.ts";

import { context, intent, now, source } from "./evaluation_cases.ts";
function generate(state: State | null = null, request = intent) {
  return applyIntent({
    state,
    context,
    intent: request,
    sources: [source()],
    message: "Demande de test",
    now,
    id: "test",
    workshop: true,
  });
}
Deno.test("workshop service proposes alternatives for ONE stake and carries market vigilance", () => {
  const state = generate();
  assert.ok(state.proposals!.length > 1);
  assert.equal(state.tickets.length, 1);
  assert.equal(state.tickets[0].stake, 50);
  assert.ok(
    state.tickets[0].picks.every((p) =>
      p.evidence.some((e) => e.role === "vigilance")
    ),
  );
  assert.ok(
    state.tickets[0].returnTotal >= 270 && state.tickets[0].returnTotal <= 330,
  );
  const brief = buildReviewBrief(state.proposals!, now);
  attachReview(state.proposals!, fallbackReview(brief), brief);
  assert.ok(
    state.proposals!.every((t) =>
      t.workshop!.notes.some((n) => n.text.includes("vigilance"))
    ),
  );
  assert.ok(state.proposals![1].workshop!.comparedTo!.number > 0);
});
Deno.test("another composition remembers ALL displayed alternatives and keeps the frozen budget", () => {
  const before = generate();
  const after = generate(before, {
    ...intent,
    action: "alternative",
    referenceTicketId: before.tickets[0].id,
    preserveConstraints: true,
  });
  const old = new Set(before.proposals!.map((t) => compositionKey(t.picks)));
  for (const t of after.proposals ?? []) {
    assert.ok(!old.has(compositionKey(t.picks)));
  }
  assert.equal(after.tickets[0].id, before.tickets[0].id);
  assert.equal(after.context.budget, 50);
});
Deno.test("explicit same-fixture instruction preserves ALL encounters with new market arguments", () => {
  const before = generate();
  const after = generate(before, {
    ...intent,
    action: "alternative",
    referenceTicketId: before.tickets[0].id,
    preserveConstraints: true,
    preserveFixtures: true,
  });
  for (const t of after.proposals ?? []) {
    assert.deepEqual(
      t.picks.map((p) => p.matchId).sort(),
      before.tickets[0].picks.map((p) => p.matchId).sort(),
    );
  }
});
Deno.test("review rejects cross-ticket or invented facts and does not accept a support-only analysis", () => {
  const state = generate(),
    brief = buildReviewBrief(state.proposals!, now),
    review = fallbackReview(brief);
  assert.deepEqual(validateReview({ variants: review }, brief), review);
  assert.throws(() =>
    validateReview({
      variants: review.map((v, i) =>
        i ? v : { ...v, factIds: ["invented", "probability-70-percent"] }
      ),
    }, brief)
  );
  assert.throws(() =>
    validateReview({
      variants: review.map((v, i) =>
        i ? v : {
          ...v,
          factIds: [
            brief.facts.find((f) => f.ticketId === review[1].ticketId)!.id,
            v.factIds[1],
          ],
        }
      ),
    }, brief)
  );
});
Deno.test("both selected models use low reasoning and receipts retain failed/incomplete paid usage", async () => {
  for (const model of ["gpt-6.1-sol", "gpt-6-luna"]) {
    let body: Record<string, unknown> = {}, receipt: ModelReceipt | undefined;
    await interpret({
      message: "test",
      date: intent.date,
      context,
      state: null,
      today: "2026-10-08",
    }, {
      key: "test",
      model,
      onReceipt: (r) => receipt = r,
      fetcher: ((_url, init) => {
        body = JSON.parse(String(init?.body));
        return Promise.resolve(Response.json({
          id: "response-test",
          model,
          status: "completed",
          output: [{
            content: [{ type: "output_text", text: JSON.stringify(intent) }],
          }],
          usage: {
            input_tokens: 100,
            output_tokens: 150,
            output_tokens_details: { reasoning_tokens: 50 },
          },
        }));
      }) as typeof fetch,
    });
    assert.deepEqual(body.reasoning, { effort: "low" });
    assert.equal(body.tools, undefined);
    assert.equal(body.store, false);
    assert.equal(receipt!.reasoningTokens, 50);
    assert.equal(receipt!.outputTokens, 150);
    const incomplete = receiptFor(model, "interpret", {
      status: "incomplete",
      usage: { input_tokens: 100, output_tokens: 50 },
    }, 10);
    assert.ok(incomplete.estimatedUsd!.minimum > 0);
    assert.equal(receiptFor(model, "interpret", {}, 10).estimatedUsd, null);
  }
});
Deno.test("workshop endpoint rejects anonymous access before any database or model request", async () => {
  const response = await generatorHandler({ workshop: true })(
    new Request("https://example.test", { method: "POST", body: "{}" }),
  );
  assert.equal(response.status, 401);
});
Deno.test("workshop handler uses its uncapped reservation and replays without a paid call", async () => {
  const oldFetch = globalThis.fetch, oldGet = Deno.env.get;
  const paths: string[] = [];
  const userId = "00000000-0000-4000-8000-000000000002";
  const conversationId = "00000000-0000-4000-8000-000000000001";
  const requestId = "00000000-0000-4000-8000-000000000003";
  try {
    Deno.env.get = (name: string) => ({
      SUPABASE_URL: "https://example.test",
      SUPABASE_ANON_KEY: "public-test",
      SUPABASE_SERVICE_ROLE_KEY: "server-test",
      OPENAI_API_KEY: "test-key",
      LECTOR_WORKSHOP_MODEL: "gpt-6-luna",
      LECTOR_WORKSHOP_ENABLED: "true",
    }[name]);
    globalThis.fetch = ((url) => {
      const path = new URL(String(url)).pathname;
      paths.push(path);
      if (path === "/auth/v1/user") {
        return Promise.resolve(Response.json({ id: userId }));
      }
      if (path === "/rest/v1/lector_generator_conversations") {
        return Promise.resolve(Response.json([]));
      }
      if (path === "/rest/v1/rpc/lector_generator_workshop_reserve") {
        return Promise.resolve(
          Response.json({
            status: "succeeded",
            cached: { id: conversationId, revision: 1 },
          }),
        );
      }
      throw new Error(`Unexpected call ${path}`);
    }) as typeof fetch;
    const response = await generatorHandler({ workshop: true })(
      new Request("https://example.test", {
        method: "POST",
        headers: {
          authorization: "Bearer session-test",
          "content-type": "application/json",
        },
        body: JSON.stringify({
          action: "chat",
          conversationId,
          requestId,
          revision: 0,
          date: "2026-10-10",
          context,
          message: "Demande déjà traitée",
        }),
      }),
    );
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), {
      state: { id: conversationId, revision: 1 },
    });
    assert.deepEqual(paths, [
      "/auth/v1/user",
      "/rest/v1/lector_generator_conversations",
      "/rest/v1/rpc/lector_generator_workshop_reserve",
    ]);
  } finally {
    globalThis.fetch = oldFetch;
    Deno.env.get = oldGet;
  }
});
Deno.test("targeted substitution keeps other picks; removal does not fabricate replacement results", () => {
  const state = generate(), t = state.tickets[0];
  const available = state.proposals!.flatMap((p) => p.picks);
  const removed = reviseWorkshop(
    [t],
    { ...intent, action: "remove", ticketIndex: 0, selectionIndex: 0 },
    available,
    now,
  );
  assert.ok(removed);
  assert.equal(removed[0].stake, 50);
  assert.deepEqual(removed[0].picks, t.picks.slice(1));
  assert.equal(t.picks.length, removed[0].picks.length + 1);
});
