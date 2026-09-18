type JsonObject = Record<string, unknown>;

const corsHeaders = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
};
const finalStatuses = new Set(["FT", "AET", "PEN"]);

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return respond({ ok: true });
  if (request.method !== "POST") return respond({ error: "Method not allowed" }, 405);
  const secret = Deno.env.get("API_FOOTBALL_SYNC_SECRET");
  if (!secret || request.headers.get("authorization") !== `Bearer ${secret}`) {
    return respond({ error: "Unauthorized" }, 401);
  }

  try {
    const payload = object(await request.json()) ?? {};
    const leagues = [...new Set(numbers(payload.league_ids))];
    const start = string(payload.window_start);
    const end = string(payload.window_end);
    const timezone = string(payload.timezone) ?? "Europe/Paris";
    const seasons = object(payload.season_by_league) ?? {};
    if (!start || !end || !/^\d{4}-\d{2}-\d{2}$/.test(start) ||
        !/^\d{4}-\d{2}-\d{2}$/.test(end) || start > end ||
        leagues.length === 0 || leagues.length > 40) {
      return respond({ error: "Invalid result window or leagues" }, 400);
    }
    const dates = dateRange(start, end);
    if (dates.length > 7) return respond({ error: "Limit result window to 7 days" }, 400);
    const apiKey = requiredEnv("API_FOOTBALL_KEY");
    const supabaseUrl = requiredEnv("SUPABASE_URL");
    const serviceKey = requiredEnv("SUPABASE_SERVICE_ROLE_KEY");
    const apiBase = Deno.env.get("API_FOOTBALL_BASE_URL") ??
      "https://v3.football.api-sports.io";
    const delayMs = Math.max(0, Math.min(5000,
      Number(payload.api_request_delay_ms ?? 750)));
    const summary = {
      providerRequests: 0,
      completedFixtures: 0,
      insertedSnapshots: 0,
      skippedFixtures: 0,
      enrichedFixtures: 0,
    };

    for (const leagueId of leagues) {
      const season = Number(seasons[String(leagueId)] ?? payload.fallback_season);
      if (!Number.isInteger(season) || season < 2000 || season > 2100) {
        throw new Error(`Missing season for league ${leagueId}`);
      }
      for (const date of dates) {
        const url = new URL("/fixtures", apiBase);
        url.searchParams.set("league", String(leagueId));
        url.searchParams.set("season", String(season));
        url.searchParams.set("date", date);
        url.searchParams.set("timezone", timezone);
        const response = await fetch(url, {
          headers: { "x-apisports-key": apiKey },
        });
        summary.providerRequests += 1;
        if (!response.ok) {
          throw new Error(`API-Football fixtures ${leagueId}/${date}: ${response.status}`);
        }
        const body = object(await response.json()) ?? {};
        const apiErrors = body.errors;
        if ((Array.isArray(apiErrors) && apiErrors.length > 0) ||
            (object(apiErrors) && Object.keys(object(apiErrors)!).length > 0)) {
          throw new Error(`API-Football fixtures ${leagueId}/${date}: ${JSON.stringify(apiErrors)}`);
        }
        const responseFixtures = Array.isArray(body.response)
          ? body.response.map(object).filter((value): value is JsonObject => value !== null)
          : [];
        const announcedFixtureIds = await announcedFixtureIdsFor({
          supabaseUrl,
          serviceKey,
          fixtureIds: responseFixtures
            .map((value) => number((object(value.fixture) ?? {}).id))
            .filter((value): value is number => value !== null),
        });
        const rows: JsonObject[] = [];
        for (const fixture of responseFixtures) {
          const details = object(fixture.fixture) ?? {};
          const teams = object(fixture.teams) ?? {};
          const home = object(teams.home) ?? {};
          const away = object(teams.away) ?? {};
          const goals = object(fixture.goals) ?? {};
          const score = object(fixture.score) ?? {};
          const halftime = object(score.halftime) ?? {};
          const status = string((object(details.status) ?? {}).short);
          const fixtureId = number(details.id);
          const kickoffAt = string(details.date);
          const homeId = number(home.id);
          const awayId = number(away.id);
          if (!status || !finalStatuses.has(status)) {
            summary.skippedFixtures += 1;
            continue;
          }
          if (fixtureId === null || !kickoffAt || homeId === null || awayId === null) {
            summary.skippedFixtures += 1;
            continue;
          }
          summary.completedFixtures += 1;
          const enrichment = announcedFixtureIds.has(fixtureId)
            ? await completedFixtureEnrichment({ apiBase, apiKey, fixtureId })
            : { statistics: [] as JsonObject[], events: [] as JsonObject[], providerRequests: 0 };
          summary.providerRequests += enrichment.providerRequests;
          if (enrichment.providerRequests > 0) summary.enrichedFixtures += 1;
          const scorePayload = {
            goals,
            halftime,
            fulltime: object(score.fulltime) ?? {},
            extratime: object(score.extratime) ?? {},
            penalty: object(score.penalty) ?? {},
          };
          const normalized = {
            fixture_id: fixtureId,
            league_id: leagueId,
            fixture_date: date,
            kickoff_at: kickoffAt,
            status,
            home_team_id: homeId,
            away_team_id: awayId,
            home_team_name: string(home.name) ?? String(homeId),
            away_team_name: string(away.name) ?? String(awayId),
            home_goals: number(goals.home),
            away_goals: number(goals.away),
            halftime_home_goals: number(halftime.home),
            halftime_away_goals: number(halftime.away),
            score: scorePayload,
            source_payload: {
              fixture,
              final_statistics: enrichment.statistics,
              final_events: enrichment.events,
              computed: {
                player_decisive: decisivePlayers(enrichment.events),
              },
            },
          };
          const resultIdentity = {
            fixture_id: fixtureId,
            status,
            home_goals: normalized.home_goals,
            away_goals: normalized.away_goals,
            score: scorePayload,
            enrichment: {
              statistics: enrichment.statistics,
              events: enrichment.events,
            },
          };
          rows.push({ ...normalized, content_hash: await sha256(JSON.stringify(resultIdentity)) });
        }
        for (let offset = 0; offset < rows.length; offset += 20) {
          const batch = rows.slice(offset, offset + 20);
          const stored = await fetch(
            `${supabaseUrl}/rest/v1/match_result_snapshots?on_conflict=fixture_id,content_hash`,
            {
              method: "POST",
              headers: {
                apikey: serviceKey,
                authorization: `Bearer ${serviceKey}`,
                "content-type": "application/json",
                prefer: "resolution=ignore-duplicates,return=representation",
              },
              body: JSON.stringify(batch),
            },
          );
          if (!stored.ok) throw new Error(`Store result snapshots: ${stored.status} ${await stored.text()}`);
          const inserted = await stored.json();
          summary.insertedSnapshots += Array.isArray(inserted) ? inserted.length : 0;
        }
        if (delayMs > 0) await new Promise((resolve) => setTimeout(resolve, delayMs));
      }
    }
    return respond({ ok: true, summary });
  } catch (error) {
    return respond({ ok: false, error: String(error) }, 500);
  }
});

