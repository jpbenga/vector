import {
  type Candidate,
  type Context,
  type Intent,
  type Target,
  type Ticket,
} from "./contracts.ts";
// Deterministic money arithmetic; the model never computes or supplies prices.
export function totals(picks: Candidate[], stake: number) {
  let product = 1n, divisor = 1n;
  for (const pick of picks) {
    const parts = pick.odds.toString().split(".");
    const fraction = parts[1] ?? "";
    product *= BigInt(parts[0] + fraction);
    divisor *= 10n ** BigInt(fraction.length);
  }
  const rounded = (n: bigint, d: bigint) => Number((n + d / 2n) / d);
  const returnTotal =
    rounded(product * BigInt(Math.round(stake * 100)), divisor) / 100;
  return {
    totalOdds: rounded(product * 100n, divisor) / 100,
    returnTotal,
    netProfit: Math.round((returnTotal - stake) * 100) / 100,
  };
}
function within(picks: Candidate[], target: Target) {
  const value = totals(picks, target.stake!).returnTotal -
    (target.kind === "net" ? target.stake! : 0);
  return (target.minimum === null || value >= target.minimum - 0.005) &&
    (target.maximum === null || value <= target.maximum + 0.005);
}
export function compatible(picks: Candidate[], next: Candidate) {
  return picks.every((p) =>
    p.matchId !== next.matchId && p.bookmaker === next.bookmaker &&
    !p.teams.some((team) => next.teams.includes(team))
  );
}
export function compose(
  candidates: Candidate[],
  intent: Intent,
  context: Context,
): Ticket[] {
  const used = new Set<string>(), result: Ticket[] = [];
  const sorted = [...candidates].filter((c) =>
    intent.sports.includes(c.sport) &&
    (!intent.marketIds.length || intent.marketIds.includes(c.marketId))
  ).sort((a, b) => {
    // Independent data families precede raw signal counts. This is not a probability.
    const depth = (c: Candidate) =>
      new Set(
        c.evidence.filter((e) => e.source === "reading").map((e) => e.family),
      ).size;
    return depth(b) - depth(a) || a.warnings.length - b.warnings.length ||
      a.kickoff.localeCompare(b.kickoff) || a.id.localeCompare(b.id);
  });
  for (const [index, target] of intent.tickets.entries()) {
    if (target.stake === null) break;
    const available = sorted.filter((c) =>
      !intent.diversify || !used.has(c.matchId)
    );
    // Fair cap by fixture, not by bookmaker rows belonging to one early fixture.
    const matches = [...new Set(available.map((c) => c.matchId))].slice(0, 24);
    const pool = matches.flatMap((id) =>
      available.filter((c) => c.matchId === id).slice(0, 12)
    );
    let attempts = 0, chosen: Candidate[] | null = null;
    const walk = (start: number, picks: Candidate[]) => {
      if (chosen || attempts++ >= 16000) return;
      if (
        picks.length && within(picks, target) &&
        (!intent.requireEachSport ||
          intent.sports.every((s) => picks.some((p) => p.sport === s)))
      ) {
        chosen = picks;
        return;
      }
      if (picks.length >= (intent.maxSelections ?? 6)) return;
      if (
        target.maximum !== null &&
        (totals(picks, target.stake!).returnTotal -
            (target.kind === "net" ? target.stake! : 0)) > target.maximum
      ) return;
      for (let i = start; i < pool.length && !chosen && attempts < 16000; i++) {
        if (compatible(picks, pool[i])) walk(i + 1, [...picks, pool[i]]);
      }
    };
    walk(0, []);
    if (!chosen) continue;
    const picks = chosen as Candidate[];
    result.push({
      id: crypto.randomUUID(),
      number: index + 1,
      stake: target.stake,
      picks,
      ...totals(picks, target.stake),
      target,
      context: structuredClone(context),
      warnings: [
        "Retour arithmétique si toutes les sélections gagnent, sans garantie.",
        "Cotes et statut à vérifier de nouveau avant toute utilisation.",
      ],
    });
    for (const p of picks) used.add(p.matchId);
  }
  if (
    result.reduce((total, t) => total + t.stake, 0) > context.budget + 0.001
  ) throw new Error("Budget exceeded");
  return result;
}
export function revise(
  tickets: Ticket[],
  intent: Intent,
  candidates: Candidate[],
): Ticket[] | null {
  const index = intent.ticketIndex, pickIndex = intent.selectionIndex;
  if (
    index === null || pickIndex === null || index < 0 || pickIndex < 0 ||
    !tickets[index]?.picks[pickIndex]
  ) return null;
  const original = tickets[index],
    old = original.picks[pickIndex],
    keep = original.picks.filter((_, i) => i !== pickIndex);
  const replacement = intent.action === "remove"
    ? null
    : candidates.find((c) =>
      c.id !== old.id && c.matchId !== old.matchId &&
      intent.sports.includes(c.sport) &&
      (!intent.marketIds.length || intent.marketIds.includes(c.marketId)) &&
      compatible(keep, c) && within([...keep, c], original.target)
    );
  if (intent.action !== "remove" && !replacement) return null;
  const picks = replacement
    ? original.picks.map((p, i) => i === pickIndex ? replacement : p)
    : keep;
  if (!picks.length) return null;
  return tickets.map((t, i) =>
    i === index
      ? {
        ...t,
        picks,
        ...totals(picks, t.stake),
        warnings: [
          ...t.warnings,
          ...(!within(picks, original.target)
            ? ["Le retrait modifie l’objectif de retour initial."]
            : []),
        ],
      }
      : t
  );
}
