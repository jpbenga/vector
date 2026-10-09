/** The model expresses intent only. Prices, evidence and tickets are server facts. */
export type Sport = "football" | "hockey";
export type Json = Record<string, unknown>;
export const obj = (v: unknown): Json =>
  v && typeof v === "object" && !Array.isArray(v) ? v as Json : {};
export const rows = (v: unknown): Json[] => Array.isArray(v) ? v.map(obj) : [];
export const strings = (v: unknown): string[] =>
  Array.isArray(v) ? v.filter((x): x is string => typeof x === "string") : [];
export interface Preferences {
  competitions: string[];
  readings: string[];
  markets: string[];
  scenarios?: string[];
}
export interface RadarMember {
  id: string;
  teamId: string;
  rank: number;
  matchIds: string[];
}
export interface RadarScope {
  version: 1;
  mode: "teams" | "players";
  category: "club" | "national";
  capturedAt: string;
  sourceIds: string[];
  includeWomen: boolean;
  includeYouth: boolean;
  competitionId: string | null;
  teams: RadarMember[];
  players: RadarMember[];
}
export interface Context {
  origin: "profile" | "explorer";
  scope: "discovery" | "strict";
  timezone: string;
  budget: number;
  preferences: Partial<Record<Sport, Preferences>>;
  /** Read scope for this request; never changes the saved preferences. */
  view?: "profile" | "radar" | "all";
  radar?: Partial<Record<Sport, RadarScope>>;
  radarKind?: "teams" | "players";
}
export interface Target {
  stake: number | null;
  minimum: number | null;
  maximum: number | null;
  kind: "total" | "net" | "unspecified";
}
export interface Intent {
  action:
    | "generate"
    | "alternative"
    | "replace"
    | "remove"
    | "restore"
    | "explain"
    | "explore"
    | "analyze"
    | "clarify"
    | "unsupported";
  date: string;
  sports: Sport[];
  tickets: Target[];
  diversify: boolean;
  requireEachSport: boolean;
  maxSelections?: number | null;
  referenceTicketId?: string | null;
  preserveConstraints?: boolean;
  ticketIndex: number | null;
  selectionIndex: number | null;
  marketIds: string[];
  message: string;
  goalMode?: "around" | "minimum" | "range" | "unconstrained";
  preserveFixtures?: boolean;
  view?: "current" | "profile" | "radar" | "all";
  radarKind?: "current" | "teams" | "players";
}
export interface Evidence {
  id: string;
  label: string;
  family: string;
  source: "reading" | "radar" | "scenario";
  subject: string;
  sample: number;
  asOf: string;
  text: string;
  photo?: string;
  metrics?: { label: string; value: string }[];
  supportsMarket?: boolean;
  reusesReading?: boolean;
  role?: "support" | "context" | "vigilance";
  lineage?: { kind: string; matchIds: string[]; from?: string; until?: string };
}
export interface Candidate {
  id: string;
  matchId: string;
  sport: Sport;
  competitionId: string;
  competition: string;
  competitionLogo?: string;
  countryFlag?: string;
  home: string;
  away: string;
  homeLogo?: string;
  awayLogo?: string;
  teams: string[];
  kickoff: string;
  marketId: string;
  market: string;
  selection: string;
  odds: number;
  oddsAt: string;
  bookmaker: string;
  snapshotId: string;
  evidence: Evidence[];
  warnings: string[];
  discovery: boolean;
}
export interface Catalog {
  candidates: Candidate[];
  matchCount: number;
  radarCount: number;
  missing: string[];
  sources: string[];
  signals: Evidence[];
  matches?: AnalysisMatch[];
}
export interface AnalysisMatch {
  id: string;
  sport: Sport;
  competition: string;
  home: string;
  away: string;
  kickoff: string;
  evidence: Evidence[];
  quoteAvailability: "recent" | "unavailable" | "not_collected";
}
export interface Analysis {
  context: {
    date: string;
    view: string;
    sports: Sport[];
    matchCount: number;
    candidateCount: number;
    radarKind?: string;
    radarScopes?: {
      sport: Sport;
      category: string;
      capturedAt: string;
      sourceIds: string[];
      members: number;
      includeWomen: boolean;
      includeYouth: boolean;
      competitionId: string | null;
    }[];
  };
  text: string;
  selections: {
    candidate: Candidate;
    reason: string;
    vigilance: string;
    references: string[];
  }[];
  comparedMatchIds: string[];
  limitations: string[];
  summary?: string;
}
export interface Ticket {
  id: string;
  number: number;
  stake: number;
  picks: Candidate[];
  totalOdds: number;
  returnTotal: number;
  netProfit: number;
  target: Target;
  constraints?: Pick<
    Intent,
    "maxSelections" | "marketIds" | "requireEachSport" | "sports" | "goalMode"
  >;
  context: Context;
  warnings: string[];
  workshop?: {
    approach: string;
    metrics: {
      conditions: number;
      minimumSample: number;
      redundantReferences: number;
      targetDistance: number;
      largestOddsContribution: number;
    };
    notes: { code: string; text: string; refs: string[] }[];
    comparison: {
      kept: string[];
      removed: string[];
      added: string[];
      replaced: { fixture: string; before: string; after: string }[];
      sharedFixtures: number;
      sharedSelections: number;
    } | null;
    comparedTo?: {
      id: string;
      number: number;
      picks: { id: string; match: string; selection: string }[];
    };
  };
}
export interface State {
  id: string;
  revision: number;
  context: Context;
  intent: Intent | null;
  pendingIntent?: Intent | null;
  tickets: Ticket[];
  versions: Ticket[][];
  pending: Ticket[] | null;
  proposals?: Ticket[];
  messages: {
    role: "user" | "assistant";
    text: string;
    ticketIds?: string[];
    proposalIds?: string[];
    at?: string;
    analysis?: Analysis;
  }[];
  drafts?: Ticket[];
  compositions?: string[];
  saved: boolean;
  updatedAt: string;
  catalog?: Pick<
    Catalog,
    "matchCount" | "radarCount" | "missing" | "sources" | "signals"
  >;
}
export function contextFrom(value: unknown): Context {
  const c = obj(value), preferences: Context["preferences"] = {};
  for (const sport of ["football", "hockey"] as const) {
    const p = obj(obj(c.preferences)[sport]);
    if (Object.keys(p).length) {
      preferences[sport] = {
        competitions: strings(p.competitions).slice(0, 150),
        readings: strings(p.readings).slice(0, 80),
        markets: strings(p.markets).slice(0, 30),
        scenarios: strings(p.scenarios).slice(0, 30),
      };
    }
  }
  const budget = Number(c.budget);
  if (!Number.isFinite(budget) || budget < 0 || budget > 1000) {
    throw new Error("Budget invalide (0 à 1 000 €).");
  }
  const timezone = String(c.timezone || "Europe/Paris");
  try {
    new Intl.DateTimeFormat("en", { timeZone: timezone }).format();
  } catch {
    throw new Error("Fuseau horaire invalide.");
  }
  return {
    origin: c.origin === "explorer" ? "explorer" : "profile",
    scope: c.scope === "strict" ? "strict" : "discovery",
    timezone,
    budget,
    preferences,
    radar: radarScopesFrom(c.radar),
  };
}
/** Scope identifiers are user inputs, not sports statistics or market authorizations. */
export function radarScopesFrom(value: unknown): Context["radar"] {
  const scopes: NonNullable<Context["radar"]> = {};
  for (const sport of ["football", "hockey"] as const) {
    const v = obj(obj(value)[sport]);
    if (!Object.keys(v).length) continue;
    const ids = strings(v.sourceIds);
    if (
      v.version !== 1 || !["teams", "players"].includes(String(v.mode)) ||
      !["club", "national"].includes(String(v.category)) ||
      typeof v.capturedAt !== "string" ||
      !Number.isFinite(Date.parse(v.capturedAt)) ||
      !Array.isArray(v.sourceIds) || ids.length !== v.sourceIds.length ||
      ids.length > 150 ||
      ids.some((id) =>
        !/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i.test(
          id,
        )
      ) ||
      (v.competitionId != null &&
        (typeof v.competitionId !== "string" ||
          !/^\d{1,10}$/.test(v.competitionId)))
    ) {
      throw new Error("Le périmètre Radar transmis est invalide.");
    }
    const members = (key: string, count: number): RadarMember[] => {
      const list = rows(v[key]);
      if (!Array.isArray(v[key]) || list.length > 50) {
        throw new Error("Liste Radar invalide.");
      }
      const seen = new Set<string>();
      return list.map((m, i) => {
        const matchIds = strings(m.matchIds), identity = `${m.teamId}:${m.id}`;
        if (
          typeof m.id !== "string" || (sport === "hockey" && key === "players"
            ? m.id.length === 0 || m.id.length > 220 ||
              /[\s\x00-\x1f]/.test(m.id)
            : !/^\d{1,10}$/.test(m.id)) ||
          typeof m.teamId !== "string" || !/^\d{1,10}$/.test(m.teamId) ||
          m.rank !== i + 1 || seen.has(identity) ||
          !Array.isArray(m.matchIds) ||
          matchIds.length !== count || matchIds.length !== m.matchIds.length ||
          new Set(matchIds).size !== count || matchIds.some((id) =>
            !/^\d{1,12}$/.test(id)
          ) ||
          (key === "teams" && m.id !== m.teamId)
        ) throw new Error("Références Radar invalides.");
        seen.add(identity);
        return { id: m.id, teamId: m.teamId, rank: i + 1, matchIds };
      });
    };
    scopes[sport] = {
      version: 1,
      mode: v.mode as RadarScope["mode"],
      category: v.category as RadarScope["category"],
      capturedAt: v.capturedAt,
      sourceIds: [...new Set(ids)],
      includeWomen: v.includeWomen === true,
      includeYouth: v.includeYouth === true,
      competitionId: v.competitionId as string | null ?? null,
      teams: members("teams", 5),
      players: members("players", 3),
    };
  }
  return scopes;
}
export function calendarDay(instant: string | Date, timezone: string): string {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: timezone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(new Date(instant));
  return ["year", "month", "day"].map((k) =>
    parts.find((p) => p.type === k)!.value
  ).join("-");
}
/** Validate provider output again: structured output is not an authorization. */
export function intentFrom(value: unknown): Intent {
  const v = obj(value);
  const actions = [
    "generate",
    "alternative",
    "replace",
    "remove",
    "restore",
    "explain",
    "explore",
    "analyze",
    "clarify",
    "unsupported",
  ];
  const keys = [
    "action",
    "date",
    "sports",
    "tickets",
    "diversify",
    "requireEachSport",
    "ticketIndex",
    "selectionIndex",
    "marketIds",
    "message",
  ];
  const index = (x: unknown) =>
    x === null || (Number.isInteger(x) && Number(x) >= 0 && Number(x) < 30);
  if (
    !Object.keys(v).every((k) =>
      [
        ...keys,
        "maxSelections",
        "referenceTicketId",
        "preserveConstraints",
        "goalMode",
        "preserveFixtures",
        "view",
        "radarKind",
      ]
        .includes(k)
    ) ||
    !keys.every((k) => k in v) ||
    (v.goalMode !== undefined &&
      !["around", "minimum", "range", "unconstrained"].includes(
        String(v.goalMode),
      )) ||
    (v.preserveFixtures !== undefined &&
      typeof v.preserveFixtures !== "boolean") ||
    (v.view !== undefined &&
      !["current", "profile", "radar", "all"].includes(String(v.view))) ||
    (v.radarKind !== undefined &&
      !["current", "teams", "players"].includes(String(v.radarKind))) ||
    (v.maxSelections !== undefined && v.maxSelections !== null &&
      (!Number.isInteger(v.maxSelections) || Number(v.maxSelections) < 1 ||
        Number(v.maxSelections) > 6)) ||
    (v.referenceTicketId != null &&
      (typeof v.referenceTicketId !== "string" ||
        v.referenceTicketId.length > 100)) ||
    (v.preserveConstraints !== undefined &&
      typeof v.preserveConstraints !== "boolean") ||
    !actions.includes(String(v.action)) || typeof v.date !== "string" ||
    v.date.length > 10 ||
    !Array.isArray(v.sports) || v.sports.length > 2 ||
    v.sports.some((x) => !["football", "hockey"].includes(x)) ||
    !Array.isArray(v.tickets) || v.tickets.length > 4 ||
    typeof v.diversify !== "boolean" ||
    typeof v.requireEachSport !== "boolean" ||
    !index(v.ticketIndex) || !index(v.selectionIndex) ||
    !Array.isArray(v.marketIds) ||
    v.marketIds.length > 30 ||
    v.marketIds.some((x) => typeof x !== "string" || x.length > 80) ||
    typeof v.message !== "string" || v.message.length > 1000
  ) throw new Error("Intention IA invalide.");
  for (const target of v.tickets) {
    const t = obj(target);
    if (
      Object.keys(t).length !== 4 ||
      !["total", "net", "unspecified"].includes(String(t.kind)) ||
      !["stake", "minimum", "maximum"].every((k) =>
        k in t &&
        (t[k] === null || (typeof t[k] === "number" && Number.isFinite(t[k])))
      )
    ) {
      throw new Error("Intention IA invalide.");
    }
  }
  return v as unknown as Intent;
}
export function validateIntent(
  i: Intent,
  context: Context,
  now: Date,
): string | null {
  if (["clarify", "unsupported", "explain", "restore"].includes(i.action)) {
    return null;
  }
  if (
    !/^\d{4}-\d{2}-\d{2}$/.test(i.date) ||
    !Number.isFinite(Date.parse(i.date)) ||
    new Date(i.date).toISOString().slice(0, 10) !== i.date
  ) return "Précisez une date valide.";
  const today = calendarDay(now, context.timezone);
  const last = new Date(`${today}T12:00:00Z`);
  last.setUTCDate(last.getUTCDate() + 13);
  if (i.date < today || i.date > last.toISOString().slice(0, 10)) {
    return "La préparation avant match couvre aujourd’hui et les 13 jours suivants.";
  }
  if (
    !i.sports.length ||
    i.sports.some((s) => !["football", "hockey"].includes(s))
  ) return "Choisissez un sport disponible dans Lector.";
  if (!["generate", "alternative"].includes(i.action)) return null;
  if (
    i.maxSelections != null &&
    (!Number.isInteger(i.maxSelections) || i.maxSelections < 1 ||
      i.maxSelections > 6)
  ) {
    return "Choisissez entre un et six matchs maximum par composition.";
  }
  if (!i.tickets.length || i.tickets.length > 4) {
    return "Précisez entre un et quatre tickets.";
  }
  let budget = 0;
  for (const t of i.tickets) {
    if (t.stake === null || !Number.isFinite(t.stake) || t.stake <= 0) {
      return "Quelle mise souhaitez-vous prévoir pour chaque composition ?";
    }
    budget += t.stake;
    if (Math.abs(t.stake * 100 - Math.round(t.stake * 100)) > 0.000001) {
      return "Précisez une mise en euros et centimes.";
    }
    if (
      (t.minimum !== null || t.maximum !== null) && t.kind === "unspecified"
    ) {
      return "L’objectif désigne-t-il le retour total, mise comprise, ou le bénéfice net ?";
    }
    if (
      [t.minimum, t.maximum].some((v) =>
        v !== null && (!Number.isFinite(v) || v < 0)
      ) || (t.minimum !== null && t.maximum !== null && t.maximum < t.minimum)
    ) return "Précisez un intervalle de retour cohérent.";
    if (t.kind === "total" && t.maximum !== null && t.maximum <= t.stake) {
      return "Le retour total comprend la mise. Avec cette mise, l’objectif doit être supérieur à la mise pour composer un ticket. Précisez la mise ou l’objectif.";
    }
  }
  return budget > context.budget + 0.001
    ? "Les mises dépassent votre plafond. Réduisez-les ou demandez moins de compositions."
    : null;
}
