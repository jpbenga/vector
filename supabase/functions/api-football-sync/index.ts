import {
  collectOddsPages,
  fixtureBodyForDate,
  footballCalendarDays,
  oddsDatesForFixtures,
  usesDatedFixtureSource,
} from "../_shared/football_calendar_policy.ts";
import {
  eligibleHeadToHeadFixtureIds,
} from "../_shared/head_to_head_history.ts";
import { fixtureSample, OpsReporter } from "../_shared/ops_runtime.ts";

type JsonObject = Record<string, unknown>;

type EnrichmentTask = {
  endpoint: string;
  query: Record<string, string>;
  ttlSeconds: number;
  kind:
    | "injury"
    | "players"
    | "player_page"
    | "fixture_statistics"
    | "fixture_events"
    | "fixture_players"
    | "club_fixtures";
};

const source = "api-football";
const defaultBaseUrl = "https://v3.football.api-sports.io";
const defaultTimezone = "Europe/Paris";
const maxDays = footballCalendarDays;
const maxLeagues = 40;
// Enrichment is processed in small resumable batches. The limit is per worker
// invocation, not per competition or per daily run.
const enrichmentBatchSize = 40;
const injuryCollectionWindowMs = 24 * 60 * 60 * 1000;
const defaultRecentFormDaysBack = 180;
// Keep enough completed fixtures to establish a decisive run beyond the
// three-match Radar window. Existing football readings still use their own
// explicit five/three-match windows.
const defaultRecentFormMatches = 5;
const defaultApiRequestDelayMs = 220;
const apiFootballRequestTimeoutMs = 30 * 1000;
const supabaseRequestTimeoutMs = 30 * 1000;
const apiFootballDailyRequestLimit = 75000;
const apiFootballMinuteRequestLimit = 280;

