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
  scores: Record<string, PublicScore>;
};
export type SportPublication = {
  schemaVersion: 1;
  sport: string;
  provider: string;
  competitionId: string;
  season: string;
  capturedAt: string;
  windowStart: string;
  windowEnd: string;
  timezone: string;
  collectionId: string;
  items: PublicFixture[];
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
export function compactNhlGames(
  payload: unknown,
  metadata: Omit<
    SportPublication,
    "items" | "schemaVersion" | "sport" | "provider" | "competitionId"
  >,
): SportPublication {
  const ids = new Set<string>();
  const items: PublicFixture[] = [];
  for (const game of providerRows(payload)) {
    const league = object(game.league);
    if (league.id !== 57 || String(league.season) !== metadata.season) {
      throw new Error("A provider response crossed the NHL season boundary");
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
      competitionId: "57",
      competitionName: nonEmpty(league.name),
      season: metadata.season,
      home,
      away,
      startsAt: startsAt.toISOString(),
      calendarDate: day,
      status,
      providerStatus,
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
    competitionId: "57",
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
