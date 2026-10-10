import { analysisCandidates, analysisContext } from "./analysis.ts";
import { buildCatalog, type Source } from "./catalog.ts";
import {
  calendarDay,
  type Catalog,
  type Context,
  type Intent,
  obj,
  rows,
  type Sport,
  type State,
  strings,
  validateIntent,
} from "./contracts.ts";
import { applyIntent } from "./service.ts";
import {
  businessId,
  constraintFields,
  type ConversationPlan,
  matchKey,
  resolvePlan,
  ticketSummary,
  validatePlan,
} from "./conversation_memory.ts";
import { intentSchema } from "./openai.ts";
import { assessCandidate } from "./workshop.ts";
import type { DayReadCoverage } from "./day_sources.ts";
import {
  type DayEvaluation,
  evaluateMatches,
  evaluationOverview,
  type MatchSheet,
  prepareMatchSheets,
} from "./match_evaluation.ts";
import type { ModelOptions } from "./models.ts";

const array = { type: "array", items: { type: "string" } };
export const planSchema = {
  type: "object",
  additionalProperties: false,
  required: ["intent", "changedFields", "newTask", "focusMode", "focusKeys"],
  properties: {
    intent: intentSchema,
    changedFields: {
      type: "array",
      items: { type: "string", enum: constraintFields },
    },
    newTask: { type: "boolean" },
    focusMode: { type: "string", enum: ["keep", "choose", "clear"] },
    focusKeys: {
      ...array,
      description:
        "Identités sport:id déjà consultées, uniquement pour choisir une liste précise.",
    },
  },
};
const tool = (
  name: string,
  description: string,
  properties: Record<string, unknown>,
) => ({
  type: "function",
  name,
  description,
  strict: true,
  parameters: {
    type: "object",
    additionalProperties: false,
    required: Object.keys(properties),
    properties,
  },
});
export const conversationTools = [
  tool(
    "read_profile",
    "Lire la configuration active de cette session et ses marchés autorisés. Aucune modification du profil.",
    {},
  ),
  tool(
    "search_matches",
    "Rechercher les rencontres publiées pour une autre journée, un sport ou une vue Lector. Radar reprend exclusivement la liste native et ses filtres. Pagination explicite ; ne pas confondre la première page avec la liste complète.",
    {
      date: { type: "string" },
      sports: {
        type: "array",
        items: { type: "string", enum: ["football", "hockey"] },
      },
      view: { type: "string", enum: ["profile", "radar", "all"] },
      radarKind: { type: "string", enum: ["teams", "players"] },
      query: { type: ["string", "null"] },
      offset: { type: "integer" },
      limit: { type: "integer" },
    },
  ),
  tool(
    "evaluate_matches",
    "Évaluer individuellement toutes les rencontres d’une recherche selon un critère naturel, puis lire l’ensemble des évaluations pour les comparer. Aucune présélection : matchKeys=null couvre la recherche entière, y compris les pages non affichées. Sinon évaluer exactement les clés demandées. Ne pas confondre récupération et évaluation. Le résultat indique toute couverture incomplète. Lecture et analyse en mémoire uniquement.",
    {
      queryId: { type: "string" },
      criteria: { type: "string" },
      matchKeys: { anyOf: [array, { type: "null" }] },
    },
  ),
  tool(
    "read_match_evaluations",
    "Lire les évaluations individuelles déjà réalisées dans cette conversation (evaluationId ou latest), leurs références et limites, y compris les rencontres non retenues. Aucun nouvel appel IA.",
    {
      evaluationId: { type: "string" },
      offset: { type: "integer" },
      limit: { type: "integer" },
    },
  ),
  tool(
    "read_matches",
    "Lire les arguments, contradictions, échantillons et marchés admissibles de rencontres issues d’une recherche. Les clés sport:id évitent de confondre deux sports. Maximum huit rencontres.",
    { queryId: { type: "string" }, matchKeys: array },
  ),
  tool(
    "read_match_data",
    "Consulter les données détaillées publiées d’une rencontre recherchée : forme, classements, H2H, score ou statistiques selon disponibilité. Ne rend jamais une cote ancienne admissible.",
    { queryId: { type: "string" }, matchKey: { type: "string" } },
  ),
  tool(
    "read_session",
    "Retrouver les échanges, contraintes, rencontres retenues et tickets de cette session. Pagination du registre et consultation d’un ticket par référence ; jamais accès à un autre utilisateur.",
    {
      offset: { type: "integer" },
      limit: { type: "integer" },
      ticketId: { type: ["string", "null"] },
    },
  ),
  tool(
    "read_bilan",
    "Lire le Bilan descriptif publié et les suivis de l’utilisateur connecté. Aucune vérification ou sauvegarde déclenchée. Un taux de confirmation n’est pas une probabilité de pari.",
    {},
  ),
  tool(
    "read_composition_options",
    "Examiner une projection calculée de compositions avec cotes et contraintes vérifiées. Calcul en mémoire uniquement : aucune écriture, aucun pari, aucune sauvegarde ni application. Lire ce résultat avant d’annoncer un ticket. Le modèle reçoit des identifiants de propositions, il ne fournit jamais des prix.",
    { plan: planSchema },
  ),
];