const corsHeaders = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers":
    "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return jsonResponse({ ok: true }, 200);
  }

  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  const authError = authorizeSyncRequest(request);
  if (authError !== null) {
    return jsonResponse({ error: authError }, 401);
  }

  const apiKey = requireEnv("API_FOOTBALL_KEY");
  const supabaseUrl = requireEnv("SUPABASE_URL");
  const serviceRoleKey = requireEnv("SUPABASE_SERVICE_ROLE_KEY");
  const apiBaseUrl = Deno.env.get("API_FOOTBALL_BASE_URL") ?? defaultBaseUrl;
  const payload = await readJson(request);
  const apiRequestDelayMs = Math.max(
    0,
    numberValue(payload.api_request_delay_ms) ??
      numberValue(Deno.env.get("API_FOOTBALL_REQUEST_DELAY_MS")) ??
      defaultApiRequestDelayMs,
  );
  const options = syncOptionsFromPayload(payload);
  const batchCursor = objectValue(payload.ops_batch_cursor) ?? {};

  let runId: string | null = null;
  const summary: SyncSummary = {
    leagues: 0,
    fixtures: 0,
    upcomingFixtures: 0,
    odds: 0,
    standings: 0,
    leagueFixtureRows: 0,
    teamStatistics: 0,
    recentFixtureRows: 0,
    fixtureStatistics: 0,
    fixtureEvents: 0,
    fixturePlayerStatistics: 0,
    headToHead: 0,
    injuries: 0,
    playerStatisticsRequests: 0,
    playerStatisticsPages: 0,
    playerStatisticsPlayers: 0,
    cachedResponses: 0,
    providerRequests: 0,
    leagueSeasons: {},
  };
  const reporter = new OpsReporter(payload);
  const fetchAndAccount = async (options: FetchAndCacheOptions) => {
    await reporter.checkpoint({ ...summary, endpoint: options.endpoint });
    const response = await fetchAndCache({
      ...options,
      onProviderRequest: () => {
        summary.providerRequests += 1;
      },
    });
    await reporter.checkpoint({ ...summary, endpoint: options.endpoint }, {
      ...fixtureSample(response.body),
      ...(Object.keys(fixtureSample(response.body)).length
        ? { from_cache: response.fromCache, fetched_at: response.fetchedAt }
        : {}),
    });
    return response;
  };
  const fixtureStatisticsIds = new Set<number>();
  const fixturePlayerStatisticsIds = new Set<number>();
  const selectionRecentFixtureIdsByTeam = new Map<number, number[]>();
  const selectionTeamSeasons = new Map<number, number>();
  const injuryFixtureIds = new Set<number>();
  const playerStatisticsTeams = new Map<
    string,
    { leagueId: number; season: number; teamId: number }
  >();
  const headToHeadPairs = new Set<string>();
  const headToHeadReferences = new Map<string, string>();
  const headToHeadFixtureIds = new Set<number>();

  try {
    await markStaleSyncRuns({
      supabaseUrl,
      serviceRoleKey,
      exceptRunId: stringValue(batchCursor.run_id) ?? undefined,
    });
    const continuedRunId = stringValue(batchCursor.run_id);
    const run = continuedRunId === null
      ? await insertSyncRun({
        supabaseUrl,
        serviceRoleKey,
        options,
        requestPayload: payload,
      })
      : await findSyncRun({
        supabaseUrl,
        serviceRoleKey,
        runId: continuedRunId,
      });
    if (
      continuedRunId !== null &&
      (run.status !== "running" ||
        JSON.stringify(run.league_ids) !== JSON.stringify(options.leagueIds))
    ) {
      throw new Error(
        "La collecte liée au lot n’est plus disponible pour reprise.",
      );
    }
    runId = String(run.id);

    for (const leagueId of options.leagueIds) {
      const leagueInfo = await fetchAndAccount({
        apiBaseUrl,
        apiKey,
        supabaseUrl,
        serviceRoleKey,
        runId,
        endpoint: "/leagues",
        query: {
          id: String(leagueId),
        },
        ttlSeconds: 24 * 60 * 60,
        requestDelayMs: apiRequestDelayMs,
      });
      const leagueSeason = seasonForWindowFromLeaguesPayload(
        leagueInfo.body,
        options.fallbackSeason,
        options.windowStart,
        options.windowEnd,
      );
      summary.leagueSeasons[String(leagueId)] = leagueSeason;
      summary.leagues += 1;
      summary.cachedResponses += 1;

      await fetchAndAccount({
        apiBaseUrl,
        apiKey,
        supabaseUrl,
        serviceRoleKey,
        runId,
        endpoint: "/standings",
        query: {
          league: String(leagueId),
          season: String(leagueSeason),
        },
        ttlSeconds: 60 * 60,
        requestDelayMs: apiRequestDelayMs,
      });
      summary.standings += 1;
      summary.cachedResponses += 1;

      // Keep the complete league fixture history in the cache. The snapshot
      // builder uses it to derive first/second-leg and half-time tables
      // without making any additional API calls during match analysis.
      const leagueFixtures = await fetchAndAccount({
        apiBaseUrl,
        apiKey,
        supabaseUrl,
        serviceRoleKey,
        runId,
        endpoint: "/fixtures",
        query: {
          league: String(leagueId),
          season: String(leagueSeason),
          timezone: options.timezone,
        },
        ttlSeconds: 6 * 60 * 60,
        requestDelayMs: apiRequestDelayMs,
      });
      summary.leagueFixtureRows += responseRows(leagueFixtures.body).length;
      summary.cachedResponses += 1;
      const leagueTeamIds = teamIdsFromFixtures(leagueFixtures.body);
      const registerPlayerStatisticsTeam = (teamId: number) => {
        const key = `${leagueId}:${leagueSeason}:${teamId}`;
        playerStatisticsTeams.set(key, {
          leagueId,
          season: leagueSeason,
          teamId,
        });
      };
      const upcomingFixtures = upcomingFixturesInWindow(
        leagueFixtures.body,
        options.windowStart,
        options.windowEnd,
        options.timezone,
      );
      summary.upcomingFixtures += upcomingFixtures;
      if (options.skipEmptyFeed && upcomingFixtures === 0) {
        continue;
      }

      if (options.includeRecentPlayerPerformances) {
        for (
          const teamId of upcomingTeamIdsInWindow(
            leagueFixtures.body,
            options.windowStart,
            options.windowEnd,
            options.timezone,
          )
        ) {
          for (
            const fixtureId of recentFixtureIdsForTeam(
              leagueFixtures.body,
              teamId,
              options.recentFormMatches,
            )
          ) {
            fixturePlayerStatisticsIds.add(fixtureId);
          }
        }
      }

      // Full player activity is deliberately opt-in. A daily multi-league
      // refresh stays bounded, while a targeted competition enrichment can
      // cache every completed fixture sheet for its upcoming teams.
      if (options.includePlayerActivityHistory) {
        const targetTeams = upcomingTeamIdsInWindow(
          leagueFixtures.body,
          options.windowStart,
          options.windowEnd,
          options.timezone,
        );
        for (
          const fixtureId of completedFixtureIdsForTeams(
            leagueFixtures.body,
            targetTeams,
          )
        ) {
          fixturePlayerStatisticsIds.add(fixtureId);
        }
      }

      if (options.includeTeamStatistics) {
        for (
          const teamId of leagueTeamIds
        ) {
          await fetchAndAccount({
            apiBaseUrl,
            apiKey,
            supabaseUrl,
            serviceRoleKey,
            runId,
            endpoint: "/teams/statistics",
            query: {
              league: String(leagueId),
              season: String(leagueSeason),
              team: String(teamId),
            },
            ttlSeconds: 60 * 60,
            requestDelayMs: apiRequestDelayMs,
          });
          summary.teamStatistics += 1;
          summary.cachedResponses += 1;
        }
      }

      if (options.includePlayerStatistics) {
        for (const teamId of leagueTeamIds) {
          registerPlayerStatisticsTeam(teamId);
        }
      }

      if (options.includeExpectedGoals) {
        for (const teamId of leagueTeamIds) {
          for (
            const fixtureId of recentFixtureIdsForTeam(
              leagueFixtures.body,
              teamId,
              options.recentFormMatches,
            )
          ) {
            fixtureStatisticsIds.add(fixtureId);
          }
        }
      }

      const collectedOddsDates = new Set<string>();
      for (const date of dateWindow(options.windowStart, options.windowEnd)) {
        const datedFixtures = usesDatedFixtureSource(date, options.windowStart)
          ? await fetchAndAccount({
            apiBaseUrl,
            apiKey,
            supabaseUrl,
            serviceRoleKey,
            runId,
            endpoint: "/fixtures",
            query: {
              league: String(leagueId),
              season: String(leagueSeason),
              date,
              timezone: options.timezone,
            },
            ttlSeconds: 15 * 60,
            requestDelayMs: apiRequestDelayMs,
          })
          : undefined;
        const fixtures = {
          body: fixtureBodyForDate(
            leagueFixtures.body,
            datedFixtures?.body,
            date,
            options.windowStart,
            options.timezone,
          ),
        };
        summary.fixtures += responseRows(fixtures.body).length;
        if (datedFixtures) summary.cachedResponses += 1;
        for (
          const pair of upcomingHeadToHeadPairs(
            fixtures.body,
            options.windowStart,
            options.windowEnd,
            options.timezone,
          )
        ) {
          headToHeadPairs.add(pair);
        }
        for (const fixture of responseRows(fixtures.body)) {
          const root = objectValue(fixture) ?? {};
          const details = objectValue(root.fixture) ?? {};
          const status = stringValue((objectValue(details.status) ?? {}).short);
          const fixtureId = numberValue(details.id);
          const kickoff = stringValue(details.date);
          const timeUntilKickoff = kickoff === null
            ? null
            : Date.parse(kickoff) - Date.now();
          if (
            fixtureId !== null && timeUntilKickoff !== null &&
            timeUntilKickoff > 0 &&
            timeUntilKickoff <= injuryCollectionWindowMs &&
            ["NS", "TBD"].includes(status ?? "")
          ) {
            injuryFixtureIds.add(fixtureId);
            const teams = objectValue(root.teams) ?? {};
            for (const side of ["home", "away"]) {
              const teamId = numberValue(
                (objectValue(teams[side]) ?? {}).id,
              );
              if (teamId !== null) {
                registerPlayerStatisticsTeam(teamId);
              }
            }
          }
          const teams = objectValue(root.teams) ?? {};
          const homeTeamId = numberValue(
            (objectValue(teams.home) ?? {}).id,
          );
          const awayTeamId = numberValue(
            (objectValue(teams.away) ?? {}).id,
          );
          if (
            kickoff !== null &&
            homeTeamId !== null &&
            awayTeamId !== null &&
            homeTeamId !== awayTeamId &&
            ["NS", "TBD"].includes(status ?? "")
          ) {
            const pair = headToHeadPair(homeTeamId, awayTeamId);
            if (headToHeadPairs.has(pair)) {
              const existing = headToHeadReferences.get(pair);
              if (existing === undefined || kickoff < existing) {
                headToHeadReferences.set(pair, kickoff);
              }
            }
          }
        }

        for (
          const oddsDate of oddsDatesForFixtures(responseRows(fixtures.body))
        ) {
          if (collectedOddsDates.has(oddsDate)) continue;
          collectedOddsDates.add(oddsDate);
          const oddsQuery: Record<string, string> = {
            league: String(leagueId),
            season: String(leagueSeason),
            date: oddsDate,
          };
          if (options.bookmakerId !== null) {
            oddsQuery.bookmaker = String(options.bookmakerId);
          }
          const oddsPages = await collectOddsPages((page) =>
            fetchAndAccount({
              apiBaseUrl,
              apiKey,
              supabaseUrl,
              serviceRoleKey,
              runId: String(runId),
              endpoint: "/odds",
              query: page === 1
                ? oddsQuery
                : { ...oddsQuery, page: String(page) },
              ttlSeconds: 15 * 60,
              requestDelayMs: apiRequestDelayMs,
            })
          );
          for (const odds of oddsPages) {
            summary.odds += responseRows(odds.body).length;
            summary.cachedResponses += 1;
          }
        }

        if (options.includeRecentForm || options.includeExpectedGoals) {
          const fixtureTeamContexts = fixtureTeamContextsFromFixtures(
            fixtures.body,
            leagueId,
          );
          for (const context of fixtureTeamContexts) {
            const recentFrom = subtractDays(
              options.windowStart,
              options.recentFormDaysBack,
            );
            const recentTo = subtractDays(options.windowStart, 1);
            const isNational = isNationalCompetitionId(context.leagueId);
            const recentFixtures = await fetchAndAccount({
              apiBaseUrl,
              apiKey,
              supabaseUrl,
              serviceRoleKey,
              runId,
              endpoint: "/fixtures",
              query: isNational
                ? {
                  team: String(context.teamId),
                  season: String(leagueSeason),
                  from: recentFrom,
                  to: recentTo,
                  timezone: options.timezone,
                }
                : {
                  league: String(context.leagueId),
                  season: String(leagueSeason),
                  team: String(context.teamId),
                  from: recentFrom,
                  to: recentTo,
                  timezone: options.timezone,
                },
              ttlSeconds: 6 * 60 * 60,
              requestDelayMs: apiRequestDelayMs,
            });
            summary.recentFixtureRows += responseRows(recentFixtures.body)
              .length;
            summary.cachedResponses += 1;

            if (options.includeExpectedGoals) {
              for (
                const fixtureId of (isNational
                  ? recentOfficialFixtureIdsForTeam(
                    recentFixtures.body,
                    context.teamId,
                    options.recentFormMatches,
                  )
                  : recentFixtureIdsForTeam(
                    recentFixtures.body,
                    context.teamId,
                    options.recentFormMatches,
                  ))
              ) {
                fixtureStatisticsIds.add(fixtureId);
              }
            }
            if (options.includeRecentPlayerPerformances && isNational) {
              selectionTeamSeasons.set(context.teamId, leagueSeason);
              selectionRecentFixtureIdsByTeam.set(
                context.teamId,
                recentOfficialFixtureIdsForTeam(
                  recentFixtures.body,
                  context.teamId,
                  3,
                ),
              );
              const activityLimit = options.includePlayerActivityHistory
                ? 32
                : 3;
              for (
                const fixtureId of recentOfficialFixtureIdsForTeam(
                  recentFixtures.body,
                  context.teamId,
                  activityLimit,
                )
              ) {
                fixturePlayerStatisticsIds.add(fixtureId);
              }
            }
          }
        }
      }
    }

    // One cache key per unordered pair across the whole window. H2H history
    // is immutable, so a 30-day TTL avoids paying again for every daily run.
    for (const pair of headToHeadPairs) {
      const response = await fetchAndAccount({
        apiBaseUrl,
        apiKey,
        supabaseUrl,
        serviceRoleKey,
        runId,
        endpoint: "/fixtures/headtohead",
        query: { h2h: pair, last: "20" },
        ttlSeconds: 30 * 24 * 60 * 60,
        requestDelayMs: apiRequestDelayMs,
      });
      summary.headToHead += 1;
      summary.cachedResponses += 1;
      const referenceKickoff = headToHeadReferences.get(pair);
      if (referenceKickoff !== undefined) {
        for (
          const fixtureId of eligibleHeadToHeadFixtureIds(
            responseRows(response.body)
              .map((value) => objectValue(value))
              .filter((value): value is JsonObject => value !== null),
            referenceKickoff,
          )
        ) {
          headToHeadFixtureIds.add(fixtureId);
        }
      }
    }

    const phases = [
      "head_to_head_timeline",
      "bulk",
      "player_pages",
      "activity_players",
      "activity_fixtures",
      "activity_sheets",
    ] as const;
    type EnrichmentPhase = typeof phases[number];
    const rawCursor = batchCursor;
    const requestedPhase = typeof rawCursor.phase === "string"
      ? rawCursor.phase
      : "bulk";
    let phaseIndex = Math.max(
      0,
      phases.indexOf(requestedPhase as EnrichmentPhase),
    );
    if (phaseIndex < 0) phaseIndex = 0;
    let offset = Math.max(0, Math.floor(numberValue(rawCursor.offset) ?? 0));
    let remaining = enrichmentBatchSize;
    let processedThisPass = 0;

    const cached = async (
      endpoint: string,
      query: Record<string, string>,
      ttlSeconds: number,
    ) =>
      await fetchAndAccount({
        apiBaseUrl,
        apiKey,
        supabaseUrl,
        serviceRoleKey,
        runId: runId!,
        endpoint,
        query,
        ttlSeconds,
        requestDelayMs: apiRequestDelayMs,
      });

    const tasksForPhase = async (
      phase: EnrichmentPhase,
    ): Promise<EnrichmentTask[]> => {
      if (phase === "bulk") {
        const tasks: EnrichmentTask[] = [];
        for (const fixtureId of [...injuryFixtureIds].sort((a, b) => a - b)) {
          tasks.push({
            endpoint: "/injuries",
            query: { fixture: String(fixtureId) },
            ttlSeconds: 3600,
            kind: "injury",
          });
        }
        for (
          const context of [...playerStatisticsTeams.values()].sort((a, b) =>
            a.leagueId - b.leagueId || a.teamId - b.teamId
          )
        ) {
          tasks.push({
            endpoint: "/players",
            query: {
              league: String(context.leagueId),
              season: String(context.season),
              team: String(context.teamId),
              page: "1",
            },
            ttlSeconds: 6 * 3600,
            kind: "player_page",
          });
        }
        if (options.includeExpectedGoals) {
          for (
            const fixtureId of [...fixtureStatisticsIds].sort((a, b) => a - b)
          ) {
            tasks.push({
              endpoint: "/fixtures/statistics",
              query: { fixture: String(fixtureId) },
              ttlSeconds: 7 * 86400,
              kind: "fixture_statistics",
            });
            tasks.push({
              endpoint: "/fixtures/events",
              query: { fixture: String(fixtureId) },
              ttlSeconds: 7 * 86400,
              kind: "fixture_events",
            });
          }
        }
        for (
          const fixtureId of [...fixturePlayerStatisticsIds].sort((a, b) =>
            a - b
          )
        ) {
          tasks.push({
            endpoint: "/fixtures/players",
            query: { fixture: String(fixtureId) },
            ttlSeconds: 30 * 86400,
            kind: "fixture_players",
          });
        }
        return tasks;
      }

      if (phase === "head_to_head_timeline") {
        return [...headToHeadFixtureIds]
          .sort((left, right) => left - right)
          .flatMap((fixtureId) => [
            {
              endpoint: "/fixtures/events",
              query: { fixture: String(fixtureId) },
              ttlSeconds: 30 * 86400,
              kind: "fixture_events" as const,
            },
            {
              endpoint: "/fixtures/statistics",
              query: { fixture: String(fixtureId) },
              ttlSeconds: 30 * 86400,
              kind: "fixture_statistics" as const,
            },
          ]);
      }

      if (phase === "player_pages") {
        const tasks: EnrichmentTask[] = [];
        for (
          const context of [...playerStatisticsTeams.values()].sort((a, b) =>
            a.leagueId - b.leagueId || a.teamId - b.teamId
          )
        ) {
          const query = {
            league: String(context.leagueId),
            season: String(context.season),
            team: String(context.teamId),
            page: "1",
          };
          const firstPage = await cached("/players", query, 6 * 3600);
          const total = numberValue(
            (objectValue(firstPage.body.paging) ?? {}).total,
          ) ?? 1;
          for (let page = 2; page <= total; page += 1) {
            tasks.push({
              endpoint: "/players",
              query: { ...query, page: String(page) },
              ttlSeconds: 6 * 3600,
              kind: "player_page",
            });
          }
        }
        return tasks;
      }

      if (!options.includePlayerActivityHistory) return [];

      if (phase === "activity_players") {
        const fixturePlayerPayloads = new Map<number, JsonObject>();
        for (
          const fixtureId of [...fixturePlayerStatisticsIds].sort((a, b) =>
            a - b
          )
        ) {
          const response = await cached("/fixtures/players", {
            fixture: String(fixtureId),
          }, 30 * 86400);
          fixturePlayerPayloads.set(fixtureId, response.body);
        }
        const candidates = decisiveSelectionPlayerCandidates({
          recentFixtureIdsByTeam: selectionRecentFixtureIdsByTeam,
          selectionTeamSeasons,
          fixturePlayerPayloads,
        });
        return candidates.map((candidate) => ({
          endpoint: "/players",
          query: {
            id: String(candidate.playerId),
            season: String(candidate.season),
          },
          ttlSeconds: 6 * 3600,
          kind: "players",
        }));
      }

      if (phase === "activity_fixtures") {
        const clubContexts = new Map<
          string,
          { teamId: number; season: number }
        >();
        const fixturePlayerPayloads = new Map<number, JsonObject>();
        for (
          const fixtureId of [...fixturePlayerStatisticsIds].sort((a, b) =>
            a - b
          )
        ) {
          const response = await cached("/fixtures/players", {
            fixture: String(fixtureId),
          }, 30 * 86400);
          fixturePlayerPayloads.set(fixtureId, response.body);
        }
        const candidates = decisiveSelectionPlayerCandidates({
          recentFixtureIdsByTeam: selectionRecentFixtureIdsByTeam,
          selectionTeamSeasons,
          fixturePlayerPayloads,
        });
        for (const candidate of candidates) {
          const profile = await cached("/players", {
            id: String(candidate.playerId),
            season: String(candidate.season),
          }, 6 * 3600);
          for (
            const club of clubContextsFromPlayerStatistics(
              profile.body,
              candidate.selectionTeamId,
              candidate.season,
            )
          ) clubContexts.set(`${club.teamId}:${club.season}`, club);
        }
        return [...clubContexts.values()].sort((a, b) =>
          a.teamId - b.teamId || a.season - b.season
        ).map((context) => ({
          endpoint: "/fixtures",
          query: {
            team: String(context.teamId),
            season: String(context.season),
            timezone: options.timezone,
          },
          ttlSeconds: 6 * 3600,
          kind: "club_fixtures",
        }));
      }

      if (phase === "activity_sheets") {
        const clubContexts = new Map<
          string,
          { teamId: number; season: number }
        >();
        const fixturePlayerPayloads = new Map<number, JsonObject>();
        for (
          const fixtureId of [...fixturePlayerStatisticsIds].sort((a, b) =>
            a - b
          )
        ) {
          const response = await cached("/fixtures/players", {
            fixture: String(fixtureId),
          }, 30 * 86400);
          fixturePlayerPayloads.set(fixtureId, response.body);
        }
        const candidates = decisiveSelectionPlayerCandidates({
          recentFixtureIdsByTeam: selectionRecentFixtureIdsByTeam,
          selectionTeamSeasons,
          fixturePlayerPayloads,
        });
        for (const candidate of candidates) {
          const profile = await cached("/players", {
            id: String(candidate.playerId),
            season: String(candidate.season),
          }, 6 * 3600);
          for (
            const club of clubContextsFromPlayerStatistics(
              profile.body,
              candidate.selectionTeamId,
              candidate.season,
            )
          ) clubContexts.set(`${club.teamId}:${club.season}`, club);
        }
        const sheets = new Set<number>();
        for (const context of clubContexts.values()) {
          const clubFixtures = await cached("/fixtures", {
            team: String(context.teamId),
            season: String(context.season),
            timezone: options.timezone,
          }, 6 * 3600);
          for (
            const fixtureId of completedClubFixtureIdsForTeam(
              clubFixtures.body,
              context.teamId,
            )
          ) {
            if (!fixturePlayerPayloads.has(fixtureId)) sheets.add(fixtureId);
          }
        }
        return [...sheets].sort((a, b) => a - b).map((fixtureId) => ({
          endpoint: "/fixtures/players",
          query: { fixture: String(fixtureId) },
          ttlSeconds: 30 * 86400,
          kind: "fixture_players",
        }));
      }
      return [];
    };

    let nextCursor: { phase: string; offset: number; run_id?: string } | null =
      null;
    while (phaseIndex < phases.length && remaining > 0) {
      const phase = phases[phaseIndex];
      const tasks = await tasksForPhase(phase);
      const selected = tasks.slice(offset, offset + remaining);
      for (const task of selected) {
        const result = await cached(task.endpoint, task.query, task.ttlSeconds);
        switch (task.kind) {
          case "injury":
            summary.injuries += 1;
            break;
          case "player_page":
            summary.playerStatisticsRequests += 1;
            summary.playerStatisticsPages += 1;
            summary.playerStatisticsPlayers += responseRows(result.body).length;
            break;
          case "players":
            summary.playerStatisticsRequests += 1;
            break;
          case "fixture_statistics":
            summary.fixtureStatistics += 1;
            break;
          case "fixture_events":
            summary.fixtureEvents += 1;
            break;
          case "fixture_players":
            summary.fixturePlayerStatistics += 1;
            break;
          case "club_fixtures":
            summary.recentFixtureRows += responseRows(result.body).length;
            break;
        }
        summary.cachedResponses += 1;
      }
      remaining -= selected.length;
      processedThisPass += selected.length;
      offset += selected.length;
      if (offset < tasks.length) {
        nextCursor = { phase, offset, run_id: runId };
        break;
      }
      phaseIndex += 1;
      offset = 0;
    }
    if (nextCursor === null && phaseIndex < phases.length) {
      nextCursor = { phase: phases[phaseIndex], offset: 0, run_id: runId };
    }

    await updateSyncRun({
      supabaseUrl,
      serviceRoleKey,
      runId,
      status: nextCursor === null ? "succeeded" : "running",
      summary,
    });

    const counters = {
      ...summary,
      enrichmentPhase: nextCursor?.phase ?? "terminé",
      enrichmentBatchSize,
      enrichmentBatchProcessed: processedThisPass,
      enrichmentBatchOffset: nextCursor?.offset ?? enrichmentBatchSize,
    };
    await reporter.checkpoint(counters, {}, true);
    return jsonResponse({
      ok: true,
      runId,
      summary,
      ...(nextCursor ? { continue: true, batch_cursor: nextCursor } : {}),
    }, 200);
  } catch (error) {
    if (runId !== null) {
      await updateSyncRun({
        supabaseUrl,
        serviceRoleKey,
        runId,
        status: "failed",
        summary,
        errorMessage: error instanceof Error ? error.message : String(error),
      });
    }

    return jsonResponse(
      {
        ok: false,
        runId,
        error: error instanceof Error ? error.message : error,
      },
      500,
    );
  }
});

