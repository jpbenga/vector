import { publicationHandler } from "../../supabase/functions/_shared/sports/publication_bridge.ts";
import { overviewPart } from "../../supabase/functions/_shared/delivery/feed_delivery.ts";

const [source, destination] = Deno.args;
if (!source || !destination) throw new Error("Missing publication paths");
const handler = publicationHandler({
  secret: () => "offline-publication-validation",
  publish: async (payload) => {
    await Deno.writeTextFile(
      destination,
      JSON.stringify({
        p_payload: payload,
        p_overview: overviewPart("hockey", payload),
      }),
    );
    return { prepared: true };
  },
});
const response = await handler(
  new Request("https://offline.invalid/validate", {
    method: "POST",
    headers: { authorization: "Bearer offline-publication-validation" },
    body: await Deno.readTextFile(source),
  }),
);
if (!response.ok) {
  throw new Error(`Publication validation rejected (${response.status})`);
}
