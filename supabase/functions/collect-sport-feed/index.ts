import { publishDeliveryPart } from "../_shared/delivery/feed_delivery_store.ts";
import { collectNhl, object } from "../_shared/sports/hockey_feed.ts";
import { SupabaseSportStore } from "../_shared/sports/sport_store.ts";

// Installation/deployment remains a separate reviewed step; no scheduler here.
Deno.serve(async (request) => {
  if (request.method !== "POST") return new Response(null, { status: 405 });
  const secret = Deno.env.get("SPORT_SYNC_SECRET") ||
    Deno.env.get("API_FOOTBALL_SYNC_SECRET");
  if (!secret || request.headers.get("authorization") !== `Bearer ${secret}`) {
    return new Response(null, { status: 401 });
  }
  let runId: string | null = null;
  let store: SupabaseSportStore | null = null;
  try {
    const input = object(await request.json());
    if (input.sport !== "hockey" || input.competitionId !== "57") {
      return Response.json({
        ok: false,
        error: "Only NHL collection is enabled in this adapter",
      }, { status: 400 });
    }
    store = new SupabaseSportStore(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    const plan = object(await store.claim("hockey", "57"));
    if (typeof plan.run_id !== "string") {
      return Response.json({ ok: true, skipped: "disabled_or_busy" });
    }
    runId = plan.run_id;
    const key = Deno.env.get("API_HOCKEY_KEY") ||
      Deno.env.get("API_FOOTBALL_KEY");
    if (!key) throw new Error("Missing hockey provider configuration");
    const publication = await collectNhl(
      {
        request: async (path, parameters) => {
          if (await store!.reserve(runId!) !== true) {
            throw new Error("Hockey budget or lease unavailable");
          }
          const url = new URL(path, "https://v1.hockey.api-sports.io/");
          url.search = new URLSearchParams(parameters).toString();
          const response = await fetch(url, {
            headers: { "x-apisports-key": key },
            signal: AbortSignal.timeout(30_000),
            redirect: "error",
          });
          if (!response.ok) {
            throw new Error(`API-Hockey HTTP ${response.status}`);
          }
          return response.json();
        },
        saveRaw: (kind, payload) => store!.saveRaw(runId!, kind, payload),
        publish: async (payload) => {
          if (await store!.finish(runId!, payload) !== true) {
            throw new Error("Hockey publication lease lost");
          }
        },
      },
      new Date(String(plan.started_at)),
      runId,
    );
    if (Deno.env.get("FEED_DELIVERY_ENABLED") === "true") {
      await publishDeliveryPart({
        sport: "hockey",
        sourceId: runId,
        scopeKey: "hockey",
        capturedAt: publication.capturedAt,
        asOf: publication.capturedAt,
        windowStart: publication.windowStart,
        windowEnd: publication.windowEnd,
        payload: publication as unknown as Record<string, unknown>,
      });
    }
    return Response.json({
      ok: true,
      runId,
      items: publication.items.length,
      windowStart: publication.windowStart,
      windowEnd: publication.windowEnd,
    });
  } catch (error) {
    let diagnostic = error instanceof Error ? error.message : String(error);
    for (
      const name of [
        "API_HOCKEY_KEY",
        "API_FOOTBALL_KEY",
        "SPORT_SYNC_SECRET",
        "API_FOOTBALL_SYNC_SECRET",
        "SUPABASE_SERVICE_ROLE_KEY",
      ]
    ) {
      const value = Deno.env.get(name);
      if (value) diagnostic = diagnostic.split(value).join("[redacted]");
    }
    diagnostic = diagnostic.replace(/Bearer\s+[^\s"}]+/gi, "Bearer [redacted]")
      .slice(0, 1200);
    console.error(JSON.stringify({ runId, diagnostic }));
    if (runId && store) await store.fail(runId, diagnostic).catch(() => {});
    return Response.json({
      ok: false,
      runId,
      error: "NHL collection failed; inspect the server logs",
    }, { status: 500 });
  }
});
