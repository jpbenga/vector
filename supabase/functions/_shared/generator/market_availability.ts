import type { AnalysisMatch, Sport } from "./contracts.ts";

export interface MarketAvailability {
  quoteAvailability: AnalysisMatch["quoteAvailability"] | "unknown";
  candidateCount: number;
  prematchEligible: boolean;
  reasons: {
    code:
      | "kickoff_passed"
      | "fixture_not_scheduled"
      | "publication_stale"
      | "quotes_not_collected"
      | "quotes_stale"
      | "quotes_unavailable"
      | "quotes_unknown"
      | "no_supported_candidate";
    text: string;
  }[];
}

/** Price presence and prematch eligibility are distinct observations. A stale
 * scheduled status must never make a started encounter eligible again. */
export function marketAvailability(
  match: {
    sport: Sport;
    kickoff: string;
    status: string;
    capturedAt: string;
  },
  quoteAvailability: AnalysisMatch["quoteAvailability"] | undefined,
  candidateCount: number,
  now: Date,
): MarketAvailability {
  const reasons: MarketAvailability["reasons"] = [];
  const scheduled = match.sport === "hockey"
    ? match.status === "scheduled"
    : match.status === "NS";
  if (Date.parse(match.kickoff) <= now.getTime()) {
    reasons.push({
      code: "kickoff_passed",
      text:
        "L’heure prévue du coup d’envoi est passée : exclusion du combiné prématch, même si des cotes ont été collectées. Cela ne confirme pas le score ou le statut en direct.",
    });
  }
  if (!scheduled) {
    reasons.push({
      code: "fixture_not_scheduled",
      text:
        "Le statut publié de la rencontre ne permet pas une sélection prématch.",
    });
  }
  const age = now.getTime() - Date.parse(match.capturedAt);
  if (!Number.isFinite(age) || age < -60000 || age > 36 * 3600000) {
    reasons.push({
      code: "publication_stale",
      text:
        "La publication analytique ne satisfait pas le contrôle de fraîcheur.",
    });
  }
  if (quoteAvailability === "stale") {
    reasons.push({
      code: "quotes_stale",
      text:
        "Des cotes publiées sont consultables, mais leur relevé dépasse 48 h. Elles nécessitent une actualisation avant le calcul d’un combiné prématch.",
    });
  } else if (quoteAvailability === "not_collected") {
    reasons.push({
      code: "quotes_not_collected",
      text: "Aucune collecte de cotes n’est présente pour cette rencontre.",
    });
  } else if (quoteAvailability === "unavailable") {
    reasons.push({
      code: "quotes_unavailable",
      text:
        "Aucune cote récente utilisable parmi les marchés pris en charge ; absence ou ancienneté à distinguer lors de la consultation des données.",
    });
  } else if (!quoteAvailability) {
    reasons.push({
      code: "quotes_unknown",
      text:
        "La disponibilité des cotes n’a pas été vérifiée dans ce périmètre.",
    });
  }
  if (!reasons.length && candidateCount === 0) {
    reasons.push({
      code: "no_supported_candidate",
      text:
        "Des cotes récentes sont présentes, mais aucune sélection ne satisfait les marchés, lectures et filtres de ce périmètre. Ce n’est pas une absence de cotes.",
    });
  }
  return {
    quoteAvailability: quoteAvailability ?? "unknown",
    candidateCount,
    prematchEligible: !reasons.length && candidateCount > 0,
    reasons,
  };
}
