type JsonObject = Record<string, unknown>;

const source = "api-football";
const defaultBaseUrl = "https://v3.football.api-sports.io";
const defaultTimezone = "Europe/Paris";
const maxDays = 7;
const maxLeagues = 40;
const maxTeamStatisticsRequests = 120;
const maxRecentFixtureRequests = 160;
const maxFixtureStatisticsRequests = 240;
const defaultRecentFormDaysBack = 180;
const defaultRecentFormMatches = 5;
const defaultApiRequestDelayMs = 750;

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

  const authError = authorizeSyncRequest(request);
  if (authError !== null) {
    return jsonResponse({ error: authError }, 401);
  }

  const apiKey = requireEnv("API_FOOTBALL_KEY");
  const supabaseUrl = requireEnv("SUPABASE_URL");
  const serviceRoleKey = requireEnv("SUPABASE_SERVICE_ROLE_KEY");
  const apiBaseUrl = Deno.env.get("API_FOOTBALL_BASE_URL") ?? defaultBaseUrl;
  const payload = await readJson(request);
  const apiRequestDelayMs = Math.max(
    0,
    numberValue(payload.api_request_delay_ms) ??
      numberValue(Deno.env.get("API_FOOTBALL_REQUEST_DELAY_MS")) ??
      defaultApiRequestDelayMs,
  );
  const options = syncOptionsFromPayload(payload);

  let runId: string | null = null;
  const summary: SyncSummary = {
    leagues: 0,
    fixtures: 0,
    odds: 0,
    standings: 0,
    teamStatistics: 0,
    recentFixtureRows: 0,
    fixtureStatistics: 0,
    cachedResponses: 0,
    leagueSeasons: {},
  };
  const fixtureStatisticsIds = new Set<number>();
  let recentFixtureRequests = 0;

  try {
    await markStaleSyncRuns({
      supabaseUrl,
      serviceRoleKey,
    });
    const run = await insertSyncRun({
      supabaseUrl,
      serviceRoleKey,
      options,
      requestPayload: payload,
    });
    runId = String(run.id);

    for (const leagueId of options.leagueIds) {
      const leagueInfo = await fetchAndCache({
        apiBaseUrl,
        apiKey,
        supabaseUrl,
        serviceRoleKey,
        runId,
        endpoint: "/leagues",
        query: {
          id: String(leagueId),
          current: "true",
        },
        ttlSeconds: 24 * 60 * 60,
        requestDelayMs: apiRequestDelayMs,
      });
      const leagueSeason = currentSeasonFromLeaguesPayload(
        leagueInfo.body,
        options.fallbackSeason,
      );
      summary.leagueSeasons[String(leagueId)] = leagueSeason;
      summary.leagues += 1;
      summary.cachedResponses += 1;

      await fetchAndCache({
        apiBaseUrl,
        apiKey,
        supabaseUrl,
        serviceRoleKey,
        runId,
        endpoint: "/standings",
        query: {
          league: String(leagueId),
          season: String(leagueSeason),
        },
        ttlSeconds: 60 * 60,
        requestDelayMs: apiRequestDelayMs,
      });
      summary.standings += 1;
      summary.cachedResponses += 1;

      for (const date of dateWindow(options.windowStart, options.windowEnd)) {
        const fixtures = await fetchAndCache({
          apiBaseUrl,
          apiKey,
          supabaseUrl,
          serviceRoleKey,
          runId,
          endpoint: "/fixtures",
          query: {
            league: String(leagueId),
            season: String(leagueSeason),
            date,
            timezone: options.timezone,
          },
          ttlSeconds: 15 * 60,
          requestDelayMs: apiRequestDelayMs,
        });
        summary.fixtures += responseRows(fixtures.body).length;
        summary.cachedResponses += 1;

        const oddsQuery: Record<string, string> = {
          league: String(leagueId),
          season: String(leagueSeason),
          date,
        };
        if (options.bookmakerId !== null) {
          oddsQuery.bookmaker = String(options.bookmakerId);
        }
        const odds = await fetchAndCache({
          apiBaseUrl,
          apiKey,
          supabaseUrl,
          serviceRoleKey,
          runId,
          endpoint: "/odds",
          query: oddsQuery,
          ttlSeconds: 15 * 60,
          requestDelayMs: apiRequestDelayMs,
        });
        summary.odds += responseRows(odds.body).length;
        summary.cachedResponses += 1;

        if (options.includeTeamStatistics) {
          const teamIds = teamIdsFromFixtures(fixtures.body);
          for (const teamId of teamIds.slice(0, maxTeamStatisticsRequests)) {
            await fetchAndCache({
              apiBaseUrl,
              apiKey,
              supabaseUrl,
              serviceRoleKey,
              runId,
              endpoint: "/teams/statistics",
              query: {
                league: String(leagueId),
                season: String(leagueSeason),
                team: String(teamId),
              },
              ttlSeconds: 60 * 60,
              requestDelayMs: apiRequestDelayMs,
            });
            summary.teamStatistics += 1;
            summary.cachedResponses += 1;
          }
        }

        if (options.includeRecentForm || options.includeExpectedGoals) {
          const fixtureTeamContexts = fixtureTeamContextsFromFixtures(
            fixtures.body,
            leagueId,
          );
          for (const context of fixtureTeamContexts) {
            if (recentFixtureRequests >= maxRecentFixtureRequests) {
              break;
            }
            const recentFixtures = await fetchAndCache({
              apiBaseUrl,
              apiKey,
              supabaseUrl,
              serviceRoleKey,
              runId,
              endpoint: "/fixtures",
              query: {
                league: String(context.leagueId),
                season: String(leagueSeason),
                team: String(context.teamId),
                from: subtractDays(
                  context.fixtureDate,
                  options.recentFormDaysBack,
                ),
                to: subtractDays(context.fixtureDate, 1),
                timezone: options.timezone,
              },
              ttlSeconds: 6 * 60 * 60,
              requestDelayMs: apiRequestDelayMs,
            });
            recentFixtureRequests += 1;
            summary.recentFixtureRows += responseRows(recentFixtures.body)
              .length;
            summary.cachedResponses += 1;

            if (options.includeExpectedGoals) {
              for (
                const fixtureId of recentFixtureIdsForTeam(
                  recentFixtures.body,
                  context.teamId,
                  options.recentFormMatches,
                )
              ) {
                fixtureStatisticsIds.add(fixtureId);
              }
            }
          }
        }
      }
    }

    if (options.includeExpectedGoals) {
      for (const fixtureId of [...fixtureStatisticsIds]) {
        if (summary.fixtureStatistics >= maxFixtureStatisticsRequests) {
          break;
        }
        await fetchAndCache({
          apiBaseUrl,
          apiKey,
          supabaseUrl,
          serviceRoleKey,
          runId,
          endpoint: "/fixtures/statistics",
          query: {
            fixture: String(fixtureId),
          },
          ttlSeconds: 7 * 24 * 60 * 60,
          requestDelayMs: apiRequestDelayMs,
        });
        summary.fixtureStatistics += 1;
        summary.cachedResponses += 1;
      }
    }

    await updateSyncRun({
      supabaseUrl,
      serviceRoleKey,
      runId,
      status: "succeeded",
      summary,
    });

    return jsonResponse({ ok: true, runId, summary }, 200);
  } catch (error) {
    if (runId !== null) {
      await updateSyncRun({
        supabaseUrl,
        serviceRoleKey,
        runId,
        status: "failed",
        summary,
        errorMessage: error instanceof Error ? error.message : String(error),
      });
    }

    return jsonResponse(
      {
        ok: false,
        runId,
        error: error instanceof Error ? error.message : error,
      },
      500,
    );
  }
});

