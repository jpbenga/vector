/** Public, immutable presentation artifacts. Never accepts provider credentials. */
export type Json = Record<string, unknown>;
export type FeedSport = "football" | "hockey";
const object = (v: unknown): Json =>
  v && typeof v === "object" && !Array.isArray(v) ? v as Json : {};
const rows = (v: unknown): Json[] => Array.isArray(v) ? v.map(object) : [];
export const dayKey = (instant: string): string => {
  const date = new Date(instant);
  if (!Number.isFinite(date.getTime())) throw new Error("Invalid fixture date");
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Europe/Paris",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(date);
  return ["year", "month", "day"].map((k) =>
    parts.find((p) => p.type === k)!.value
  ).join("-");
};
// Wire catalogue mirrors the markets consumed by OddsNormalizationCatalog.
// The parity test prevents silently dropping a newly supported market.
export const footballCardMarketIds = [1, 5, 8, 12, 16, 17, 45, 80, 92];
function cardOdds(value: unknown): Json[] {
  return rows(value).map((row) => ({
    ...row,
    bookmakers: rows(row.bookmakers).map((bookmaker) => ({
      ...bookmaker,
      bets: rows(bookmaker.bets).filter((bet) =>
        footballCardMarketIds.includes(Number(bet.id))
      ),
    })).filter((bookmaker) => bookmaker.bets.length > 0),
  }));
}
export function overviewPart(sport: FeedSport, full: Json): Json {
  if (sport === "football") {
    const raw = object(full.raw);
    // Precomputed readings and scenarios remain authoritative and unchanged.
    // Tier tables and presentation histories are loaded with the detail file.
    return {
      ...full,
      raw: {
        fixtures: raw.fixtures ?? [],
        odds: cardOdds(raw.odds),
        player_form_radar: raw.player_form_radar ?? [],
        recent_league_matches: raw.recent_league_matches ?? [],
      },
      computed: {
        ...object(full.computed),
        fixtures: rows(object(full.computed).fixtures).map((f) => {
          const { tier_snapshot: _tier, ...card } = f;
          return card;
        }),
      },
    };
  }
  // Keep only the result facts used by the existing hockey reading engine.
  // Historical event logs and match events are exclusively detail data.
  return {
    ...full,
    items: rows(full.items).map((f) => {
      const { matchEvents: _events, ...card } = f;
      const h = object(card.headToHead);
      return Object.keys(h).length === 0 ? card : {
        ...card,
        headToHead: {
          ...h,
          meetings: rows(h.meetings).map((m) => ({
            ...m,
            events: [],
            eventsCollected: false,
            eventDataIssue: "Détails chargés à l’ouverture de la rencontre.",
          })),
        },
      };
    }),
  };
}
export interface DeliveryPart {
  id: string;
  scopeKey: string;
  capturedAt: string;
  asOf: string;
  windowStart: string;
  windowEnd: string;
  fullPath: string;
  overview: Json;
}
export function selectParts(
  parts: DeliveryPart[],
  day: string,
  today: string,
): DeliveryPart[] {
  const historical = day < today;
  // Midnight in Paris, including DST; do not admit a next-day reading snapshot.
  const end = Date.parse(`${day}T23:59:59.999${parisOffset(day)}`);
  const sorted = [...parts].sort((a, b) =>
    Date.parse(b.asOf) - Date.parse(a.asOf) || b.id.localeCompare(a.id)
  );
  const covered = sorted.filter((p) =>
    p.windowStart <= day && p.windowEnd >= day &&
    (!historical || Date.parse(p.asOf) <= end)
  );
  const selected = new Map<string, DeliveryPart>();
  for (const p of historical ? covered : [...covered, ...sorted]) {
    if (!selected.has(p.scopeKey)) selected.set(p.scopeKey, p);
  }
  return [...selected.values()];
}
function parisOffset(day: string): string {
  const name = new Intl.DateTimeFormat("en", {
    timeZone: "Europe/Paris",
    timeZoneName: "shortOffset",
  }).formatToParts(new Date(`${day}T12:00:00Z`)).find((p) =>
    p.type === "timeZoneName"
  )!.value;
  return name.endsWith("+2") ? "+02:00" : "+01:00";
}
export function dayOverview(
  sport: FeedSport,
  parts: DeliveryPart[],
  day: string,
): Json | null {
  if (
    !parts.length ||
    parts.every((p) => p.windowStart > day || p.windowEnd < day)
  ) return null;
  const paths: Record<string, unknown> = {};
  const first = parts[0].overview;
  if (sport === "hockey") {
    if (parts.length !== 1) {
      throw new Error("Hockey requires an atomic multi-league publication");
    }
    const items = rows(first.items).filter((f) => f.calendarDate === day);
    for (const f of items) {
      paths[String(f.id)] =
        object(object(first.delivery_part).detailPaths)[String(f.id)] ??
          parts[0].fullPath;
    }
    const teams = new Set(
      items.flatMap(
        (f) => [String(object(f.home).id), String(object(f.away).id)],
      ),
    );
    const radar = object(first.playerRadar);
    return {
      ...first,
      delivery_part: undefined,
      items,
      playerRadar: {
        ...radar,
        profiles: rows(radar.profiles).filter((p) =>
          teams.has(String(object(p.team).id))
        ),
        coverage: rows(radar.coverage).filter((p) =>
          teams.has(String(p.teamId))
        ),
      },
      delivery: {
        schemaVersion: 1,
        sport,
        day,
        detailPaths: paths,
        radarPaths: parts.map((p) => p.fullPath),
      },
    };
  }
  const recent: Json[] = [];
  const fixtures: Json[] = [],
    odds: Json[] = [],
    computed: Json[] = [],
    players: Json[] = [];
  const fixtureIds = new Set<number>();
  const owners = new Map<number, string>();
  const playerIds = new Set<string>();
  for (const part of parts) {
    const raw = object(part.overview.raw);
    const matches = rows(raw.fixtures).filter((f) => {
      const date = object(f.fixture).date;
      return typeof date === "string" && dayKey(date) === day;
    });
    const ids = new Set(matches.map((f) => Number(object(f.fixture).id)));
    const teams = new Set(
      matches.flatMap(
        (f) => [
          Number(object(object(f.teams).home).id),
          Number(object(object(f.teams).away).id),
        ],
      ),
    );
    for (const f of matches) {
      const id = Number(object(f.fixture).id);
      if (!fixtureIds.has(id)) {
        fixtures.push(f);
        fixtureIds.add(id);
        owners.set(id, part.id);
        paths[`api-fixture-${id}`] = object(
          object(part.overview.delivery_part).detailPaths,
        )[`api-fixture-${id}`] ?? part.fullPath;
      }
    }
    odds.push(
      ...rows(raw.odds).filter((r) =>
        ids.has(Number(object(r.fixture).id)) &&
        owners.get(Number(object(r.fixture).id)) === part.id
      ),
    );
    computed.push(
      ...rows(object(part.overview.computed).fixtures).filter((r) =>
        ids.has(Number(r.fixture_id)) &&
        owners.get(Number(r.fixture_id)) === part.id
      ),
    );
    recent.push(
      ...rows(raw.recent_league_matches).filter((r) =>
        teams.has(Number(object(r.team).id))
      ),
    );
    for (const p of rows(raw.player_form_radar)) {
      const key = `${object(p.league).id}:${object(p.player).id}`;
      if (teams.has(Number(object(p.team).id)) && !playerIds.has(key)) {
        players.push(p);
        playerIds.add(key);
      }
    }
  }
  return {
    schema_version: 1,
    source: first.source,
    timezone: "Europe/Paris",
    captured_at: parts.map((p) => p.capturedAt).sort().at(-1),
    window_start: day,
    window_end: day,
    raw: {
      fixtures,
      odds,
      player_form_radar: players,
      recent_league_matches: recent,
    },
    computed: { fixtures: computed },
    delivery: {
      schemaVersion: 1,
      sport,
      day,
      detailPaths: paths,
      radarPaths: parts.map((p) =>
        object(p.overview.delivery_part).radarPath ?? p.fullPath
      ),
    },
  };
}

