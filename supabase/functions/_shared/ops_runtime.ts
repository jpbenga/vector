export type Obj = Record<string, unknown>;
export const stages = ["collect", "results", "snapshot", "publish"] as const;
export const object = (v: unknown): Obj =>
  v !== null && typeof v === "object" && !Array.isArray(v) ? v as Obj : {};
export const uuid = (v: unknown): v is string =>
  typeof v === "string" &&
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(v);
export async function db(
  path: string,
  method = "GET",
  body?: unknown,
): Promise<any> {
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const response = await fetch(
    `${Deno.env.get("SUPABASE_URL")}/rest/v1/${path}`,
    {
      method,
      headers: {
        apikey: key,
        authorization: `Bearer ${key}`,
        "Content-Type": "application/json",
        Prefer: "return=representation",
      },
      body: body === undefined ? undefined : JSON.stringify(body),
      signal: AbortSignal.timeout(30000),
    },
  );
  if (!response.ok) {
    throw new Error(
      `Base opérations (${response.status}): ${
        (await response.text()).slice(0, 1000)
      }`,
    );
  }
  const text = await response.text();
  return text ? JSON.parse(text) : null;
}
export const rpc = (name: string, body: Obj = {}) =>
  db(`rpc/${name}`, "POST", body);
export function safeError(error: unknown): string {
  let message = error instanceof Error ? error.message : String(error);
  for (
    const name of [
      "API_FOOTBALL_KEY",
      "API_FOOTBALL_SYNC_SECRET",
      "SUPABASE_SERVICE_ROLE_KEY",
    ]
  ) {
    const value = Deno.env.get(name);
    if (value) message = message.split(value).join("[masqué]");
  }
  return message.replace(/Bearer\s+[^\s"}]+/gi, "Bearer [masqué]").slice(
    0,
    1600,
  );
}
// Whitelist factual fields: no headers, URLs, credentials or raw response dump.
export function fixtureSample(body: unknown): Obj {
  const rows = object(body).response;
  if (!Array.isArray(rows)) return {};
  const row = rows.map(object).find((r) =>
    object(r.fixture).id != null && object(r.teams).home != null
  );
  if (!row) return {};
  const fixture = object(row.fixture),
    teams = object(row.teams),
    league = object(row.league);
  return {
    fixture_id: fixture.id,
    kickoff: fixture.date,
    competition: league.name,
    home: object(teams.home).name,
    away: object(teams.away).name,
    status: object(fixture.status).short,
    goals: { home: object(row.goals).home, away: object(row.goals).away },
  };
}
export class OpsReporter {
  private last = 0;
  private latestSample: Obj = {};
  constructor(private payload: Obj) {}
  async checkpoint(counters: Obj = {}, sample: Obj = {}, force = false) {
    if (!uuid(this.payload.ops_task_id) || !uuid(this.payload.ops_token)) {
      return;
    }
    if (Object.keys(sample).length) this.latestSample = sample;
    if (!force && Date.now() - this.last < 2000) return;
    const allowed = await rpc("ops_checkpoint", {
      p_task: this.payload.ops_task_id,
      p_token: this.payload.ops_token,
      p_counters: {
        ...counters,
        ...(typeof counters.providerRequests === "number" &&
            this.payload.ops_stage === 0
          ? { collectProviderRequests: counters.providerRequests }
          : {}),
        ...(typeof counters.providerRequests === "number" &&
            this.payload.ops_stage === 1
          ? { resultProviderRequests: counters.providerRequests }
          : {}),
      },
      p_sample: this.latestSample,
    });
    this.last = Date.now();
    if (allowed !== true) {
      throw new Error("Arrêt demandé ou autorisation du worker expirée");
    }
  }
}
export function stageCall(task: Obj): { name: string; payload: Obj } {
  const stage = Number(task.stage), context = object(task.context);
  const day = String(task.day), date = new Date(`${day}T12:00:00Z`);
  const offset = (n: number) =>
    new Date(date.getTime() + n * 86400000).toISOString().slice(0, 10);
  const common = {
    league_ids: [task.league_id],
    timezone: "Europe/Paris",
    ops_task_id: task.id,
    ops_token: task.stage_token,
    ops_stage: stage,
  };
  const sync = object(context.sync);
  if (stage === 0) {
    return {
      name: "api-football-sync",
      payload: {
        ...common,
        window_start: day,
        window_end: offset(3),
        purpose: "daily_football_sync",
        include_player_statistics: task.job_kind === "enrichment",
        include_recent_player_performances: true,
        include_player_activity_history: false,
        api_request_delay_ms: 750,
        recent_form_matches: 10,
        ops_batch_cursor: object(sync.batch_cursor),
      },
    };
  }
  const summary = object(sync.summary);
  if (stage === 1) {
    if (!uuid(sync.runId)) {
      throw new Error(
        "Identifiant de collecte manquant : résultats non lancés",
      );
    }
    return {
      name: "sync-match-results",
      payload: {
        ...common,
        api_football_sync_run_id: sync.runId,
        season_by_league: summary.leagueSeasons,
        window_start: offset(-7),
        window_end: offset(-1),
        api_request_delay_ms: 750,
      },
    };
  }
  if (stage === 2) {
    return {
      name: "build-match-feed-snapshot",
      payload: {
        ...common,
        season_by_league: summary.leagueSeasons,
        window_start: day,
        window_end: offset(3),
        as_of: task.started_at,
        recent_form_matches: 10,
      },
    };
  }
  const snapshot = object(context.snapshot);
  if (stage === 3 && uuid(snapshot.snapshotId)) {
    return {
      name: "analyze-match-feed-snapshot",
      payload: { ...common, snapshot_id: snapshot.snapshotId },
    };
  }
  throw new Error("Snapshot manquant : publication non lancée");
}
