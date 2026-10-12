/** Read-only pre-match dossier. No provider calls, model calls or betting rules. */
type Json = Record<string, unknown>;
const obj = (v: unknown): Json =>
  v && typeof v === "object" && !Array.isArray(v) ? v as Json : {};
const rows = (v: unknown): Json[] => Array.isArray(v) ? v.map(obj) : [];
const num = (v: unknown): number | null =>
  typeof v === "number" && Number.isFinite(v) ? v : null;
const str = (v: unknown): string | null =>
  typeof v === "string" && v.trim() ? v : null;
const time = (v: unknown): number | null => {
  const t = Date.parse(String(v ?? ""));
  return Number.isFinite(t) ? t : null;
};
const european = (id: unknown) => [2, 3, 848].includes(Number(id));
export type CachedContextSource = {
  endpoint: string;
  query_params: Json;
  fetched_at: string;
  as_of: string;
  response_body: unknown;
  source?: string;
  query_hash?: string;
  sync_run_id?: string | null;
  response_status?: number;
};

/** Domestic year comes from the league calendar, never from the European year. */
export function resolveEuropeanDomesticContexts<S extends CachedContextSource>(
  fixtures: Json[],
  standings: S[],
  leagues: S[],
) {
  const contexts: Json[] = [], selected = new Map<string, S>();
  for (const target of fixtures) {
    const f = obj(target.fixture),
      kickoff = time(f.date),
      teams = obj(target.teams);
    if (!european(obj(target.league).id) || kickoff === null) continue;
    for (const side of ["home", "away"]) {
      const team = obj(teams[side]), teamId = num(team.id);
      if (teamId === null) continue;
      const candidates: { source: S; league: Json; season: Json }[] = [];
      for (const source of standings) {
        for (const response of rows(obj(source.response_body).response)) {
          const league = obj(response.league);
          if (european(league.id) || league.country === "World") {
            continue;
          }
          if (
            !rows(league.standings).length && !Array.isArray(league.standings)
          ) continue;
          const groups = Array.isArray(league.standings)
            ? league.standings
            : [];
          if (
            !groups.some((g) =>
              rows(g).some((s) => num(obj(s.team).id) === teamId)
            )
          ) continue;
          for (const metadata of leagues) {
            for (const entry of rows(obj(metadata.response_body).response)) {
              if (
                num(obj(entry.league).id) !== num(league.id) ||
                obj(entry.league).type !== "League"
              ) continue;
              const begun = rows(entry.seasons)
                .filter((s) => (time(s.start) ?? Infinity) <= kickoff)
                .sort((a, b) => (time(b.start) ?? 0) - (time(a.start) ?? 0));
              const current = begun[0];
              if (current) {
                const start = time(current.start), end = time(current.end);
                // The last completed domestic season remains useful for a final
                // played during the break, until a new season has actually begun.
                if (
                  num(current.year) === num(league.season) && start !== null &&
                  end !== null && kickoff < end + 120 * 86400000
                ) {
                  candidates.push({ source, league, season: current });
                }
              }
            }
          }
        }
      }
      // Ambiguous membership stays unresolved rather than choosing a random league.
      const identities = new Set(
        candidates.map((c) => `${c.league.id}:${c.league.season}`),
      );
      if (identities.size !== 1) continue;
      candidates.sort((a, b) =>
        (time(b.source.fetched_at) ?? 0) - (time(a.source.fetched_at) ?? 0)
      );
      const c = candidates.find((c) =>
        (time(c.source.fetched_at) ?? Infinity) < kickoff
      ) ?? candidates[0];
      contexts.push({
        fixture_id: f.id,
        fixture_date: String(f.date).slice(0, 10),
        team: { id: teamId, name: team.name },
        league: {
          id: c.league.id,
          name: c.league.name,
          country: c.league.country,
          logo: c.league.logo,
          season: c.league.season,
        },
        season_start: c.season.start,
        season_end: c.season.end,
        context_period_valid: true,
        observed_at: c.source.fetched_at,
      });
      selected.set(`${c.league.id}:${c.league.season}`, c.source);
    }
  }
  return {
    contexts,
    sourceRows: [...selected.values()],
    standings: [...selected.values()].flatMap((s) =>
      rows(obj(s.response_body).response).map((r) => ({
        ...r,
        observed_at: s.fetched_at,
      }))
    ),
  };
}