type SyncOptions = {
  fallbackSeason: number;
  timezone: string;
  windowStart: string;
  windowEnd: string;
  leagueIds: number[];
  bookmakerId: number | null;
  includeTeamStatistics: boolean;
  includeRecentForm: boolean;
  includeExpectedGoals: boolean;
  includePlayerStatistics: boolean;
  includeRecentPlayerPerformances: boolean;
  includePlayerActivityHistory: boolean;
  skipEmptyFeed: boolean;
  recentFormDaysBack: number;
  recentFormMatches: number;
};

type SyncSummary = {
  leagues: number;
  fixtures: number;
  upcomingFixtures: number;
  odds: number;
  standings: number;
  leagueFixtureRows: number;
  teamStatistics: number;
  recentFixtureRows: number;
  fixtureStatistics: number;
  fixtureEvents: number;
  fixturePlayerStatistics: number;
  headToHead: number;
  injuries: number;
  playerStatisticsRequests: number;
  playerStatisticsPages: number;
  playerStatisticsPlayers: number;
  cachedResponses: number;
  providerRequests: number;
  leagueSeasons: Record<string, number>;
};

type CachedResponse = {
  body: JsonObject;
  fetchedAt: string;
  fromCache: boolean;
};

type FetchAndCacheOptions = {
  apiBaseUrl: string;
  apiKey: string;
  supabaseUrl: string;
  serviceRoleKey: string;
  runId: string;
  endpoint: string;
  query: Record<string, string>;
  ttlSeconds: number;
  requestDelayMs: number;
  onProviderRequest?: () => void;
};

