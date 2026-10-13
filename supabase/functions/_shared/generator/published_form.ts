/** Factual form projection from publications only. No provider calls or inferred seasons. */
import { obj, rows } from "./contracts.ts";
export interface PublishedFormResult {
  fixtureId: string;
  playedAt: string;
  competitionId: string;
  season: number;
  result: "W" | "D" | "L";
  venue: string | null;
  goalsFor: number | null;
  goalsAgainst: number | null;
  opponent: string | null;
}
export interface PublishedTeamForm {
  teamId: string;
  competitionId: string | null;
  competitionName: string | null;
  season: number | null;
  state: "available" | "partial" | "absent" | "unverified";
  sourcePath: string;
  observedAt: string | null;
  results: PublishedFormResult[];
  limitations: string[];
}
export interface PublishedFixtureForm {
  schemaVersion: 1;
  fixtureId: string;
  kickoffAt: string;
  scope: "domestic_championship" | "competition";
  home: PublishedTeamForm;
  away: PublishedTeamForm;
}
const id = (v: unknown) =>
  typeof v === "number" || typeof v === "string"
    ? /^\d{1,12}$/.test(String(v)) ? String(v) : null
    : null;
const seasonNumber = (v: unknown) =>
  typeof v === "number" && Number.isInteger(v) && v >= 1900 && v <= 3000
    ? v
    : null;
const score = (v: unknown) =>
  typeof v === "number" && Number.isInteger(v) && v >= 0 ? v : null;
const stamp = (v: unknown) =>
  typeof v === "string" && Number.isFinite(Date.parse(v)) ? v : null;
