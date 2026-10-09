import { type Source } from "./catalog.ts";
import {
  calendarDay,
  type Context,
  type Json,
  obj,
  rows,
  type Sport,
} from "./contracts.ts";
import { sourceQuery } from "./service.ts";

export interface PublicationRef {
  id: string;
  sport: Sport;
  capturedAt: string;
}
export interface DayMatchRef extends PublicationRef {
  key: string;
  matchId: string;
}
export interface DayManifest {
  version: 1;
  date: string;
  timezone: string;
  total: number;
  sources: PublicationRef[];
  matches: DayMatchRef[];
}
export interface DayReadCoverage {
  expected: number;
  loaded: number;
  pages: number;
  bytes: number;
  complete: boolean;
}
export interface DaySourcePort {
  manifest(parameters: Record<string, unknown>): Promise<unknown>;
  page(parameters: Record<string, unknown>): Promise<unknown>;
}
const identity = (r: PublicationRef) => `${r.sport}:${r.id}`;
const validRef = (r: Json, sports: Sport[]) =>
  sports.includes(r.sport as Sport) &&
  typeof r.id === "string" &&
  /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i.test(
    r.id,
  ) &&
  typeof r.capturedAt === "string" &&
  Number.isFinite(Date.parse(r.capturedAt));

export function daySourceParameters(
  context: Context,
  date: string,
  sports: Sport[],
) {
  return {
    ...sourceQuery(context, date, sports),
    ...(context.view === "all" ? { p_readings: null, p_scenarios: [] } : {}),
    ...(context.view === "radar"
      ? { p_competitions: null, p_readings: null, p_scenarios: [] }
      : {}),
    p_radar: context.view === "radar"
      ? Object.fromEntries(
        Object.entries(context.radar ?? {}).filter(([sport]) =>
          sports.includes(sport as Sport)
        ),
      )
      : null,
  };
}

function manifestFrom(
  value: unknown,
  date: string,
  timezone: string,
  sports: Sport[],
): DayManifest {
  const m = obj(value);
  if (
    m.version !== 1 || m.date !== date || m.timezone !== timezone ||
    !Number.isInteger(m.total) || Number(m.total) < 0 ||
    Number(m.total) > 3000 || !Array.isArray(m.matches) ||
    !Array.isArray(m.sources) || m.sources.length > 150 ||
    m.matches.length !== m.total ||
    m.sources.some((s) => !validRef(obj(s), sports))
  ) throw new Error("Recensement de la journée invalide ou incomplet.");
  const publications = new Map(
    rows(m.sources).map((s) => [identity(s as unknown as PublicationRef), s]),
  );
  const keys = new Set<string>();
  for (const ref of rows(m.matches)) {
    const source = publications.get(identity(ref as unknown as PublicationRef));
    if (
      !validRef(ref, sports) || !/^\d{1,12}$/.test(String(ref.matchId)) ||
      ref.key !== `${ref.sport}:${ref.matchId}` || keys.has(String(ref.key)) ||
      !source || Date.parse(String(source.capturedAt)) !==
        Date.parse(String(ref.capturedAt))
    ) throw new Error("Identités de la journée incohérentes.");
    keys.add(String(ref.key));
  }
  if (publications.size !== m.sources.length) {
    throw new Error("Publications de la journée dupliquées.");
  }
  return m as unknown as DayManifest;
}

function union(left: unknown, right: unknown, key: (v: Json) => string) {
  const all = new Map(rows(left).map((r) => [key(r), r]));
  for (const r of rows(right)) all.set(key(r), r);
  return [...all.values()];
}

/** Reassemble only the projected facts; raw collector envelopes never travel here. */
function mergeSource(previous: Source | undefined, next: Source): Source {
  if (!previous) return next;
  const a = previous.payload, b = next.payload;
  if (next.sport === "football") {
    const ar = obj(a.raw), br = obj(b.raw);
    return {
      ...previous,
      payload: {
        raw: {
          fixtures: union(
            ar.fixtures,
            br.fixtures,
            (r) => String(obj(r.fixture).id),
          ),
          odds: union(
            ar.odds,
            br.odds,
            (r) => `${obj(r.fixture).id}:${r.update}`,
          ),
          player_form_radar: union(
            ar.player_form_radar,
            br.player_form_radar,
            (r) => `${obj(r.team).id}:${obj(r.player).id}`,
          ),
          recent_league_matches: union(
            ar.recent_league_matches,
            br.recent_league_matches,
            (r) => `${obj(r.league).id}:${obj(r.team).id}`,
          ),
        },
        computed: {
          fixtures: union(
            obj(a.computed).fixtures,
            obj(b.computed).fixtures,
            (r) => String(r.fixture_id),
          ),
        },
      },
    };
  }
  const competitions = new Map(
    rows(a.competitions).map((c) => [String(c.id), c]),
  );
  for (const c of rows(b.competitions)) {
    const old = competitions.get(String(c.id));
    competitions.set(String(c.id), {
      ...c,
      tables: rows(c.tables).map((table, i) => ({
        ...table,
        rows: union(
          rows(old?.tables)[i]?.rows,
          table.rows,
          (r) => String(obj(r.team).id),
        ),
      })),
    });
  }
  return {
    ...previous,
    payload: {
      ...a,
      items: union(a.items, b.items, (r) => String(r.id)),
      playerRadar: {
        profiles: union(
          obj(a.playerRadar).profiles,
          obj(b.playerRadar).profiles,
          (r) => `${r.competitionId}:${obj(r.team).id}:${r.id}`,
        ),
      },
      competitions: [...competitions.values()],
    },
  };
}

