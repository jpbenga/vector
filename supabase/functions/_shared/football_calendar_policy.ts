// Calendar availability is independent of bookmaker availability. Offsets are
// inclusive: 14 calendar days means today through today + 13, in the league TZ.
export const footballCalendarDays = 14;
export const footballAnalysisDays = 4;
type Obj = Record<string, unknown>;
const object = (value: unknown): Obj =>
  value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as Obj
    : {};
export function calendarEnd(
  start: string,
  days = footballCalendarDays,
): string {
  const date = new Date(`${start}T12:00:00Z`);
  date.setUTCDate(date.getUTCDate() + days - 1);
  return date.toISOString().slice(0, 10);
}
export function localCalendarDate(
  value: string | Date,
  timezone: string,
): string {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: timezone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(new Date(value));
  const part = (name: string) => parts.find((p) => p.type === name)!.value;
  return `${part("year")}-${part("month")}-${part("day")}`;
}
export function fixturesOnDate(
  body: Obj,
  date: string,
  timezone: string,
): Obj[] {
  const rows = Array.isArray(body.response) ? body.response : [];
  return rows.map(object).filter((row) => {
    const kickoff = object(row.fixture).date;
    return typeof kickoff === "string" && !Number.isNaN(Date.parse(kickoff)) &&
      localCalendarDate(kickoff, timezone) === date;
  });
}
export function usesDatedFixtureSource(date: string, start: string): boolean {
  return date <= calendarEnd(start, footballAnalysisDays);
}
export function fixtureBodyForDate(
  seasonBody: Obj,
  datedBody: Obj | undefined,
  date: string,
  start: string,
  timezone: string,
): Obj {
  // A successful empty dated response is authoritative (postponement/removal).
  return usesDatedFixtureSource(date, start) && datedBody !== undefined
    ? datedBody
    : { ...seasonBody, response: fixturesOnDate(seasonBody, date, timezone) };
}
export function fixturesEligibleForAnnouncements(
  fixtures: Obj[],
  capturedAt: Date,
  timezone: string,
): Obj[] {
  const start = localCalendarDate(capturedAt, timezone);
  const end = calendarEnd(start, footballAnalysisDays);
  return fixtures.filter((row) => {
    const kickoff = object(row.fixture).date;
    if (typeof kickoff !== "string" || Number.isNaN(Date.parse(kickoff))) {
      return false;
    }
    const day = localCalendarDate(kickoff, timezone);
    return day >= start && day <= end;
  });
}
export function oddsPageCount(body: Obj): number {
  const total = object(body.paging).total ?? 1;
  if (
    total === 0 && Array.isArray(body.response) && body.response.length === 0
  ) return 1;
  if (!Number.isInteger(total) || Number(total) < 1) {
    throw new Error("Invalid odds pagination returned by provider.");
  }
  return Number(total);
}
export async function collectOddsPages<T extends { body: Obj }>(
  fetchPage: (page: number) => Promise<T>,
): Promise<T[]> {
  const first = await fetchPage(1);
  const pages = [first];
  const total = oddsPageCount(first.body);
  for (let page = 2; page <= total; page++) pages.push(await fetchPage(page));
  return pages;
}
export function selectCachedOddsPages<
  T extends { query_params: Obj; response_body: Obj },
>(
  rows: T[],
  filters: Record<string, string>,
): T[] {
  // Rows arrive newest first. Extra bookmaker/bet filters must never leak in.
  const exact = rows.filter((row) => {
    const keys = Object.keys(row.query_params).filter((key) => key !== "page");
    return keys.length === Object.keys(filters).length &&
      Object.entries(filters).every(([key, value]) =>
        String(row.query_params[key]) === value
      );
  });
  const byPage = new Map<number, T>();
  for (const row of exact) {
    const page = Number(row.query_params.page ?? 1);
    if (!byPage.has(page)) byPage.set(page, row);
  }
  const first = byPage.get(1);
  if (!first) return [];
  const total = oddsPageCount(first.response_body);
  const result: T[] = [];
  for (let page = 1; page <= total; page++) {
    const row = byPage.get(page);
    if (!row) {
      throw new Error(
        `Missing cached odds page ${page}/${total}; collect before publishing.`,
      );
    }
    result.push(row);
  }
  // Surplus pages from an older, larger response are intentionally omitted.
  return result;
}

// /odds has no timezone parameter: its date filter refers to the UTC kickoff.
export function oddsDatesForFixtures(fixtures: unknown[]): string[] {
  return [
    ...new Set(
      fixtures.map((row) => object(object(row).fixture).date)
        .filter((value): value is string =>
          typeof value === "string" && !Number.isNaN(Date.parse(value))
        )
        .map((value) => new Date(value).toISOString().slice(0, 10)),
    ),
  ];
}
