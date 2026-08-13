type JsonObject = Record<string, unknown>;

const defaultTimezone = "Europe/Paris";
const defaultResultsDaysBack = 2;
const defaultFutureDays = 3;
const defaultDatabaseSizeLimitBytes = 500 * 1024 * 1024;
const defaultApiRequestDelayMs = 750;
const defaultBookmakerId = 16;
const defaultRecentFormDaysBack = 180;
const defaultRecentFormMatches = 5;

const corsHeaders = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers":
    "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return jsonResponse({ ok: true }, 200);
  }

  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  const authError = authorizeRequest(request);
  if (authError !== null) {
    return jsonResponse({ error: authError }, 401);
  }

  const supabaseUrl = requireEnv("SUPABASE_URL");
  const serviceRoleKey = requireEnv("SUPABASE_SERVICE_ROLE_KEY");
  const syncSecret = requireEnv("API_FOOTBALL_SYNC_SECRET");
  const payload = await readJson(request);
  const options = dailyOptionsFromPayload(payload);

  let runId: string | null = null;
  let syncResponse: JsonObject = {};
  let snapshotResponse: JsonObject = {};

  try {
    await markStaleDailyRuns({
      supabaseUrl,
      serviceRoleKey,
    });
    const run = await insertDailyRun({
      supabaseUrl,
      serviceRoleKey,
      options,
    });
    runId = String(run.id);

    syncResponse = await callFunction({
      supabaseUrl,
      name: "api-football-sync",
      syncSecret,
      payload: syncPayload(options),
    });

    snapshotResponse = await callFunction({
      supabaseUrl,
      name: "build-match-feed-snapshot",
      syncSecret,
      payload: snapshotPayload(options, syncResponse),
    });

    const databaseSizeBytes = await currentDatabaseSizeBytes({
      supabaseUrl,
      serviceRoleKey,
    });
    const storage = storageSummary(
      databaseSizeBytes,
      options.databaseSizeLimitBytes,
    );
    const apiRequestCount = apiRequestCountFromSyncResponse(syncResponse);
    const snapshotId = stringValue(snapshotResponse.snapshotId);
    const status = booleanValue(syncResponse.ok) === true &&
        booleanValue(snapshotResponse.ok) === true
      ? "succeeded"
      : "partial";

    await updateDailyRun({
      supabaseUrl,
      serviceRoleKey,
      runId,
      status,
      options,
      syncResponse,
      snapshotResponse,
      apiRequestCount,
      snapshotId,
      storage,
    });

    return jsonResponse({
      ok: status === "succeeded",
      status,
      runId,
      apiFootballSyncRunId: stringValue(syncResponse.runId),
      snapshotId,
      windows: windowsPayload(options),
      apiRequestCount,
      storage,
      sync: syncResponse,
      snapshot: snapshotResponse,
    }, status === "succeeded" ? 200 : 207);
  } catch (error) {
    if (runId !== null) {
      const databaseSizeBytes = await currentDatabaseSizeBytes({
        supabaseUrl,
        serviceRoleKey,
      }).catch(() => null);
      await updateDailyRun({
        supabaseUrl,
        serviceRoleKey,
        runId,
        status: "failed",
        options,
        syncResponse,
        snapshotResponse,
        apiRequestCount: apiRequestCountFromSyncResponse(syncResponse),
        snapshotId: stringValue(snapshotResponse.snapshotId),
        storage: storageSummary(
          databaseSizeBytes,
          options.databaseSizeLimitBytes,
        ),
        errorMessage: error instanceof Error ? error.message : String(error),
      });
    }

    return jsonResponse({
      ok: false,
      runId,
      error: error instanceof Error ? error.message : String(error),
      sync: syncResponse,
      snapshot: snapshotResponse,
    }, 500);
  }
});

type DailyOptions = {
  season: number;
  timezone: string;
  leagueIds: number[];
  bookmakerId: number | null;
  apiRequestDelayMs: number;
  resultsWindowStart: string;
  resultsWindowEnd: string;
  feedWindowStart: string;
  feedWindowEnd: string;
  fullWindowStart: string;
  fullWindowEnd: string;
  databaseSizeLimitBytes: number;
  includeTeamStatistics: boolean;
  includeRecentForm: boolean;
  includeExpectedGoals: boolean;
  recentFormDaysBack: number;
  recentFormMatches: number;
};

type StorageSummary = {
  databaseSizeBytes: number | null;
  databaseSizeLimitBytes: number;
  databaseSizeRatio: number | null;
  warningLevel: "ok" | "warning_80" | "warning_90" | "critical_95";
};

