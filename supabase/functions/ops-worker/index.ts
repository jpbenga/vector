import {
  type Obj,
  object,
  rpc,
  safeError,
  stageCall,
  uuid,
} from "../_shared/ops_runtime.ts";
Deno.serve(async (request) => {
  const secret = Deno.env.get("API_FOOTBALL_SYNC_SECRET");
  if (!secret || request.headers.get("authorization") !== `Bearer ${secret}`) {
    return new Response("Unauthorized", { status: 401 });
  }
  if (request.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }
  const payload = object(await request.json().catch(() => ({})));
  if (!uuid(payload.task_id) || !uuid(payload.token)) {
    return new Response("Invalid task", { status: 400 });
  }
  let task: Obj | null = null;
  try {
    task = await rpc("ops_claim", {
      p_task: payload.task_id,
      p_token: payload.token,
    });
    if (!task) {
      return Response.json({ ok: true, skipped: "already claimed or expired" });
    }
    if (
      await rpc("ops_checkpoint", {
        p_task: task.id,
        p_token: task.stage_token,
      }) !== true
    ) throw new Error("Arrêt demandé");
    const call = stageCall(task);
    const response = await fetch(
      `${Deno.env.get("SUPABASE_URL")}/functions/v1/${call.name}`,
      {
        method: "POST",
        headers: {
          authorization: `Bearer ${secret}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(call.payload),
        signal: AbortSignal.timeout(125000),
      },
    );
    const result = object(await response.json().catch(() => ({})));
    if (!response.ok || result.ok !== true) {
      throw new Error(
        `${call.name} (${response.status}): ${
          result.error ?? "Réponse partielle ou invalide"
        }`,
      );
    }
    const key = ["sync", "results", "snapshot", "analysis"][Number(task.stage)];
    // Store compact stage result only. Provider cache remains private.
    await rpc("ops_finish", {
      p_task: task.id,
      p_token: task.stage_token,
      p_context: { [key]: result },
      p_continue: result.continue === true,
    });
    return Response.json({ ok: true });
  } catch (error) {
    if (task) {
      await rpc("ops_finish", {
        p_task: task.id,
        p_token: task.stage_token,
        p_error: safeError(error),
      });
    }
    return Response.json({ ok: false, error: safeError(error) }, {
      status: 500,
    });
  }
});