function authorizeSyncRequest(request: Request): string | null {
  const expectedSecret = Deno.env.get("API_FOOTBALL_SYNC_SECRET");
  if (expectedSecret === undefined || expectedSecret.trim() === "") {
    return "API_FOOTBALL_SYNC_SECRET is not configured.";
  }

  const authorization = request.headers.get("authorization") ?? "";
  const token = authorization.replace(/^Bearer\s+/i, "").trim();
  return token === expectedSecret ? null : "Invalid sync secret.";
}

function requireEnv(name: string): string {
  const value = Deno.env.get(name);
  if (value === undefined || value.trim() === "") {
    throw new Error(`${name} is not configured.`);
  }
  return value;
}

async function readJson(request: Request): Promise<JsonObject> {
  const body = await request.json().catch(() => ({}));
  if (body === null || typeof body !== "object" || Array.isArray(body)) {
    throw new Error("Request body must be a JSON object.");
  }
  return body as JsonObject;
}

function syncOptionsFromPayload(payload: JsonObject): SyncOptions {
  const today = dateOnly(new Date());
  const windowStart = stringValue(payload.window_start) ?? today;
  const windowEnd = stringValue(payload.window_end) ?? windowStart;
  const leagueIds = numberList(payload.league_ids);
  const fallbackSeason = numberValue(payload.season) ??
    new Date().getFullYear();
  const bookmakerId = numberValue(payload.bookmaker_id);
  const timezone = stringValue(payload.timezone) ?? defaultTimezone;
  const includeTeamStatistics = booleanValue(payload.include_team_statistics) ??
    true;
  const includeRecentForm = booleanValue(payload.include_recent_form) ?? true;
  const includeExpectedGoals = booleanValue(payload.include_expected_goals) ??
    includeRecentForm;
  // Player pages are by far the most expensive part of a league refresh.
  // Keep them opt-in so rolling fixture/odds jobs cannot silently repaginate
  // every squad. The scheduled enrichment job enables them explicitly.
  const includePlayerStatistics =
    booleanValue(payload.include_player_statistics) ?? false;
  // This is deliberately separate from season player pages. Completed fixture
  // line-ups supply each player's minutes, goals and assists for the full
  // Radar history, while the ranking still evaluates its last three matches.
  const includeRecentPlayerPerformances =
    booleanValue(payload.include_recent_player_performances) ?? true;
  // Season activity can require one provider call per completed fixture.
  // It is enabled only for an explicit, targeted enrichment run.
  const includePlayerActivityHistory =
    booleanValue(payload.include_player_activity_history) ?? false;
  const skipEmptyFeed = payload.purpose === "daily_football_sync";
  const recentFormDaysBack = numberValue(payload.recent_form_days_back) ??
    defaultRecentFormDaysBack;
  const recentFormMatches = numberValue(payload.recent_form_matches) ??
    defaultRecentFormMatches;

  if (leagueIds.length === 0) {
    throw new Error(
      "league_ids must contain at least one API-Football league id.",
    );
  }
  if (leagueIds.length > maxLeagues) {
    throw new Error(`league_ids cannot contain more than ${maxLeagues} ids.`);
  }
  if (!isDate(windowStart) || !isDate(windowEnd)) {
    throw new Error("window_start and window_end must be ISO dates.");
  }
  if (windowEnd < windowStart) {
    throw new Error("window_end must be on or after window_start.");
  }
  if (dateWindow(windowStart, windowEnd).length > maxDays) {
    throw new Error(`Date window cannot exceed ${maxDays} days.`);
  }
  if (recentFormDaysBack < 1 || recentFormDaysBack > 730) {
    throw new Error("recent_form_days_back must be between 1 and 730.");
  }
  if (recentFormMatches < 1 || recentFormMatches > 10) {
    throw new Error("recent_form_matches must be between 1 and 10.");
  }

  return {
    fallbackSeason,
    timezone,
    windowStart,
    windowEnd,
    leagueIds,
    bookmakerId,
    includeTeamStatistics,
    includeRecentForm,
    includeExpectedGoals,
    includePlayerStatistics,
    includeRecentPlayerPerformances,
    includePlayerActivityHistory,
    skipEmptyFeed,
    recentFormDaysBack,
    recentFormMatches,
  };
}