function dailyOptionsFromPayload(payload: JsonObject): DailyOptions {
  const timezone = stringValue(payload.timezone) ?? defaultTimezone;
  const today = parisDateOnly(new Date());
  const resultsDaysBack = boundedInteger(
    numberValue(payload.results_days_back),
    1,
    3,
    defaultResultsDaysBack,
  );
  const futureDays = boundedInteger(
    numberValue(payload.future_days),
    1,
    6,
    defaultFutureDays,
  );
  const feedWindowStart = stringValue(payload.feed_window_start) ?? today;
  const feedWindowEnd = stringValue(payload.feed_window_end) ??
    addDays(feedWindowStart, futureDays);
  const resultsWindowStart = stringValue(payload.results_window_start) ??
    subtractDays(feedWindowStart, resultsDaysBack);
  const resultsWindowEnd = stringValue(payload.results_window_end) ??
    subtractDays(feedWindowStart, 1);
  const leagueIds = numberList(payload.league_ids);

  if (leagueIds.length === 0) {
    throw new Error(
      "league_ids must contain at least one API-Football league id.",
    );
  }
  if (!isDate(resultsWindowStart) || !isDate(resultsWindowEnd)) {
    throw new Error("results window values must be ISO dates.");
  }
  if (!isDate(feedWindowStart) || !isDate(feedWindowEnd)) {
    throw new Error("feed window values must be ISO dates.");
  }
  if (resultsWindowEnd < resultsWindowStart) {
    throw new Error(
      "results_window_end must be on or after results_window_start.",
    );
  }
  if (feedWindowEnd < feedWindowStart) {
    throw new Error("feed_window_end must be on or after feed_window_start.");
  }

  return {
    season: numberValue(payload.season) ?? new Date().getUTCFullYear(),
    timezone,
    leagueIds,
    bookmakerId: numberValue(payload.bookmaker_id) ?? defaultBookmakerId,
    apiRequestDelayMs: boundedInteger(
      numberValue(payload.api_request_delay_ms),
      0,
      5000,
      defaultApiRequestDelayMs,
    ),
    resultsWindowStart,
    resultsWindowEnd,
    feedWindowStart,
    feedWindowEnd,
    fullWindowStart: minDate(resultsWindowStart, feedWindowStart),
    fullWindowEnd: maxDate(resultsWindowEnd, feedWindowEnd),
    databaseSizeLimitBytes: boundedInteger(
      numberValue(payload.database_size_limit_bytes),
      1,
      Number.MAX_SAFE_INTEGER,
      defaultDatabaseSizeLimitBytes,
    ),
    includeTeamStatistics: booleanValue(payload.include_team_statistics) ??
      true,
    includeRecentForm: booleanValue(payload.include_recent_form) ?? true,
    includeExpectedGoals: booleanValue(payload.include_expected_goals) ?? true,
    recentFormDaysBack: boundedInteger(
      numberValue(payload.recent_form_days_back),
      1,
      730,
      defaultRecentFormDaysBack,
    ),
    recentFormMatches: boundedInteger(
      numberValue(payload.recent_form_matches),
      1,
      10,
      defaultRecentFormMatches,
    ),
  };
}

function syncPayload(options: DailyOptions): JsonObject {
  return {
    season: options.season,
    timezone: options.timezone,
    window_start: options.fullWindowStart,
    window_end: options.fullWindowEnd,
    league_ids: options.leagueIds,
    bookmaker_id: options.bookmakerId,
    api_request_delay_ms: options.apiRequestDelayMs,
    include_team_statistics: options.includeTeamStatistics,
    include_recent_form: options.includeRecentForm,
    include_expected_goals: options.includeExpectedGoals,
    recent_form_days_back: options.recentFormDaysBack,
    recent_form_matches: options.recentFormMatches,
    purpose: "daily_football_sync",
    windows: windowsPayload(options),
  };
}

function snapshotPayload(
  options: DailyOptions,
  syncResponse: JsonObject,
): JsonObject {
  return {
    season: options.season,
    season_by_league: objectValue(
      objectValue(syncResponse.summary)?.leagueSeasons,
    ),
    timezone: options.timezone,
    window_start: options.feedWindowStart,
    window_end: options.feedWindowEnd,
    league_ids: options.leagueIds,
    bookmaker_id: options.bookmakerId,
    recent_form_days_back: options.recentFormDaysBack,
    recent_form_matches: options.recentFormMatches,
    as_of: new Date().toISOString(),
  };
}

function windowsPayload(options: DailyOptions): JsonObject {
  return {
    results: {
      window_start: options.resultsWindowStart,
      window_end: options.resultsWindowEnd,
    },
    feed: {
      window_start: options.feedWindowStart,
      window_end: options.feedWindowEnd,
    },
    collection: {
      window_start: options.fullWindowStart,
      window_end: options.fullWindowEnd,
    },
  };
}

