import {
  dayKey,
  dayOverview,
  type DeliveryPart,
  type FeedSport,
  type Json,
} from "./feed_delivery.ts";
import { deliveryRpc, putDeliveryJson } from "./feed_delivery_store.ts";
import { calendarRolloverBufferDays } from "../calendar_window.ts";

/** Same immutable delivery job, usable in the worker or the publication runner. */
export async function buildFeedDelivery(sport: FeedSport): Promise<Json> {
  const claim = await deliveryRpc("feed_delivery_claim", {
    p_sport: sport,
  }) as { token?: string; revision?: number };
  if (!claim.token) {
    return { ok: true, skipped: "unchanged_or_busy" };
  }
  try {
    const today = dayKey(new Date().toISOString()), manifests = [];
    const generation = crypto.randomUUID();
    const cachedOverviews = new Map<string, Record<string, unknown>>();
    for (let offset = -7; offset <= 13 + calendarRolloverBufferDays; offset++) {
      const date = new Date(`${today}T12:00:00Z`);
      date.setUTCDate(date.getUTCDate() + offset);
      const day = date.toISOString().slice(0, 10);
      const rows = await deliveryRpc("feed_delivery_parts_for_day", {
        p_sport: sport,
        p_day: day,
      }) as Record<string, unknown>[];
      const ids = rows.map((r) => String(r.source_id));
      const missing = ids.filter((id) => !cachedOverviews.has(id));
      for (let start = 0; start < missing.length; start += 5) {
        const url = new URL(
          "/rest/v1/sport_feed_delivery_parts",
          Deno.env.get("SUPABASE_URL"),
        );
        url.search = new URLSearchParams({
          sport: `eq.${sport}`,
          source_id: `in.(${missing.slice(start, start + 5).join(",")})`,
          select: "source_id,overview",
        }).toString();
        const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
        const response = await fetch(url, {
          headers: { apikey: key, authorization: `Bearer ${key}` },
          signal: AbortSignal.timeout(20000),
          redirect: "error",
        });
        if (!response.ok) {
          throw new Error(`Delivery overview HTTP ${response.status}`);
        }
        for (const row of await response.json()) {
          cachedOverviews.set(String(row.source_id), row.overview);
        }
      }
      if (ids.some((id) => !cachedOverviews.has(id))) {
        throw new Error("Incomplete delivery overview response");
      }
      // Retain only this day's sources; archive builds cannot grow memory forever.
      for (const id of cachedOverviews.keys()) {
        if (!ids.includes(id)) cachedOverviews.delete(id);
      }
      const selected: DeliveryPart[] = rows.map((r) => ({
        id: String(r.source_id),
        scopeKey: String(r.scope_key),
        capturedAt: String(r.captured_at),
        asOf: String(r.as_of),
        windowStart: String(r.window_start),
        windowEnd: String(r.window_end),
        fullPath: String(r.full_path),
        overview: cachedOverviews.get(String(r.source_id))!,
      }));
      const overview = dayOverview(sport, selected, day);
      if (!overview) continue;
      const path = `delivery/${sport}/${generation}/${day}.json`;
      const bytes = await putDeliveryJson(path, overview);
      manifests.push({
        schemaVersion: 1,
        sport,
        day,
        path,
        bytes,
        sourceIds: selected.map((p) => p.id),
        publishedAt: new Date().toISOString(),
      });
    }
    const committed = await deliveryRpc("feed_delivery_finish", {
      p_sport: sport,
      p_token: claim.token,
      p_revision: claim.revision,
      p_manifests: manifests,
    });
    return { ok: true, committed, days: manifests.length };
  } catch (error) {
    const message = error instanceof Error
      ? error.message
      : "Delivery build failed";
    await deliveryRpc("feed_delivery_finish", {
      p_sport: sport,
      p_token: claim.token,
      p_revision: claim.revision,
      p_manifests: [],
      p_error: message,
    });
    throw new Error(message);
  }
}
