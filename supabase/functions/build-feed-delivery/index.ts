import { buildFeedDelivery } from "../_shared/delivery/feed_delivery_build.ts";
Deno.serve(async (request) => {
  const secret = Deno.env.get("API_FOOTBALL_SYNC_SECRET");
  if (!secret || request.headers.get("authorization") !== `Bearer ${secret}`) {
    return new Response("Unauthorized", { status: 401 });
  }
  if (request.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }
  const input = await request.json().catch(() => ({}));
  if (input.sport !== "football" && input.sport !== "hockey") {
    return Response.json({ error: "Invalid sport" }, { status: 400 });
  }
  try {
    return Response.json(await buildFeedDelivery(input.sport));
  } catch (error) {
    return Response.json({
      ok: false,
      error: error instanceof Error ? error.message : "Delivery build failed",
    }, { status: 500 });
  }
});
