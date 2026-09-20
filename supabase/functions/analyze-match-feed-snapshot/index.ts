type JsonObject = Record<string, unknown>;

const corsHeaders = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers":
    "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
};

// This function is deliberately the boundary between private provider data and
// the public mobile read model. It exposes a reduced presentation context for
// the ranking and form screens, never provider cache, events or player pages.
Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return respond({ ok: true });
  if (request.method !== "POST") {
    return respond({ error: "Method not allowed." }, 405);
  }
  const secret = requiredEnv("API_FOOTBALL_SYNC_SECRET");
  if (request.headers.get("authorization") !== `Bearer ${secret}`) {
    return respond({ error: "Unauthorized." }, 401);
  }

  try {
    const payload = objectValue(await request.json()) ?? {};
    const snapshotId = stringValue(payload.snapshot_id);
    if (snapshotId === null) {
      return respond({ error: "snapshot_id is required." }, 400);
    }
    const supabaseUrl = requiredEnv("SUPABASE_URL");
    const serviceRoleKey = requiredEnv("SUPABASE_SERVICE_ROLE_KEY");

    const existing = await supabaseFetch({
      supabaseUrl,
      serviceRoleKey,
      path:
        `/rest/v1/match_feed_analysis_snapshots?select=id&source_snapshot_id=eq.${
          encodeURIComponent(snapshotId)
        }&limit=1`,
      method: "GET",
    });
    if (existing.length > 0) {
      return respond({
        ok: true,
        reused: true,
        analysisSnapshotId: String(objectValue(existing[0])?.id ?? ""),
      });
    }

    // Announcements are the single source for both the Bilan and the mobile
    // feed. Publishing happens before materialisation, so a reading has the
    // same definition and immutable evidence everywhere in the product.
    const publication = await invokeFunction({
      supabaseUrl,
      name: "publish-reading-announcements",
      secret,
      payload: { snapshot_id: snapshotId },
    });
    if (booleanValue(publication.ok) !== true) {
      throw new Error(
        `Reading publication failed: ${
          stringValue(publication.error) ?? "unknown error"
        }`,
      );
    }

    const snapshots = await supabaseFetch({
      supabaseUrl,
      serviceRoleKey,
      path:
        `/rest/v1/match_feed_snapshots?select=id,schema_version,source,scope,scope_key,league_ids,timezone,window_start,window_end,captured_at,as_of,payload,coverage_summary&id=eq.${
          encodeURIComponent(snapshotId)
        }&limit=1`,
      method: "GET",
    });
    const snapshot = objectValue(snapshots[0]);
    if (snapshot === null) throw new Error("Snapshot not found.");
    const snapshotPayload = objectValue(snapshot.payload);
    const raw = objectValue(snapshotPayload?.raw) ?? {};
    const fixtures = objectList(raw.fixtures);
    const odds = objectList(raw.odds);
    const presentationStandings = compactStandings(objectList(raw.standings));
    const presentationRecentMatches = compactRecentMatches(
      objectList(raw.recent_league_matches),
    );
    const presentationHeadToHead = compactHeadToHead(
      objectList(raw.head_to_head),
    );
    // Tier assignments are calculated here, from the same standings snapshot
    // that powers the mobile table. The app only renders this compact result.
    const tiersByLeagueId = buildTierSnapshots({
      standings: objectList(raw.standings),
      fixtures,
      capturedAt: stringValue(snapshot.captured_at),
    });

    // Announcements are immutable and intentionally written only once per
    // fixture/reading. A newer source snapshot must reuse the existing
    // announcement rather than filtering it out by source snapshot.
    const fixtureIds = [
      ...new Set(
        fixtures
          .map((row) => numberValue((objectValue(row.fixture) ?? {}).id))
          .filter((id): id is number => id !== null),
      ),
    ];
    const announced = fixtureIds.length === 0 ? [] : await supabaseFetch({
      supabaseUrl,
      serviceRoleKey,
      path:
        `/rest/v1/match_reading_announcements?select=fixture_id,reading_id,reading_label,subject_side,subject_team_id,player_id,player_name,evidence,sample_size,announcement_kind,required_reading_ids,outcome_rule&fixture_id=in.(${
          fixtureIds.join(",")
        })&order=fixture_id,reading_id`,
      method: "GET",
    });
    const computedByFixture = new Map<number, JsonObject[]>();
    for (const value of announced) {
      const row = objectValue(value);
      const fixtureId = row === null ? null : numberValue(row.fixture_id);
      if (fixtureId === null || row === null) continue;
      const item = {
        id: stringValue(row.reading_id) ?? "unknown",
        label: stringValue(row.reading_label) ?? "Lecture",
        kind: stringValue(row.announcement_kind) ?? "reading",
        // A nuance is a pre-match counter-signal. Keep that semantic in the
        // compact read model so the app can display it separately from the
        // readings that support a thesis.
        is_contradiction: stringValue(row.announcement_kind) === "nuance",
        side: stringValue(row.subject_side) ?? "match",
        subject_team_id: stringValue(row.subject_team_id) ??
          `api-fixture-${fixtureId}`,
        player_id: numberValue(row.player_id),
        player_name: stringValue(row.player_name),
        sample_size: numberValue(row.sample_size) ?? 0,
        evidence: objectList(row.evidence),
        required_reading_ids: stringList(row.required_reading_ids),
        outcome_rule: stringValue(row.outcome_rule),
      };
      const values = computedByFixture.get(fixtureId) ?? [];
      values.push(item);
      computedByFixture.set(fixtureId, values);
    }

    const computedFixtures: JsonObject[] = [];
    for (const fixtureRow of fixtures) {
      const fixture = objectValue(fixtureRow.fixture) ?? {};
      const league = objectValue(fixtureRow.league) ?? {};
      const fixtureId = numberValue(fixture.id);
      if (fixtureId === null) continue;
      const items = computedByFixture.get(fixtureId) ?? [];
      computedFixtures.push({
        fixture_id: fixtureId,
        readings: items.filter((item) =>
          item.kind === "reading" || item.kind === "nuance"
        ),
        scenarios: items.filter((item) => item.kind === "scenario"),
        tier_snapshot: numberValue(league.id) === null
          ? null
          : tiersByLeagueId.get(numberValue(league.id)!),
      });
    }

    const compactPayload = {
      schema_version: 1,
      source: stringValue(snapshot.source) ?? "api-football",
      captured_at: stringValue(snapshot.captured_at),
      timezone: stringValue(snapshot.timezone) ?? "Europe/Paris",
      window_start: stringValue(snapshot.window_start),
      window_end: stringValue(snapshot.window_end),
      raw: {
        fixtures,
        odds,
        // Compact, display-only data. The app maps these values to widgets but
        // does not calculate football signals from provider history.
        standings: presentationStandings,
        recent_league_matches: presentationRecentMatches,
        head_to_head: presentationHeadToHead,
      },
      computed: {
        engine_version: "server_computed_feed_v1",
        fixtures: computedFixtures,
      },
    };
    const stored = await supabaseFetch({
      supabaseUrl,
      serviceRoleKey,
      path: "/rest/v1/match_feed_analysis_snapshots",
      method: "POST",
      body: [{
        source_snapshot_id: snapshotId,
        schema_version: 1,
        source: stringValue(snapshot.source) ?? "api-football",
        scope: stringValue(snapshot.scope) ?? "global",
        scope_key: stringValue(snapshot.scope_key) ?? "global",
        league_ids: numberList(snapshot.league_ids),
        timezone: stringValue(snapshot.timezone) ?? "Europe/Paris",
        window_start: stringValue(snapshot.window_start),
        window_end: stringValue(snapshot.window_end),
        captured_at: stringValue(snapshot.captured_at),
        as_of: stringValue(snapshot.as_of),
        payload: compactPayload,
        coverage_summary: {
          source_snapshot_id: snapshotId,
          fixture_count: fixtures.length,
          reading_count: announced.filter((value) =>
            stringValue(objectValue(value)?.announcement_kind) !== "scenario"
          ).length,
          scenario_count: announced.filter((value) =>
            stringValue(objectValue(value)?.announcement_kind) === "scenario"
          ).length,
          publication: publication.summary ?? {},
        },
      }],
      prefer: "return=representation",
    });
    return respond({
      ok: true,
      reused: false,
      analysisSnapshotId: stringValue(objectValue(stored[0])?.id),
      summary: { fixtures: fixtures.length, announcements: announced.length },
    });
  } catch (error) {
    return respond({
      ok: false,
      error: error instanceof Error ? error.message : String(error),
    }, 500);
  }
});

