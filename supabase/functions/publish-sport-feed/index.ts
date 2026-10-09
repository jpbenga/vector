import { overviewPart } from "../_shared/delivery/feed_delivery.ts";
import { deliveryRpc } from "../_shared/delivery/feed_delivery_store.ts";
import { publicationHandler } from "../_shared/sports/publication_bridge.ts";

Deno.serve(publicationHandler({
  secret: () => Deno.env.get("API_FOOTBALL_SYNC_SECRET"),
  publish: (payload) =>
    deliveryRpc("publish_sport_feed", {
      p_payload: payload,
      p_overview: overviewPart("hockey", payload),
    }),
}));
