/** Offline real-tool replay. Input contains PUBLIC publications only, no account/AI key.
 * deno run --allow-read --allow-write tool/check_generator_catalogue_parity.ts <capture> [report]
 * Capture after publication through the authoritative readers, then run this same check.
 */
import { ConversationReader } from "../supabase/functions/_shared/generator/conversation_tools.ts";
import {
  type DaySourcePort,
  loadDaySources,
} from "../supabase/functions/_shared/generator/day_sources.ts";
import {
  type Context,
  type Json,
  obj,
  rows,
  type Sport,
} from "../supabase/functions/_shared/generator/contracts.ts";

export function capturedPort(capture: Json): DaySourcePort {
  return {
    manifest: async () => capture.manifest,
    page: async (p) => {
      const keys = new Set(rows(p.p_matches).map((m) => m.key));
      const ids = new Set(rows(p.p_sources).map((s) => s.id));
      return {
        sources: rows(obj(capture.page).sources).filter((s) => ids.has(s.id))
          .map((s) => {
            const payload = obj(s.payload);
            return {
              ...s,
              payload: s.sport === "hockey"
                ? {
                  ...payload,
                  items: rows(payload.items).filter((f) =>
                    keys.has(`hockey:${f.id}`)
                  ),
                }
                : {
                  ...payload,
                  raw: {
                    ...obj(payload.raw),
                    fixtures: rows(obj(payload.raw).fixtures).filter((f) =>
                      keys.has(`football:${obj(f.fixture).id}`)
                    ),
                  },
                },
            };
          }),
      };
    },
  };
}

export async function catalogueParity(
  capture: Json,
  day: string,
  asOf: string,
  sport: Sport,
) {
  const context: Context = {
    origin: "profile",
    scope: "discovery",
    view: "all",
    configurationPolicy: "request",
    timezone: "Europe/Paris",
    budget: 100,
    preferences: {},
  };
  const port = capturedPort(capture);
  const reader = new ConversationReader({
    context,
    date: day,
    now: new Date(asOf),
    state: null,
    id: "parity",
    message: "",
  }, {
    sources: async () => {
      throw Error("The paginated publication reader must be used");
    },
    daySources: (c, d, sports, progress) =>
      loadDaySources(c, d, sports, port, progress),
  });
  const found: Json[] = [];
  let queryId = "", offset = 0;
  do {
    const q = obj(
      await reader.execute("search_matches", {
        date: day,
        sports: [sport],
        view: "all",
        radarKind: "teams",
        query: null,
        offset,
        limit: 7,
      }),
    );
    if (!obj(q.coverage).complete) {
      throw Error("Incomplete discovery cannot establish parity");
    }
    queryId = String(q.queryId);
    found.push(...rows(q.matches));
    if (!q.hasMore) break;
    if (!Number.isInteger(q.nextOffset) || Number(q.nextOffset) <= offset) {
      throw Error("Incomplete pagination");
    }
    offset = Number(q.nextOffset);
  } while (true);
  const visible = rows(capture.visible);
  const missing = visible.filter((v) => !found.some((m) => m.key === v.key));
  const extra = found.filter((m) => !visible.some((v) => m.key === v.key));
  if (missing.length || extra.length) {
    throw Error(
      `Catalogue divergence: missing=${missing.map((m) => m.key)} extra=${
        extra.map((m) => m.key)
      }`,
    );
  }
  for (const v of visible) {
    const match = found.find((m) => m.key === v.key)!;
    for (
      const field of [
        "competitionId",
        "season",
        "home",
        "away",
        "kickoff",
        "sourceId",
        "capturedAt",
      ]
    ) {
      if (
        field === "capturedAt"
          ? Date.parse(String(match[field])) !== Date.parse(String(v[field]))
          : match[field] !== v[field]
      ) {
        throw Error(`Publication mismatch: ${v.key} ${field}`);
      }
    }
  }
  const details: Json[] = [];
  for (let start = 0; start < found.length; start += 8) {
    details.push(
      ...rows(
        await reader.execute("read_matches", {
          queryId,
          matchKeys: found.slice(start, start + 8).map((m) => m.key),
        }),
      ),
    );
  }
  return {
    sport,
    day,
    asOf,
    visible: visible.length,
    discoverable: found.length,
    withPublishedFacts:
      details.filter((m) => rows(m.evidence).length > 0).length,
    // Evidence presence is not independent validation of sporting analysis quality.
    composable:
      details.filter((m) => obj(m.marketAvailability).prematchEligible).length,
    matches: details.map((m) => ({
      key: m.key,
      home: m.home,
      away: m.away,
      sourceId: m.sourceId,
      capturedAt: m.capturedAt,
      publishedQuotes: rows(m.publishedQuotes).length,
      facts: rows(m.evidence).length,
      candidates: rows(m.candidates).length,
      marketAvailability: m.marketAvailability,
    })),
    paidModelCalls: 0,
  };
}

if (import.meta.main) {
  const [input, output] = Deno.args;
  if (!input) throw Error("Public capture path required");
  const document = obj(JSON.parse(await Deno.readTextFile(input))),
    results = [];
  for (const [sport, capture] of Object.entries(obj(document.sports))) {
    results.push(
      await catalogueParity(
        obj(capture),
        String(document.day),
        String(document.asOf),
        sport as Sport,
      ),
    );
  }
  if (output) {
    await Deno.writeTextFile(output, JSON.stringify(results, null, 2));
  }
  console.log(
    JSON.stringify(results.map(({ matches: _, ...summary }) => summary)),
  );
}