async function markStaleSyncRuns({
  supabaseUrl,
  serviceRoleKey,
  exceptRunId,
}: {
  supabaseUrl: string;
  serviceRoleKey: string;
  exceptRunId?: string;
}): Promise<void> {
  // A per-league run should finish in a few minutes. Recover promptly from an
  // invocation that the platform or provider has left without a response.
  const staleBefore = new Date(Date.now() - 15 * 60 * 1000).toISOString();
  await supabaseFetch({
    supabaseUrl,
    serviceRoleKey,
    path: `/rest/v1/api_football_sync_runs?status=eq.running&started_at=lt.${
      encodeURIComponent(staleBefore)
    }${
      exceptRunId === undefined
        ? ""
        : `&id=neq.${encodeURIComponent(exceptRunId)}`
    }`,
    method: "PATCH",
    body: {
      status: "failed",
      error_message: "Run marked failed after exceeding stale running window.",
      finished_at: new Date().toISOString(),
    },
    prefer: "return=minimal",
  });
}

async function insertSyncRun({
  supabaseUrl,
  serviceRoleKey,
  options,
  requestPayload,
}: {
  supabaseUrl: string;
  serviceRoleKey: string;
  options: SyncOptions;
  requestPayload: JsonObject;
}): Promise<JsonObject> {
  const rows = await supabaseFetch({
    supabaseUrl,
    serviceRoleKey,
    path: "/rest/v1/api_football_sync_runs",
    method: "POST",
    body: [
      {
        season: options.fallbackSeason,
        timezone: options.timezone,
        window_start: options.windowStart,
        window_end: options.windowEnd,
        league_ids: options.leagueIds,
        bookmaker_id: options.bookmakerId,
        include_team_statistics: options.includeTeamStatistics,
        request_payload: requestPayload,
      },
    ],
    prefer: "return=representation",
  });

  return rows[0] as JsonObject;
}

async function findSyncRun({
  supabaseUrl,
  serviceRoleKey,
  runId,
}: {
  supabaseUrl: string;
  serviceRoleKey: string;
  runId: string;
}): Promise<JsonObject> {
  const rows = await supabaseFetch({
    supabaseUrl,
    serviceRoleKey,
    path: `/rest/v1/api_football_sync_runs?id=eq.${
      encodeURIComponent(runId)
    }&select=id,league_ids,status&limit=1`,
    method: "GET",
  });
  const row = objectValue(rows[0]);
  if (row === null || stringValue(row.id) !== runId) {
    throw new Error(
      "Batch d’enrichissement introuvable pour reprendre le lot.",
    );
  }
  return row;
}

async function updateSyncRun({
  supabaseUrl,
  serviceRoleKey,
  runId,
  status,
  summary,
  errorMessage,
}: {
  supabaseUrl: string;
  serviceRoleKey: string;
  runId: string;
  status: "running" | "succeeded" | "failed" | "partial";
  summary: SyncSummary;
  errorMessage?: string;
}): Promise<void> {
  await supabaseFetch({
    supabaseUrl,
    serviceRoleKey,
    path: `/rest/v1/api_football_sync_runs?id=eq.${encodeURIComponent(runId)}`,
    method: "PATCH",
    body: {
      status,
      response_summary: summary,
      error_message: errorMessage ?? null,
      finished_at: status === "running" ? null : new Date().toISOString(),
    },
    prefer: "return=minimal",
  });
}

async function fetchAndCache(
  options: FetchAndCacheOptions,
): Promise<CachedResponse> {
  const uri = new URL(`${options.apiBaseUrl}${options.endpoint}`);
  for (const key of Object.keys(options.query).sort()) {
    uri.searchParams.set(key, options.query[key]);
  }

  const queryHash = await sha256Hex(
    JSON.stringify({
      endpoint: options.endpoint,
      query: sortedObject(options.query),
    }),
  );
  const freshRows = await supabaseFetch({
    supabaseUrl: options.supabaseUrl,
    serviceRoleKey: options.serviceRoleKey,
    path: `/rest/v1/api_football_cached_responses?source=eq.${source}` +
      `&endpoint=eq.${encodeURIComponent(options.endpoint)}` +
      `&query_hash=eq.${queryHash}&response_status=eq.200` +
      `&expires_at=gt.${encodeURIComponent(new Date().toISOString())}` +
      `&select=response_body,fetched_at&limit=1`,
    method: "GET",
  });
  const freshRow = objectValue(freshRows[0]);
  const cachedBody = objectValue(freshRow?.response_body);
  const cachedAt = stringValue(freshRow?.fetched_at);
  if (
    cachedBody !== null && cachedAt !== null &&
    apiFootballErrorMessages(cachedBody).length === 0
  ) {
    return { body: cachedBody, fetchedAt: cachedAt, fromCache: true };
  }

  const reservation = await reserveApiFootballRequest(options);
  if (!reservation.allowed) {
    throw new Error(
      `API-Football quota guard blocked ${options.endpoint}: ${reservation.reason}; ` +
        `daily remaining=${reservation.dailyRemaining}, ` +
        `rolling-minute remaining=${reservation.minuteRemaining}.`,
    );
  }
  options.onProviderRequest?.();
  const fetchedAt = new Date();
  const response = await fetchWithTimeout(
    uri,
    {
      headers: {
        accept: "application/json",
        "x-apisports-key": options.apiKey,
      },
    },
    apiFootballRequestTimeoutMs,
    `API-Football ${options.endpoint}`,
  );
  const body = await response.json().catch(() => ({}));
  if (body === null || typeof body !== "object" || Array.isArray(body)) {
    throw new Error(`Unexpected API-Football payload for ${options.endpoint}.`);
  }

  const fetchedAtIso = fetchedAt.toISOString();
  const expiresAt = new Date(
    fetchedAt.getTime() + options.ttlSeconds * 1000,
  ).toISOString();

  await supabaseFetch({
    supabaseUrl: options.supabaseUrl,
    serviceRoleKey: options.serviceRoleKey,
    path: "/rest/v1/api_football_cached_responses",
    method: "POST",
    body: [
      {
        source,
        endpoint: options.endpoint,
        query_hash: queryHash,
        query_params: sortedObject(options.query),
        request_url: redactUrl(uri),
        response_status: response.status,
        response_body: body,
        rate_limit: rateLimitHeaders(response.headers),
        sync_run_id: options.runId,
        fetched_at: fetchedAtIso,
        as_of: fetchedAtIso,
        expires_at: expiresAt,
      },
    ],
    prefer: "resolution=merge-duplicates,return=minimal",
  });

  if (!response.ok) {
    await delay(options.requestDelayMs);
    throw new Error(
      `API-Football ${response.status} for ${options.endpoint}.`,
    );
  }

  const apiErrors = apiFootballErrorMessages(body as JsonObject);
  if (apiErrors.length > 0) {
    await delay(options.requestDelayMs);
    throw new Error(
      `API-Football error for ${options.endpoint}: ${apiErrors.join("; ")}`,
    );
  }

  await delay(options.requestDelayMs);
  return {
    body: body as JsonObject,
    fetchedAt: fetchedAtIso,
    fromCache: false,
  };
}

