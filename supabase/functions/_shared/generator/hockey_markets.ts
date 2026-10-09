import { hockeyMarkets } from "../sports/hockey_odds.ts";
import {
  type Candidate,
  type Evidence,
  type Json,
  obj,
  rows,
} from "./contracts.ts";

export function freshHockeyQuotes(f: Json, now: Date): Json[] {
  return rows(f.quotes).filter((q) => {
    const at = Date.parse(String(q.capturedAt)), odds = Number(q.decimalOdds);
    return !!hockeyMarkets[
      String(q.marketCode) as keyof typeof hockeyMarkets
    ] && q.scope === "regulation" &&
      typeof q.bookmaker === "string" && !!q.bookmaker &&
      typeof q.bookmakerId === "string" && !!q.bookmakerId &&
      Number.isFinite(odds) && odds > 1 && odds <= 100 && Number.isFinite(at) &&
      at <= now.getTime() + 60000 &&
      now.getTime() - at <= 48 * 3600000 && at < Date.parse(String(f.startsAt));
  });
}

export function hockeyCandidates(
  f: Json,
  source: { id: string },
  markets: string[],
  evidence: Evidence[],
  now: Date,
): Candidate[] {
  const home = obj(f.home), away = obj(f.away), candidates: Candidate[] = [];
  const positive =
    /:(standing_advantage|structural_level_gap|recent_form_advantage|form_gap|positive_streak|winning_streak|improving_form|strong_home_team|strong_away_team|home_away_advantage|away_home_advantage|head_to_head_dominance):/;
  const negative = /:(negative_streak|weak_home_team|weak_away_team):/;
  const seen = new Set<string>();
  for (const q of freshHockeyQuotes(f, now)) {
    const market = String(q.marketCode),
      code = String(q.selectionCode),
      odds = Number(q.decimalOdds),
      at = Date.parse(String(q.capturedAt));
    const definition = hockeyMarkets[market as keyof typeof hockeyMarkets];
    if (
      !definition || !markets.includes(market) || q.scope !== "regulation" ||
      !q.bookmakerId || !q.bookmaker ||
      !Number.isFinite(odds) || odds <= 1 || odds > 100 ||
      !Number.isFinite(at) || at > now.getTime() + 60000 ||
      now.getTime() - at > 48 * 3600000 || at >= Date.parse(String(f.startsAt))
    ) continue;
    const side = ["home", "home_draw"].includes(code)
      ? String(home.id)
      : ["away", "draw_away"].includes(code)
      ? String(away.id)
      : null;
    // An offensive observation alone doesn't support an arbitrary total line.
    // Goal thresholds need their own verified rules; no synthetic selections.
    if (
      market === "total_goals_regulation" || !side ||
      (market === "result_regulation" && !["home", "away"].includes(code)) ||
      (market === "double_chance_regulation" &&
        !["home_draw", "draw_away"].includes(code))
    ) continue;
    const direct = evidence.filter((e) =>
      e.source === "reading" && e.subject === side && positive.test(e.id)
    );
    if (
      !direct.length ||
      evidence.some((e) => e.subject === side && negative.test(e.id))
    ) continue;
    const label = code === "home"
      ? `${home.name} gagne à 60 minutes`
      : code === "away"
      ? `${away.name} gagne à 60 minutes`
      : code === "home_draw"
      ? `${home.name} ou nul à 60 minutes`
      : `${away.name} ou nul à 60 minutes`;
    const id =
      `hockey:${f.id}:${market}:regulation:${code}:${q.bookmakerId}:${q.capturedAt}`;
    if (seen.has(id)) continue;
    seen.add(id);
    candidates.push({
      id,
      matchId: String(f.id),
      sport: "hockey",
      competitionId: `hockey:api-hockey:competition:${f.competitionId}`,
      competition: String(f.competitionName),
      home: String(home.name),
      away: String(away.name),
      homeLogo: String(home.logoUrl ?? ""),
      awayLogo: String(away.logoUrl ?? ""),
      teams: [String(home.id), String(away.id)],
      kickoff: String(f.startsAt),
      marketId: market,
      market: definition.label,
      selection: label,
      odds,
      oddsAt: String(q.capturedAt),
      bookmaker: String(q.bookmaker),
      snapshotId: source.id,
      scope: "regulation",
      selectionCode: code,
      evidence: evidence.map((e) => ({
        ...e,
        supportsMarket: direct.includes(e),
        role: direct.includes(e)
          ? "support"
          : e.source === "reading" && e.subject !== side && positive.test(e.id)
          ? "vigilance"
          : "context",
      })),
      warnings: [
        "Marché à 60 minutes : prolongation et tirs au but exclus.",
        "Les séries de résultats utilisées incluent les victoires finales : elles ne garantissent pas une victoire à 60 minutes.",
        "Cote observée auprès du fournisseur ; sa date de mise à jour n’est pas fournie.",
      ],
      discovery: false,
    });
  }
  return candidates;
}
