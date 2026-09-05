type JsonObject = Record<string, unknown>;

const source = "api-football";
const schemaVersion = 1;
const snapshotKind = "pre_match_feed";
const defaultTimezone = "Europe/Paris";
const maxDays = 7;
const maxLeagues = 40;

const defaultBookmakerPriority = [
  { id: 16, name: "Unibet" },
  { id: 8, name: "Bet365" },
  { id: 4, name: "Pinnacle" },
  { id: 3, name: "Betfair" },
  { id: 11, name: "1xBet" },
  { id: 6, name: "Bwin" },
];

type SnapshotScope = {
  scope: "global" | "league";
  scopeKey: string;
  leagueIds: number[];
};

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

  const authError = authorizeBuildRequest(request);
  if (authError !== null) {
    return jsonResponse({ error: authError }, 401);
  }

  const supabaseUrl = requireEnv("SUPABASE_URL");
  const serviceRoleKey = requireEnv("SUPABASE_SERVICE_ROLE_KEY");
  const payload = await readJson(request);
  const options = snapshotOptionsFromPayload(payload);

  try {
    const build = await collectSnapshotSources({
      supabaseUrl,
      serviceRoleKey,
      options,
    });

    if (build.sourceRows.length === 0) {
      return jsonResponse(
        {
          ok: false,
          error:
            "No cached API-Football responses found for this snapshot window. Run api-football-sync first.",
        },
        404,
      );
    }

    const seasonByLeague = completeSeasonByLeague({
      options,
      sourceRows: build.sourceRows,
    });
    const season = seasonByLeagueReference(seasonByLeague, options.season);
    const asOf = options.asOf ??
      (options.forceRebuild ? new Date().toISOString() : null) ??
      latestTimestamp(build.sourceRows) ??
      new Date().toISOString();
    const scope = snapshotScope(options);
    if (!options.forceRebuild) {
      const existing = await findExistingSnapshot({
        supabaseUrl,
        serviceRoleKey,
        options,
        season,
        asOf,
        scope,
      });
      if (existing !== null) {
        return jsonResponse({
          ok: true,
          reused: true,
          snapshotId: existing.id,
          asOf,
          summary: existing.coverage_summary ?? {},
        }, 200);
      }
    }

    const dateWindowValues = dateWindow(options.windowStart, options.windowEnd);
    const fixtureIndex = buildFixtureIndex({
      fixtures: build.rawFixtures,
      odds: build.rawOdds,
      standings: build.rawStandings,
      teamStatistics: build.rawTeamStatistics,
      recentLeagueMatches: build.rawRecentLeagueMatches,
      expectedGoals: build.rawExpectedGoals,
      season,
    });
    const summary = coverageSummary({
      rawFixtures: build.rawFixtures,
      rawOdds: build.rawOdds,
      rawStandings: build.rawStandings,
      rawTeamStatistics: build.rawTeamStatistics,
      rawRecentLeagueMatches: build.rawRecentLeagueMatches,
      rawExpectedGoals: build.rawExpectedGoals,
      fixtureIndex,
      sourceRows: build.sourceRows,
    });
    const emptySnapshotError = emptySnapshotPublicationError(summary);
    if (emptySnapshotError !== null) {
      return jsonResponse(
        {
          ok: false,
          error: emptySnapshotError,
          summary,
        },
        422,
      );
    }
    const syncRunIds = uniqueStrings(
      build.sourceRows
        .map((row) => stringValue(row.sync_run_id))
        .filter((value): value is string => value !== null),
    );
    const payloadV1 = {
      schema_version: schemaVersion,
      source,
      scope: scope.scope,
      scope_key: scope.scopeKey,
      league_ids: scope.leagueIds,
      captured_at: asOf,
      timezone: options.timezone,
      window_start: options.windowStart,
      window_end: options.windowEnd,
      date_window: dateWindowValues,
      season_by_league: seasonByLeague,
      bookmaker_priority: options.bookmakerPriority,
      raw: {
        fixtures: build.rawFixtures,
        odds: build.rawOdds,
        standings: build.rawStandings,
        team_statistics: build.rawTeamStatistics,
        recent_league_matches: build.rawRecentLeagueMatches,
        expected_goals: build.rawExpectedGoals,
        predictions: [],
      },
    };

    const snapshotRows = await supabaseFetch({
      supabaseUrl,
      serviceRoleKey,
      path: "/rest/v1/match_feed_snapshots",
      method: "POST",
      body: [
        {
          schema_version: schemaVersion,
          source,
          kind: snapshotKind,
          scope: scope.scope,
          scope_key: scope.scopeKey,
          league_ids: scope.leagueIds,
          season,
          timezone: options.timezone,
          window_start: options.windowStart,
          window_end: options.windowEnd,
          date_window: dateWindowValues,
          bookmaker_priority: options.bookmakerPriority,
          payload: payloadV1,
          coverage_summary: summary,
          provenance: provenanceSummary({
            options,
            season,
            seasonByLeague,
            sourceRows: build.sourceRows,
            asOf,
            scope,
          }),
          source_sync_run_ids: syncRunIds,
          captured_at: asOf,
          as_of: asOf,
        },
      ],
      prefer: "return=representation",
    });
    const snapshot = snapshotRows[0] as JsonObject;
    const snapshotId = String(snapshot.id);

    if (fixtureIndex.length > 0) {
      await supabaseFetch({
        supabaseUrl,
        serviceRoleKey,
        path: "/rest/v1/match_feed_snapshot_fixtures",
        method: "POST",
        body: fixtureIndex.map((row) => ({
          ...row,
          snapshot_id: snapshotId,
        })),
        prefer: "return=minimal",
      });
    }

    await supabaseFetch({
      supabaseUrl,
      serviceRoleKey,
      path: "/rest/v1/match_feed_snapshot_sources",
      method: "POST",
      body: build.sourceRows.map((row) => ({
        snapshot_id: snapshotId,
        source: row.source,
        endpoint: row.endpoint,
        query_hash: row.query_hash,
        sync_run_id: row.sync_run_id,
        fetched_at: row.fetched_at,
        as_of: row.as_of,
        response_status: row.response_status,
      })),
      prefer: "return=minimal",
    });

    return jsonResponse({
      ok: true,
      reused: false,
      snapshotId,
      asOf,
      summary,
    }, 200);
  } catch (error) {
    return jsonResponse(
      { ok: false, error: error instanceof Error ? error.message : error },
      500,
    );
  }
});

