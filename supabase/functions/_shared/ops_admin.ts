import { db, type Obj, object, rpc, safeError, uuid } from "./ops_runtime.ts";
const publicTaskSelect =
  "id,cycle_id,league_id,competition_name,position,job_kind,status,stage,cancel_requested,attempts,day,counters,sample,error_message,created_at,started_at,finished_at,heartbeat_at";
export async function operationsOverview(cycleId?: string): Promise<Obj> {
  if (cycleId && !uuid(cycleId)) throw new Error("Cycle invalide");
  const [cycles, competitions, config, legacy, budget, audit, durations] =
    await Promise.all([
      db("ops_cycle_overview?select=*&order=created_at.desc&limit=50"),
      db("ops_competitions?select=*&order=name.asc"),
      db(
        "ops_configuration?select=scheduling_enabled,last_tick_at&singleton=eq.true",
      ),
      db(
        "daily_football_sync_runs?select=id,status,league_ids,started_at,finished_at,error_message,snapshot_id&order=started_at.desc&limit=100",
      ),
      db(
        "api_football_request_budget_days?select=budget_date,request_count,updated_at&order=budget_date.desc&limit=1",
      ),
      db(
        "ops_events?select=id,actor,kind,message,created_at&task_id=is.null&order=created_at.desc&limit=100",
      ),
      db("ops_duration_overview?select=*"),
    ]);
  const selected = cycleId ?? cycles[0]?.id;
  const tasks = selected
    ? await db(
      `ops_tasks?select=${publicTaskSelect}&cycle_id=eq.${selected}&order=position.asc&limit=500`,
    )
    : [];
  const active = await db(
    `ops_tasks?select=${publicTaskSelect}&status=eq.running&limit=10`,
  );
  return {
    cycles,
    competitions,
    tasks,
    active,
    legacy,
    audit,
    durations,
    last_tick_at: config[0]?.last_tick_at ?? null,
    budget: budget[0] ?? null,
    selected_cycle_id: selected ?? null,
    configured: config.length > 0,
    scheduling_enabled: config[0]?.scheduling_enabled ?? false,
    generated_at: new Date().toISOString(),
  };
}
export async function handleOperations(
  payload: Obj,
  actor: string,
): Promise<Obj> {
  const action = String(payload.action);
  if (action === "ops_overview") {
    return {
      ok: true,
      ...await operationsOverview(
        typeof payload.cycle_id === "string" ? payload.cycle_id : undefined,
      ),
    };
  }
  if (action === "ops_events") {
    if (!uuid(payload.task_id)) throw new Error("Batch invalide");
    const [events, tasks] = await Promise.all([
      db(
        `ops_events?select=id,kind,stage,message,created_at,actor&task_id=eq.${payload.task_id}&order=created_at.desc&limit=100`,
      ),
      db(
        `ops_tasks?select=${publicTaskSelect},context&id=eq.${payload.task_id}`,
      ),
    ]);
    const task = tasks[0];
    return {
      ok: true,
      events,
      task: task
        ? {
          ...task,
          context: undefined,
          stage_results: {
            sync: object(task.context.sync).summary,
            results: object(task.context.results).summary,
            snapshot: object(task.context.snapshot).summary,
            analysis: object(task.context.analysis).summary,
          },
        }
        : null,
    };
  }
  if (action === "ops_configure") {
    await rpc("ops_configure", {
      p_url: Deno.env.get("SUPABASE_URL"),
      p_secret: Deno.env.get("API_FOOTBALL_SYNC_SECRET"),
      p_scheduling: payload.enabled === true,
      p_actor: actor,
    });
    await rpc("ops_tick");
    return { ok: true };
  }
  if (action === "ops_start" || action === "ops_retry") {
    if (
      !(await db("ops_configuration?select=singleton&singleton=eq.true")).length
    ) {
      await rpc("ops_configure", {
        p_url: Deno.env.get("SUPABASE_URL"),
        p_secret: Deno.env.get("API_FOOTBALL_SYNC_SECRET"),
        p_scheduling: false,
        p_actor: actor,
      });
    }
    let kind = payload.job_kind === "enrichment" ? "enrichment" : "daily";
    let ids: number[];
    if (action === "ops_retry") {
      if (!uuid(payload.cycle_id)) throw new Error("Cycle invalide");
      const failed = await db(
        `ops_tasks?select=league_id,job_kind&cycle_id=eq.${payload.cycle_id}&status=in.(failed,cancelled)&order=position.asc`,
      );
      ids = failed.map((x: Obj) => Number(x.league_id));
      kind = failed[0]?.job_kind ?? "daily";
    } else if (payload.all === true) {
      ids = (await db(
        "ops_competitions?select=league_id&enabled=eq.true&order=league_id.asc",
      )).map((x: Obj) => Number(x.league_id));
    } else {
      ids = Array.isArray(payload.league_ids)
        ? [
          ...new Set(payload.league_ids.filter((x): x is number =>
            Number.isInteger(x) && Number(x) > 0
          )),
        ]
        : [];
    }
    if (!ids.length || ids.length > 500) {
      throw new Error("Sélection vide ou trop grande");
    }
    const id = await rpc("ops_enqueue", {
      p_ids: ids,
      p_label: action === "ops_retry"
        ? "Reprise des échecs"
        : kind === "enrichment"
        ? "Enrichissement manuel"
        : ids.length === 1
        ? "Relance manuelle"
        : "Cycle manuel",
      p_source: action === "ops_retry" ? "retry" : "manual",
      p_actor: actor,
      p_kind: kind,
    });
    await rpc("ops_dispatch");
    return { ok: true, cycle_id: id };
  }
  if (
    [
      "ops_pause_cycle",
      "ops_resume_cycle",
      "ops_cancel_cycle",
      "ops_cancel_task",
    ].includes(action)
  ) {
    if (!uuid(payload.id)) throw new Error("Identifiant invalide");
    await rpc("ops_control", {
      p_action: action.replace("ops_", ""),
      p_id: payload.id,
      p_actor: actor,
    });
    return { ok: true };
  }
  if (action === "ops_competition") {
    const id = Number(payload.league_id),
      name = String(payload.name ?? "").trim(),
      time = String(payload.daily_time ?? "02:00");
    if (
      !Number.isInteger(id) || id < 1 || !name || name.length > 160 ||
      !/^([01]\d|2[0-3]):[0-5]\d$/.test(time)
    ) throw new Error("Compétition ou heure invalide");
    const existing = await db(`ops_competitions?select=*&league_id=eq.${id}`);
    // Verify newly added provider IDs and use the provider name, never silently accept a guessed ID.
    let actualName = name;
    if (!existing.length) {
      const reservation = await rpc("reserve_api_football_request", {
        p_sync_run_id: null,
        p_daily_limit: 75000,
        p_minute_limit: 450,
      });
      if (reservation.allowed !== true) {
        throw new Error(`Quota API-Football : ${reservation.reason}`);
      }
      const response = await fetch(
        `${
          Deno.env.get("API_FOOTBALL_BASE_URL") ??
            "https://v3.football.api-sports.io"
        }/leagues?id=${id}`,
        {
          headers: { "x-apisports-key": Deno.env.get("API_FOOTBALL_KEY")! },
          signal: AbortSignal.timeout(30000),
        },
      );
      const body = object(await response.json());
      if (
        !response.ok || Object.keys(object(body.errors)).length ||
        (Array.isArray(body.errors) && body.errors.length)
      ) {
        throw new Error(
          "API-Football : vérification de la compétition impossible",
        );
      }
      const row = Array.isArray(body.response) ? object(body.response[0]) : {};
      if (Number(object(row.league).id) !== id) {
        throw new Error("Compétition introuvable chez API-Football");
      }
      actualName = String(object(row.league).name ?? name);
    }
    const previous = existing[0] ?? {};
    const enrichmentDay = Number(
      payload.enrichment_day ?? previous.enrichment_day ?? 0,
    );
    const enrichmentTime = String(
      payload.enrichment_time ?? previous.enrichment_time ?? "04:15",
    ).slice(0, 5);
    if (
      !Number.isInteger(enrichmentDay) || enrichmentDay < 0 ||
      enrichmentDay > 6 || !/^([01]\d|2[0-3]):[0-5]\d$/.test(enrichmentTime)
    ) throw new Error("Horaire hebdomadaire invalide");
    await rpc("ops_save_competition", {
      p_id: id,
      p_name: actualName,
      p_enabled: payload.enabled === true,
      p_time: time,
      p_actor: actor,
      p_enrichment: payload.enrichment_enabled ?? previous.enrichment_enabled ??
        false,
      p_enrichment_day: enrichmentDay,
      p_enrichment_time: enrichmentTime,
    });
    return { ok: true };
  }
  throw new Error("Action opérations inconnue");
}
export { safeError };
