import {
  calendarDate,
  collectNhl,
  compactNhlGames,
  type SportPublication,
} from "../../supabase/functions/_shared/sports/hockey_feed.ts";

// Server-only process. The Flutter build receives the preview URL, never the key.
const root = new URL("../../", import.meta.url);
const storage = new URL("var/sports/hockey/", root);
const port = Number(
  Deno.args.find((a) => a.startsWith("--port="))?.split("=")[1] ?? 8100,
);
const collectOnly = Deno.args.includes("--collect-only");
const refresh = Deno.args.includes("--refresh");
if (!Number.isInteger(port) || port < 1024 || port > 65535) {
  throw new Error("Invalid preview port");
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
const lock = new URL("collector.lock/", storage);
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
const releaseLock = async () => {
  await Deno.remove(lock).catch(() => {});
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
  await Deno.writeTextFile(temp, JSON.stringify(value, null, 2), {
    mode: 0o600,
  });
  await Deno.rename(temp, path);
}
let calls = 0;
try {
  const now = new Date();
  let publication = await readPublication();
  const fresh = publication &&
    calendarDate(new Date(publication.capturedAt)) === calendarDate(now) &&
    now.getTime() - Date.parse(publication.capturedAt) < 15 * 60_000;
  if (fresh && !refresh && publication) {
    // Rebuild retained raw data after adapter changes without another API call.
    const rawGames = JSON.parse(
      await Deno.readTextFile(
        new URL(`raw/${publication.collectionId}/games.json`, storage),
      ),
    );
    publication = compactNhlGames(rawGames, {
      season: publication.season,
      capturedAt: publication.capturedAt,
      windowStart: publication.windowStart,
      windowEnd: publication.windowEnd,
      timezone: publication.timezone,
      collectionId: publication.collectionId,
    });
    await atomicJson(publicationPath, publication);
  }
  if (!fresh || refresh) {
    const id = crypto.randomUUID();
    const rawDir = new URL(`raw/${id}/`, storage);
    await Deno.mkdir(rawDir, { recursive: true, mode: 0o700 });
    const budgetPath = new URL("quota-api-hockey.json", storage);
    const reserve = async () => {
      // Durable reservation before sending, including failed calls. Exclusive
      // collector lock serializes local requests. This is not a production quota guard.
      let ledger: number[] = [];
      try {
        ledger = JSON.parse(await Deno.readTextFile(budgetPath));
      } catch (e) {
        if (!(e instanceof Deno.errors.NotFound)) throw e;
      }
      const time = Date.now(), day = new Date(time).toISOString().slice(0, 10);
      ledger = ledger.filter((t) => time - t < 24 * 60 * 60_000);
      if (
        ledger.filter((t) => new Date(t).toISOString().slice(0, 10) === day)
            .length >= 7500 ||
        ledger.filter((t) => time - t < 60_000).length >= 280
      ) {
        throw new Error("Local API-Hockey budget exhausted; no request sent");
      }
      ledger.push(time);
      await atomicJson(budgetPath, ledger);
    };
    try {
      publication = await collectNhl(
        {
          request: async (path, parameters) => {
            await reserve();
            calls++;
            const url = new URL(path, apiOrigin);
            url.search = new URLSearchParams(parameters).toString();
            const response = await fetch(url, {
              headers: { "x-apisports-key": key },
              signal: AbortSignal.timeout(30_000),
              redirect: "error",
            });
            if (!response.ok) {
              throw new Error(`API-Hockey HTTP ${response.status}`);
            }
            return await response.json();
          },
          saveRaw: (kind, payload) =>
            atomicJson(new URL(`${kind}.json`, rawDir), payload),
          publish: async (compact) => {
            await atomicJson(new URL("compact.json", rawDir), compact);
            await atomicJson(publicationPath, compact);
          },
        },
        now,
        id,
      );
      await atomicJson(new URL("run.json", rawDir), {
        id,
        status: "succeeded",
        providerRequests: calls,
        items: publication.items.length,
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
    `NHL: ${publication!.items.length} rencontres, ${
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
  if (collectOnly) {
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
