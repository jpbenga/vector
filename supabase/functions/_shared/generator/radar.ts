import { type Evidence, type Json, obj, rows } from "./contracts.ts";
import type { Source } from "./catalog.ts";
/** A factual discovery list. It never authorizes a market or creates a price. */
export function playerSignals(
  source: Source,
  teamIds: string[],
  cutoff: string,
): Evidence[] {
  const raw = obj(source.payload.raw);
  const profiles = source.sport === "football"
    ? rows(raw.player_form_radar)
    : rows(obj(source.payload.playerRadar).profiles);
  const seen = new Set<string>(), signals: Evidence[] = [];
  for (const profile of profiles) {
    const team = obj(profile.team), player = obj(profile.player);
    if (!teamIds.includes(String(team.id))) continue;
    const id = String(player.id ?? profile.id);
    if (seen.has(id)) continue;
    seen.add(id);
    const activities = rows(profile.activity).filter((a) => {
      const date = String(a.played_at ?? a.startsAt ?? "");
      return Number.isFinite(Date.parse(date)) &&
        Date.parse(date) < Date.parse(cutoff) &&
        Date.parse(date) <= Date.parse(source.capturedAt);
    }).sort((a, b) =>
      String(b.played_at ?? b.startsAt).localeCompare(
        String(a.played_at ?? a.startsAt),
      )
    ).slice(0, 3);
    if (
      activities.length !== 3 ||
      activities.some((a) =>
        typeof a.goals !== "number" || typeof a.assists !== "number"
      )
    ) continue;
    const decisive = activities.filter((a) =>
      Number(a.goals) + Number(a.assists) > 0
    ).length;
    if (decisive < 2) continue;
    const name = String(player.name ?? profile.name),
      goals = activities.reduce((n, a) => n + Number(a.goals), 0),
      assists = activities.reduce((n, a) => n + Number(a.assists), 0);
    signals.push({
      id: `${source.id}:radar:${id}`,
      source: "radar",
      family: "player",
      subject: `player:${id}`,
      label: name,
      sample: 3,
      asOf: source.capturedAt,
      text:
        `${name} (${team.name}) : décisif dans ${decisive}/3 matchs, ${goals} but(s) et ${assists} passe(s). ${
          source.sport === "hockey"
            ? "Temps de glace non renseigné."
            : "Un signal d’activité, sans garantie de contribution au prochain match."
        }`,
    });
  }
  return signals.slice(0, 3);
}

/** Reuse the published team trajectory; it is not another independent proof. */
export function teamSignals(
  source: Source,
  fixture: Json,
  readings: Json[] = [],
): Evidence[] {
  if (source.sport === "football") {
    const teams = obj(fixture.teams);
    return readings.filter((r) =>
      [
        "positive_streak",
        "winning_streak",
        "negative_streak",
        "improving_form",
        "declining_form",
        "form_gap",
      ].includes(String(r.id)) && Number(r.sample_size) >= 3
    ).map((r) => ({
      id: `${source.id}:radar:team:${r.subject_team_id}:${r.id}`,
      source: "radar",
      family: "form",
      subject: String(r.subject_team_id),
      label: String(r.label ?? r.id),
      sample: Number(r.sample_size),
      asOf: source.capturedAt,
      text: `${obj(teams[String(r.side)]).name ?? "Équipe"} : ${
        rows(r.evidence).map((e) => String(e.label ?? "")).join(" ")
      }. Le Radar équipes et cette lecture reprennent la même série de résultats.`,
    }));
  }
  const result: Evidence[] = [];
  const competition = rows(source.payload.competitions).find((c) =>
    String(c.id) === String(fixture.competitionId)
  );
  if (competition?.formPhaseVerified !== true) return result;
  for (const side of ["home", "away"]) {
    const matches = rows(obj(fixture.recentForm)[side]).filter((m) =>
      typeof m.startsAt === "string" &&
      Date.parse(m.startsAt) < Date.parse(source.capturedAt) &&
      ["win", "loss"].includes(String(m.outcome))
    )
      .sort((a, b) => String(b.startsAt).localeCompare(String(a.startsAt)))
      .slice(0, 5);
    if (matches.length !== 5) continue;
    const team = obj(fixture[side]),
      wins = matches.filter((m) => m.outcome === "win").length;
    result.push({
      id: `${source.id}:radar:team:${team.id}`,
      source: "radar",
      family: "form",
      subject: `hockey:${team.id}`,
      label: String(team.name),
      sample: 5,
      asOf: source.capturedAt,
      text:
        `${team.name} : ${wins} victoire(s) sur les cinq derniers matchs publiés, prolongations et tirs au but inclus. La forme d’équipe et les lectures de dynamique reposent sur les mêmes résultats. Les points dépendent du règlement de la compétition.`,
    });
  }
  return result;
}
