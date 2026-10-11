import type { Source } from "./catalog.ts";
import {
  calendarDay,
  type Context,
  obj,
  rows,
  type Sport,
  strings,
} from "./contracts.ts";
export interface ShortlistReference {
  sessionId: string;
  revision: number;
  keys: string[];
}
export interface ShortlistScope extends ShortlistReference {
  expiresAt: string;
  items: {
    key: string;
    sport: Sport;
    fixtureId: string;
    date: string;
    status?: string;
    available?: boolean;
  }[];
}
export function shortlistReference(raw: unknown): ShortlistReference {
  const r = obj(raw), keys = strings(r.keys);
  if (
    typeof r.sessionId !== "string" ||
    !/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i.test(
      r.sessionId,
    ) ||
    !Number.isInteger(r.revision) || Number(r.revision) < 0 ||
    !Array.isArray(r.keys) ||
    keys.length !== r.keys.length || !keys.length || keys.length > 200 ||
    new Set(keys).size !== keys.length ||
    keys.some((k) => !/^(football|hockey):[0-9]{1,12}$/.test(k))
  ) throw new Error("Sélection Shortlist invalide.");
  return { sessionId: r.sessionId, revision: Number(r.revision), keys };
}
/** The snapshot is obtained server-side for the authenticated owner, never supplied by the client/model. */
export function resolveShortlist(
  raw: unknown,
  snapshot: unknown,
  now: Date,
): ShortlistScope {
  const ref = shortlistReference(raw);
  const session = rows(obj(snapshot).sessions).find((s) =>
    s.id === ref.sessionId
  );
  if (
    !session || !Number.isFinite(Date.parse(String(session.expiresAt))) ||
    Date.parse(String(session.expiresAt)) <= now.getTime()
  ) {
    throw new Error(
      "La Shortlist a expiré. Restaurez-la avant une nouvelle préparation.",
    );
  }
  if (session.revision !== ref.revision) {
    throw new Error(
      "La Shortlist a changé sur un autre appareil. Actualisez votre préparation.",
    );
  }
  const members = rows(session.items);
  const items = ref.keys.map((key) => {
    const item = members.find((i) => i.key === key);
    if (!item) {
      throw new Error(
        "Une rencontre sélectionnée n’appartient plus à votre Shortlist.",
      );
    }
    const fixture = obj(item.fixture), kickoff = fixture.kickoff;
    const date =
      typeof kickoff === "string" && Number.isFinite(Date.parse(kickoff))
        ? calendarDay(kickoff, String(session.timezone))
        : String(item.date);
    return {
      key,
      sport: item.sport as Sport,
      fixtureId: String(item.fixtureId),
      date,
      status: typeof fixture.status === "string" ? fixture.status : undefined,
      available: item.fixture != null,
    };
  });
  return { ...ref, expiresAt: String(session.expiresAt), items };
}
export function shortlistGroups(scope: ShortlistScope, sports: Sport[]) {
  const groups = new Map<
    string,
    { date: string; sports: Sport[]; keys: string[] }
  >();
  for (const item of scope.items) {
    if (!sports.includes(item.sport)) continue;
    const group = groups.get(item.date) ??
      { date: item.date, sports: [], keys: [] };
    if (!group.sports.includes(item.sport)) group.sports.push(item.sport);
    group.keys.push(item.key);
    groups.set(item.date, group);
  }
  return [...groups.values()].sort((a, b) => a.date.localeCompare(b.date));
}
export function shortlistContext(
  context: Context,
  scope: ShortlistScope,
): Context {
  return {
    ...context,
    shortlist: scope,
    view: "shortlist",
    scope: "discovery",
    configurationPolicy: "request",
  };
}

/** Paged day slices can share a publication ID. Rejoin its factual arrays without losing another day. */
export function mergeShortlistSources(sources: Source[]): Source[] {
  const merged = new Map<string, Source>();
  const combine = (a: unknown, b: unknown): unknown => {
    if (Array.isArray(a) && Array.isArray(b)) {
      return [
        ...new Map([...a, ...b].map((v) => [JSON.stringify(v), v])).values(),
      ];
    }
    if (a && b && typeof a === "object" && typeof b === "object") {
      return Object.fromEntries(
        [...new Set([...Object.keys(obj(a)), ...Object.keys(obj(b))])].map((
          key,
        ) => [key, combine(obj(a)[key], obj(b)[key])]),
      );
    }
    return b ?? a;
  };
  for (const source of sources) {
    const key = source.sport + ":" + source.id;
    const prior = merged.get(key);
    merged.set(
      key,
      prior
        ? { ...source, payload: obj(combine(prior.payload, source.payload)) }
        : structuredClone(source),
    );
  }
  return [...merged.values()];
}

/** Keep references in persistent chat/ticket contexts; the verified server hydration is per request. */
export function compactShortlistReferences(value: unknown): void {
  if (!value || typeof value !== "object") return;
  if (Array.isArray(value)) {
    for (const entry of value) compactShortlistReferences(entry);
    return;
  }
  const record = value as Record<string, unknown>;
  if (record.shortlist && typeof record.shortlist === "object") {
    const scope = obj(record.shortlist);
    record.shortlist = {
      sessionId: scope.sessionId,
      revision: scope.revision,
      keys: scope.keys,
      expiresAt: scope.expiresAt,
    };
  }
  for (const [key, entry] of Object.entries(record)) {
    if (key !== "shortlist") compactShortlistReferences(entry);
  }
}