type SyncOptions = {
  fallbackSeason: number;
  timezone: string;
  windowStart: string;
  windowEnd: string;
  leagueIds: number[];
  bookmakerId: number | null;
  includeTeamStatistics: boolean;
  includeRecentForm: boolean;
  includeExpectedGoals: boolean;
  recentFormDaysBack: number;
  recentFormMatches: number;
};

type SyncSummary = {
  leagues: number;
  fixtures: number;
  odds: number;
  standings: number;
  teamStatistics: number;
  recentFixtureRows: number;
  fixtureStatistics: number;
  cachedResponses: number;
  leagueSeasons: Record<string, number>;
};

type CachedResponse = {
  body: JsonObject;
  fetchedAt: string;
};

type FetchAndCacheOptions = {
  apiBaseUrl: string;
  apiKey: string;
  supabaseUrl: string;
  serviceRoleKey: string;
  runId: string;
  endpoint: string;
  query: Record<string, string>;
  ttlSeconds: number;
  requestDelayMs: number;
};

function authorizeSyncRequest(request: Request): string | null {
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

function syncOptionsFromPayload(payload: JsonObject): SyncOptions {
  const today = dateOnly(new Date());
  const windowStart = stringValue(payload.window_start) ?? today;
  const windowEnd = stringValue(payload.window_end) ?? windowStart;
  const leagueIds = numberList(payload.league_ids);
  const fallbackSeason = numberValue(payload.season) ??
    new Date().getFullYear();
  const bookmakerId = numberValue(payload.bookmaker_id);
  const timezone = stringValue(payload.timezone) ?? defaultTimezone;
  const includeTeamStatistics = booleanValue(payload.include_team_statistics) ??
    true;
  const includeRecentForm = booleanValue(payload.include_recent_form) ?? true;
  const includeExpectedGoals = booleanValue(payload.include_expected_goals) ??
    includeRecentForm;
  const recentFormDaysBack = numberValue(payload.recent_form_days_back) ??
    defaultRecentFormDaysBack;
  const recentFormMatches = numberValue(payload.recent_form_matches) ??
    defaultRecentFormMatches;

  if (leagueIds.length === 0) {
    throw new Error(
      "league_ids must contain at least one API-Football league id.",
    );
  }
  if (leagueIds.length > maxLeagues) {
    throw new Error(`league_ids cannot contain more than ${maxLeagues} ids.`);
  }
  if (!isDate(windowStart) || !isDate(windowEnd)) {
    throw new Error("window_start and window_end must be ISO dates.");
  }
  if (windowEnd < windowStart) {
    throw new Error("window_end must be on or after window_start.");
  }
  if (dateWindow(windowStart, windowEnd).length > maxDays) {
    throw new Error(`Date window cannot exceed ${maxDays} days.`);
  }
  if (recentFormDaysBack < 1 || recentFormDaysBack > 730) {
    throw new Error("recent_form_days_back must be between 1 and 730.");
  }
  if (recentFormMatches < 1 || recentFormMatches > 10) {
    throw new Error("recent_form_matches must be between 1 and 10.");
  }

  return {
    fallbackSeason,
    timezone,
    windowStart,
    windowEnd,
    leagueIds,
    bookmakerId,
    includeTeamStatistics,
    includeRecentForm,
    includeExpectedGoals,
    recentFormDaysBack,
    recentFormMatches,
  };
}

async function markStaleSyncRuns({
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
    path: `/rest/v1/api_football_sync_runs?status=eq.running&started_at=lt.${
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

async function insertSyncRun({
  supabaseUrl,
  serviceRoleKey,
  options,
  requestPayload,
}: {
  supabaseUrl: string;
  serviceRoleKey: string;
  options: SyncOptions;
  requestPayload: JsonObject;
}): Promise<JsonObject> {
  const rows = await supabaseFetch({
    supabaseUrl,
    serviceRoleKey,
    path: "/rest/v1/api_football_sync_runs",
    method: "POST",
    body: [
      {
        season: options.fallbackSeason,
        timezone: options.timezone,
        window_start: options.windowStart,
        window_end: options.windowEnd,
        league_ids: options.leagueIds,
        bookmaker_id: options.bookmakerId,
        include_team_statistics: options.includeTeamStatistics,
        request_payload: requestPayload,
      },
    ],
    prefer: "return=representation",
  });

  return rows[0] as JsonObject;
}

async function updateSyncRun({
  supabaseUrl,
  serviceRoleKey,
  runId,
  status,
  summary,
  errorMessage,
}: {
  supabaseUrl: string;
  serviceRoleKey: string;
  runId: string;
  status: "succeeded" | "failed" | "partial";
  summary: SyncSummary;
  errorMessage?: string;
}): Promise<void> {
  await supabaseFetch({
    supabaseUrl,
    serviceRoleKey,
    path: `/rest/v1/api_football_sync_runs?id=eq.${encodeURIComponent(runId)}`,
    method: "PATCH",
    body: {
      status,
      response_summary: summary,
      error_message: errorMessage ?? null,
      finished_at: new Date().toISOString(),
    },
    prefer: "return=minimal",
  });
}

async function fetchAndCache(
  options: FetchAndCacheOptions,
): Promise<CachedResponse> {
  const uri = new URL(`${options.apiBaseUrl}${options.endpoint}`);
  for (const key of Object.keys(options.query).sort()) {
    uri.searchParams.set(key, options.query[key]);
  }

  const queryHash = await sha256Hex(
    JSON.stringify({
      endpoint: options.endpoint,
      query: sortedObject(options.query),
    }),
  );
  const fetchedAt = new Date();
  const response = await fetch(uri, {
    headers: {
      accept: "application/json",
      "x-apisports-key": options.apiKey,
    },
  });
  const body = await response.json().catch(() => ({}));
  if (body === null || typeof body !== "object" || Array.isArray(body)) {
    throw new Error(`Unexpected API-Football payload for ${options.endpoint}.`);
  }

  const fetchedAtIso = fetchedAt.toISOString();
  const expiresAt = new Date(
    fetchedAt.getTime() + options.ttlSeconds * 1000,
  ).toISOString();

  await supabaseFetch({
    supabaseUrl: options.supabaseUrl,
    serviceRoleKey: options.serviceRoleKey,
    path: "/rest/v1/api_football_cached_responses",
    method: "POST",
    body: [
      {
        source,
        endpoint: options.endpoint,
        query_hash: queryHash,
        query_params: sortedObject(options.query),
        request_url: redactUrl(uri),
        response_status: response.status,
        response_body: body,
        rate_limit: rateLimitHeaders(response.headers),
        sync_run_id: options.runId,
        fetched_at: fetchedAtIso,
        as_of: fetchedAtIso,
        expires_at: expiresAt,
      },
    ],
    prefer: "resolution=merge-duplicates,return=minimal",
  });

  if (!response.ok) {
    await delay(options.requestDelayMs);
    throw new Error(
      `API-Football ${response.status} for ${options.endpoint}.`,
    );
  }

  await delay(options.requestDelayMs);
  return { body: body as JsonObject, fetchedAt: fetchedAtIso };
}

function delay(milliseconds: number): Promise<void> {
  if (milliseconds <= 0) {
    return Promise.resolve();
  }
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
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
  body: unknown;
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
    body: JSON.stringify(body),
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

function responseRows(payload: JsonObject): unknown[] {
  const rows = payload.response;
  return Array.isArray(rows) ? rows : [];
}

function currentSeasonFromLeaguesPayload(
  payload: JsonObject,
  fallbackSeason: number,
): number {
  for (const row of responseRows(payload)) {
    const root = objectValue(row);
    if (root === null) {
      continue;
    }
    const seasons = root.seasons;
    if (!Array.isArray(seasons)) {
      continue;
    }
    const current = seasons
      .map(objectValue)
      .find((season) =>
        season !== null && booleanValue(season.current) === true
      );
    const year = numberValue(current?.year);
    if (year !== null) {
      return year;
    }
    for (const season of seasons.map(objectValue)) {
      const year = numberValue(season?.year);
      if (year !== null) {
        return year;
      }
    }
  }
  return fallbackSeason;
}

function teamIdsFromFixtures(payload: JsonObject): number[] {
  const ids = new Set<number>();
  for (const row of responseRows(payload)) {
    if (row === null || typeof row !== "object") {
      continue;
    }
    const teams = (row as JsonObject).teams;
    if (teams === null || typeof teams !== "object" || Array.isArray(teams)) {
      continue;
    }
    for (const side of ["home", "away"]) {
      const team = (teams as JsonObject)[side];
      if (team === null || typeof team !== "object" || Array.isArray(team)) {
        continue;
      }
      const id = numberValue((team as JsonObject).id);
      if (id !== null) {
        ids.add(id);
      }
    }
  }
  return [...ids];
}

type FixtureTeamContext = {
  leagueId: number;
  teamId: number;
  fixtureDate: string;
};

function fixtureTeamContextsFromFixtures(
  payload: JsonObject,
  fallbackLeagueId: number,
): FixtureTeamContext[] {
  const contexts = new Map<string, FixtureTeamContext>();
  for (const row of responseRows(payload)) {
    const root = objectValue(row);
    if (root === null) {
      continue;
    }
    const leagueId = numberValue((objectValue(root.league) ?? {}).id) ??
      fallbackLeagueId;
    const fixture = objectValue(root.fixture) ?? {};
    const fixtureDateTime = stringValue(fixture.date);
    if (fixtureDateTime === null) {
      continue;
    }
    const fixtureDate = dateOnly(new Date(fixtureDateTime));
    const teams = objectValue(root.teams) ?? {};
    for (const side of ["home", "away"]) {
      const teamId = numberValue((objectValue(teams[side]) ?? {}).id);
      if (teamId !== null) {
        contexts.set(`${leagueId}:${teamId}:${fixtureDate}`, {
          leagueId,
          teamId,
          fixtureDate,
        });
      }
    }
  }
  return [...contexts.values()];
}

function recentFixtureIdsForTeam(
  payload: JsonObject,
  teamId: number,
  maxMatches: number,
): number[] {
  const fixtures = responseRows(payload)
    .filter(isCompletedFixture)
    .filter((row) => fixtureContainsTeam(row, teamId))
    .sort((a, b) => fixtureTimestamp(b) - fixtureTimestamp(a));

  return fixtures
    .slice(0, maxMatches)
    .map((row) => {
      const root = objectValue(row) ?? {};
      return numberValue((objectValue(root.fixture) ?? {}).id);
    })
    .filter((id): id is number => id !== null);
}

function isCompletedFixture(row: unknown): boolean {
  const root = objectValue(row);
  if (root === null) {
    return false;
  }
  const status = objectValue((objectValue(root.fixture) ?? {}).status) ?? {};
  const shortStatus = stringValue(status.short);
  if (shortStatus !== null && ["FT", "AET", "PEN"].includes(shortStatus)) {
    return true;
  }
  const goals = objectValue(root.goals) ?? {};
  return numberValue(goals.home) !== null && numberValue(goals.away) !== null;
}

function fixtureContainsTeam(row: unknown, teamId: number): boolean {
  const root = objectValue(row);
  if (root === null) {
    return false;
  }
  const teams = objectValue(root.teams) ?? {};
  return ["home", "away"].some((side) =>
    numberValue((objectValue(teams[side]) ?? {}).id) === teamId
  );
}

function fixtureTimestamp(row: unknown): number {
  const root = objectValue(row);
  const fixture = objectValue(root?.fixture) ?? {};
  const timestamp = numberValue(fixture.timestamp);
  if (timestamp !== null) {
    return timestamp;
  }
  const date = stringValue(fixture.date);
  return date === null ? 0 : Date.parse(date);
}

function rateLimitHeaders(headers: Headers): JsonObject {
  const values: JsonObject = {};
  headers.forEach((value, key) => {
    if (key.toLowerCase().startsWith("x-ratelimit")) {
      values[key] = value;
    }
  });
  return values;
}

async function sha256Hex(value: string): Promise<string> {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function sortedObject(input: Record<string, string>): Record<string, string> {
  return Object.fromEntries(
    Object.entries(input).sort(([a], [b]) => a.localeCompare(b)),
  );
}

function redactUrl(uri: URL): string {
  return `${uri.origin}${uri.pathname}?${uri.searchParams.toString()}`;
}

function dateWindow(start: string, end: string): string[] {
  const dates: string[] = [];
  const current = new Date(`${start}T00:00:00.000Z`);
  const last = new Date(`${end}T00:00:00.000Z`);
  while (current <= last) {
    dates.push(dateOnly(current));
    current.setUTCDate(current.getUTCDate() + 1);
  }
  return dates;
}

function dateOnly(date: Date): string {
  return [
    date.getUTCFullYear().toString().padStart(4, "0"),
    (date.getUTCMonth() + 1).toString().padStart(2, "0"),
    date.getUTCDate().toString().padStart(2, "0"),
  ].join("-");
}

function subtractDays(date: string, days: number): string {
  const value = new Date(`${date}T00:00:00.000Z`);
  value.setUTCDate(value.getUTCDate() - days);
  return dateOnly(value);
}

function isDate(value: string): boolean {
  return /^\d{4}-\d{2}-\d{2}$/.test(value) &&
    !Number.isNaN(Date.parse(`${value}T00:00:00.000Z`));
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

function stringValue(value: unknown): string | null {
  return typeof value === "string" && value.trim() !== "" ? value.trim() : null;
}

function objectValue(value: unknown): JsonObject | null {
  return isJsonObject(value) ? value : null;
}

function isJsonObject(value: unknown): value is JsonObject {
  return value !== null && typeof value === "object" && !Array.isArray(value);
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

function jsonResponse(payload: unknown, status: number): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...corsHeaders,
      "content-type": "application/json",
    },
  });
}
