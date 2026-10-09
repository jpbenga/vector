import { object, providerRows, type PublicFixture } from "./hockey_feed.ts";

// Only markets with an unambiguous 60-minute settlement are enabled. Provider
// Home/Away and generic totals are not silently treated as regulation markets.
export const hockeyMarkets = {
  result_regulation: {
    id: 1,
    name: "3Way Result",
    label: "Résultat à 60 minutes (1N2)",
  },
  double_chance_regulation: {
    id: 9,
    name: "Double Chance",
    label: "Double chance à 60 minutes",
  },
  total_goals_regulation: {
    id: 52,
    name: "Over/Under (Reg Time)",
    label: "Total de buts à 60 minutes",
  },
} as const;
export interface HockeyQuote {
  marketCode: keyof typeof hockeyMarkets;
  selectionCode: string;
  scope: "regulation";
  bookmaker: string;
  bookmakerId: string;
  decimalOdds: number;
  capturedAt: string;
  line?: number;
}
export interface HockeyQuoteRecord {
  matchId: string;
  competitionId: string;
  season: string;
  homeId: string;
  awayId: string;
  collectedAt: string;
  quotes: HockeyQuote[];
}
/** Validate the provider envelope AND fixture identity before accepting prices. */
export function hockeyQuoteRecords(
  payload: unknown,
  fixtures: PublicFixture[],
  league: string,
  season: string,
  collectedAt: string,
): HockeyQuoteRecord[] {
  if (!Number.isFinite(Date.parse(collectedAt))) {
    throw new Error("Invalid quote timestamp");
  }
  const games = providerRows(payload);
  const records = fixtures.filter((f) =>
    f.competitionId === league && f.season === season &&
    f.status === "scheduled" && Date.parse(f.startsAt) > Date.parse(collectedAt)
  ).map((f) => ({
    matchId: f.id,
    competitionId: league,
    season,
    homeId: f.home.id,
    awayId: f.away.id,
    collectedAt,
    quotes: [] as HockeyQuote[],
  }));
  for (const row of games) {
    const game = object(row.game),
      teams = object(game.teams),
      l = object(row.league);
    const record = records.find((r) => r.matchId === String(game.id));
    const fixture = fixtures.find((f) => f.id === String(game.id));
    if (
      !record || !fixture ||
      Date.parse(String(game.date)) !== Date.parse(fixture.startsAt) ||
      String(l.id) !== league || String(l.season) !== season ||
      String(object(teams.home).id) !== record.homeId ||
      String(object(teams.away).id) !== record.awayId
    ) continue;
    const seen = new Set<string>();
    for (
      const b of Array.isArray(row.bookmakers) ? row.bookmakers.map(object) : []
    ) {
      if (
        !Number.isInteger(b.id) || typeof b.name !== "string" || !b.name.trim()
      ) continue;
      for (const bet of Array.isArray(b.bets) ? b.bets.map(object) : []) {
        const market = Object.entries(hockeyMarkets).find(([, m]) =>
          m.id === bet.id && m.name === bet.name
        );
        if (!market) continue;
        for (
          const v of Array.isArray(bet.values) ? bet.values.map(object) : []
        ) {
          const odds = Number(v.odd), value = String(v.value);
          if (!Number.isFinite(odds) || odds <= 1 || odds > 100) continue;
          let selectionCode = "", line: number | undefined;
          if (bet.id === 1) {
            selectionCode =
              ({ Home: "home", Draw: "draw", Away: "away" })[value] ?? "";
          }
          if (bet.id === 9) {
            selectionCode = ({
              "Home/Draw": "home_draw",
              "Draw/Away": "draw_away",
              "Home/Away": "home_away",
            })[value] ?? "";
          }
          if (bet.id === 52) {
            const parts = /^(Over|Under) (\d+\.5)$/.exec(value);
            if (parts) {
              selectionCode = parts[1].toLowerCase();
              line = Number(parts[2]);
            }
            if (line !== undefined && (line < .5 || line > 15.5)) continue;
          }
          if (!selectionCode) continue;
          const key = `${b.id}:${market[0]}:${selectionCode}:${line ?? ""}`;
          if (seen.has(key)) continue;
          seen.add(key);
          record.quotes.push({
            marketCode: market[0] as HockeyQuote["marketCode"],
            selectionCode,
            scope: "regulation",
            bookmaker: b.name.trim(),
            bookmakerId: String(b.id),
            decimalOdds: odds,
            // The provider doesn't supply an update time. This is the time we actually observed its response.
            capturedAt: collectedAt,
            ...(line === undefined ? {} : { line }),
          });
        }
      }
    }
  }
  return records;
}
