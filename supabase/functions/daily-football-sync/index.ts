type JsonObject = Record<string, unknown>;

const defaultTimezone = "Europe/Paris";
const defaultResultsDaysBack = 7;
const defaultFutureDays = 3;
const defaultDatabaseSizeLimitBytes = 500 * 1024 * 1024;
const defaultApiRequestDelayMs = 220;
const defaultRecentFormDaysBack = 180;
const defaultRecentFormMatches = 5;
// A child Edge Function must return to the queue worker. Without a deadline,
// a stalled gateway call leaves its queue lease open until the database has to
// recover it, which used to block every subsequent league.
const childFunctionTimeoutMs = 4 * 60 * 1000;

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

  if (booleanValue(payload.process_queue) === true) {
    return processQueuedJob({ supabaseUrl, serviceRoleKey, syncSecret });
  }

  // Cron and manual calls only place an idempotent request in the durable
  // queue. The worker below is the only path that can contact API-Football.
  if (booleanValue(payload._queue_job) !== true) {
    return enqueueDailySync({ supabaseUrl, serviceRoleKey, payload });
  }

  const options = dailyOptionsFromPayload(payload);
  const queueJobId = stringValue(payload.queue_job_id);

  let runId: string | null = null;
  let syncResponse: JsonObject = {};
  let snapshotResponse: JsonObject = {};
  let resultResponse: JsonObject = {};
  let analysisResponse: JsonObject = {};

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
      payload: syncPayload(options, queueJobId),
    });

    resultResponse = await callFunction({
      supabaseUrl,
      name: "sync-match-results",
      syncSecret,
      payload: {
        league_ids: options.leagueIds,
        season_by_league: objectValue(
          objectValue(syncResponse.summary)?.leagueSeasons,
        ),
        fallback_season: options.season,
        timezone: options.timezone,
        window_start: options.resultsWindowStart,
        window_end: options.resultsWindowEnd,
        api_request_delay_ms: options.apiRequestDelayMs,
        api_football_sync_run_id: stringValue(syncResponse.runId),
        queue_job_id: queueJobId,
      },
    });

    snapshotResponse = numberValue(
        objectValue(syncResponse.summary)?.upcomingFixtures,
      ) === 0
      ? { ok: true, skipped: "no_upcoming_fixtures" }
      : await callFunction({
        supabaseUrl,
        name: "build-match-feed-snapshot",
        syncSecret,
        payload: snapshotPayload(options, syncResponse),
      });

    const publishedSnapshotId = stringValue(snapshotResponse.snapshotId);
    analysisResponse = publishedSnapshotId === null
      ? { ok: true, skipped: "no_snapshot" }
      : await callFunction({
        supabaseUrl,
        name: "analyze-match-feed-snapshot",
        syncSecret,
        payload: { snapshot_id: publishedSnapshotId },
      });
    snapshotResponse = {
      ...snapshotResponse,
      analysis: analysisResponse,
    };

    const databaseSizeBytes = await currentDatabaseSizeBytes({
      supabaseUrl,
      serviceRoleKey,
    });
    const storage = storageSummary(
      databaseSizeBytes,
      options.databaseSizeLimitBytes,
    );
    const apiRequestCount = apiRequestCountFromSyncResponse(syncResponse) +
      (numberValue(objectValue(resultResponse.summary)?.providerRequests) ?? 0);
    const snapshotId = stringValue(snapshotResponse.snapshotId);
    const status = booleanValue(syncResponse.ok) === true &&
        booleanValue(resultResponse.ok) === true &&
        booleanValue(snapshotResponse.ok) === true &&
        booleanValue(analysisResponse.ok) === true
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
      resultResponse,
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
      results: resultResponse,
      analysis: analysisResponse,
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
        resultResponse,
        apiRequestCount: apiRequestCountFromSyncResponse(syncResponse) +
          (numberValue(objectValue(resultResponse.summary)?.providerRequests) ??
            0),
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
      results: resultResponse,
      analysis: analysisResponse,
    }, 500);
  }
});

