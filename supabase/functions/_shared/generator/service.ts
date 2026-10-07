import { buildCatalog, type Source } from "./catalog.ts";
import {
  calendarDay,
  type Context,
  type Intent,
  type State,
  validateIntent,
} from "./contracts.ts";
import { compose, revise } from "./engine.ts";
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
  // Revisions always use the original frozen configuration. A changed current
  // profile applies only when asking for a fresh generation.
  const context = ["generate", "explore"].includes(input.intent.action)
    ? input.context
    : previous?.tickets[input.intent.ticketIndex ?? 0]?.context ??
      previous?.context ?? input.context;
  const error = validateIntent(input.intent, context, input.now);
  let reply = error ?? "", tickets = previous?.tickets ?? [], pending = null;
  const versions = [...(previous?.versions ?? [])];
  let catalog = previous?.catalog;
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
      } else if (input.intent.action === "generate") {
        const proposed = compose(available.candidates, input.intent, context);
        if (proposed.length) {
          if (tickets.length) {
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
        } else {reply =
            "Les données vérifiées ne permettent pas de respecter votre demande. Vous pouvez élargir la date ou réduire le nombre de compositions, sans augmenter votre budget.";}
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
        reply = pending
          ? "Le changement proposé conserve les autres sélections et les mises. Examinez-le, puis confirmez son application."
          : "Aucun remplacement vérifié ne respecte ces contraintes, ou les sélections conservées doivent être actualisées. La composition initiale reste disponible.";
      }
    }
  }
  // Invalid/ambiguous prompts do not replace the last usable intent.
  return {
    id: input.id,
    revision: previous?.revision ?? 0,
    context,
    intent: !error && !["unsupported", "clarify"].includes(input.intent.action)
      ? input.intent
      : previous?.intent ?? null,
    tickets,
    pending,
    versions: versions.slice(-12),
    saved: tickets === previous?.tickets ? previous.saved : false,
    updatedAt: input.now.toISOString(),
    catalog,
    messages: [...(previous?.messages ?? []), {
      role: "user",
      text: input.message,
    }, { role: "assistant", text: reply }].slice(-40) as State["messages"],
  };
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
