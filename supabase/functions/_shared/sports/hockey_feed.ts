import {
  calculateHockeyStandingContext,
  type HockeyStandingContext,
} from "./hockey_standing_context.ts";
import type { PublicPlayerRadar } from "./hockey_player_radar.ts";
import {
  type CalculatedHockeyVenueStandings,
} from "./hockey_venue_standings.ts";
/** Provider parsing lives in the sport adapter. No API key or raw payload enters
 * the public publication. This module also runs in the local preview collector. */
export type JsonObject = Record<string, unknown>;
export type PublicScore = { home: number; away: number };
export type PublicFixture = {
  id: string;
  competitionId: string;
  competitionName: string;
  season: string;
  home: { id: string; name: string; logoUrl: string | null };
  away: { id: string; name: string; logoUrl: string | null };
  startsAt: string;
  calendarDate: string;
  status: string;
  providerStatus: string;
  clock?: string;
  scores: Record<string, PublicScore>;
  recentForm?: { home: PublicFormResult[]; away: PublicFormResult[] };
};
export type PublicFormResult = {
  id: string;
  startsAt: string;
  opponent: string;
  home: boolean;
  scored: number;
  conceded: number;
  outcome: "win" | "loss" | "draw";
  providerStatus: string;
};
export type PublicStanding = {
  team: PublicFixture["home"];
  rank: number;
  played: number;
  points: number;
  wins: number;
  overtimeWins: number;
  losses: number;
  overtimeLosses: number;
  goalsFor?: number | null;
  goalsAgainst?: number | null;
  description?: string | null;
  form: PublicFormResult[];
  formHistory?: PublicFormResult[];
};
export type PublicCompetition = {
  id: string;
  name: string;
  season: string;
  logoUrl: string | null;
  country: string;
  countryCode?: string | null;
  countryFlagUrl?: string | null;
  formPhaseVerified: boolean;
  venueStandings?: CalculatedHockeyVenueStandings;
  standingContext?: HockeyStandingContext;
  tables: { stage: string; group: string; rows: PublicStanding[] }[];
};
export type SportPublication = {
  schemaVersion: 1;
  sport: string;
  provider: string;
  competitionId: string;
  season: string;
  capturedAt: string;
  baseCapturedAt?: string;
  windowStart: string;
  windowEnd: string;
  timezone: string;
  collectionId: string;
  items: PublicFixture[];
  competitions?: PublicCompetition[];
  playerRadar?: PublicPlayerRadar;
};
export function object(value: unknown): JsonObject {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("Invalid provider object");
  }
  return value as JsonObject;
}
function nonEmpty(value: unknown): string {
  if (typeof value !== "string" || !value.trim()) {
    throw new Error("Missing provider text");
  }
  return value;
}
function identity(value: unknown): string {
  if (!Number.isSafeInteger(value) || Number(value) <= 0) {
    throw new Error("Invalid provider ID");
  }
  return String(value);
}
/** API-Sports sometimes returns HTTP 200 with an error body. Never publish it. */
export function providerRows(payload: unknown): JsonObject[] {
  const envelope = object(payload);
  const errors = envelope.errors;
  if (!errors || typeof errors !== "object" || Object.keys(errors).length) {
    throw new Error(
      "Provider rejected the request (see private collection log)",
    );
  }
  if (
    !Array.isArray(envelope.response) ||
    envelope.results !== envelope.response.length
  ) {
    throw new Error("Incomplete provider response");
  }
  return envelope.response.map(object);
}
export function calendarDate(date: Date, timezone = "Europe/Paris"): string {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: timezone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(date);
  const get = (kind: string) => parts.find((p) => p.type === kind)!.value;
  return `${get("year")}-${get("month")}-${get("day")}`;
}
export function shiftDate(day: string, offset: number): string {
  const date = new Date(`${day}T12:00:00Z`);
  if (!Number.isFinite(date.getTime())) {
    throw new Error("Invalid calendar date");
  }
  date.setUTCDate(date.getUTCDate() + offset);
  return date.toISOString().slice(0, 10);
}
export function currentNhlSeason(payload: unknown): number {
  const league = providerRows(payload).find((l) => l.id === 57);
  if (!league || !Array.isArray(league.seasons)) {
    throw new Error("NHL league missing");
  }
  const current = league.seasons.map(object).filter((s) => s.current === true);
  if (current.length !== 1 || !Number.isSafeInteger(current[0].season)) {
    throw new Error("NHL current season is ambiguous");
  }
  return Number(current[0].season);
}
function periodScore(value: unknown): PublicScore | null {
  if (value == null) return null;
  if (typeof value !== "string" || !/^\d+-\d+$/.test(value)) {
    throw new Error("Invalid period score");
  }
  const [home, away] = value.split("-").map(Number);
  return { home, away };
}
const statuses: Record<string, string> = {
  NS: "scheduled",
  P1: "live",
  P2: "live",
  P3: "live",
  OT: "live",
  BT: "live",
  PT: "live",
  PEN: "live",
  IN1: "live",
  IN2: "live",
  FT: "finished",
  AOT: "finished",
  AP: "finished",
  APEN: "finished",
  PST: "postponed",
  CANC: "cancelled",
  ABD: "cancelled",
};
export function compactHockeyGames(
  payload: unknown,
  metadata: Omit<
    SportPublication,
    "items" | "schemaVersion" | "sport" | "provider" | "competitionId"
  >,
  leagueId = 57,
): SportPublication {
  const ids = new Set<string>();
  const items: PublicFixture[] = [];
  for (const game of providerRows(payload)) {
    const league = object(game.league);
    if (league.id !== leagueId || String(league.season) !== metadata.season) {
      throw new Error(
        "A provider response crossed the competition season boundary",
      );
    }
    const id = identity(game.id);
    if (ids.has(id)) throw new Error("Duplicate provider game");
    ids.add(id);
    const startsAt = new Date(nonEmpty(game.date));
    if (!Number.isFinite(startsAt.getTime())) {
      throw new Error("Invalid game date");
    }
    const day = calendarDate(startsAt, metadata.timezone);
    if (day < metadata.windowStart || day > metadata.windowEnd) continue;
    const teams = object(game.teams);
    const participant = (value: unknown) => {
      const team = object(value);
      return {
        id: identity(team.id),
        name: nonEmpty(team.name),
        logoUrl: typeof team.logo === "string" ? team.logo : null,
      };
    };
    const home = participant(teams.home), away = participant(teams.away);
    if (home.id === away.id) throw new Error("Identical game participants");
    const providerStatus = nonEmpty(object(game.status).short);
    const status = statuses[providerStatus] ?? "unknown";
    const totals = object(game.scores);
    const scores: Record<string, PublicScore> = {};
    if (totals.home !== null || totals.away !== null) {
      if (
        ![totals.home, totals.away].every((n) =>
          Number.isSafeInteger(n) && Number(n) >= 0
        )
      ) {
        throw new Error("Incomplete game score");
      }
      // Live totals are not labelled final; scheduled 0-0 is not a played score.
      if (status === "finished") {
        scores.final = { home: Number(totals.home), away: Number(totals.away) };
      }
      if (status === "live") {
        scores.current = {
          home: Number(totals.home),
          away: Number(totals.away),
        };
      }
    }
    const periods = game.periods == null ? {} : object(game.periods);
    for (const key of ["first", "second", "third", "overtime", "penalties"]) {
      const score = periodScore(periods[key]);
      if (score) scores[key] = score;
    }
    // Only completed regulation periods prove a 60-minute result. Missing
    // periods must never be replaced with an OT/shootout final score.
    if (
      (status === "finished" || ["OT", "PEN", "PT"].includes(providerStatus)) &&
      scores.first && scores.second && scores.third
    ) {
      scores.regulation = {
        home: scores.first.home + scores.second.home + scores.third.home,
        away: scores.first.away + scores.second.away + scores.third.away,
      };
    }
    items.push({
      id,
      competitionId: String(leagueId),
      competitionName: nonEmpty(league.name),
      season: metadata.season,
      home,
      away,
      startsAt: startsAt.toISOString(),
      calendarDate: day,
      status,
      providerStatus,
      ...(status === "live" && typeof game.timer === "string" &&
          /^\d{1,2}:\d{2}$/.test(game.timer)
        ? { clock: game.timer }
        : {}),
      scores,
    });
  }
  items.sort((a, b) =>
    a.startsAt.localeCompare(b.startsAt) || a.id.localeCompare(b.id)
  );
  return {
    schemaVersion: 1,
    sport: "hockey",
    provider: "api-hockey",
    competitionId: String(leagueId),
    ...metadata,
    items,
  };
}
/** Storage owns atomic publication. If normalization fails, publish is never
 * called, so the last complete publication remains readable. */
