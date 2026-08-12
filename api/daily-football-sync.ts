type JsonObject = Record<string, unknown>;

export const config = {
  runtime: "edge",
};

const defaultLeagues = [
  39, // Premier League
  61, // Ligue 1
  140, // La Liga
  78, // Bundesliga
  135, // Serie A
  94, // Liga Portugal
  88, // Eredivisie
  144, // Jupiler Pro League
  179, // Scottish Premiership
  203, // Super Lig
  197, // Super League Greece
  119, // Danish Superliga
  207, // Swiss Super League
  218, // Austrian Bundesliga
  40, // Championship
  62, // Ligue 2
  136, // Serie B
  79, // 2. Bundesliga
  141, // La Liga 2
  106, // Ekstraklasa
  210, // HNL
  209, // Czech Liga
  283, // Liga I
  253, // MLS
  71, // Brasileiro Serie A
  128, // Liga Profesional Argentina
  262, // Liga MX
  307, // Saudi Pro League
  98, // J1 League
  188, // A-League
];

export default async function handler(request: Request): Promise<Response> {
  if (request.method !== "GET" && request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  const cronSecret = process.env.CRON_SECRET;
  if (cronSecret !== undefined && cronSecret.trim() !== "") {
    const authorization = request.headers.get("authorization") ?? "";
    const token = authorization.replace(/^Bearer\s+/i, "").trim();
    if (token !== cronSecret) {
      return jsonResponse({ error: "Invalid cron secret." }, 401);
    }
  }

  const supabaseUrl = requireEnv("SUPABASE_URL");
  const syncSecret = requireEnv("API_FOOTBALL_SYNC_SECRET");
  const payload = dailyPayload();

  const response = await fetch(
    `${supabaseUrl}/functions/v1/daily-football-sync`,
    {
      method: "POST",
      headers: {
        authorization: `Bearer ${syncSecret}`,
        "content-type": "application/json",
      },
      body: JSON.stringify(payload),
    },
  );
  const body = await response.json().catch(() => ({}));
  return jsonResponse(body, response.status);
}

function dailyPayload(): JsonObject {
  return {
    timezone: process.env.API_FOOTBALL_TIMEZONE ?? "Europe/Paris",
    league_ids: listEnv("API_FOOTBALL_LEAGUE_IDS") ?? defaultLeagues,
    bookmaker_id: numberEnv("API_FOOTBALL_BOOKMAKER_ID") ?? 16,
    results_days_back: numberEnv("API_FOOTBALL_RESULTS_DAYS_BACK") ?? 2,
    future_days: numberEnv("API_FOOTBALL_FUTURE_DAYS") ?? 3,
    api_request_delay_ms: numberEnv("API_FOOTBALL_REQUEST_DELAY_MS") ?? 750,
    database_size_limit_bytes:
      numberEnv("SUPABASE_DATABASE_SIZE_LIMIT_BYTES") ??
        500 * 1024 * 1024,
    include_team_statistics:
      booleanEnv("API_FOOTBALL_INCLUDE_TEAM_STATISTICS") ??
        true,
    include_recent_form: booleanEnv("API_FOOTBALL_INCLUDE_RECENT_FORM") ?? true,
    include_expected_goals: booleanEnv("API_FOOTBALL_INCLUDE_EXPECTED_GOALS") ??
      true,
    recent_form_days_back: numberEnv("API_FOOTBALL_RECENT_FORM_DAYS_BACK") ??
      180,
    recent_form_matches: numberEnv("API_FOOTBALL_RECENT_FORM_MATCHES") ?? 5,
  };
}

function requireEnv(name: string): string {
  const value = process.env[name];
  if (value === undefined || value.trim() === "") {
    throw new Error(`${name} is not configured.`);
  }
  return value;
}

function numberEnv(name: string): number | null {
  const value = process.env[name];
  if (value === undefined || value.trim() === "") {
    return null;
  }
  const parsed = Number(value);
  return Number.isFinite(parsed) ? Math.trunc(parsed) : null;
}

function listEnv(name: string): number[] | null {
  const value = process.env[name];
  if (value === undefined || value.trim() === "") {
    return null;
  }
  const values = value
    .split(",")
    .map((item) => Number(item.trim()))
    .filter((item) => Number.isFinite(item))
    .map((item) => Math.trunc(item));
  return values.length === 0 ? null : [...new Set(values)];
}

function booleanEnv(name: string): boolean | null {
  const value = process.env[name];
  if (value === undefined) {
    return null;
  }
  return value === "true" ? true : value === "false" ? false : null;
}

function jsonResponse(payload: unknown, status: number): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { "content-type": "application/json" },
  });
}
