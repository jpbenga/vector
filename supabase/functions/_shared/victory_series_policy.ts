/** Same three-win contract as core/domain/lector_victory_series.dart.
 * Adapters supply completed, deduplicated, newest-first history for one
 * competition/season/phase. Unknowns interrupt proof, never join two runs.
 */
export type SeriesScope = "overall" | "home" | "away";
export type SeriesGame = {
  won: boolean | null;
  home: boolean | null;
  lost?: boolean | null;
};
export function assessVictorySeries(
  games: readonly SeriesGame[],
  scope: SeriesScope = "overall",
  historyComplete = false,
): { count: number; sample: number; exact: boolean; detected: boolean } {
  return assessResultSeries(games, (g) => g.won, scope, historyComplete);
}
export function assessResultSeries(
  games: readonly SeriesGame[],
  matches: (game: SeriesGame) => boolean | null,
  scope: SeriesScope = "overall",
  historyComplete = false,
): { count: number; sample: number; exact: boolean; detected: boolean } {
  let count = 0, sample = 0;
  const result = (exact: boolean) => ({
    count,
    sample,
    exact,
    detected: count >= 3,
  });
  for (const game of games) {
    if (scope !== "overall") {
      if (game.home === null) return result(false);
      if (game.home !== (scope === "home")) continue;
    }
    sample++;
    const value = matches(game);
    if (value !== true) return result(value === false);
    count++;
  }
  return result(historyComplete);
}

type JsonObject = Record<string, unknown>;
/** Football provider history is already competition/season scoped. */
export function footballSeriesHistory(
  rows: readonly JsonObject[],
  cutoff: Date,
  upcomingId: number,
): SeriesGame[] {
  const dated = rows.some((r) => object(r.fixture)?.date != null);
  if (dated && rows.some((r) => !validDate(object(r.fixture)?.date))) return [];
  const ordered = rows.filter((r) => {
    const fixture = object(r.fixture);
    return fixture?.id !== upcomingId &&
      (!dated || validDate(fixture?.date)!.getTime() < cutoff.getTime());
  }).slice();
  if (dated) {
    ordered.sort((a, b) =>
      validDate(object(b.fixture)?.date)!.getTime() -
      validDate(object(a.fixture)?.date)!.getTime()
    );
  }
  const seen = new Map<string, JsonObject>();
  let conflict = false;
  const unique = ordered.filter((r) => {
    const fixture = object(r.fixture);
    const key = fixture?.id != null
      ? `id:${fixture.id}`
      : dated
      ? `${fixture?.date}:${object(r.opponent)?.name}:${r.venue}`
      : null;
    if (key === null) return true;
    const previous = seen.get(key);
    if (previous) {
      if (
        previous.result !== r.result || previous.venue !== r.venue ||
        object(previous.fixture)?.date !== fixture?.date
      ) conflict = true;
      return false;
    }
    seen.set(key, r);
    return true;
  });
  if (conflict) return [];
  return unique.map((r) => ({
    won: ["W", "V"].includes(String(r.result).toUpperCase())
      ? true
      : ["D", "N", "L"].includes(String(r.result).toUpperCase())
      ? false
      : null,
    lost: ["L"].includes(String(r.result).toUpperCase())
      ? true
      : ["W", "V", "D", "N"].includes(String(r.result).toUpperCase())
      ? false
      : null,
    home: r.venue === "home" ? true : r.venue === "away" ? false : null,
  }));
}
function object(value: unknown): JsonObject | null {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as JsonObject
    : null;
}
function validDate(value: unknown): Date | null {
  if (typeof value !== "string") return null;
  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? null : d;
}
