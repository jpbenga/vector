type JsonObject = Record<string, unknown>;

const corsHeaders = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers":
    "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "GET, POST, OPTIONS",
};

type AdminIdentity = {
  id: string;
  email: string;
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return jsonResponse({ ok: true }, 200);
  }

  if (request.method !== "GET" && request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  const supabaseUrl = requireEnv("SUPABASE_URL");
  const serviceRoleKey = requireEnv("SUPABASE_SERVICE_ROLE_KEY");
  const environment = Deno.env.get("LECTOR_ENV") ??
    Deno.env.get("APP_ENV") ??
    "unknown";

  if (request.method === "POST") {
    const payload = await readJson(request);
    const action = stringValue(payload.action);
    if (action === "redeem_test_link") {
      const result = await redeemTestLink({
        supabaseUrl,
        serviceRoleKey,
        payload,
      });
      return jsonResponse(result, result.ok === true ? 200 : 403);
    }

    const admin = await authorizeAdmin({
      request,
      supabaseUrl,
      serviceRoleKey,
    });

    if (admin.error !== null) {
      return jsonResponse({ error: admin.error }, admin.status);
    }

    const identity = admin.identity;
    if (identity === null) {
      return jsonResponse({ error: "Admin identity is required." }, 401);
    }

    if (action === "rerun_league") {
      const result = await rerunLeague({
        supabaseUrl,
        serviceRoleKey,
        environment,
        admin: identity,
        payload,
      });
      return jsonResponse(result, result.ok === true ? 200 : 400);
    }

    if (action === "create_test_link") {
      const result = await createTestLink({
        supabaseUrl,
        serviceRoleKey,
        environment,
        admin: identity,
        payload,
      });
      return jsonResponse(result, result.ok === true ? 200 : 400);
    }

    return jsonResponse({ error: "Unknown admin action." }, 400);
  }

  const admin = await authorizeAdmin({
    request,
    supabaseUrl,
    serviceRoleKey,
  });

  if (admin.error !== null) {
    return jsonResponse({ error: admin.error }, admin.status);
  }

  const identity = admin.identity;
  if (identity === null) {
    return jsonResponse({ error: "Admin identity is required." }, 401);
  }

  if (request.method === "GET") {
    const overview = await loadOverview({
      supabaseUrl,
      serviceRoleKey,
      environment,
    });
    return jsonResponse({ ok: true, admin: identity, ...overview }, 200);
  }

  return jsonResponse({ error: "Unknown admin action." }, 400);
});

async function authorizeAdmin({
  request,
  supabaseUrl,
  serviceRoleKey,
}: {
  request: Request;
  supabaseUrl: string;
  serviceRoleKey: string;
}): Promise<
  | { identity: AdminIdentity; error: null; status: 200 }
  | { identity: null; error: string; status: number }
> {
  const allowedEmails = adminEmails();
  if (allowedEmails.length === 0) {
    return {
      identity: null,
      error: "ADMIN_EMAILS is required for admin operations.",
      status: 503,
    };
  }

  const bearerToken = bearerTokenFromRequest(request);
  if (bearerToken === null) {
    return { identity: null, error: "Missing bearer token.", status: 401 };
  }

  const response = await fetch(`${supabaseUrl}/auth/v1/user`, {
    headers: {
      "authorization": `Bearer ${bearerToken}`,
      "apikey": serviceRoleKey,
    },
  });

  if (!response.ok) {
    return { identity: null, error: "Invalid user token.", status: 401 };
  }

  const user = objectValue(await response.json());
  const email = stringValue(user?.email)?.toLowerCase();
  const id = stringValue(user?.id);
  if (email === undefined || id === undefined) {
    return { identity: null, error: "User email is required.", status: 403 };
  }

  if (!allowedEmails.includes(email)) {
    return { identity: null, error: "Admin access denied.", status: 403 };
  }

  return { identity: { id, email }, error: null, status: 200 };
}