/** A deliberately narrow capability interface. No SQL, URL, user ID, RPC or write method. */
export interface ConversationReadPort {
  sources(context: Context, date: string, sports: Sport[]): Promise<Source[]>;
  daySources?(
    context: Context,
    date: string,
    sports: Sport[],
    progress: (coverage: DayReadCoverage) => Promise<void>,
  ): Promise<{ sources: Source[]; coverage: DayReadCoverage }>;
  matchData?(
    sport: Sport,
    date: string,
    id: string,
    capturedAt: string,
    sourceId: string,
  ): Promise<unknown>;
  bilan?(): Promise<unknown>;
  archivedTicket?(id: string): Promise<State["tickets"][number] | null>;
  evaluation?(id: string): Promise<DayEvaluation | null>;
}
export interface ReadQuery {
  id: string;
  date: string;
  context: Context;
  sports: Sport[];
  sources: Source[];
  coverage?: DayReadCoverage;
  catalog: Catalog;
  matches: {
    key: string;
    id: string;
    sport: Sport;
    competition: string;
    home: string;
    away: string;
    kickoff: string;
    status: string;
    sourceId: string;
    capturedAt: string;
  }[];
}
const exact = (args: Record<string, unknown>, keys: string[]) => {
  if (Object.keys(args).sort().join() !== [...keys].sort().join()) {
    throw new Error("Paramètres d’outil non autorisés.");
  }
};
const page = (args: Record<string, unknown>, maximum: number) => {
  if (
    !Number.isInteger(args.offset) || Number(args.offset) < 0 ||
    Number(args.offset) > 10000 ||
    !Number.isInteger(args.limit) || Number(args.limit) < 1 ||
    Number(args.limit) > maximum
  ) throw new Error("Page invalide.");
  return { offset: Number(args.offset), limit: Number(args.limit) };
};
const normalize = (s: string) =>
  s.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