async function markStaleDailyRuns({
  supabaseUrl,
  serviceRoleKey,
}: {
  supabaseUrl: string;
  serviceRoleKey: string;
}): Promise<void> {
  const staleBefore = new Date(Date.now() - 60 * 60 * 1000).toISOString();
  await supabaseFetch({
    supabaseUrl,
    serviceRoleKey,
    path: `/rest/v1/daily_football_sync_runs?status=eq.running&started_at=lt.${
      encodeURIComponent(staleBefore)
    }`,
    method: "PATCH",
    body: {
      status: "failed",
      error_message: "Run marked failed after exceeding stale running window.",
      finished_at: new Date().toISOString(),
    },
    prefer: "return=minimal",
  });
}

async function insertDailyRun({
  supabaseUrl,
  serviceRoleKey,
  options,
}: {
  supabaseUrl: string;
  serviceRoleKey: string;
  options: DailyOptions;
}): Promise<JsonObject> {
  const rows = await supabaseFetch({
    supabaseUrl,
    serviceRoleKey,
    path: "/rest/v1/daily_football_sync_runs",
    method: "POST",
    body: [
      {
        season: options.season,
        timezone: options.timezone,
        results_window_start: options.resultsWindowStart,
        results_window_end: options.resultsWindowEnd,
        feed_window_start: options.feedWindowStart,
        feed_window_end: options.feedWindowEnd,
        league_ids: options.leagueIds,
        bookmaker_id: options.bookmakerId,
        api_request_delay_ms: options.apiRequestDelayMs,
        database_size_limit_bytes: options.databaseSizeLimitBytes,
      },
    ],
    prefer: "return=representation",
  });
  return rows[0] as JsonObject;
}

async function updateDailyRun({
  supabaseUrl,
  serviceRoleKey,
  runId,
  status,
  options,
  syncResponse,
  snapshotResponse,
  apiRequestCount,
  snapshotId,
  storage,
  errorMessage,
}: {
  supabaseUrl: string;
  serviceRoleKey: string;
  runId: string;
  status: "succeeded" | "failed" | "partial";
  options: DailyOptions;
  syncResponse: JsonObject;
  snapshotResponse: JsonObject;
  apiRequestCount: number;
  snapshotId: string | null;
  storage: StorageSummary;
  errorMessage?: string;
}): Promise<void> {
  await supabaseFetch({
    supabaseUrl,
    serviceRoleKey,
    path: `/rest/v1/daily_football_sync_runs?id=eq.${
      encodeURIComponent(runId)
    }`,
    method: "PATCH",
    body: {
      status,
      sync_response: syncResponse,
      snapshot_response: snapshotResponse,
      api_football_sync_run_id: stringValue(syncResponse.runId),
      snapshot_id: snapshotId,
      api_request_count: apiRequestCount,
      database_size_bytes: storage.databaseSizeBytes,
      database_size_limit_bytes: options.databaseSizeLimitBytes,
      database_size_ratio: storage.databaseSizeRatio,
      storage_warning_level: storage.warningLevel,
      error_message: errorMessage ?? null,
      finished_at: new Date().toISOString(),
    },
    prefer: "return=minimal",
  });
}

async function callFunction({
  supabaseUrl,
  name,
  syncSecret,
  payload,
}: {
  supabaseUrl: string;
  name: string;
  syncSecret: string;
  payload: JsonObject;
}): Promise<JsonObject> {
  const response = await fetch(`${supabaseUrl}/functions/v1/${name}`, {
    method: "POST",
    headers: {
      authorization: `Bearer ${syncSecret}`,
      "content-type": "application/json",
    },
    body: JSON.stringify(payload),
  });
  const body = await response.json().catch(() => ({}));
  if (!isJsonObject(body)) {
    throw new Error(`${name} returned a non-object response.`);
  }
  if (!response.ok) {
    throw new Error(
      `${name} failed with ${response.status}: ${JSON.stringify(body)}`,
    );
  }
  return body;
}

async function currentDatabaseSizeBytes({
  supabaseUrl,
  serviceRoleKey,
}: {
  supabaseUrl: string;
  serviceRoleKey: string;
}): Promise<number | null> {
  const rows = await supabaseFetch({
    supabaseUrl,
    serviceRoleKey,
    path: "/rest/v1/rpc/current_database_size_bytes",
    method: "POST",
    body: {},
    prefer: "return=representation",
  });
  const value = rows[0];
  return typeof value === "number" ? value : numberValue(value);
}

