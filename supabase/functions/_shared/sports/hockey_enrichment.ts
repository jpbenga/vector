import {
  compactHockeyGames,
  object,
  providerRows,
  type PublicFixture,
  type SportPublication,
} from "./hockey_feed.ts";

export type HockeyEvent = {
  period: string;
  minute: number | null;
  elapsed: number | null;
  teamId: string;
  type: string;
  detail: string;
  players: string[];
  assists: string[];
};
export type HockeyMeeting = PublicFixture & {
  events: HockeyEvent[];
  eventsCollected: boolean;
  eventDataIssue?: string;
  competitionPhase?: string;
  competitionKind?: "league" | "cup" | "unknown" | "excluded";
};
export type HockeyVenueRow = {
  team: PublicFixture["home"];
  rank: number;
  played: number;
  wins: number;
  losses: number;
  goalsFor: number;
  goalsAgainst: number;
};
export type HockeyEnrichedCompetition = {
  venueStandings?: {
    home: HockeyVenueRow[];
    away: HockeyVenueRow[];
    collectedAt: string;
    unavailableTeams: string[];
  };
};
export type HockeyEnrichedFixture = {
  matchEvents?: {
    collectedAt: string;
    events: HockeyEvent[];
    complete: boolean;
    isFinal?: boolean;
  };
  headToHead?: { collectedAt: string; meetings: HockeyMeeting[] };
};
export type HockeyEnrichmentPorts = {
  /** Cache keys include league/season/team, unordered pair, or historical game ID.
   * Cached responses must still pass the same parser as a fresh response. */
  request: (
    path: string,
    params: Record<string, string>,
    ttlMs: number,
  ) => Promise<unknown>;
};
const day = 24 * 60 * 60_000;
const count = (n: unknown): number => {
  if (!Number.isSafeInteger(n) || Number(n) < 0) {
    throw new Error("Invalid hockey statistic");
  }
  return Number(n);
};
export function compactVenueStatistics(
  payload: unknown,
  leagueId: string,
  season: string,
  team: PublicFixture["home"],
): { home: HockeyVenueRow; away: HockeyVenueRow } | null {
  const envelope = object(payload);
  if (!envelope.errors || Object.keys(envelope.errors).length) {
    throw new Error("Provider rejected team statistics");
  }
  if (
    envelope.results === 0 &&
    (Array.isArray(envelope.response) && envelope.response.length === 0 ||
      envelope.response && Object.keys(object(envelope.response)).length === 0)
  ) return null;
  const data = object(envelope.response), league = object(data.league);
  if (
    String(league.id) !== leagueId || String(league.season) !== season ||
    String(object(data.team).id) !== team.id
  ) throw new Error("Crossed hockey statistics identity");
  const games = object(data.games), goals = object(data.goals);
  const venue = (side: "home" | "away"): HockeyVenueRow => {
    const played = count(object(games.played)[side]);
    const wins = count(object(object(games.wins)[side]).total);
    const losses = count(object(object(games.loses)[side]).total);
    if (wins + losses > played) {
      throw new Error("Inconsistent venue statistics");
    }
    return {
      team,
      rank: 0,
      played,
      wins,
      losses,
      goalsFor: count(object(object(goals.for).total)[side]),
      goalsAgainst: count(object(object(goals.against).total)[side]),
    };
  };
  return { home: venue("home"), away: venue("away") };
}
export function compactHockeyHistory(
  payload: unknown,
  pair: string[],
  now: Date,
): HockeyMeeting[] {
  const meetings: HockeyMeeting[] = [], ids = new Set<string>();
  for (const row of providerRows(payload)) {
    const league = object(row.league);
    const compact =
      compactHockeyGames({ errors: [], results: 1, response: [row] }, {
        season: String(league.season),
        capturedAt: now.toISOString(),
        collectionId: "h2h",
        timezone: "Europe/Paris",
        windowStart: "1900-01-01",
        windowEnd: "2999-12-31",
      }, count(league.id)).items[0];
    if (
      !pair.includes(compact.home.id) || !pair.includes(compact.away.id) ||
      ids.has(compact.id)
    ) throw new Error("Crossed or duplicate H2H game");
    ids.add(compact.id);
    if (
      compact.status === "finished" && compact.scores.final &&
      compact.startsAt < now.toISOString()
    ) {
      meetings.push({
        ...compact,
        events: [],
        eventsCollected: false,
        competitionPhase: `${league.round ?? ""} ${league.stage ?? ""}`.trim(),
        competitionKind: hockeyMeetingKind(
          league,
          compact.competitionId,
          compact.startsAt,
        ),
      });
    }
  }
  return meetings.sort((a, b) => a.startsAt.localeCompare(b.startsAt));
}
export function hockeyMeetingKind(
  league: Record<string, unknown>,
  id: string,
  startsAt: string,
  declaredKind?: HockeyMeeting["competitionKind"],
): "league" | "cup" | "unknown" | "excluded" {
  const label = `${league.name ?? ""} ${league.round ?? ""} ${
    league.stage ?? ""
  }`.toLowerCase();
  if (
    /friendl|amical|pre.?season|exhibition/.test(label) ||
    declaredKind === "excluded"
  ) return "excluded";
  if (
    /\bcup\b|coupe|champions|play.?off|post.?season|phase[s]? finale/.test(
      label,
    ) || declaredKind === "cup"
  ) return "cup";
  if (label.includes("regular season") || label.includes("saison régulière")) {
    return "league";
  }
  if (id !== "57") return "unknown";
  // Same verified NHL windows as the Dart policy, including the ambiguous
  // simultaneous preseason/Global Series opening in 2024. Sources: audit.
  const date = new Date(startsAt);
  if (!Number.isFinite(date.getTime())) return "unknown";
  const year = date.getUTCMonth() >= 6
    ? date.getUTCFullYear()
    : date.getUTCFullYear() - 1;
  const windows: Record<number, string[]> = {
    2023: ["2023-10-10", "2023-10-10", "2024-04-19T07:00:00Z"],
    2024: ["2024-10-04", "2024-10-08", "2025-04-18T07:00:00Z"],
    2025: ["2025-10-07", "2025-10-07", "2026-04-17T07:00:00Z"],
    2026: ["2026-09-29", "2026-09-29", "2027-04-11T07:00:00Z"],
  };
  const window = windows[year];
  if (!window) return "unknown";
  if (date.getTime() < Date.parse(`${window[0]}T00:00:00Z`)) return "excluded";
  if (
    date.getTime() < Date.parse(`${window[1]}T00:00:00Z`) ||
    date.getTime() >= Date.parse(window[2])
  ) return "unknown";
  return "league";
}
export function selectHockeyHistory(
  history: HockeyMeeting[],
  fixture: PublicFixture,
  now: Date,
): HockeyMeeting[] {
  const before = new Date(
    Math.min(Date.parse(fixture.startsAt), now.getTime()),
  );
  const lower = new Date(before);
  lower.setUTCFullYear(lower.getUTCFullYear() - 3);
  const kindOf = (g: HockeyMeeting) =>
    hockeyMeetingKind(
      { name: g.competitionName, stage: g.competitionPhase },
      g.competitionId,
      g.startsAt,
      g.competitionKind,
    );
  const eligible = history.filter((g) =>
    kindOf(g) !== "excluded" && g.id !== fixture.id &&
    Date.parse(g.startsAt) >= lower.getTime() &&
    Date.parse(g.startsAt) < before.getTime()
  );
  // Six within this competition AND six across competitions; neither scope
  // starves the other when a cup or pre-season meeting is more recent.
  const ids = new Set(
    [
      ...eligible.slice(-6),
      ...eligible.filter((g) => g.competitionId === fixture.competitionId)
        .slice(-6),
      ...eligible.filter((g) => kindOf(g) === "league").slice(-6),
      ...eligible.filter((g) => kindOf(g) === "cup").slice(-6),
    ].map((g) => g.id),
  );
  return eligible.filter((g) => ids.has(g.id));
}
export class HockeyEventDataError extends Error {}
export function compactHockeyEvents(
  payload: unknown,
  game: HockeyMeeting,
): HockeyEvent[] {
  const offsets: Record<string, number> = { P1: 0, P2: 20, P3: 40, OT: 60 };
  return providerRows(payload).map((row) => {
    const teamId = String(object(row.team).id),
      period = String(row.period),
      minute = row.minute == null ? null : Number(row.minute);
    if (
      String(row.game_id) !== game.id ||
      ![game.home.id, game.away.id].includes(teamId) || !(period in offsets) ||
      (minute != null &&
        (!Number.isInteger(minute) || minute < 0 ||
          (period !== "OT" && minute > 20)))
    ) throw new HockeyEventDataError("identity_or_clock");
    const names = (v: unknown): string[] => {
      if (!Array.isArray(v) || v.some((s) => typeof s !== "string")) {
        throw new Error("Invalid hockey event participants");
      }
      return v as string[];
    };
    if (typeof row.type !== "string") {
      throw new Error("Missing hockey event type");
    }
    return {
      period,
      minute,
      elapsed: minute == null ? null : offsets[period] + minute,
      teamId,
      type: row.type,
      detail: typeof row.comment === "string" ? row.comment : "",
      players: names(row.players),
      assists: names(row.assists),
    };
  }).sort((a, b) =>
    (a.elapsed ?? offsets[a.period]) - (b.elapsed ?? offsets[b.period])
  );
}
/** One request per team and unordered opposition, then one per unique historical
 * game advertising events. Nothing is fetched on a user's click. Publication
 * happens only after this entire enrichment has been validated. */
