import {
  calendarDay,
  type Context,
  type Intent,
  intentFrom,
  type Sport,
  type State,
} from "./contracts.ts";

/** Business constraints are patched individually, independently of the words used. */
export const constraintFields = [
  "date",
  "sports",
  "tickets",
  "minSelections",
  "maxSelections",
  "targetOdds",
  "marketIds",
  "goalMode",
  "requireEachSport",
  "diversify",
  "view",
  "radarKind",
  "stake",
  "returnMinimum",
  "returnMaximum",
  "returnKind",
] as const;
export interface ConversationPlan {
  intent: Intent;
  changedFields: string[];
  newTask: boolean;
  focusMode: "keep" | "choose" | "clear";
  focusKeys: string[];
}
export const providerId = (id: string) => id.replace(/^api-fixture-/, "");
export const matchKey = (sport: Sport, id: string) =>
  `${sport}:${providerId(id)}`;
export const businessId = (sport: Sport, id: string) =>
  sport === "football" ? `api-fixture-${providerId(id)}` : id;
export function initialIntent(context: Context, date: string): Intent {
  return {
    action: "analyze",
    date,
    sports: Object.keys(context.preferences) as Sport[],
    tickets: [],
    minSelections: null,
    maxSelections: null,
    targetOdds: null,
    marketIds: [],
    goalMode: "unconstrained",
    requireEachSport: false,
    diversify: false,
    ticketIndex: null,
    selectionIndex: null,
    message: "",
    view: "profile",
    radarKind: "teams",
    preserveConstraints: false,
    preserveFixtures: false,
  };
}
export function ticketSummary(t: State["tickets"][number]) {
  return {
    id: t.id,
    number: t.number,
    stake: t.stake,
    target: t.target,
    constraints: t.constraints,
    totalOdds: t.totalOdds,
    returnTotal: t.returnTotal,
    netProfit: t.netProfit,
    picks: t.picks.map((p, index) => ({
      index,
      id: p.id,
      key: matchKey(p.sport, p.matchId),
      sport: p.sport,
      matchId: p.matchId,
      match: `${p.home} — ${p.away}`,
      kickoff: p.kickoff,
      marketId: p.marketId,
      market: p.market,
      selection: p.selection,
      odds: p.odds,
      oddsAt: p.oddsAt,
      bookmaker: p.bookmaker,
      evidence: p.evidence,
      warnings: p.warnings,
    })),
    workshop: t.workshop,
    warnings: t.warnings,
  };
}
export function workingIntent(
  state: State | null,
  context: Context,
  date: string,
): Intent {
  return structuredClone(
    state?.conversation?.workingIntent ?? state?.pendingIntent ??
      state?.intent ?? initialIntent(context, date),
  );
}
export function knownFocus(state: State | null) {
  if (state?.conversation) return structuredClone(state.conversation.focus);
  const analysis = state?.messages.findLast((m) => m.analysis)?.analysis;
  return analysis
    ? [
      ...analysis.selections.map((s) => ({
        sport: s.candidate.sport,
        matchId: s.candidate.matchId,
        match: `${s.candidate.home} — ${s.candidate.away}`,
      })),
      ...(analysis.observations ?? []).map((o) => ({
        sport: o.sport,
        matchId: o.matchId,
        match: o.match,
      })),
    ]
    : [];
}
export function validatePlan(value: unknown): ConversationPlan {
  const v = value as ConversationPlan;
  if (
    !v || typeof v !== "object" || Array.isArray(v) ||
    Object.keys(v).sort().join() !==
      ["intent", "changedFields", "newTask", "focusMode", "focusKeys"].sort()
        .join() ||
    !Array.isArray(v.changedFields) ||
    v.changedFields.some((f) =>
      !constraintFields.includes(f as typeof constraintFields[number])
    ) ||
    new Set(v.changedFields).size !== v.changedFields.length ||
    typeof v.newTask !== "boolean" ||
    !["keep", "choose", "clear"].includes(v.focusMode) ||
    !Array.isArray(v.focusKeys) ||
    v.focusKeys.length > 6 ||
    v.focusKeys.some((k) =>
      typeof k !== "string" || !/^(football|hockey):\d{1,12}$/.test(k)
    ) ||
    new Set(v.focusKeys).size !== v.focusKeys.length ||
    (v.focusMode !== "choose" && v.focusKeys.length) ||
    (v.focusMode === "choose" && !v.focusKeys.length)
  ) throw new Error("Plan de conversation invalide.");
  return { ...v, intent: intentFrom(v.intent) };
}
export function resolvePlan(
  plan: ConversationPlan,
  state: State | null,
  context: Context,
  date: string,
) {
  const base = plan.newTask
    ? initialIntent(context, date)
    : workingIntent(state, context, date);
  let reference = plan.intent.referenceTicketId
    ? [
      ...(state?.tickets ?? []),
      ...(state?.drafts ?? []),
      ...(state?.pending ?? []),
    ].find((t) => t.id === plan.intent.referenceTicketId)
    : undefined;
  if (plan.intent.referenceTicketId && !reference) {
    throw new Error("Ce ticket n’appartient pas à cette session.");
  }
  if (reference) {
    // Explicit object references recover that object's constraints, even after other tasks.
    Object.assign(base, reference.constraints, {
      date: calendarDay(reference.picks[0].kickoff, reference.context.timezone),
      tickets: [reference.target],
    });
  }
  const intent = { ...base };
  const targetFields: Record<string, "stake" | "minimum" | "maximum" | "kind"> =
    {
      stake: "stake",
      returnMinimum: "minimum",
      returnMaximum: "maximum",
      returnKind: "kind",
    };
  for (const field of plan.changedFields) {
    if (targetFields[field]) {
      if (!intent.tickets.length) {
        intent.tickets = [{
          stake: null,
          minimum: null,
          maximum: null,
          kind: "unspecified",
        }];
      }
      intent.tickets = intent.tickets.map((t, i) => {
        const supplied = plan.intent.tickets[i] ?? plan.intent.tickets[0];
        if (!supplied) {
          throw new Error("Précision de mise ou d’objectif manquante.");
        }
        return { ...t, [targetFields[field]]: supplied[targetFields[field]] };
      });
      continue;
    }
    (intent as unknown as Record<string, unknown>)[field] = structuredClone(
      plan.intent[field as keyof Intent],
    );
  }
  Object.assign(intent, {
    action: plan.intent.action,
    message: plan.intent.message,
    referenceTicketId: reference?.id ?? null,
    referenceAnalysisAt: null,
    ticketIndex: plan.intent.ticketIndex,
    selectionIndex: plan.intent.selectionIndex,
    preserveConstraints: false,
    preserveFixtures: false,
  });
  delete intent.fixtureFocus;
  // A display context can change while discussing a ticket. Current authorizations win.
  if (intent.view === "current") {
    intent.view = base.view === "current" ? "profile" : base.view ?? "profile";
  }
  if (intent.radarKind === "current") {
    intent.radarKind = base.radarKind === "current"
      ? "teams"
      : base.radarKind ?? "teams";
  }
  const changedScope = plan.changedFields.some((f) =>
    ["date", "sports", "view", "radarKind"].includes(f)
  );
  const focus = plan.focusMode === "clear" || plan.newTask || changedScope
    ? []
    : knownFocus(state);
  if (plan.focusMode === "keep" && focus.length) intent.fixtureFocus = focus;
  // With an explicit smaller maximum, choose a subset instead of demanding every previous match.
  if (
    intent.fixtureFocus &&
    intent.fixtureFocus.length <= (intent.maxSelections ?? 6)
  ) intent.preserveFixtures = true;
  if (
    reference && intent.action === "alternative" && plan.focusMode === "keep" &&
    !changedScope
  ) {
    intent.fixtureFocus = reference.picks.map((p) => ({
      sport: p.sport,
      matchId: p.matchId,
      match: `${p.home} — ${p.away}`,
    }));
    intent.preserveFixtures =
      intent.fixtureFocus.length <= (intent.maxSelections ?? 6);
  }
  return intent;
}