function storageSummary(
  databaseSizeBytes: number | null,
  databaseSizeLimitBytes: number,
): StorageSummary {
  const ratio = databaseSizeBytes === null
    ? null
    : round5(databaseSizeBytes / databaseSizeLimitBytes);
  let warningLevel: StorageSummary["warningLevel"] = "ok";
  if (ratio !== null && ratio >= 0.95) {
    warningLevel = "critical_95";
  } else if (ratio !== null && ratio >= 0.90) {
    warningLevel = "warning_90";
  } else if (ratio !== null && ratio >= 0.80) {
    warningLevel = "warning_80";
  }
  return {
    databaseSizeBytes,
    databaseSizeLimitBytes,
    databaseSizeRatio: ratio,
    warningLevel,
  };
}

function apiRequestCountFromSyncResponse(syncResponse: JsonObject): number {
  const summary = objectValue(syncResponse.summary) ?? {};
  return numberValue(summary.cachedResponses) ?? 0;
}

function authorizeRequest(request: Request): string | null {
  const expectedSecret = Deno.env.get("API_FOOTBALL_SYNC_SECRET");
  if (expectedSecret === undefined || expectedSecret.trim() === "") {
    return "API_FOOTBALL_SYNC_SECRET is not configured.";
  }

  const authorization = request.headers.get("authorization") ?? "";
  const token = authorization.replace(/^Bearer\s+/i, "").trim();
  return token === expectedSecret ? null : "Invalid sync secret.";
}

function requireEnv(name: string): string {
  const value = Deno.env.get(name);
  if (value === undefined || value.trim() === "") {
    throw new Error(`${name} is not configured.`);
  }
  return value;
}

async function readJson(request: Request): Promise<JsonObject> {
  const body = await request.json().catch(() => ({}));
  if (body === null || typeof body !== "object" || Array.isArray(body)) {
    throw new Error("Request body must be a JSON object.");
  }
  return body as JsonObject;
}

async function supabaseFetch({
  supabaseUrl,
  serviceRoleKey,
  path,
  method,
  body,
  prefer,
}: {
  supabaseUrl: string;
  serviceRoleKey: string;
  path: string;
  method: string;
  body?: unknown;
  prefer: string;
}): Promise<unknown[]> {
  const response = await fetch(`${supabaseUrl}${path}`, {
    method,
    headers: {
      apikey: serviceRoleKey,
      authorization: `Bearer ${serviceRoleKey}`,
      "content-type": "application/json",
      prefer,
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Supabase ${response.status}: ${text}`);
  }

  if (prefer.includes("return=minimal")) {
    return [];
  }

  const payload = await response.json();
  return Array.isArray(payload) ? payload : [payload];
}

function parisDateOnly(date: Date): string {
  const formatter = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Europe/Paris",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  });
  return formatter.format(date);
}

function addDays(date: string, days: number): string {
  const value = new Date(`${date}T00:00:00.000Z`);
  value.setUTCDate(value.getUTCDate() + days);
  return dateOnly(value);
}

function subtractDays(date: string, days: number): string {
  return addDays(date, -days);
}

function dateOnly(date: Date): string {
  return [
    date.getUTCFullYear().toString().padStart(4, "0"),
    (date.getUTCMonth() + 1).toString().padStart(2, "0"),
    date.getUTCDate().toString().padStart(2, "0"),
  ].join("-");
}

function minDate(first: string, second: string): string {
  return first < second ? first : second;
}

function maxDate(first: string, second: string): string {
  return first > second ? first : second;
}

function isDate(value: string): boolean {
  return /^\d{4}-\d{2}-\d{2}$/.test(value) &&
    !Number.isNaN(Date.parse(`${value}T00:00:00.000Z`));
}

function boundedInteger(
  value: number | null,
  min: number,
  max: number,
  fallback: number,
): number {
  if (value === null) {
    return fallback;
  }
  return Math.min(max, Math.max(min, value));
}

function numberList(value: unknown): number[] {
  if (!Array.isArray(value)) {
    return [];
  }
  return [
    ...new Set(
      value
        .map(numberValue)
        .filter((number): number is number => number !== null),
    ),
  ];
}

function numberValue(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  if (typeof value === "string" && value.trim() !== "") {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? Math.trunc(parsed) : null;
  }
  return null;
}

function booleanValue(value: unknown): boolean | null {
  if (typeof value === "boolean") {
    return value;
  }
  if (typeof value === "string") {
    return value === "true" ? true : value === "false" ? false : null;
  }
  return null;
}

function stringValue(value: unknown): string | null {
  return typeof value === "string" && value.trim() !== "" ? value.trim() : null;
}

function objectValue(value: unknown): JsonObject | null {
  return isJsonObject(value) ? value : null;
}

function isJsonObject(value: unknown): value is JsonObject {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function round5(value: number): number {
  return Math.round(value * 100000) / 100000;
}

function jsonResponse(payload: unknown, status: number): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...corsHeaders,
      "content-type": "application/json",
    },
  });
}