export async function enrichHockeyPublication(
  publication: SportPublication,
  ports: HockeyEnrichmentPorts,
  now: Date,
): Promise<SportPublication> {
  const enriched = structuredClone(publication);
  for (const competition of enriched.competitions ?? []) {
    // Calculated venue points use complete season results and league rules.
    // Team aggregates lack overtime detail and must not overwrite this table.
    if (competition.venueStandings?.source === "season-games") continue;
    const teams = new Map([
      ...competition.tables.flatMap((t) => t.rows).map((r) =>
        [r.team.id, r.team] as const
      ),
      ...enriched.items.filter((f) => f.competitionId === competition.id)
        .flatMap((f) => [f.home, f.away]).map((t) => [t.id, t] as const),
    ]);
    const home: HockeyVenueRow[] = [],
      away: HockeyVenueRow[] = [],
      unavailableTeams: string[] = [];
    for (const team of teams.values()) {
      const raw = await ports.request("teams/statistics", {
        league: competition.id,
        season: competition.season,
        team: team.id,
      }, day);
      const rows = compactVenueStatistics(
        raw,
        competition.id,
        competition.season,
        team,
      );
      if (!rows) {
        unavailableTeams.push(team.id);
        continue;
      }
      home.push(rows.home);
      away.push(rows.away);
    }
    for (const rows of [home, away]) {
      rows.sort((a, b) =>
        (b.played ? b.wins / b.played : -1) -
          (a.played ? a.wins / a.played : -1) ||
        b.played - a.played || a.team.name.localeCompare(b.team.name)
      );
      rows.forEach((r, i) => r.rank = i + 1);
    }
    (competition as unknown as HockeyEnrichedCompetition)
      .venueStandings = {
        home,
        away,
        collectedAt: now.toISOString(),
        unavailableTeams,
      };
  }
  const pairs = new Map<string, PublicFixture[]>();
  for (const fixture of enriched.items) {
    const key = [fixture.home.id, fixture.away.id].sort().join("-");
    if (!pairs.has(key)) pairs.set(key, []);
    pairs.get(key)!.push(fixture);
  }
  const events = new Map<string, HockeyEvent[]>();
  for (const [pair, fixtures] of pairs) {
    const payload = await ports.request("games/h2h", { h2h: pair }, day);
    const history = compactHockeyHistory(payload, pair.split("-"), now);
    const selected = fixtures.map((f) => selectHockeyHistory(history, f, now));
    const games = new Map(selected.flat().map((g) => [g.id, g]));
    for (const f of fixtures) {
      const completed = history.find((g) => g.id === f.id);
      if (completed) games.set(completed.id, completed);
    }
    const available = new Set(
      providerRows(payload).filter((r) => r.events === true).map((r) =>
        String(r.id)
      ),
    );
    for (const game of games.values()) {
      if (!available.has(game.id)) continue;
      try {
        if (!events.has(game.id)) {
          events.set(
            game.id,
            compactHockeyEvents(
              await ports.request(
                "games/events",
                { game: game.id },
                now.getTime() - Date.parse(game.startsAt) < 2 * day
                  ? 60 * 60_000
                  : 30 * day,
              ),
              game,
            ),
          );
        }
        game.events = events.get(game.id)!;
        game.eventsCollected = true;
      } catch (error) {
        // A factual score remains usable when an optional event body contains
        // an inconsistent team identity. Do not reassign that event to a team.
        if (!(error instanceof HockeyEventDataError)) throw error;
        game.eventDataIssue = error.message;
      }
    }
    for (const f of fixtures) {
      const current = games.get(f.id);
      if (current?.eventsCollected && !current.eventDataIssue) {
        (f as PublicFixture & HockeyEnrichedFixture).matchEvents = {
          collectedAt: now.toISOString(),
          events: current.events,
          complete: true,
        };
      }
    }
    fixtures.forEach((f, i) =>
      (f as PublicFixture & HockeyEnrichedFixture).headToHead = {
        collectedAt: now.toISOString(),
        meetings: selected[i],
      }
    );
  }
  return enriched;
}
