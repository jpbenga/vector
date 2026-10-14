/** Resumable UEFA collection. Cursors contain requests, never provider bodies or keys. */
import {
  localCalendarDate,
  oddsPageCount,
  usesDatedFixtureSource,
} from "./football_calendar_policy.ts";
type Obj = Record<string, any>;
const object = (v: unknown): Obj =>
  v && typeof v === "object" && !Array.isArray(v) ? v as Obj : {};
const rows = (v: unknown): Obj[] => Array.isArray(v) ? v.map(object) : [];
export type EuropeanRequest = {
  endpoint: string;
  query: Record<string, string>;
  ttlSeconds: number;
  kind:
    | "fixtures"
    | "odds"
    | "recent"
    | "statistics"
    | "headToHead"
    | "injury"
    | "players"
    | "fixtureStatistics"
    | "fixturePlayers"
    | "fixtureEvents";
};
export interface EuropeanCursor {
  version: 1;
  run_id: string;
  tasks: EuropeanRequest[];
  offset: number;
  season: number;
}

export async function collectEuropeanBatch(input: {
  leagueId: number;
  runId: string;
  timezone: string;
  windowStart: string;
  windowEnd: string;
  recentDays: number;
  cursor: Obj;
  now: Date;
  includeTeamStatistics?: boolean;
  includeExpectedGoals?: boolean;
  includeRecentPlayerPerformances?: boolean;
  bookmakerId?: number | null;
  recentMatches?: number;
}, port: {
  fetch: (
    request: {
      endpoint: string;
      query: Record<string, string>;
      ttlSeconds: number;
    },
  ) => Promise<{ body: Obj; fetchedAt: string; fromCache: boolean }>;
  season: (body: Obj) => number;
  record: (kind: string, body: Obj) => void;
  missingStatistics: (teamId: string) => void;
  clock?: () => number;
}) {
  if (![2, 3, 848].includes(input.leagueId)) {
    throw Error("Bounded collection is restricted to UEFA competitions");
  }
  const clock = port.clock ?? (() => performance.now()), started = clock();
  let calls = 0, cursor: EuropeanCursor;
  const fetch = async (
    request: {
      endpoint: string;
      query: Record<string, string>;
      ttlSeconds: number;
    },
  ) => {
    calls++;
    return await port.fetch(request);
  };
  if (input.cursor.version === undefined) {
    const league = await fetch({
      endpoint: "/leagues",
      query: { id: String(input.leagueId) },
      ttlSeconds: 86400,
    });
    const season = port.season(league.body);
    const common = { league: String(input.leagueId), season: String(season) };
    const history = await fetch({
      endpoint: "/fixtures",
      query: { ...common, timezone: input.timezone },
      ttlSeconds: 6 * 3600,
    });
    port.record("league", history.body);
    const table = await fetch({
      endpoint: "/standings",
      query: common,
      ttlSeconds: 3600,
    });
    port.record("standings", table.body);
    const teams = new Set<string>(),
      dates = new Set<string>(),
      pairs = new Set<string>(),
      imminent = new Set<string>();

    for (const row of rows(history.body.response)) {
      const fixture = object(row.fixture), kickoff = Date.parse(fixture.date);
      if (!Number.isFinite(kickoff)) continue;
      const day = localCalendarDate(new Date(kickoff), input.timezone);
      if (day < input.windowStart || day > input.windowEnd) continue;
      dates.add(day);
      if (
        ["NS", "TBD"].includes(object(fixture.status).short) &&
        kickoff > input.now.getTime()
      ) {
        const pairIds = [
          object(object(row.teams).home).id,
          object(object(row.teams).away).id,
        ];
        if (pairIds.every((id) => Number.isInteger(id) && id > 0)) {
          pairs.add(pairIds.sort((a, b) => a - b).join("-"));
        }
        if (kickoff - input.now.getTime() <= 48 * 3600000) {
          imminent.add(String(fixture.id));
        }
        for (const side of ["home", "away"]) {
          const id = object(object(row.teams)[side]).id;
          if (Number.isInteger(id) && id > 0) teams.add(String(id));
        }
      }
    }
    const tasks: EuropeanRequest[] = [];
    for (
      let at = Date.parse(input.windowStart);
      at <= Date.parse(input.windowEnd);
      at += 86400000
    ) {
      const day = new Date(at).toISOString().slice(0, 10);
      if (usesDatedFixtureSource(day, input.windowStart)) {
        tasks.push({
          endpoint: "/fixtures",
          query: { ...common, date: day, timezone: input.timezone },
          ttlSeconds: 900,
          kind: "fixtures",
        });
      }
    }
    for (const day of [...dates].sort()) {
      tasks.push({
        endpoint: "/odds",
        query: {
          ...common,
          date: day,
          ...(input.bookmakerId
            ? { bookmaker: String(input.bookmakerId) }
            : {}),
        },
        ttlSeconds: 900,
        kind: "odds",
      });
    }
    const before = new Date(Date.parse(input.windowStart) - 86400000)
      .toISOString().slice(0, 10);
    const from = new Date(
      Date.parse(input.windowStart) - input.recentDays * 86400000,
    ).toISOString().slice(0, 10);
    // Recent results precede optional statistics; qualifiers/old squads are not re-polled.
    for (const team of [...teams].sort()) {
      tasks.push({
        endpoint: "/fixtures",
        query: { ...common, team, from, to: before, timezone: input.timezone },
        ttlSeconds: 6 * 3600,
        kind: "recent",
      });
    }
    if (input.includeTeamStatistics !== false) {
      for (const team of [...teams].sort()) {
        tasks.push({
          endpoint: "/teams/statistics",
          query: { ...common, team },
          ttlSeconds: 3600,
          kind: "statistics",
        });
      }
    }
    for (const h2h of pairs) {
      tasks.push({
        endpoint: "/fixtures/headtohead",
        query: { h2h, last: "20" },
        ttlSeconds: 30 * 86400,
        kind: "headToHead",
      });
    }
    for (const fixture of imminent) {
      tasks.push({
        endpoint: "/injuries",
        query: { fixture },
        ttlSeconds: 3600,
        kind: "injury",
      });
    }
    cursor = { version: 1, run_id: input.runId, tasks, offset: 0, season };
  } else {
    cursor = input.cursor as EuropeanCursor;
    if (
      cursor.version !== 1 || cursor.run_id !== input.runId ||
      !Array.isArray(cursor.tasks) || cursor.tasks.length > 2000 ||
      !Number.isInteger(cursor.offset) || cursor.offset < 0 ||
      cursor.offset > cursor.tasks.length
    ) throw Error("Invalid European collection checkpoint");
  }
  while (
    cursor.offset < cursor.tasks.length && calls < 10 &&
    clock() - started < 45000
  ) {
    const task = cursor.tasks[cursor.offset];
    const scoped = ["/fixtures", "/odds", "/teams/statistics", "/players"]
      .includes(task.endpoint);
    if (
      ![
        "/fixtures",
        "/odds",
        "/teams/statistics",
        "/players",
        "/fixtures/headtohead",
        "/injuries",
        "/fixtures/statistics",
        "/fixtures/players",
        "/fixtures/events",
      ].includes(task.endpoint) ||
      (scoped &&
        (task.query.league !== String(input.leagueId) ||
          task.query.season !== String(cursor.season))) ||
      !Number.isFinite(task.ttlSeconds) || task.ttlSeconds < 0
    ) throw Error("Foreign European collection request");
    try {
      const result = await fetch(task);
      port.record(task.kind, result.body);
      if (
        (task.kind === "odds" || task.kind === "players") &&
        task.query.page === undefined
      ) {
        const total = oddsPageCount(result.body);
        if (!Number.isInteger(total) || total < 1 || total > 50) {
          throw Error("Invalid odds pagination");
        }
        cursor.tasks.splice(
          cursor.offset + 1,
          0,
          ...Array.from(
            { length: total - 1 },
            (_, i) => ({
              ...task,
              query: { ...task.query, page: String(i + 2) },
            }),
          ),
        );
      }
      if (task.kind === "recent") {
        const recent = rows(result.body.response).filter((r) =>
          ["FT", "AET", "PEN"].includes(
            object(object(r.fixture).status).short,
          ) &&
          Date.parse(object(r.fixture).date) < Date.parse(input.windowStart)
        ).sort((a, b) =>
          Date.parse(object(b.fixture).date) -
          Date.parse(object(a.fixture).date)
        ).slice(0, input.recentMatches ?? 5);
        const append = (
          endpoint: string,
          query: Record<string, string>,
          kind: EuropeanRequest["kind"],
          ttlSeconds = 86400,
        ) => {
          if (
            !cursor.tasks.some((t) =>
              t.endpoint === endpoint &&
              JSON.stringify(t.query) === JSON.stringify(query)
            )
          ) cursor.tasks.push({ endpoint, query, kind, ttlSeconds });
        };
        for (const match of recent) {
          const fixture = String(object(match.fixture).id);
          if (input.includeExpectedGoals !== false) {
            append("/fixtures/statistics", { fixture }, "fixtureStatistics");
          }
          if (input.includeRecentPlayerPerformances === true) {
            append("/fixtures/players", { fixture }, "fixturePlayers");
            append("/fixtures/events", { fixture }, "fixtureEvents");
          }
        }
        if (input.includeRecentPlayerPerformances === true) {
          append(
            "/players",
            {
              league: String(input.leagueId),
              season: String(cursor.season),
              team: task.query.team,
            },
            "players",
            6 * 3600,
          );
        }
      }
    } catch (error) {
      // Missing provider statistics are not zero and do not destroy the calendar.
      const message = error instanceof Error ? error.message : String(error);
      const providerStatisticsFailure =
        /^API-Football (?:5\d\d|4(?:00|04|22)) for \/teams\/statistics/.test(
          message,
        ) ||
        (/^API-Football error for \/teams\/statistics/.test(message) &&
          /(?:\b5xEr\b|\bbug:)/i.test(message));
      if (
        task.kind !== "statistics" || !providerStatisticsFailure ||
        /quota|rate.?limit|too many|429|authentication|token|key/i.test(message)
      ) throw error;
      port.missingStatistics(task.query.team);
    }
    cursor.offset++;
  }
  return {
    season: cursor.season,
    done: cursor.offset === cursor.tasks.length,
    cursor,
    calls,
  };
}
