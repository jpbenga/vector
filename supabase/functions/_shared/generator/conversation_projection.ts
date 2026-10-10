import type { Candidate, Evidence, Ticket } from "./contracts.ts";
import { ticketSummary } from "./conversation_memory.ts";
import { assessCandidate } from "./workshop.ts";

/** Presentation assets are irrelevant to analysis. Keep every sporting fact. */
export function modelEvidence(e: Evidence) {
  const { photo: _photo, ...fact } = e;
  return fact;
}

/** The encounter supplies identity and facts once, markets reference them. */
export function modelCandidate(c: Candidate, now: Date) {
  const assessment = assessCandidate(c, now);
  return {
    id: c.id,
    matchId: c.matchId,
    sport: c.sport,
    teams: c.teams,
    competitionId: c.competitionId,
    discovery: c.discovery,
    marketId: c.marketId,
    market: c.market,
    selection: c.selection,
    scope: c.scope,
    selectionCode: c.selectionCode,
    odds: c.odds,
    oddsAt: c.oddsAt,
    bookmaker: c.bookmaker,
    snapshotId: c.snapshotId,
    evidence: c.evidence.map((e) => ({
      id: e.id,
      supportsMarket: e.supportsMarket,
      role: e.role,
    })),
    assessment: {
      directReferences: assessment.directReferences,
      vigilanceReferences: assessment.vigilanceReferences,
      contextReferences: assessment.contextReferences,
      dataGroups: assessment.dataGroups,
      redundantReferences: assessment.redundantReferences,
      minimumSample: assessment.minimumSample,
      quoteAgeHours: assessment.quoteAgeHours,
      independence: assessment.independence,
      contradictions: assessment.contradictions,
      history: assessment.history,
      warnings: assessment.warnings,
      exclusions: assessment.exclusions,
    },
  };
}

/** Repeated markets/variants share a fact dictionary; persisted tickets stay full. */
export function modelTickets(tickets: Ticket[]) {
  const facts = new Map<
    string,
    Omit<ReturnType<typeof modelEvidence>, "supportsMarket" | "role">
  >();
  return {
    tickets: tickets.map((t) => {
      const summary = ticketSummary(t);
      return {
        ...summary,
        picks: summary.picks.map((p) => ({
          ...p,
          evidence: p.evidence.map((e) => {
            // The same observation may support one market and contradict
            // another. Its role belongs to the selection, not the dictionary.
            const { supportsMarket: _support, role: _role, ...fact } =
              modelEvidence(e);
            facts.set(e.id, fact);
            return { id: e.id, supportsMarket: e.supportsMarket, role: e.role };
          }),
        })),
      };
    }),
    facts: [...facts.values()],
    factSemantics:
      "Les faits sont fournis une seule fois. Chaque sélection référence ses propres soutiens, contextes et vigilances par id ; plusieurs références au même fait ne sont pas des preuves indépendantes.",
  };
}
