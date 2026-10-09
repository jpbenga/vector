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
      if (path === "/rest/v1/rpc/lector_generator_session") {
        return Promise.resolve(Response.json({ expired: false }));
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
      "/rest/v1/rpc/lector_generator_session",
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
for (const view of ["profile", "radar"] as const) {
  Deno.test(`workshop ${view} chat connects scoped sources, actual tool work, progress and an owner-only analysis commit`, async () => {
    const oldFetch = globalThis.fetch, oldGet = Deno.env.get;
    const owner = "00000000-0000-4000-8000-000000000002";
    const id = "00000000-0000-4000-8000-000000000001";
    const requestId = "00000000-0000-4000-8000-000000000003";
    const future = new Date();
    future.setUTCDate(future.getUTCDate() + 1);
    const date = future.toISOString().slice(0, 10);
    const publication = source();
    publication.id = "11111111-1111-4111-8111-111111111111";
    const requestContext = {
      ...context,
      radar: view === "radar"
        ? {
          football: {
            version: 1,
            mode: "players",
            category: "club",
            sourceIds: [publication.id],
            capturedAt: new Date().toISOString(),
            includeWomen: false,
            includeYouth: false,
            competitionId: null,
            teams: [{
              id: "2",
              teamId: "2",
              rank: 1,
              matchIds: ["10", "11", "12", "13", "14"],
            }],
            players: [],
          },
        }
        : undefined,
    };
    (publication.payload.raw as Record<string, unknown>).recent_league_matches =
      [{
        team: { id: 2, name: "Team" },
        league: { id: 61 },
        matches: [10, 11, 12, 13, 14].map((id, i) => ({
          fixture: {
            id,
            date: new Date(Date.now() - (6 - i) * 86400000).toISOString(),
          },
          result: "W",
        })),
      }];
    publication.capturedAt = new Date().toISOString();
    const raw = publication.payload.raw as {
      fixtures: { fixture: { date: string } }[];
      odds: { update: string }[];
    };
    raw.fixtures.forEach((f) => f.fixture.date = `${date}T18:00:00Z`);
    raw.odds.forEach((o) => o.update = publication.capturedAt);
    const parsed = {
      ...intent,
      action: "analyze",
      date,
      tickets: [],
      maxSelections: 5,
      view,
      radarKind: view === "radar" ? "teams" : "current",
    };
    let paid = 0, committed: unknown = null;
    const phases: string[] = [];
    try {
      Deno.env.get = (name: string) => ({
        SUPABASE_URL: "https://example.test",
        SUPABASE_ANON_KEY: "public",
        SUPABASE_SERVICE_ROLE_KEY: "server",
        OPENAI_API_KEY: "test",
        LECTOR_WORKSHOP_MODEL: "gpt-6.1-sol",
        LECTOR_WORKSHOP_ENABLED: "true",
      }[name]);
      globalThis.fetch = (async (url: unknown, init?: RequestInit) => {
        const u = new URL(String(url)),
          payload = init?.body ? JSON.parse(String(init.body)) : null;
        if (u.pathname === "/auth/v1/user") return Response.json({ id: owner });
        if (u.pathname === "/rest/v1/rpc/lector_generator_session") {
          return Response.json({ expired: false });
        }
        if (u.pathname === "/rest/v1/lector_generator_conversations") {
          assert.equal(u.searchParams.get("user_id"), `eq.${owner}`);
          return Response.json([]);
        }
        if (u.pathname === "/rest/v1/rpc/lector_generator_workshop_reserve") {
          return Response.json({ status: "reserved" });
        }
        if (u.pathname === "/rest/v1/lector_generator_turns") {
          assert.equal(u.searchParams.get("user_id"), `eq.${owner}`);
          if (init?.method === "PATCH") {
            phases.push(payload.usage.phase);
            return Response.json(null);
          }
          return Response.json([{ status: "pending" }]);
        }
        if (u.pathname === "/rest/v1/rpc/lector_generator_shared_sources") {
          assert.equal(view, "profile");
          assert.deepEqual(payload.p_competitions, ["61"]);
          return Response.json([publication]);
        }
        if (
          u.pathname === "/rest/v1/rpc/lector_generator_shared_radar_sources"
        ) {
          assert.equal(view, "radar");
          assert.deepEqual(payload.p_radar, requestContext.radar);
          assert.equal(payload.p_date, date);
          return Response.json([publication]);
        }
        if (u.pathname === "/rest/v1/rpc/match_reading_bilan_breakdown") {
          return Response.json([]);
        }
        if (u.pathname === "/rest/v1/rpc/lector_generator_commit") {
          assert.equal(payload.p_user, owner);
          assert.equal(payload.p_request, requestId);
          assert.equal(
            payload.p_state.messages.at(-1).analysis.context.view,
            view,
          );
          assert.equal(payload.p_state.tickets.length, 0);
          assert.equal(payload.p_usage.ai.length, 3);
          assert.ok(
            payload.p_usage.steps.some((s: { phase: string }) =>
              s.phase === "details"
            ),
          );
          committed = payload.p_state;
          return Response.json(payload.p_state);
        }
        if (u.hostname === "api.openai.com") {
          paid++;
          const response = (output: unknown[]) =>
            Response.json({
              id: `r-${paid}`,
              status: "completed",
              model: "gpt-6.1-sol",
              usage: { input_tokens: 20, output_tokens: 30 },
              output,
            });
          if (paid === 1) {
            return response([{
              type: "function_call",
              name: "search_matches",
              call_id: "search",
              arguments: JSON.stringify({
                date,
                sports: ["football"],
                view,
                radarKind: "teams",
                query: null,
                offset: 0,
                limit: 60,
              }),
            }]);
          }
          if (paid === 2) {
            return response([{
              type: "function_call",
              name: "read_matches",
              call_id: "details",
              arguments: '{"queryId":"q1","matchKeys":["football:1"]}',
            }]);
          }
          const content = JSON.stringify({
            plan: {
              intent: parsed,
              changedFields: [
                "date",
                "sports",
                "maxSelections",
                "view",
                "radarKind",
              ],
              newTask: true,
              focusMode: "clear",
              focusKeys: [],
            },
            queryId: "q1",
            projectionId: null,
            text: "Voici une rencontre à examiner.",
            analysis: {
              text: "Voici une rencontre à examiner.",
              selections: [{
                candidateId: `football:1:1:Home:1:${publication.id}`,
                reason: "La série à domicile soutient la victoire.",
                vigilance: "L’adversaire a un avantage au classement.",
                references: [
                  `${publication.id}:strong_home_team:2`,
                  ...(view === "radar"
                    ? ["radar:football:teams:2:2:10-11-12-13-14"]
                    : []),
                ],
              }],
              comparedMatchIds: ["football:1"],
              limitations: [],
            },
          });
          return response([{
            type: "message",
            content: [{ type: "output_text", text: content }],
          }]);
        }
        throw new Error(`Unexpected call ${u.pathname}`);
      }) as typeof fetch;
      const response = await generatorHandler({ workshop: true })(
        new Request("https://example.test", {
          method: "POST",
          headers: { authorization: "Bearer session-test" },
          body: JSON.stringify({
            action: "chat",
            conversationId: id,
            requestId,
            revision: 0,
            context: requestContext,
            date,
            message: "Top 5 dans Pour moi",
          }),
        }),
      );
      assert.equal(
        response.status,
        200,
        JSON.stringify(await response.clone().json()),
      );
      assert.ok(committed);
      assert.equal(paid, 3);
      assert.ok(phases.includes("details"));
    } finally {
      globalThis.fetch = oldFetch;
      Deno.env.get = oldGet;
    }
  });
}
Deno.test("retained choices use authenticated ownership and server identifiers; expired sessions cannot pay for a turn", async () => {
  const originalFetch = globalThis.fetch, originalGet = Deno.env.get;
  const owner = "11111111-1111-4111-8111-111111111111",
    conversation = "33333333-3333-4333-8333-333333333333";
  let expired = false;
  const requests: { path: string; body: any }[] = [];
  try {
    Deno.env.get = (
      key: string,
    ) => ({
      SUPABASE_URL: "https://example.test",
      SUPABASE_ANON_KEY: "public",
      SUPABASE_SERVICE_ROLE_KEY: "server",
    }[key]);
    globalThis.fetch = (async (url, init) => {
      const path = new URL(String(url)).pathname;
      const body = init?.body ? JSON.parse(String(init.body)) : {};
      requests.push({ path, body });
      if (path === "/auth/v1/user") return Response.json({ id: owner });
      if (path === "/rest/v1/rpc/lector_generator_session") {
        return Response.json({ expired });
      }
      if (path === "/rest/v1/rpc/lector_generator_keep") {
        return Response.json({ id: "saved", snapshot: { original: true } });
      }
      if (path === "/rest/v1/rpc/lector_generator_verify") {
        return Response.json(0);
      }
      if (path === "/rest/v1/rpc/lector_generator_decision_list") {
        return Response.json({ decisions: [], hasMore: false });
      }
      throw new Error("Unexpected path " + path);
    }) as typeof fetch;
    const handler = generatorHandler({ workshop: true });
    const invoke = (body: any) =>
      handler(
        new Request("https://example.test", {
          method: "POST",
          headers: { authorization: "Bearer token" },
          body: JSON.stringify(body),
        }),
      );
    const response = await invoke({
      action: "keep",
      conversationId: conversation,
      revision: 1,
      kind: "selection",
      sourceId: "real-id",
      choice: "follow",
      userId: "forged",
      snapshot: { odds: 99 },
    });
    assert.equal(response.status, 200);
    const keep = requests.find((r) =>
      r.path.endsWith("lector_generator_keep")
    )!.body;
    assert.equal(keep.p_user, owner);
    assert.equal(keep.p_source, "real-id");
    assert.equal(keep.snapshot, undefined);
    const list = await invoke({ action: "decisions", userId: "forged" });
    assert.equal(list.status, 200);
    assert.equal(
      requests.find((r) => r.path.endsWith("lector_generator_decision_list"))!
        .body.p_user,
      owner,
    );
    expired = true;
    requests.length = 0;
    const chat = await invoke({
      action: "chat",
      conversationId: conversation,
      revision: 1,
      message: "new",
      requestId: conversation,
    });
    assert.equal(chat.status, 410);
    assert.equal(requests.length, 2);
    assert.ok(!requests.some((r) => r.path.includes("reserve")));
    const read = await invoke({
      action: "read",
      conversationId: conversation,
      revision: 1,
    });
    assert.deepEqual(await read.json(), { state: null, expired: true });
  } finally {
    globalThis.fetch = originalFetch;
    Deno.env.get = originalGet;
  }
});