async function loadOverview({
  supabaseUrl,
  serviceRoleKey,
  environment,
}: {
  supabaseUrl: string;
  serviceRoleKey: string;
  environment: string;
}): Promise<JsonObject> {
  const [
    jobs,
    cronRuns,
    pipeline,
    syncRuns,
    snapshots,
    adminRuns,
  ] = await Promise.all([
    restSelect({
      supabaseUrl,
      serviceRoleKey,
      path: "admin_cron_jobs",
      query: "select=*&order=jobname.asc",
    }),
    restSelect({
      supabaseUrl,
      serviceRoleKey,
      path: "admin_cron_job_runs",
      query: "select=*&order=start_time.desc&limit=80",
    }),
    restSelect({
      supabaseUrl,
      serviceRoleKey,
      path: "api_football_pipeline_health",
      query: "select=*&order=api_football_league_id.asc",
    }),
    restSelect({
      supabaseUrl,
      serviceRoleKey,
      path: "api_football_sync_runs",
      query:
        "select=id,status,started_at,finished_at,league_ids,window_start,window_end,response_summary,error_message&order=started_at.desc&limit=40",
    }),
    restSelect({
      supabaseUrl,
      serviceRoleKey,
      path: "match_feed_snapshots",
      query:
        "select=id,scope,scope_key,league_ids,season,window_start,window_end,as_of,snapshot_created_at,coverage_summary&scope=eq.league&order=snapshot_created_at.desc&limit=40",
    }),
    restSelect({
      supabaseUrl,
      serviceRoleKey,
      path: "admin_operation_runs",
      query:
        "select=id,action,status,environment,actor_email,league_ids,response_summary,error_message,started_at,finished_at&order=started_at.desc&limit=20",
    }),
  ]);

  return {
    environment,
    generated_at: new Date().toISOString(),
    jobs,
    cron_runs: cronRuns,
    pipeline_health: pipeline,
    sync_runs: syncRuns,
    snapshots,
    admin_operation_runs: adminRuns,
  };
}

async function createTestLink({
  supabaseUrl,
  serviceRoleKey,
  environment,
  admin,
  payload,
}: {
  supabaseUrl: string;
  serviceRoleKey: string;
  environment: string;
  admin: AdminIdentity;
  payload: JsonObject;
}): Promise<JsonObject> {
  const baseUrl = publicBaseUrl(payload);
  if (baseUrl === undefined) {
    return { ok: false, error: "base_url must be an absolute URL." };
  }

  const durationMinutes = clamp(
    numberValue(payload.duration_minutes) ?? 60,
    5,
    1440,
  );
  const label = stringValue(payload.label);
  const token = randomToken();
  const tokenHash = await sha256Hex(token);
  const expiresAt = new Date(Date.now() + durationMinutes * 60 * 1000)
    .toISOString();

  const rows = await restInsert({
    supabaseUrl,
    serviceRoleKey,
    path: "admin_preview_links",
    body: {
      token_hash: tokenHash,
      environment,
      label: label ?? null,
      created_by_user_id: admin.id,
      created_by_email: admin.email,
      expires_at: expiresAt,
    },
  });
  const first = objectValue(rows[0]);
  const id = stringValue(first?.id);
  if (id === undefined) {
    return { ok: false, error: "Preview link insert did not return an id." };
  }

  return {
    ok: true,
    link_id: id,
    url: previewUrl(baseUrl, token),
    expires_at: expiresAt,
    duration_minutes: durationMinutes,
  };
}

async function redeemTestLink({
  supabaseUrl,
  serviceRoleKey,
  payload,
}: {
  supabaseUrl: string;
  serviceRoleKey: string;
  payload: JsonObject;
}): Promise<JsonObject> {
  const token = stringValue(payload.token);
  if (token === undefined) {
    return { ok: false, error: "token is required." };
  }

  const tokenHash = await sha256Hex(token);
  const rows = await restSelect({
    supabaseUrl,
    serviceRoleKey,
    path: "admin_preview_links",
    query:
      `select=id,environment,expires_at,revoked_at,redeemed_count&token_hash=eq.${tokenHash}&limit=1`,
  });
  const link = objectValue(rows[0]);
  if (link === null) {
    return { ok: false, error: "Temporary tester link is invalid." };
  }

  const revokedAt = stringValue(link.revoked_at);
  if (revokedAt !== undefined) {
    return { ok: false, error: "Temporary tester link has been revoked." };
  }

  const expiresAt = stringValue(link.expires_at);
  if (expiresAt === undefined || new Date(expiresAt).getTime() <= Date.now()) {
    return { ok: false, error: "Temporary tester link has expired." };
  }

  const id = stringValue(link.id);
  if (id !== undefined) {
    await restPatch({
      supabaseUrl,
      serviceRoleKey,
      path: "admin_preview_links",
      query: `id=eq.${encodeURIComponent(id)}`,
      body: {
        last_redeemed_at: new Date().toISOString(),
        redeemed_count: (numberValue(link.redeemed_count) ?? 0) + 1,
      },
    });
  }

  return {
    ok: true,
    environment: stringValue(link.environment) ?? "unknown",
    expires_at: expiresAt,
  };
}

