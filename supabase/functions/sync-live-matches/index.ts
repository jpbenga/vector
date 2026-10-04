import { collectLiveMatches, liveObject } from "../_shared/live_matches.ts";
import { rpc, safeError } from "../_shared/ops_runtime.ts";

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }
  const secret = Deno.env.get("API_FOOTBALL_SYNC_SECRET");
  if (!secret || request.headers.get("authorization") !== `Bearer ${secret}`) {
    return new Response("Unauthorized", { status: 401 });
  }
  let token: string | null = null;
  let requests = 0;
  const respond = (body: unknown, status = 200) =>
    Response.json(body, { status });
  try {
    const plan = liveObject(await rpc("match_live_claim"));
    if (typeof plan.token !== "string") {
      return respond({ ok: true, skipped: true, reason: "disabled_or_busy" });
    }
    token = plan.token;
    const key = Deno.env.get("API_FOOTBALL_KEY");
    if (!key) throw new Error("Configuration API-Football absente.");
    const deadline = Date.now() + 42000;
    const collection = await collectLiveMatches(
      Array.isArray(plan.league_ids) ? plan.league_ids.map(Number) : [],
      Array.isArray(plan.fixture_ids) ? plan.fixture_ids.map(Number) : [],
      {
        reserve: async () => {
          if (Date.now() >= deadline) return false;
          // Check the lease before EVERY external request. A stopped or revoked
          // collector cannot spend quota or publish a late response.
          if (await rpc("match_live_checkpoint", { p_token: token }) !== true) {
            return false;
          }
          const budget = liveObject(
            await rpc("reserve_api_football_request", {
              p_sync_run_id: null,
              p_daily_limit: 75000,
              p_minute_limit: 280,
            }),
          );
          return budget.allowed === true;
        },
        fetchFixtures: async (query) => {
          requests++;
          const base = Deno.env.get("API_FOOTBALL_BASE_URL") ??
            "https://v3.football.api-sports.io";
          const response = await fetch(
            `${base}/fixtures?${query}&timezone=Europe%2FParis`,
            {
              headers: { "x-apisports-key": key },
              signal: AbortSignal.timeout(
                Math.max(1, Math.min(12000, deadline - Date.now())),
              ),
            },
          );
          if (!response.ok) {
            throw new Error(
              `API-Football HTTP ${response.status} : ${
                response.status === 429
                  ? "limite de requêtes atteinte"
                  : "collecte indisponible"
              }.`,
            );
          }
          return await response.json();
        },
      },
      new Date().toISOString(),
    );
    const published = await rpc("match_live_publish", {
      p_token: token,
      p_states: collection.states,
      p_results: collection.results,
      p_checked: collection.checked,
      p_requests: requests,
      p_deferred: collection.deferred,
      p_issue: collection.issue ? safeError(collection.issue) : null,
    });
    return respond({ ok: true, ...liveObject(published) });
  } catch (error) {
    const message = safeError(error);
    if (token) {
      try {
        await rpc("match_live_fail", {
          p_token: token,
          p_error: message,
          p_requests: requests,
        });
      } catch { /* Lease expiry recovers a worker lost during an outage. */ }
    }
    return respond({ ok: false, error: message }, 500);
  }
});
