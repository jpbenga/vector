import assert from "node:assert/strict";
import { generatorHandler } from "./handler.ts";
import {
  evaluateFixture,
  explorationDay,
  modelResponse,
} from "./exploration_cases.ts";
import { evaluateMatches } from "./match_evaluation.ts";
import { now } from "./evaluation_cases.ts";
import {
  canaryConfiguration,
  canUseWorkshop,
  forwardLegacy,
  redactAuditText,
  requestAudit,
} from "./release.ts";

const revision = "a".repeat(40),
  user = {
    id: "verified-owner",
    email: "Owner@example.test",
    email_confirmed_at: "2026-10-14T00:00:00Z",
  };
Deno.test("archive comparison gets an owned audit ID without calling the real model", async () => {
  const fixture = await explorationDay(2);
  const evaluationId = crypto.randomUUID(), requestId = crypto.randomUUID();
  const report = await evaluateMatches({
    id: evaluationId,
    query: fixture.query,
    criteria: fixture.criterion.criteria,
    exploration: fixture.criterion,
    now,
    deadline: performance.now() + 10000,
  }, {
    key: "controlled",
    model: "gpt-6-luna",
    fetcher: (async (_u, init) =>
      modelResponse(
        evaluateFixture(JSON.parse(String(init?.body))),
      )) as typeof fetch,
  });
  const oldFetch = globalThis.fetch, oldGet = Deno.env.get;
  const owner = "11111111-1111-4111-8111-111111111111";
  let audited = 0;
  try {
    Deno.env.get = (name: string) =>
      ({
        LECTOR_GENERATOR_CANARY_ENABLED: "true",
        LECTOR_GENERATOR_CANARY_USER_IDS: owner,
        LECTOR_RELEASE_REVISION: revision,
        SUPABASE_URL: "https://project.test",
        SUPABASE_ANON_KEY: "public",
        SUPABASE_SERVICE_ROLE_KEY: "server",
      } as Record<string, string>)[name];
    globalThis.fetch = (async (url, init) => {
      const path = String(url);
      if (path.endsWith("/auth/v1/user")) return Response.json({ id: owner });
      if (path.endsWith("/rpc/lector_generator_session")) {
        return Response.json({ expired: false });
      }
      if (path.endsWith("/rpc/lector_generator_exploration_read")) {
        return Response.json(report);
      }
      assert.ok(path.endsWith("/rpc/lector_generator_request_audit_write"));
      const body = JSON.parse(String(init?.body));
      assert.equal(body.p_user, owner);
      assert.equal(body.p_request, requestId);
      assert.equal(body.p_usage.request.action, "exploration_compare");
      assert.equal(body.p_usage.auditReports[0].reportId, evaluationId);
      audited++;
      return Response.json(null);
    }) as typeof fetch;
    const response = await generatorHandler({ workshop: true })(
      new Request(
        "https://project.test/functions/v1/lector-generator-workshop",
        {
          method: "POST",
          headers: {
            authorization: "Bearer verified",
            "x-lector-client-revision": revision,
          },
          body: JSON.stringify({
            action: "exploration_compare",
            conversationId: crypto.randomUUID(),
            revision: 0,
            requestId,
            evaluationId,
            context: { view: "all" },
            matchKeys: report.rows.map((r) => r.key),
          }),
        },
      ),
    );
    assert.equal(
      response.status,
      200,
      JSON.stringify(await response.clone().json()),
    );
    assert.equal(response.headers.get("x-lector-request-id"), requestId);
    assert.equal((await response.json()).comparison.comparisons.length, 2);
    assert.equal(audited, 1);
  } finally {
    globalThis.fetch = oldFetch;
    Deno.env.get = oldGet;
  }
});
Deno.test("HTTP gate rejects spoofed account access and mismatched builds before any model or database call", async () => {
  const oldFetch = globalThis.fetch, oldGet = Deno.env.get;
  const owner = "11111111-1111-4111-8111-111111111111";
  const foreign = "22222222-2222-4222-8222-222222222222";
  let verified = foreign;
  const paths: string[] = [];
  try {
    Deno.env.get = (name: string) =>
      ({
        LECTOR_GENERATOR_CANARY_ENABLED: "true",
        LECTOR_GENERATOR_CANARY_USER_IDS: owner,
        LECTOR_RELEASE_REVISION: revision,
        SUPABASE_URL: "https://project.test",
        SUPABASE_ANON_KEY: "public",
      } as Record<string, string>)[name];
    globalThis.fetch = (async (url) => {
      paths.push(String(url));
      if (String(url).endsWith("/auth/v1/user")) {
        return Response.json({ id: verified });
      }
      assert.equal(
        String(url),
        "https://project.test/functions/v1/lector-generator",
      );
      return Response.json({ state: { tickets: [{ id: "preserved" }] } });
    }) as typeof fetch;
    const request = () =>
      new Request(
        "https://project.test/functions/v1/lector-generator-workshop",
        {
          method: "POST",
          headers: {
            authorization: "Bearer verified",
            "x-lector-client-revision": "b".repeat(40),
          },
          body: JSON.stringify({
            action: "chat",
            userId: owner,
            requestId: crypto.randomUUID(),
            message: "Hello",
          }),
        },
      );
    const handler = generatorHandler({ workshop: true });
    const legacy = await handler(request());
    assert.equal(legacy.headers.get("x-lector-generator-mode"), "legacy");
    assert.equal((await legacy.json()).state.tickets[0].id, "preserved");
    assert.equal(paths.length, 2);
    verified = owner;
    paths.length = 0;
    const mismatch = await handler(request());
    assert.equal(mismatch.status, 409);
    assert.equal(paths.length, 1);
  } finally {
    globalThis.fetch = oldFetch;
    Deno.env.get = oldGet;
  }
});
Deno.test("canary is disabled by default and requires a fixed revision and verified account", () => {
  const config = canaryConfiguration(() => undefined);
  assert.equal(canUseWorkshop(user, config), false);
  const ready = {
    ...config,
    enabled: true,
    revision,
    emails: ["owner@example.test"],
  };
  assert.equal(canUseWorkshop(user, ready), true);
  assert.equal(
    canUseWorkshop({ ...user, email_confirmed_at: null }, ready),
    false,
  );
  assert.equal(
    canUseWorkshop({ ...user, email: "foreign@example.test" }, ready),
    false,
  );
  assert.equal(
    canUseWorkshop(user, { ...ready, revision: "unversioned" }),
    false,
  );
  assert.equal(canUseWorkshop(user, { ...ready, enabled: false }), false);
  assert.equal(
    canUseWorkshop(user, { ...ready, emails: [], userIds: ["verified-owner"] }),
    true,
  );
});
Deno.test("non-canary fallback preserves request, authentication and response without a service key", async () => {
  const request = new Request(
    "https://project.test/functions/v1/lector-generator-workshop",
    {
      method: "POST",
      headers: { authorization: "Bearer existing-session" },
      body: '{"action":"read"}',
    },
  );
  const response = await forwardLegacy(
    request,
    '{"action":"read"}',
    "https://project.test",
    "public",
    (async (url, init) => {
      assert.equal(
        String(url),
        "https://project.test/functions/v1/lector-generator",
      );
      assert.equal(
        new Headers(init?.headers).get("authorization"),
        "Bearer existing-session",
      );
      assert.equal(new Headers(init?.headers).get("apikey"), "public");
      assert.equal(init?.body, '{"action":"read"}');
      return new Response('{"state":{"tickets":[{"id":"existing"}]}}', {
        status: 200,
      });
    }) as typeof fetch,
  );
  assert.equal(response.headers.get("x-lector-generator-mode"), "legacy");
  assert.equal((await response.json()).state.tickets[0].id, "existing");
});
Deno.test("request audit retains scope and revision but never authentication, voice or key material", () => {
  const audit = requestAudit(
    {
      requestId: "request",
      action: "chat",
      message: "Bearer token sk-secret",
      audio: "private-base64",
      authorization: "never-copy",
      context: {
        view: "all",
        timezone: "Europe/Paris",
        preferences: { hockey: {} },
      },
    },
    revision,
    true,
  );
  assert.deepEqual(audit.release, { revision, mode: "workshop" });
  assert.deepEqual((audit.request as any).sports, ["hockey"]);
  assert.ok(!JSON.stringify(audit).includes("private-base64"));
  assert.ok(!JSON.stringify(audit).includes("sk-secret"));
  assert.ok(!JSON.stringify(audit).includes("Bearer token"));
  assert.equal(redactAuditText("eyJabc.abc.signature"), "[redacted-token]");
});
