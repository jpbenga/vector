import {
  type Candidate,
  type Context,
  type Intent,
  type Ticket,
} from "./contracts.ts";
import { compositionKey, totals } from "./engine.ts";
import {
  assessCandidate,
  compareCompositions,
  type CompositionProposal,
  exploreCompositions,
  measureComposition,
} from "./workshop.ts";

export const approachLabels: Record<string, string> = {
  balanced: "Arguments complémentaires",
  fewer_matches: "Moins de rencontres",
  other_markets: "Autres marchés",
  different_matches: "Autres rencontres",
};
export function comparisonReference(ticket: Ticket) {
  return {
    id: ticket.id,
    number: ticket.number,
    picks: ticket.picks.map((p) => ({
      id: p.id,
      match: `${p.home} — ${p.away}`,
      selection: p.selection,
    })),
  };
}
function ticketFrom(
  proposal: CompositionProposal,
  intent: Intent,
  context: Context,
  index: number,
  reference?: Ticket,
): Ticket {
  return {
    id: crypto.randomUUID(),
    number: index + 1,
    stake: proposal.stake,
    picks: proposal.picks,
    totalOdds: proposal.totalOdds,
    returnTotal: proposal.returnTotal,
    netProfit: proposal.netProfit,
    target: intent.tickets[index],
    context: structuredClone(context),
    constraints: {
      maxSelections: intent.maxSelections ?? 6,
      marketIds: intent.marketIds,
      requireEachSport: intent.requireEachSport,
      sports: intent.sports,
      goalMode: intent.goalMode,
    },
    warnings: [
      "Retour arithmétique si toutes les sélections gagnent, sans garantie.",
      "Cotes et statut à vérifier avant toute utilisation.",
    ],
    workshop: {
      approach: proposal.approach,
      metrics: proposal.metrics,
      notes: [],
      comparison: proposal.comparison,
      ...(reference ? { comparedTo: comparisonReference(reference) } : {}),
    },
  };
}
export function composeWorkshop(
  candidates: Candidate[],
  intent: Intent,
  context: Context,
  history: { tickets?: Ticket[]; compositions?: string[] } = {},
  now = new Date(),
) {
  const reference = intent.referenceTicketId
    ? history.tickets?.find((t) => t.id === intent.referenceTicketId)
    : undefined;
  const excluded = new Set(history.compositions ?? []),
    tickets: Ticket[] = [],
    proposals: Ticket[] = [],
    reports = [];
  let pool = candidates;
  for (let i = 0; i < intent.tickets.length; i++) {
    const result = exploreCompositions(pool, intent, context, {
      now,
      targetIndex: i,
      reference: reference?.picks,
      preserveFixtures: intent.preserveFixtures,
      excludedCompositions: [...excluded],
      maxAlternatives: intent.tickets.length === 1 ? 3 : 1,
      maxExpansions: 40000,
      maxComputeMs: 650 / intent.tickets.length,
    });
    reports.push(result.report);
    const options = result.alternatives.map((p) =>
      ticketFrom(p, intent, context, i, reference)
    );
    if (!options.length) continue;
    tickets.push(options[0]);
    if (intent.tickets.length === 1) {
      proposals.push(...options);
      for (const option of options.slice(1)) {
        option.workshop!.comparedTo = comparisonReference(
          reference ?? options[0],
        );
      }
    }
    for (const option of options) excluded.add(compositionKey(option.picks));
    if (intent.diversify && intent.tickets.length > 1) {
      const fixtures = new Set(
        options[0].picks.map((p) => `${p.sport}:${p.matchId}`),
      );
      pool = pool.filter((p) => !fixtures.has(`${p.sport}:${p.matchId}`));
    }
  }
  if (tickets.reduce((n, t) => n + t.stake, 0) > context.budget + .001) {
    throw new Error("Les mises dépassent le budget.");
  }
  return { tickets, proposals, reports };
}
export function reviseWorkshop(
  tickets: Ticket[],
  intent: Intent,
  candidates: Candidate[],
  now: Date,
) {
  const ti = intent.ticketIndex, pi = intent.selectionIndex;
  if (ti === null || pi === null || !tickets[ti]?.picks[pi]) return null;
  const original = tickets[ti],
    keep = original.picks.filter((_, i) => i !== pi);
  let picks: Candidate[], proposal: CompositionProposal | undefined;
  if (intent.action === "remove") {
    if (
      !keep.length ||
      keep.some((p) => assessCandidate(p, now).exclusions.length)
    ) return null;
    picks = keep;
  } else {
    const result = exploreCompositions(
      candidates,
      {
        ...intent,
        tickets: [original.target],
        sports: original.constraints?.sports ?? intent.sports,
        maxSelections: original.picks.length,
        goalMode: original.constraints?.goalMode ?? "minimum",
      },
      original.context,
      {
        now,
        reference: original.picks,
        fixed: keep,
        maxAlternatives: 1,
        maxExpansions: 20000,
        maxComputeMs: 650,
      },
    );
    proposal = result.alternatives[0];
    if (!proposal || proposal.picks.length !== original.picks.length) {
      return null;
    }
    // Keep visual order and the exact frozen retained selections.
    const changed = proposal.picks.find((p) =>
      !keep.some((k) => k.id === p.id)
    );
    if (!changed) return null;
    picks = original.picks.map((p, index) => index === pi ? changed : p);
  }
  const next: Ticket = {
    ...original,
    id: crypto.randomUUID(),
    picks,
    ...totals(picks, original.stake),
    workshop: {
      approach: proposal?.approach ?? "fewer_matches",
      metrics: proposal?.metrics ??
        measureComposition(picks, original.target, now),
      notes: [],
      comparison: compareCompositions(original.picks, picks),
      comparedTo: comparisonReference(original),
    },
    warnings: [
      ...original.warnings,
      ...(intent.action === "remove"
        ? [
          "Le retrait modifie le retour potentiel ; l’objectif initial peut ne plus être atteint.",
        ]
        : []),
    ],
  };
  return tickets.map((t, index) => index === ti ? next : t);
}