const finished = new Set(["FT", "AET", "PEN", "AWD"]);
export function publishedFixtureForm(
  raw: Record<string, unknown>,
  fixture: Record<string, unknown>,
  capturedAt: string,
  scope: PublishedFixtureForm["scope"] = "domestic_championship",
  now = new Date(capturedAt),
): PublishedFixtureForm {
  const f = obj(fixture.fixture),
    teams = obj(fixture.teams),
    competition = obj(fixture.league);
  const kickoffAt = String(f.date),
    cutoff = Math.min(Date.parse(kickoffAt), now.getTime());
  const dossier = rows(raw.european_comparisons).find((d) =>
    d.schemaVersion === 1 &&
    String(d.fixtureId) === String(f.id) &&
    Date.parse(String(d.kickoffAt)) === Date.parse(kickoffAt) &&
    String(obj(d.home).teamId) === String(obj(teams.home).id) &&
    String(obj(d.away).teamId) === String(obj(teams.away).id)
  );
  const projected = rows(raw.generator_domestic_forms).find((d) =>
    d.schemaVersion === 1 &&
    d.scope === scope && String(d.fixtureId) === String(f.id) &&
    d.kickoffAt === kickoffAt &&
    String(obj(d.home).teamId) === String(obj(teams.home).id) &&
    String(obj(d.away).teamId) === String(obj(teams.away).id)
  );
  const side = (name: "home" | "away"): PublishedTeamForm => {
    const teamId = String(obj(teams[name]).id);
    let league = competition,
      path = "raw.recent_league_matches",
      observedAt: string | null = stamp(capturedAt);
    let history: Record<string, unknown>[] = [],
      canonical = false,
      explicit = false;
    const d = obj(dossier?.[name]), projection = obj(projected?.[name]);
    if (projected) {
      league = {
        id: projection.competitionId,
        season: projection.season,
        name: projection.competitionName,
        type: "League",
      };
      history = rows(projection.results);
      path = String(projection.sourcePath ?? "raw.generator_domestic_forms");
      observedAt = stamp(projection.observedAt);
      canonical = true;
      explicit = projection.state !== "unverified" &&
        projection.competitionId != null && projection.season != null;
    } else if (dossier && scope === "domestic_championship") {
      league = obj(d.domesticCompetition);
      history = rows(d.domesticRecentMatches);
      path = `raw.european_comparisons.${name}.domesticRecentMatches`;
      observedAt = stamp(d.domesticObservedAt);
      canonical = true;
      explicit = id(league.id) !== null && seasonNumber(league.season) !== null;
    } else {
      const context = rows(raw.domestic_team_contexts).find((c) =>
        String(obj(c.team).id) === teamId &&
        (c.fixture_id === undefined || String(c.fixture_id) === String(f.id))
      );
      if (scope === "domestic_championship" && context) {
        league = obj(context.league);
      }
      const histories = rows(raw.recent_league_matches).filter((r) =>
        String(obj(r.team).id) === teamId &&
        String(obj(r.league).id) === String(league.id)
      );
      // A row or provider metadata must state the type. A cup is never guessed to be domestic.
      explicit = scope === "competition" ||
        league.type !== "Cup" &&
          (Boolean(context) || league.type === "League" ||
            histories.some((r) => obj(r.league).type === "League"));
      const season = seasonNumber(league.season);
      history = histories.filter((r) => {
        const s = seasonNumber(obj(r.league).season);
        return season !== null &&
          (s !== null
            ? s === season
            : rows(r.matches).length > 0 && rows(r.matches).every((m) =>
              seasonNumber(obj(m.league).season) === season
            ));
      }).flatMap((r) => rows(r.matches));
    }
    const competitionId = id(league.id), season = seasonNumber(league.season);
    const base: PublishedTeamForm = {
      teamId,
      competitionId,
      competitionName: typeof league.name === "string" ? league.name : null,
      season,
      sourcePath: path,
      observedAt,
      results: [],
      state: "unverified",
      limitations: [],
    };
    if (
      !Number.isFinite(cutoff) || !explicit || competitionId === null ||
      season === null ||
      !observedAt || Date.parse(observedAt) > cutoff
    ) {
      base.limitations.push(
        "Forme non vérifiable : championnat, saison ou observation pré-match non publiés.",
      );
      return base;
    }
    const valid = new Map<string, PublishedFormResult>();
    for (const m of history) {
      const mf = obj(m.fixture), ml = obj(m.league);
      const fixtureId = id(m.fixtureId ?? mf.id),
        playedAt = stamp(m.playedAt ?? m.date ?? mf.date);
      const mid = id(m.competitionId ?? ml.id ?? league.id),
        ms = seasonNumber(m.season ?? ml.season ?? league.season);
      const status = String(obj(mf.status).short ?? m.status ?? "");
      const gf = score(m.goalsFor ?? obj(m.goals).for),
        ga = score(m.goalsAgainst ?? obj(m.goals).against);
      const result = String(m.result);
      if (
        !fixtureId || fixtureId === String(f.id) || !playedAt ||
        Date.parse(playedAt) >= cutoff ||
        mid !== competitionId || ms !== season ||
        !["W", "D", "L"].includes(result) ||
        (!canonical && !finished.has(status)) ||
        (gf !== null && ga !== null &&
          (gf > ga ? "W" : gf === ga ? "D" : "L") !== result)
      ) continue;
      valid.set(fixtureId, {
        fixtureId,
        playedAt,
        competitionId,
        season,
        result: result as PublishedFormResult["result"],
        venue: typeof m.venue === "string" ? m.venue : null,
        goalsFor: gf,
        goalsAgainst: ga,
        opponent: typeof m.opponent === "string"
          ? m.opponent
          : typeof m.opponentName === "string"
          ? m.opponentName
          : typeof obj(m.opponent).name === "string"
          ? String(obj(m.opponent).name)
          : null,
      });
    }
    base.results = [...valid.values()].sort((a, b) =>
      Date.parse(a.playedAt) - Date.parse(b.playedAt) ||
      (a.fixtureId < b.fixtureId ? -1 : a.fixtureId > b.fixtureId ? 1 : 0)
    ).slice(-5);
    base.state = base.results.length === 5
      ? "available"
      : base.results.length
      ? "partial"
      : "absent";
    if (base.results.length < 5) {
      base.limitations.push(
        `${base.results.length}/5 résultats terminés et contextualisés publiés ; aucune série complétée.`,
      );
    }
    return base;
  };
  return {
    schemaVersion: 1,
    fixtureId: String(f.id),
    kickoffAt,
    scope,
    home: side("home"),
    away: side("away"),
  };
}
/** Additive overview field. Existing readings, card form, odds and algorithms are untouched. */
export function projectDomesticForms(
  raw: Record<string, unknown>,
  capturedAt: string,
) {
  const ids = new Set(
    rows(raw.european_comparisons).map((d) => String(d.fixtureId)),
  );
  return rows(raw.fixtures).filter((fixture) =>
    ids.has(String(obj(fixture.fixture).id))
  )
    .map((fixture) => publishedFixtureForm(raw, fixture, capturedAt));
}