type ApiFootballRequestReservation = {
  allowed: boolean;
  reason: string;
  dailyRemaining: number;
  minuteRemaining: number;
};

async function reserveApiFootballRequest(
  options: FetchAndCacheOptions,
): Promise<ApiFootballRequestReservation> {
  const rows = await supabaseFetch({
    supabaseUrl: options.supabaseUrl,
    serviceRoleKey: options.serviceRoleKey,
    path: "/rest/v1/rpc/reserve_api_football_request",
    method: "POST",
    body: {
      p_sync_run_id: options.runId,
      p_daily_limit: apiFootballDailyRequestLimit,
      p_minute_limit: apiFootballMinuteRequestLimit,
    },
    prefer: "return=representation",
  });
  const payload = objectValue(rows[0]) ?? {};
  return {
    allowed: payload.allowed === true,
    reason: stringValue(payload.reason) ?? "unknown_limit",
    dailyRemaining: numberValue(payload.daily_remaining) ?? 0,
    minuteRemaining: numberValue(payload.minute_remaining) ?? 0,
  };
}

function apiFootballErrorMessages(payload: JsonObject): string[] {
  const errors = payload.errors;
  if (errors === null || errors === undefined) {
    return [];
  }

  if (Array.isArray(errors)) {
    return errors.map(errorMessageValue).filter(isNonEmptyString);
  }

  if (typeof errors === "string") {
    return errors.trim() === "" ? [] : [errors.trim()];
  }

  if (typeof errors === "object") {
    return Object.entries(errors as Record<string, unknown>)
      .map(([key, value]) => {
        const message = errorMessageValue(value);
        return message === "" ? key : `${key}: ${message}`;
      })
      .filter(isNonEmptyString);
  }

  return [];
}

function errorMessageValue(value: unknown): string {
  if (typeof value === "string") {
    return value.trim();
  }
  if (Array.isArray(value)) {
    return value.map(errorMessageValue).filter(isNonEmptyString).join(", ");
  }
  if (value !== null && value !== undefined && typeof value === "object") {
    return JSON.stringify(value);
  }
  return "";
}

function isNonEmptyString(value: string): boolean {
  return value.trim() !== "";
}

