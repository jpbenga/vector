import {
  changedSheets,
  compareExploration,
  frozenQuery,
  requireSnapshot,
  reusableRows,
} from "./exploration_continuity.ts";
import { buildExplorationReport, explorationCriterion } from "./exploration.ts";
import { ExplorationBudget } from "./exploration_budget.ts";
import { footballPublishedQuotes } from "./published_quotes.ts";
import {
  mergeShortlistSources,
  shortlistGroups,
  type ShortlistScope,
} from "./shortlist.ts";
import { analysisCandidates, analysisContext } from "./analysis.ts";
import { buildCatalog, type Source } from "./catalog.ts";
import {
  calendarDay,
  type Catalog,
  type Context,
  focusFitsTargets,
  type Intent,
  obj,
  rows,
  type Sport,
  type State,
  strings,
  usesRequestConfiguration,
  validateIntent,
} from "./contracts.ts";
import { applyIntent } from "./service.ts";
import {
  businessId,
  constraintFields,
  type ConversationPlan,
  matchKey,
  resolvePlan,
  validatePlan,
  workingIntent,
} from "./conversation_memory.ts";
import {
  CompositionContractError,
  requestedSports,
  sameSports,
} from "./conversation_scope.ts";
import { intentSchema } from "./openai.ts";
import {
  modelCandidate,
  modelEvidence,
  modelTickets,
} from "./conversation_projection.ts";
import type { DayReadCoverage } from "./day_sources.ts";
import {
  type DayEvaluation,
  evaluateMatches,
  evaluationOverview,
  type MatchSheet,
  prepareMatchSheets,
} from "./match_evaluation.ts";
import type { ModelOptions } from "./models.ts";
import {
  type MarketAvailability,
  marketAvailability,
} from "./market_availability.ts";

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
    "read_shortlist",
    "Lire la sélection Shortlist authentifiée, toutes ses dates et ses sports, et obtenir son queryId. Aucune mutation. Les rencontres hors sélection ne font pas partie de cette préparation. Utiliser search_matches(view=shortlist) pour filtrer un sport ; lire Tous seulement après demande explicite d’élargissement.",
    {},
  ),
  tool(
    "read_profile",
    "Lire le contexte et les préférences de cette session, ainsi que leur rôle informatif ou contraignant indiqué par le serveur. Aucune modification du profil.",
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
      view: { type: "string", enum: ["profile", "radar", "all", "shortlist"] },
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
      observationCount: {
        type: ["integer", "null"],
        minimum: 1,
        maximum: 20,
        description: "Nombre d’observations sans ticket ; null pour composer.",
      },
      useProfileReadings: {
        type: ["boolean", "null"],
        description:
          "True pour le critère explicite mes lectures. Null hors exploration.",
      },
      formScope: {
        type: ["string", "null"],
        enum: ["domestic_championship", "competition", null],
        description:
          "Périmètre de forme explicite. Championnat domestique par défaut pour l'exploration football.",
      },
    },
  ),
  tool(
    "continue_match_evaluation",
    "Reprendre uniquement les lots non évalués d’une évaluation incomplète de cet échange, avec exactement le même critère, les mêmes sources et le même périmètre. Conserve les évaluations validées et retourne la couverture cumulée de l’ensemble original. Un appel supplémentaire borné, jamais une relance de toute la journée. Aucun changement de données ou de profil.",
    { evaluationId: { type: "string" } },
  ),
  tool(
    "reevaluate_exploration",
    "Actualiser explicitement une préparation archivée : même critère et périmètre, nouvelle version et différences. Évaluer seulement les données sportives modifiées ou manquantes.",
    { evaluationId: { type: "string" } },
  ),
  tool(
    "compare_exploration",
    "Comparer les faits archivés des rencontres choisies, sans nouvelle évaluation ni actualisation.",
    { evaluationId: { type: "string" }, matchKeys: array },
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
    "Lire les arguments, contradictions, échantillons et marchés admissibles de rencontres issues d’une recherche. Les clés sport:id évitent de confondre deux sports. Regrouper jusqu’à huit rencontres par appel ; inutile de faire un appel séparé pour chaque clé.",
    { queryId: { type: "string" }, matchKeys: array },
  ),
  tool(
    "read_match_data",
    "Consulter les données détaillées publiées d’une rencontre recherchée : forme, classements, H2H, score ou statistiques selon disponibilité. Pour une rencontre UEFA, items[].europeanComparison contient le dossier pré-match domestique/européen avec cutoff et provenance. Ne rend jamais une cote ancienne admissible.",
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
    "read_analysis",
    "Relire une analyse antérieure par analysisRef obtenu dans read_session, par pages de sélections. Snapshot exact de la proposition d’origine, sans nouvel appel IA ; ne rend pas ses anciennes cotes admissibles aujourd’hui.",
    {
      analysisId: { type: "string" },
      offset: { type: "integer" },
      limit: { type: "integer" },
    },
  ),
  tool(
    "read_work_evidence",
    "Relire les preuves exactes d’un ticket ou d’une analyse archivée. Pagination des preuves et du texte ; continuer avec nextTextOffset si textComplete=false. Aucun recalcul, aucune écriture et aucune actualisation implicite de cote.",
    {
      kind: { type: "string", enum: ["ticket", "analysis"] },
      objectId: { type: "string" },
      offset: { type: "integer" },
      limit: { type: "integer" },
      textOffset: { type: "integer" },
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
    signal?: AbortSignal,
  ): Promise<unknown>;
  bilan?(): Promise<unknown>;
  archivedTicket?(id: string): Promise<State["tickets"][number] | null>;
  archivedAnalysis?(
    id: string,
  ): Promise<import("./contracts.ts").Analysis | null>;
  sessionHistory?(offset: number, limit: number): Promise<unknown>;
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
    competitionId?: string;
    season?: string;
    home: string;
    away: string;
    kickoff: string;
    status: string;
    sourceId: string;
    capturedAt: string;
    homeLogo?: string;
    awayLogo?: string;
    marketAvailability?: MarketAvailability;
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
const competitionAliases: Record<string, string> = {
  "2": "Ligue des champions Champions League",
  "3": "Ligue Europa Europa League",
  "848": "Ligue Conference Conference League Ligue de conference",
};
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
  /** Expand only verified reports from this exchange and this exact query. */
  expandComparedKeys(queryId: string, ids: unknown): string[] {
    if (!Array.isArray(ids) || ids.some((id) => typeof id !== "string")) {
      throw new Error("Références de comparaison invalides.");
    }
    const keys = ids.flatMap((id: string) => {
      if (!id.startsWith("evaluation:")) return [id];
      const report = this.evaluations.get(id.slice("evaluation:".length));
      if (!report || report.queryId !== queryId) {
        throw new Error("Référence d’évaluation étrangère à cette recherche.");
      }
      return report.rows.map((row) => row.key);
    });
    return [...new Set(keys)];
  }
  private requests = new Map<string, Promise<ReadQuery>>();
  private reads = 0;
  private totalMatches = 0;
  private state: State | null;
  private explorationBudget?: ExplorationBudget;
  private archiveExplorationRead = false;
  get hasExploration() {
    return this.archiveExplorationRead ||
      [...this.evaluations.values()].some((r) => r.exploration) ||
      this.state?.messages.some((m) =>
        m.analysis?.exploration || m.explorationRef
      );
  }
  private explorationDetails = new Map<string, unknown>();
  private clock = () => performance.now();
  private startedAt: number;
  private requestSports: Sport[] | null;
  private explorationBaseCalls: number | null = null;
  get explorationDeadline() {
    return this.explorationBudget?.deadline;
  }
  get explorationFinalizationMs() {
    return this.explorationBudget?.config.finalizationMs;
  }
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
    this.clock = evaluator?.clock ?? this.clock;
    this.startedAt = this.clock();
    this.state = input.state ? structuredClone(input.state) : null;
    this.requestSports = requestedSports(input.message);
    // Existing sessions/ticket revisions inherit the current server policy too.
    if (this.state && usesRequestConfiguration(input.context)) {
      this.state.context.configurationPolicy = "request";
      for (
        const ticket of [
          ...this.state.tickets,
          ...(this.state.drafts ?? []),
          ...(this.state.proposals ?? []),
          ...(this.state.pending ?? []),
        ]
      ) ticket.context.configurationPolicy = "request";
    }
  }
  /** A sport instruction is effective throughout the turn, before any model patch.
   * Persisted working constraints win over the two-sport preference catalogue. */
  private constrainedSports() {
    return this.requestSports ??
      this.state?.conversation?.workingIntent.sports ?? null;
  }
  private scope(
    date: string,
    sports: Sport[],
    view: string,
    radarKind: string,
  ) {
    return { date, sports: [...sports].sort() as Sport[], view, radarKind };
  }
  private assertSports(
    date: string,
    sports: Sport[],
    view: string,
    radarKind: string,
    referenceSports?: Sport[],
  ) {
    const expected = this.requestSports ?? referenceSports ??
      this.constrainedSports();
    if (expected && !sameSports(expected, sports)) {
      throw new CompositionContractError({
        code: "sport_scope_mismatch",
        expected: this.scope(date, expected, view, radarKind),
        received: this.scope(date, sports, view, radarKind),
        queryId: null,
        dossierKeys: [],
        compatibleQueryIds: [...this.queries.values()].filter((q) =>
          sameSports(q.sports, expected)
        ).map((q) => q.id),
        repair:
          "Conserver le sport demandé. Un changement de discipline nécessite une demande explicite, pas l’élargissement aux préférences enregistrées.",
      });
    }
  }
  resolveIntent(plan: ConversationPlan, binding?: ReadQuery) {
    let normalized = plan;
    const reference = plan.intent.referenceTicketId
      ? [
        ...(this.state?.tickets ?? []),
        ...(this.state?.drafts ?? []),
        ...(this.state?.pending ?? []),
      ].find((t) => t.id === plan.intent.referenceTicketId)
      : undefined;
    const sports = this.requestSports ?? reference?.constraints?.sports ??
      this.constrainedSports() ??
      (!plan.changedFields.includes("sports") && binding &&
          sameSports(binding.sports, plan.intent.sports)
        ? binding.sports
        : null);
    if (sports) {
      if (plan.changedFields.includes("sports")) {
        this.assertSports(
          plan.intent.date,
          plan.intent.sports,
          plan.intent.view ?? "profile",
          plan.intent.radarKind ?? "teams",
          reference?.constraints?.sports,
        );
      }
      // This normalization repairs a missing sports patch only. Dates, markets,
      // stakes, counts and explicit ticket references keep their patch semantics.
      const resolved = resolvePlan(
        plan,
        this.state,
        this.input.context,
        this.input.date,
      );
      normalized = {
        ...plan,
        intent: { ...plan.intent, sports },
        changedFields: sameSports(resolved.sports, sports)
          ? plan.changedFields
          : [...new Set([...plan.changedFields, "sports"])],
      };
    }
    const intent = resolvePlan(
      normalized,
      this.state,
      this.input.context,
      this.input.date,
    );
    return intent;
  }
  activeIntent() {
    const intent = workingIntent(
      this.state,
      this.input.context,
      this.input.date,
    );
    return { ...intent, sports: this.constrainedSports() ?? intent.sports };
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
    view: "profile" | "radar" | "all" | "shortlist",
    radarKind: "teams" | "players",
    referenceSports?: Sport[],
  ) {
    this.validDay(date);
    this.assertSports(date, sports, view, radarKind, referenceSports);
    if (view === "shortlist") {
      return this.queryShortlist(sports, referenceSports);
    }
    if (
      !sports.length || sports.length > 2 ||
      new Set(sports).size !== sports.length ||
      sports.some((s) => !["football", "hockey"].includes(s)) ||
      !["profile", "radar", "all", "shortlist"].includes(view) ||
      !["teams", "players"].includes(radarKind)
    ) throw new Error("Périmètre de lecture invalide.");
    const key = JSON.stringify([date, [...sports].sort(), view, radarKind]);
    if (!this.requests.has(key)) {
      if (this.requests.size >= (this.input.context.shortlist ? 32 : 8)) {
        throw new Error(
          "Trop de journées consultées dans un seul échange ; poursuivez la comparaison dans le message suivant.",
        );
      }
      this.requests.set(key, this.loadQuery(date, sports, view, radarKind));
    }
    return await this.requests.get(key)!;
  }
  private async queryShortlist(sports: Sport[], referenceSports?: Sport[]) {
    this.assertSports(
      this.input.date,
      sports,
      "shortlist",
      "teams",
      referenceSports,
    );
    const scope = this.input.context.shortlist;
    if (!scope) {
      throw new Error("Aucune sélection Shortlist liée à cette conversation.");
    }
    if (
      !sports.length ||
      sports.some((s) => !["football", "hockey"].includes(s)) ||
      new Set(sports).size !== sports.length
    ) throw new Error("Sports Shortlist invalides.");
    if (Date.parse(scope.expiresAt) <= this.input.now.getTime()) {
      throw new Error("La Shortlist a expiré.");
    }
    const cacheKey = JSON.stringify([
      "shortlist",
      scope.sessionId,
      scope.revision,
      [...sports].sort(),
    ]);
    if (!this.requests.has(cacheKey)) {
      this.requests.set(cacheKey, this.loadShortlistQuery(scope, sports));
    }
    return await this.requests.get(cacheKey)!;
  }
  private async loadShortlistQuery(
    scope: ShortlistScope,
    sports: Sport[],
  ): Promise<ReadQuery> {
    const groups = shortlistGroups(scope, sports), parts: ReadQuery[] = [];
    for (const group of groups) {
      this.validDay(group.date);
      const part = await this.loadQuery(
        group.date,
        group.sports,
        "shortlist",
        "teams",
      );
      parts.push(part);
    }
    const allowed = new Set(groups.flatMap((g) => g.keys));
    const matches = parts.flatMap((p) => p.matches).filter((m) =>
      allowed.has(m.key)
    );
    const missing = [...allowed].filter((key) =>
      !matches.some((m) => m.key === key)
    ).map((key) => `Publication indisponible pour ${key}`);
    const contexts = {
      ...this.input.context,
      view: "shortlist" as const,
      scope: "discovery" as const,
    };
    const query: ReadQuery = {
      id: `q${this.queries.size + 1}`,
      date: this.input.date,
      context: contexts,
      sports,
      sources: mergeShortlistSources(parts.flatMap((p) => p.sources)),
      matches,
      catalog: {
        candidates: parts.flatMap((p) => p.catalog.candidates).filter((c) =>
          allowed.has(matchKey(c.sport, c.matchId))
        ),
        matches: parts.flatMap((p) => p.catalog.matches ?? []).filter((m) =>
          allowed.has(matchKey(m.sport, m.id))
        ),
        signals: parts.flatMap((p) => p.catalog.matches ?? []).filter((m) =>
          allowed.has(matchKey(m.sport, m.id))
        ).flatMap((m) => m.evidence),
        sources: [...new Set(parts.flatMap((p) => p.catalog.sources))],
        matchCount: matches.length,
        radarCount: 0,
        missing: [
          ...new Set([...missing, ...parts.flatMap((p) => p.catalog.missing)]),
        ],
      },
    };
    this.queries.set(query.id, query);
    return query;
  }
  private async loadQuery(
    date: string,
    sports: Sport[],
    view: "profile" | "radar" | "all" | "shortlist",
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
        view === "profile"
          ? "Pour moi"
          : view === "radar"
          ? "Radar"
          : view === "shortlist"
          ? "Shortlist"
          : "Tous"
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
    const candidateCounts = new Map<string, number>();
    const admissible = analysisCandidates(
      catalog,
      { marketIds: [] },
      this.input.now,
    );
    for (const candidate of admissible) {
      const key = matchKey(candidate.sport, candidate.matchId);
      candidateCounts.set(key, (candidateCounts.get(key) ?? 0) + 1);
    }
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
        if (view === "shortlist" && !context.shortlist?.keys.includes(key)) {
          continue;
        }
        if (view !== "all" && view !== "shortlist" && !known.has(key)) continue;
        seen.add(key);
        const match = {
          key,
          id,
          sport: source.sport,
          competition: String(
            native
              ? raw.competitionName ?? raw.competitionId
              : obj(raw.league).name,
          ),
          competitionId: String(
            native ? raw.competitionId : obj(raw.league).id,
          ),
          season: String(
            native ? raw.season ?? "" : obj(raw.league).season ?? "",
          ),
          homeLogo: String(obj(teams.home).logo ?? ""),
          awayLogo: String(obj(teams.away).logo ?? ""),
          home: String(obj(teams.home).name),
          away: String(obj(teams.away).name),
          kickoff,
          status: String(native ? raw.status : obj(fixture.status).short),
          sourceId: source.id,
          capturedAt: source.capturedAt,
        };
        matches.push({
          ...match,
          marketAvailability: marketAvailability(
            match,
            known.get(key)?.quoteAvailability,
            candidateCounts.get(key) ?? 0,
            this.input.now,
          ),
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
  private async evolveExploration(
    previous: DayEvaluation,
    mode: "resume" | "refresh",
  ) {
    if (!this.evaluator || this.evaluations.size >= 2) {
      throw new Error("Budget de versions atteint pour cet échange.");
    }
    const snapshot = requireSnapshot(previous);
    const current = await this.refreshedQuery(previous);
    const freshSheets = prepareMatchSheets(
      current,
      this.input.now,
      previous.exploration!.criterion,
    );
    const changes = changedSheets(previous, freshSheets);
    if (
      mode === "resume" &&
      (changes.changedKeys.length || changes.addedKeys.length ||
        changes.removedKeys.length)
    ) {
      return {
        conflict: true,
        evaluationId: previous.id,
        ...changes,
        noEvaluation: true,
        limitation:
          "Les publications ont changé. La préparation initiale reste intacte ; demandez une réévaluation explicite.",
      };
    }
    const q = mode === "resume"
      ? frozenQuery(previous, current.id, this.input.now)
      : current;
    this.queries.set(q.id, q);
    const sheets = mode === "resume"
      ? structuredClone(snapshot.sheets)
      : freshSheets;
    this.sheets.set(q.id, sheets);
    this.explorationBudget ??= new ExplorationBudget(
      this.evaluator.explorationBudget,
      this.clock,
      this.startedAt,
    );
    const rows = mode === "resume"
      ? structuredClone(previous.rows)
      : reusableRows(previous, freshSheets);
    const report = await evaluateMatches({
      id: crypto.randomUUID(),
      query: q,
      criteria: previous.criteria,
      exploration: previous.exploration!.criterion,
      now: this.input.now,
      deadline: this.evaluator.deadline,
      budget: this.explorationBudget,
      preparedSheets: sheets,
      reusedRows: rows,
      snapshotAsOf: mode === "resume" ? snapshot.asOf : undefined,
      version: {
        rootId: previous.version?.rootId ?? previous.id,
        parentId: previous.id,
        mode,
        ...changes,
        reusedKeys: rows.map((r) => r.key),
        previousSelectedKeys: [...previous.exploration!.selectedKeys],
      },
      onCheckpoint: this.evaluator.onEvaluation,
      onProgress: (n, total) =>
        this.progress(
          "evaluate",
          `${n} / ${total} rencontres évaluées · ${rows.length} résultats réutilisés`,
        ),
    }, this.evaluator);
    report.version = {
      rootId: previous.version?.rootId ?? previous.id,
      parentId: previous.id,
      mode,
      ...changes,
      reusedKeys: rows.map((r) => r.key),
      previousSelectedKeys: [...previous.exploration!.selectedKeys],
    };
    this.explorationBaseCalls ??= report.batches;
    this.evaluations.set(report.id, report);
    for (const row of report.rows) this.detailsRead.add(`${q.id}:${row.key}`);
    await this.evaluator.onEvaluation?.(report);
    return evaluationOverview(report, q);
  }
  private async archivedExploration(id: string) {
    if (id !== "latest" && !/^[0-9a-f-]{36}$/i.test(id)) {
      throw new Error("Référence d’exploration invalide.");
    }
    const report =
      (id === "latest"
        ? [...this.evaluations.values()].at(-1)
        : this.evaluations.get(id)) ?? await this.port.evaluation?.(id);
    if (!report) {
      throw new Error("Préparation inaccessible dans cette session.");
    }
    return report;
  }
  private async refreshedQuery(previous: DayEvaluation) {
    const snapshot = requireSnapshot(previous);
    const context = structuredClone(snapshot.context);
    const fixedMembership = ["radar", "shortlist"].includes(context.view ?? "");
    const other = new ConversationReader({
      ...this.input,
      date: previous.scope.date,
      state: null,
      context: fixedMembership
        ? { ...context, view: "all", shortlist: undefined, radar: undefined }
        : context,
    }, this.port);
    let current: ReadQuery;
    if (!fixedMembership) {
      current = await other.query(
        previous.scope.date,
        previous.scope.sports as Sport[],
        context.view ?? "profile",
        context.radarKind ?? "teams",
      );
    } else {
      // Archived preparation membership is independent of a later Shortlist
      // expiry or a new Radar ranking. Refresh only those owned fixture IDs,
      // using latest publications across all of their original dates.
      const allowed = new Set(snapshot.sheets.map((s) => s.key));
      const groups = new Map<string, Sport[]>();
      for (const sheet of snapshot.sheets) {
        const day = calendarDay(sheet.match.kickoff, context.timezone);
        const sports = groups.get(day) ?? [];
        if (!sports.includes(sheet.match.sport)) sports.push(sheet.match.sport);
        groups.set(day, sports);
      }
      const parts: ReadQuery[] = [];
      for (const [day, sports] of groups) {
        const fresh = await other.query(
          day,
          sports,
          "all",
          context.radarKind ?? "teams",
        );
        const scoped = structuredClone(context);
        if (scoped.view === "radar") {
          for (const sport of sports) {
            const scope = scoped.radar?.[sport],
              pool = fresh.sources.filter((s) => s.sport === sport);
            if (scope && pool.length) {
              scope.sourceIds = pool.map((s) => s.id);
              scope.capturedAt = pool.map((s) => s.capturedAt).sort().at(-1)!;
            }
          }
        }
        parts.push({
          ...fresh,
          context: scoped,
          matches: fresh.matches.filter((m) => allowed.has(m.key)),
          catalog: buildCatalog(fresh.sources, scoped, day, this.input.now, {
            includePastAndLive: true,
          }),
        });
      }
      const matches = parts.flatMap((p) => p.matches);
      const facts = parts.flatMap((p) => p.catalog.matches ?? []).filter((m) =>
        allowed.has(matchKey(m.sport, m.id))
      );
      current = {
        id: "refresh",
        date: previous.scope.date,
        context,
        sports: previous.scope.sports as Sport[],
        sources: mergeShortlistSources(parts.flatMap((p) => p.sources)),
        matches,
        catalog: {
          candidates: [],
          matches: facts,
          signals: facts.flatMap((m) => m.evidence),
          sources: [...new Set(parts.flatMap((p) => p.catalog.sources))],
          matchCount: matches.length,
          radarCount: context.view === "radar" ? matches.length : 0,
          missing: [...allowed].filter((key) =>
            !matches.some((m) => m.key === key)
          ).map((key) => `Publication indisponible pour ${key}`),
        },
      };
    }
    const q = { ...current, id: `q${this.queries.size + 1}` };
    this.queries.set(q.id, q);
    return q;
  }
  private details(q: ReadQuery, key: string) {
    const match = q.matches.find((m) => m.key === key);
    if (!match) throw new Error("Rencontre extérieure au périmètre consulté.");
    this.detailsRead.add(`${q.id}:${key}`);
    return {
      ...match,
      publishedQuotes: match.sport === "football"
        ? q.sources.filter((s) => s.id === match.sourceId).flatMap((s) =>
          footballPublishedQuotes(obj(s.payload.raw).odds, match.id)
        )
        : rows(q.sources.find((s) => s.id === match.sourceId)?.payload.items)
          .filter((f) => String(f.id) === match.id).flatMap((f) =>
            rows(f.quotes)
          ),
      evidence: (this.matchSheets(q).find((s) => s.key === key)?.facts ?? [])
        .map(modelEvidence),
      candidates: analysisCandidates(
        q.catalog,
        { ...this.input.state?.intent, marketIds: [] } as Intent,
        this.input.now,
      )
        .filter((c) => matchKey(c.sport, c.matchId) === key)
        .map((c) => modelCandidate(c, this.input.now)),
    };
  }
  async resolve(plan: ConversationPlan) {
    // Bind a chosen set only to a verified query with the declared scope. Do not
    // infer a sport from the chosen match IDs (a subset of a multisport ticket
    // can legitimately contain a single sport).
    const bindings = [...this.queries.values()].filter((q) =>
      q.date === plan.intent.date && sameSports(q.sports, plan.intent.sports) &&
      q.context.view === plan.intent.view &&
      (plan.intent.radarKind === "current" ||
        q.context.radarKind === plan.intent.radarKind) &&
      plan.focusMode === "choose" && plan.focusKeys.every((key) =>
        q.matches.some((m) =>
          m.key === key
        ) && this.detailsRead.has(`${q.id}:${key}`)
      )
    );
    const intent = this.resolveIntent(
      plan,
      bindings.length === 1 ? bindings[0] : undefined,
    );
    const context = analysisContext(this.input.context, intent);
    const query = await this.query(
      intent.date,
      intent.sports,
      context.view ?? "profile",
      context.radarKind ?? "teams",
      intent.referenceTicketId ? intent.sports : undefined,
    );
    if (plan.focusMode === "choose") {
      intent.fixtureFocus = plan.focusKeys.map((key) => {
        const match = query.matches.find((m) => m.key === key);
        if (match && !this.detailsRead.has(`${query.id}:${key}`)) {
          const compatible = [...this.queries.values()].find((q) =>
            q.date === query.date && q.context.view === query.context.view &&
            q.context.radarKind === query.context.radarKind &&
            JSON.stringify(q.context) === JSON.stringify(query.context) &&
            this.detailsRead.has(`${q.id}:${key}`) && q.matches.some((m) =>
              m.key === key && m.sourceId === match.sourceId &&
              m.capturedAt === match.capturedAt && m.kickoff === match.kickoff
            )
          );
          if (compatible) this.detailsRead.add(`${query.id}:${key}`);
        }
        if (!match || !this.detailsRead.has(`${query.id}:${key}`)) {
          throw new CompositionContractError({
            code: "composition_details_missing",
            expected: this.scope(
              query.date,
              query.sports,
              context.view ?? "profile",
              context.radarKind ?? "teams",
            ),
            received: this.scope(
              plan.intent.date,
              plan.intent.sports,
              plan.intent.view ?? "profile",
              plan.intent.radarKind ?? "teams",
            ),
            queryId: query.id,
            dossierKeys: plan.focusKeys.filter((k) =>
              !this.detailsRead.has(`${query.id}:${k}`)
            ),
            compatibleQueryIds: [...this.queries.values()].filter((q) =>
              plan.focusKeys.some((k) => this.detailsRead.has(`${q.id}:${k}`))
            ).map((q) => q.id),
            repair:
              "Lire uniquement les dossiers manquants avec read_matches et le queryId indiqué. Un autre périmètre ou une autre version ne remplace pas ces preuves.",
          });
        }
        return {
          sport: match.sport,
          matchId: businessId(match.sport, match.id),
          match: `${match.home} — ${match.away}`,
        };
      });
      intent.preserveFixtures = focusFitsTargets(
        intent,
        intent.fixtureFocus.length,
      );
    }
    return { intent, context, query };
  }
  async execute(name: string, raw: unknown): Promise<unknown> {
    if (++this.reads > 32) {
      throw new Error("Limite de consultations atteinte pour cet échange.");
    }
    const args = obj(raw);
    switch (name) {
      case "read_shortlist": {
        exact(args, []);
        const scope = this.input.context.shortlist;
        if (!scope) {
          return {
            queryId: null,
            items: [],
            limitation: "Aucune sélection Shortlist liée à cette conversation.",
          };
        }
        const q = await this.queryShortlist([
          ...new Set(
            scope.items.map((i) => i.sport).filter((s) =>
              !this.constrainedSports() || this.constrainedSports()!.includes(s)
            ),
          ),
        ]);
        return {
          queryId: q.id,
          sessionId: scope.sessionId,
          revision: scope.revision,
          expiresAt: scope.expiresAt,
          expected: scope.keys.length,
          resolved: q.matches.length,
          matches: q.matches,
          missing: q.catalog.missing,
          semantics:
            "Références de préparation, données actualisées ; aucune écriture.",
        };
      }
      case "read_profile":
        exact(args, []);
        return {
          preferences: structuredClone(this.input.context.preferences),
          budget: usesRequestConfiguration(this.input.context)
            ? null
            : this.input.context.budget,
          configurationPolicy: this.input.context.configurationPolicy ??
            "profile",
          savedBudgetHint: this.input.context.budget,
          timezone: this.input.context.timezone,
          origin: this.input.context.origin,
          semantics: usesRequestConfiguration(this.input.context)
            ? "Préférences enregistrées en lecture seule. Mises, marchés et nombres de matchs viennent de la demande ; aucun plafond de mise du profil ne les bloque. Pour moi et Radar gardent leur périmètre de rencontres."
            : "Configuration active transmise par l’application ; lecture seule, jamais modifiée par Hector.",
        };
      case "evaluate_matches": {
        const extended = "observationCount" in args;
        exact(args, [
          "queryId",
          "criteria",
          "matchKeys",
          ...(extended
            ? ["observationCount", "useProfileReadings", "formScope"]
            : []),
        ]);
        const q = this.getQuery(args.queryId);
        if (
          extended && args.observationCount != null &&
          typeof args.observationCount !== "number"
        ) {
          throw new Error("Nombre d’observations invalide.");
        }
        if (
          extended && args.observationCount === null &&
          (args.useProfileReadings !== null || args.formScope !== null)
        ) {
          throw new Error("Paramètres d’exploration sans nombre demandé.");
        }
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
        const previous = [...this.evaluations.values()].findLast((r) =>
          r.queryId === q.id && r.criteria === args.criteria &&
          (args.observationCount != null
            ? r.exploration?.criterion.observationCount ===
                args.observationCount &&
              r.exploration.criterion.useProfileReadings ===
                (args.useProfileReadings ?? false) &&
              r.exploration.criterion.formScope ===
                (args.formScope ?? "domestic_championship")
            : !r.exploration) &&
          r.expected === query.matches.length && [
            ...r.rows.map((r) => r.key),
            ...r.failed.flatMap((f) => f.keys),
          ]
            .every((key) => query.matches.some((m) => m.key === key))
        );
        if (previous) return evaluationOverview(previous, q);
        if (this.evaluations.size >= 2) {
          throw new Error(
            "Deux évaluations ont déjà été réalisées dans cet échange ; poursuivez au message suivant.",
          );
        }
        const criterion = args.observationCount != null
          ? explorationCriterion({
            request: this.input.message,
            criteria: String(args.criteria),
            query,
            observationCount: Number(args.observationCount),
            useProfileReadings: args.useProfileReadings == null
              ? false
              : args.useProfileReadings as boolean,
            formScope: args.formScope == null
              ? "domestic_championship"
              : args.formScope as "domestic_championship" | "competition",
          })
          : undefined;
        if (criterion) {
          this.explorationBudget ??= new ExplorationBudget(
            this.evaluator.explorationBudget,
            this.clock,
            this.startedAt,
          );
          this.sheets.set(
            q.id,
            prepareMatchSheets(q, this.input.now, criterion),
          );
        }
        const cachedReport = await this.port.evaluation?.("latest").catch(() =>
          null
        );
        const report = await evaluateMatches({
          id: crypto.randomUUID(),
          query,
          criteria: args.criteria.trim(),
          cachedReports: [
            ...this.evaluations.values(),
            ...(cachedReport ? [cachedReport] : []),
          ],
          now: this.input.now,
          deadline: this.evaluator.deadline,
          ...(criterion ? { exploration: criterion } : {}),
          ...(this.explorationBudget
            ? {
              budget: this.explorationBudget,
              ...(this.explorationBaseCalls !== null
                ? {
                  batchCallLimit: this.explorationBaseCalls +
                    this.explorationBudget.config.extraBatchCalls,
                }
                : {}),
            }
            : {}),
          onCheckpoint: criterion ? this.evaluator.onEvaluation : undefined,
          onProgress: (n, total) =>
            this.progress(
              "evaluate",
              `${n} / ${total} rencontres évaluées selon votre critère`,
            ),
        }, this.evaluator);
        if (criterion) this.explorationBaseCalls ??= report.batches;
        this.evaluations.set(report.id, report);
        for (const row of report.rows) {
          this.detailsRead.add(`${q.id}:${row.key}`);
        }
        await this.evaluator.onEvaluation?.(report);
        return evaluationOverview(report, q);
      }
      case "continue_match_evaluation": {
        exact(args, ["evaluationId"]);
        const previous = await this.archivedExploration(
          String(args.evaluationId),
        );
        if (previous.exploration && previous.snapshot) {
          return await this.evolveExploration(previous, "resume");
        }
        if (!previous || !this.evaluator) {
          throw new Error("Évaluation inconnue dans cet échange.");
        }
        const q = this.getQuery(previous.queryId);
        if (previous.complete) return evaluationOverview(previous, q);
        if (this.evaluations.size >= 2) {
          throw new Error(
            "Limite de deux évaluations atteinte dans cet échange.",
          );
        }
        const missing = new Set(previous.failed.flatMap((f) => f.keys));
        const retryQuery = {
          ...q,
          matches: q.matches.filter((m) => missing.has(m.key)),
        };
        if (!missing.size || retryQuery.matches.length !== missing.size) {
          throw new Error("Périmètre de reprise invalide.");
        }
        const retry = await evaluateMatches({
          id: crypto.randomUUID(),
          query: retryQuery,
          criteria: previous.criteria,
          now: this.input.now,
          deadline: this.evaluator.deadline,
          ...(previous.exploration
            ? {
              exploration: previous.exploration.criterion,
              budget: this.explorationBudget,
              batchCallLimit: (this.explorationBaseCalls ?? 0) +
                (this.explorationBudget?.config.extraBatchCalls ?? 0),
            }
            : {}),
          onProgress: (n) =>
            this.progress(
              "evaluate",
              `${
                previous.evaluated + n
              } / ${previous.expected} rencontres évaluées selon votre critère`,
            ),
        }, this.evaluator);
        const completed = new Map(
          [...previous.rows, ...retry.rows].map((r) => [r.key, r]),
        );
        const report: DayEvaluation = {
          ...retry,
          scope: previous.scope,
          expected: previous.expected,
          prepared: previous.prepared,
          evaluated: completed.size,
          complete: completed.size === previous.expected &&
            !retry.failed.length,
          rows: q.matches.flatMap((m) =>
            completed.has(m.key) ? [completed.get(m.key)!] : []
          ),
          reused: (previous.reused ?? 0) + (retry.reused ?? 0),
          cache: retry.cache && previous.cache
            ? {
              createdAt: retry.cache.createdAt,
              fingerprints: {
                ...previous.cache.fingerprints,
                ...retry.cache.fingerprints,
              },
              evaluatedAt: {
                ...Object.fromEntries(previous.rows.map((r) => [
                  r.key,
                  previous.cache!.evaluatedAt?.[r.key] ??
                    previous.cache!.createdAt,
                ])),
                ...retry.cache.evaluatedAt,
              },
            }
            : retry.cache,
          elapsedMs: previous.elapsedMs + retry.elapsedMs,
          inputBytes: previous.inputBytes + retry.inputBytes,
          batches: previous.batches + retry.batches,
        };
        if (previous.exploration) {
          report.exploration = await buildExplorationReport(
            report,
            this.matchSheets(q).filter((s) =>
              previous.exploration!.manifest.some((m) => m.key === s.key)
            ),
            previous.exploration.criterion,
            this.input.now,
          );
        }
        this.evaluations.set(report.id, report);
        for (const row of report.rows) {
          this.detailsRead.add(`${q.id}:${row.key}`);
        }
        await this.evaluator.onEvaluation?.(report);
        return evaluationOverview(report, q);
      }
      case "reevaluate_exploration": {
        exact(args, ["evaluationId"]);
        return await this.evolveExploration(
          await this.archivedExploration(String(args.evaluationId)),
          "refresh",
        );
      }
      case "compare_exploration": {
        exact(args, ["evaluationId", "matchKeys"]);
        if (
          !Array.isArray(args.matchKeys) ||
          strings(args.matchKeys).length !== args.matchKeys.length
        ) throw new Error("Rencontres de comparaison invalides.");
        return compareExploration(
          await this.archivedExploration(String(args.evaluationId)),
          strings(args.matchKeys),
        );
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
        if (report.exploration) this.archiveExplorationRead = true;
        const manifestPage = report.exploration?.manifest.slice(
          p.offset,
          p.offset + p.limit,
        );
        const rowMap = new Map(report.rows.map((row) => [row.key, row]));
        const total = report.exploration?.manifest.length ?? report.rows.length;
        return {
          evaluationId: report.id,
          criteria: report.criteria,
          scope: report.scope,
          total,
          rows: manifestPage
            ? manifestPage.flatMap((m) =>
              rowMap.has(m.key) ? [rowMap.get(m.key)!] : []
            )
            : report.rows.slice(p.offset, p.offset + p.limit),
          ...(report.exploration
            ? {
              exploration: {
                criterion: report.exploration.criterion,
                coverage: report.exploration.coverage,
                selectedKeys: report.exploration.selectedKeys,
                decisions: report.exploration.decisions.slice(
                  p.offset,
                  p.offset + p.limit,
                ),
                manifest: report.exploration.manifest.slice(
                  p.offset,
                  p.offset + p.limit,
                ),
                forms: Object.fromEntries(
                  manifestPage!.map((
                    m,
                  ) => [m.key, report.exploration!.forms[m.key] ?? null]),
                ),
                evidence: Object.fromEntries(
                  report.exploration.manifest.slice(
                    p.offset,
                    p.offset + p.limit,
                  )
                    .map((
                      m,
                    ) => [m.key, report.exploration!.evidence[m.key] ?? []]),
                ),
                nextManifestOffset:
                  p.offset + p.limit < report.exploration.manifest.length
                    ? p.offset + p.limit
                    : null,
                limitations: report.exploration.limitations,
              },
              budgetUsage: report.budgetUsage,
            }
            : {}),
          nextOffset: p.offset + p.limit < total ? p.offset + p.limit : null,
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
          normalize(
            `${m.home} ${m.away} ${m.competition} ${
              m.sport === "football"
                ? competitionAliases[m.competitionId ?? ""] ?? ""
                : ""
            }`,
          ).includes(
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
        const detailCacheKey = `${q.id}:${m.key}`;
        if (
          this.explorationBudget && this.explorationDetails.has(detailCacheKey)
        ) {
          return structuredClone(this.explorationDetails.get(detailCacheKey));
        }
        const detailedReport = [...this.evaluations.values()].findLast((r) =>
          r.queryId === q.id && r.exploration
        );
        const finishDetail = (
          value: unknown,
          status:
            | "available"
            | "absent"
            | "timeout"
            | "version_mismatch"
            | "oversized"
            | "failed",
        ) => {
          if (this.explorationBudget) {
            this.explorationBudget.recordDeepening(m.key, status);
            if (detailedReport) {
              detailedReport.budgetUsage = this.explorationBudget.snapshot();
            }
            this.explorationDetails.set(detailCacheKey, structuredClone(value));
          }
          return value;
        };
        let detailFailure: "timeout" | "failed" | undefined;
        if (this.explorationBudget) {
          const report = [...this.evaluations.values()].findLast((r) =>
            r.queryId === q.id && r.exploration
          );
          const row = report?.rows.find((r) => r.key === m.key);
          const boundary = report?.rows.find((r) =>
            r.key === report.exploration?.selectedKeys.at(-1)
          );
          const comparison = /compar|confront/i.test(this.input.message);
          const reason = comparison
            ? "explicit_comparison"
            : row?.status === "mixed"
            ? "relevant_conflict"
            : row?.limitations.length
            ? "missing_decisive_fact"
            : "boundary_tie";
          const eligible = Boolean(
            this.port.matchData && row &&
              (comparison || row.status === "mixed" ||
                row.limitations.length ||
                row.fit > 0 && row.fit === boundary?.fit),
          );
          if (!this.explorationBudget.admitDeepening(m.key, reason, eligible)) {
            if (report) report.budgetUsage = this.explorationBudget.snapshot();
            return {
              match: m,
              live: null,
              data: null,
              limitation:
                "Approfondissement non justifié ou budget atteint ; les observations évaluées restent consultables.",
              budgetUsage: this.explorationBudget.snapshot(),
            };
          }
          if (report) report.budgetUsage = this.explorationBudget.snapshot();
        }
        const response = obj(
          await this.port.matchData?.(
            m.sport,
            calendarDay(m.kickoff, q.context.timezone),
            m.id,
            m.capturedAt,
            m.sourceId,
            this.explorationBudget
              ? AbortSignal.timeout(Math.max(
                1,
                Math.floor(
                  this.explorationBudget.deepeningDeadline(
                    this.evaluator!.deadline,
                  ) - this.clock(),
                ),
              ))
              : undefined,
          ).catch((error) => {
            if (this.explorationBudget) {
              detailFailure = error instanceof Error &&
                  ["TimeoutError", "AbortError"].includes(error.name)
                ? "timeout"
                : "failed";
              return null;
            }
            throw error;
          }),
        );
        const payload = obj(
            "publication" in response ? response.publication : response,
          ),
          live = response.live ?? null;
        if (!Object.keys(payload).length) {
          return finishDetail({
            match: m,
            live,
            data: null,
            limitation: detailFailure === "timeout"
              ? "Budget d’approfondissement atteint ; le classement initial est conservé."
              : "Les données détaillées de cette publication ne sont pas disponibles.",
          }, detailFailure ?? "absent");
        }
        if (
          payload.sport !== m.sport || payload.capturedAt !== m.capturedAt ||
          !rows(payload.items).some((f) => String(f.id) === m.id)
        ) {
          return finishDetail({
            match: m,
            live,
            data: null,
            limitation:
              "La version détaillée disponible diffère de la recherche ; ses données ne sont pas substituées à la publication consultée.",
          }, "version_mismatch");
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
          return finishDetail({
            match: m,
            live,
            data: null,
            limitation:
              "Détail trop volumineux ; les lectures et marchés vérifiés restent consultables.",
          }, "oversized");
        }
        return finishDetail(projection, "available");
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
        const history = this.port.sessionHistory
          ? obj(await this.port.sessionHistory(offset, limit))
          : null;
        return {
          ...(ticket
            ? (() => {
              const projected = modelTickets([ticket]);
              let bytes = 0;
              const facts = projected.facts.filter((fact) => {
                const size = JSON.stringify(fact).length;
                if (bytes + size > 20000) return false;
                bytes += size;
                return true;
              });
              return {
                ticket: projected.tickets[0],
                facts,
                unreadEvidenceIds: projected.facts.filter((f) =>
                  !facts.includes(f)
                ).map((f) => f.id),
                evidenceReadTool: "read_work_evidence",
              };
            })()
            : { ticket: null }),
          tickets: history?.tickets ?? [
            ...new Map(all.map((t) => [t.id, { id: t.id, number: t.number }]))
              .values(),
          ],
          turns:
            (history
              ? rows(history.turns)
              : turns.slice(offset, offset + limit)).map((t) => ({
                at: t.at,
                request: String(t.request).slice(0, 2000),
                response: String(t.response).slice(0, 2000),
                constraints: t.constraints,
                focus: t.focus,
                ticketIds: t.ticketIds,
              })),
          hasMore: history?.hasMore ?? offset + limit < turns.length,
          nextOffset: history?.offset ?? offset + limit,
          olderTurns: this.state?.conversation?.olderTurns ?? 0,
          messages:
            (history
              ? rows(history.messages)
              : this.state?.messages.slice(offset, offset + limit) ?? []).map((
                m,
              ) => ({
                role: m.role,
                text: String(m.text).slice(0, 2500),
                at: m.at,
                ticketIds: m.ticketIds,
                analysisRef: m.analysisRef ?? (m.analysis ? m.id : undefined),
                analysis: m.analysis
                  ? {
                    context: obj(m.analysis).context,
                    selections: rows(obj(m.analysis).selections).length,
                    observations: rows(obj(m.analysis).observations).length,
                  }
                  : undefined,
              })),
        };
      }
      case "read_analysis": {
        exact(args, ["analysisId", "offset", "limit"]);
        if (
          !/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i
            .test(String(args.analysisId))
        ) {
          throw new Error("Référence d’analyse invalide.");
        }
        const { offset, limit } = page(args, 4);
        const analysis = await this.port.archivedAnalysis?.(
          String(args.analysisId),
        );
        if (!analysis) {
          throw new Error("Cette analyse n’appartient pas à cette session.");
        }
        const selected = analysis.selections.slice(offset, offset + limit);
        return {
          context: analysis.context,
          text: analysis.text.slice(0, 3000),
          selections: selected.map((s) => ({
            ...s,
            candidate: modelCandidate(s.candidate, this.input.now),
          })),
          facts: [
            ...new Map(
              selected.flatMap((s) => s.candidate.evidence).map((
                e,
              ) => [e.id, modelEvidence(e)]),
            ).values(),
          ].map((fact) => ({
            ...fact,
            text: fact.text.slice(0, 4000),
            textComplete: fact.text.length <= 4000,
            nextTextOffset: Math.min(fact.text.length, 4000),
          })),
          observations: (analysis.observations ?? []).slice(
            offset,
            offset + limit,
          ),
          limitations: analysis.limitations,
          hasMore: offset + limit <
            Math.max(
              analysis.selections.length,
              analysis.observations?.length ?? 0,
            ),
          nextOffset: offset + limit,
          semantics:
            "Snapshot d’origine, pas de nouvelle cote ni de probabilité.",
        };
      }
      case "read_work_evidence": {
        exact(args, ["kind", "objectId", "offset", "limit", "textOffset"]);
        if (
          !["ticket", "analysis"].includes(String(args.kind)) ||
          !/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i
            .test(String(args.objectId)) ||
          !Number.isInteger(args.textOffset) || Number(args.textOffset) < 0
        ) throw new Error("Référence de preuve invalide.");
        const { offset, limit } = page(args, 4);
        const object = args.kind === "ticket"
          ? await this.port.archivedTicket?.(String(args.objectId))
          : await this.port.archivedAnalysis?.(String(args.objectId));
        if (!object) {
          throw new Error("Cet objet n’appartient pas à cette session.");
        }
        const candidates = "picks" in object
          ? object.picks
          : object.selections.map((s) => s.candidate);
        const facts = [
          ...new Map(
            candidates.flatMap((p) => p.evidence).map((
              e,
            ) => [e.id, modelEvidence(e)]),
          ).values(),
        ];
        const start = Number(args.textOffset);
        return {
          facts: facts.slice(offset, offset + limit).map((f) => ({
            ...f,
            text: f.text.slice(start, start + 4000),
            textComplete: start + 4000 >= f.text.length,
            nextTextOffset: Math.min(start + 4000, f.text.length),
          })),
          hasMore: offset + limit < facts.length,
          nextEvidenceOffset: offset + limit,
          total: facts.length,
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
          ...(context.view === "shortlist" ? { catalog: query.catalog } : {}),
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
          queryId: query.id,
          scope: this.scope(
            query.date,
            query.sports,
            context.view ?? "profile",
            context.radarKind ?? "teams",
          ),
          dossiers: plan.focusKeys.map((key) => {
            const m = query.matches.find((m) => m.key === key);
            return { key, sourceId: m?.sourceId, capturedAt: m?.capturedAt };
          }),
          intent,
          result: attached.text,
          clarification: validateIntent(intent, context, this.input.now),
          ...modelTickets(tickets),
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