type SnapshotOptions = {
  season: number;
  seasonByLeague: Record<string, number>;
  timezone: string;
  windowStart: string;
  windowEnd: string;
  leagueIds: number[];
  bookmakerId: number | null;
  bookmakerPriority: JsonObject[];
  asOf: string | null;
  forceRebuild: boolean;
  recentFormDaysBack: number;
  recentFormMatches: number;
};

type CachedRawResponse = {
  source: string;
  endpoint: string;
  query_hash: string;
  query_params: JsonObject;
  response_status: number;
  response_body: JsonObject;
  sync_run_id: string | null;
  fetched_at: string;
  as_of: string;
};

type SourceBuild = {
  sourceRows: CachedRawResponse[];
  rawFixtures: JsonObject[];
  rawOdds: JsonObject[];
  rawStandings: JsonObject[];
  rawTeamStatistics: JsonObject[];
  rawRecentLeagueMatches: JsonObject[];
  rawExpectedGoals: JsonObject[];
};

type FixtureIndexRow = {
  fixture_id: string;
  api_football_fixture_id: number | null;
  api_football_league_id: number | null;
  season: number;
  fixture_date: string;
  kickoff_at: string | null;
  status: string;
  competition_id: string;
  competition_name: string;
  country_code: string;
  country_name: string;
  home_team_id: string;
  home_team_name: string;
  away_team_id: string;
  away_team_name: string;
  has_odds: boolean;
  has_standings: boolean;
  has_team_statistics: boolean;
  has_recent_form: boolean;
  has_expected_goals: boolean;
  contains_predictions: boolean;
  payload: JsonObject;
};

async function collectSnapshotSources({
  supabaseUrl,
  serviceRoleKey,
  options,
}: {
  supabaseUrl: string;
  serviceRoleKey: string;
  options: SnapshotOptions;
}): Promise<SourceBuild> {
  const sourceRowsByKey = new Map<string, CachedRawResponse>();
  const rawFixtures: JsonObject[] = [];
  const rawOdds: JsonObject[] = [];
  const rawStandings: JsonObject[] = [];
  const rawTeamStatistics: JsonObject[] = [];
  const rawRecentLeagueMatches: JsonObject[] = [];
  const fixtureStatisticsRows: FixtureStatisticsPayload[] = [];

  const addSourceRows = (rows: CachedRawResponse[]) => {
    for (const row of rows) {
      sourceRowsByKey.set(
        `${row.source}:${row.endpoint}:${row.query_hash}`,
        row,
      );
    }
  };

  for (const leagueId of options.leagueIds) {
    const leagueRows = await cachedResponsesFor({
      supabaseUrl,
      serviceRoleKey,
      endpoint: "/leagues",
      filters: {
        id: String(leagueId),
      },
    });
    addSourceRows(leagueRows);
    const leagueSeason = seasonForLeagueFromRows(
      options,
      leagueId,
      leagueRows,
    );

    const standingsRows = await cachedResponsesFor({
      supabaseUrl,
      serviceRoleKey,
      endpoint: "/standings",
      filters: {
        league: String(leagueId),
        season: String(leagueSeason),
      },
    });
    addSourceRows(standingsRows);
    rawStandings.push(...flatResponseItems(standingsRows));

    for (const date of dateWindow(options.windowStart, options.windowEnd)) {
      const fixtureRows = await cachedResponsesFor({
        supabaseUrl,
        serviceRoleKey,
        endpoint: "/fixtures",
        filters: {
          league: String(leagueId),
          season: String(leagueSeason),
          date,
          timezone: options.timezone,
        },
      });
      addSourceRows(fixtureRows);
      rawFixtures.push(...flatResponseItems(fixtureRows));

      const oddsFilters: Record<string, string> = {
        league: String(leagueId),
        season: String(leagueSeason),
        date,
      };
      if (options.bookmakerId !== null) {
        oddsFilters.bookmaker = String(options.bookmakerId);
      }
      const oddsRows = await cachedResponsesFor({
        supabaseUrl,
        serviceRoleKey,
        endpoint: "/odds",
        filters: oddsFilters,
      });
      addSourceRows(oddsRows);
      rawOdds.push(...flatResponseItems(oddsRows));
    }
  }

  const teamRequests = teamStatisticsRequests(rawFixtures, options);
  for (const request of teamRequests) {
    const rows = await cachedResponsesFor({
      supabaseUrl,
      serviceRoleKey,
      endpoint: "/teams/statistics",
      filters: {
        league: String(request.leagueId),
        season: String(request.season),
        team: String(request.teamId),
      },
    });
    addSourceRows(rows);
    rawTeamStatistics.push(...flatResponseItems(rows));
  }

  const recentRequests = recentFixtureRequests(rawFixtures, options);
  for (const request of recentRequests) {
    const rows = await cachedResponsesFor({
      supabaseUrl,
      serviceRoleKey,
      endpoint: "/fixtures",
      filters: {
        league: String(request.leagueId),
        season: String(request.season),
        team: String(request.teamId),
        from: request.from,
        to: request.to,
        timezone: options.timezone,
      },
    });
    addSourceRows(rows);
    const recentMatches = normalizeRecentFixturesForTeam({
      leagueId: request.leagueId,
      teamId: request.teamId,
      fixtures: flatResponseItems(rows),
      maxMatches: options.recentFormMatches,
    });
    if (recentMatches !== null) {
      rawRecentLeagueMatches.push(recentMatches);
    }
  }

  const recentFixtureIds = recentFixtureIdsFromRows(rawRecentLeagueMatches);
  for (const fixtureId of recentFixtureIds) {
    const rows = await cachedResponsesFor({
      supabaseUrl,
      serviceRoleKey,
      endpoint: "/fixtures/statistics",
      filters: {
        fixture: String(fixtureId),
      },
    });
    addSourceRows(rows);
    for (const row of rows) {
      fixtureStatisticsRows.push({
        fixtureId,
        statistics: flatResponseItems([row]),
      });
    }
  }

  const rawExpectedGoals = expectedGoalsSnapshots({
    recentLeagueMatches: rawRecentLeagueMatches,
    fixtureStatisticsRows,
    asOf: latestTimestamp([...sourceRowsByKey.values()]) ??
      new Date().toISOString(),
  });

  return {
    sourceRows: [...sourceRowsByKey.values()],
    rawFixtures,
    rawOdds,
    rawStandings,
    rawTeamStatistics,
    rawRecentLeagueMatches,
    rawExpectedGoals,
  };
}