export function buildEuropeanComparisons(
  payload: Json,
  now = new Date(),
): Json[] {
  const raw = obj(payload.raw), capturedAt = str(payload.captured_at);
  const sources = rows(raw.context_sources), pool = rows(raw.league_fixtures);
  const sourceFor = (
    endpoint: string,
    leagueId: number,
    season: number,
    teamId?: number,
  ) =>
    sources.filter((s) => {
      const q = obj(s.query_params);
      return s.endpoint === endpoint && Number(q.league) === leagueId &&
        Number(q.season) === season &&
        (teamId === undefined || Number(q.team) === teamId);
    });
  const observation = (
    endpoint: string,
    leagueId: number,
    season: number,
    kickoff: number,
    teamId?: number,
  ) => {
    const candidates = sourceFor(endpoint, leagueId, season, teamId).map((s) =>
      str(s.fetched_at)
    ).filter((s): s is string => s !== null);
    const prior = candidates.filter((s) => (time(s) ?? Infinity) < kickoff)
      .sort();
    return prior.at(-1) ?? candidates.sort().at(-1) ?? capturedAt;
  };
  return rows(raw.fixtures).filter((f) => european(obj(f.league).id)).flatMap(
    (target) => {
      const fixture = obj(target.fixture),
        league = obj(target.league),
        teams = obj(target.teams),
        kickoff = time(fixture.date);
      const leagueId = num(league.id), season = num(league.season);
      if (
        kickoff === null || leagueId === null || season === null ||
        num(fixture.id) === null
      ) return [];
      const quality: string[] = [];
      const normalize = (
        row: Json,
        teamId: number,
        competitionId: number,
        year: number,
        observedAt: string | null,
      ): Json | null => {
        const f = obj(row.fixture),
          l = obj(row.league),
          t = obj(row.teams),
          h = obj(t.home),
          a = obj(t.away),
          g = obj(row.goals);
        const playedAt = time(f.date),
          observed = time(row.observed_at ?? observedAt);
        if (
          num(l.id) !== competitionId || num(l.season) !== year ||
          !["FT", "AET", "PEN"].includes(String(obj(f.status).short)) ||
          playedAt === null || playedAt >= kickoff ||
          num(f.id) === num(fixture.id) ||
          (num(h.id) !== teamId && num(a.id) !== teamId)
        ) return null;
        // API has no final-whistle timestamp. Late captures cannot certify a close
        // preceding fixture: retain only games at least a day before the cutoff.
        if (
          (observed === null || observed >= kickoff) &&
          playedAt + 86400000 > kickoff
        ) return null;
        const home = num(h.id) === teamId,
          gf = num(home ? g.home : g.away),
          ga = num(home ? g.away : g.home);
        if (
          gf === null || ga === null || num(f.id) === null ||
          num((home ? a : h).id) === null
        ) return null;
        return {
          fixtureId: f.id,
          competitionId,
          competitionName: l.name,
          season: year,
          round: l.round ?? null,
          playedAt: f.date,
          opponentTeamId: (home ? a : h).id,
          opponentName: (home ? a : h).name ?? "Adversaire",
          opponentLogo: (home ? a : h).logo ?? null,
          venue: home ? "home" : "away",
          result: obj(f.status).short === "PEN" &&
              typeof (home ? h : a).winner === "boolean"
            ? ((home ? h : a).winner ? "W" : "L")
            : gf > ga
            ? "W"
            : gf === ga
            ? "D"
            : "L",
          goalsFor: gf,
          goalsAgainst: ga,
          penaltyDecision: obj(f.status).short === "PEN",
          observedAt: str(row.observed_at) ?? observedAt,
        };
      };
      const matches = (teamId: number, id: number, year: number) => {
        const stamp = observation("/fixtures", id, year, kickoff);
        const unique = new Map<number, Json>();
        for (const row of pool) {
          const m = normalize(row, teamId, id, year, stamp);
          if (m) unique.set(Number(m.fixtureId), m);
        }
        return [...unique.values()].sort((a, b) =>
          Number(time(a.playedAt)) - Number(time(b.playedAt))
        );
      };
      const standing = (teamId: number, id: number, year: number) => {
        for (
          const row of rows(raw.standings).sort((a, b) =>
            (time(b.observed_at ?? capturedAt) ?? 0) -
            (time(a.observed_at ?? capturedAt) ?? 0)
          )
        ) {
          const stamp = str(row.observed_at) ?? capturedAt,
            observed = time(stamp);
          if (observed === null || observed >= kickoff) continue;
          const l = obj(row.league);
          if (num(l.id) !== id || num(l.season) !== year) continue;
          for (const group of Array.isArray(l.standings) ? l.standings : []) {
            for (const s of rows(group)) {
              if (num(obj(s.team).id) !== teamId) {
                continue;
              }
              const all = obj(s.all), goals = obj(all.goals);
              return {
                teamId,
                teamName: obj(s.team).name,
                rank: num(s.rank),
                points: num(s.points),
                played: num(all.played),
                wins: num(all.win),
                draws: num(all.draw),
                losses: num(all.lose),
                goalsFor: num(goals.for),
                goalsAgainst: num(goals.against),
                goalDiff: num(s.goalsDiff),
                group: str(s.group),
                observedAt: stamp,
              };
            }
          }
        }
        return null;
      };
      const summary = (ms: Json[]) =>
        ms.length
          ? {
            played: ms.length,
            wins: ms.filter((m) => m.result === "W").length,
            draws: ms.filter((m) => m.result === "D").length,
            losses: ms.filter((m) => m.result === "L").length,
            goalsFor: ms.reduce((n, m) => n + Number(m.goalsFor), 0),
            goalsAgainst: ms.reduce((n, m) => n + Number(m.goalsAgainst), 0),
            points: ms.reduce(
              (n, m) => n + (m.result === "W" ? 3 : m.result === "D" ? 1 : 0),
              0,
            ),
            fixtureIds: ms.map((m) => m.fixtureId),
          }
          : null;
      const phase = (round: unknown) =>
        /knockout/i.test(String(round))
          ? "knockout"
          : /qualif|preliminary|play-off/i.test(String(round))
          ? "qualification"
          : /league stage|group stage|regular season/i.test(String(round))
          ? "league"
          : "knockout";
      const teamContext = (side: string) => {
        const team = obj(teams[side]), teamId = num(team.id)!;
        const domestic = rows(raw.domestic_team_contexts).find((c) =>
          num(obj(c.team).id) === teamId &&
          (c.fixture_id === undefined || num(c.fixture_id) === num(fixture.id))
        );
        const dl = obj(domestic?.league),
          ds = num(dl.season),
          di = num(dl.id),
          start = time(domestic?.season_start),
          end = time(domestic?.season_end);
        const validDomestic = di !== null && ds !== null && start !== null &&
          end !== null && kickoff >= start &&
          (kickoff < end + 86400000 ||
            domestic?.context_period_valid === true &&
              kickoff < end + 120 * 86400000);
        let dm = validDomestic ? matches(teamId, di!, ds!) : [];
        // Normalized history fallback requires explicit season and date, never an
        // undated form string nor a season guessed from the European competition.
        if (validDomestic && !dm.length) {
          for (const r of rows(raw.recent_league_matches)) {
            if (
              num(obj(r.league).id) !== di ||
              num(obj(r.league).season) !== ds || num(obj(r.team).id) !== teamId
            ) {
              continue;
            }
            const stamp = observation("/fixtures", di!, ds!, kickoff);
            dm = rows(r.matches).flatMap((m) => {
              const f = obj(m.fixture),
                t = time(f.date),
                gf = num(obj(m.goals).for),
                ga = num(obj(m.goals).against);
              if (
                t === null || t >= kickoff || gf === null || ga === null ||
                num(f.id) === null || num(f.id) === num(fixture.id) ||
                ((time(stamp) ?? Infinity) >= kickoff && t + 86400000 > kickoff)
              ) return [];
              return [{
                fixtureId: f.id,
                competitionId: di,
                competitionName: dl.name,
                season: ds,
                round: null,
                playedAt: f.date,
                opponentTeamId: obj(m.opponent).id,
                opponentName: obj(m.opponent).name ?? "Adversaire",
                opponentLogo: obj(m.opponent).logo ?? null,
                venue: m.venue,
                result: gf > ga ? "W" : gf === ga ? "D" : "L",
                goalsFor: gf,
                goalsAgainst: ga,
                penaltyDecision: false,
                observedAt: stamp,
              }];
            }).sort((a, b) =>
              Number(time(a.playedAt)) - Number(time(b.playedAt))
            );
          }
        }
        dm = [...new Map(dm.map((m) => [m.fixtureId, m])).values()].slice(-5);
        const em = matches(teamId, leagueId, season),
          currentPhase = phase(league.round);
        const phaseMatches = em.filter((m) => phase(m.round) === currentPhase);
        const es = standing(teamId, leagueId, season);
        const domesticStanding = validDomestic
          ? standing(teamId, di!, ds!)
          : null;
        const fixtureSources = sourceFor("/fixtures", leagueId, season);
        const invalidResults = pool.some((r) => {
          const l = obj(r.league),
            ts = obj(r.teams),
            f = obj(r.fixture),
            d = time(f.date);
          return num(l.id) === leagueId && num(l.season) === season &&
            [num(obj(ts.home).id), num(obj(ts.away).id)].includes(teamId) &&
            ["FT", "AET", "PEN"].includes(String(obj(f.status).short)) &&
            (d === null || d < kickoff) &&
            (num(obj(r.goals).home) === null ||
              num(obj(r.goals).away) === null || d === null);
        });
        if (invalidResults) {
          quality.push(
            `${team.name} : certains résultats européens sont incomplets et sont exclus du bilan.`,
          );
        }
        const complete = !invalidResults && fixtureSources.some((s) => {
          const q = obj(s.query_params);
          return q.team === undefined && q.from === undefined &&
            q.to === undefined && q.date === undefined &&
            q.round === undefined && q.last === undefined &&
            q.status === undefined && q.ids === undefined;
        });
        const domesticState = !validDomestic
          ? "missing"
          : !dm.length
          ? "missing"
          : !domesticStanding || dm.length < 5
          ? "partial"
          : "available";
        const europeanState = !complete
          ? "partial"
          : phaseMatches.length && phaseMatches.length < 3
          ? "partial"
          : "available";
        if (!validDomestic) {
          quality.push(
            `${team.name} : championnat ou saison domestique non résolu dans le cache.`,
          );
        } else if (!domesticStanding) {
          quality.push(
            `${team.name} : classement domestique antérieur au match indisponible.`,
          );
        }
        if (!complete) {
          quality.push(
            `${team.name} : couverture du calendrier européen non certifiée.`,
          );
        }
        return {
          teamId,
          name: team.name,
          logo: team.logo ?? null,
          domesticCompetition: validDomestic ? dl : null,
          domesticStanding,
          domesticSeasonStart: domestic?.season_start ?? null,
          domesticSeasonEnd: domestic?.season_end ?? null,
          domesticSeasonEnded: validDomestic && kickoff >= end! + 86400000,
          domesticRecentMatches: dm,
          domesticSummary: summary(dm),
          domesticState,
          europeanRecentMatches: em,
          europeanStanding: currentPhase === "league" ? es : null,
          europeanSummary: summary(phaseMatches),
          europeanState,
          europeanPhase: currentPhase,
          europeanPhaseMatches: phaseMatches,
          europeanCoverageComplete: complete,
          domesticObservedAt:
            dm.map((m) => str(m.observedAt)).filter((v): v is string =>
              v !== null
            ).sort().at(-1) ?? null,
          europeanObservedAt:
            em.map((m) => str(m.observedAt)).filter((v): v is string =>
              v !== null
            ).sort().at(-1) ??
              fixtureSources.filter((s) =>
                Object.keys(obj(s.query_params)).every((k) =>
                  ["league", "season", "timezone"].includes(k)
                )
              ).map((s) => str(s.fetched_at)).filter((v): v is string =>
                v !== null
              ).sort().at(-1) ?? null,
          dataAsOf: fixture.date,
        };
      };
      const home = teamContext("home"), away = teamContext("away");
      const h2h = rows(raw.head_to_head).filter((r) =>
        num(obj(r.fixture).id) === num(fixture.id)
      ).flatMap((r) => rows(r.matches)).filter((m) => {
        const t = obj(m.teams),
          ids = [num(obj(t.home).id), num(obj(t.away).id)],
          d = time(obj(m.fixture).date);
        return d !== null && d + 86400000 < kickoff &&
          ids.includes(Number(home.teamId)) &&
          ids.includes(Number(away.teamId)) &&
          num(obj(m.goals).home) !== null && num(obj(m.goals).away) !== null;
      }).sort((a, b) =>
        Number(time(obj(b.fixture).date)) - Number(time(obj(a.fixture).date))
      ).slice(0, 20);
      const priorLeg = home.europeanRecentMatches as Json[];
      const firstLeg = phase(league.round) === "knockout" &&
          /(?:-\s*2|second leg|2nd leg)$/i.test(String(league.round))
        ? priorLeg.filter((m) =>
          Number(m.opponentTeamId) === Number(away.teamId) &&
          String(m.round).replace(/\s*-\s*\d+$/, "") ===
            String(league.round).replace(/\s*-\s*\d+$/, "")
        ).at(-1)
        : undefined;
      const observed = time(capturedAt);
      if (observed !== null && observed >= kickoff) {
        quality.push(
          "Consultation historique : les classements collectés après le coup d’envoi sont exclus. Les résultats antérieurs sont reconstitués à partir des rencontres finalisées.",
        );
      }
      const notices: Json[] = [];
      for (const t of [home, away]) {
        const d = t.domesticSummary as Json | null,
          e = t.europeanSummary as Json | null;
        if (d) {
          notices.push({
            kind: "fact",
            text: `${t.name} : ${d.points}/${
              Number(d.played) * 3
            } points sur ${d.played} matchs de championnat, ${d.goalsFor} buts marqués et ${d.goalsAgainst} encaissés.`,
            fixtureIds: d.fixtureIds,
          });
        }
        if (
          d && e && t.europeanPhase === "league" && Number(e.played) >= 3 &&
          ((Number(d.points) / Number(d.played) >= 2 &&
            Number(e.points) / Number(e.played) < 1.5) ||
            (Number(d.points) / Number(d.played) < 1.5 &&
              Number(e.points) / Number(e.played) >= 2))
        ) {
          notices.push({
            kind: "contradiction",
            text: `${t.name} : rendement différent en championnat (${
              (Number(d.points) / Number(d.played)).toFixed(2)
            } pt/match) et en Europe (${
              (Number(e.points) / Number(e.played)).toFixed(2)
            }). Adversaires et échantillons différents.`,
            fixtureIds: [
              ...d.fixtureIds as unknown[],
              ...e.fixtureIds as unknown[],
            ],
          });
        }
        if (e && Number(e.played) < 3) {
          notices.push({
            kind: "limit",
            text:
              `${t.name} : seulement ${e.played} résultat(s) dans cette phase européenne ; conclusions limitées.`,
            fixtureIds: e.fixtureIds,
          });
        }
      }
      if (home.domesticSummary && away.domesticSummary) {
        const h = home.domesticSummary as Json,
          a = away.domesticSummary as Json;
        const hp = Number(h.points) / Number(h.played),
          ap = Number(a.points) / Number(a.played);
        notices.push({
          kind: "comparison",
          text: `Rendement récent en championnat : ${
            hp.toFixed(2)
          } pt/match pour ${home.name}, ${
            ap.toFixed(2)
          } pour ${away.name}. Championnats et adversaires différents ; cet écart ne mesure pas une force absolue.`,
          fixtureIds: [
            ...h.fixtureIds as unknown[],
            ...a.fixtureIds as unknown[],
          ],
        });
      }
      return [{
        schemaVersion: 1,
        fixtureId: fixture.id,
        kickoffAt: fixture.date,
        competition: { id: leagueId, name: league.name, season },
        round: league.round ?? null,
        home,
        away,
        headToHead: [
          ...new Map(h2h.map((m) => [obj(m.fixture).id, {
            fixture: {
              id: obj(m.fixture).id,
              date: obj(m.fixture).date,
              status: obj(m.fixture).status,
            },
            league: {
              id: obj(m.league).id,
              name: obj(m.league).name,
              season: obj(m.league).season,
              round: obj(m.league).round,
            },
            teams: {
              home: {
                id: obj(obj(m.teams).home).id,
                name: obj(obj(m.teams).home).name,
              },
              away: {
                id: obj(obj(m.teams).away).id,
                name: obj(obj(m.teams).away).name,
              },
            },
            goals: { home: obj(m.goals).home, away: obj(m.goals).away },
          }])).values(),
        ],
        firstLeg: firstLeg ?? null,
        aggregate: firstLeg
          ? {
            homeGoals: firstLeg.goalsFor,
            awayGoals: firstLeg.goalsAgainst,
            matchesPlayed: 1,
            asOf: fixture.date,
          }
          : null,
        notices,
        dataQuality: {
          state: quality.length ? "partial" : "available",
          limitations: [...new Set(quality)],
          capturedAt,
          stale: kickoff > now.getTime() &&
            [
              home.domesticObservedAt,
              away.domesticObservedAt,
              home.europeanObservedAt,
              away.europeanObservedAt,
            ].map(time).some((t) =>
              t !== null && now.getTime() - t > 36 * 3600000
            ),
        },
        provenance: sources.filter((s) => {
          const q = obj(s.query_params);
          return ["/fixtures", "/standings", "/leagues", "/fixtures/headtohead"]
            .includes(String(s.endpoint)) &&
            ([
              leagueId,
              num(obj(home.domesticCompetition).id),
              num(obj(away.domesticCompetition).id),
            ].includes(Number(q.league ?? q.id)) ||
              s.endpoint === "/fixtures/headtohead" &&
                String(q.h2h).split("-").map(Number).includes(
                  Number(home.teamId),
                ));
        }).map((s) => ({
          endpoint: s.endpoint,
          query: s.query_params,
          observedAt: s.fetched_at,
        })),
        dataAsOf: fixture.date,
      }];
    },
  );
}