async function invokeFunction(
  { supabaseUrl, name, secret, payload }: {
    supabaseUrl: string;
    name: string;
    secret: string;
    payload: JsonObject;
  },
): Promise<JsonObject> {
  const response = await fetch(`${supabaseUrl}/functions/v1/${name}`, {
    method: "POST",
    headers: {
      authorization: `Bearer ${secret}`,
      "content-type": "application/json",
    },
    body: JSON.stringify(payload),
  });
  const body = objectValue(await response.json().catch(() => ({}))) ?? {};
  if (!response.ok) {
    throw new Error(
      `${name}: ${response.status} ${stringValue(body.error) ?? ""}`,
    );
  }
  return body;
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
  method: "GET" | "POST";
  body?: JsonObject[];
  prefer?: string;
}): Promise<unknown[]> {
  const response = await fetch(`${supabaseUrl}${path}`, {
    method,
    headers: {
      apikey: serviceRoleKey,
      authorization: `Bearer ${serviceRoleKey}`,
      "content-type": "application/json",
      ...(prefer === undefined ? {} : { prefer }),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  if (!response.ok) {
    throw new Error(
      `Supabase ${method} ${path}: ${response.status} ${await response.text()}`,
    );
  }
  const result = await response.json().catch(() => []);
  return Array.isArray(result) ? result : [];
}

type TierRow = {
  teamId: number;
  teamName: string;
  rank: number;
  points: number;
  played: number;
  group: string | null;
  description: string | null;
};

// The display Tier map is intentionally data-led: the podium and the official
// relegation zone are anchors, then at most two statistically visible breaks
// split the middle of the standings. This keeps a compact three-to-five tier
// presentation from the fifth completed matchday without inventing breaks.
function buildTierSnapshots({
  standings,
  fixtures,
  capturedAt,
}: {
  standings: JsonObject[];
  fixtures: JsonObject[];
  capturedAt: string | null;
}): Map<number, JsonObject> {
  const result = new Map<number, JsonObject>();
  const fixtureLeagueData = new Map<number, JsonObject>();
  for (const fixture of fixtures) {
    const league = objectValue(fixture.league);
    const leagueId = league === null ? null : numberValue(league.id);
    if (league !== null && leagueId !== null && !fixtureLeagueData.has(leagueId)) {
      fixtureLeagueData.set(leagueId, league);
    }
  }

  for (const standingRow of standings) {
    const league = objectValue(standingRow.league);
    const leagueId = league === null ? null : numberValue(league.id);
    if (league === null || leagueId === null) continue;
    const groups = Array.isArray(league.standings) ? league.standings : [];
    const rows = groups
      .flatMap((group) => objectList(group))
      .map(tierRowFromStanding)
      .filter((row): row is TierRow => row !== null)
      .sort((left, right) => left.rank - right.rank);
    const snapshot = buildTierSnapshot({
      leagueId,
      season: numberValue(
        fixtureLeagueData.get(leagueId)?.season ?? league.season,
      ) ?? 0,
      rows,
      capturedAt,
    });
    if (snapshot !== null) result.set(leagueId, snapshot);
  }
  return result;
}

function tierRowFromStanding(value: JsonObject): TierRow | null {
  const team = objectValue(value.team) ?? {};
  const all = objectValue(value.all) ?? {};
  const teamId = numberValue(team.id);
  const rank = numberValue(value.rank);
  const points = numberValue(value.points);
  const played = numberValue(all.played);
  if (teamId === null || rank === null || points === null || played === null) {
    return null;
  }
  return {
    teamId,
    teamName: stringValue(team.name) ?? "Équipe",
    rank,
    points,
    played,
    group: stringValue(value.group),
    description: stringValue(value.description),
  };
}

function buildTierSnapshot({
  leagueId,
  season,
  rows,
  capturedAt,
}: {
  leagueId: number;
  season: number;
  rows: TierRow[];
  capturedAt: string | null;
}): JsonObject | null {
  if (rows.length < 10 || rows.length > 24 || !hasValidRanks(rows)) {
    return null;
  }
  const played = rows.map((row) => row.played);
  const minPlayed = Math.min(...played);
  const maxPlayed = Math.max(...played);
  const medianPlayed = median(played);
  // From the fifth matchday, publish provisional tiers. A severely uneven
  // table stays hidden rather than pretending the ranking is comparable.
  if (medianPlayed < 5 || minPlayed < 4 || maxPlayed - minPlayed > Math.max(4, Math.ceil(medianPlayed / 3))) {
    return null;
  }
  const relegationStart = officialRelegationStart(rows);
  if (relegationStart === null || relegationStart <= 3) return null;
  const middleStart = 4;
  const middleEnd = relegationStart - 1;
  const middle = rows.filter((row) => row.rank >= middleStart && row.rank <= middleEnd);
  const points = rows.map((row) => row.points);
  const gaps = points.slice(0, -1).map((point, index) => point - points[index + 1]);
  const positiveGaps = gaps.filter((gap) => gap > 0);
  const medianGap = median(gaps);
  const typicalGap = Math.max(1, positiveGaps.length === 0 ? 0 : median(positiveGaps));
  const rawMad = median(gaps.map((gap) => Math.abs(gap - medianGap)));
  const robustScale = rawMad > 0 ? rawMad * 1.4826 : Math.max(1, typicalGap * 0.5);
  const candidates = [] as JsonObject[];
  for (let index = middleStart; index < middleEnd; index += 1) {
    const rawGap = gaps[index - 1];
    const ratio = rawGap / typicalGap;
    const robustZ = Math.max(0, (rawGap - medianGap) / robustScale);
    const upperCount = index - middleStart + 1;
    const lowerCount = middle.length - upperCount;
    if (rawGap < 3 || upperCount < 2 || lowerCount < 2 || (ratio < 2 && robustZ < 2.5)) continue;
    const score = Math.round(Math.min(100, 35 + ratio * 12 + robustZ * 9));
    candidates.push({
      boundary_index: index,
      upper_rank: index,
      lower_rank: index + 1,
      raw_gap: rawGap,
      score,
      strength: score >= 78 ? "strong" : "moderate",
    });
  }
  const selected = selectTierBoundaries(candidates, middleStart, middleEnd);
  const selectedIndexes = selected.map((value) => numberValue(value.boundary_index)!).sort((a, b) => a - b);
  const identity = rows.map((row) => `${row.teamId}:${row.rank}:${row.points}:${row.played}`).join("|");
  const isMature = minPlayed >= 12;
  const assignments = rows.map((row) => ({
    team_id: row.teamId,
    team_name: row.teamName,
    rank: row.rank,
    points: row.points,
    played: row.played,
    points_per_game: row.played === 0 ? 0 : row.points / row.played,
    group: row.group,
    description: row.description,
    assigned_tier: tierForRank(row.rank, relegationStart, selectedIndexes),
  }));
  return {
    competition_id: String(leagueId),
    season,
    analysis_as_of: capturedAt,
    tier_system_version: "tier-server-v1",
    standings_snapshot_identity: identity,
    status: isMature ? "mature" : "immature",
    maturity: isMature ? "mature" : "immature",
    team_count: rows.length,
    confirmed_boundaries: selected,
    tier_partition_boundaries: selected,
    team_assignments: assignments,
  };
}

function hasValidRanks(rows: TierRow[]): boolean {
  return rows.every((row, index) => row.rank === index + 1) &&
    rows.every((row, index) => index === 0 || row.points <= rows[index - 1].points) &&
    new Set(rows.map((row) => row.group).filter((group) => group !== null)).size <= 1;
}

function officialRelegationStart(rows: TierRow[]): number | null {
  const last = rows.at(-1)?.description?.toLowerCase() ?? "";
  if (!last.includes("relegation")) return null;
  let index = rows.length - 1;
  while (index > 0 && (rows[index - 1].description?.toLowerCase() ?? "") === last) index -= 1;
  return rows[index].rank;
}

function selectTierBoundaries(candidates: JsonObject[], middleStart: number, middleEnd: number): JsonObject[] {
  const selected: JsonObject[] = [];
  for (const candidate of [...candidates].sort((left, right) =>
    (numberValue(right.score) ?? 0) - (numberValue(left.score) ?? 0))) {
    const boundary = numberValue(candidate.boundary_index)!;
    const indexes = [...selected.map((value) => numberValue(value.boundary_index)!), boundary].sort((a, b) => a - b);
    const separators = [
      middleStart,
      ...indexes.map((index) => index + 1),
      middleEnd + 1,
    ];
    const segments = separators
      .slice(0, -1)
      .map((start, index) => separators[index + 1] - start);
    if (segments.every((size) => size >= 2)) selected.push(candidate);
    if (selected.length === 2) break;
  }
  return selected.sort((left, right) => (numberValue(left.boundary_index) ?? 0) - (numberValue(right.boundary_index) ?? 0));
}

function tierForRank(rank: number, relegationStart: number, boundaries: number[]): string {
  if (rank <= 3) return "TIER_1";
  if (rank >= relegationStart) return "TIER_5";
  if (boundaries.length === 0) return "TIER_3";
  if (boundaries.length === 1) return rank <= boundaries[0] ? "TIER_2" : "TIER_4";
  if (rank <= boundaries[0]) return "TIER_2";
  if (rank <= boundaries[1]) return "TIER_3";
  return "TIER_4";
}

function median(values: number[]): number {
  const sorted = [...values].sort((left, right) => left - right);
  if (sorted.length === 0) return 0;
  const middle = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 0 ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle];
}

function compactStandings(rows: JsonObject[]): JsonObject[] {
  return rows.map((row) => {
    const league = objectValue(row.league) ?? {};
    const groups = Array.isArray(league.standings) ? league.standings : [];
    return {
      league: {
        id: numberValue(league.id),
        standings: groups.map((group) =>
          objectList(group).map((standing) => {
            const team = objectValue(standing.team) ?? {};
            const compactSplit = (name: string) => {
              const split = objectValue(standing[name]) ?? {};
              const goals = objectValue(split.goals) ?? {};
              return {
                played: numberValue(split.played),
                win: numberValue(split.win),
                draw: numberValue(split.draw),
                lose: numberValue(split.lose),
                goals: {
                  for: numberValue(goals.for),
                  against: numberValue(goals.against),
                },
              };
            };
            return {
              rank: numberValue(standing.rank),
              points: numberValue(standing.points),
              goalsDiff: numberValue(standing.goalsDiff),
              form: stringValue(standing.form),
              description: stringValue(standing.description),
              group: stringValue(standing.group),
              team: { id: numberValue(team.id), name: stringValue(team.name) },
              all: compactSplit("all"),
              home: compactSplit("home"),
              away: compactSplit("away"),
            };
          })
        ),
      },
    };
  });
}

function compactRecentMatches(rows: JsonObject[]): JsonObject[] {
  return rows.map((row) => {
    const league = objectValue(row.league) ?? {};
    const team = objectValue(row.team) ?? {};
    return {
      league: { id: numberValue(league.id) },
      team: { id: numberValue(team.id), name: stringValue(team.name) },
      matches: objectList(row.matches).slice(0, 5).map((match) => {
        const value = objectValue(match) ?? {};
        const fixture = objectValue(value.fixture) ?? {};
        const opponent = objectValue(value.opponent) ?? {};
        const goals = objectValue(value.goals) ?? {};
        return {
          fixture: { date: stringValue(fixture.date) },
          opponent: {
            id: numberValue(opponent.id),
            name: stringValue(opponent.name),
            logo: stringValue(opponent.logo),
          },
          venue: stringValue(value.venue),
          result: stringValue(value.result),
          goals: {
            for: numberValue(goals.for),
            against: numberValue(goals.against),
          },
        };
      }),
    };
  });
}

// H2H is presentation data, not a raw provider payload. Keep only the fields
// needed by the app to compare meetings within the current competition.
function compactHeadToHead(rows: JsonObject[]): JsonObject[] {
  return rows.flatMap((row) => {
    const fixture = objectValue(row.fixture) ?? {};
    const fixtureId = numberValue(fixture.id);
    if (fixtureId === null) return [];

    const matches = objectList(row.matches).flatMap((match) => {
      const matchFixture = objectValue(match.fixture) ?? {};
      const league = objectValue(match.league) ?? {};
      const teams = objectValue(match.teams) ?? {};
      const home = objectValue(teams.home) ?? {};
      const away = objectValue(teams.away) ?? {};
      const goals = objectValue(match.goals) ?? {};
      const date = stringValue(matchFixture.date);
      const leagueId = numberValue(league.id);
      const homeId = numberValue(home.id);
      const awayId = numberValue(away.id);
      const homeGoals = numberValue(goals.home);
      const awayGoals = numberValue(goals.away);
      if (
        date === null || leagueId === null || homeId === null || awayId === null ||
        homeGoals === null || awayGoals === null
      ) return [];
      return [{
        fixture: { date },
        league: { id: leagueId, name: stringValue(league.name) },
        teams: {
          home: { id: homeId, name: stringValue(home.name) },
          away: { id: awayId, name: stringValue(away.name) },
        },
        goals: { home: homeGoals, away: awayGoals },
      }];
    });

    return matches.length == 0 ? [] : [{
      fixture: { id: fixtureId },
      matches: matches.slice(0, 20),
    }];
  });
}

function objectValue(value: unknown): JsonObject | null {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as JsonObject
    : null;
}
function objectList(value: unknown): JsonObject[] {
  return Array.isArray(value)
    ? value.map(objectValue).filter((value): value is JsonObject =>
      value !== null
    )
    : [];
}
function stringList(value: unknown): string[] {
  return Array.isArray(value)
    ? value.map(stringValue).filter((value): value is string => value !== null)
    : [];
}
function numberList(value: unknown): number[] {
  return Array.isArray(value)
    ? value.map(numberValue).filter((value): value is number => value !== null)
    : [];
}
function stringValue(value: unknown): string | null {
  return typeof value === "string" && value.length > 0 ? value : null;
}
function numberValue(value: unknown): number | null {
  const parsed = typeof value === "number"
    ? value
    : typeof value === "string"
    ? Number(value)
    : Number.NaN;
  return Number.isFinite(parsed) ? parsed : null;
}
function booleanValue(value: unknown): boolean | null {
  return typeof value === "boolean" ? value : null;
}
function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing ${name}`);
  return value;
}
function respond(payload: JsonObject, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...corsHeaders,
      "content-type": "application/json; charset=utf-8",
    },
  });
}
