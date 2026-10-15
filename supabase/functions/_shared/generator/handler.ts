import { generatorTimeouts } from "./timeouts.ts";
import { withCollectedQuotes } from "./cached_quotes.ts";
import {
  compareExploration,
  explorationChanges,
  explorationView,
} from "./exploration_continuity.ts";
import { explainExplorationChoice } from "./exploration.ts";
import { explorationBudgetFromEnvironment } from "./exploration_budget.ts";
import { archiveWork } from "./work_storage.ts";
import {
  resolveShortlist,
  shortlistContext,
  shortlistReference,
} from "./shortlist.ts";
import { ConversationReader } from "./conversation_tools.ts";
import { comparisonModels, type ModelReceipt } from "./models.ts";
import {
  attachReview,
  buildReviewBrief,
  fallbackReview,
  reviewCompositions,
} from "./review.ts";
import {
  calendarDay,
  contextFrom,
  type Json,
  obj,
  rows,
  type Sport,
  type State,
} from "./contracts.ts";
import { type Source } from "./catalog.ts";
import { interpret } from "./openai.ts";
import { converse } from "./conversation.ts";
import type { DayEvaluation } from "./match_evaluation.ts";
import {
  footballDetailColumns,
  projectFootballMatch,
} from "./conversation_data.ts";
import {
  analysisContext,
  type AnalysisProgress,
  analyzeDay,
} from "./analysis.ts";
import {
  applyIntent,
  preparation,
  resolveIntent,
  sourceQuery,
} from "./service.ts";
import { validateIntent } from "./contracts.ts";
import { decodeVoice, transcribe } from "./voice.ts";
import { buildCatalog } from "./catalog.ts";
import { type DayReadCoverage, loadDaySources } from "./day_sources.ts";
import { GeneratorFailure, generatorTimeoutMessage } from "./failures.ts";
import { CompositionContractError } from "./conversation_scope.ts";
import { canReadTurnResponse, turnStatus } from "./turn_status.ts";
const cors = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers":
    "authorization, apikey, content-type, x-client-info, x-lector-client-revision",
  "access-control-allow-methods": "POST, OPTIONS",
  "access-control-expose-headers":
    "x-lector-release-revision, x-lector-request-id, x-lector-generator-mode",
};
const uuid = (value: unknown) =>
  typeof value === "string" &&
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value);
async function rest(
  path: string,
  body?: unknown,
  method = body ? "POST" : "GET",
  timeoutMs = generatorTimeouts.databaseMs,
  signal?: AbortSignal,
) {
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const result = await fetch(
    `${Deno.env.get("SUPABASE_URL")}/rest/v1/${path}`,
    {
      method,
      redirect: "error",
      signal: signal
        ? AbortSignal.any([signal, AbortSignal.timeout(timeoutMs)])
        : AbortSignal.timeout(timeoutMs),
      headers: {
        authorization: `Bearer ${key}`,
        apikey: key,
        "content-type": "application/json",
      },
      body: body === undefined ? undefined : JSON.stringify(body),
    },
  );
  if (!result.ok) {
    const failure = await result.json().catch(() => ({}));
    const safe = String(failure.message ?? "");
    if (/session expired/i.test(safe)) {
      throw new Error(
        "Cette session a expiré. Vos éléments conservés restent dans Mes suivis.",
      );
    }
    if (/test budget limit/i.test(safe)) {
      throw new Error(
        "Le plafond de tests IA est atteint. Rechargez l’enveloppe avant de poursuivre les générations.",
      );
    }
    throw new Error(
      /limit|wait|running|changed/i.test(safe)
        ? "Limite atteinte ou conversation modifiée. Attendez, puis rechargez la conversation."
        : "Le service de compositions est indisponible.",
    );
  }
  const text = await result.text();
  return text ? JSON.parse(text) : null;
}
export function generatorHandler(
  options: { workshop?: boolean; onReserved?: (headers: Response) => void } =
    {},
) {
  return async (request: Request) => {
    const releaseConfig = canaryConfiguration((name) => Deno.env.get(name));
    let trace: Json = {};
    let serverRequestId: string = crypto.randomUUID();
    const reply = (body: unknown, status = 200) =>
      Response.json(body, {
        status,
        headers: {
          ...cors,
          "x-lector-release-revision": releaseConfig.revision,
          "x-lector-request-id": serverRequestId,
          "x-lector-generator-mode": options.workshop ? "workshop" : "legacy",
        },
      });
    if (request.method === "OPTIONS") return reply({});
    if (request.method !== "POST") {
      return reply({ error: "Méthode non autorisée." }, 405);
    }
    if (Number(request.headers.get("content-length") ?? 0) > 2700000) {
      return reply({ error: "Demande trop longue." }, 413);
    }
    let reservation: string | null = null;
    let authenticatedUser: string | null = null;
    let stage = "authenticate";
    let aiUsage: unknown = null;
    const started = performance.now();
    const receipts: ModelReceipt[] = [];
    const timings: Record<string, number> = {};
    const comparison: Record<string, unknown> = {};
    let search: unknown = null;
    const call = async (
      path: string,
      body?: unknown,
      method?: string,
      timeoutMs?: number,
      signal?: AbortSignal,
    ) => {
      const operation = path.split("?")[0];
      stage = operation;
      const began = performance.now();
      try {
        return await rest(path, body, method, timeoutMs, signal);
      } catch (error) {
        throw new GeneratorFailure(error, operation);
      } finally {
        timings[operation] = (timings[operation] ?? 0) +
          Math.round(performance.now() - began);
      }
    };
    const daySourcesFor = async (
      context: ReturnType<typeof contextFrom>,
      date: string,
      sports: Sport[],
      onCoverage?: (coverage: DayReadCoverage) => Promise<void>,
    ) => {
      const result = await loadDaySources(context, date, sports, {
        manifest: (parameters) =>
          call("rpc/lector_generator_day_manifest", parameters),
        page: (parameters) => call("rpc/lector_generator_day_page", parameters),
      }, onCoverage);
      return {
        ...result,
        sources: await withCollectedQuotes(
          result.sources,
          context,
          date,
          new Date(),
          (query) =>
            call(
              `api_football_cached_responses?${query}`,
              undefined,
              "GET",
              generatorTimeouts.authenticationMs,
            ),
        ),
      };
    };
    const sourcesFor = (
      context: ReturnType<typeof contextFrom>,
      date: string,
      sports = Object.keys(context.preferences),
    ) =>
      options.workshop
        ? daySourcesFor(context, date, sports as Sport[]).then((r) => r.sources)
        : context.view === "radar"
        ? call(
          "rpc/lector_generator_radar_sources",
          {
            p_date: date,
            p_timezone: context.timezone,
            p_radar: Object.fromEntries(
              Object.entries(context.radar ?? {}).filter(([sport]) =>
                sports.includes(sport)
              ),
            ),
          },
        ) as Promise<Source[]>
        : call(
          "rpc/lector_generator_sources_filtered",
          sourceQuery(context, date, sports),
        ) as Promise<Source[]>;
    try {
      const auth = request.headers.get("authorization") ?? "";
      if (!auth.startsWith("Bearer ")) {
        return reply(
          { error: "Connectez-vous pour utiliser l’assistant." },
          401,
        );
      }
      const userResponse = await fetch(
        `${Deno.env.get("SUPABASE_URL")}/auth/v1/user`,
        {
          headers: {
            authorization: auth,
            apikey: Deno.env.get("SUPABASE_ANON_KEY")!,
          },
          redirect: "error",
          signal: AbortSignal.timeout(generatorTimeouts.authenticationMs),
        },
      );
      if (!userResponse.ok) {
        return reply({ error: "Votre connexion doit être renouvelée." }, 401);
      }
      const user = await userResponse.json();
      if (!uuid(user.id)) return reply({ error: "Connexion invalide." }, 401);
      authenticatedUser = user.id;
      const knownTickets = new Set<string>(),
        knownMessages = new Set<string>(),
        knownTurns = new Set<string>();
      const materialize = async (state: State | null, full = true) =>
        state?.storageVersion === 2
          ? await call("rpc/lector_generator_work_read", {
            p_user: user.id,
            p_conversation: state.id,
            p_full: full,
            p_state: state,
          }) as State
          : state;
      const commit = async (parameters: Record<string, unknown>) => {
        const state = obj(parameters.p_state);
        const interpreted = obj(
          state.intent ?? obj(state.conversation).workingIntent,
        );
        parameters = {
          ...parameters,
          p_usage: {
            ...obj(parameters.p_usage),
            ...trace,
            responseText: redactAuditText(
              String(
                rows(state.messages).filter((m) => m.role === "assistant").at(
                  -1,
                )?.text ?? "",
              ),
            ).slice(0, 7000),
            interpretedIntent: {
              ...interpreted,
              message: typeof interpreted.message === "string"
                ? redactAuditText(String(interpreted.message))
                : null,
            },
            catalogSummary: {
              matchCount: obj(state.catalog).matchCount,
              sourceIds: obj(state.catalog).sources,
              exclusions: obj(state.catalog).missing,
            },
            ticketRefs: rows(state.tickets).map((t) => ({
              id: t.id,
              number: t.number,
              version: t.version,
              selections: rows(t.picks).map((p) => ({
                id: p.id,
                sport: p.sport,
                matchId: p.matchId,
                marketId: p.marketId,
                scope: p.scope,
                oddsAt: p.oddsAt,
                quoteReferences: p.quoteReferences,
                snapshotId: p.snapshotId,
                evidence: rows(p.evidence).map((e) => e.id),
              })),
            })),
          },
        };
        if (!options.workshop) {
          return await call("rpc/lector_generator_commit", parameters);
        }
        const work = archiveWork(
          parameters.p_state as State,
          knownTickets,
          knownMessages,
          knownTurns,
        );
        // Adopt existing sessions without losing messages trimmed from the active window.
        if (previous && previous.storageVersion !== 2) {
          const older = archiveWork(previous);
          work.tickets = [
            ...new Map(
              [...older.tickets, ...work.tickets].map((t) => [t.id, t]),
            ).values(),
          ];
          work.messages = [
            ...new Map(
              [...older.messages, ...work.messages].map((m) => [m.id, m]),
            ).values(),
          ];
          work.turns = [
            ...new Map([...older.turns, ...work.turns].map((t) => [t.id, t]))
              .values(),
          ];
        }
        const stored = await call("rpc/lector_generator_work_commit", {
          ...parameters,
          p_state: work.state,
          p_tickets: work.tickets,
          p_messages: work.messages,
          p_turns: work.turns,
        });
        return await materialize(stored);
      };

      const text = await request.text();
      if (text.length > 2700000) {
        return reply({ error: "Demande trop longue." }, 413);
      }
      const input = obj(JSON.parse(text)), action = input.action;
      const access = options.workshop === true &&
        canUseWorkshop(user, releaseConfig);
      if (action === "capabilities") {
        return reply({
          workshop: access,
          exploration: access,
          revision: releaseConfig.revision,
          fallbackEndpoint: "lector-generator",
        });
      }
      const clientRevision = request.headers.get("x-lector-client-revision");
      if (
        access && clientRevision && clientRevision !== releaseConfig.revision
      ) {
        return reply({
          error:
            "Cette interface et le Générateur utilisent des versions différentes. Rechargez l’application.",
        }, 409);
      }
      if (options.workshop && !access) {
        return await forwardLegacy(
          request,
          text,
          Deno.env.get("SUPABASE_URL")!,
          Deno.env.get("SUPABASE_ANON_KEY")!,
        );
      }
      trace = requestAudit(
        {
          ...input,
          requestId: uuid(input.requestId) ? input.requestId : serverRequestId,
        },
        releaseConfig.revision,
        options.workshop === true,
      );
      if (uuid(input.requestId)) serverRequestId = String(input.requestId);
      if (action === "audit") {
        if (!uuid(input.requestId)) {
          return reply({ error: "Identifiant de requête invalide." }, 400);
        }
        return reply({
          audit: await call("rpc/lector_generator_request_audit_read", {
            p_user: user.id,
            p_request: input.requestId,
          }),
        });
      }
      if (action !== "transcribe" && text.length > 75000) {
        return reply({ error: "Demande trop longue." }, 413);
      }
      if (options.workshop && action === "shortlist_inspect") {
        const ref = shortlistReference(input.shortlist);
        if (ref.keys.length !== 2) {
          return reply({
            error: "Choisissez exactement deux rencontres à comparer.",
          }, 400);
        }
        const now = new Date();
        const scope = resolveShortlist(
          ref,
          await call("rpc/lector_shortlist_read", { p_user: user.id }),
          now,
        );
        const context = shortlistContext({
          origin: "profile",
          scope: "discovery",
          timezone: "Europe/Paris",
          budget: 100,
          preferences: {},
        }, scope);
        const reader = new ConversationReader({
          context,
          date: calendarDay(now, context.timezone),
          state: null,
          now,
          id: "shortlist-comparison",
          message: "",
        }, { sources: sourcesFor, daySources: daySourcesFor });
        const query = await reader.execute("read_shortlist", {});
        const q = obj(query);
        const resolved = scope.keys.filter((key) =>
          rows(q.matches).some((m) => m.key === key)
        );
        const detail = resolved.length
          ? await reader.execute("read_matches", {
            queryId: q.queryId,
            matchKeys: resolved,
          })
          : [];
        return reply({
          matches: obj(detail).matches ?? detail,
          missing: q.missing,
        });
      }
      if (options.workshop && action === "decisions") {
        await call("rpc/lector_generator_verify", { p_user: user.id });
        if (
          input.offset !== undefined &&
          (!Number.isInteger(input.offset) || Number(input.offset) < 0 ||
            Number(input.offset) > 100000)
        ) return reply({ error: "Page invalide." }, 400);
        return reply(
          await call("rpc/lector_generator_decision_list", {
            p_user: user.id,
            p_offset: input.offset ?? 0,
          }),
        );
      }
      if (options.workshop && action === "decision") {
        if (!uuid(input.decisionId)) {
          return reply({ error: "Référence invalide." }, 400);
        }
        const rows = await call(
          `lector_generator_decisions?id=eq.${input.decisionId}&user_id=eq.${user.id}&select=*`,
        );
        return rows.length
          ? reply({ decision: rows[0] })
          : reply({ error: "Cet élément n’est pas disponible." }, 404);
      }

      if (options.workshop && action === "decision_action") {
        if (
          !uuid(input.decisionId) ||
          !["played", "unplayed", "unfollow", "irrelevant", "delete"].includes(
            String(input.choice),
          )
        ) {
          return reply({ error: "Action invalide." }, 400);
        }
        return reply({
          decision: await call("rpc/lector_generator_decision_action", {
            p_user: user.id,
            p_id: input.decisionId,
            p_action: input.choice,
          }),
        });
      }
      if (action === "history") {
        const filter = options.workshop
          ? `&mode=eq.workshop&expires_at=gt.${
            encodeURIComponent(new Date().toISOString())
          }`
          : "&state->>saved=eq.true";
        const history = await call(
          `lector_generator_conversations?user_id=eq.${user.id}&select=id,state,updated_at${filter}&order=updated_at.desc&limit=20`,
        );
        return reply({
          history: history.filter((h: Json) => obj(h.state).id).map((h: Json) =>
            h.state
          ),
        });
      }
      if (
        !uuid(input.conversationId) || !Number.isInteger(input.revision) ||
        Number(input.revision) < 0
      ) return reply({ error: "Conversation invalide." }, 400);
      const id = String(input.conversationId),
        revision = Number(input.revision);
      if (["status", "cancel"].includes(String(action))) {
        if (!uuid(input.requestId)) {
          return reply({ error: "Demande invalide." }, 400);
        }
        if (action === "cancel") {
          return reply({
            turn: await call("rpc/lector_generator_cancel", {
              p_user: user.id,
              p_conversation: id,
              p_request: input.requestId,
            }),
          });
        }
        const includeResult = input.includeResult === true;
        const rows = await call(
          `lector_generator_turns?request_id=eq.${input.requestId}&user_id=eq.${user.id}&conversation_id=eq.${id}&select=status,usage${
            includeResult ? ",response" : ""
          }`,
        );
        if (
          includeResult && options.workshop && rows[0]?.status === "complete"
        ) {
          const sessions = await call(
            `lector_generator_conversations?id=eq.${id}&user_id=eq.${user.id}&select=mode,expires_at,updated_at`,
          );
          if (!canReadTurnResponse(sessions[0])) {
            return reply({
              error:
                "Cette session a expiré. Vos éléments enregistrés restent dans Mes suivis.",
              expired: true,
            }, 410);
          }
        }
        if (rows[0]?.response) {
          rows[0].response = await materialize(rows[0].response);
        }
        return reply(turnStatus(rows[0], Boolean(options.workshop)));
      }
      const session = options.workshop
        ? await call("rpc/lector_generator_session", {
          p_user: user.id,
          p_conversation: id,
          p_create: ["chat", "transcribe"].includes(String(action)),
        })
        : null;
      if (session?.expired) {
        return action === "read"
          ? reply({ state: null, expired: true })
          : reply({
            error:
              "Cette session a expiré. Vos éléments enregistrés restent dans Mes suivis.",
            expired: true,
          }, 410);
      }
      if (
        options.workshop &&
        [
          "exploration_read",
          "exploration_compare",
          "exploration_explain",
          "exploration_changes",
        ]
          .includes(String(action))
      ) {
        if (!uuid(input.evaluationId)) {
          return reply({ error: "Référence invalide." }, 400);
        }
        const report = await call("rpc/lector_generator_exploration_read", {
          p_user: user.id,
          p_conversation: id,
          p_evaluation: input.evaluationId,
        }) as DayEvaluation;
        if (!report) return reply({ error: "Préparation inaccessible." }, 404);
        const audited = async (body: unknown) => {
          await call("rpc/lector_generator_request_audit_write", {
            p_user: user.id,
            p_request: serverRequestId,
            p_usage: {
              ...trace,
              auditReports: [{
                reportId: report.id,
                scope: report.scope,
                evaluated: report.evaluated,
                found: report.expected,
                complete: report.complete,
              }],
            },
          });
          return reply(body);
        };
        if (action === "exploration_changes") {
          if (!uuid(report.version?.parentId)) {
            return reply({ error: "Version précédente inaccessible." }, 404);
          }
          const parent = await call("rpc/lector_generator_exploration_read", {
            p_user: user.id,
            p_conversation: id,
            p_evaluation: report.version!.parentId,
          }) as DayEvaluation;
          if (!parent) {
            return reply({ error: "Version précédente inaccessible." }, 404);
          }
          return await audited({ changes: explorationChanges(report, parent) });
        }
        if (action === "exploration_compare") {
          if (
            !Array.isArray(input.matchKeys) ||
            input.matchKeys.some((k) => typeof k !== "string")
          ) return reply({ error: "Sélection invalide." }, 400);
          return await audited({
            comparison: compareExploration(report, input.matchKeys as string[]),
          });
        }
        if (action === "exploration_explain") {
          return await audited({
            explanation: explainExplorationChoice(
              report,
              String(input.matchKey),
            ),
          });
        }
        const offset = input.offset ?? 0, limit = input.limit ?? 40;
        if (
          !Number.isInteger(offset) || Number(offset) < 0 ||
          !Number.isInteger(limit) || Number(limit) < 1 || Number(limit) > 40
        ) return reply({ error: "Page invalide." }, 400);
        return await audited({
          exploration: explorationView(
            report,
            new Date(),
            Number(offset),
            Number(limit),
          ),
        });
      }
      if (options.workshop && action === "keep") {
        if (
          !["ticket", "selection"].includes(String(input.kind)) ||
          typeof input.sourceId !== "string" || input.sourceId.length > 300 ||
          !["save", "follow", "relevant"].includes(String(input.choice)) ||
          (input.supersedes !== undefined && !uuid(input.supersedes))
        ) {
          return reply({ error: "Référence invalide." }, 400);
        }
        const decision = await call("rpc/lector_generator_keep", {
          p_user: user.id,
          p_conversation: id,
          p_kind: input.kind,
          p_source: input.sourceId,
          p_action: input.choice,
          p_supersedes: input.supersedes ?? null,
        });
        return reply({ decision });
      }
      if (options.workshop && action === "delete_session") {
        await call(
          `lector_generator_conversations?id=eq.${id}&user_id=eq.${user.id}&mode=eq.workshop`,
          undefined,
          "DELETE",
        );
        return reply({ state: null });
      }
      const states = await call(
        `lector_generator_conversations?id=eq.${id}&user_id=eq.${user.id}&select=state,revision`,
      );
      if (action === "read") {
        return reply({
          state: states.length && Object.keys(states[0].state).length
            ? { ...await materialize(states[0].state), ...session }
            : null,
        });
      }
      if (options.workshop && action === "history") {
        if (!Number.isInteger(input.offset) || Number(input.offset) < 0) {
          return reply({ error: "Page invalide." }, 400);
        }
        return reply(
          await call("rpc/lector_generator_work_history", {
            p_user: user.id,
            p_conversation: id,
            p_offset: input.offset,
            p_limit: 20,
          }),
        );
      }
      if (options.workshop && action === "audit") {
        const turns = await call(
          `lector_generator_turns?user_id=eq.${user.id}&conversation_id=eq.${id}&select=request_id,started_at,status,usage&order=started_at.desc&limit=10`,
        );
        return reply({ turns });
      }
      if (action === "ticket") {
        if (!uuid(input.ticketId)) {
          return reply({ error: "Référence invalide." }, 400);
        }
        const archived = await call(
          `lector_generator_ticket_drafts?id=eq.${input.ticketId}&conversation_id=eq.${id}&user_id=eq.${user.id}&select=ticket`,
        );
        return archived.length
          ? reply({ ticket: archived[0].ticket })
          : reply({ error: "Ce brouillon n’est pas disponible." }, 404);
      }

      const previous = states.length && Object.keys(states[0].state).length
        ? await materialize(states[0].state as State, false)
        : null;
      if (previous && previous.storageVersion !== 2) {
        for (const m of previous.messages) m.id ??= crypto.randomUUID();
        for (const t of previous.conversation?.turns ?? []) {
          t.id ??= crypto.randomUUID();
        }
      }
      if (previous?.storageVersion === 2) {
        for (
          const t of [
            ...previous.tickets,
            ...(previous.drafts ?? []),
            ...(previous.proposals ?? []),
            ...(previous.pending ?? []),
            ...previous.versions.flat(),
          ]
        ) knownTickets.add(t.id);
        for (const m of previous.messages) if (m.id) knownMessages.add(m.id);
        for (const t of previous.conversation?.turns ?? []) {
          if (t.id) knownTurns.add(t.id);
        }
      }

      // Chat replay is resolved by the reservation RPC before its revision fence;
      // a completed request must not cause a second paid interpretation.
      if (
        !["chat", "transcribe"].includes(String(action)) && states.length &&
        states[0].revision !== revision
      ) {
        return reply({
          error:
            "La conversation a changé dans une autre fenêtre. Rechargez-la.",
        }, 409);
      }
      const now = new Date();
      if (["apply", "save"].includes(String(action))) {
        if (!previous) {
          return reply({ error: "Aucune composition à enregistrer." }, 400);
        }
        const next = { ...previous };
        if (action === "apply") {
          const selected = options.workshop && uuid(input.ticketId)
            ? previous.proposals?.find((t) => t.id === input.ticketId)
            : null;
          const proposed = selected ? [selected] : previous.pending;
          if (input.ticketId !== undefined && !selected) {
            return reply({
              error:
                "Cette composition ne fait pas partie des choix disponibles.",
            }, 400);
          }
          if (!proposed) {
            return reply({ error: "Aucun changement en attente." }, 400);
          }
          for (const ticket of proposed) {
            if (ticket.context.shortlist) {
              resolveShortlist(
                ticket.context.shortlist,
                await call("rpc/lector_shortlist_read", { p_user: user.id }),
                now,
              );
            }
            const _date = calendarDay(
              ticket.picks[0].kickoff,
              ticket.context.timezone,
            );
            const groups = new Map<string, Sport[]>();
            for (const pick of ticket.picks) {
              const day = calendarDay(pick.kickoff, ticket.context.timezone);
              const sports = groups.get(day) ?? [];
              if (!sports.includes(pick.sport)) sports.push(pick.sport);
              groups.set(day, sports);
            }
            const catalogs = [];
            for (const [day, sports] of groups) {
              const sources = await sourcesFor(
                { ...ticket.context, view: "all", scope: "discovery" },
                day,
                sports,
              );
              catalogs.push(buildCatalog(sources, ticket.context, day, now));
            }
            const catalog = {
              candidates: catalogs.flatMap((c) => c.candidates),
            };
            const ids = new Set(catalog.candidates.map((c) => c.id));
            if (!ticket.picks.every((p) => ids.has(p.id))) {
              return reply({
                error:
                  "Des sélections ou cotes ont changé. Préparez une nouvelle version avant de confirmer.",
              }, 409);
            }
          }
          next.tickets = proposed;
          next.versions = [...previous.versions, next.tickets].slice(-3);
          next.pending = null;
          next.saved = false;
          if (selected) {
            next.messages = [...previous.messages, {
              role: "assistant",
              text:
                "Cette composition est retenue pour la mise indiquée. Les autres propositions restent des alternatives.",
              ticketIds: [selected.id],
              at: now.toISOString(),
            }];
          } else next.proposals = [];
        } else next.saved = true;
        const state = await commit({
          p_user: user.id,
          p_conversation: id,
          p_revision: revision,
          p_state: next,
        });
        return reply({ state });
      }
      const explorationAction = input.explorationAction === undefined
        ? undefined
        : obj(input.explorationAction);
      if (
        explorationAction &&
        (!uuid(explorationAction.evaluationId) ||
          !["resume", "refresh"].includes(String(explorationAction.mode)))
      ) return reply({ error: "Action d’exploration invalide." }, 400);
      let context = contextFrom(input.context);
      const date = String(input.date ?? "");
      // This policy is assigned by the demo endpoint, never accepted from model/client input.
      if (options.workshop) context.configurationPolicy = "request";
      if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) {
        return reply({ error: "Date invalide." }, 400);
      }
      const requestedShortlist = obj(input.context).shortlist;
      if (
        options.workshop && requestedShortlist !== undefined &&
        !explorationAction
      ) {
        context = shortlistContext(
          context,
          resolveShortlist(
            requestedShortlist,
            await call("rpc/lector_shortlist_read", { p_user: user.id }),
            now,
          ),
        );
      }
      if (action === "prepare" && context.shortlist) {
        return reply({
          preparation: {
            matchCount: context.shortlist.keys.length,
            missing: [],
            shortlist: {
              sessionId: context.shortlist.sessionId,
              revision: context.shortlist.revision,
            },
          },
        });
      }
      if (action === "prepare") {
        const sources = await sourcesFor(context, date);
        return reply({ preparation: preparation(sources, context, date, now) });
      }
      if (
        !["chat", "transcribe"].includes(String(action)) ||
        (action === "chat" && (typeof input.message !== "string" ||
          !String(input.message).trim() || input.message.length > 2000 ||
          !uuid(input.requestId))) ||
        !uuid(input.requestId)
      ) return reply({ error: "Demande invalide." }, 400);
      const key = Deno.env.get("OPENAI_API_KEY"),
        model = options.workshop
          ? "gpt-6-luna"
          : Deno.env.get("LECTOR_OPENAI_MODEL");
      if (
        Deno.env.get(
            options.workshop
              ? "LECTOR_WORKSHOP_ENABLED"
              : "LECTOR_GENERATOR_ENABLED",
          ) !== "true" || !key || !model
      ) {
        return reply({
          error:
            "L’assistant IA n’est pas encore activé. Les appels IA restent désactivés tant que sa configuration serveur n’est pas installée.",
        }, 503);
      }
      const voice = action === "transcribe" ? decodeVoice(input.audio) : null;
      const claim = await call(
        options.workshop
          ? "rpc/lector_generator_workshop_reserve"
          : "rpc/lector_generator_reserve",
        {
          p_user: user.id,
          p_conversation: id,
          p_request: input.requestId,
          p_revision: revision,
          p_user_limit: Number(
            Deno.env.get("LECTOR_GENERATOR_USER_DAILY_LIMIT") ?? 10,
          ),
          p_global_limit: Number(
            Deno.env.get("LECTOR_GENERATOR_DAILY_LIMIT") ?? 100,
          ),
        },
      );
      if (claim.status !== "reserved") {
        return claim.cached
          ? reply(
            action === "transcribe"
              ? claim.cached
              : { state: await materialize(claim.cached) },
          )
          : reply({
            error:
              "Cette demande est déjà en cours ou a échoué. Réessayez après actualisation.",
          }, 409);
      }
      reservation = String(input.requestId);
      if (options.workshop && action === "chat") {
        options.onReserved?.(reply({}));
      }
      const progressState: {
        release?: Json["release"];
        request?: Json["request"];
        auditReports?: Json[];
        phase: string;
        steps: { phase: string; detail: string; at: string }[];
        summary?: string;
        context?: AnalysisProgress["context"];
        evaluations?: DayEvaluation[];
      } = { ...trace, phase: "interpret", steps: [] };
      let lastProgressAt = 0, lastProgressPhase = "", publishedEvaluations = 0;
      const progress = async (phase: string, event?: AnalysisProgress) => {
        const labels: Record<string, string> = {
          interpret: "Compréhension de votre demande",
          sources: "Consultation des publications Lector",
          compose: "Construction des compositions",
          review: "Comparaison des arguments et des compromis",
          analyze: "Comparaison des rencontres",
          evaluate: "Évaluation individuelle des rencontres",
          details: "Examen des lectures et marchés",
          commit: "Préparation de la réponse",
        };
        const detail = event?.detail ?? labels[phase] ?? phase;
        if (
          !event?.summary &&
          !progressState.steps.some((s) =>
            s.phase === phase && s.detail === detail
          )
        ) {
          progressState.steps.push({
            phase,
            detail,
            at: new Date().toISOString(),
          });
        }
        progressState.phase = phase;
        progressState.auditReports = reportsAudit(progressState.evaluations);
        if (event?.context) progressState.context = event.context;
        if (event?.summary) progressState.summary = event.summary;
        // Batch evaluation callbacks can arrive together. Publishing every item
        // adds two database round trips to every result; keep terminal reports.
        const clock = performance.now();
        const reportCount = progressState.evaluations?.length ?? 0;
        if (
          phase === "evaluate" && lastProgressPhase === phase &&
          reportCount === publishedEvaluations && clock - lastProgressAt < 1000
        ) return;
        lastProgressAt = clock;
        lastProgressPhase = phase;
        publishedEvaluations = reportCount;
        await rest(
          `lector_generator_turns?request_id=eq.${reservation}&user_id=eq.${user.id}&status=eq.pending`,
          { usage: options.workshop ? progressState : { ...trace, phase } },
          "PATCH",
        );
        const turn = await rest(
          `lector_generator_turns?request_id=eq.${reservation}&user_id=eq.${user.id}&select=status`,
        );
        if (turn[0]?.status !== "pending") {
          throw new Error("La génération a été interrompue.");
        }
      };
      if (voice) {
        await progress("transcribe");
        const transcript = await transcribe(voice, { key });
        const result = await call("rpc/lector_generator_finish_transcription", {
          p_user: user.id,
          p_conversation: id,
          p_request: reservation,
          p_transcript: transcript,
          p_usage: {
            transcription_seconds: (voice.length - 44) / 32000,
            model: "whisper-1",
          },
        });
        reservation = null;
        return reply(result);
      }
      if (options.workshop) {
        if (
          input.referenceTicketId !== undefined &&
          !uuid(input.referenceTicketId)
        ) {
          throw new Error("Référence de ticket invalide.");
        }
        stage = "conversation";
        const conversation = await converse({
          ...(explorationAction
            ? {
              explorationAction: explorationAction as {
                evaluationId: string;
                mode: "resume" | "refresh";
              },
            }
            : {}),
          message: String(input.message).trim(),
          date,
          context,
          state: previous,
          today: calendarDay(now, context.timezone),
          now,
          id,
          ...(input.referenceTicketId
            ? { referenceTicketId: String(input.referenceTicketId) }
            : {}),
        }, {
          key,
          model,
          deadline: started + generatorTimeouts.conversationMs,
          onReceipt: (r) => receipts.push(r),
          onToolAudit: (event) => {
            const events = Array.isArray(trace.tools) ? trace.tools : [];
            if (
              JSON.stringify(events).length + JSON.stringify(event).length <=
                64000
            ) {
              trace.tools = [...events, event];
            } else {
              trace.toolsTruncated = true;
              trace.toolsOmittedCount = Number(trace.toolsOmittedCount ?? 0) +
                1;
            }
          },
          evaluationConcurrency: Number(
            Deno.env.get("LECTOR_EVALUATION_CONCURRENCY") ?? 24,
          ),
          explorationBudget: explorationBudgetFromEnvironment((name) =>
            Deno.env.get(name)
          ),
          onContractError: (error) => {
            console.error(
              JSON.stringify({
                event: "generator_contract_error",
                detail: error,
              }),
            );
          },
          onProgress: (event) => progress(event.phase, event),
          onEvaluation: async (report) => {
            progressState.evaluations = [
              ...(progressState.evaluations ?? []).filter((r) =>
                r.id !== report.id
              ),
              report,
            ];
            await progress("evaluate", {
              phase: "evaluate",
              detail:
                `${report.evaluated} / ${report.expected} rencontres évaluées${
                  report.complete ? "" : " · analyse partielle"
                }`,
            });
          },
          reads: {
            sources: (scope, day, sports) => sourcesFor(scope, day, sports),
            daySources: (scope, day, sports, onCoverage) =>
              daySourcesFor(scope, day, sports, onCoverage),
            matchData: async (
              sport,
              day,
              matchId,
              capturedAt,
              sourceId,
              signal,
            ) => {
              const found = await Promise.allSettled([
                sport === "football"
                  ? (uuid(sourceId)
                    ? call(
                      `match_feed_analysis_snapshots?id=eq.${sourceId}&captured_at=eq.${
                        encodeURIComponent(capturedAt)
                      }&select=${footballDetailColumns}&limit=1`,
                      undefined,
                      undefined,
                      undefined,
                      signal,
                    ).then((r) =>
                      projectFootballMatch(r[0], sourceId, capturedAt, matchId)
                    )
                    : Promise.resolve(null))
                  : call(
                    "rpc/read_sport_feed",
                    {
                      p_sport: sport,
                      p_day: day,
                      p_section: "match",
                      p_match: matchId,
                      p_captured_at: capturedAt,
                    },
                    undefined,
                    undefined,
                    signal,
                  ),
                call(
                  sport === "hockey"
                    ? `sport_live_states?sport=eq.hockey&provider=eq.api-hockey&fixture_id=eq.${matchId}&select=fixture_id,captured_at,payload&limit=1`
                    : `match_live_states?fixture_id=eq.${matchId}&select=fixture_id,status,elapsed,extra,home_goals,away_goals,captured_at,statistics,statistics_captured_at,events,events_captured_at&limit=1`,
                  undefined,
                  undefined,
                  undefined,
                  signal,
                ),
              ]);
              signal?.throwIfAborted();
              return {
                publication: found[0].status === "fulfilled"
                  ? found[0].value
                  : null,
                live: found[1].status === "fulfilled"
                  ? found[1].value[0] ?? null
                  : null,
              };
            },
            bilan: async () => {
              // These are stable read RPCs. Verification/saving endpoints are never capabilities of the model.
              const found = await Promise.allSettled([
                call(
                  "rpc/match_reading_bilan_breakdown",
                  {
                    p_since: new Date(now.getTime() - 90 * 86400000)
                      .toISOString(),
                    p_until: now.toISOString(),
                  },
                  "POST",
                  generatorTimeouts.optionalHistoryMs,
                ),
                call("rpc/lector_generator_decision_list", {
                  p_user: user.id,
                  p_offset: 0,
                }),
              ]);
              return {
                readings: found[0].status === "fulfilled"
                  ? found[0].value
                  : null,
                personal: found[1].status === "fulfilled"
                  ? found[1].value
                  : null,
                limitations: found.some((r) => r.status === "rejected")
                  ? ["Une partie du Bilan est indisponible."]
                  : [],
                semantics:
                  "Résultats descriptifs, aucune probabilité de pari ni vérification déclenchée.",
              };
            },
            evaluation: async (evaluationId) =>
              await call("rpc/lector_generator_exploration_read", {
                p_user: user.id,
                p_conversation: id,
                p_evaluation: evaluationId === "latest" ? null : evaluationId,
              }),
            sessionHistory: async (offset, limit) =>
              await call("rpc/lector_generator_work_history", {
                p_user: user.id,
                p_conversation: id,
                p_offset: offset,
                p_limit: limit,
                p_full: false,
              }),
            archivedAnalysis: async (analysisId) => {
              const messages = await call(
                `lector_generator_messages?id=eq.${analysisId}&conversation_id=eq.${id}&user_id=eq.${user.id}&select=body`,
              );
              return messages[0]?.body?.analysis ?? null;
            },
            archivedTicket: async (ticketId) => {
              const archived = await call(
                `lector_generator_ticket_drafts?id=eq.${ticketId}&conversation_id=eq.${id}&user_id=eq.${user.id}&select=ticket`,
              );
              if (archived[0]?.ticket) knownTickets.add(ticketId);
              return archived[0]?.ticket ?? null;
            },
          },
        });
        if (context.shortlist) {
          // The world can change during an analysis: recheck membership/expiry and kickoff before returning new drafts.
          const finishedAt = new Date();
          const freshScope = resolveShortlist(
            context.shortlist,
            await call("rpc/lector_shortlist_read", { p_user: user.id }),
            finishedAt,
          );
          const newIds = new Set([
            ...(conversation.next.messages.at(-1)?.ticketIds ?? []),
            ...(conversation.next.messages.at(-1)?.proposalIds ?? []),
          ]);
          const proposed = [
            ...(conversation.next.tickets ?? []),
            ...(conversation.next.drafts ?? []),
            ...(conversation.next.proposals ?? []),
            ...(conversation.next.pending ?? []),
          ].filter((t) => newIds.has(t.id));
          for (const ticket of proposed) {
            for (const pick of ticket.picks) {
              if (
                ticket.context.view === "shortlist" &&
                !freshScope.keys.includes(
                  pick.sport + ":" + pick.matchId.split(/[-:]/).at(-1),
                )
              ) {
                throw new Error(
                  "La composition contient une rencontre extérieure à votre sélection.",
                );
              }
              if (ticket.context.view === "shortlist") {
                const fixture = freshScope.items.find((f) =>
                  f.key === pick.sport + ":" + pick.matchId.split(/[-:]/).at(-1)
                );
                if (
                  !fixture?.available ||
                  !["NS", "scheduled"].includes(fixture.status ?? "")
                ) {
                  throw new Error(
                    "Une rencontre n’est plus disponible en prématch. Actualisez votre préparation.",
                  );
                }
              }
              if (Date.parse(pick.kickoff) <= finishedAt.getTime()) {
                throw new Error(
                  "Une rencontre a commencé pendant l’analyse. Demandez une nouvelle composition avec les rencontres encore à venir.",
                );
              }
            }
          }
        }
        await progress("commit");
        const state = await commit({
          p_user: user.id,
          p_conversation: id,
          p_revision: revision,
          p_state: conversation.next,
          p_request: reservation,
          p_usage: {
            protocol: "lector-conversation-v2",
            model,
            ai: receipts,
            timings_ms: timings,
            elapsed_ms: Math.round(performance.now() - started),
            search: conversation.search,
            consultations: conversation.consultations,
            evaluations: conversation.evaluations,
            ...progressState,
          },
        });
        reservation = null;
        return reply({ state });
      }
      await progress("interpret");
      stage = "interpret";
      const interpreterInput = {
        message: String(input.message).trim(),
        date,
        context,
        state: previous,
        today: calendarDay(now, context.timezone),
      };
      const shadow = options.workshop &&
          Deno.env.get("LECTOR_WORKSHOP_COMPARE_MODELS") === "true"
        ? comparisonModels.find((m) => m !== model)
        : undefined;
      const interpreted = await Promise.allSettled([
        interpret(interpreterInput, {
          key,
          model,
          onReceipt: (r) => receipts.push(r),
        }),
        ...(shadow
          ? [
            interpret(interpreterInput, {
              key,
              model: shadow,
              onReceipt: (r) => receipts.push(r),
            }),
          ]
          : []),
      ]);
      if (shadow) {
        comparison.interpretation = interpreted.map((r, i) =>
          r.status === "fulfilled"
            ? { model: i ? shadow : model, intent: r.value.intent }
            : { model: i ? shadow : model, status: "failed" }
        );
      }
      if (interpreted[0].status === "rejected") throw interpreted[0].reason;
      const { intent: parsed, usage } = interpreted[0].value;
      aiUsage = usage;
      if (input.referenceTicketId !== undefined) {
        if (!uuid(input.referenceTicketId)) {
          throw new Error("Référence de ticket invalide.");
        }
        parsed.action = "alternative";
        parsed.referenceTicketId = String(input.referenceTicketId);
        parsed.preserveConstraints = true;
      }
      if (
        parsed.referenceTicketId && previous &&
        ![...previous.tickets, ...(previous.drafts ?? [])].some((t) =>
          t.id === parsed.referenceTicketId
        )
      ) {
        if (!uuid(parsed.referenceTicketId)) {
          throw new Error("Référence de ticket invalide.");
        }
        const archived = await call(
          `lector_generator_ticket_drafts?id=eq.${parsed.referenceTicketId}&conversation_id=eq.${id}&user_id=eq.${user.id}&select=ticket`,
        );
        if (archived.length) {
          previous.drafts = [...(previous.drafts ?? []), archived[0].ticket];
        }
      }
      const intent = resolveIntent(parsed, previous);
      const baseContext =
        ["generate", "explore", "analyze"].includes(intent.action)
          ? context
          : (intent.referenceTicketId
            ? [...(previous?.tickets ?? []), ...(previous?.drafts ?? [])].find(
              (t) => t.id === intent.referenceTicketId,
            )?.context
            : undefined) ??
            previous?.tickets[intent.ticketIndex ?? 0]?.context ??
            previous?.context ?? context;
      const revisionContext = options.workshop
        ? analysisContext({
          ...baseContext,
          ...((intent.view === "current" || intent.view === undefined) &&
              (!intent.radarKind || intent.radarKind === "current") &&
              previous?.context.view === "radar"
            ? { view: "radar" as const, radarKind: previous.context.radarKind }
            : {}),
        }, intent)
        : baseContext;
      if (
        ["replace", "remove"].includes(intent.action) &&
        previous?.tickets[intent.ticketIndex ?? 0]?.picks[0]
      ) {
        intent.date = calendarDay(
          previous.tickets[intent.ticketIndex ?? 0].picks[0].kickoff,
          revisionContext.timezone,
        );
      }
      await progress("sources");
      const sources =
        ["generate", "alternative", "replace", "remove", "explore", "analyze"]
            .includes(
              intent.action,
            ) &&
          !validateIntent(intent, revisionContext, now)
          ? await sourcesFor(revisionContext, intent.date, intent.sports)
          : [];
      if (sources.some((s) => s.sport === "football")) {
        try {
          const history = await call(
            "rpc/match_reading_bilan_breakdown",
            {
              p_since: new Date(now.getTime() - 90 * 86400000).toISOString(),
              p_until: now.toISOString(),
            },
            "POST",
            generatorTimeouts.optionalHistoryMs,
          );
          for (const source of sources.filter((s) => s.sport === "football")) {
            source.payload.bilan = history;
          }
        } catch {
          // Historical context is optional; never manufacture a confirmation rate.
          for (const source of sources.filter((s) => s.sport === "football")) {
            source.payload.bilan = [];
          }
        }
      }
      await progress("compose");
      stage = "compose";
      const composedAt = performance.now();
      const next = applyIntent({
        state: previous,
        context: options.workshop ? revisionContext : context,
        intent,
        sources,
        message: String(input.message).trim(),
        now,
        id,
        workshop: options.workshop,
        onWorkshop: (reports) => {
          search = (reports as { exclusions: { reasons: string[] }[] }[]).map((
            { exclusions, ...report },
          ) => ({
            ...report,
            exclusionReasons: exclusions.flatMap((e) => e.reasons).reduce(
              (all, reason) => ({ ...all, [reason]: (all[reason] ?? 0) + 1 }),
              {} as Record<string, number>,
            ),
          }));
        },
      });
      timings.compose = Math.round(performance.now() - composedAt);
      if (
        options.workshop && ["analyze", "explore"].includes(intent.action) &&
        !validateIntent(intent, revisionContext, now)
      ) {
        stage = "analyze";
        const analysis = await analyzeDay({
          message: String(input.message).trim(),
          intent,
          context: revisionContext,
          catalog: buildCatalog(sources, revisionContext, intent.date, now),
          state: previous,
          now,
        }, {
          key,
          model,
          onReceipt: (r) => receipts.push(r),
          onProgress: (event) => progress(event.phase, event),
        });
        const message = next.messages.at(-1)!;
        message.text = analysis.text;
        message.analysis = analysis;
        // Detailed analyses are archived independently by commit.
      }
      if (options.workshop) {
        const attachments = next.messages.at(-1)?.ticketIds ?? [];
        const reviewTickets = intent.action === "explain" &&
            previous?.tickets[intent.ticketIndex ?? 0]
          ? [previous.tickets[intent.ticketIndex ?? 0]]
          : [
            ...new Map(
              [...(next.proposals ?? []), ...(next.drafts ?? [])].filter((
                t,
              ) =>
                attachments.includes(t.id) ||
                next.messages.at(-1)?.proposalIds?.includes(t.id)
              ).map((t) => [t.id, t]),
            ).values(),
          ].slice(0, 4);
        if (reviewTickets.length) {
          const brief = buildReviewBrief(reviewTickets, now);
          brief.request = String(input.message).trim();
          await progress("review");
          stage = "review";
          const reviewed = await Promise.allSettled([
            reviewCompositions(brief, {
              key,
              model,
              onReceipt: (r) => receipts.push(r),
            }),
            ...(shadow
              ? [
                reviewCompositions(brief, {
                  key,
                  model: shadow,
                  onReceipt: (r) => receipts.push(r),
                }),
              ]
              : []),
          ]);
          const primary = reviewed[0];
          attachReview(
            reviewTickets,
            primary.status === "fulfilled"
              ? primary.value.review
              : fallbackReview(brief),
            brief,
          );
          if (
            primary.status === "fulfilled" && primary.value.narrative.trim()
          ) {
            if (intent.action === "explain") {
              next.messages.at(-1)!.text = primary.value.narrative;
            } else {next.messages.at(-1)!.text +=
                `\n\n${primary.value.narrative}`;}
          }
          if (primary.status === "rejected") {
            next.messages.at(-1)!.text +=
              " L’analyse IA n’est pas disponible ; les arguments factuels restent consultables.";
          }
          comparison.review = reviewed.map((r, i) =>
            r.status === "fulfilled"
              ? { model: i ? shadow : model, review: r.value.review }
              : { model: i ? shadow : model, status: "failed" }
          );
          comparison.facts = brief.facts;
        }
      }
      await progress("commit");
      const state = await commit({
        p_user: user.id,
        p_conversation: id,
        p_revision: revision,
        p_state: next,
        p_request: reservation,
        p_usage: options.workshop
          ? {
            protocol: "lector-workshop-v1",
            model,
            ai: receipts,
            timings_ms: timings,
            elapsed_ms: Math.round(performance.now() - started),
            comparison,
            search,
            ...progressState,
          }
          : usage,
      });
      reservation = null;
      return reply({ state });
    } catch (error) {
      if (
        error instanceof GeneratorFailure ||
        error instanceof CompositionContractError
      ) stage = error.stage;
      if (reservation) {
        const failure = {
          failure_stage: stage,
          failure_name: error instanceof Error ? error.name : "unknown",
          failure_message: error instanceof Error
            ? redactAuditText(error.message).slice(0, 1000)
            : "unknown",
          ...(error instanceof CompositionContractError
            ? { failure_contract: error.contract }
            : {}),
          elapsed_ms: Math.round(performance.now() - started),
          ai_usage: aiUsage,
          ai: receipts,
          timings_ms: timings,
          comparison,
          ...trace,
        };
        if (options.workshop) {
          await rest("rpc/lector_generator_workshop_record_failure", {
            p_user: authenticatedUser,
            p_request: reservation,
            p_usage: failure,
          }).catch(() => {});
        } else {await rest(
            `lector_generator_turns?request_id=eq.${reservation}&status=eq.pending`,
            { status: "failed", usage: failure },
            "PATCH",
          ).catch(() => {});}
      }
      const timeout = error instanceof Error &&
        ["TimeoutError", "AbortError"].includes(error.name);
      console.error(
        JSON.stringify({
          event: "generator_failure",
          stage,
          elapsed_ms: Math.round(performance.now() - started),
          timeout,
        }),
      );
      return reply({
        error: timeout
          ? generatorTimeoutMessage(stage)
          : error instanceof Error
          ? redactAuditText(error.message)
          : "La préparation a échoué. Aucune mise n’a été engagée.",
      }, timeout ? 504 : 400);
    }
  };
}
import {
  canaryConfiguration,
  canUseWorkshop,
  forwardLegacy,
  redactAuditText,
  reportsAudit,
  requestAudit,
} from "./release.ts";