function delay(milliseconds: number): Promise<void> {
  if (milliseconds <= 0) {
    return Promise.resolve();
  }
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

async function supabaseFetch({
  supabaseUrl,
  serviceRoleKey,
  path,
  method,
  body,
  prefer,
}: {
  supabaseUrl: string;
  serviceRoleKey: string;
  path: string;
  method: string;
  body?: unknown;
  prefer?: string;
}): Promise<unknown[]> {
  const response = await fetchWithTimeout(
    `${supabaseUrl}${path}`,
    {
      method,
      headers: {
        apikey: serviceRoleKey,
        authorization: `Bearer ${serviceRoleKey}`,
        "content-type": "application/json",
        ...(prefer === undefined ? {} : { prefer }),
      },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    },
    supabaseRequestTimeoutMs,
    `Supabase ${path}`,
  );

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Supabase ${response.status}: ${text}`);
  }

  if (prefer?.includes("return=minimal")) {
    return [];
  }

  const payload = await response.json();
  return Array.isArray(payload) ? payload : [payload];
}

async function fetchWithTimeout(
  input: string | URL,
  init: RequestInit,
  timeoutMs: number,
  label: string,
): Promise<Response> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(input, { ...init, signal: controller.signal });
  } catch (error) {
    if (controller.signal.aborted) {
      throw new Error(`${label} timed out after ${timeoutMs / 1000} seconds.`);
    }
    throw error;
  } finally {
    clearTimeout(timer);
  }
}

function responseRows(payload: JsonObject): unknown[] {
  const rows = payload.response;
  return Array.isArray(rows) ? rows : [];
}

function seasonForWindowFromLeaguesPayload(
  payload: JsonObject,
  fallbackSeason: number,
  windowStart: string,
  windowEnd: string,
): number {
  const overlappingSeasons: Array<{
    year: number;
    current: boolean;
    start: string;
  }> = [];
  let currentSeason: number | null = null;
  let firstSeason: number | null = null;

  for (const row of responseRows(payload)) {
    const root = objectValue(row);
    if (root === null) {
      continue;
    }
    const seasons = root.seasons;
    if (!Array.isArray(seasons)) {
      continue;
    }
    for (const season of seasons.map(objectValue)) {
      const year = numberValue(season?.year);
      if (year === null) {
        continue;
      }
      firstSeason ??= year;
      const isCurrent = booleanValue(season?.current) === true;
      if (isCurrent) {
        currentSeason = year;
      }
      const coverage = objectValue(season?.coverage) ?? {};
      const fixtures = objectValue(coverage.fixtures) ?? {};
      const start = stringValue(fixtures.start);
      const end = stringValue(fixtures.end);
      if (
        start !== null &&
        end !== null &&
        isDate(start) &&
        isDate(end) &&
        dateRangesOverlap(start, end, windowStart, windowEnd)
      ) {
        overlappingSeasons.push({ year, current: isCurrent, start });
      }
    }
  }

  if (overlappingSeasons.length > 0) {
    overlappingSeasons.sort((a, b) => {
      if (a.start !== b.start) {
        return b.start.localeCompare(a.start);
      }
      if (a.current !== b.current) {
        return a.current ? -1 : 1;
      }
      return b.year - a.year;
    });
    return overlappingSeasons[0].year;
  }

  if (currentSeason !== null) {
    return currentSeason;
  }

  if (firstSeason !== null) {
    return firstSeason;
  }

  return fallbackSeason;
}

function teamIdsFromFixtures(payload: JsonObject): number[] {
  const ids = new Set<number>();
  for (const row of responseRows(payload)) {
    if (row === null || typeof row !== "object") {
      continue;
    }
    const teams = (row as JsonObject).teams;
    if (teams === null || typeof teams !== "object" || Array.isArray(teams)) {
      continue;
    }
    for (const side of ["home", "away"]) {
      const team = (teams as JsonObject)[side];
      if (team === null || typeof team !== "object" || Array.isArray(team)) {
        continue;
      }
      const id = numberValue((team as JsonObject).id);
      if (id !== null) {
        ids.add(id);
      }
    }
  }
  return [...ids];
}

type FixtureTeamContext = {
  leagueId: number;
  teamId: number;
  fixtureDate: string;
};

function fixtureTeamContextsFromFixtures(
  payload: JsonObject,
  fallbackLeagueId: number,
): FixtureTeamContext[] {
  const contexts = new Map<string, FixtureTeamContext>();
  for (const row of responseRows(payload)) {
    const root = objectValue(row);
    if (root === null) {
      continue;
    }
    const leagueId = numberValue((objectValue(root.league) ?? {}).id) ??
      fallbackLeagueId;
    const fixture = objectValue(root.fixture) ?? {};
    const fixtureDateTime = stringValue(fixture.date);
    if (fixtureDateTime === null) {
      continue;
    }
    const fixtureDate = dateOnly(new Date(fixtureDateTime));
    const teams = objectValue(root.teams) ?? {};
    for (const side of ["home", "away"]) {
      const teamId = numberValue((objectValue(teams[side]) ?? {}).id);
      if (teamId !== null) {
        contexts.set(`${leagueId}:${teamId}:${fixtureDate}`, {
          leagueId,
          teamId,
          fixtureDate,
        });
      }
    }
  }
  return [...contexts.values()];
}

function recentFixtureIdsForTeam(
  payload: JsonObject,
  teamId: number,
  maxMatches: number,
): number[] {
  const fixtures = responseRows(payload)
    .filter(isCompletedFixture)
    .filter((row) => fixtureContainsTeam(row, teamId))
    .sort((a, b) => fixtureTimestamp(b) - fixtureTimestamp(a));

  return fixtures
    .slice(0, maxMatches)
    .map((row) => {
      const root = objectValue(row) ?? {};
      return numberValue((objectValue(root.fixture) ?? {}).id);
    })
    .filter((id): id is number => id !== null);
}

function recentOfficialFixtureIdsForTeam(
  payload: JsonObject,
  teamId: number,
  maxMatches: number,
): number[] {
  return responseRows(payload)
    .filter(isCompletedFixture)
    .filter(isOfficialInternationalFixture)
    .filter((row) => fixtureContainsTeam(row, teamId))
    .sort((a, b) => fixtureTimestamp(b) - fixtureTimestamp(a))
    .slice(0, maxMatches)
    .map((row) =>
      numberValue((objectValue((objectValue(row) ?? {}).fixture) ?? {}).id)
    )
    .filter((id): id is number => id !== null);
}

type SelectionPlayerCandidate = {
  playerId: number;
  selectionTeamId: number;
  season: number;
};

/** Mirrors the published decisive-player rule on the three latest official
 * selection fixtures. It intentionally keeps the Club enrichment tied to the
 * exact profiles the user can see, rather than collecting every squad member.
 */
function decisiveSelectionPlayerCandidates({
  recentFixtureIdsByTeam,
  selectionTeamSeasons,
  fixturePlayerPayloads,
}: {
  recentFixtureIdsByTeam: Map<number, number[]>;
  selectionTeamSeasons: Map<number, number>;
  fixturePlayerPayloads: Map<number, JsonObject>;
}): SelectionPlayerCandidate[] {
  const candidates: SelectionPlayerCandidate[] = [];
  for (const [selectionTeamId, fixtureIds] of recentFixtureIdsByTeam) {
    const season = selectionTeamSeasons.get(selectionTeamId);
    if (season === undefined || fixtureIds.length < 3) continue;
    const profiles = new Map<number, {
      appearances: number;
      minutes: number;
      contributions: number;
      matchesWithContribution: number;
    }>();
    let sheetsAvailable = 0;
    for (const fixtureId of fixtureIds) {
      const payload = fixturePlayerPayloads.get(fixtureId);
      if (payload === undefined) continue;
      const teamSheet = responseRows(payload)
        .map(objectValue)
        .find((row): row is JsonObject =>
          row !== null &&
          numberValue((objectValue(row.team) ?? {}).id) === selectionTeamId
        );
      if (teamSheet === undefined) continue;
      sheetsAvailable += 1;
      for (const row of arrayValue(teamSheet.players).map(objectValue)) {
        if (row === null) continue;
        const playerId = numberValue((objectValue(row.player) ?? {}).id);
        const statistics = arrayValue(row.statistics).map(objectValue).find(
          (value): value is JsonObject => value !== null,
        ) ?? {};
        const games = objectValue(statistics.games) ?? {};
        const goals = objectValue(statistics.goals) ?? {};
        const minutes = numberValue(games.minutes) ?? 0;
        if (playerId === null || minutes <= 0) continue;
        const contributions = (numberValue(goals.total) ?? 0) +
          (numberValue(goals.assists) ?? 0);
        const profile = profiles.get(playerId) ?? {
          appearances: 0,
          minutes: 0,
          contributions: 0,
          matchesWithContribution: 0,
        };
        profile.appearances += 1;
        profile.minutes += minutes;
        profile.contributions += contributions;
        if (contributions > 0) profile.matchesWithContribution += 1;
        profiles.set(playerId, profile);
      }
    }
    if (sheetsAvailable < 3) continue;
    for (const [playerId, profile] of profiles) {
      const recentRate = profile.contributions * 90 / profile.minutes;
      if (
        profile.appearances >= 2 && profile.matchesWithContribution >= 2 &&
        profile.contributions > 0 && recentRate >= 0.8
      ) {
        candidates.push({ playerId, selectionTeamId, season });
      }
    }
  }
  return candidates;
}

function clubContextsFromPlayerStatistics(
  payload: JsonObject,
  selectionTeamId: number,
  fallbackSeason: number,
): Array<{ teamId: number; season: number }> {
  const contexts = new Map<string, { teamId: number; season: number }>();
  for (const row of responseRows(payload)) {
    const player = objectValue(row) ?? {};
    for (const statisticValue of arrayValue(player.statistics)) {
      const statistic = objectValue(statisticValue) ?? {};
      const teamId = numberValue((objectValue(statistic.team) ?? {}).id);
      const league = objectValue(statistic.league) ?? {};
      const leagueId = numberValue(league.id);
      if (
        teamId === null || leagueId === null || teamId === selectionTeamId ||
        isNationalCompetitionId(leagueId)
      ) continue;
      const season = numberValue(league.season) ?? fallbackSeason;
      contexts.set(`${teamId}:${season}`, { teamId, season });
    }
  }
  return [...contexts.values()];
}

function completedClubFixtureIdsForTeam(
  payload: JsonObject,
  teamId: number,
): number[] {
  return responseRows(payload)
    .filter(isCompletedFixture)
    .filter((row) => fixtureContainsTeam(row, teamId))
    .filter((row) => !isOfficialInternationalFixture(row))
    .map((row) =>
      numberValue((objectValue((objectValue(row) ?? {}).fixture) ?? {}).id)
    )
    .filter((id): id is number => id !== null);
}

function isNationalCompetitionId(leagueId: number): boolean {
  return new Set([1, 4, 5, 6, 7, 8, 9, 22, 32, 536]).has(leagueId);
}

function isOfficialInternationalFixture(row: unknown): boolean {
  const league = objectValue((objectValue(row) ?? {}).league) ?? {};
  return isNationalCompetitionId(numberValue(league.id) ?? -1);
}

function completedFixtureIdsForTeams(
  payload: JsonObject,
  teamIds: number[],
): number[] {
  const targets = new Set(teamIds);
  return responseRows(payload)
    .filter(isCompletedFixture)
    .filter((row) =>
      teamIdsFromFixture(row).some((teamId) => targets.has(teamId))
    )
    .map((row) =>
      numberValue((objectValue((objectValue(row) ?? {}).fixture) ?? {}).id)
    )
    .filter((id): id is number => id !== null);
}

function teamIdsFromFixture(row: unknown): number[] {
  const teams = objectValue((objectValue(row) ?? {}).teams) ?? {};
  return ["home", "away"].map((side) =>
    numberValue((objectValue(teams[side]) ?? {}).id)
  )
    .filter((value): value is number => value !== null);
}

function isCompletedFixture(row: unknown): boolean {
  const root = objectValue(row);
  if (root === null) {
    return false;
  }
  const status = objectValue((objectValue(root.fixture) ?? {}).status) ?? {};
  const shortStatus = stringValue(status.short);
  return shortStatus !== null && ["FT", "AET", "PEN"].includes(shortStatus);
}

function fixtureContainsTeam(row: unknown, teamId: number): boolean {
  const root = objectValue(row);
  if (root === null) {
    return false;
  }
  const teams = objectValue(root.teams) ?? {};
  return ["home", "away"].some((side) =>
    numberValue((objectValue(teams[side]) ?? {}).id) === teamId
  );
}

function fixtureTimestamp(row: unknown): number {
  const root = objectValue(row);
  const fixture = objectValue(root?.fixture) ?? {};
  const timestamp = numberValue(fixture.timestamp);
  if (timestamp !== null) {
    return timestamp;
  }
  const date = stringValue(fixture.date);
  return date === null ? 0 : Date.parse(date);
}

function rateLimitHeaders(headers: Headers): JsonObject {
  const values: JsonObject = {};
  headers.forEach((value, key) => {
    if (key.toLowerCase().startsWith("x-ratelimit")) {
      values[key] = value;
    }
  });
  return values;
}

async function sha256Hex(value: string): Promise<string> {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function sortedObject(input: Record<string, string>): Record<string, string> {
  return Object.fromEntries(
    Object.entries(input).sort(([a], [b]) => a.localeCompare(b)),
  );
}

function redactUrl(uri: URL): string {
  return `${uri.origin}${uri.pathname}?${uri.searchParams.toString()}`;
}

function upcomingFixturesInWindow(
  payload: JsonObject,
  windowStart: string,
  windowEnd: string,
  timezone: string,
): number {
  const formatter = new Intl.DateTimeFormat("en-US", {
    timeZone: timezone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  });
  const now = Date.now();
  let count = 0;
  for (const row of responseRows(payload)) {
    const fixture = objectValue(objectValue(row)?.fixture);
    const kickoff = stringValue(fixture?.date);
    const status = stringValue(objectValue(fixture?.status)?.short);
    if (kickoff === null || !["NS", "TBD"].includes(status ?? "")) {
      continue;
    }
    const kickoffTime = Date.parse(kickoff);
    if (!Number.isFinite(kickoffTime) || kickoffTime <= now) {
      continue;
    }
    const parts = Object.fromEntries(
      formatter.formatToParts(new Date(kickoffTime))
        .map((part) => [part.type, part.value]),
    );
    const date = `${parts.year}-${parts.month}-${parts.day}`;
    if (date >= windowStart && date <= windowEnd) {
      count += 1;
    }
  }
  return count;
}

function upcomingTeamIdsInWindow(
  payload: JsonObject,
  windowStart: string,
  windowEnd: string,
  timezone: string,
): number[] {
  const formatter = new Intl.DateTimeFormat("en-US", {
    timeZone: timezone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  });
  const now = Date.now();
  const teamIds = new Set<number>();
  for (const row of responseRows(payload)) {
    const root = objectValue(row) ?? {};
    const fixture = objectValue(root.fixture) ?? {};
    const kickoff = stringValue(fixture.date);
    const status = stringValue(objectValue(fixture.status)?.short);
    if (kickoff === null || !["NS", "TBD"].includes(status ?? "")) continue;
    const kickoffTime = Date.parse(kickoff);
    if (!Number.isFinite(kickoffTime) || kickoffTime <= now) continue;
    const parts = Object.fromEntries(
      formatter.formatToParts(new Date(kickoffTime))
        .map((part) => [part.type, part.value]),
    );
    const date = `${parts.year}-${parts.month}-${parts.day}`;
    if (date < windowStart || date > windowEnd) continue;
    const teams = objectValue(root.teams) ?? {};
    for (const side of ["home", "away"]) {
      const teamId = numberValue((objectValue(teams[side]) ?? {}).id);
      if (teamId !== null) teamIds.add(teamId);
    }
  }
  return [...teamIds];
}

function upcomingHeadToHeadPairs(
  payload: JsonObject,
  windowStart: string,
  windowEnd: string,
  timezone: string,
): string[] {
  const formatter = new Intl.DateTimeFormat("en-US", {
    timeZone: timezone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  });
  const now = Date.now();
  const pairs = new Set<string>();
  for (const row of responseRows(payload)) {
    const root = objectValue(row) ?? {};
    const fixture = objectValue(root.fixture) ?? {};
    const kickoff = stringValue(fixture.date);
    const status = stringValue(objectValue(fixture.status)?.short);
    if (kickoff === null || !["NS", "TBD"].includes(status ?? "")) continue;
    const kickoffTime = Date.parse(kickoff);
    if (!Number.isFinite(kickoffTime) || kickoffTime <= now) continue;
    const parts = Object.fromEntries(
      formatter.formatToParts(new Date(kickoffTime))
        .map((part) => [part.type, part.value]),
    );
    const date = `${parts.year}-${parts.month}-${parts.day}`;
    if (date < windowStart || date > windowEnd) continue;
    const teams = objectValue(root.teams) ?? {};
    const homeTeamId = numberValue((objectValue(teams.home) ?? {}).id);
    const awayTeamId = numberValue((objectValue(teams.away) ?? {}).id);
    if (
      homeTeamId === null || awayTeamId === null || homeTeamId === awayTeamId
    ) {
      continue;
    }
    pairs.add(headToHeadPair(homeTeamId, awayTeamId));
  }
  return [...pairs];
}

function headToHeadPair(firstTeamId: number, secondTeamId: number): string {
  const [lowest, highest] = [firstTeamId, secondTeamId].sort((a, b) => a - b);
  return `${lowest}-${highest}`;
}

function dateWindow(start: string, end: string): string[] {
  const dates: string[] = [];
  const current = new Date(`${start}T00:00:00.000Z`);
  const last = new Date(`${end}T00:00:00.000Z`);
  while (current <= last) {
    dates.push(dateOnly(current));
    current.setUTCDate(current.getUTCDate() + 1);
  }
  return dates;
}

function dateOnly(date: Date): string {
  return [
    date.getUTCFullYear().toString().padStart(4, "0"),
    (date.getUTCMonth() + 1).toString().padStart(2, "0"),
    date.getUTCDate().toString().padStart(2, "0"),
  ].join("-");
}

function subtractDays(date: string, days: number): string {
  const value = new Date(`${date}T00:00:00.000Z`);
  value.setUTCDate(value.getUTCDate() - days);
  return dateOnly(value);
}

function isDate(value: string): boolean {
  return /^\d{4}-\d{2}-\d{2}$/.test(value) &&
    !Number.isNaN(Date.parse(`${value}T00:00:00.000Z`));
}

function dateRangesOverlap(
  firstStart: string,
  firstEnd: string,
  secondStart: string,
  secondEnd: string,
): boolean {
  return firstStart <= secondEnd && secondStart <= firstEnd;
}

function numberList(value: unknown): number[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return [
    ...new Set(
      value
        .map(numberValue)
        .filter((number): number is number => number !== null),
    ),
  ];
}

function numberValue(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  if (typeof value === "string" && value.trim() !== "") {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? Math.trunc(parsed) : null;
  }
  return null;
}

function stringValue(value: unknown): string | null {
  return typeof value === "string" && value.trim() !== "" ? value.trim() : null;
}

function objectValue(value: unknown): JsonObject | null {
  return isJsonObject(value) ? value : null;
}

function arrayValue(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

function isJsonObject(value: unknown): value is JsonObject {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function booleanValue(value: unknown): boolean | null {
  if (typeof value === "boolean") {
    return value;
  }
  if (typeof value === "string") {
    return value === "true" ? true : value === "false" ? false : null;
  }
  return null;
}

function jsonResponse(payload: unknown, status: number): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...corsHeaders,
      "content-type": "application/json",
    },
  });
}