export async function collectNhl(
  ports: {
    request: (
      path: string,
      parameters: Record<string, string>,
    ) => Promise<unknown>;
    saveRaw: (kind: string, payload: unknown) => Promise<void>;
    publish: (publication: SportPublication) => Promise<void>;
  },
  now: Date,
  collectionId: string,
): Promise<SportPublication> {
  const leagues = await ports.request("leagues", { id: "57" });
  await ports.saveRaw("leagues", leagues);
  const season = currentNhlSeason(leagues);
  const games = await ports.request("games", {
    league: "57",
    season: String(season),
    timezone: "Europe/Paris",
  });
  await ports.saveRaw("games", games);
  const today = calendarDate(now);
  const publication = compactNhlGames(games, {
    season: String(season),
    capturedAt: now.toISOString(),
    windowStart: shiftDate(today, -7),
    windowEnd: shiftDate(today, 13),
    timezone: "Europe/Paris",
    collectionId,
  });
  await ports.publish(publication);
  return publication;
}

export function compactNhlGames(
  payload: unknown,
  metadata: Parameters<typeof compactHockeyGames>[1],
): SportPublication {
  return compactHockeyGames(payload, metadata, 57);
}
export const hockeyLeagueIds = [57, 58, 35, 10, 18, 16, 47] as const;
function integer(value: unknown): number {
  if (!Number.isSafeInteger(value) || Number(value) < 0) {
    throw new Error("Invalid standing number");
  }
  return Number(value);
}
function seasonFor(payload: unknown, leagueId: number): string {
  const league = providerRows(payload).find((l) => l.id === leagueId);
  const seasons = (league?.seasons as unknown[] | undefined)?.map(object)
    .filter((s) => s.current === true);
  if (seasons?.length !== 1) throw new Error("Ambiguous current hockey season");
  return String(integer(seasons[0].season));
}
function standingRows(payload: unknown): JsonObject[] {
  const envelope = object(payload);
  if (
    !envelope.errors || Object.keys(envelope.errors).length ||
    !Array.isArray(envelope.response) ||
    envelope.results !== envelope.response.length
  ) throw new Error("Invalid standings response");
  return envelope.response.flatMap((group) => {
    if (!Array.isArray(group)) throw new Error("Invalid standings group");
    return group.map(object);
  });
}
/** Last five completed results, excluding the selected match and later games.
 * Uses game identity and full timestamps, never today's ranking to rewrite history. */
