import { type Json, obj } from "./contracts.ts";
import type { DayEvaluation } from "./match_evaluation.ts";

export interface CanaryConfiguration {
  enabled: boolean;
  userIds: string[];
  emails: string[];
  revision: string;
}
export function canaryConfiguration(
  get: (name: string) => string | undefined,
): CanaryConfiguration {
  const list = (name: string) =>
    (get(name) ?? "").split(",").map((s) => s.trim().toLowerCase()).filter(
      Boolean,
    );
  return {
    enabled: get("LECTOR_GENERATOR_CANARY_ENABLED") === "true",
    userIds: list("LECTOR_GENERATOR_CANARY_USER_IDS"),
    emails: list("LECTOR_GENERATOR_CANARY_EMAILS"),
    revision: get("LECTOR_RELEASE_REVISION") ?? "unversioned",
  };
}
export function canUseWorkshop(
  user: Json,
  config: CanaryConfiguration,
): boolean {
  if (!config.enabled || !/^[a-f0-9]{40}$/i.test(config.revision)) return false;
  // user is the verified /auth/v1/user response, never the request body.
  if (config.userIds.includes(String(user.id).toLowerCase())) return true;
  return typeof user.email === "string" &&
    typeof user.email_confirmed_at === "string" &&
    Number.isFinite(Date.parse(user.email_confirmed_at)) &&
    config.emails.includes(user.email.trim().toLowerCase());
}
export async function forwardLegacy(
  request: Request,
  body: string,
  projectUrl: string,
  publicKey: string,
  fetcher: typeof fetch = fetch,
): Promise<Response> {
  const origin = new URL(projectUrl);
  if (origin.protocol !== "https:" || origin.username || origin.password) {
    throw new Error("Invalid server origin");
  }
  const response = await fetcher(
    new URL("/functions/v1/lector-generator", origin),
    {
      method: "POST",
      redirect: "error",
      signal: AbortSignal.timeout(130000),
      headers: {
        authorization: request.headers.get("authorization") ?? "",
        apikey: publicKey,
        "content-type": "application/json",
      },
      body,
    },
  );
  // Do not forward service-role keys or upstream cookies.
  return new Response(response.body, {
    status: response.status,
    headers: {
      "content-type": response.headers.get("content-type") ??
        "application/json",
      "access-control-allow-origin": "*",
      "access-control-expose-headers":
        "x-lector-release-revision, x-lector-generator-mode",
      "x-lector-generator-mode": "legacy",
      "x-lector-release-revision":
        response.headers.get("x-lector-release-revision") ?? "legacy-unknown",
    },
  });
}
export function redactAuditText(value: string): string {
  return value.replace(/Bearer\s+[^\s"']+/gi, "Bearer [redacted]")
    .replace(/\bsk-[A-Za-z0-9_-]+/g, "[redacted-key]")
    .replace(
      /\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g,
      "[redacted-token]",
    );
}
export function requestAudit(
  input: Json,
  revision: string,
  workshop: boolean,
): Json {
  const context = obj(input.context);
  return {
    release: { revision, mode: workshop ? "workshop" : "legacy" },
    request: {
      requestId: input.requestId,
      action: input.action,
      date: input.date,
      view: context.view,
      timezone: context.timezone,
      sports: Object.keys(obj(context.preferences)),
      evaluationId: input.evaluationId,
      matchKeys: input.matchKeys,
      matchKey: input.matchKey,
      message: typeof input.message === "string"
        ? redactAuditText(input.message).slice(0, 8000)
        : null,
      // Audio, authorization, session tokens and provider bodies are never copied.
    },
  };
}
export function reportsAudit(reports: DayEvaluation[] | undefined): Json[] {
  return (reports ?? []).map((r) => ({
    reportId: r.id,
    queryId: r.queryId,
    scope: r.scope,
    criterion: r.criteria,
    model: r.model,
    found: r.expected,
    prepared: r.prepared,
    evaluated: r.evaluated,
    reused: r.reused ?? 0,
    complete: r.complete,
    batches: r.batches,
    elapsedMs: r.elapsedMs,
    selections: r.exploration?.selectedKeys ?? [],
    coverage: r.exploration?.coverage,
    evaluations: r.rows.map((x) => ({
      key: x.key,
      status: x.status,
      candidateId: x.candidateId,
      references: x.references,
      vigilanceReferences: x.vigilanceReferences,
    })),
    marketAvailability: r.snapshot?.sheets.map((s) => ({
      key: s.key,
      availability: s.match.marketAvailability,
    })),
    failures: r.failed.map((f) => ({
      keys: f.keys,
      reason: redactAuditText(f.reason),
    })),
  }));
}