export class ConversationReader {
  readonly queries = new Map<string, ReadQuery>();
  readonly previews = new Map<
    string,
    {
      plan: ConversationPlan;
      intent: Intent;
      context: Context;
      next: State;
      report: unknown;
    }
  >();
  readonly detailsRead = new Set<string>();
  readonly evaluations = new Map<string, DayEvaluation>();
  private sheets = new Map<string, MatchSheet[]>();
  matchSheets(q: ReadQuery) {
    if (!this.sheets.has(q.id)) {
      this.sheets.set(q.id, prepareMatchSheets(q, this.input.now));
    }
    return this.sheets.get(q.id)!;
  }
  private requests = new Map<string, Promise<ReadQuery>>();
  private reads = 0;
  private totalMatches = 0;
  private state: State | null;
  constructor(
    readonly input: {
      context: Context;
      date: string;
      state: State | null;
      now: Date;
      id: string;
      message: string;
    },
    private port: ConversationReadPort,
    private progress: (phase: string, detail: string) => Promise<void> =
      async () => {},
    private evaluator?: ModelOptions & {
      deadline: number;
      onEvaluation?: (r: DayEvaluation) => Promise<void>;
    },
  ) {
    this.state = input.state ? structuredClone(input.state) : null;
  }
  private validDay(date: unknown): string {
    if (
      typeof date !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(date) ||
      !Number.isFinite(Date.parse(date)) ||
      new Date(date).toISOString().slice(0, 10) !== date
    ) throw new Error("Date de lecture invalide.");
    const today = calendarDay(this.input.now, this.input.context.timezone);
    const gap = (Date.parse(date) - Date.parse(today)) / 86400000;
    if (gap < -14 || gap > 13) {
      throw new Error(
        "La recherche couvre les 14 derniers jours et les 13 prochains jours, selon les publications disponibles.",
      );
    }
    return date;
  }
  async query(
    date: string,
    sports: Sport[],
    view: "profile" | "radar" | "all",
    radarKind: "teams" | "players",
  ) {
    this.validDay(date);
    if (
      !sports.length || sports.length > 2 ||
      new Set(sports).size !== sports.length ||
      sports.some((s) => !["football", "hockey"].includes(s)) ||
      !["profile", "radar", "all"].includes(view) ||
      !["teams", "players"].includes(radarKind)
    ) throw new Error("Périmètre de lecture invalide.");
    const key = JSON.stringify([date, [...sports].sort(), view, radarKind]);
    if (!this.requests.has(key)) {
      if (this.requests.size >= 8) {
        throw new Error(
          "Trop de journées consultées dans un seul échange ; poursuivez la comparaison dans le message suivant.",
        );
      }
      this.requests.set(key, this.loadQuery(date, sports, view, radarKind));
    }
    return await this.requests.get(key)!;
  }
  private async loadQuery(
    date: string,
    sports: Sport[],
    view: "profile" | "radar" | "all",
    radarKind: "teams" | "players",
  ) {
    const context: Context = {
      ...structuredClone(this.input.context),
      view,
      radarKind,
      scope: view === "profile" ? "strict" : "discovery",
    };
    await this.progress(
      "sources",
      `Consultation de ${
        view === "profile" ? "Pour moi" : view === "radar" ? "Radar" : "Tous"
      } · ${date} · ${sports.join(" + ")}`,
    );
    const day = this.port.daySources
      ? await this.port.daySources(context, date, sports, async (coverage) => {
        await this.progress(
          "sources",
          `${coverage.loaded}/${coverage.expected} rencontres récupérées · ${date}${
            coverage.complete ? " · lecture complète" : ""
          }`,
        );
      })
      : null;
    const sources = day?.sources ??
      await this.port.sources(context, date, sports);
    if (!day && JSON.stringify(sources).length > 1500000) {
      throw new Error("Publication trop volumineuse pour ce périmètre.");
    }
    const catalog = buildCatalog(sources, context, date, this.input.now, {
      includePastAndLive: true,
    });
    const known = new Map(
      (catalog.matches ?? []).map((m) => [matchKey(m.sport, m.id), m]),
    );
    const matches: ReadQuery["matches"] = [];
    const seen = new Set<string>();
    for (
      const source of [...sources].sort((a, b) =>
        b.capturedAt.localeCompare(a.capturedAt)
      )
    ) {
      if (!sports.includes(source.sport)) continue;
      const native = source.sport === "hockey";
      for (
        const raw of rows(
          native ? source.payload.items : obj(source.payload.raw).fixtures,
        )
      ) {
        const fixture = native ? raw : obj(raw.fixture),
          teams = native ? raw : obj(raw.teams);
        const id = String(fixture.id),
          key = matchKey(source.sport, id),
          kickoff = String(native ? raw.startsAt : fixture.date);
        if (
          !/^\d{1,12}$/.test(id) || seen.has(key) ||
          !Number.isFinite(Date.parse(kickoff)) ||
          calendarDay(kickoff, context.timezone) !== date
        ) continue;
        if (view !== "all" && !known.has(key)) continue;
        seen.add(key);
        matches.push({
          key,
          id,
          sport: source.sport,
          competition: String(
            native
              ? raw.competitionName ?? raw.competitionId
              : obj(raw.league).name,
          ),
          home: String(obj(teams.home).name),
          away: String(obj(teams.away).name),
          kickoff,
          status: String(native ? raw.status : obj(fixture.status).short),
          sourceId: source.id,
          capturedAt: source.capturedAt,
        });
      }
    }
    this.totalMatches += matches.length;
    if (this.totalMatches > 3000) {
      throw new Error(
        "Trop de rencontres dans cet échange ; ciblez davantage la recherche.",
      );
    }
    const query: ReadQuery = {
      id: `q${this.queries.size + 1}`,
      date,
      context,
      sports,
      sources,
      ...(day ? { coverage: day.coverage } : {}),
      catalog,
      matches,
    };
    this.queries.set(query.id, query);
    return query;
  }
  private getQuery(id: unknown) {
    const query = typeof id === "string" ? this.queries.get(id) : undefined;
    if (!query) {
      throw new Error("Recherchez d’abord ces rencontres dans la session.");
    }
    return query;
  }
  private details(q: ReadQuery, key: string) {
    const match = q.matches.find((m) => m.key === key);
    if (!match) throw new Error("Rencontre extérieure au périmètre consulté.");
    this.detailsRead.add(`${q.id}:${key}`);
    return {
      ...q.catalog.matches?.find((m) => matchKey(m.sport, m.id) === key),
      ...match,
      evidence: this.matchSheets(q).find((s) => s.key === key)?.facts ?? [],
      candidates: analysisCandidates(
        q.catalog,
        { ...this.input.state?.intent, marketIds: [] } as Intent,
        this.input.now,
      )
        .filter((c) => matchKey(c.sport, c.matchId) === key).map((c) => ({
          ...c,
          assessment: assessCandidate(c, this.input.now),
        })),
    };
  }
  async resolve(plan: ConversationPlan) {
    const intent = resolvePlan(
      plan,
      this.state,
      this.input.context,
      this.input.date,
    );
    const context = analysisContext(this.input.context, intent);
    const query = await this.query(
      intent.date,
      intent.sports,
      context.view ?? "profile",
      context.radarKind ?? "teams",
    );
    if (plan.focusMode === "choose") {
      intent.fixtureFocus = plan.focusKeys.map((key) => {
        const match = query.matches.find((m) => m.key === key);
        if (!match || !this.detailsRead.has(`${query.id}:${key}`)) {
          throw new Error(
            "Consultez les détails avant de retenir cette rencontre.",
          );
        }
        return {
          sport: match.sport,
          matchId: businessId(match.sport, match.id),
          match: `${match.home} — ${match.away}`,
        };
      });
      intent.preserveFixtures =
        intent.fixtureFocus.length <= (intent.maxSelections ?? 6);
    }
    return { intent, context, query };
  }
  async execute(name: string, raw: unknown): Promise<unknown> {
    if (++this.reads > 32) {
      throw new Error("Limite de consultations atteinte pour cet échange.");
    }
    const args = obj(raw);
    switch (name) {
      case "read_profile":
        exact(args, []);
        return {
          preferences: structuredClone(this.input.context.preferences),
          budget: this.input.context.budget,
          timezone: this.input.context.timezone,
          origin: this.input.context.origin,
          semantics:
            "Configuration active transmise par l’application ; lecture seule, jamais modifiée par Hector.",
        };
      case "evaluate_matches": {
        exact(args, ["queryId", "criteria", "matchKeys"]);
        const q = this.getQuery(args.queryId);
        if (!this.evaluator) {
          throw new Error(
            "Évaluation individuelle IA indisponible dans cette session.",
          );
        }
        if (
          typeof args.criteria !== "string" || !args.criteria.trim() ||
          args.criteria.length > 1200
        ) {
          throw new Error("Critère d’évaluation invalide.");
        }
        let query = q;
        if (args.matchKeys !== null) {
          if (
            !Array.isArray(args.matchKeys) || !args.matchKeys.length ||
            strings(args.matchKeys).length !== args.matchKeys.length ||
            new Set(args.matchKeys).size !== args.matchKeys.length ||
            args.matchKeys.some((k) => !q.matches.some((m) => m.key === k))
          ) {
            throw new Error(
              "Rencontres d’évaluation hors périmètre ou dupliquées.",
            );
          }
          query = {
            ...q,
            matches: q.matches.filter((m) =>
              (args.matchKeys as string[]).includes(m.key)
            ),
          };
        }
        if (query.matches.length > 750) {
          throw new Error(
            "Ce protocole compare au maximum 750 fiches par recherche ; précisez le périmètre. Aucune rencontre n’a été omise.",
          );
        }
        const previous = [...this.evaluations.values()].find((r) =>
          r.queryId === q.id && r.criteria === args.criteria &&
          r.expected === query.matches.length && [
            ...r.rows.map((r) => r.key),
            ...r.failed.flatMap((f) => f.keys),
          ]
            .every((key) => query.matches.some((m) => m.key === key))
        );
        if (previous) return evaluationOverview(previous, q);
        if (this.evaluations.size >= 2) {
          throw new Error(
            "Deux critères ont déjà été évalués dans cet échange ; poursuivez au message suivant.",
          );
        }
        const report = await evaluateMatches({
          id: crypto.randomUUID(),
          query,
          criteria: args.criteria.trim(),
          now: this.input.now,
          deadline: this.evaluator.deadline,
          onProgress: (n, total) =>
            this.progress(
              "evaluate",
              `${n} / ${total} rencontres évaluées selon votre critère`,
            ),
        }, this.evaluator);
        this.evaluations.set(report.id, report);
        for (const row of report.rows) {
          this.detailsRead.add(`${q.id}:${row.key}`);
        }
        await this.evaluator.onEvaluation?.(report);
        return evaluationOverview(report, q);
      }
      case "read_match_evaluations": {
        exact(args, ["evaluationId", "offset", "limit"]);
        const p = page(args, 40), evaluationId = String(args.evaluationId);
        if (
          evaluationId !== "latest" && !/^[0-9a-f-]{36}$/i.test(evaluationId)
        ) throw new Error("Référence d’évaluation invalide.");
        const report =
          (evaluationId === "latest"
            ? [...this.evaluations.values()].at(-1)
            : this.evaluations.get(evaluationId)) ??
            await this.port.evaluation?.(evaluationId);
        if (!report) throw new Error("Évaluation inconnue dans cet échange.");
        return {
          evaluationId: report.id,
          criteria: report.criteria,
          scope: report.scope,
          total: report.rows.length,
          rows: report.rows.slice(p.offset, p.offset + p.limit),
          nextOffset: p.offset + p.limit < report.rows.length
            ? p.offset + p.limit
            : null,
          complete: report.complete,
          failed: report.failed,
        };
      }
      case "search_matches": {
        exact(args, [
          "date",
          "sports",
          "view",
          "radarKind",
          "query",
          "offset",
          "limit",
        ]);
        const pagination = page(args, 60);
        if (
          !Array.isArray(args.sports) ||
          strings(args.sports).length !== args.sports.length ||
          (args.query !== null &&
            (typeof args.query !== "string" || args.query.length > 120))
        ) throw new Error("Recherche invalide.");
        const q = await this.query(
          String(args.date),
          args.sports as Sport[],
          args.view as "profile",
          args.radarKind as "teams",
        );
        const found = q.matches.filter((m) =>
          args.query === null ||
          normalize(`${m.home} ${m.away} ${m.competition}`).includes(
            normalize(String(args.query)),
          )
        );
        return {
          queryId: q.id,
          date: q.date,
          view: q.context.view,
          sports: q.sports,
          radarKind: q.context.radarKind,
          total: found.length,
          offset: pagination.offset,
          hasMore: pagination.offset + pagination.limit < found.length,
          nextOffset: pagination.offset + pagination.limit < found.length
            ? pagination.offset + pagination.limit
            : null,
          ...(q.coverage ? { coverage: q.coverage } : {}),
          matches: found.slice(
            pagination.offset,
            pagination.offset + pagination.limit,
          ).map((m) => ({
            ...m,
            candidates:
              q.catalog.candidates.filter((c) =>
                matchKey(c.sport, c.matchId) === m.key
              ).length,
          })),
          missing: q.catalog.missing,
          sourceIds: q.sources.map((s) => s.id),
        };
      }
      case "read_matches": {
        exact(args, ["queryId", "matchKeys"]);
        const keys = strings(args.matchKeys);
        if (
          !Array.isArray(args.matchKeys) || !keys.length || keys.length > 8 ||
          keys.length !== args.matchKeys.length ||
          new Set(keys).size !== keys.length
        ) throw new Error("Liste de rencontres invalide.");
        const q = this.getQuery(args.queryId);
        await this.progress(
          "details",
          `Examen des lectures et marchés de ${keys.length} rencontres · ${q.date}`,
        );
        return keys.map((key) => this.details(q, key));
      }
      case "read_match_data": {
        exact(args, ["queryId", "matchKey"]);
        const q = this.getQuery(args.queryId),
          m = this.details(q, String(args.matchKey));
        const response = obj(
          await this.port.matchData?.(
            m.sport,
            q.date,
            m.id,
            m.capturedAt,
            m.sourceId,
          ),
        );
        const payload = obj(
            "publication" in response ? response.publication : response,
          ),
          live = response.live ?? null;
        if (!Object.keys(payload).length) {
          return {
            match: m,
            live,
            data: null,
            limitation:
              "Les données détaillées de cette publication ne sont pas disponibles.",
          };
        }
        if (
          payload.sport !== m.sport || payload.capturedAt !== m.capturedAt ||
          !rows(payload.items).some((f) => String(f.id) === m.id)
        ) {
          return {
            match: m,
            live,
            data: null,
            limitation:
              "La version détaillée disponible diffère de la recherche ; ses données ne sont pas substituées à la publication consultée.",
          };
        }
        // Only published sports fields; cap a single detail without truncating JSON.
        const projection = {
          match: m,
          live,
          items: rows(payload.items).filter((f) => String(f.id) === m.id),
          competitions: rows(payload.competitions),
          playerRadar: obj(payload.playerRadar),
        };
        if (JSON.stringify(projection).length > 65000) {
          return {
            match: m,
            live,
            data: null,
            limitation:
              "Détail trop volumineux ; les lectures et marchés vérifiés restent consultables.",
          };
        }
        return projection;
      }
      case "read_session": {
        exact(args, ["offset", "limit", "ticketId"]);
        const { offset, limit } = page(args, 20);
        if (
          args.ticketId !== null &&
          (typeof args.ticketId !== "string" ||
            !/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i
              .test(args.ticketId))
        ) throw new Error("Référence de ticket invalide.");
        const all = [
          ...(this.state?.tickets ?? []),
          ...(this.state?.drafts ?? []),
          ...(this.state?.pending ?? []),
        ];
        let ticket = args.ticketId
          ? all.find((t) => t.id === args.ticketId)
          : undefined;
        if (args.ticketId && !ticket) {
          ticket = await this.port.archivedTicket?.(String(args.ticketId)) ??
            undefined;
          if (ticket && this.state) {
            this.state.drafts = [...(this.state.drafts ?? []), ticket];
          }
        }
        const turns = this.state?.conversation?.turns ?? [];
        return {
          ticket: ticket ? ticketSummary(ticket) : null,
          tickets: [
            ...new Map(all.map((t) => [t.id, { id: t.id, number: t.number }]))
              .values(),
          ],
          turns: turns.slice(offset, offset + limit),
          hasMore: offset + limit < turns.length,
          olderTurns: this.state?.conversation?.olderTurns ?? 0,
          messages: this.state?.messages.slice(offset, offset + limit).map((
            m,
          ) => ({
            role: m.role,
            text: m.text,
            at: m.at,
            ticketIds: m.ticketIds,
            analysis: m.analysis
              ? {
                context: m.analysis.context,
                observations: m.analysis.observations,
                selections: m.analysis.selections.map((s) => ({
                  id: s.candidate.id,
                  key: matchKey(s.candidate.sport, s.candidate.matchId),
                  marketId: s.candidate.marketId,
                  selection: s.candidate.selection,
                  odds: s.candidate.odds,
                  oddsAt: s.candidate.oddsAt,
                  reason: s.reason,
                  vigilance: s.vigilance,
                  references: s.references,
                })),
              }
              : undefined,
          })),
        };
      }
      case "read_bilan":
        exact(args, []);
        await this.progress("details", "Consultation du Bilan descriptif");
        return await this.port.bilan?.() ?? { unavailable: true };
      case "read_composition_options": {
        exact(args, ["plan"]);
        const plan = validatePlan(args.plan);
        if (
          !["generate", "alternative", "replace", "remove", "restore"].includes(
            plan.intent.action,
          )
        ) {
          throw new Error(
            "Cette projection concerne uniquement une composition.",
          );
        }
        const { intent, context, query } = await this.resolve(plan);
        await this.progress(
          "compose",
          "Comparaison de compositions calculées à partir des données vérifiées",
        );
        let report: unknown = null;
        const next = applyIntent({
          state: this.state ? structuredClone(this.state) : null,
          context,
          intent,
          sources: query.sources,
          message: this.input.message,
          now: this.input.now,
          id: this.input.id,
          workshop: true,
          conversationResolved: true,
          onWorkshop: (r) => report = r,
        });
        const id = `projection-${this.previews.size + 1}`;
        this.previews.set(id, { plan, intent, context, next, report });
        const attached = next.messages.at(-1)!;
        const tickets = [
          ...new Map(
            [
              ...(next.proposals ?? []),
              ...(next.drafts ?? []),
              ...(next.pending ?? []),
            ]
              .filter((t) =>
                attached.ticketIds?.includes(t.id) ||
                attached.proposalIds?.includes(t.id) ||
                next.pending?.some((p) => p.id === t.id)
              )
              .map((t) => [t.id, t]),
          ).values(),
        ];
        return {
          projectionId: id,
          intent,
          result: attached.text,
          clarification: validateIntent(intent, context, this.input.now),
          tickets: tickets.map(ticketSummary),
          missing: query.catalog.missing,
          semantics:
            "Projection calculée en mémoire ; aucun ticket sauvegardé, aucun profil modifié, aucun pari placé.",
        };
      }
      default:
        throw new Error(
          "Outil non autorisé : seules les consultations Lector déclarées sont disponibles.",
        );
    }
  }
  consultations(): NonNullable<State["conversation"]>["consultations"] {
    return [...this.queries.values()].map((q) => ({
      key: `${q.date}:${
        q.sports.join("+")
      }:${q.context.view}:${q.context.radarKind}`,
      date: q.date,
      view: q.context.view ?? "profile",
      sports: q.sports,
      sources: q.sources.map((s) => s.id),
      ...(q.coverage ? { coverage: q.coverage } : {}),
    }));
  }
  sessionState() {
    return this.state ? structuredClone(this.state) : null;
  }
}
