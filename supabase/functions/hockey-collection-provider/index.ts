import { hockeyCollectionProvider } from "../_shared/sports/hockey_collection_provider.ts";
import { rpc } from "../_shared/ops_runtime.ts";
Deno.serve(hockeyCollectionProvider({
  secret: () => Deno.env.get("API_FOOTBALL_SYNC_SECRET"),
  reserve: async () =>
    (await rpc("hockey_live_reserve", { p_token: null, p_live: false }) as {
      allowed?: boolean;
    }).allowed === true,
  request: async (path, parameters) => {
    const key = Deno.env.get("API_HOCKEY_KEY") ||
      Deno.env.get("API_FOOTBALL_KEY");
    if (!key) throw new Error("Missing hockey provider configuration");
    const url = new URL(path, "https://v1.hockey.api-sports.io/");
    url.search = new URLSearchParams(parameters).toString();
    return await fetch(url, {
      headers: { "x-apisports-key": key },
      redirect: "error",
      signal: AbortSignal.timeout(30000),
    });
  },
}));
