import { refreshPublishedOdds } from "../refresh_published_odds.ts";
import type { Source } from "./catalog.ts";
import { calendarDay, type Context, obj, rows } from "./contracts.ts";

/** Read only prices already collected by the server. No provider/model call,
 * no publication write, no modification of the analytical observation date. */
export async function withCollectedQuotes(
  sources: Source[],
  context: Context,
  date: string,
  now: Date,
  read: (query: URLSearchParams) => Promise<unknown>,
): Promise<Source[]> {
  // An old match must never acquire prices observed after that match.
  if (date < calendarDay(now, context.timezone)) return sources;
  const leagues = [
    ...new Set(
      sources.filter((s) => s.sport === "football")
        .flatMap((s) =>
          rows(obj(s.payload.raw).fixtures).map((f) => String(obj(f.league).id))
        )
        .filter((id) => /^\d{1,8}$/.test(id)),
    ),
  ];
  if (!leagues.length) return sources;
  const query = new URLSearchParams({
    select:
      "endpoint,query_hash,query_params,response_status,response_body,fetched_at",
    endpoint: "eq./odds",
    "query_params->>league": `in.(${leagues.join(",")})`,
    "query_params->>date": `eq.${date}`,
    fetched_at: `lte.${now.toISOString()}`,
    response_status: "eq.200",
    order: "fetched_at.desc",
    limit: "150",
  });
  let cached: ReturnType<typeof rows>;
  try {
    cached = rows(await read(query));
  } catch {
    // Available older prices still answer the request; a cache read failure
    // must not become another reason to block discovery or composition.
    return sources.map((s) =>
      s.sport !== "football" ? s : {
        ...s,
        payload: {
          ...s.payload,
          quoteRevision: {
            analysisAsOf: s.capturedAt,
            limitation:
              "Actualisation des cotes indisponible : dernier relevé publié conservé.",
          },
        },
      }
    );
  }
  const compact = cached.map((c) => ({
    ...c,
    response_body: {
      ...obj(c.response_body),
      response: rows(obj(c.response_body).response)
        .filter((q) =>
          Number.isFinite(Date.parse(String(q.update))) &&
          Date.parse(String(q.update)) <= now.getTime() + 60000
        )
        .map((q) => ({
          ...q,
          bookmakers: rows(q.bookmakers).map((b) => ({
            ...b,
            bets: rows(b.bets).filter((bet) =>
              [1, 5, 8, 12].includes(Number(bet.id))
            ),
          })),
        })),
    },
  }));
  return sources.map((s) => {
    if (s.sport !== "football") return s;
    const raw = obj(s.payload.raw);
    const odds = refreshPublishedOdds(raw, compact);
    const relevant = cached.filter((c) =>
      rows(raw.fixtures).some((f) =>
        String(obj(f.league).id) === String(obj(c.query_params).league) &&
        String(obj(f.league).season) === String(obj(c.query_params).season)
      )
    );
    return {
      ...s,
      payload: {
        ...s.payload,
        raw: { ...raw, odds },
        quoteRevision: {
          analysisAsOf: s.capturedAt,
          cacheReferences: relevant.map((c) => ({
            queryHash: c.query_hash,
            fetchedAt: c.fetched_at,
          })),
        },
      },
    };
  });
}