type DailyOptions = {
  season: number | null;
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
  includePlayerStatistics: boolean;
  includeRecentPlayerPerformances: boolean;
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
    7,
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
    season: numberValue(payload.season),
    timezone,
    leagueIds,
    // No bookmaker filter by default: one /odds request can then return every
    // available bookmaker and the client applies its existing priority order.
    // A bookmaker remains an explicit diagnostic override only.
    bookmakerId: numberValue(payload.bookmaker_id),
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
    // Player collection is intentionally opt-in. Daily rolling odds refreshes
    // stay light; the weekly enrichment schedule enables it explicitly.
    includePlayerStatistics: booleanValue(payload.include_player_statistics) ??
      false,
    includeRecentPlayerPerformances:
      booleanValue(payload.include_recent_player_performances) ?? true,
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

function syncPayload(
  options: DailyOptions,
  queueJobId: string | null,
): JsonObject {
  const payload: JsonObject = {
    timezone: options.timezone,
    window_start: options.feedWindowStart,
    window_end: options.feedWindowEnd,
    league_ids: options.leagueIds,
    api_request_delay_ms: options.apiRequestDelayMs,
    include_team_statistics: options.includeTeamStatistics,
    include_recent_form: options.includeRecentForm,
    include_expected_goals: options.includeExpectedGoals,
    include_player_statistics: options.includePlayerStatistics,
    include_recent_player_performances: options.includeRecentPlayerPerformances,
    recent_form_days_back: options.recentFormDaysBack,
    recent_form_matches: options.recentFormMatches,
    purpose: "daily_football_sync",
    windows: windowsPayload(options),
  };
  if (queueJobId !== null) {
    payload.queue_job_id = queueJobId;
  }
  if (options.bookmakerId !== null) {
    payload.bookmaker_id = options.bookmakerId;
  }
  if (options.season !== null) {
    payload.season = options.season;
  }
  return payload;
}

function snapshotPayload(
  options: DailyOptions,
  syncResponse: JsonObject,
): JsonObject {
  const payload: JsonObject = {
    season_by_league: objectValue(
      objectValue(syncResponse.summary)?.leagueSeasons,
    ),
    timezone: options.timezone,
    window_start: options.feedWindowStart,
    window_end: options.feedWindowEnd,
    league_ids: options.leagueIds,
    recent_form_days_back: options.recentFormDaysBack,
    recent_form_matches: options.recentFormMatches,
    as_of: new Date().toISOString(),
  };
  if (options.bookmakerId !== null) {
    payload.bookmaker_id = options.bookmakerId;
  }
  if (options.season !== null) {
    payload.season = options.season;
  }
  return payload;
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
        season: options.season ?? new Date().getUTCFullYear(),
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
  resultResponse,
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
  resultResponse: JsonObject;
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
      result_response: resultResponse,
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
  let response: Response;
  try {
    response = await fetch(`${supabaseUrl}/functions/v1/${name}`, {
      method: "POST",
      headers: {
        authorization: `Bearer ${syncSecret}`,
        "content-type": "application/json",
      },
      body: JSON.stringify(payload),
      signal: AbortSignal.timeout(childFunctionTimeoutMs),
    });
  } catch (error) {
    if (error instanceof DOMException && error.name === "TimeoutError") {
      throw new Error(
        `${name} timed out after ${childFunctionTimeoutMs / 1000} seconds.`,
      );
    }
    throw error;
  }
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

type QueueJob = {
  id: string;
  payload: JsonObject;
  attempts: number;
};

async function enqueueDailySync({
  supabaseUrl,
  serviceRoleKey,
  payload,
}: {
  supabaseUrl: string;
  serviceRoleKey: string;
  payload: JsonObject;
}): Promise<Response> {
  const options = dailyOptionsFromPayload(payload);
  const requestedAt = parisDateOnly(new Date());
  const manualRequested = booleanValue(payload.manual_override) === true;
  const manualOverride = manualRequested ||
    booleanValue(payload.manual_cycle) === true;
  if (manualRequested) {
    await supabaseFetch({
      supabaseUrl,
      serviceRoleKey,
      path: "/rest/v1/rpc/prepare_manual_api_football_cycle",
      method: "POST",
      body: {},
      prefer: "return=minimal",
    });
    if (options.leagueIds.length > 1) {
      const queued = await Promise.all(options.leagueIds.map((leagueId) =>
        enqueueDailySync({
          supabaseUrl,
          serviceRoleKey,
          payload: {
            ...payload,
            league_ids: [leagueId],
            manual_override: false,
            manual_cycle: true,
          },
        })
      ));
      return jsonResponse({
        ok: true,
        status: "queued",
        manual: true,
        queuedLeagues: options.leagueIds.length,
        responses: await Promise.all(queued.map(async (response) => response.json())),
      }, 202);
    }
  }
  const mode = manualOverride
    ? "manual"
    : options.includePlayerStatistics ? "enrichment" : "rolling";
  const dedupeKey = `${mode}:${requestedAt}:${[...options.leagueIds].sort((a, b) => a - b).join(",")}`;
  const existing = await supabaseFetch({
    supabaseUrl,
    serviceRoleKey,
    path: `/rest/v1/api_football_sync_queue_jobs?dedupe_key=eq.${encodeURIComponent(dedupeKey)}` +
      "&status=in.(queued,running,retrying)&select=id,status,available_at,attempts&limit=1",
    method: "GET",
    prefer: "return=representation",
  });
  const active = objectValue(existing[0]);
  if (active !== null) {
    return jsonResponse({
      ok: true,
      status: "already_queued",
      queueJobId: stringValue(active.id),
      queueStatus: stringValue(active.status),
      availableAt: stringValue(active.available_at),
    }, 202);
  }

  const queuedPayload = { ...payload };
  delete queuedPayload.process_queue;
  delete queuedPayload._queue_job;
  const rows = await supabaseFetch({
    supabaseUrl,
    serviceRoleKey,
    path: "/rest/v1/api_football_sync_queue_jobs",
    method: "POST",
    body: [{
      dedupe_key: dedupeKey,
      payload: queuedPayload,
      priority: manualOverride ? 1000 : 0,
    }],
    prefer: "return=representation",
  });
  const queued = objectValue(rows[0]) ?? {};
  return jsonResponse({
    ok: true,
    status: "queued",
    queueJobId: stringValue(queued.id),
    leagueIds: options.leagueIds,
  }, 202);
}

const queueWorkerTimeBudgetMs = 4 * 60 * 1000;

type QueueProcessOutcome = {
  queueJobId: string;
  status: "succeeded" | "retrying" | "failed";
  error?: string;
};

async function processQueuedJob({
  supabaseUrl,
  serviceRoleKey,
  syncSecret,
}: {
  supabaseUrl: string;
  serviceRoleKey: string;
  syncSecret: string;
}): Promise<Response> {
  // pg_cron wakes this worker every minute. Consume consecutive jobs during a
  // bounded invocation instead of idling for a whole minute after a short
  // collection. The database claim keeps this loop globally serial.
  const deadline = Date.now() + queueWorkerTimeBudgetMs;
  const outcomes: QueueProcessOutcome[] = [];
  while (Date.now() < deadline) {
    const outcome = await processOneQueuedJob({
      supabaseUrl,
      serviceRoleKey,
      syncSecret,
    });
    if (outcome === null) break;
    outcomes.push(outcome);
  }
  return jsonResponse({
    ok: outcomes.every((outcome) => outcome.status === "succeeded"),
    status: outcomes.length === 0 ? "idle" : "processed",
    processed: outcomes,
  }, 200);
}

async function processOneQueuedJob({
  supabaseUrl,
  serviceRoleKey,
  syncSecret,
}: {
  supabaseUrl: string;
  serviceRoleKey: string;
  syncSecret: string;
}): Promise<QueueProcessOutcome | null> {
  const rows = await supabaseFetch({
    supabaseUrl,
    serviceRoleKey,
    path: "/rest/v1/rpc/claim_next_api_football_sync_queue_job",
    method: "POST",
    body: { p_lease_seconds: 900 },
    prefer: "return=representation",
  });
  const row = objectValue(rows[0]);
  const id = stringValue(row?.id);
  const payload = objectValue(row?.payload);
  if (id === null || payload === null) return null;

  const job: QueueJob = {
    id,
    payload,
    attempts: numberValue(row?.attempts) ?? 1,
  };
  try {
    const response = await callFunction({
      supabaseUrl,
      name: "daily-football-sync",
      syncSecret,
      payload: { ...job.payload, _queue_job: true, queue_job_id: job.id },
    });
    if (booleanValue(response.ok) !== true) {
      throw new Error(`Queued orchestration returned ${JSON.stringify(response)}`);
    }
    await finishQueuedJob({
      supabaseUrl,
      serviceRoleKey,
      jobId: job.id,
      status: "succeeded",
    });
    return { queueJobId: job.id, status: "succeeded" };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    const retry = isRetryableQueueError(message) && job.attempts < 3;
    const status = retry ? "retrying" : "failed";
    await finishQueuedJob({
      supabaseUrl,
      serviceRoleKey,
      jobId: job.id,
      status,
      errorMessage: message,
      availableAt: retry
        ? new Date(Date.now() + retryDelayMs(job.attempts)).toISOString()
        : undefined,
    });
    return { queueJobId: job.id, status, error: message };
  }
}

async function finishQueuedJob({
  supabaseUrl,
  serviceRoleKey,
  jobId,
  status,
  errorMessage,
  availableAt,
}: {
  supabaseUrl: string;
  serviceRoleKey: string;
  jobId: string;
  status: "succeeded" | "retrying" | "failed";
  errorMessage?: string;
  availableAt?: string;
}): Promise<void> {
  await supabaseFetch({
    supabaseUrl,
    serviceRoleKey,
    path: `/rest/v1/api_football_sync_queue_jobs?id=eq.${encodeURIComponent(jobId)}`,
    method: "PATCH",
    body: {
      status,
      lease_expires_at: null,
      available_at: availableAt,
      last_error: errorMessage ?? null,
      finished_at: status === "retrying" ? null : new Date().toISOString(),
      updated_at: new Date().toISOString(),
    },
    prefer: "return=minimal",
  });
}

function isRetryableQueueError(message: string): boolean {
  return /\b429\b|rate.?limit|timeout|network|temporar/i.test(message);
}

function retryDelayMs(attempt: number): number {
  return Math.min(15 * 60 * 1000, 2 ** attempt * 60 * 1000);
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
  return numberValue(summary.providerRequests) ??
    numberValue(summary.cachedResponses) ?? 0;
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