export function recentHockeyResults(
  games: PublicFixture[],
  team: string,
  before: string,
  limit = 5,
): PublicFormResult[] {
  return games.filter((g) =>
    g.status === "finished" && g.startsAt < before &&
    (g.home.id === team || g.away.id === team) && g.scores.final
  )
    .sort((a, b) =>
      b.startsAt.localeCompare(a.startsAt) || b.id.localeCompare(a.id)
    ).slice(0, limit).reverse()
    .map((g) => {
      const home = g.home.id === team, score = g.scores.final;
      const scored = home ? score.home : score.away,
        conceded = home ? score.away : score.home;
      return {
        id: g.id,
        startsAt: g.startsAt,
        opponent: home ? g.away.name : g.home.name,
        home,
        scored,
        conceded,
        outcome: scored > conceded
          ? "win"
          : scored < conceded
          ? "loss"
          : "draw",
        providerStatus: g.providerStatus,
      };
    });
}
export function compactHockeyCollection(
  raw: {
    leagueId: number;
    leagues: unknown;
    games: unknown;
    standings: unknown;
  }[],
  now: Date,
  collectionId: string,
): SportPublication {
  const today = calendarDate(now),
    windowStart = shiftDate(today, -7),
    windowEnd = shiftDate(today, 13);
  const competitions: PublicCompetition[] = [], items: PublicFixture[] = [];
  if (new Set(raw.map((r) => r.leagueId)).size !== raw.length) {
    throw new Error("Duplicate hockey competition");
  }
  for (const entry of raw) {
    const season = seasonFor(entry.leagues, entry.leagueId);
    const metadata = {
      season,
      capturedAt: now.toISOString(),
      windowStart: "1900-01-01",
      windowEnd: "2999-12-31",
      timezone: "Europe/Paris",
      collectionId,
    };
    const all = compactHockeyGames(entry.games, metadata, entry.leagueId).items;
    const league = providerRows(entry.leagues).find((l) =>
      l.id === entry.leagueId
    )!;
    const rows = standingRows(entry.standings);
    const tables = new Map<string, PublicCompetition["tables"][number]>();
    // NHL response contains pre-season and regular-season standings, whereas
    // games do not expose their phase. Do not mix them in a ranked form radar.
    const formPhaseVerified = new Set(rows.map((r) => r.stage)).size === 1 &&
      rows.every((r) => /regular season/i.test(String(r.stage))) &&
      !rows.some((r) => /pre.?season/i.test(String(r.stage))) &&
      rows.length > 0;
    for (const row of rows) {
      const rowLeague = object(row.league);
      if (
        rowLeague.id !== entry.leagueId || String(rowLeague.season) !== season
      ) throw new Error("Crossed standings season");
      const stage = nonEmpty(row.stage);
      if (/pre.?season/i.test(stage)) continue;
      const group = object(row.group).name == null
        ? "Classement général"
        : nonEmpty(object(row.group).name);
      const key = `${stage}::${group}`;
      if (!tables.has(key)) tables.set(key, { stage, group, rows: [] });
      const team = object(row.team),
        games = object(row.games),
        goals = row.goals == null ? {} : object(row.goals),
        teamId = identity(team.id);
      const target = tables.get(key)!;
      if (target.rows.some((r) => r.team.id === teamId)) {
        throw new Error("Duplicate team in standings group");
      }
      target.rows.push({
        team: {
          id: teamId,
          name: nonEmpty(team.name),
          logoUrl: typeof team.logo === "string" ? team.logo : null,
        },
        rank: integer(row.position),
        played: integer(games.played),
        points: integer(row.points),
        goalsFor: goals.for == null ? null : integer(goals.for),
        goalsAgainst: goals.against == null ? null : integer(goals.against),
        description:
          typeof row.description === "string" && row.description.trim()
            ? row.description.trim()
            : null,
        wins: integer(object(games.win).total),
        overtimeWins: integer(object(games.win_overtime).total),
        losses: integer(object(games.lose).total),
        overtimeLosses: integer(object(games.lose_overtime).total),
        formHistory: formPhaseVerified
          ? recentHockeyResults(all, teamId, now.toISOString(), all.length)
          : [],
        form: formPhaseVerified
          ? recentHockeyResults(all, teamId, now.toISOString())
          : [],
      });
    }
    const country = object(league.country);
    const competition: PublicCompetition = {
      id: String(entry.leagueId),
      name: nonEmpty(league.name),
      season,
      logoUrl: typeof league.logo === "string" ? league.logo : null,
      country: nonEmpty(country.name),
      countryCode: typeof country.code === "string" ? country.code : null,
      countryFlagUrl: typeof country.flag === "string" ? country.flag : null,
      formPhaseVerified,
      tables: [...tables.values()].map((t) => ({
        ...t,
        rows: t.rows.sort((a, b) => a.rank - b.rank),
      })),
    };
    Object.assign(
      competition,
      calculateHockeyStandingContext(competition, all, now.toISOString()),
    );
    competitions.push(competition);
    for (const game of all) {
      if (game.calendarDate < windowStart || game.calendarDate > windowEnd) {
        continue;
      }
      const cutoff = game.startsAt < now.toISOString()
        ? game.startsAt
        : now.toISOString();
      game.recentForm = {
        home: formPhaseVerified
          ? recentHockeyResults(all, game.home.id, cutoff)
          : [],
        away: formPhaseVerified
          ? recentHockeyResults(all, game.away.id, cutoff)
          : [],
      };
      items.push(game);
    }
  }
  items.sort((a, b) =>
    a.startsAt.localeCompare(b.startsAt) || a.id.localeCompare(b.id)
  );
  return {
    schemaVersion: 1,
    sport: "hockey",
    provider: "api-hockey",
    competitionId: "multi",
    season: "multi",
    capturedAt: now.toISOString(),
    windowStart,
    windowEnd,
    timezone: "Europe/Paris",
    collectionId,
    items,
    competitions,
  };
}
export async function collectHockey(
  ports: Parameters<typeof collectNhl>[0],
  now: Date,
  collectionId: string,
): Promise<SportPublication> {
  const raw = [];
  for (const leagueId of hockeyLeagueIds) {
    const leagues = await ports.request("leagues", { id: String(leagueId) });
    await ports.saveRaw(`leagues-${leagueId}`, leagues);
    const season = seasonFor(leagues, leagueId);
    const games = await ports.request("games", {
      league: String(leagueId),
      season,
      timezone: "Europe/Paris",
    });
    await ports.saveRaw(`games-${leagueId}`, games);
    const standings = await ports.request("standings", {
      league: String(leagueId),
      season,
    });
    await ports.saveRaw(`standings-${leagueId}`, standings);
    raw.push({ leagueId, leagues, games, standings });
  }
  const publication = compactHockeyCollection(raw, now, collectionId);
  await ports.publish(publication);
  return publication;
}
