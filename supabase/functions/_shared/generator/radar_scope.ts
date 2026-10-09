import {
  type Context,
  type Evidence,
  obj,
  type RadarScope,
  rows,
  type Sport,
} from "./contracts.ts";
import type { Source } from "./catalog.ts";

export function scopeKind(context: Context, scope: RadarScope) {
  return context.radarKind ?? scope.mode;
}
export function sourceInRadar(source: Source, context: Context) {
  const scope = context.radar?.[source.sport];
  return !!scope &&
    (source.sport === "football"
      ? scope.sourceIds.includes(source.id)
      : Date.parse(scope.capturedAt) === Date.parse(source.capturedAt));
}

/** Membership comes from the UI's canonical rankers; every statistic below
 * comes from the referenced, immutable server publication, never from the client.
 */
export function scopedRadarEvidence(
  sources: Source[],
  context: Context,
): Map<string, Evidence[]> {
  const result = new Map<string, Evidence[]>();
  for (const sport of ["football", "hockey"] as const) {
    const scope = context.radar?.[sport];
    if (!scope) continue;
    const pool = sources.filter((s) =>
      s.sport === sport && sourceInRadar(s, context)
    );
    if (sport === "football") {
      pool.sort((a, b) =>
        scope.sourceIds.indexOf(a.id) - scope.sourceIds.indexOf(b.id)
      );
    }
    const kind = scopeKind(context, scope);
    for (const member of (kind === "teams" ? scope.teams : scope.players)) {
      const records = new Map<
        string,
        {
          row: ReturnType<typeof obj>;
          source: Source;
          name: string;
          photo?: string;
        }
      >();
      for (const source of pool) {
        if (kind === "teams") {
          const histories = sport === "football"
            ? rows(obj(source.payload.raw).recent_league_matches)
            : rows(source.payload.competitions).filter((c) =>
              c.formPhaseVerified === true &&
              (!scope.competitionId || String(c.id) === scope.competitionId)
            ).flatMap((c) => rows(c.tables).flatMap((t) => rows(t.rows)));
          for (const history of histories) {
            const team = obj(history.team);
            if (String(team.id) !== member.teamId) continue;
            for (
              const row of rows(
                sport === "football" ? history.matches : history.formHistory,
              )
            ) {
              const id = String(
                sport === "football"
                  ? obj(row.fixture).id ?? row.fixtureId
                  : row.id,
              );
              const at = String(
                sport === "football"
                  ? obj(row.fixture).date ?? row.date
                  : row.startsAt,
              );
              if (
                !Number.isFinite(Date.parse(at)) ||
                Date.parse(at) > Date.parse(source.capturedAt)
              ) continue;
              if (!records.has(id)) {
                records.set(id, { row, source, name: String(team.name) });
              }
            }
          }
        } else {
          const profiles = sport === "football"
            ? rows(obj(source.payload.raw).player_form_radar)
            : rows(obj(source.payload.playerRadar).profiles);
          for (const p of profiles) {
            const team = obj(p.team),
              player = sport === "football" ? obj(p.player) : p;
            if (
              String(team.id) !== member.teamId ||
              String(player.id) !== member.id ||
              (sport === "hockey" && scope.competitionId &&
                String(p.competitionId) !== scope.competitionId)
            ) continue;
            for (const row of rows(p.activity)) {
              const id = String(row.fixture_id ?? row.id);
              const at = String(row.played_at ?? row.startsAt);
              if (
                !Number.isFinite(Date.parse(at)) ||
                Date.parse(at) > Date.parse(source.capturedAt)
              ) continue;
              if (!records.has(id)) {
                records.set(id, {
                  row,
                  source,
                  name: String(player.name),
                  photo: String(player.photo ?? ""),
                });
              }
            }
          }
        }
      }
      const recent = member.matchIds.map((id) => records.get(id));
      if (recent.some((r) => !r)) continue;
      const checked = recent.map((r) => r!);
      const name = checked[0].name,
        asOf = checked.map((r) => r.source.capturedAt).sort().at(-1)!;
      let text: string, metrics: Evidence["metrics"];
      if (kind === "teams") {
        const values = checked.map(({ row }) =>
          sport === "football"
            ? /^(W|V)$/i.test(String(row.result))
              ? 3
              : /^(D|N)$/i.test(String(row.result))
              ? 1
              : /^(L)$/i.test(String(row.result))
              ? 0
              : null
            : row.outcome === "win"
            ? 1
            : row.outcome === "loss"
            ? 0
            : null
        );
        if (values.some((v) => v === null)) continue;
        const total = values.reduce<number>((a, b) => a + b!, 0);
        text = sport === "football"
          ? `${name} : ${total}/15 points sur les cinq derniers matchs du Radar, toutes compétitions présentes dans cette publication.`
          : `${name} : ${total}/5 victoires finales sur les cinq derniers matchs du Radar, prolongations et tirs au but inclus.`;
        metrics = [{
          label: sport === "football" ? "Points Radar" : "Victoires",
          value: `${total}/${sport === "football" ? 15 : 5}`,
        }];
      } else {
        if (
          checked.some(({ row }) =>
            typeof row.goals !== "number" || typeof row.assists !== "number"
          )
        ) continue;
        const goals = checked.reduce((n, { row }) => n + Number(row.goals), 0),
          assists = checked.reduce((n, { row }) => n + Number(row.assists), 0),
          decisive = checked.filter(({ row }) =>
            Number(row.goals) + Number(row.assists) > 0
          ).length;
        if (goals + assists < 2) {
          continue;
        }
        text =
          `${name} : ${goals} but(s), ${assists} passe(s), décisif dans ${decisive}/3 derniers matchs de son équipe. Ce signal ne prouve pas une victoire au prochain match.`;
        metrics = [{ label: "Décisif", value: `${decisive}/3 matchs` }, {
          label: "Buts",
          value: String(goals),
        }, { label: "Passes", value: String(assists) }];
      }
      const evidence: Evidence = {
        id: `radar:${sport}:${kind}:${member.teamId}:${member.id}:${
          member.matchIds.join("-")
        }`,
        source: "radar",
        family: kind === "teams" ? "form" : "player",
        subject: `${sport}:${member.teamId}`,
        label: name,
        sample: checked.length,
        asOf,
        text: `${text} Rang ${member.rank} dans votre Radar ${
          kind === "teams" ? "équipes" : "joueurs"
        }.`,
        supportsMarket: false,
        reusesReading: kind === "teams",
        role: "context",
        metrics,
        lineage: { kind: "radar", matchIds: member.matchIds },
        ...(kind === "players" ? { photo: checked[0].photo } : {}),
      };
      const key = `${sport}:${member.teamId}`;
      result.set(key, [...(result.get(key) ?? []), evidence]);
    }
  }
  return result;
}
export function matchRadarSignals(
  evidence: Map<string, Evidence[]>,
  sport: Sport,
  home: string,
  away: string,
) {
  return [
    ...evidence.get(`${sport}:${home}`) ?? [],
    ...evidence.get(`${sport}:${away}`) ?? [],
  ];
}
