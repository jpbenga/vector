import { enrichHockeyPlayers } from "../../supabase/functions/_shared/sports/hockey_player_radar.ts";
import { enrichHockeyPublication } from "../../supabase/functions/_shared/sports/hockey_enrichment.ts";
import {
  calendarDate,
  collectHockey,
  compactHockeyCollection,
  hockeyLeagueIds,
  type SportPublication,
} from "../../supabase/functions/_shared/sports/hockey_feed.ts";

// Server-only process. The Flutter build receives the preview URL, never the key.
const root = new URL("../../", import.meta.url);
const storage = new URL("var/sports/hockey/", root);
const port = Number(
  Deno.args.find((a) => a.startsWith("--port="))?.split("=")[1] ?? 8100,
);
const collectOnly = Deno.args.includes("--collect-only");
const playersOnly = Deno.args.includes("--players-only");
const enrichOnly = Deno.args.includes("--enrich-only") || playersOnly;
const refresh = Deno.args.includes("--refresh");
const auditGame = Deno.args.find((a) => a.startsWith("--audit-game="))?.split(
  "=",
)[1];
if (!Number.isInteger(port) || port < 1024 || port > 65535) {
  throw new Error("Invalid preview port");
}
// Refuse an occupied serving port before reserving any provider request.
// collect-only and enrich-only intentionally do not open a server.
if (!collectOnly && !enrichOnly && !auditGame) {
  try {
    const probe = Deno.listen({ hostname: "127.0.0.1", port });
    probe.close();
  } catch (error) {
    if (error instanceof Deno.errors.AddrInUse) {
      throw new Error(
        `Le port hockey ${port} est déjà utilisé. Relancez via tool/run_multisport_local.sh pour réutiliser la source existante. Aucune requête API effectuée.`,
      );
    }
    throw error;
  }
}
await Deno.mkdir(storage, { recursive: true, mode: 0o700 });
const envText = await Deno.readTextFile(new URL(".env", root));
const env = Object.fromEntries(
  envText.split(/\r?\n/).flatMap((line) => {
    const match = /^([A-Z_]+)\s*=\s*(.*)$/.exec(line);
    if (!match) return [];
    return [[match[1], match[2].trim().replace(/^(['"])(.*)\1$/, "$2")]];
  }),
);
const key = env.API_HOCKEY_KEY || env.API_FOOTBALL_KEY;
if (!key) {
  throw new Error(
    "API_HOCKEY_KEY (or the shared API_FOOTBALL_KEY) is missing in .env",
  );
}
// Fixed trusted origin prevents accidental forwarding of the shared key.
const apiOrigin = "https://v1.hockey.api-sports.io/";
const lock = new URL(
  enrichOnly ? "collection-write.lock/" : "collector.lock/",
  storage,
);
const writeLock = new URL("collection-write.lock/", storage);
try {
  await Deno.mkdir(lock);
} catch (error) {
  if (error instanceof Deno.errors.AlreadyExists) {
    throw new Error(
      "A hockey preview is already running. Close its terminal before starting another one. A lock after a crash is at var/sports/hockey/collector.lock.",
    );
  }
  throw error;
}
if (!enrichOnly) {
  try {
    await Deno.mkdir(writeLock);
  } catch (error) {
    await Deno.remove(lock);
    throw error;
  }
}
let ownsWriteLock = true;
const releaseLock = async () => {
  if (ownsWriteLock) await Deno.remove(writeLock).catch(() => {});
  ownsWriteLock = false;
  if (!enrichOnly) await Deno.remove(lock).catch(() => {});
};
Deno.addSignalListener("SIGTERM", () => {
  releaseLock().finally(() => Deno.exit());
});
Deno.addSignalListener("SIGINT", () => {
  releaseLock().finally(() => Deno.exit());
});
const publicationPath = new URL("published.json", storage);
async function readPublication(): Promise<SportPublication | null> {
  try {
    return JSON.parse(await Deno.readTextFile(publicationPath));
  } catch (error) {
    if (error instanceof Deno.errors.NotFound) return null;
    throw error;
  }
}
async function atomicJson(path: URL, value: unknown) {
  const temp = new URL(`${path.href}.tmp`);
  const compact = [publicationPath.href].includes(path.href) ||
    path.pathname.endsWith("/compact.json");
  await Deno.writeTextFile(
    temp,
    JSON.stringify(value, null, compact ? undefined : 2),
    {
      mode: 0o600,
    },
  );
  await Deno.rename(temp, path);
}
let calls = 0;
let providerMinuteLimit = 100;
// Once installed, local full collection and remote live share the same atomic
// quota. A genuinely absent demo function is the only local-only fallback.
let remoteQuotaInstalled: boolean | null = null;
async function reserveRemoteCollection(): Promise<void> {
  if (remoteQuotaInstalled === false) return;
  if (!env.SUPABASE_URL || !env.API_FOOTBALL_SYNC_SECRET) return;
  const url = new URL("/functions/v1/sync-hockey-live", env.SUPABASE_URL);
  if (
    url.protocol !== "https:" ||
    url.hostname !== "ednvvxxvlawaagjyshkj.supabase.co"
  ) {
    throw new Error("Unexpected quota reservation destination");
  }
  const response = await fetch(url, {
    method: "POST",
    redirect: "error",
    signal: AbortSignal.timeout(12_000),
    headers: {
      "Content-Type": "application/json",
      authorization: `Bearer ${env.API_FOOTBALL_SYNC_SECRET}`,
    },
    body: JSON.stringify({ action: "reserve_collection" }),
  });
  if (response.status === 404 && remoteQuotaInstalled !== true) {
    remoteQuotaInstalled = false;
    return;
  }
  if (!response.ok) {
    throw new Error(
      `Shared hockey quota unavailable (HTTP ${response.status})`,
    );
  }
  const reservation = await response.json();
  remoteQuotaInstalled = true;
  if (reservation.allowed !== true) {
    throw new Error("Shared hockey quota reached; collection deferred");
  }
}
const budgetPath = new URL("quota-api-hockey.json", storage);
async function providerRequest(
  path: string,
  parameters: Record<string, string>,
  attempt = 0,
): Promise<unknown> {
  let ledger: number[] = [];
  try {
    ledger = JSON.parse(await Deno.readTextFile(budgetPath));
  } catch (e) {
    if (!(e instanceof Deno.errors.NotFound)) throw e;
  }
  while (true) {
    const time = Date.now(), day = new Date(time).toISOString().slice(0, 10);
    ledger = ledger.filter((t) => time - t < 24 * 60 * 60_000);
    if (
      ledger.filter((t) => new Date(t).toISOString().slice(0, 10) === day)
        .length >= 7500
    ) throw new Error("Local API-Hockey daily budget exhausted");
    const minute = ledger.filter((t) => time - t < 60_000);
    if (minute.length < providerMinuteLimit) break;
    await new Promise((resolve) =>
      setTimeout(resolve, Math.min(10_000, 60_001 - (time - minute[0])))
    );
  }
  await reserveRemoteCollection();
  ledger.push(Date.now());
  await atomicJson(budgetPath, ledger);
  calls++;
  if (calls % 50 === 0) {
    console.log(`Collecte hockey : ${calls} appels réservés.`);
  }
  const url = new URL(path, apiOrigin);
  url.search = new URLSearchParams(parameters).toString();
  const response = await fetch(url, {
    headers: { "x-apisports-key": key, "Cache-Control": "no-cache" },
    signal: AbortSignal.timeout(30_000),
    redirect: "error",
  });
  const rateHeaders = Object.fromEntries(
    [...response.headers].filter(([name]) =>
      /ratelimit|rate-limit|retry-after/i.test(name)
    ),
  );
  await atomicJson(new URL("last-rate-limit.json", storage), rateHeaders);
  const advertised = Number(response.headers.get("x-ratelimit-limit"));
  if (advertised > 0) {
    providerMinuteLimit = Math.min(
      providerMinuteLimit,
      Math.floor(advertised * .8),
    );
  }
  const payload = await response.json();
  const limited = response.status === 429 || payload?.errors?.rateLimit != null;
  if (limited && attempt < 3) {
    providerMinuteLimit = Math.max(30, Math.floor(providerMinuteLimit * .75));
    console.log(
      "Limite par minute signalée par le fournisseur : attente et reprise du même appel.",
    );
    await new Promise((resolve) => setTimeout(resolve, 62_000));
    return await providerRequest(path, parameters, attempt + 1);
  }
  if (!response.ok) throw new Error(`API-Hockey HTTP ${response.status}`);
  return payload;
}
async function enrichedPublication(
  publication: SportPublication,
): Promise<SportPublication> {
  const cacheDir = new URL("enrichment-cache/", storage);
  await Deno.mkdir(cacheDir, { recursive: true, mode: 0o700 });
  const now = new Date();
  const ports = {
    request: async (
      path: string,
      params: Record<string, string>,
      ttl: number,
    ) => {
      const cacheKey = path.replaceAll("/", "-") + "-" +
        Object.entries(params).sort().map(([k, v]) => `${k}-${v}`).join("-");
      const file = new URL(`${cacheKey}.json`, cacheDir);
      try {
        const cached = JSON.parse(await Deno.readTextFile(file));
        if (
          Date.now() - Date.parse(cached.at) < ttl &&
          (ttl !== 24 * 60 * 60_000 ||
            calendarDate(new Date(cached.at)) === calendarDate(new Date()))
        ) return cached.payload;
      } catch (e) {
        if (!(e instanceof Deno.errors.NotFound)) throw e;
      }
      const payload = await providerRequest(path, params);
      const envelope = payload as { errors?: unknown; response?: unknown };
      if (
        !envelope.errors || Object.keys(envelope.errors).length ||
        envelope.response == null
      ) {
        await atomicJson(new URL("last-provider-error.json", storage), {
          path,
          params,
          payload,
        });
        throw new Error(
          `API-Hockey rejected ${path} (private diagnostic saved)`,
        );
      }
      await atomicJson(file, { at: new Date().toISOString(), payload });
      return payload;
    },
  };
  let result = playersOnly ? publication : await enrichHockeyPublication(
    {
      ...publication,
      capturedAt: now.toISOString(),
      baseCapturedAt: publication.baseCapturedAt ?? publication.capturedAt,
    },
    ports,
    now,
  );
  const rawGames = new Map<string, unknown>();
  for (const c of publication.competitions ?? []) {
    rawGames.set(
      c.id,
      JSON.parse(
        await Deno.readTextFile(
          new URL(
            `raw/${publication.collectionId}/games-${c.id}.json`,
            storage,
          ),
        ),
      ),
    );
  }
  result = await enrichHockeyPlayers(result, rawGames, ports, now);
  await atomicJson(new URL("enrichment-run.json", storage), {
    completedAt: now.toISOString(),
    baseCapturedAt: publication.baseCapturedAt ?? publication.capturedAt,
    providerRequests: calls,
    fixtures: result.items.length,
    historicalGames: new Set(result.items.flatMap((f) =>
      ((f as unknown as { headToHead: { meetings: { id: string }[] } })
        .headToHead?.meetings ?? []).map((m) =>
          m.id
        )
    )).size,
  });
  return result;
}
try {
  if (auditGame) {
    if (!/^\d+$/.test(auditGame)) throw new Error("Invalid game ID");
    const payload = await providerRequest("games", { id: auditGame });
    await atomicJson(new URL(`audit-game-${auditGame}.json`, storage), payload);
    // The game response has no credentials. Keep raw details private, print
    // only factual identity/status/score fields for the audit.
    const envelope = payload as { errors?: unknown; response?: unknown[] };
    if (!envelope.errors || Object.keys(envelope.errors).length) {
      throw new Error("Provider rejected audit request");
    }
    for (const raw of envelope.response ?? []) {
      const g = raw as Record<string, unknown>;
      console.log(
        JSON.stringify({
          id: g.id,
          date: g.date,
          league: g.league,
          teams: g.teams,
          status: g.status,
          scores: g.scores,
          periods: g.periods,
        }),
      );
    }
    await releaseLock();
    Deno.exit(0);
  }
  const now = new Date();
  let publication = await readPublication();
  if (enrichOnly && !refresh && !publication) {
    throw new Error(
      "No base hockey publication to enrich; run a full collection first",
    );
  }
  const fresh = publication?.competitions?.length === hockeyLeagueIds.length &&
    publication &&
    calendarDate(
        new Date(publication.baseCapturedAt ?? publication.capturedAt),
      ) === calendarDate(now) &&
    now.getTime() -
          Date.parse(publication.baseCapturedAt ?? publication.capturedAt) <
      15 * 60_000;
  if ((enrichOnly || fresh) && !refresh && publication) {
    // Player-history backfill keeps the existing calendar, scores, H2H and
    // standings intact. Only its event ledgers are enriched.
    if (!playersOnly) {
      // Rebuild retained raw data after adapter changes without another API call.
      const raw = await Promise.all(hockeyLeagueIds.map(async (leagueId) => {
        const read = async (kind: string) =>
          JSON.parse(
            await Deno.readTextFile(
              new URL(
                `raw/${publication!.collectionId}/${kind}-${leagueId}.json`,
                storage,
              ),
            ),
          );
        return {
          leagueId,
          leagues: await read("leagues"),
          games: await read("games"),
          standings: await read("standings"),
        };
      }));
      publication = compactHockeyCollection(
        raw,
        new Date(publication.baseCapturedAt ?? publication.capturedAt),
        publication.collectionId,
      );
    }
    publication = await enrichedPublication(publication);
    await atomicJson(publicationPath, publication);
  }
  if (refresh || (!enrichOnly && !fresh)) {
    const id = crypto.randomUUID();
    const rawDir = new URL(`raw/${id}/`, storage);
    await Deno.mkdir(rawDir, { recursive: true, mode: 0o700 });
    try {
      publication = await collectHockey(
        {
          request: providerRequest,
          saveRaw: (kind, payload) =>
            atomicJson(new URL(`${kind}.json`, rawDir), payload),
          publish: async (compact) => {
            compact = await enrichedPublication(compact);
            await atomicJson(new URL("compact.json", rawDir), compact);
            await atomicJson(publicationPath, compact);
          },
        },
        now,
        id,
      );
      publication = await readPublication();
      await atomicJson(new URL("run.json", rawDir), {
        id,
        status: "succeeded",
        providerRequests: calls,
        items: publication!.items.length,
      });
    } catch (error) {
      await atomicJson(new URL("run.json", rawDir), {
        id,
        status: "failed",
        providerRequests: calls,
        error: String(error),
      });
      throw error;
    }
  }
  console.log(
    `Hockey (7 ligues): ${publication!.items.length} rencontres, ${
      publication!.windowStart
    } → ${publication!.windowEnd}. ${calls} appels API (${
      calls === 0 ? "publication récente réutilisée" : "collecte réelle"
    }).`,
  );
  const retained: { path: URL; modified: number }[] = [];
  for await (const entry of Deno.readDir(new URL("raw/", storage))) {
    if (!entry.isDirectory) continue;
    const path = new URL(`raw/${entry.name}/`, storage);
    const info = await Deno.stat(path);
    retained.push({ path, modified: info.mtime?.getTime() ?? 0 });
  }
  retained.sort((a, b) => b.modified - a.modified);
  const publishedRaw =
    new URL(`raw/${publication!.collectionId}/`, storage).href;
  for (
    const old of retained.filter((r) => r.path.href !== publishedRaw).slice(2)
  ) {
    await Deno.remove(old.path, { recursive: true });
  }
  await Deno.remove(writeLock).catch(() => {});
  ownsWriteLock = false;
  if (collectOnly || enrichOnly) {
    await releaseLock();
    Deno.exit(0);
  }
  Deno.serve({ hostname: "127.0.0.1", port }, async (request) => {
    const url = new URL(request.url);
    const origin = request.headers.get("origin");
    const allowed = !origin ||
      /^http:\/\/(localhost|127\.0\.0\.1):\d+$/.test(origin);
    if (!allowed) return new Response("Local preview only", { status: 403 });
    const headers = {
      "Cache-Control": "no-store",
      ...(origin
        ? { "Access-Control-Allow-Origin": origin, "Vary": "Origin" }
        : {}),
    };
    if (request.method === "OPTIONS") return new Response(null, { headers });
    if (request.method !== "GET" || url.pathname !== "/sports/hockey/feed") {
      return new Response("Not found", { status: 404, headers });
    }
    // Only the compact public contract is exposed. Raw responses stay private.
    const compact = await readPublication();
    return compact
      ? Response.json(compact, { headers })
      : new Response(null, { status: 204, headers });
  });
} catch (error) {
  await releaseLock();
  console.error(String(error));
  Deno.exit(1);
}
