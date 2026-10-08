import {
  calendarDay,
  contextFrom,
  type Json,
  obj,
  type State,
} from "../_shared/generator/contracts.ts";
import { type Source } from "../_shared/generator/catalog.ts";
import { interpret } from "../_shared/generator/openai.ts";
import {
  applyIntent,
  preparation,
  resolveIntent,
  sourceQuery,
} from "../_shared/generator/service.ts";
import { validateIntent } from "../_shared/generator/contracts.ts";
import { decodeVoice, transcribe } from "../_shared/generator/voice.ts";
import { buildCatalog } from "../_shared/generator/catalog.ts";
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
Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return reply({});
  if (request.method !== "POST") {
    return reply({ error: "Méthode non autorisée." }, 405);
  }
  if (Number(request.headers.get("content-length") ?? 0) > 2700000) {
    return reply({ error: "Demande trop longue." }, 413);
  }
  let reservation: string | null = null;
  let stage = "authenticate";
  let aiUsage: unknown = null;
  const started = performance.now();
  const call = async (
    path: string,
    body?: unknown,
    method?: string,
    timeoutMs?: number,
  ) => {
    stage = path.split("?")[0];
    return await rest(path, body, method, timeoutMs);
  };
  const sourcesFor = (
    context: ReturnType<typeof contextFrom>,
    date: string,
    sports = Object.keys(context.preferences),
  ) =>
    call(
      "rpc/lector_generator_sources_filtered",
      sourceQuery(context, date, sports),
    ) as Promise<Source[]>;
  try {
    const auth = request.headers.get("authorization") ?? "";
    if (!auth.startsWith("Bearer ")) {
      return reply({ error: "Connectez-vous pour utiliser l’assistant." }, 401);
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
    const text = await request.text();
    if (text.length > 2700000) {
      return reply({ error: "Demande trop longue." }, 413);
    }
    const input = obj(JSON.parse(text)), action = input.action;
    if (action !== "transcribe" && text.length > 25000) {
      return reply({ error: "Demande trop longue." }, 413);
    }
    if (action === "history") {
      const history = await call(
        `lector_generator_conversations?user_id=eq.${user.id}&select=id,state,updated_at&state->>saved=eq.true&order=updated_at.desc&limit=20`,
      );
      return reply({ history: history.map((h: Json) => h.state) });
    }
    if (
      !uuid(input.conversationId) || !Number.isInteger(input.revision) ||
      Number(input.revision) < 0
    ) return reply({ error: "Conversation invalide." }, 400);
    const id = String(input.conversationId), revision = Number(input.revision);
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
        },
      });
    }
    const states = await call(
      `lector_generator_conversations?id=eq.${id}&user_id=eq.${user.id}&select=state,revision`,
    );
    const previous = states.length && Object.keys(states[0].state).length
      ? states[0].state as State
      : null;
    if (action === "read") return reply({ state: previous });
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
        error: "La conversation a changé dans une autre fenêtre. Rechargez-la.",
      }, 409);
    }
    const now = new Date();
    if (["apply", "save"].includes(String(action))) {
      if (!previous) {
        return reply({ error: "Aucune composition à enregistrer." }, 400);
      }
      const next = { ...previous };
      if (action === "apply") {
        if (!previous.pending) {
          return reply({ error: "Aucun changement en attente." }, 400);
        }
        for (const ticket of previous.pending) {
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
        next.tickets = previous.pending;
        next.versions = [...previous.versions, next.tickets].slice(-3);
        next.pending = null;
        next.saved = false;
      } else next.saved = true;
      const state = await call("rpc/lector_generator_commit", {
        p_user: user.id,
        p_conversation: id,
        p_revision: revision,
        p_state: next,
      });
      return reply({ state });
    }
    const context = contextFrom(input.context), date = String(input.date ?? "");
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
      model = Deno.env.get("LECTOR_OPENAI_MODEL");
    if (Deno.env.get("LECTOR_GENERATOR_ENABLED") !== "true" || !key || !model) {
      return reply({
        error:
          "L’assistant IA n’est pas encore activé. Les appels IA restent désactivés tant que sa configuration serveur n’est pas installée.",
      }, 503);
    }
    const voice = action === "transcribe" ? decodeVoice(input.audio) : null;
    const claim = await call("rpc/lector_generator_reserve", {
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
    });
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
    const progress = async (phase: string) => {
      await rest(
        `lector_generator_turns?request_id=eq.${reservation}&user_id=eq.${user.id}&status=eq.pending`,
        { usage: { phase } },
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
    await progress("interpret");
    stage = "interpret";
    const { intent: parsed, usage } = await interpret({
      message: String(input.message).trim(),
      date,
      context,
      state: previous,
      today: calendarDay(now, context.timezone),
    }, { key, model });
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
    const revisionContext = ["generate", "explore"].includes(intent.action)
      ? context
      : (intent.referenceTicketId
        ? [...(previous?.tickets ?? []), ...(previous?.drafts ?? [])].find(
          (t) => t.id === intent.referenceTicketId,
        )?.context
        : undefined) ??
        previous?.tickets[intent.ticketIndex ?? 0]?.context ??
        previous?.context ?? context;
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
      ["generate", "alternative", "replace", "remove", "explore"].includes(
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
    const next = applyIntent({
      state: previous,
      context,
      intent,
      sources,
      message: String(input.message).trim(),
      now,
      id,
    });
    await progress("commit");
    const state = await call("rpc/lector_generator_commit", {
      p_user: user.id,
      p_conversation: id,
      p_revision: revision,
      p_state: next,
      p_request: reservation,
      p_usage: usage,
    });
    reservation = null;
    return reply({ state });
  } catch (error) {
    if (reservation) {
      await rest(
        `lector_generator_turns?request_id=eq.${reservation}&status=eq.pending`,
        {
          status: "failed",
          usage: {
            failure_stage: stage,
            elapsed_ms: Math.round(performance.now() - started),
            ai_usage: aiUsage,
          },
        },
        "PATCH",
      ).catch(() => {});
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
});
