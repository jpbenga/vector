export type HeadToHeadJson = Record<string, unknown>;

export const headToHeadHistoryYears = 3;
export const maxHeadToHeadMeetings = 6;

/// Returns the six most recent official, completed meetings that were known
/// at the time of the upcoming fixture. Friendlies are deliberately excluded.
export function eligibleHeadToHeadMeetings(
  values: readonly HeadToHeadJson[],
  referenceKickoff: string | Date,
): HeadToHeadJson[] {
  const reference = dateValue(referenceKickoff);
  if (reference === null) return [];
  const lowerBound = new Date(reference);
  lowerBound.setUTCFullYear(
    lowerBound.getUTCFullYear() - headToHeadHistoryYears,
  );

  return values
    .filter((value) => {
      const fixture = objectValue(value.fixture) ?? {};
      const league = objectValue(value.league) ?? {};
      const playedAt = dateValue(fixture.date);
      const status = stringValue(objectValue(fixture.status)?.short);
      return playedAt !== null &&
        playedAt >= lowerBound &&
        playedAt < reference &&
        ["FT", "AET", "PEN"].includes(status ?? "") &&
        !isFriendlyCompetition(league);
    })
    .sort((left, right) => {
      const leftDate = dateValue((objectValue(left.fixture) ?? {}).date);
      const rightDate = dateValue((objectValue(right.fixture) ?? {}).date);
      return (rightDate?.getTime() ?? 0) - (leftDate?.getTime() ?? 0);
    })
    .slice(0, maxHeadToHeadMeetings);
}

/// Returns the provider fixture ids whose immutable event timeline must be
/// collected for the meetings displayed by the application.
export function eligibleHeadToHeadFixtureIds(
  values: readonly HeadToHeadJson[],
  referenceKickoff: string | Date,
): number[] {
  const ids = new Set<number>();
  for (const meeting of eligibleHeadToHeadMeetings(values, referenceKickoff)) {
    const fixture = objectValue(meeting.fixture) ?? {};
    const id = numberValue(fixture.id);
    if (id !== null) ids.add(id);
  }
  return [...ids];
}

function isFriendlyCompetition(league: HeadToHeadJson): boolean {
  const label = [league.name, league.type, league.country]
    .map(stringValue)
    .filter((value): value is string => value !== null)
    .join(" ")
    .toLocaleLowerCase();
  return label.includes("friendl") || label.includes("amical");
}

function objectValue(value: unknown): HeadToHeadJson | null {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as HeadToHeadJson
    : null;
}

function stringValue(value: unknown): string | null {
  return typeof value === "string" && value.length > 0 ? value : null;
}

function numberValue(value: unknown): number | null {
  const parsed = typeof value === "number"
    ? value
    : typeof value === "string"
    ? Number(value)
    : Number.NaN;
  return Number.isFinite(parsed) ? parsed : null;
}

function dateValue(value: unknown): Date | null {
  if (value instanceof Date) {
    return Number.isNaN(value.getTime()) ? null : value;
  }
  if (typeof value !== "string") return null;
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}
