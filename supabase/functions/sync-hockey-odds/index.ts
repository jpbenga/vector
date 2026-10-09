import { db, object, rpc, safeError } from "../_shared/ops_runtime.ts";
import { hockeyQuoteRecords } from "../_shared/sports/hockey_odds.ts";
import {
  hockeyLeagueIds,
  type PublicFixture,
} from "../_shared/sports/hockey_feed.ts";

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }
  const secret = Deno.env.get("API_FOOTBALL_SYNC_SECRET");
  if (!secret || request.headers.get("authorization") !== `Bearer ${secret}`) {
    return new Response("Unauthorized", { status: 401 });
  }
  const plan = object(await rpc("hockey_odds_claim"));
  if (typeof plan.token !== "string") {
    return Response.json({ ok: true, skipped: true });
  }
  let requests = 0;
  try {
    const key = Deno.env.get("API_HOCKEY_KEY") ||
      Deno.env.get("API_FOOTBALL_KEY");
    if (!key) throw new Error("Hockey API configuration missing");
    const snapshots = await db(
      "sport_feed_snapshots?sport=eq.hockey&select=payload&order=captured_at.desc&limit=1",
    );
    const payload = object(snapshots?.[0]?.payload);
    const fixtures =
      (Array.isArray(payload.items) ? payload.items : []) as PublicFixture[];
    const groups = [
      ...new Map(
        fixtures.filter((f) =>
          hockeyLeagueIds.includes(Number(f.competitionId)) &&
          f.status === "scheduled" && Date.parse(f.startsAt) > Date.now() &&
          Date.parse(f.startsAt) < Date.now() + 8 * 86400000
        )
          .map((
            f,
          ) => [`${f.competitionId}:${f.season}`, {
            league: f.competitionId,
            season: f.season,
          }]),
      ).values(),
    ];
    if (!groups.length) {
      throw new Error("No upcoming published hockey fixtures");
    }
    const deadline = Date.now() + 50000, failures: string[] = [];
    let prices = 0, matches = 0;
    // One request per league/season, not one request per match; batches of three.
    for (let i = 0; i < groups.length; i += 3) {
      await Promise.all(
        groups.slice(i, i + 3).map(async ({ league, season }) => {
          try {
            if (
              Date.now() > deadline - 1000 ||
              object(
                  await rpc("hockey_live_reserve", {
                    p_token: null,
                    p_live: false,
                  }),
                ).allowed !== true
            ) throw new Error("Quota or deadline");
            const url = new URL("https://v1.hockey.api-sports.io/odds");
            url.search = new URLSearchParams({ league, season }).toString();
            requests++;
            const response = await fetch(url, {
              headers: { "x-apisports-key": key },
              redirect: "error",
              signal: AbortSignal.timeout(
                Math.min(15000, Math.max(1, deadline - Date.now())),
              ),
            });
            if (!response.ok) {
              throw new Error(`Provider HTTP ${response.status}`);
            }
            const rows = hockeyQuoteRecords(
              await response.json(),
              fixtures,
              league,
              season,
              new Date().toISOString(),
            );
            await rpc("hockey_odds_publish", {
              p_token: plan.token,
              p_rows: rows,
            });
            prices += rows.reduce((n, r) => n + r.quotes.length, 0);
            matches += rows.filter((r) => r.quotes.length).length;
          } catch {
            failures.push(league);
          } // Keep the previous prices when a provider call fails.
        }),
      );
    }
    await rpc("hockey_odds_finish", {
      p_token: plan.token,
      p_requests: requests,
      p_error: failures.length
        ? `Leagues deferred: ${failures.join(",")}`
        : null,
    });
    return Response.json({
      ok: !failures.length,
      requests,
      matches,
      prices,
      deferredLeagues: failures,
    });
  } catch (e) {
    await rpc("hockey_odds_finish", {
      p_token: plan.token,
      p_requests: requests,
      p_error: safeError(e),
    }).catch(() => {});
    return Response.json({ ok: false, error: safeError(e) }, { status: 500 });
  }
});