async function completedFixtureEnrichment({
  apiBase,
  apiKey,
  fixtureId,
}: {
  apiBase: string;
  apiKey: string;
  fixtureId: number;
}): Promise<{ statistics: JsonObject[]; events: JsonObject[]; providerRequests: number }> {
  // The provider exposes these final resources per fixture. They are fetched
  // only after FT and retained once in the immutable result snapshot; the app
  // never asks the provider for a completed match.
  const load = async (path: string): Promise<JsonObject[]> => {
    const url = new URL(path, apiBase);
    url.searchParams.set("fixture", String(fixtureId));
    const response = await fetch(url, { headers: { "x-apisports-key": apiKey } });
    if (!response.ok) throw new Error(`API-Football ${path} ${fixtureId}: ${response.status}`);
    const body = object(await response.json()) ?? {};
    const errors = body.errors;
    if ((Array.isArray(errors) && errors.length > 0) ||
        (object(errors) && Object.keys(object(errors)!).length > 0)) {
      throw new Error(`API-Football ${path} ${fixtureId}: ${JSON.stringify(errors)}`);
    }
    return Array.isArray(body.response)
      ? body.response.map(object).filter((value): value is JsonObject => value !== null)
      : [];
  };
  const [statistics, events] = await Promise.all([
    load("/fixtures/statistics"),
    load("/fixtures/events"),
  ]);
  return { statistics, events, providerRequests: 2 };
}

async function announcedFixtureIdsFor({
  supabaseUrl,
  serviceKey,
  fixtureIds,
}: {
  supabaseUrl: string;
  serviceKey: string;
  fixtureIds: number[];
}): Promise<Set<number>> {
  const unique = [...new Set(fixtureIds)];
  if (unique.length === 0) return new Set();
  // One database lookup per league-day replaces two provider calls for every
  // completed fixture. Technical result enrichment is only useful when an
  // immutable reading or scenario was actually announced for that fixture.
  const response = await fetch(
    `${supabaseUrl}/rest/v1/match_reading_announcements?select=fixture_id&fixture_id=in.(${unique.join(",")})`,
    { headers: { apikey: serviceKey, authorization: `Bearer ${serviceKey}` } },
  );
  if (!response.ok) throw new Error(`Find announced fixtures: ${response.status} ${await response.text()}`);
  const rows = await response.json();
  return new Set(
    (Array.isArray(rows) ? rows : [])
      .map(object)
      .map((value) => number(value?.fixture_id))
      .filter((value): value is number => value !== null),
  );
}

function decisivePlayers(events: JsonObject[]): JsonObject {
  const result: JsonObject = {};
  for (const event of events) {
    if (string(event.type) !== "Goal") continue;
    const player = object(event.player) ?? {};
    const assist = object(event.assist) ?? {};
    const playerId = number(player.id);
    const assistId = number(assist.id);
    if (playerId !== null) result[String(playerId)] = true;
    if (assistId !== null) result[String(assistId)] = true;
  }
  return result;
}

function dateRange(start: string, end: string): string[] {
  const values: string[] = [];
  for (let day = new Date(`${start}T12:00:00Z`);
    day <= new Date(`${end}T12:00:00Z`);
    day = new Date(day.getTime() + 86400000)) {
    values.push(day.toISOString().slice(0, 10));
  }
  return values;
}

async function sha256(value: string): Promise<string> {
  const bytes = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return [...new Uint8Array(bytes)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

function object(value: unknown): JsonObject | null {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as JsonObject
    : null;
}
function string(value: unknown): string | null {
  return typeof value === "string" && value.length > 0 ? value : null;
}
function number(value: unknown): number | null {
  if (value === null || value === undefined || value === "") return null;
  const parsed = typeof value === "number" ? value : Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}
function numbers(value: unknown): number[] {
  return Array.isArray(value)
    ? value.map(number).filter((item): item is number => item !== null && Number.isInteger(item))
    : [];
}
function requiredEnv(key: string): string {
  const value = Deno.env.get(key);
  if (!value) throw new Error(`Missing ${key}`);
  return value;
}
function respond(body: JsonObject, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "content-type": "application/json; charset=utf-8" },
  });
}
