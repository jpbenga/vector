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
const cors = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers":
    "authorization, apikey, content-type, x-client-info",
  "access-control-allow-methods": "POST, OPTIONS",
};
const reply = (body: unknown, status = 200) =>
  Response.json(body, { status, headers: cors });
const uuid = (value: unknown) =>
  typeof value === "string" &&
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value);
async function rest(
  path: string,
  body?: unknown,
  method = body ? "POST" : "GET",
  timeoutMs = 15000,
) {
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const result = await fetch(
    `${Deno.env.get("SUPABASE_URL")}/rest/v1/${path}`,
    {
      method,
      redirect: "error",
      signal: AbortSignal.timeout(timeoutMs),
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
export function generatorHandler(options: { workshop?: boolean } = {}) {
  return async (request: Request) => {
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
    ) => {
      const operation = path.split("?")[0];
      stage = operation;
      const began = performance.now();
      try {
        return await rest(path, body, method, timeoutMs);
      } finally {
        timings[operation] = (timings[operation] ?? 0) +
          Math.round(performance.now() - began);
      }
    };
    const daySourcesFor = (
      context: ReturnType<typeof contextFrom>,
      date: string,
      sports: Sport[],
      onCoverage?: (coverage: DayReadCoverage) => Promise<void>,
    ) =>
      loadDaySources(context, date, sports, {
        manifest: (parameters) =>
          call("rpc/lector_generator_day_manifest", parameters),
        page: (parameters) => call("rpc/lector_generator_day_page", parameters),
      }, onCoverage);
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
          signal: AbortSignal.timeout(10000),
        },
      );
      if (!userResponse.ok) {
        return reply({ error: "Votre connexion doit être renouvelée." }, 401);
      }
      const user = await userResponse.json();
      if (!uuid(user.id)) return reply({ error: "Connexion invalide." }, 401);
      authenticatedUser = user.id;
      const text = await request.text();
      if (text.length > 2700000) {
        return reply({ error: "Demande trop longue." }, 413);
      }
      const input = obj(JSON.parse(text)), action = input.action;
      if (action !== "transcribe" && text.length > 75000) {
        return reply({ error: "Demande trop longue." }, 413);
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
        const rows = await call(
          `lector_generator_turns?request_id=eq.${input.requestId}&user_id=eq.${user.id}&conversation_id=eq.${id}&select=status,usage`,
        );
        return reply({
          turn: {
            status: rows[0]?.status ?? "starting",
            phase: rows[0]?.usage?.phase ?? "interpret",
            ...(options.workshop
              ? {
                steps: rows[0]?.usage?.steps ?? [],
                context: rows[0]?.usage?.context ?? null,
                summary: rows[0]?.usage?.summary ?? null,
              }
              : {}),
          },
        });
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
      const previous = states.length && Object.keys(states[0].state).length
        ? states[0].state as State
        : null;
      if (action === "read") {
        return reply({ state: previous ? { ...previous, ...session } : null });
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
            const date = calendarDay(
              ticket.picks[0].kickoff,
              ticket.context.timezone,
            );
            const sources = await sourcesFor(ticket.context, date, [
              ...new Set(ticket.picks.map((p) => p.sport)),
            ]);
            const catalog = buildCatalog(sources, ticket.context, date, now);
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
        const state = await call("rpc/lector_generator_commit", {
          p_user: user.id,
          p_conversation: id,
          p_revision: revision,
          p_state: next,
        });
        return reply({ state });
      }
      const context = contextFrom(input.context),
        date = String(input.date ?? "");
      // This policy is assigned by the demo endpoint, never accepted from model/client input.
      if (options.workshop) context.configurationPolicy = "request";
      if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) {
        return reply({ error: "Date invalide." }, 400);
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
            action === "transcribe" ? claim.cached : { state: claim.cached },
          )
          : reply({
            error:
              "Cette demande est déjà en cours ou a échoué. Réessayez après actualisation.",
          }, 409);
      }
      reservation = String(input.requestId);
      const progressState: {
        phase: string;
        steps: { phase: string; detail: string; at: string }[];
        summary?: string;
        context?: AnalysisProgress["context"];
        evaluations?: DayEvaluation[];
      } = { phase: "interpret", steps: [] };
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
          { usage: options.workshop ? progressState : { phase } },
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
          onReceipt: (r) => receipts.push(r),
          evaluationConcurrency: Number(
            Deno.env.get("LECTOR_EVALUATION_CONCURRENCY") ?? 24,
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
              ...progressState.evaluations ?? [],
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
            matchData: async (sport, day, matchId, capturedAt, sourceId) => {
              const found = await Promise.allSettled([
                sport === "football"
                  ? (uuid(sourceId)
                    ? call(
                      `match_feed_analysis_snapshots?id=eq.${sourceId}&captured_at=eq.${
                        encodeURIComponent(capturedAt)
                      }&select=${footballDetailColumns}&limit=1`,
                    ).then((r) =>
                      projectFootballMatch(r[0], sourceId, capturedAt, matchId)
                    )
                    : Promise.resolve(null))
                  : call("rpc/read_sport_feed", {
                    p_sport: sport,
                    p_day: day,
                    p_section: "match",
                    p_match: matchId,
                    p_captured_at: capturedAt,
                  }),
                call(
                  sport === "hockey"
                    ? `sport_live_states?sport=eq.hockey&provider=eq.api-hockey&fixture_id=eq.${matchId}&select=fixture_id,captured_at,payload&limit=1`
                    : `match_live_states?fixture_id=eq.${matchId}&select=fixture_id,status,elapsed,extra,home_goals,away_goals,captured_at,statistics,statistics_captured_at,events,events_captured_at&limit=1`,
                ),
              ]);
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
                  3000,
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
            evaluation: async (evaluationId) => {
              const filter = evaluationId === "latest"
                ? ""
                : `&usage->evaluations=cs.${
                  encodeURIComponent(JSON.stringify([{ id: evaluationId }]))
                }`;
              const turns = await call(
                `lector_generator_turns?user_id=eq.${user.id}&conversation_id=eq.${id}&select=usage&order=started_at.desc&limit=10${filter}`,
              );
              for (const turn of turns) {
                const reports = Array.isArray(obj(turn.usage).evaluations)
                  ? obj(turn.usage).evaluations as DayEvaluation[]
                  : [];
                const report = evaluationId === "latest"
                  ? reports.at(-1)
                  : reports.find((r) => r.id === evaluationId);
                if (report) return report;
              }
              return null;
            },
            archivedTicket: async (ticketId) => {
              const archived = await call(
                `lector_generator_ticket_drafts?id=eq.${ticketId}&conversation_id=eq.${id}&user_id=eq.${user.id}&select=ticket`,
              );
              return archived[0]?.ticket ?? null;
            },
          },
        });
        await progress("commit");
        const state = await call("rpc/lector_generator_commit", {
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
            3000,
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
        // Retain recent analyses for follow-ups without duplicating unbounded snapshots.
        let size = JSON.stringify(next).length;
        for (const older of next.messages.slice(0, -1)) {
          if (size <= 180000) break;
          delete older.analysis;
          size = JSON.stringify(next).length;
        }
        while (JSON.stringify(next).length > 180000 && next.versions.length) {
          next.versions.shift();
        }
        while (
          JSON.stringify(next).length > 180000 && (next.drafts?.length ?? 0) > 1
        ) next.drafts!.shift();
        while (
          JSON.stringify(next).length > 180000 && next.messages.length > 2
        ) next.messages.shift();
        if (JSON.stringify(next).length > 180000) {
          throw new Error(
            "Cette analyse contient trop de données pour être conservée. Choisissez un périmètre plus ciblé.",
          );
        }
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
      const state = await call("rpc/lector_generator_commit", {
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
      if (reservation) {
        const failure = {
          failure_stage: stage,
          failure_name: error instanceof Error ? error.name : "unknown",
          failure_message: error instanceof Error
            ? error.message.slice(0, 1000)
            : "unknown",
          elapsed_ms: Math.round(performance.now() - started),
          ai_usage: aiUsage,
          ai: receipts,
          timings_ms: timings,
          comparison,
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
          ? (stage === "interpret"
            ? "L’interprétation a pris trop de temps. Votre conversation est conservée ; vous pouvez réessayer."
            : "La récupération des données a pris trop de temps. Votre conversation est conservée ; vous pouvez réessayer.")
          : error instanceof Error
          ? error.message
          : "La préparation a échoué. Aucune mise n’a été engagée.",
      }, timeout ? 504 : 400);
    }
  };
}
