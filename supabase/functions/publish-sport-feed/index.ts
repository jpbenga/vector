import { overviewPart } from "../_shared/delivery/feed_delivery.ts";
async function publish(payload: Record<string, unknown>) {
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const response = await fetch(
    `${Deno.env.get("SUPABASE_URL")}/rest/v1/rpc/publish_sport_feed`,
    {
      method: "POST",
      redirect: "error",
      signal: AbortSignal.timeout(60000),
      headers: {
        apikey: key,
        authorization: `Bearer ${key}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        p_payload: payload,
        p_overview: overviewPart("hockey", payload),
      }),
    },
  );
  if (!response.ok) {
    const body = await response.json().catch(() => ({}));
    const code =
      typeof body.code === "string" && /^[A-Z0-9]{5,10}$/.test(body.code)
        ? body.code
        : "unknown";
    const known = [
      "Invalid shared publication",
      "Duplicate match identity",
      "Invalid match boundary",
      "Publication version is immutable",
    ];
    const reason = known.includes(body.message)
      ? body.message
      : "Publication storage rejected";
    throw new Error(`Storage ${response.status}/${code}: ${reason}`);
  }
  return response.json();
}
import { publicationHandler } from "../_shared/sports/publication_bridge.ts";

Deno.serve(publicationHandler({
  secret: () => Deno.env.get("API_FOOTBALL_SYNC_SECRET"),
  publish,
}));