async function cachedResponsesFor({
  supabaseUrl,
  serviceRoleKey,
  endpoint,
  filters,
}: {
  supabaseUrl: string;
  serviceRoleKey: string;
  endpoint: string;
  filters: Record<string, string>;
}): Promise<CachedRawResponse[]> {
  const query = new URLSearchParams();
  query.set(
    "select",
    "source,endpoint,query_hash,query_params,response_status,response_body,sync_run_id,fetched_at,as_of",
  );
  query.set("source", `eq.${source}`);
  query.set("endpoint", `eq.${endpoint}`);
  query.append("response_status", "gte.200");
  query.append("response_status", "lt.300");
  for (const [key, value] of Object.entries(filters)) {
    query.set(`query_params->>${key}`, `eq.${value}`);
  }
  query.set("order", "fetched_at.desc");

  const rows = await supabaseFetch({
    supabaseUrl,
    serviceRoleKey,
    path: `/rest/v1/api_football_cached_responses?${query.toString()}`,
    method: "GET",
    prefer: "return=representation",
  });

  const normalizedRows = rows.map(normalizeCachedRow);
  const errorRows = normalizedRows.filter((row) =>
    apiFootballErrorMessages(row.response_body).length > 0
  );
  if (errorRows.length > 0 && errorRows.length === normalizedRows.length) {
    const message = apiFootballErrorMessages(errorRows[0].response_body).join(
      "; ",
    );
    throw new Error(
      `Cached API-Football response for ${endpoint} contains API errors: ${message}`,
    );
  }

  return normalizedRows.filter((row) =>
    apiFootballErrorMessages(row.response_body).length === 0
  );
}

