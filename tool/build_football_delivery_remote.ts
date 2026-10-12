import { buildFeedDelivery } from "../supabase/functions/_shared/delivery/feed_delivery_build.ts";
if (
  Deno.env.get("GITHUB_ACTIONS") !== "true" ||
  Deno.env.get("SUPABASE_URL") !== "https://ednvvxxvlawaagjyshkj.supabase.co"
) {
  throw new Error(
    "This delivery publication runs on the configured GitHub project only",
  );
}
const result = await buildFeedDelivery("football");
if (result.committed !== true) {
  throw new Error(
    `Football delivery was not committed: ${
      result.skipped ?? "revision changed or lease expired"
    }`,
  );
}
console.log(
  JSON.stringify({ footballDelivery: result, providerCalls: 0, modelCalls: 0 }),
);
