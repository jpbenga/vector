import { collectHockeyLive } from "../_shared/sports/hockey_live.ts";
import { object } from "../_shared/sports/hockey_feed.ts";
import { rpc, safeError } from "../_shared/ops_runtime.ts";

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }
  const secret = Deno.env.get("API_FOOTBALL_SYNC_SECRET");
  if (!secret || request.headers.get("authorization") !== `Bearer ${secret}`) {
    return new Response("Unauthorized", { status: 401 });
  }
  let token: string | null = null, requests = 0;
  try {
    const body = await request.json().catch(() => ({}));
    // Local full collection uses this same atomic provider quota. The endpoint
    // is private; the browser never receives this server secret or API key.
    if (body?.action === "reserve_collection") {
      return Response.json(
        await rpc("hockey_live_reserve", { p_token: null, p_live: false }),
      );
    }
    const plan = object(await rpc("hockey_live_claim"));
    if (typeof plan.token !== "string") {
      return Response.json({ ok: true, skipped: true });
    }
    token = plan.token;
    const key = Deno.env.get("API_HOCKEY_KEY") ||
      Deno.env.get("API_FOOTBALL_KEY");
    if (!key) throw new Error("Hockey API configuration missing");
    const deadline = Date.now() + 42000;
    const collection = await collectHockeyLive(plan.dates as string[], {
      reserve: async () =>
        Date.now() < deadline &&
        object(
            await rpc("hockey_live_reserve", { p_token: token, p_live: true }),
          ).allowed === true,
      request: async (date) => {
        requests++;
        const url = new URL("https://v1.hockey.api-sports.io/games");
        url.search = new URLSearchParams({ date, timezone: "Europe/Paris" })
          .toString();
        const response = await fetch(url, {
          headers: { "x-apisports-key": key },
          redirect: "error",
          signal: AbortSignal.timeout(
            Math.max(1, Math.min(12000, deadline - Date.now())),
          ),
        });
        if (!response.ok) throw new Error(`API-Hockey HTTP ${response.status}`);
        return response.json();
      },
    }, new Date().toISOString());
    const published = await rpc("hockey_live_publish", {
      p_token: token,
      p_states: collection.states,
      p_requests: requests,
      p_deferred: collection.deferred,
    });
    return Response.json({ ok: true, ...object(published) });
  } catch (error) {
    if (token) {
      await rpc("hockey_live_fail", {
        p_token: token,
        p_error: safeError(error),
        p_requests: requests,
      }).catch(() => {});
    }
    return Response.json({ ok: false, error: safeError(error) }, {
      status: 500,
    });
  }
});
