import { buildCatalog, publishedReadingIds, type Source } from "./catalog.ts";
import {
  calendarDay,
  type Context,
  type Intent,
  type State,
  validateIntent,
} from "./contracts.ts";
import { compose, compositionKey, revise } from "./engine.ts";
import { composeWorkshop, reviseWorkshop } from "./compositions.ts";
export function sourceQuery(
  context: Context,
  date: string,
  sports = Object.keys(context.preferences),
) {
  const prefs = sports.flatMap((s) =>
    context.preferences[s as "football" | "hockey"] ?? []
  );
  return {
    p_date: date,
    p_timezone: context.timezone,
    p_sports: sports,
    p_competitions: context.scope === "strict"
      ? [...new Set(prefs.flatMap((p) => p.competitions))]
      : null,
    p_readings: publishedReadingIds(prefs.flatMap((p) => p.readings)),
    p_scenarios: [...new Set(prefs.flatMap((p) => p.scenarios ?? []))],
  };
}
/** References and frozen constraints are resolved by the server, not trusted to the model. */
export function resolveIntent(intent: Intent, state: State | null): Intent {
  if (
    intent.referenceAnalysisAt &&
    ["generate", "clarify"].includes(intent.action)
  ) {
    const message = state?.messages.find((m) =>
      m.at === intent.referenceAnalysisAt && m.analysis
    );
    const analysis = message?.analysis;
    const chosen = analysis
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
    if (!analysis || !chosen.length) {
      return {
        ...intent,
        action: "clarify",
        fixtureFocus: undefined,
        message:
          "Cette analyse n’a pas conservé de rencontres retenues avec des références vérifiées. Demandez-moi une nouvelle analyse ou précisez les rencontres à reprendre.",
      };
    }
    if (
      intent.date !== analysis.context.date ||
      intent.sports.some((s) => !analysis.context.sports.includes(s))
    ) {
      return {
        ...intent,
        action: "clarify",
        fixtureFocus: undefined,
        message:
          "Souhaitez-vous reprendre les rencontres de l’analyse précédente ou chercher celles de cette nouvelle journée ?",
      };
    }
    const focus = [
      ...new Map(chosen.map((m) => [`${m.sport}:${m.matchId}`, m])).values(),
    ];
    if ((intent.maxSelections ?? 6) < focus.length) {
      return {
        ...intent,
        action: "clarify",
        fixtureFocus: undefined,
        message:
          `L’analyse retient ${focus.length} rencontres. Lesquelles souhaitez-vous garder dans ce ticket plus court ?`,
      };
    }
    return {
      ...intent,
      fixtureFocus: focus,
      preserveFixtures: true,
      view: analysis.context.view === "discovery"
        ? "all"
        : analysis.context.view as Intent["view"],
      radarKind: analysis.context.radarKind as Intent["radarKind"],
      sports: [...new Set(focus.map((m) => m.sport))],
      maxSelections: intent.maxSelections ?? focus.length,
    };
  }
  if (intent.action !== "alternative") {
    if (!intent.fixtureFocus) return intent;
    const reset = { ...intent };
    delete reset.fixtureFocus;
    return reset;
  }
  const reference = intent.referenceTicketId
    ? [...(state?.tickets ?? []), ...(state?.drafts ?? [])].find((t) =>
      t.id === intent.referenceTicketId
    )
    : state?.tickets.at(-1);
  if (!reference) {
    return {
      ...intent,
      action: "clarify",
      message: "Quel ticket souhaitez-vous prendre comme point de départ ?",
    };
  }
  const previous = state?.intent;
  return {
    ...intent,
    referenceTicketId: reference.id,
    date: intent.preserveConstraints !== false
      ? calendarDay(reference.picks[0].kickoff, reference.context.timezone)
      : intent.date,
    sports: intent.preserveConstraints !== false
      ? reference.constraints?.sports ??
        [...new Set(reference.picks.map((p) => p.sport))]
      : intent.sports,
    tickets: intent.preserveConstraints !== false
      ? [reference.target]
      : intent.tickets,
    maxSelections: intent.preserveConstraints !== false
      ? reference.constraints?.maxSelections ?? previous?.maxSelections ?? 6
      : intent.maxSelections,
    marketIds: intent.preserveConstraints !== false
      ? reference.constraints?.marketIds ?? previous?.marketIds ?? []
      : intent.marketIds,
    goalMode: intent.preserveConstraints !== false
      ? reference.constraints?.goalMode ?? previous?.goalMode
      : intent.goalMode,
    preserveFixtures: intent.preserveFixtures ?? false,
    requireEachSport: intent.preserveConstraints !== false
      ? reference.constraints?.requireEachSport ?? previous?.requireEachSport ??
        false
      : intent.requireEachSport,
  };
}
export function applyIntent(
  input: {
    state: State | null;
    context: Context;
    intent: Intent;
    sources: Source[];
    message: string;
    now: Date;
    id: string;
    workshop?: boolean;
    /** Only the server conversation planner can resolve references and focus. */
    conversationResolved?: boolean;
    onWorkshop?: (report: unknown) => void;
  },
): State {
  const previous = input.state;
  if (!input.conversationResolved) {
    input.intent = resolveIntent(input.intent, previous);
  }
  // Revisions always use the original frozen configuration. A changed current
  // profile applies only when asking for a fresh generation.
  const context = input.conversationResolved
    ? input.context
    : ["generate", "explore", "analyze"].includes(input.intent.action)
    ? input.context
    : (input.intent.referenceTicketId
      ? [...(previous?.tickets ?? []), ...(previous?.drafts ?? [])].find((
        t,
      ) => t.id === input.intent.referenceTicketId)?.context
      : undefined) ??
      previous?.tickets[input.intent.ticketIndex ?? 0]?.context ??
      previous?.context ?? input.context;
  const error = validateIntent(input.intent, context, input.now);
  let reply = error ?? "", tickets = previous?.tickets ?? [], pending = null;
  const versions = [...(previous?.versions ?? [])];
  let catalog = previous?.catalog;
  let drafts = [
    ...(previous?.drafts ?? []),
    ...(previous?.tickets ?? []),
    ...(previous?.pending ?? []),
  ];
  const compositions = new Set([
    ...(previous?.compositions ?? []),
    ...drafts.map((t) => compositionKey(t.picks)),
  ]);
  let proposals = previous?.proposals ?? [];
  let proposalIds: string[] = [];
  let attachments: string[] = [];
  if (!error) {
    if (input.intent.action === "unsupported") {
      reply =
        "Je suis l’assistant de composition Lector. Je peux vous aider à explorer les rencontres et à préparer vos compositions, sans garantie de résultat ni récupération des pertes.";
    } else if (input.intent.action === "clarify") {
      reply = input.intent.message || "Précisez votre demande pour poursuivre.";
    } else if (input.intent.action === "restore") {
      pending = versions.at(-2) ?? null;
      reply = pending
        ? "La version précédente est prête à être restaurée. Confirmez son application."
        : "Aucune version précédente à restaurer.";
    } else if (input.intent.action === "explain") {
      const ticket = tickets[input.intent.ticketIndex ?? 0];
      reply = ticket
        ? ticket.picks.map((p) =>
          `${p.selection} : ${
            p.evidence.map((e) => e.text || e.label).join(" ")
          } ${p.warnings.join(" ")}`
        ).join("\n\n")
        : "Préparez d’abord une composition pour examiner ses raisons.";
    } else {
      const available = buildCatalog(
        input.sources,
        context,
        input.intent.date,
        input.now,
      );
      catalog = {
        matchCount: available.matchCount,
        radarCount: available.radarCount,
        missing: available.missing,
        sources: available.sources,
        signals: available.signals,
      };
      if (["explore", "analyze"].includes(input.intent.action)) {
        reply = available.signals.length
          ? available.signals.map((s) => s.text).join("\n\n")
          : "Aucun signal Radar suffisamment documenté n’a été trouvé pour cette date et ce contexte.";
      } else if (
        input.intent.marketIds.some((m) =>
          !input.intent.sports.some((s) =>
            context.preferences[s]?.markets.includes(m)
          )
        )
      ) {
        reply =
          "Un marché demandé ne fait pas partie de vos marchés autorisés. Modifiez vos préférences explicitement avant de l’utiliser.";
      } else if (["generate", "alternative"].includes(input.intent.action)) {
        const reuse = input.conversationResolved &&
          input.intent.action === "generate";
        const history = {
          tickets: drafts,
          compositions: reuse ? [] : [...compositions],
          allowSameComposition: reuse,
        };
        const workshop = input.workshop
          ? composeWorkshop(
            available.candidates,
            input.intent,
            context,
            history,
            input.now,
          )
          : null;
        input.onWorkshop?.(workshop?.reports ?? []);
        const focusedPool = input.intent.fixtureFocus
          ? available.candidates.filter((c) =>
            input.intent.fixtureFocus!.some((m) =>
              m.sport === c.sport && m.matchId === c.matchId
            )
          )
          : available.candidates;
        const composed = workshop?.tickets ??
          compose(focusedPool, input.intent, context, history);
        const proposed =
          input.intent.fixtureFocus && input.intent.preserveFixtures
            ? composed.filter((t) =>
              t.picks.length === input.intent.fixtureFocus!.length &&
              input.intent.fixtureFocus!.every((m) =>
                t.picks.some((p) =>
                  p.sport === m.sport && p.matchId === m.matchId
                )
              )
            )
            : composed;
        proposals = workshop?.proposals ?? [];
        proposalIds = proposals.length > 1 ? proposals.map((t) => t.id) : [];
        if (proposed.length) {
          const lastNumber = Math.max(0, ...drafts.map((t) => t.number));
          const numbered = proposals.length ? proposals : proposed;
          numbered.forEach((t, i) => t.number = lastNumber + i + 1);
          for (const option of proposals.slice(1)) {
            if (option.workshop?.comparedTo?.id === proposed[0].id) {
              option.workshop.comparedTo.number = proposed[0].number;
            }
          }
          attachments = proposed.map((t) => t.id);
          drafts.push(...(proposals.length ? proposals : proposed));
          (proposals.length ? proposals : proposed).forEach((t) =>
            compositions.add(compositionKey(t.picks))
          );
          if (input.intent.action === "alternative") {
            tickets = [...tickets, ...proposed].slice(-12);
            versions.push(tickets);
            reply = input.intent.preserveConstraints === false
              ? "Voici une autre composition, avec les ajustements demandés. Le ticket précédent reste disponible."
              : "Voici une autre composition, avec les contraintes conservées. Le ticket précédent reste disponible.";
          } else if (tickets.length) {
            pending = proposed;
            reply =
              "Une nouvelle composition est prête. Vous pouvez l’appliquer après examen.";
          } else {
            tickets = proposed;
            versions.push(proposed);
            reply = `${proposed.length} composition${
              proposed.length > 1 ? "s" : ""
            } préparée${
              proposed.length > 1 ? "s" : ""
            } avec marchés et cotes vérifiés.`;
          }
          if (proposalIds.length) {
            reply +=
              ` ${proposals.length} approches sont disponibles pour cette même mise. Choisissez une composition après examen.`;
          }
          if (input.workshop && input.intent.goalMode === "around") {
            reply +=
              " L’objectif est exploré avec une marge de 10 % autour du retour demandé.";
          }
          if (proposed.length < input.intent.tickets.length) {
            reply +=
              " Certaines compositions n’ont pas pu respecter toutes les contraintes ; elles ne sont pas complétées artificiellement.";
          }
        } else {
          reply = input.intent.fixtureFocus?.length
            ? `Je reprends ${
              input.intent.fixtureFocus.map((m) => m.match).join(" ; ")
            }. Aucun ticket réunissant ces rencontres avec leurs marchés autorisés, des cotes récentes et les contraintes demandées n’est disponible. Je conserve cette liste : je n’ajoute pas d’autres matchs. ${
              available.missing.join(" ")
            }`
            : !available.candidates.length
            ? `Aucune sélection ne dispose actuellement d’un marché autorisé, d’une cote récente et de lectures exploitables dans ce périmètre. ${
              available.missing.join(" ")
            }`
            : input.intent.action === "alternative"
            ? "Aucune composition différente n’a été trouvée avec ces contraintes et les données disponibles. Le ticket précédent est conservé. Vous pouvez choisir une autre date, un autre marché autorisé ou ajuster l’objectif."
            : "Les données vérifiées ne permettent pas de respecter votre demande. Vous pouvez élargir la date ou ajuster l’objectif.";
        }
      } else {
        // Keep the untouched selections only if they are still real and fresh.
        const freshIds = new Set(available.candidates.map((c) => c.id));
        const existingFresh = tickets.every((t, ti) =>
          t.picks.every((p, pi) =>
            (ti === input.intent.ticketIndex &&
              pi === input.intent.selectionIndex) || freshIds.has(p.id)
          )
        );
        pending = existingFresh
          ? (input.workshop
            ? reviseWorkshop(
              tickets,
              input.intent,
              available.candidates,
              input.now,
            )
            : revise(tickets, input.intent, available.candidates))
          : null;
        if (pending) {
          proposals = [];
          const changed = pending.filter((t) =>
            !tickets.some((old) => old.id === t.id)
          );
          attachments = changed.map((t) => t.id);
          drafts.push(...changed);
          changed.forEach((t) => compositions.add(compositionKey(t.picks)));
        }
        reply = pending
          ? "Le changement proposé conserve les autres sélections et les mises. Examinez-le, puis confirmez son application."
          : "Aucun remplacement vérifié ne respecte ces contraintes, ou les sélections conservées doivent être actualisées. La composition initiale reste disponible.";
      }
    }
  }
  // Invalid/ambiguous prompts do not replace the last usable intent.
  drafts = [...new Map(drafts.map((t) => [t.id, t])).values()].slice(-12);
  const next: State = {
    id: input.id,
    revision: previous?.revision ?? 0,
    context,
    intent: !error && !["unsupported", "clarify"].includes(input.intent.action)
      ? input.intent
      : previous?.intent ?? null,
    // Keep the structured draft through clarification without replacing any
    // usable ticket intent. Old conversations still retain their raw messages.
    pendingIntent: (error && input.intent.action === "generate") ||
        input.intent.action === "clarify"
      ? (input.intent.tickets.length
        ? input.intent
        : previous?.pendingIntent ?? null)
      : input.intent.action === "unsupported"
      ? previous?.pendingIntent ?? null
      : null,
    tickets: [...tickets],
    pending,
    proposals,
    versions: versions.slice(-3),
    drafts,
    compositions: [...compositions],
    saved: tickets === previous?.tickets ? previous.saved : false,
    updatedAt: input.now.toISOString(),
    catalog,
    messages: [...(previous?.messages ?? []), {
      role: "user",
      text: input.message,
      at: input.now.toISOString(),
    }, {
      role: "assistant",
      text: reply,
      ticketIds: attachments,
      proposalIds,
      at: input.now.toISOString(),
    }].slice(-40) as State["messages"],
  };
  // Bound duplicated ticket snapshots without forgetting composition identities.
  while (JSON.stringify(next).length > 180000 && next.versions.length) {
    next.versions.shift();
  }
  while (
    JSON.stringify(next).length > 180000 && (next.drafts?.length ?? 0) > 1
  ) next.drafts!.shift();
  while (JSON.stringify(next).length > 180000 && next.tickets.length > 1) {
    next.tickets.shift();
  }
  return next;
}
export function preparation(
  sources: Source[],
  context: Context,
  date: string,
  now: Date,
) {
  const { candidates: _candidates, matches: _matches, ...catalog } =
    buildCatalog(
      sources,
      context,
      date,
      now,
    );
  return {
    ...catalog,
    candidateCount: _candidates.length,
    status: _candidates.length
      ? "verifiable"
      : catalog.matchCount
      ? "anticipated"
      : "unavailable",
    date,
    today: calendarDay(now, context.timezone),
  };
}