async function findExistingSnapshot({
  supabaseUrl,
  serviceRoleKey,
  options,
  season,
  asOf,
  scope,
}: {
  supabaseUrl: string;
  serviceRoleKey: string;
  options: SnapshotOptions;
  season: number;
  asOf: string;
  scope: SnapshotScope;
}): Promise<JsonObject | null> {
  const query = new URLSearchParams();
  query.set("select", "id,coverage_summary,snapshot_created_at");
  query.set("source", `eq.${source}`);
  query.set("schema_version", `eq.${schemaVersion}`);
  query.set("scope_key", `eq.${scope.scopeKey}`);
  query.set("season", `eq.${season}`);
  query.set("timezone", `eq.${options.timezone}`);
  query.set("window_start", `eq.${options.windowStart}`);
  query.set("window_end", `eq.${options.windowEnd}`);
  query.set("as_of", `eq.${asOf}`);
  query.set("limit", "1");

  const rows = await supabaseFetch({
    supabaseUrl,
    serviceRoleKey,
    path: `/rest/v1/match_feed_snapshots?${query.toString()}`,
    method: "GET",
    prefer: "return=representation",
  });

  return rows.length === 0 ? null : rows[0] as JsonObject;
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
  prefer: string;
}): Promise<unknown[]> {
  const response = await fetch(`${supabaseUrl}${path}`, {
    method,
    headers: {
      apikey: serviceRoleKey,
      authorization: `Bearer ${serviceRoleKey}`,
      "content-type": "application/json",
      prefer,
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Supabase ${response.status}: ${text}`);
  }

  if (prefer.includes("return=minimal")) {
    return [];
  }

  const payload = await response.json();
  return Array.isArray(payload) ? payload : [payload];
}

function buildFixtureIndex({
  fixtures,
  odds,
  standings,
  teamStatistics,
  recentLeagueMatches,
  expectedGoals,
  season,
}: {
  fixtures: JsonObject[];
  odds: JsonObject[];
  standings: JsonObject[];
  teamStatistics: JsonObject[];
  recentLeagueMatches: JsonObject[];
  expectedGoals: JsonObject[];
  season: number;
}): FixtureIndexRow[] {
  const oddsFixtureIds = new Set(
    odds
      .map((row) => numberValue((objectValue(row.fixture) ?? {}).id))
      .filter((id): id is number => id !== null),
  );
  const standingsLeagueIds = new Set(
    standings
      .map((row) => numberValue((objectValue(row.league) ?? {}).id))
      .filter((id): id is number => id !== null),
  );
  const statisticsKeys = new Set(
    teamStatistics
      .map((row) => {
        const leagueId = numberValue((objectValue(row.league) ?? {}).id);
        const teamId = numberValue((objectValue(row.team) ?? {}).id);
        return leagueId === null || teamId === null
          ? null
          : `${leagueId}:${teamId}`;
      })
      .filter((key): key is string => key !== null),
  );
  const recentKeys = new Set(
    recentLeagueMatches
      .map((row) => {
        const leagueId = numberValue((objectValue(row.league) ?? {}).id);
        const teamId = numberValue((objectValue(row.team) ?? {}).id);
        return leagueId === null || teamId === null
          ? null
          : `${leagueId}:${teamId}`;
      })
      .filter((key): key is string => key !== null),
  );
  const expectedGoalTeamIds = new Set(
    expectedGoals
      .map((row) => numberValue((objectValue(row.team) ?? {}).id))
      .filter((id): id is number => id !== null),
  );

  return fixtures.map((row) => {
    const fixture: JsonObject = objectValue(row.fixture) ?? {};
    const league: JsonObject = objectValue(row.league) ?? {};
    const teams: JsonObject = objectValue(row.teams) ?? {};
    const status: JsonObject = objectValue(fixture.status) ?? {};
    const home: JsonObject = objectValue(teams.home) ?? {};
    const away: JsonObject = objectValue(teams.away) ?? {};
    const fixtureApiId = numberValue(fixture.id);
    const leagueApiId = numberValue(league.id);
    const fixtureDateTime = stringValue(fixture.date);
    const fixtureDate = dateOnly(
      new Date(fixtureDateTime ?? `${dateOnly(new Date())}T00:00:00.000Z`),
    );
    const homeTeamId = numberValue(home.id);
    const awayTeamId = numberValue(away.id);
    const countryName = stringValue(league.country) ?? "Unknown";

    return {
      fixture_id: fixtureApiId === null
        ? `api-fixture-${
          stableSlug([
            stringValue(league.name) ?? "",
            fixtureDateTime ?? fixtureDate,
            stringValue(home.name) ?? "",
            stringValue(away.name) ?? "",
          ])
        }`
        : `api-fixture-${fixtureApiId}`,
      api_football_fixture_id: fixtureApiId,
      api_football_league_id: leagueApiId,
      season,
      fixture_date: fixtureDate,
      kickoff_at: fixtureDateTime,
      status: stringValue(status.short) ?? stringValue(status.long) ?? "NS",
      competition_id: leagueApiId === null
        ? `api-league-${stableSlug([stringValue(league.name) ?? countryName])}`
        : `api-league-${leagueApiId}`,
      competition_name: stringValue(league.name) ?? "Competition inconnue",
      country_code: countryCode(countryName),
      country_name: countryName,
      home_team_id: homeTeamId === null
        ? `api-team-${stableSlug([stringValue(home.name) ?? "home"])}`
        : `api-team-${homeTeamId}`,
      home_team_name: stringValue(home.name) ?? "Equipe domicile",
      away_team_id: awayTeamId === null
        ? `api-team-${stableSlug([stringValue(away.name) ?? "away"])}`
        : `api-team-${awayTeamId}`,
      away_team_name: stringValue(away.name) ?? "Equipe exterieure",
      has_odds: fixtureApiId !== null && oddsFixtureIds.has(fixtureApiId),
      has_standings: leagueApiId !== null &&
        standingsLeagueIds.has(leagueApiId),
      has_team_statistics: leagueApiId !== null &&
        homeTeamId !== null &&
        awayTeamId !== null &&
        statisticsKeys.has(`${leagueApiId}:${homeTeamId}`) &&
        statisticsKeys.has(`${leagueApiId}:${awayTeamId}`),
      has_recent_form: leagueApiId !== null &&
        homeTeamId !== null &&
        awayTeamId !== null &&
        recentKeys.has(`${leagueApiId}:${homeTeamId}`) &&
        recentKeys.has(`${leagueApiId}:${awayTeamId}`),
      has_expected_goals: homeTeamId !== null &&
        awayTeamId !== null &&
        expectedGoalTeamIds.has(homeTeamId) &&
        expectedGoalTeamIds.has(awayTeamId),
      contains_predictions: false,
      payload: {
        fixture: row,
      },
    };
  });
}

function coverageSummary({
  rawFixtures,
  rawOdds,
  rawStandings,
  rawTeamStatistics,
  rawRecentLeagueMatches,
  rawExpectedGoals,
  fixtureIndex,
  sourceRows,
}: {
  rawFixtures: JsonObject[];
  rawOdds: JsonObject[];
  rawStandings: JsonObject[];
  rawTeamStatistics: JsonObject[];
  rawRecentLeagueMatches: JsonObject[];
  rawExpectedGoals: JsonObject[];
  fixtureIndex: FixtureIndexRow[];
  sourceRows: CachedRawResponse[];
}): JsonObject {
  return {
    fixtures: rawFixtures.length,
    odds: rawOdds.length,
    standings: rawStandings.length,
    team_statistics: rawTeamStatistics.length,
    recent_league_matches: rawRecentLeagueMatches.length,
    expected_goals: rawExpectedGoals.length,
    predictions: 0,
    fixture_index_rows: fixtureIndex.length,
    source_rows: sourceRows.length,
    missing: {
      odds: fixtureIndex.filter((row) => !row.has_odds).length,
      standings: fixtureIndex.filter((row) => !row.has_standings).length,
      team_statistics: fixtureIndex.filter((row) => !row.has_team_statistics)
        .length,
      recent_form: fixtureIndex.filter((row) => !row.has_recent_form).length,
      expected_goals: fixtureIndex.filter((row) => !row.has_expected_goals)
        .length,
    },
  };
}

function emptySnapshotPublicationError(summary: JsonObject): string | null {
  const hasUsableData = [
    "fixtures",
    "odds",
    "standings",
    "team_statistics",
    "recent_league_matches",
    "expected_goals",
  ].some((key) => (numberValue(summary[key]) ?? 0) > 0);

  return hasUsableData
    ? null
    : "Refusing to publish an empty match feed snapshot.";
}

function provenanceSummary({
  options,
  season,
  seasonByLeague,
  sourceRows,
  asOf,
  scope,
}: {
  options: SnapshotOptions;
  season: number;
  seasonByLeague: Record<string, number>;
  sourceRows: CachedRawResponse[];
  asOf: string;
  scope: SnapshotScope;
}): JsonObject {
  const endpoints: JsonObject = {};
  for (const row of sourceRows) {
    endpoints[row.endpoint] = numberValue(endpoints[row.endpoint]) ?? 0;
    endpoints[row.endpoint] = (endpoints[row.endpoint] as number) + 1;
  }

  return {
    source,
    generated_by: "build-match-feed-snapshot",
    scope: scope.scope,
    scope_key: scope.scopeKey,
    season,
    season_by_league: seasonByLeague,
    timezone: options.timezone,
    window_start: options.windowStart,
    window_end: options.windowEnd,
    league_ids: options.leagueIds,
    bookmaker_id: options.bookmakerId,
    endpoints,
    source_rows: sourceRows.length,
    fetched_at_min: minTimestamp(sourceRows),
    fetched_at_max: maxTimestamp(sourceRows),
    as_of: asOf,
    note:
      "recent_league_matches and expected_goals are derived from factual cached endpoints; predictions remain empty until explicitly collected.",
  };
}

function snapshotScope(options: SnapshotOptions): SnapshotScope {
  const leagueIds = uniqueNumbers(options.leagueIds).sort((a, b) => a - b);
  if (leagueIds.length === 1) {
    return {
      scope: "league",
      scopeKey: `league:${leagueIds[0]}`,
      leagueIds,
    };
  }

  return {
    scope: "global",
    scopeKey: `global:${leagueIds.join(",")}`,
    leagueIds,
  };
}

function snapshotOptionsFromPayload(payload: JsonObject): SnapshotOptions {
  const today = dateOnly(new Date());
  const windowStart = stringValue(payload.window_start) ?? today;
  const windowEnd = stringValue(payload.window_end) ?? windowStart;
  const leagueIds = numberList(payload.league_ids);
  const fallbackSeason = numberValue(payload.season) ??
    new Date().getFullYear();
  const seasonByLeague = seasonByLeagueValue(
    payload.season_by_league,
  );
  const season = seasonByLeagueReference(seasonByLeague, fallbackSeason);
  const bookmakerId = numberValue(payload.bookmaker_id);
  const timezone = stringValue(payload.timezone) ?? defaultTimezone;
  const asOf = isoDateTimeValue(payload.as_of);
  const forceRebuild = booleanValue(payload.force_rebuild) ?? false;
  const bookmakerPriority = bookmakerPriorityValue(payload.bookmaker_priority);
  const recentFormDaysBack = numberValue(payload.recent_form_days_back) ?? 180;
  const recentFormMatches = numberValue(payload.recent_form_matches) ?? 5;

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
    season,
    seasonByLeague,
    timezone,
    windowStart,
    windowEnd,
    leagueIds,
    bookmakerId,
    bookmakerPriority,
    asOf,
    forceRebuild,
    recentFormDaysBack,
    recentFormMatches,
  };
}

function authorizeBuildRequest(request: Request): string | null {
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

function seasonForLeague(options: SnapshotOptions, leagueId: number): number {
  return options.seasonByLeague[String(leagueId)] ?? options.season;
}

function completeSeasonByLeague({
  options,
  sourceRows,
}: {
  options: SnapshotOptions;
  sourceRows: CachedRawResponse[];
}): Record<string, number> {
  const seasons: Record<string, number> = { ...options.seasonByLeague };
  for (const row of sourceRows) {
    if (row.endpoint !== "/leagues") {
      continue;
    }
    const leagueId = numberValue(row.query_params.id);
    if (leagueId === null || seasons[String(leagueId)] !== undefined) {
      continue;
    }
    seasons[String(leagueId)] = seasonForWindowFromLeaguesPayload(
      row.response_body,
      options.season,
      options.windowStart,
      options.windowEnd,
    );
  }
  return seasons;
}

function seasonForLeagueFromRows(
  options: SnapshotOptions,
  leagueId: number,
  leagueRows: CachedRawResponse[],
): number {
  const explicitSeason = options.seasonByLeague[String(leagueId)];
  if (explicitSeason !== undefined) {
    return explicitSeason;
  }

  for (const row of leagueRows) {
    return seasonForWindowFromLeaguesPayload(
      row.response_body,
      options.season,
      options.windowStart,
      options.windowEnd,
    );
  }

  return options.season;
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

  for (const row of flatApiFootballResponseItems(payload)) {
    const seasons = row.seasons;
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

function flatApiFootballResponseItems(payload: JsonObject): JsonObject[] {
  const response = payload.response;
  if (Array.isArray(response)) {
    return response.filter(isJsonObject);
  }
  return isJsonObject(response) ? [response] : [];
}

function seasonByLeagueValue(value: unknown): Record<string, number> {
  const source = objectValue(value) ?? {};
  const seasons: Record<string, number> = {};
  for (const [leagueId, season] of Object.entries(source)) {
    const parsedLeagueId = numberValue(leagueId);
    const parsedSeason = numberValue(season);
    if (parsedLeagueId !== null && parsedSeason !== null) {
      seasons[String(parsedLeagueId)] = parsedSeason;
    }
  }
  return seasons;
}

function seasonByLeagueReference(
  seasonByLeague: Record<string, number>,
  fallbackSeason: number,
): number {
  const first = Object.values(seasonByLeague).find((season) =>
    Number.isFinite(season)
  );
  return first ?? fallbackSeason;
}

function normalizeCachedRow(row: unknown): CachedRawResponse {
  if (row === null || typeof row !== "object" || Array.isArray(row)) {
    throw new Error("Unexpected cached response row.");
  }
  const value = row as JsonObject;
  return {
    source: stringValue(value.source) ?? source,
    endpoint: stringValue(value.endpoint) ?? "",
    query_hash: stringValue(value.query_hash) ?? "",
    query_params: objectValue(value.query_params) ?? {},
    response_status: numberValue(value.response_status) ?? 500,
    response_body: objectValue(value.response_body) ?? {},
    sync_run_id: stringValue(value.sync_run_id),
    fetched_at: stringValue(value.fetched_at) ?? new Date().toISOString(),
    as_of: stringValue(value.as_of) ?? stringValue(value.fetched_at) ??
      new Date().toISOString(),
  };
}

function flatResponseItems(rows: CachedRawResponse[]): JsonObject[] {
  const values: JsonObject[] = [];
  for (const row of rows) {
    const response = row.response_body.response;
    if (Array.isArray(response)) {
      values.push(...response.filter(isJsonObject));
    } else if (isJsonObject(response)) {
      values.push(response);
    }
  }
  return values;
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

function teamStatisticsRequests(
  fixtures: JsonObject[],
  options: SnapshotOptions,
): Array<{ leagueId: number; teamId: number; season: number }> {
  const requests = new Map<
    string,
    { leagueId: number; teamId: number; season: number }
  >();
  for (const row of fixtures) {
    const league = objectValue(row.league) ?? {};
    const leagueId = numberValue(league.id);
    const teams: JsonObject = objectValue(row.teams) ?? {};
    if (leagueId === null) {
      continue;
    }
    const season = numberValue(league.season) ?? seasonForLeague(
      options,
      leagueId,
    );
    for (const side of ["home", "away"]) {
      const team = objectValue(teams[side]);
      const teamId = numberValue((team ?? {}).id);
      if (teamId !== null) {
        requests.set(`${leagueId}:${teamId}`, {
          leagueId,
          teamId,
          season,
        });
      }
    }
  }
  return [...requests.values()];
}

type RecentFixtureRequest = {
  leagueId: number;
  teamId: number;
  season: number;
  from: string;
  to: string;
};

type FixtureStatisticsPayload = {
  fixtureId: number;
  statistics: JsonObject[];
};

function recentFixtureRequests(
  fixtures: JsonObject[],
  options: SnapshotOptions,
): RecentFixtureRequest[] {
  const requests = new Map<string, RecentFixtureRequest>();
  for (const row of fixtures) {
    const league = objectValue(row.league) ?? {};
    const leagueId = numberValue(league.id);
    const fixtureDateTime = stringValue((objectValue(row.fixture) ?? {}).date);
    if (leagueId === null || fixtureDateTime === null) {
      continue;
    }

    const fixtureDate = dateOnly(new Date(fixtureDateTime));
    const from = subtractDays(fixtureDate, options.recentFormDaysBack);
    const to = subtractDays(fixtureDate, 1);
    const season = numberValue(league.season) ?? seasonForLeague(
      options,
      leagueId,
    );
    const teams: JsonObject = objectValue(row.teams) ?? {};
    for (const side of ["home", "away"]) {
      const teamId = numberValue((objectValue(teams[side]) ?? {}).id);
      if (teamId !== null) {
        requests.set(`${leagueId}:${teamId}:${from}:${to}`, {
          leagueId,
          teamId,
          season,
          from,
          to,
        });
      }
    }
  }
  return [...requests.values()];
}

function normalizeRecentFixturesForTeam({
  leagueId,
  teamId,
  fixtures,
  maxMatches,
}: {
  leagueId: number;
  teamId: number;
  fixtures: JsonObject[];
  maxMatches: number;
}): JsonObject | null {
  const matches: JsonObject[] = [];
  let teamName: string | null = null;

  for (
    const row of [...fixtures]
      .filter(isCompletedFixture)
      .filter((fixture) => fixtureContainsTeam(fixture, teamId))
      .sort((a, b) => fixtureTimestamp(b) - fixtureTimestamp(a))
  ) {
    const teams = objectValue(row.teams) ?? {};
    const home = objectValue(teams.home) ?? {};
    const away = objectValue(teams.away) ?? {};
    const homeTeamId = numberValue(home.id);
    const awayTeamId = numberValue(away.id);
    const isHome = homeTeamId === teamId;
    const isAway = awayTeamId === teamId;
    if (!isHome && !isAway) {
      continue;
    }

    const own = isHome ? home : away;
    const opponent = isHome ? away : home;
    teamName ??= stringValue(own.name);
    const goals = objectValue(row.goals) ?? {};
    const homeGoals = numberValue(goals.home);
    const awayGoals = numberValue(goals.away);
    const goalsFor = isHome ? homeGoals : awayGoals;
    const goalsAgainst = isHome ? awayGoals : homeGoals;
    const result = recentResult(goalsFor, goalsAgainst);
    const fixture = objectValue(row.fixture) ?? {};
    const fixtureId = numberValue(fixture.id);
    if (fixtureId === null || result === null) {
      continue;
    }

    matches.push({
      fixture: {
        id: fixtureId,
        date: stringValue(fixture.date),
      },
      opponent: {
        id: numberValue(opponent.id),
        name: stringValue(opponent.name),
        logo: stringValue(opponent.logo),
      },
      venue: isHome ? "home" : "away",
      result,
      goals: {
        for: goalsFor,
        against: goalsAgainst,
      },
    });

    if (matches.length >= maxMatches) {
      break;
    }
  }

  if (matches.length === 0) {
    return null;
  }

  return {
    league: { id: leagueId },
    team: {
      id: teamId,
      name: teamName ?? "Equipe",
    },
    matches,
  };
}

function recentFixtureIdsFromRows(rows: JsonObject[]): number[] {
  const fixtureIds = new Set<number>();
  for (const row of rows) {
    for (const match of arrayValue(row.matches)) {
      const matchObject = objectValue(match) ?? {};
      const fixtureId = numberValue(
        (objectValue(matchObject.fixture) ?? {}).id,
      );
      if (fixtureId !== null) {
        fixtureIds.add(fixtureId);
      }
    }
  }
  return [...fixtureIds];
}

function expectedGoalsSnapshots({
  recentLeagueMatches,
  fixtureStatisticsRows,
  asOf,
}: {
  recentLeagueMatches: JsonObject[];
  fixtureStatisticsRows: FixtureStatisticsPayload[];
  asOf: string;
}): JsonObject[] {
  const statisticsByFixture = new Map<number, Map<number, number>>();
  for (const row of fixtureStatisticsRows) {
    const byTeam = new Map<number, number>();
    for (const teamStatistics of row.statistics) {
      const teamId = numberValue((objectValue(teamStatistics.team) ?? {}).id);
      const xg = expectedGoalsValue(arrayValue(teamStatistics.statistics));
      if (teamId !== null && xg !== null) {
        byTeam.set(teamId, xg);
      }
    }
    if (byTeam.size > 0) {
      statisticsByFixture.set(row.fixtureId, byTeam);
    }
  }

  const snapshots: JsonObject[] = [];
  for (const row of recentLeagueMatches) {
    const team = objectValue(row.team) ?? {};
    const teamId = numberValue(team.id);
    if (teamId === null) {
      continue;
    }

    const samples: Array<{
      xgFor: number;
      xgAgainst: number;
      goalsFor: number;
      goalsAgainst: number;
    }> = [];
    for (const match of arrayValue(row.matches)) {
      const matchObject = objectValue(match) ?? {};
      const fixtureId = numberValue(
        (objectValue(matchObject.fixture) ?? {}).id,
      );
      const opponentId = numberValue(
        (objectValue(matchObject.opponent) ?? {}).id,
      );
      if (fixtureId === null || opponentId === null) {
        continue;
      }
      const stats = statisticsByFixture.get(fixtureId);
      const xgFor = stats?.get(teamId);
      const xgAgainst = stats?.get(opponentId);
      const goals = objectValue(matchObject.goals) ?? {};
      const goalsFor = numberValue(goals.for);
      const goalsAgainst = numberValue(goals.against);
      if (
        xgFor === undefined ||
        xgAgainst === undefined ||
        goalsFor === null ||
        goalsAgainst === null
      ) {
        continue;
      }
      samples.push({ xgFor, xgAgainst, goalsFor, goalsAgainst });
    }

    if (samples.length === 0) {
      continue;
    }

    snapshots.push({
      team: {
        id: teamId,
        name: stringValue(team.name) ?? "Equipe",
      },
      asOf,
      sampleSize: samples.length,
      rolling: {
        xgFor5: round2(average(samples.map((sample) => sample.xgFor))),
        xgAgainst5: round2(
          average(samples.map((sample) => sample.xgAgainst)),
        ),
        goalsFor5: sum(samples.map((sample) => sample.goalsFor)),
        goalsAgainst5: sum(samples.map((sample) => sample.goalsAgainst)),
      },
      season: {
        xgForAverage: round2(average(samples.map((sample) => sample.xgFor))),
        xgAgainstAverage: round2(
          average(samples.map((sample) => sample.xgAgainst)),
        ),
      },
      latest: {
        xgFor: round2(samples[0].xgFor),
        xgAgainst: round2(samples[0].xgAgainst),
      },
    });
  }

  return snapshots;
}

function isCompletedFixture(row: JsonObject): boolean {
  const status = objectValue((objectValue(row.fixture) ?? {}).status) ?? {};
  const shortStatus = stringValue(status.short);
  if (shortStatus !== null && ["FT", "AET", "PEN"].includes(shortStatus)) {
    return true;
  }
  const goals = objectValue(row.goals) ?? {};
  return numberValue(goals.home) !== null && numberValue(goals.away) !== null;
}

function fixtureContainsTeam(row: JsonObject, teamId: number): boolean {
  const teams = objectValue(row.teams) ?? {};
  return ["home", "away"].some((side) =>
    numberValue((objectValue(teams[side]) ?? {}).id) === teamId
  );
}

function fixtureTimestamp(row: JsonObject): number {
  const fixture = objectValue(row.fixture) ?? {};
  const timestamp = numberValue(fixture.timestamp);
  if (timestamp !== null) {
    return timestamp;
  }
  const date = stringValue(fixture.date);
  return date === null ? 0 : Date.parse(date);
}

function recentResult(
  goalsFor: number | null,
  goalsAgainst: number | null,
): string | null {
  if (goalsFor === null || goalsAgainst === null) {
    return null;
  }
  if (goalsFor > goalsAgainst) {
    return "W";
  }
  if (goalsFor === goalsAgainst) {
    return "D";
  }
  return "L";
}

function expectedGoalsValue(statistics: unknown[]): number | null {
  for (const item of statistics) {
    const row = objectValue(item);
    if (row === null) {
      continue;
    }
    const type = stringValue(row.type)?.toLowerCase().replace(/\s+/g, "_");
    if (type === "expected_goals") {
      return decimalValue(row.value);
    }
  }
  return null;
}

function average(values: number[]): number {
  if (values.length === 0) {
    return 0;
  }
  return sum(values) / values.length;
}

function sum(values: number[]): number {
  return values.reduce((total, value) => total + value, 0);
}

function round2(value: number): number {
  return Math.round(value * 100) / 100;
}

function bookmakerPriorityValue(value: unknown): JsonObject[] {
  if (!Array.isArray(value)) {
    return defaultBookmakerPriority;
  }

  const priority = value
    .map((item) => {
      if (!isJsonObject(item)) {
        return null;
      }
      const id = numberValue(item.id);
      const name = stringValue(item.name);
      return id === null || name === null ? null : { id, name };
    })
    .filter((item): item is { id: number; name: string } => item !== null);

  return priority.length === 0 ? defaultBookmakerPriority : priority;
}

function latestTimestamp(rows: CachedRawResponse[]): string | null {
  return maxTimestamp(rows.map((row) => row.as_of ?? row.fetched_at));
}

function minTimestamp(value: CachedRawResponse[] | string[]): string | null {
  const timestamps = Array.isArray(value) && value.length > 0 &&
      typeof value[0] === "object"
    ? (value as CachedRawResponse[]).map((row) => row.fetched_at)
    : value as string[];
  const sorted = timestamps.filter(Boolean).sort();
  return sorted.length === 0 ? null : sorted[0];
}

function maxTimestamp(value: CachedRawResponse[] | string[]): string | null {
  const timestamps = Array.isArray(value) && value.length > 0 &&
      typeof value[0] === "object"
    ? (value as CachedRawResponse[]).map((row) => row.fetched_at)
    : value as string[];
  const sorted = timestamps.filter(Boolean).sort();
  return sorted.length === 0 ? null : sorted[sorted.length - 1];
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

function isoDateTimeValue(value: unknown): string | null {
  const text = stringValue(value);
  if (text === null) {
    return null;
  }
  const parsed = Date.parse(text);
  return Number.isNaN(parsed) ? null : new Date(parsed).toISOString();
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

function decimalValue(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === "string" && value.trim() !== "") {
    const parsed = Number(value.replace(",", "."));
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function booleanValue(value: unknown): boolean | null {
  if (typeof value === "boolean") {
    return value;
  }
  if (typeof value === "string") {
    if (value.toLowerCase() === "true") {
      return true;
    }
    if (value.toLowerCase() === "false") {
      return false;
    }
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

function uniqueStrings(values: string[]): string[] {
  return [...new Set(values)];
}

function uniqueNumbers(values: number[]): number[] {
  return [...new Set(values)];
}

function stableSlug(parts: string[]): string {
  const text = parts.join("-").toLowerCase();
  const slug = text
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
  return slug === "" ? "unknown" : slug;
}

function countryCode(countryName: string): string {
  const known: Record<string, string> = {
    Austria: "AT",
    Belgium: "BE",
    Denmark: "DK",
    England: "GB-ENG",
    Finland: "FI",
    France: "FR",
    Germany: "DE",
    Italy: "IT",
    Netherlands: "NL",
    Norway: "NO",
    Portugal: "PT",
    Spain: "ES",
    Sweden: "SE",
    Wales: "GB-WLS",
  };
  return known[countryName] ??
    countryName.slice(0, 3).toUpperCase().replace(/[^A-Z]/g, "UN");
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "content-type": "application/json",
    },
  });
}
