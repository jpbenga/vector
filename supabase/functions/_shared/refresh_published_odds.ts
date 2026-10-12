import { obj, rows } from "./generator/contracts.ts";

/** Rebuilds quote facts from existing cache, scoped by fixture/league/season.
 * Observation times stay untouched: rebuilding a document never refreshes a price. */
export function refreshPublishedOdds(
  raw: Record<string, unknown>,
  cached: Record<string, unknown>[],
) {
  const fixtures = new Map(
    rows(raw.fixtures).map((f) => [String(obj(f.fixture).id), obj(f.league)]),
  );
  const quotes = new Map(
    rows(raw.odds).filter((p) => fixtures.has(String(obj(p.fixture).id))).map(
      (p) => [String(obj(p.fixture).id), p],
    ),
  );
  for (
    const c of [...cached].filter((c) =>
      c.endpoint === "/odds" &&
      !Object.keys(obj(obj(c.response_body).errors)).length
    )
      .sort((a, b) => String(a.fetched_at).localeCompare(String(b.fetched_at)))
  ) {
    const params = obj(c.query_params);
    for (const q of rows(obj(c.response_body).response)) {
      const id = String(obj(q.fixture).id), league = fixtures.get(id);
      if (
        !league ||
        (params.league != null &&
          String(params.league) !== String(league.id)) ||
        (params.season != null &&
          String(params.season) !== String(league.season))
      ) continue;
      const old = quotes.get(id);
      if (
        old && Date.parse(String(old.update)) > Date.parse(String(q.update))
      ) continue;
      if (!Number.isFinite(Date.parse(String(q.update)))) continue;
      quotes.set(id, q);
    }
  }
  return [...quotes.values()];
}