/** Retain exact constraints/identities alongside a bounded readable conversation ledger. */
export function rememberTurn(
  next: State,
  previous: State | null,
  intent: Intent,
  focus: NonNullable<Intent["fixtureFocus"]>,
  consultations: NonNullable<State["conversation"]>["consultations"],
) {
  const prior = previous?.conversation;
  const turns = [...(prior?.turns ?? []), {
    at: next.updatedAt,
    request: next.messages.at(-2)?.text ?? "",
    response: next.messages.at(-1)?.text ?? "",
    constraints: structuredClone(intent),
    focus: structuredClone(focus),
    ticketIds: [
      ...new Set([
        ...(next.messages.at(-1)?.ticketIds ?? []),
        ...(next.messages.at(-1)?.proposalIds ?? []),
      ]),
    ],
    selections: next.messages.at(-1)?.analysis?.selections.map((s) => ({
      key: matchKey(s.candidate.sport, s.candidate.matchId),
      candidateId: s.candidate.id,
      marketId: s.candidate.marketId,
      selection: s.candidate.selection,
      odds: s.candidate.odds,
      oddsAt: s.candidate.oddsAt,
      reason: s.reason,
      vigilance: s.vigilance,
      references: structuredClone(s.references),
    })),
  }];
  next.conversation = {
    version: 1,
    workingIntent: structuredClone(intent),
    focus: structuredClone(focus),
    turns,
    consultations: [
      ...new Map(
        [...(prior?.consultations ?? []), ...consultations].map((
          c,
        ) => [c.key, c]),
      ).values(),
    ].slice(-20),
    olderTurns: prior?.olderTurns ?? 0,
  };
  while (JSON.stringify(next.conversation).length > 50000 && turns.length > 1) {
    turns.shift();
    next.conversation.olderTurns++;
  }
  // Older full analyses duplicate evidence; their chosen identities survive in the ledger.
  for (const m of next.messages.slice(0, -2)) {
    if (JSON.stringify(next).length <= 210000) break;
    delete m.analysis;
  }
  while (JSON.stringify(next).length > 210000 && next.versions.length) {
    next.versions.shift();
  }
  while (
    JSON.stringify(next).length > 210000 && (next.drafts?.length ?? 0) > 1
  ) next.drafts!.shift();
  while (JSON.stringify(next).length > 210000 && next.messages.length > 2) {
    next.messages.shift();
  }
  if (JSON.stringify(next).length > 210000) {
    throw new Error(
      "La session contient trop de données ; les éléments précédents sont conservés.",
    );
  }
}