export function partArtifacts(
  sport: FeedSport,
  sourceId: string,
  full: Json,
): { overview: Json; artifacts: Map<string, Json> } {
  const root = `delivery/${sport}/${sourceId}/`,
    artifacts = new Map<string, Json>(),
    detailPaths: Json = {};
  if (sport === "football") {
    const raw = object(full.raw),
      {
        fixtures: _fixtures,
        odds: _odds,
        head_to_head: _h2h,
        player_form_radar: _players,
        ...context
      } = raw;
    artifacts.set(`${root}context.json`, { raw: context });
    for (const f of rows(raw.fixtures)) {
      const id = String(object(f.fixture).id),
        teams = new Set([
          Number(object(object(f.teams).home).id),
          Number(object(object(f.teams).away).id),
        ]);
      const path = `${root}match-${id}.json`;
      artifacts.set(path, {
        ...full,
        raw: {
          fixtures: [f],
          odds: rows(raw.odds).filter((r) =>
            String(object(r.fixture).id) === id
          ),
          head_to_head: rows(raw.head_to_head).filter((r) =>
            String(r.fixture_id ?? object(r.fixture).id) === id
          ),
          player_form_radar: rows(raw.player_form_radar).filter((p) =>
            teams.has(Number(object(p.team).id))
          ),
        },
        computed: {
          ...object(full.computed),
          fixtures: rows(object(full.computed).fixtures).filter((r) =>
            String(r.fixture_id) === id
          ),
        },
      });
      detailPaths[`api-fixture-${id}`] = {
        path,
        context: `${root}context.json`,
      };
    }
    // Radar needs card markets, computed readings and activity histories.
    // Full bookmaker catalogues and ranking tables belong in match details.
    artifacts.set(`${root}radar.json`, overviewPart(sport, full));
    artifacts.set(`${root}full.json`, full);
  } else {
    for (const c of rows(full.competitions)) {
      artifacts.set(`${root}context-${c.id}.json`, { competitions: [c] });
    }
    const radar = object(full.playerRadar);
    for (const f of rows(full.items)) {
      const teams = new Set([
          String(object(f.home).id),
          String(object(f.away).id),
        ]),
        path = `${root}match-${f.id}.json`;
      const { competitions: _contexts, ...base } = full;
      artifacts.set(path, {
        ...base,
        items: [f],
        playerRadar: {
          ...radar,
          profiles: rows(radar.profiles).filter((p) =>
            teams.has(String(object(p.team).id))
          ),
          coverage: rows(radar.coverage).filter((c) =>
            teams.has(String(c.teamId))
          ),
        },
      });
      detailPaths[String(f.id)] = {
        path,
        context: `${root}context-${f.competitionId}.json`,
      };
    }
    // The broad Radar needs result history and player activity, not event logs.
    artifacts.set(`${root}full.json`, overviewPart(sport, full));
  }
  return {
    overview: {
      ...overviewPart(sport, full),
      delivery_part: {
        detailPaths,
        radarPath: sport === "football"
          ? `${root}radar.json`
          : `${root}full.json`,
      },
    },
    artifacts,
  };
}
