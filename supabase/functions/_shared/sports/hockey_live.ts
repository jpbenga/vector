import {
  calendarDate,
  compactHockeyGames,
  hockeyLeagueIds,
  object,
  providerRows,
  type PublicFixture,
  shiftDate,
} from "./hockey_feed.ts";

/** One grouped request per calendar day, for all seven leagues. No per-user
 * provider calls; incomplete/error responses never erase the last valid result. */
export async function collectHockeyLive(
  dates: string[],
  ports: {
    reserve(): Promise<boolean>;
    request(date: string): Promise<unknown>;
  },
  capturedAt: string,
): Promise<
  {
    states: { fixture: PublicFixture; capturedAt: string }[];
    deferred: boolean;
  }
> {
  const now = new Date(capturedAt);
  if (!Number.isFinite(now.getTime())) {
    throw new Error("Invalid collection time");
  }
  const today = calendarDate(now);
  if (
    dates.length > 3 || new Set(dates).size !== dates.length ||
    dates.some((d) =>
      !/^\d{4}-\d{2}-\d{2}$/.test(d) || shiftDate(d, 0) !== d || d > today ||
      d < shiftDate(today, -7)
    )
  ) throw new Error("Invalid live calendar window");
  const states: { fixture: PublicFixture; capturedAt: string }[] = [];
  const seen = new Set<string>();
  for (const date of dates) {
    if (!await ports.reserve()) return { states, deferred: true };
    const rows = providerRows(await ports.request(date));
    for (const leagueId of hockeyLeagueIds) {
      // Current supported rules are explicitly bound to the 2026 season. Never
      // silently mix foreign leagues or a newly rolled season into this demo.
      const selected = rows.filter((r) => {
        const l = object(r.league);
        return l.id === leagueId && l.season === 2026;
      });
      const compact = compactHockeyGames({
        errors: [],
        results: selected.length,
        response: selected,
      }, {
        season: "2026",
        capturedAt,
        windowStart: date,
        windowEnd: date,
        timezone: "Europe/Paris",
        collectionId: "live",
      }, leagueId);
      for (const fixture of compact.items) {
        if (seen.has(fixture.id)) throw new Error("Duplicate live fixture");
        if (fixture.status === "unknown") {
          throw new Error("Unknown provider game status");
        }
        if (
          ["live", "finished"].includes(fixture.status) &&
          !fixture.scores.current && !fixture.scores.final
        ) throw new Error("Missing live score");
        seen.add(fixture.id);
        states.push({ fixture, capturedAt });
      }
    }
  }
  return { states, deferred: false };
}