async function rerunLeague({
  supabaseUrl,
  serviceRoleKey,
  environment,
  admin,
  payload,
}: {
  supabaseUrl: string;
  serviceRoleKey: string;
  environment: string;
  admin: AdminIdentity;
  payload: JsonObject;
}): Promise<JsonObject> {
  const leagueId = numberValue(payload.league_id);
  if (leagueId === undefined || leagueId <= 0) {
    return { ok: false, error: "league_id must be a positive number." };
  }

  const includeSnapshot = booleanValue(payload.include_snapshot) ?? true;
  const bookmakerId = numberValue(payload.bookmaker_id) ?? 16;
  const today = dateOnly(new Date());
  const collectionStart = addDays(today, -2);
  const collectionEnd = addDays(today, 3);
  const feedEnd = addDays(today, 3);
  const operation = await insertAdminOperation({
    supabaseUrl,
    serviceRoleKey,
    environment,
    admin,
    payload: {
      action: "rerun_league",
      league_id: leagueId,
      include_snapshot: includeSnapshot,
      bookmaker_id: bookmakerId,
      collection_window_start: collectionStart,
      collection_window_end: collectionEnd,
      feed_window_start: today,
      feed_window_end: feedEnd,
    },
  });

  try {
    const syncPayload = {
      league_ids: [leagueId],
      bookmaker_id: bookmakerId,
      window_start: collectionStart,
      window_end: collectionEnd,
    };
    const sync = await invokeInternalFunction({
      supabaseUrl,
      name: "api-football-sync",
      payload: syncPayload,
    });

    let snapshot: JsonObject | null = null;
    if (includeSnapshot) {
      snapshot = await invokeInternalFunction({
        supabaseUrl,
        name: "build-match-feed-snapshot",
        payload: {
          league_ids: [leagueId],
          bookmaker_id: bookmakerId,
          window_start: today,
          window_end: feedEnd,
        },
      });
    }

    const summary = {
      sync,
      snapshot,
    };
    const status = okValue(sync) && (snapshot === null || okValue(snapshot))
      ? "succeeded"
      : "partial";
    await finishAdminOperation({
      supabaseUrl,
      serviceRoleKey,
      operationId: operation.id,
      status,
      summary,
    });

    return {
      ok: true,
      operation_id: operation.id,
      status,
      league_id: leagueId,
      summary,
    };
  } catch (error) {
    await finishAdminOperation({
      supabaseUrl,
      serviceRoleKey,
      operationId: operation.id,
      status: "failed",
      summary: {},
      errorMessage: errorMessage(error),
    });
    return {
      ok: false,
      operation_id: operation.id,
      error: errorMessage(error),
    };
  }
}

async function insertAdminOperation({
  supabaseUrl,
  serviceRoleKey,
  environment,
  admin,
  payload,
}: {
  supabaseUrl: string;
  serviceRoleKey: string;
  environment: string;
  admin: AdminIdentity;
  payload: JsonObject;
}): Promise<{ id: string }> {
  const leagueId = numberValue(payload.league_id);
  if (leagueId === undefined) {
    throw new Error("league_id is required for admin operation logging.");
  }
  const body = {
    action: "rerun_league",
    status: "running",
    environment,
    actor_user_id: admin.id,
    actor_email: admin.email,
    league_ids: [leagueId],
    request_payload: payload,
  };
  const rows = await restInsert({
    supabaseUrl,
    serviceRoleKey,
    path: "admin_operation_runs",
    body,
  });
  const first = objectValue(rows[0]);
  const id = stringValue(first?.id);
  if (id === undefined) {
    throw new Error("Admin operation insert did not return an id.");
  }
  return { id };
}

async function finishAdminOperation({
  supabaseUrl,
  serviceRoleKey,
  operationId,
  status,
  summary,
  errorMessage,
}: {
  supabaseUrl: string;
  serviceRoleKey: string;
  operationId: string;
  status: string;
  summary: JsonObject;
  errorMessage?: string;
}) {
  const patch: JsonObject = {
    status,
    response_summary: summary,
    finished_at: new Date().toISOString(),
  };
  if (errorMessage !== undefined) {
    patch.error_message = errorMessage;
  }
  await restPatch({
    supabaseUrl,
    serviceRoleKey,
    path: "admin_operation_runs",
    query: `id=eq.${encodeURIComponent(operationId)}`,
    body: patch,
  });
}

async function invokeInternalFunction({
  supabaseUrl,
  name,
  payload,
}: {
  supabaseUrl: string;
  name: string;
  payload: JsonObject;
}): Promise<JsonObject> {
  const secret = requireEnv("API_FOOTBALL_SYNC_SECRET");
  const response = await fetch(`${supabaseUrl}/functions/v1/${name}`, {
    method: "POST",
    headers: {
      "authorization": `Bearer ${secret}`,
      "content-type": "application/json",
    },
    body: JSON.stringify(payload),
  });
  const body = objectValue(await response.json().catch(() => ({}))) ?? {};
  if (!response.ok) {
    throw new Error(`${name} failed: ${JSON.stringify(body)}`);
  }
  return body;
}

