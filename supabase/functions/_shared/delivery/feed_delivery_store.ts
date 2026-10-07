import { type FeedSport, type Json, partArtifacts } from "./feed_delivery.ts";
export async function putDeliveryJson(
  path: string,
  body: Json,
): Promise<number> {
  const value = JSON.stringify(body);
  const response = await fetch(
    `${
      Deno.env.get("SUPABASE_URL")
    }/storage/v1/object/lector-feed-delivery/${path}`,
    {
      method: "POST",
      headers: {
        authorization: `Bearer ${Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")}`,
        "Content-Type": "application/json",
        "cache-control": "31536000",
        "x-upsert": "false",
      },
      body: value,
      signal: AbortSignal.timeout(20000),
      redirect: "error",
    },
  );
  // The source-id path is immutable; an existing object is a successful retry.
  if (!response.ok && response.status !== 409 && response.status !== 400) {
    throw new Error(`Delivery upload HTTP ${response.status}`);
  }
  if (response.status === 400) {
    const error = await response.json();
    if (
      error.error !== "Duplicate" &&
      error.message !== "The resource already exists"
    ) throw new Error("Delivery upload rejected");
  }
  return new TextEncoder().encode(value).length;
}
export async function deliveryRpc(name: string, body: Json): Promise<unknown> {
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const response = await fetch(
    `${Deno.env.get("SUPABASE_URL")}/rest/v1/rpc/${name}`,
    {
      method: "POST",
      headers: {
        apikey: key!,
        authorization: `Bearer ${key}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(20000),
      redirect: "error",
    },
  );
  if (!response.ok) {
    throw new Error(`Delivery registration HTTP ${response.status}`);
  }
  const text = await response.text();
  return text ? JSON.parse(text) : null;
}
export async function publishDeliveryPart(
  input: {
    sport: FeedSport;
    sourceId: string;
    scopeKey: string;
    capturedAt: string;
    asOf: string;
    windowStart: string;
    windowEnd: string;
    payload: Json;
  },
) {
  if (!/^[a-zA-Z0-9_-]+$/.test(input.sourceId)) {
    throw new Error("Invalid delivery source identity");
  }
  const fullPath = `delivery/${input.sport}/${input.sourceId}/full.json`;
  const bundle = partArtifacts(input.sport, input.sourceId, input.payload);
  const entries = [...bundle.artifacts.entries()];
  for (let start = 0; start < entries.length; start += 4) {
    await Promise.all(
      entries.slice(start, start + 4).map(([path, payload]) =>
        putDeliveryJson(path, payload)
      ),
    );
  }
  await deliveryRpc("feed_delivery_register", {
    p_sport: input.sport,
    p_source_id: input.sourceId,
    p_scope_key: input.scopeKey,
    p_captured_at: input.capturedAt,
    p_as_of: input.asOf,
    p_window_start: input.windowStart,
    p_window_end: input.windowEnd,
    p_full_path: fullPath,
    p_overview: bundle.overview,
  });
}
