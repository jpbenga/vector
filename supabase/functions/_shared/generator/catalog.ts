import { playerSignals, teamSignals } from "./radar.ts";
import {
  type AnalysisMatch,
  calendarDay,
  type Candidate,
  type Catalog,
  type Context,
  type Evidence,
  type Json,
  obj,
  rows,
} from "./contracts.ts";
export interface Source {
  id: string;
  sport: "football" | "hockey";
  capturedAt: string;
  payload: Json;
}
const family = (id: string) =>
  /ranking|standing|structural/.test(id)
    ? "standing"
    : /home|away/.test(id)
    ? "venue"
    : /goal|attack|defen|scor|btts/.test(id)
    ? "production"
    : /player|decisive/.test(id)
    ? "player"
    : /head_to_head/.test(id)
    ? "h2h"
    : "form";
const aliases: Record<string, string> = {
  ranking_superiority: "standing_advantage",
  form_advantage: "recent_form_advantage",
  form_improvement: "improving_form",
};
export function publishedReadingIds(ids: string[]): string[] {
  return [
    ...new Set([
      ...ids,
      ...Object.keys(aliases).filter((id) => ids.includes(aliases[id])),
    ]),
  ];
}
function evidence(raw: Json[], source: Source, readings: string[]): Evidence[] {
  return raw.filter((r) =>
    readings.includes(String(r.id)) || readings.includes(aliases[String(r.id)])
  ).map((r) => ({
    id: `${source.id}:${r.id}:${
      r.subject_team_id ?? r.subject ?? r.side ?? "match"
    }`,
    label: String(r.label ?? r.id),
    family: family(String(r.id)),
    source: "reading",
    subject: String(r.subject_team_id ?? r.subject ?? r.side ?? "match"),
    sample: Number(r.sample_size ?? r.sampleSize ?? 0),
    asOf: source.capturedAt,
    supportsMarket: true,
    role: "support",
    ...(Array.isArray(obj(r.lineage).matchIds)
      ? {
        lineage: {
          kind: String(obj(r.lineage).kind ?? family(String(r.id))),
          matchIds: (obj(r.lineage).matchIds as unknown[]).map(String).slice(
            0,
            80,
          ),
        },
      }
      : {}),
    metrics: rows(r.evidence).slice(0, 4).map((e) => ({
      label: String(e.label ?? ""),
      value: String(e.value ?? ""),
    })),
    text: rows(r.evidence).map((e) => String(e.label ?? "")).join(" ") ||
      String(r.explanation ?? ""),
  }));
}
// Explicit scope: result/double chance use team direction, goals use goal readings.
// Radar is supplementary; never translate a hot player into an unpriced scorer bet.
function supports(raw: Json[], bet: number, value: string): Json[] {
  if ([1, 12].includes(bet)) {
    const side = value === "Home" || value === "Home/Draw"
      ? "home"
      : value === "Away" || value === "Draw/Away"
      ? "away"
      : null;
    if (!side) return [];
    const positive = new Set([
      "ranking_superiority",
      "form_advantage",
      "form_gap",
      "structural_level_gap",
      "positive_streak",
      "winning_streak",
      "improving_form",
      "strong_home_team",
      "strong_away_team",
      "home_away_advantage",
      "away_home_advantage",
      "head_to_head_dominance",
    ]);
    return raw.filter((r) =>
      r.side === side && positive.has(String(r.id)) &&
      r.is_contradiction !== true
    );
  }
  const ids = value === "Over 2.5"
    ? [
      "frequent_over_25",
      "open_match_profile",
      "prolific_attack",
      "attack_in_form",
    ]
    : value === "Under 2.5"
    ? ["frequent_under_25", "closed_match_profile"]
    : bet === 8 && value === "Yes"
    ? ["frequent_btts"]
    : [];
  return raw.filter((r) =>
    ids.includes(String(r.id)) && r.is_contradiction !== true
  );
}
function opposing(raw: Json[], side: string): boolean {
  return raw.some((r) =>
    r.is_contradiction === true ||
    (r.side === side &&
      ["negative_streak", "weak_home_team", "weak_away_team"].includes(
        String(r.id),
      ))
  );
}
/** Opponent support is vigilance for this market, not extra support. */
function vigilance(raw: Json[], bet: number, value: string): Json[] {
  if ([1, 12].includes(bet)) {
    const other = value.startsWith("Home") ? "Away" : "Home";
    return supports(raw, 1, other);
  }
  const opposite = value === "Over 2.5"
    ? ["frequent_under_25", "closed_match_profile"]
    : value === "Under 2.5"
    ? [
      "frequent_over_25",
      "open_match_profile",
      "prolific_attack",
      "attack_in_form",
    ]
    : bet === 8 && value === "Yes"
    ? ["frequent_no_btts", "closed_match_profile"]
    : [];
  return raw.filter((r) => opposite.includes(String(r.id)));
}
export function buildCatalog(
  sources: Source[],
  context: Context,
  date: string,
  now: Date,
): Catalog {
  const candidates: Candidate[] = [], missing = new Set<string>();
  const matches: AnalysisMatch[] = [];
  const seen = new Set<string>(), sourceIds = new Set<string>();
  const signals = new Map<string, Evidence>();
  let matchCount = 0;
  for (
    const source of [...sources].sort((a, b) =>
      b.capturedAt.localeCompare(a.capturedAt)
    )
  ) {
    const pref = context.preferences[source.sport];
    if (!pref || (!pref.readings.length && !pref.scenarios?.length)) {
      missing.add(
        `Préférences ${
          source.sport === "hockey" ? "hockey" : "football"
        } incomplètes : lectures et marchés requis.`,
      );
      continue;
    }
    if (!pref.markets.length) {
      missing.add(
        `Aucun marché ${source.sport} autorisé : exploration possible, composition indisponible.`,
      );
    }
    const age = now.getTime() - Date.parse(source.capturedAt);
    if (!Number.isFinite(age) || age < -60000 || age > 36 * 3600000) {
      missing.add(
        "Une publication est trop ancienne pour la préparation avant match.",
      );
      continue;
    }
    sourceIds.add(source.id);
    if (source.sport === "hockey") {
      const fixtures = rows(source.payload.items).filter((f) =>
        f.status === "scheduled" && typeof f.startsAt === "string" &&
        Date.parse(f.startsAt) > now.getTime() &&
        calendarDay(String(f.startsAt), context.timezone) === date
      );
      for (const fixture of fixtures) {
        const identity = `hockey:${fixture.id}`;
        if (seen.has(identity)) continue;
        if (
          context.scope === "strict" &&
          !pref.competitions.includes(
            `hockey:api-hockey:competition:${fixture.competitionId}`,
          )
        ) continue;
        seen.add(identity);
        matchCount++;
        matches.push({
          id: String(fixture.id),
          sport: "hockey",
          competition: String(fixture.competitionName ?? fixture.competitionId),
          home: String(obj(fixture.home).name),
          away: String(obj(fixture.away).name),
          kickoff: String(fixture.startsAt),
          quoteAvailability: "not_collected",
          evidence: evidence(rows(fixture.readings), source, pref.readings).map(
            (e) => ({ ...e, supportsMarket: false, role: "context" as const }),
          ),
        });
        for (
          const signal of playerSignals(source, [
            String(obj(fixture.home).id),
            String(obj(fixture.away).id),
          ], String(fixture.startsAt))
        ) signals.set(signal.id, signal);
        for (const signal of teamSignals(source, fixture)) {
          signals.set(signal.id, signal);
        }
      }
      // Current hockey publication deliberately contains no market catalogue.
      // Supporting a provider route is not proof a quote was collected.
      missing.add(
        "Hockey : les publications actuelles ne contiennent pas de marchés et cotes horodatés. Aucun pari hockey n’est complété artificiellement.",
      );
      continue;
    }
    const raw = obj(source.payload.raw),
      computed = rows(obj(source.payload.computed).fixtures);
    for (const fixture of rows(raw.fixtures)) {
      const f = obj(fixture.fixture),
        league = obj(fixture.league),
        teams = obj(fixture.teams),
        home = obj(teams.home),
        away = obj(teams.away);
      const id = String(f.id),
        competitionId = String(league.id),
        kickoff = String(f.date);
      if (
        seen.has(id) || obj(f.status).short !== "NS" ||
        !Number.isFinite(Date.parse(kickoff)) ||
        Date.parse(kickoff) <= now.getTime() ||
        calendarDay(kickoff, context.timezone) !== date
      ) continue;
      seen.add(id);
      const discovery = !pref.competitions.includes(competitionId);
      if (discovery && context.scope === "strict") continue;
      const analysis = computed.find((v) => String(v.fixture_id) === id);
      const allReadings = rows(analysis?.readings),
        scenarios = rows(analysis?.scenarios).filter((s) =>
          pref.scenarios?.includes(String(s.id))
        ),
        scenarioReadings = new Set(
          scenarios.flatMap((s) =>
            Array.isArray(s.required_reading_ids)
              ? s.required_reading_ids.map(String)
              : []
          ),
        ),
        selected = allReadings.filter((r) =>
          pref.readings.includes(String(r.id)) ||
          pref.readings.includes(aliases[String(r.id)]) ||
          scenarioReadings.has(String(r.id))
        );
      if (!selected.length && !scenarios.length) continue;
      const radar = [
        ...playerSignals(
          source,
          [String(home.id), String(away.id)],
          kickoff,
        ),
        ...teamSignals(source, fixture, selected),
      ];
      // Outside followed competitions, only a factual Radar opportunity may
      // supplement Pour moi. A matching reading alone never scans all leagues.
      if (context.view === "radar" && !radar.length) continue;
      if (discovery && !radar.length && context.view !== "all") continue;
      const prices = rows(raw.odds).filter((r) =>
        String(obj(r.fixture).id) === id
      );
      const hasFreshQuotes = prices.some((p) => {
        const age = now.getTime() - Date.parse(String(p.update ?? ""));
        return Number.isFinite(age) && age >= -60000 && age <= 48 * 3600000 &&
          rows(p.bookmakers).some((b) =>
            rows(b.bets).some((bet) =>
              rows(bet.values).some((v) =>
                Number.isFinite(Number(v.odd)) && Number(v.odd) > 1 &&
                Number(v.odd) <= 100
              )
            )
          );
      });
      matchCount++;
      matches.push({
        id: `api-fixture-${id}`,
        sport: "football",
        competition: String(league.name),
        home: String(home.name),
        away: String(away.name),
        kickoff,
        quoteAvailability: hasFreshQuotes ? "recent" : "unavailable",
        evidence: [
          ...evidence(selected, source, [...pref.readings, ...scenarioReadings])
            .map((e) => ({
              ...e,
              supportsMarket: false,
              role: "context" as const,
            })),
          ...radar,
        ],
      });
      for (const signal of radar) signals.set(signal.id, signal);
      for (const price of prices) {
        const oddsAt = String(price.update ?? ""),
          oddsAge = now.getTime() - Date.parse(oddsAt);
        if (
          !Number.isFinite(oddsAge) || oddsAge < -60000 ||
          oddsAge > 48 * 3600000
        ) {
          missing.add(
            "Des cotes absentes ou datant de plus de 48 h ont été exclues.",
          );
          continue;
        }
        for (const bookmaker of rows(price.bookmakers)) {
          for (const bet of rows(bookmaker.bets)) {
            for (const v of rows(bet.values)) {
              const betId = Number(bet.id),
                value = String(v.value),
                odds = Number(v.odd);
              const marketId = betId === 1
                ? "matchResult"
                : betId === 12
                ? "doubleChance"
                : betId === 5 && ["Over 2.5", "Under 2.5"].includes(value)
                ? "goalsTotal"
                : betId === 8
                ? "bothTeamsScore"
                : null;
              if (
                !marketId || !pref.markets.includes(marketId) ||
                !Number.isFinite(odds) || odds <= 1 || odds > 100
              ) {
                continue;
              }
              const support = supports(selected, betId, value);
              const side = value.startsWith("Home")
                ? "home"
                : value.startsWith("Away") || value === "Draw/Away"
                ? "away"
                : "match";
              const ev = evidence(support, source, [
                ...pref.readings,
                ...scenarioReadings,
              ]);
              if (
                !ev.length || ev.some((e) => e.sample < 3) ||
                opposing(allReadings, side)
              ) continue;
              const selection = value === "Home"
                ? `${home.name} gagne`
                : value === "Away"
                ? `${away.name} gagne`
                : value === "Home/Draw"
                ? `${home.name} ou nul`
                : value === "Draw/Away"
                ? `${away.name} ou nul`
                : value === "Over 2.5"
                ? "Plus de 2,5 buts"
                : value === "Under 2.5"
                ? "Moins de 2,5 buts"
                : value === "Yes"
                ? "Les deux équipes marquent"
                : value;
              const counter = evidence(
                vigilance(allReadings, betId, value),
                source,
                allReadings.map((r) => String(r.id)),
              )
                .map((e) => ({
                  ...e,
                  supportsMarket: false,
                  role: "vigilance" as const,
                }));
              candidates.push({
                id:
                  `football:${id}:${betId}:${value}:${bookmaker.id}:${source.id}`,
                matchId: `api-fixture-${id}`,
                sport: "football",
                competitionId,
                competition: String(league.name),
                competitionLogo: String(league.logo ?? ""),
                countryFlag: String(league.flag ?? ""),
                home: String(home.name),
                away: String(away.name),
                homeLogo: String(home.logo ?? ""),
                awayLogo: String(away.logo ?? ""),
                teams: [`football:${home.id}`, `football:${away.id}`],
                kickoff,
                marketId,
                market: ({
                  matchResult: "Résultat du match",
                  doubleChance: "Double chance",
                  goalsTotal: "Plus/Moins de buts",
                  bothTeamsScore: "Les deux équipes marquent",
                })[marketId],
                selection,
                odds,
                oddsAt,
                bookmaker: String(bookmaker.name),
                snapshotId: source.id,
                evidence: [
                  ...ev,
                  ...evidence(
                    selected.filter((r) => !support.includes(r)),
                    source,
                    [...pref.readings, ...scenarioReadings],
                  ).map((e) => ({ ...e, supportsMarket: false })),
                  ...counter.filter((e) =>
                    !ev.some((direct) => direct.id === e.id)
                  ),
                  ...radar,
                ],
                warnings: [
                  ...(counter.length
                    ? [
                      "Des lectures concernant l’adversaire ou le marché opposé appellent à la vigilance.",
                    ]
                    : []),
                  ...(radar.length
                    ? [
                      "Activité des joueurs et production de leur équipe peuvent se recouper : le Radar ne constitue pas une preuve indépendante.",
                    ]
                    : []),
                  ...rows(source.payload.bilan).filter((b) =>
                    String(b.league_id) === competitionId &&
                    support.some((r) => r.id === b.reading_id)
                  ).map((b) =>
                    `Bilan descriptif sur 90 jours : ${b.confirmed}/${b.evaluable} lectures « ${b.reading_label} » confirmées. Observation historique, ni probabilité de réussite ni rentabilité ; aucune validation prédictive.`
                  ),
                  ...(discovery
                    ? ["Découverte : compétition hors de vos préférences."]
                    : []),
                  ...(new Set(ev.map((e) => e.family)).size < ev.length
                    ? [
                      "Certaines lectures partagent la même famille de données ; elles ne constituent pas des preuves indépendantes.",
                    ]
                    : []),
                ],
                discovery,
              });
              // Scenario evidence reuses the underlying readings, never adds
              // an independent family or a second predictive proof.
              const candidate = candidates.at(-1)!;
              for (const scenario of scenarios) {
                const required = Array.isArray(scenario.required_reading_ids)
                  ? scenario.required_reading_ids.map(String)
                  : [];
                if (
                  !required.length || !required.every((id) =>
                    selected.some((r) => r.id === id)
                  ) ||
                  !support.some((r) => required.includes(String(r.id)))
                ) continue;
                candidate.evidence.push({
                  id: `${source.id}:scenario:${scenario.id}:${scenario.side}`,
                  source: "scenario",
                  family: "derived",
                  label: String(scenario.label ?? scenario.id),
                  subject: String(scenario.subject_team_id ?? scenario.side),
                  sample: Number(scenario.sample_size ?? 0),
                  asOf: source.capturedAt,
                  text: rows(scenario.evidence).map((e) =>
                    String(e.label ?? "")
                  ).join(" "),
                });
                candidate.warnings.push(
                  `Le scénario « ${
                    scenario.label ?? scenario.id
                  } » réutilise ses lectures : il ne constitue pas une preuve indépendante supplémentaire.`,
                );
              }
            }
          }
        }
      }
    }
  }
  if (!candidates.length) {
    missing.add(
      "Aucune sélection avec marché autorisé, cote récente et lecture exploitable n’a été vérifiée.",
    );
  }
  return {
    candidates,
    matchCount,
    radarCount: signals.size,
    missing: [...missing],
    sources: [...sourceIds],
    signals: [...signals.values()].slice(0, 30),
    matches,
  };
}