async function restSelect({
  supabaseUrl,
  serviceRoleKey,
  path,
  query,
}: {
  supabaseUrl: string;
  serviceRoleKey: string;
  path: string;
  query: string;
}): Promise<unknown[]> {
  const response = await fetch(`${supabaseUrl}/rest/v1/${path}?${query}`, {
    headers: serviceRoleHeaders(serviceRoleKey),
  });
  if (!response.ok) {
    throw new Error(`REST select ${path} failed: ${await response.text()}`);
  }
  const body = await response.json();
  return Array.isArray(body) ? body : [];
}

async function restInsert({
  supabaseUrl,
  serviceRoleKey,
  path,
  body,
}: {
  supabaseUrl: string;
  serviceRoleKey: string;
  path: string;
  body: JsonObject;
}): Promise<unknown[]> {
  const response = await fetch(`${supabaseUrl}/rest/v1/${path}`, {
    method: "POST",
    headers: {
      ...serviceRoleHeaders(serviceRoleKey),
      "content-type": "application/json",
      "prefer": "return=representation",
    },
    body: JSON.stringify(body),
  });
  if (!response.ok) {
    throw new Error(`REST insert ${path} failed: ${await response.text()}`);
  }
  const result = await response.json();
  return Array.isArray(result) ? result : [];
}

async function restPatch({
  supabaseUrl,
  serviceRoleKey,
  path,
  query,
  body,
}: {
  supabaseUrl: string;
  serviceRoleKey: string;
  path: string;
  query: string;
  body: JsonObject;
}) {
  const response = await fetch(`${supabaseUrl}/rest/v1/${path}?${query}`, {
    method: "PATCH",
    headers: {
      ...serviceRoleHeaders(serviceRoleKey),
      "content-type": "application/json",
    },
    body: JSON.stringify(body),
  });
  if (!response.ok) {
    throw new Error(`REST patch ${path} failed: ${await response.text()}`);
  }
}

function serviceRoleHeaders(serviceRoleKey: string): Record<string, string> {
  return {
    "authorization": `Bearer ${serviceRoleKey}`,
    "apikey": serviceRoleKey,
    "accept": "application/json",
  };
}

function adminEmails(): string[] {
  return (Deno.env.get("ADMIN_EMAILS") ?? "")
    .split(",")
    .map((email) => email.trim().toLowerCase())
    .filter((email) => email.length > 0);
}

function bearerTokenFromRequest(request: Request): string | null {
  const header = request.headers.get("authorization") ?? "";
  const match = header.match(/^Bearer\s+(.+)$/i);
  return match?.[1] ?? null;
}

async function readJson(request: Request): Promise<JsonObject> {
  const body = await request.json().catch(() => ({}));
  if (body === null || typeof body !== "object" || Array.isArray(body)) {
    throw new Error("Request body must be a JSON object.");
  }
  return body as JsonObject;
}

function jsonResponse(body: JsonObject, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "content-type": "application/json",
    },
  });
}

function requireEnv(name: string): string {
  const value = Deno.env.get(name);
  if (value === undefined || value.length === 0) {
    throw new Error(`${name} is required.`);
  }
  return value;
}

function dateOnly(date: Date): string {
  return date.toISOString().slice(0, 10);
}

function addDays(date: string, days: number): string {
  const value = new Date(`${date}T00:00:00.000Z`);
  value.setUTCDate(value.getUTCDate() + days);
  return dateOnly(value);
}

function objectValue(value: unknown): JsonObject | null {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as JsonObject
    : null;
}

function stringValue(value: unknown): string | undefined {
  return typeof value === "string" && value.trim().length > 0
    ? value.trim()
    : undefined;
}

function numberValue(value: unknown): number | undefined {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === "string" && value.trim().length > 0) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : undefined;
  }
  return undefined;
}

function booleanValue(value: unknown): boolean | undefined {
  return typeof value === "boolean" ? value : undefined;
}

function publicBaseUrl(payload: JsonObject): URL | undefined {
  const raw = stringValue(payload.base_url);
  if (raw === undefined) {
    return undefined;
  }
  try {
    const url = new URL(raw);
    if (url.protocol !== "https:" && url.protocol !== "http:") {
      return undefined;
    }
    url.pathname = "/";
    url.search = "";
    url.hash = "";
    return url;
  } catch (_) {
    return undefined;
  }
}

function previewUrl(baseUrl: URL, token: string): string {
  const url = new URL(baseUrl.toString());
  url.searchParams.set("tester_token", token);
  return url.toString();
}

function randomToken(): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return btoa(String.fromCharCode(...bytes))
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replaceAll("=", "");
}

async function sha256Hex(value: string): Promise<string> {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max);
}

function okValue(value: JsonObject): boolean {
  return value.ok === true;
}

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
