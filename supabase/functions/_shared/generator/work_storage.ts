import { compactShortlistReferences } from "./shortlist.ts";
import { type State, type Ticket } from "./contracts.ts";
import { compositionKey } from "./engine.ts";

/** Detailed immutable objects live outside the bounded conversational working set. */
export function archiveWork(
  state: State,
  knownTickets = new Set<string>(),
  knownMessages = new Set<string>(),
  knownTurns = new Set<string>(),
) {
  const next = structuredClone(state);
  compactShortlistReferences(next);
  const tickets = [...new Map([
    ...next.tickets,
    ...(next.drafts ?? []),
    ...(next.proposals ?? []),
    ...(next.pending ?? []),
    ...next.versions.flat(),
  ].map((t) => [t.id, t])).values()];
  const messages = next.messages.map((m) => ({
    ...m,
    id: m.id ?? crypto.randomUUID(),
    ...(m.analysis?.exploration
      ? {
        explorationRef: {
          evaluationId: m.analysis.exploration.evaluationId,
          criterion: m.analysis.exploration.criterion,
          coverage: m.analysis.exploration.coverage,
          version: m.analysis.exploration.version,
        },
      }
      : {}),
  }));
  const turns = (next.conversation?.turns ?? []).map((t) => ({
    ...t,
    id: t.id ?? crypto.randomUUID(),
  }));
  const reference = (t: Ticket) => ({ id: t.id });
  const stored = {
    ...next,
    storageVersion: 2,
    tickets: next.tickets.map(reference),
    drafts: (next.drafts ?? []).slice(-12).map(reference),
    proposals: (next.proposals ?? []).map(reference),
    pending: next.pending?.map(reference) ?? null,
    versions: next.versions.slice(-3).map((v) => v.map(reference)),
    messages: messages.slice(-20).map(({ analysis, ...m }) => ({
      ...m,
      text: m.text.slice(0, 500),
      ...(analysis ? { analysisRef: m.id } : {}),
      ...(analysis?.exploration
        ? {
          explorationRef: {
            evaluationId: analysis.exploration.evaluationId,
            criterion: analysis.exploration.criterion,
            coverage: analysis.exploration.coverage,
            version: analysis.exploration.version,
          },
        }
        : {}),
    })),
    // Older composition identities can be rediscovered through read_session.
    compositions: (next.compositions ?? []).slice(-100),
    catalog: next.catalog
      ? {
        ...next.catalog,
        signals: [],
        missing: next.catalog.missing.slice(0, 50),
      }
      : undefined,
    conversation: next.conversation
      ? {
        ...next.conversation,
        turns: turns.slice(-8).map(({ selections: _selections, ...t }) => ({
          ...t,
          request: t.request.slice(0, 2000),
          response: t.response.slice(0, 2000),
        })),
      }
      : undefined,
  };
  return {
    state: stored,
    tickets: tickets.filter((t) => !knownTickets.has(t.id)).map((t) => ({
      ...t,
      workFingerprint: compositionKey(t.picks),
    })),
    messages: messages.filter((m) => !knownMessages.has(m.id)),
    turns: turns.filter((t) => !knownTurns.has(t.id)),
  };
}

/** An old analysis is read by reference, rather than recopied into every call. */
export function compactModelMemory(state: State | null) {
  return {
    ledger: state?.conversation?.turns.slice(-8).map((t) => ({
      at: t.at,
      request: t.request.slice(0, 1200),
      response: t.response.slice(0, 1200),
      ticketIds: t.ticketIds,
      focus: t.focus,
      constraints: t.constraints,
    })),
    tickets: [...new Map([
      ...(state?.tickets ?? []),
      ...(state?.drafts ?? []),
      ...(state?.proposals ?? []),
      ...(state?.pending ?? []),
    ].map((t) => [t.id, t])).values()].slice(-12).map((t) => ({
      id: t.id,
      number: t.number,
      target: t.target,
      constraints: t.constraints,
      selections: t.picks.map((p) => ({
        key: `${p.sport}:${p.matchId.replace(/^api-fixture-/, "")}`,
        match: `${p.home} — ${p.away}`,
        market: p.marketId,
        selection: p.selection,
      })),
    })),
    ...(state?.messages.some((m) => m.analysis?.exploration || m.explorationRef)
      ? {
        explorations: state.messages.filter((m) =>
          m.analysis?.exploration || m.explorationRef
        ).slice(-4).map((m) => ({
          evaluationId:
            (m.analysis?.exploration ?? m.explorationRef)!.evaluationId,
          criterion: (m.analysis?.exploration ?? m.explorationRef)!.criterion,
          coverage: (m.analysis?.exploration ?? m.explorationRef)!.coverage,
          version: (m.analysis?.exploration ?? m.explorationRef)!.version,
        })),
      }
      : {}),
    archivedHistory: state?.history ?? null,
  };
}
