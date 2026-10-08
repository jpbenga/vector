import { buildCatalog, publishedReadingIds, type Source } from "./catalog.ts";
import {
  calendarDay,
  type Context,
  type Intent,
  type State,
  validateIntent,
} from "./contracts.ts";
import { compose, compositionKey, revise } from "./engine.ts";
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
  if (intent.action !== "alternative") return intent;
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
  },
): State {
  const previous = input.state;
  input.intent = resolveIntent(input.intent, previous);
  // Revisions always use the original frozen configuration. A changed current
  // profile applies only when asking for a fresh generation.
  const context = ["generate", "explore"].includes(input.intent.action)
    ? input.context
    : (input.intent.referenceTicketId
      ? [...(previous?.tickets ?? []), ...(previous?.drafts ?? [])].find((t) =>
        t.id === input.intent.referenceTicketId
      )?.context
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
      if (input.intent.action === "explore") {
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
        const proposed = compose(available.candidates, input.intent, context, {
          tickets: drafts,
          compositions: [...compositions],
        });
        if (proposed.length) {
          const lastNumber = Math.max(0, ...drafts.map((t) => t.number));
          proposed.forEach((t, i) => t.number = lastNumber + i + 1);
          attachments = proposed.map((t) => t.id);
          drafts.push(...proposed);
          proposed.forEach((t) => compositions.add(compositionKey(t.picks)));
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
          if (proposed.length < input.intent.tickets.length) {
            reply +=
              " Certaines compositions n’ont pas pu respecter toutes les contraintes ; elles ne sont pas complétées artificiellement.";
          }
        } else {
          reply = input.intent.action === "alternative"
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
          ? revise(tickets, input.intent, available.candidates)
          : null;
        if (pending) {
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
  const { candidates: _candidates, ...catalog } = buildCatalog(
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
