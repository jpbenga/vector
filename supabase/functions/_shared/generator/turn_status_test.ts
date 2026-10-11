import assert from "node:assert/strict";
import { generatorHandler } from "./handler.ts";
import { canReadTurnResponse, turnStatus } from "./turn_status.ts";
import { obj } from "./contracts.ts";

Deno.test("turn recovery returns the stored response only after completion", () => {
  const state = {
    id: "conversation",
    revision: 4,
    tickets: [{ id: "original" }],
  };
  assert.deepEqual(
    turnStatus({ status: "complete", response: state }, true).state,
    state,
  );
  for (const status of ["pending", "failed", "cancelled"]) {
    assert.equal(
      turnStatus({ status, response: state }, true).state,
      undefined,
    );
  }
  assert.equal(obj(turnStatus(undefined, true).turn).status, "starting");
});

Deno.test("failure status uses a safe explanation and never leaks a provider exception", () => {
  const failed = turnStatus({
    status: "failed",
    usage: {
      failure_message: "private provider response https://private.test/key",
    },
  }, true);
  assert.match(String(obj(failed.turn).error), /arrêtée côté serveur/);
  assert.ok(!JSON.stringify(failed).includes("private"));
  const timedOut = turnStatus({
    status: "failed",
    usage: {
      failure_name: "TimeoutError",
      failure_stage: "conversation/model/2",
    },
  }, true);
  assert.match(
    String(obj(timedOut.turn).error),
    /réponse IA a dépassé le délai/,
  );
});

Deno.test("authenticated recovery reads only the requested owner's conversation turn", async () => {
  const user = "11111111-1111-4111-8111-111111111111";
  const conversation = "22222222-2222-4222-8222-222222222222";
  const requestId = "33333333-3333-4333-8333-333333333333";
  const state = { id: conversation, revision: 4, tickets: [{ id: "ticket" }] };
  const calls: string[] = [];
  const originalFetch = globalThis.fetch;
  try {
    for (
      const scenario of [
        { includeResult: true, valid: true, exists: true },
        { includeResult: false, valid: true, exists: true },
        { includeResult: true, valid: false, exists: true },
        { includeResult: true, valid: true, exists: false },
      ]
    ) {
      calls.length = 0;
      globalThis.fetch = ((url) => {
        const path = String(url);
        calls.push(path);
        if (path.endsWith("/auth/v1/user")) {
          return Promise.resolve(Response.json({ id: user }));
        }
        assert.ok(path.includes(`user_id=eq.${user}`));
        if (path.includes("lector_generator_conversations?")) {
          assert.ok(path.includes(`id=eq.${conversation}`));
          assert.ok(path.includes("select=mode,expires_at,updated_at"));
          const session = {
            mode: "workshop",
            expires_at: new Date(Date.now() + (scenario.valid ? 3600000 : -1))
              .toISOString(),
          };
          return Promise.resolve(
            Response.json(scenario.exists ? [session] : []),
          );
        }
        assert.ok(path.includes(`request_id=eq.${requestId}`));
        assert.ok(path.includes(`conversation_id=eq.${conversation}`));
        assert.equal(path.includes(",response"), scenario.includeResult);
        return Promise.resolve(Response.json([{
          status: "complete",
          ...(scenario.includeResult ? { response: state } : {}),
        }]));
      }) as typeof fetch;
      const result = await generatorHandler({ workshop: true })(
        new Request("https://function.test", {
          method: "POST",
          headers: {
            authorization: "Bearer test-session",
            "content-type": "application/json",
          },
          body: JSON.stringify({
            action: "status",
            conversationId: conversation,
            requestId,
            revision: 3,
            includeResult: scenario.includeResult,
          }),
        }),
      );
      const expired = scenario.includeResult &&
        (!scenario.valid || !scenario.exists);
      assert.equal(
        result.status,
        expired ? 410 : 200,
        JSON.stringify(await result.clone().json()),
      );
      assert.equal(result.headers.get("access-control-allow-origin"), "*");
      const body = await result.json();
      assert.deepEqual(
        body.state,
        scenario.includeResult && !expired ? state : undefined,
      );
      if (expired) assert.equal(body.expired, true);
      assert.equal(calls.length, scenario.includeResult ? 3 : 2);
    }
  } finally {
    globalThis.fetch = originalFetch;
  }
});

Deno.test("turn response recovery cannot bypass expired or deleted sessions", () => {
  const now = new Date("2026-10-11T00:00:00Z");
  assert.equal(canReadTurnResponse(undefined, now), false);
  assert.equal(
    canReadTurnResponse({ mode: "workshop", expires_at: "invalid" }, now),
    false,
  );
  assert.equal(
    canReadTurnResponse(
      { mode: "workshop", expires_at: now.toISOString() },
      now,
    ),
    false,
  );
  assert.equal(
    canReadTurnResponse({
      mode: "workshop",
      expires_at: "2026-10-11T01:00:00Z",
    }, now),
    true,
  );
  assert.equal(
    canReadTurnResponse(
      { mode: "legacy", updated_at: "2026-10-09T12:00:00Z" },
      now,
    ),
    false,
  );
  assert.equal(
    canReadTurnResponse(
      { mode: "legacy", updated_at: "2026-10-10T12:00:00Z" },
      now,
    ),
    true,
  );
});

Deno.test("browser preflight and authentication errors both carry CORS headers", async () => {
  const handler = generatorHandler({ workshop: true });
  const preflight = await handler(
    new Request("https://function.test", { method: "OPTIONS" }),
  );
  assert.equal(preflight.status, 200);
  assert.ok(
    preflight.headers.get("access-control-allow-headers")?.includes(
      "authorization",
    ),
  );
  const unauthorized = await handler(
    new Request("https://function.test", {
      method: "POST",
      body: "{}",
    }),
  );
  assert.equal(unauthorized.status, 401);
  assert.equal(unauthorized.headers.get("access-control-allow-origin"), "*");
});
