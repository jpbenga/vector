// Pure provider adapter. No environment access: usable in permission-free tests.
export type LiveObject = Record<string, unknown>;
export const liveObject = (v: unknown): LiveObject =>
  v !== null && typeof v === "object" && !Array.isArray(v)
    ? v as LiveObject
    : {};
const integer = (v: unknown): number | null =>
  typeof v === "number" && Number.isInteger(v) && v >= 0 ? v : null;
export const finalStatuses = new Set(["FT", "AET", "PEN"]);
const statuses = new Set([
  "NS",
  "TBD",
  "1H",
  "HT",
  "2H",
  "ET",
  "BT",
  "P",
  "LIVE",
  "FT",
  "AET",
  "PEN",
  "SUSP",
  "INT",
  "PST",
  "CANC",
  "ABD",
  "AWD",
  "WO",
]);

export function liveState(
  payload: unknown,
  capturedAt: string,
): LiveObject | null {
  const row = liveObject(payload);
  const fixture = liveObject(row.fixture);
  const league = liveObject(row.league);
  const status = liveObject(fixture.status);
  const teams = liveObject(row.teams);
  const goals = liveObject(row.goals);
  const half = liveObject(liveObject(row.score).halftime);
  const id = integer(fixture.id), leagueId = integer(league.id);
  const kickoff = typeof fixture.date === "string" ? fixture.date : "";
  if (
    !id || !leagueId || !statuses.has(String(status.short)) ||
    !Number.isFinite(Date.parse(kickoff))
  ) return null;
  const day = new Intl.DateTimeFormat("sv-SE", { timeZone: "Europe/Paris" })
    .format(new Date(kickoff));
  return {
    fixture_id: id,
    league_id: leagueId,
    fixture_date: day,
    kickoff_at: kickoff,
    status: status.short,
    elapsed: integer(status.elapsed),
    extra: integer(status.extra),
    home_goals: integer(goals.home),
    away_goals: integer(goals.away),
    halftime_home_goals: integer(half.home),
    halftime_away_goals: integer(half.away),
    home_team_name: liveObject(teams.home).name ?? "",
    away_team_name: liveObject(teams.away).name ?? "",
    captured_at: capturedAt,
    // The existing ids endpoint already returns match statistics. A missing
    // block is not zero and must not erase the previous factual block.
    statistics: Array.isArray(row.statistics) && row.statistics.length > 0
      ? row.statistics
      : null,
    events: Array.isArray(row.events) ? row.events : null,
    events_captured_at: Array.isArray(row.events) ? capturedAt : null,
    statistics_captured_at:
      Array.isArray(row.statistics) && row.statistics.length > 0
        ? capturedAt
        : null,
  };
}

export async function finalResult(
  payload: unknown,
  capturedAt: string,
): Promise<LiveObject | null> {
  const row = liveObject(payload), state = liveState(row, capturedAt);
  if (
    !state || !finalStatuses.has(String(state.status)) ||
    state.home_goals === null || state.away_goals === null
  ) return null;
  const teams = liveObject(row.teams),
    score = liveObject(row.score),
    half = liveObject(score.halftime);
  const events = Array.isArray(row.events) ? row.events.map(liveObject) : [];
  const statistics = Array.isArray(row.statistics) ? row.statistics : [];
  const goals = events.filter((e) =>
    e.type === "Goal" && e.detail !== "Missed Penalty" &&
    e.comments !== "Penalty Shootout"
  );
  const decisive: LiveObject = {};
  for (const event of goals) {
    if (event.detail === "Own Goal") continue;
    const player = integer(liveObject(event.player).id),
      assist = integer(liveObject(event.assist).id);
    if (player) decisive[String(player)] = true;
    if (assist) decisive[String(assist)] = true;
  }
  // A goals-only final is useful for team readings; missing events never prove
  // a player was NOT decisive. Coverage can legitimately be absent.
  const eventsComplete = Array.isArray(row.events) &&
    goals.length >= Number(state.home_goals) + Number(state.away_goals);
  const stable = {
    fixture_id: state.fixture_id,
    status: state.status,
    home_goals: state.home_goals,
    away_goals: state.away_goals,
    score,
    statistics,
    events,
    eventsComplete,
  };
  const hash = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(JSON.stringify(stable)),
  );
  const contentHash = Array.from(
    new Uint8Array(hash),
    (b) => b.toString(16).padStart(2, "0"),
  ).join("");
  return {
    ...state,
    home_team_id: integer(liveObject(teams.home).id),
    away_team_id: integer(liveObject(teams.away).id),
    halftime_home_goals: integer(half.home),
    halftime_away_goals: integer(half.away),
    score,
    source_payload: {
      fixture: row,
      final_statistics: statistics,
      final_events: events,
      computed: {
        player_decisive: decisive,
        player_events_complete: eventsComplete,
        live_semantic_hash: contentHash,
      },
    },
    content_hash: contentHash,
  };
}

export function providerRows(payload: unknown): LiveObject[] {
  const body = liveObject(payload), errors = body.errors;
  if (errors && Object.keys(errors).length) {
    throw new Error(`API-Football : ${JSON.stringify(errors).slice(0, 600)}`);
  }
  if (!Array.isArray(body.response)) {
    throw new Error(
      "API-Football : réponse invalide (liste de matchs absente).",
    );
  }
  return body.response.map(liveObject);
}

export type LiveTransport = {
  reserve: () => Promise<boolean>;
  fetchFixtures: (query: string) => Promise<unknown>;
};

export async function collectLiveMatches(
  leagues: number[],
  dueIds: number[],
  transport: LiveTransport,
  capturedAt: string,
): Promise<
  {
    states: LiveObject[];
    results: LiveObject[];
    checked: number[];
    requests: number;
    deferred: boolean;
    issue?: string;
  }
> {
  const states = new Map<number, LiveObject>();
  const results: LiveObject[] = [];
  let requests = 0, deferred = false;
  let issue: string | undefined;
  const query = async (q: string) => {
    if (!await transport.reserve()) {
      deferred = true;
      return null;
    }
    requests++;
    try {
      return providerRows(await transport.fetchFixtures(q));
    } catch (error) {
      deferred = true;
      issue = error instanceof Error ? error.message : String(error);
      return null;
    }
  };
  if (!leagues.length) {
    return { states: [], results, checked: [], requests, deferred };
  }
  const live = await query(`live=${[...new Set(leagues)].join("-")}`);
  for (const row of live ?? []) {
    const state = liveState(row, capturedAt);
    if (state && leagues.includes(Number(state.league_id))) {
      states.set(Number(state.fixture_id), state);
    }
  }
  const ids = [...new Set(dueIds)].filter((id) =>
    Number.isInteger(id) && id > 0
  ).slice(0, 20);
  let checked: number[] = [];
  if (!deferred && ids.length) {
    const detailed = await query(`ids=${ids.join("-")}`);
    if (detailed !== null) checked = ids;
    for (const row of detailed ?? []) {
      const state = liveState(row, capturedAt);
      if (
        !state || !ids.includes(Number(state.fixture_id)) ||
        !leagues.includes(Number(state.league_id))
      ) continue;
      states.set(Number(state.fixture_id), state);
      const result = await finalResult(row, capturedAt);
      if (result) results.push(result);
    }
    // IDs omitted by the provider remain queued and are checked again. An
    // absent live row never changes the last known score/status.
  }
  return {
    states: [...states.values()],
    results,
    checked,
    requests,
    deferred,
    issue,
  };
}