export async function loadDaySources(
  context: Context,
  date: string,
  sports: Sport[],
  port: DaySourcePort,
  progress: (coverage: DayReadCoverage) => Promise<void> = async () => {},
) {
  const parameters = daySourceParameters(context, date, sports);
  const manifest = manifestFrom(
    await port.manifest(parameters),
    date,
    context.timezone,
    sports,
  );
  const sources = new Map<string, Source>();
  const coverage: DayReadCoverage = {
    expected: manifest.total,
    loaded: 0,
    pages: 0,
    bytes: 0,
    complete: false,
  };
  await progress({ ...coverage });
  // These are transport limits. They never become a silent top-N filter.
  let pageSize = 50;
  const pageBytes = 1500000, totalBytes = 32 * 1024 * 1024;
  for (let offset = 0; offset < manifest.total;) {
    const requested = manifest.matches.slice(offset, offset + pageSize);
    const requestedKeys = new Set(requested.map((r) => r.key));
    const publications = context.view === "radar"
      ? manifest.sources
      : manifest.sources.filter((s) =>
        requested.some((r) => identity(r) === identity(s))
      );
    const result = obj(
      await port.page({
        p_date: date,
        p_timezone: context.timezone,
        p_sources: publications,
        p_matches: requested,
      }),
    );
    const bytes = new TextEncoder().encode(JSON.stringify(result)).length;
    coverage.bytes += bytes;
    if (
      coverage.bytes > totalBytes ||
      (bytes > pageBytes && requested.length === 1)
    ) {
      throw new Error(
        "La lecture complète dépasse le budget de transport ; aucune analyse exhaustive n’est annoncée.",
      );
    }
    if (bytes > pageBytes) {
      pageSize = Math.max(1, Math.floor(requested.length / 2));
      continue;
    }
    if (!Array.isArray(result.sources)) {
      throw new Error("Page de rencontres invalide.");
    }
    const primary = new Set<string>();
    for (const raw of rows(result.sources)) {
      const publication = publications.find((p) =>
        identity(p) === identity(raw as unknown as PublicationRef)
      );
      if (
        !publication ||
        Date.parse(String(raw.capturedAt)) !==
          Date.parse(publication.capturedAt)
      ) {
        throw new Error(
          "La publication a changé pendant la lecture de la journée.",
        );
      }
      const source = raw as unknown as Source;
      const items = rows(
        source.sport === "hockey"
          ? source.payload?.items
          : obj(source.payload?.raw).fixtures,
      );
      for (const item of items) {
        const id = String(
          source.sport === "hockey" ? item.id : obj(item.fixture).id,
        );
        const key = `${source.sport}:${id}`;
        const kickoff = String(
          source.sport === "hockey" ? item.startsAt : obj(item.fixture).date,
        );
        if (
          !Number.isFinite(Date.parse(kickoff)) ||
          calendarDay(kickoff, context.timezone) !== date
        ) {
          throw new Error("Rencontre extérieure à la journée demandée.");
        }
        if (!requestedKeys.has(key)) {
          throw new Error("Rencontre extérieure à la page demandée.");
        }
        if (
          requested.some((r) =>
            r.key === key && identity(r) === identity(source)
          )
        ) {
          if (primary.has(key)) {
            throw new Error("Rencontre dupliquée dans la page demandée.");
          }
          primary.add(key);
        }
      }
      sources.set(
        identity(source),
        mergeSource(sources.get(identity(source)), source),
      );
    }
    if (primary.size !== requested.length) {
      throw new Error(
        "Lecture de journée incomplète : une rencontre ou sa publication est indisponible.",
      );
    }
    coverage.loaded += primary.size;
    coverage.pages++;
    offset += requested.length;
    await progress({ ...coverage });
  }
  coverage.complete = coverage.loaded === coverage.expected;
  await progress({ ...coverage });
  return { sources: [...sources.values()], coverage, manifest };
}
