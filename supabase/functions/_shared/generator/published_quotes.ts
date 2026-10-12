import { obj, rows } from "./contracts.ts";

/** Readable prices are independent of recommendation eligibility and user readings. */
export function footballPublishedQuotes(rawOdds: unknown, fixtureId: string) {
  const quotes = new Map<
    string,
    {
      marketId: string;
      market: string;
      selection: string;
      odds: number;
      bookmaker: string;
      bookmakerId: string;
      observedAt: string;
    }
  >();
  const prices = rows(rawOdds).filter((p) =>
    String(obj(p.fixture).id) === fixtureId
  )
    .sort((a, b) => String(b.update).localeCompare(String(a.update)));
  for (const p of prices) {
    const bookmakers = rows(p.bookmakers).sort((
      a,
      b,
    ) => (Number(a.id) === 8
      ? -1
      : Number(b.id) === 8
      ? 1
      : Number(a.id) - Number(b.id))
    );
    for (const b of bookmakers) {
      for (const m of rows(b.bets)) {
        for (const v of rows(m.values)) {
          const odds = Number(v.odd),
            selection = String(v.value ?? ""),
            marketId = String(m.id ?? "");
          if (!marketId || !selection || !Number.isFinite(odds) || odds <= 1) {
            continue;
          }
          const key = `${marketId}:${selection}`;
          if (!quotes.has(key)) {
            quotes.set(key, {
              marketId,
              market: String(m.name ?? marketId),
              selection,
              odds,
              bookmaker: String(b.name ?? ""),
              bookmakerId: String(b.id ?? ""),
              observedAt: String(p.update ?? ""),
            });
          }
        }
      }
    }
  }
  return [...quotes.values()];
}
export function footballQuoteAvailability(
  rawOdds: unknown,
  fixtureId: string,
  now: Date,
) {
  const quotes = footballPublishedQuotes(rawOdds, fixtureId);
  if (!quotes.length) return "unavailable" as const;
  return quotes.some((q) => {
      const age = now.getTime() - Date.parse(q.observedAt);
      return Number.isFinite(age) && age >= -60000 && age <= 48 * 3600000;
    })
    ? "recent" as const
    : "stale" as const;
}
