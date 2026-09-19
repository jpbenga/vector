import { assessStructuralGap } from "../_shared/structural_gap_policy.ts";

type JsonObject = Record<string, unknown>;

const corsHeaders = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers":
    "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
};

const minimumDistributionTeamCount = 10;

type GoalProfile = {
  leagueId: number;
  teamId: number;
  teamName: string;
  played: number;
  over25: number;
  btts: number;
  totalGoals: number;
};

type TeamPerformanceProfile = {
  leagueId: number;
  teamId: number;
  teamName: string;
  played: number;
  goalsFor: number;
  goalsAgainst: number;
};

type EdgeZones = {
  high: Set<number>;
  low: Set<number>;
};

type RecentForm = {
  results: string[];
};

type VenueProfile = {
  homePlayed: number;
  homeWins: number;
  homeLosses: number;
  awayPlayed: number;
  awayWins: number;
  awayLosses: number;
};

type StandingProfile = {
  rank: number;
  points: number;
  played: number;
};

type ExpectedGoalProfile = {
  leagueId: number;
  teamId: number;
  sampleSize: number;
  xgFor: number;
  xgAgainst: number;
  goalsMinusXg: number;
};

type ReadingDefinition = {
  id: "frequent_over_25" | "frequent_under_25" | "frequent_btts";
  label: string;
  outcomeRule: "over_25" | "under_25" | "btts";
  evidenceVerb: string;
  valueFor: (profile: GoalProfile) => number;
};

const readingDefinitions: ReadingDefinition[] = [
  {
    id: "frequent_over_25",
    label: "Tendance over 2,5 buts",
    outcomeRule: "over_25",
    evidenceVerb: "dépasse 2,5 buts",
    valueFor: (profile) => profile.over25 / profile.played,
  },
  {
    id: "frequent_under_25",
    label: "Tendance under 2,5 buts",
    outcomeRule: "under_25",
    evidenceVerb: "reste sous 2,5 buts",
    valueFor: (profile) => 1 - profile.over25 / profile.played,
  },
  {
    id: "frequent_btts",
    label: "BTTS fréquent",
    outcomeRule: "btts",
    evidenceVerb: "voit les deux équipes marquer",
    valueFor: (profile) => profile.btts / profile.played,
  },
];

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return respond({ ok: true });
  if (request.method !== "POST") {
    return respond({ error: "Method not allowed." }, 405);
  }

  const syncSecret = requiredEnv("API_FOOTBALL_SYNC_SECRET");
  if (request.headers.get("authorization") !== `Bearer ${syncSecret}`) {
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
    const rows = await supabaseFetch({
      supabaseUrl,
      serviceRoleKey,
      path:
        "/rest/v1/match_feed_snapshots?select=id,captured_at,payload&id=eq." +
        encodeURIComponent(snapshotId) + "&limit=1",
      method: "GET",
    });
    const snapshot = objectValue(rows[0]);
    const capturedAt = snapshot === null
      ? null
      : dateValue(snapshot.captured_at);
    const snapshotPayload = snapshot === null
      ? null
      : objectValue(snapshot.payload);
    if (capturedAt === null || snapshotPayload === null) {
      return respond({ error: "Snapshot not found or incomplete." }, 404);
    }

    const raw = objectValue(snapshotPayload.raw) ?? {};
    const fixtures = objectList(raw.fixtures);
    const leagueFixtures = objectList(raw.league_fixtures);
    const recentForms = recentFormsByTeam(
      objectList(raw.recent_league_matches),
    );
    const teamStatistics = objectList(raw.team_statistics);
    const venueProfiles = venueProfilesByTeam(teamStatistics);
    const performanceProfiles = performanceProfilesByTeam(teamStatistics);
    const expectedGoals = expectedGoalProfiles(objectList(raw.expected_goals));
    const standings = standingsByTeam(objectList(raw.standings));
    const profiles = goalProfiles(leagueFixtures, capturedAt);
    const highZones = highZoneTeamIds(profiles);
    const totalGoalZones = edgeZonesByLeague(
      profiles,
      (profile) => profile.totalGoals / profile.played,
    );
    const performanceZones = performanceEdgeZones(performanceProfiles);
    const goalAnnouncements = announcementRows({
      snapshotId,
      capturedAt,
      fixtures,
      profiles,
      highZones,
    });
    const levelFormVenueAnnouncements = levelFormVenueAnnouncementRows({
      snapshotId,
      capturedAt,
      fixtures,
      recentForms,
      venueProfiles,
      standings,
    });
    const attackDefenseAnnouncements = attackDefenseAnnouncementRows({
      snapshotId,
      capturedAt,
      fixtures,
      profiles,
      totalGoalZones,
      performanceProfiles,
      performanceZones,
    });
    const playerAnnouncements = playerAnnouncementRows({
      snapshotId,
      capturedAt,
      fixtures,
      playerRecentPerformances: objectList(raw.player_recent_performances),
      injuries: objectList(raw.injuries),
    });
    const timingAnnouncements = timingAnnouncementRows({
      snapshotId,
      capturedAt,
      fixtures,
      teamStatistics,
    });
    const nuanceAnnouncements = nuanceAnnouncementRows({
      snapshotId,
      capturedAt,
      fixtures,
      recentForms,
      expectedGoals,
    });
    // Scenarios are resolved from the same immutable pre-match readings that
    // the app displays.  The mobile client never combines football inputs.
    const scenarioSupportAnnouncements = scenarioSupportAnnouncementRows({
      snapshotId,
      capturedAt,
      fixtures,
      recentForms,
      venueProfiles,
      standings,
    });
    const scenarioTechnicalSupportAnnouncements =
      scenarioTechnicalSupportAnnouncementRows({
        snapshotId,
        capturedAt,
        fixtures,
        expectedGoals,
        performanceStatistics: objectList(raw.performance_statistics),
      });
    const baseAnnouncements = [
      ...goalAnnouncements,
      ...levelFormVenueAnnouncements,
      ...attackDefenseAnnouncements,
      ...playerAnnouncements,
      ...timingAnnouncements,
      ...nuanceAnnouncements,
      ...scenarioSupportAnnouncements,
      ...scenarioTechnicalSupportAnnouncements,
    ];
    // Tirs, corners et cartons remain available in the raw snapshot for their
    // future dedicated experience. They are not Lector readings or scenarios.
    const hiddenPreMatchStatisticalReadingIds = new Set([
      "high_shot_volume",
      "high_shots_on_target",
      "high_shots_on_target_conceded",
      "high_corner_creation",
      "high_corners_conceded",
      "high_card_rate",
      "high_total_cards_profile",
    ]);
    const visibleBaseAnnouncements = baseAnnouncements.filter((announcement) =>
      !hiddenPreMatchStatisticalReadingIds.has(
        stringValue(announcement.reading_id) ?? "",
      )
    );
    const announcements = [
      ...visibleBaseAnnouncements,
      ...scenarioAnnouncementRows({
        snapshotId,
        capturedAt,
        fixtures,
        readings: visibleBaseAnnouncements,
      }),
    ];
    const inserted = await insertAnnouncements({
      supabaseUrl,
      serviceRoleKey,
      announcements,
    });

    return respond({
      ok: true,
      summary: {
        snapshotId,
        candidateFixtures: fixtures.length,
        eligibleProfiles: profiles.length,
        detectedAnnouncements: announcements.length,
        detectedScenarios: announcements.filter((announcement) =>
          announcement.announcement_kind === "scenario"
        ).length,
        insertedAnnouncements: inserted,
      },
    });
  } catch (error) {
    return respond({
      ok: false,
      error: error instanceof Error ? error.message : String(error),
    }, 500);
  }
});

function goalProfiles(
  fixtures: JsonObject[],
  capturedAt: Date,
): GoalProfile[] {
  const profiles = new Map<string, GoalProfile>();
  const seenFixtures = new Set<number>();

  for (const row of fixtures) {
    const fixture = objectValue(row.fixture) ?? {};
    const league = objectValue(row.league) ?? {};
    const teams = objectValue(row.teams) ?? {};
    const status = objectValue(fixture.status) ?? {};
    const fixtureId = numberValue(fixture.id);
    const fixtureDate = dateValue(fixture.date);
    const leagueId = numberValue(league.id);
    const home = objectValue(teams.home) ?? {};
    const away = objectValue(teams.away) ?? {};
    const homeId = numberValue(home.id);
    const awayId = numberValue(away.id);
    const goals = objectValue(row.goals) ?? {};
    const fulltime = objectValue(objectValue(row.score)?.fulltime) ?? {};
    const homeGoals = numberValue(fulltime.home) ?? numberValue(goals.home);
    const awayGoals = numberValue(fulltime.away) ?? numberValue(goals.away);

    if (
      fixtureId === null || seenFixtures.has(fixtureId) ||
      stringValue(status.short) !== "FT" || fixtureDate === null ||
      fixtureDate >= capturedAt || leagueId === null || homeId === null ||
      awayId === null || homeGoals === null || awayGoals === null
    ) {
      continue;
    }
    seenFixtures.add(fixtureId);

    const totalGoals = homeGoals + awayGoals;
    addProfile({
      profiles,
      leagueId,
      teamId: homeId,
      teamName: stringValue(home.name) ?? String(homeId),
      over25: totalGoals >= 3,
      btts: homeGoals > 0 && awayGoals > 0,
      totalGoals,
    });
    addProfile({
      profiles,
      leagueId,
      teamId: awayId,
      teamName: stringValue(away.name) ?? String(awayId),
      over25: totalGoals >= 3,
      btts: homeGoals > 0 && awayGoals > 0,
      totalGoals,
    });
  }

  return [...profiles.values()];
}

function addProfile({
  profiles,
  leagueId,
  teamId,
  teamName,
  over25,
  btts,
  totalGoals,
}: {
  profiles: Map<string, GoalProfile>;
  leagueId: number;
  teamId: number;
  teamName: string;
  over25: boolean;
  btts: boolean;
  totalGoals: number;
}): void {
  const key = `${leagueId}:${teamId}`;
  const profile = profiles.get(key) ?? {
    leagueId,
    teamId,
    teamName,
    played: 0,
    over25: 0,
    btts: 0,
    totalGoals: 0,
  };
  profile.played += 1;
  if (over25) profile.over25 += 1;
  if (btts) profile.btts += 1;
  profile.totalGoals += totalGoals;
  profiles.set(key, profile);
}

function recentFormsByTeam(rows: JsonObject[]): Map<string, RecentForm> {
  const result = new Map<string, RecentForm>();
  for (const row of rows) {
    const leagueId = numberValue((objectValue(row.league) ?? {}).id);
    const teamId = numberValue((objectValue(row.team) ?? {}).id);
    if (leagueId === null || teamId === null) continue;
    const results = objectList(row.matches)
      .map((match) => stringValue(match.result)?.toUpperCase())
      .filter((result): result is string =>
        result === "W" || result === "D" || result === "L"
      )
      .slice(0, 3);
    if (results.length === 3) result.set(`${leagueId}:${teamId}`, { results });
  }
  return result;
}

function venueProfilesByTeam(rows: JsonObject[]): Map<string, VenueProfile> {
  const result = new Map<string, VenueProfile>();
  for (const row of rows) {
    const leagueId = numberValue((objectValue(row.league) ?? {}).id);
    const teamId = numberValue((objectValue(row.team) ?? {}).id);
    const fixtures = objectValue(row.fixtures) ?? {};
    const played = objectValue(fixtures.played) ?? {};
    const wins = objectValue(fixtures.wins) ?? {};
    const losses = objectValue(fixtures.loses) ?? {};
    const homePlayed = numberValue(played.home);
    const homeWins = numberValue(wins.home);
    const homeLosses = numberValue(losses.home);
    const awayPlayed = numberValue(played.away);
    const awayWins = numberValue(wins.away);
    const awayLosses = numberValue(losses.away);
    if (
      leagueId === null || teamId === null || homePlayed === null ||
      homeWins === null || homeLosses === null || awayPlayed === null ||
      awayWins === null || awayLosses === null
    ) continue;
    result.set(`${leagueId}:${teamId}`, {
      homePlayed,
      homeWins,
      homeLosses,
      awayPlayed,
      awayWins,
      awayLosses,
    });
  }
  return result;
}

function performanceProfilesByTeam(
  rows: JsonObject[],
): Map<string, TeamPerformanceProfile> {
  const result = new Map<string, TeamPerformanceProfile>();
  for (const row of rows) {
    const leagueId = numberValue((objectValue(row.league) ?? {}).id);
    const team = objectValue(row.team) ?? {};
    const teamId = numberValue(team.id);
    const fixtures = objectValue(row.fixtures) ?? {};
    const played = objectValue(fixtures.played) ?? {};
    const goals = objectValue(row.goals) ?? {};
    const goalsFor = objectValue(goals.for) ?? {};
    const goalsAgainst = objectValue(goals.against) ?? {};
    const playedTotal = numberValue(played.total);
    const totalFor = numberValue(goalsFor.total);
    const totalAgainst = numberValue(goalsAgainst.total);
    if (
      leagueId === null || teamId === null || playedTotal === null ||
      playedTotal <= 0 || totalFor === null || totalAgainst === null
    ) continue;
    result.set(`${leagueId}:${teamId}`, {
      leagueId,
      teamId,
      teamName: stringValue(team.name) ?? String(teamId),
      played: playedTotal,
      goalsFor: totalFor,
      goalsAgainst: totalAgainst,
    });
  }
  return result;
}

function expectedGoalProfiles(rows: JsonObject[]): ExpectedGoalProfile[] {
  const profiles: ExpectedGoalProfile[] = [];
  for (const row of rows) {
    const leagueId = numberValue((objectValue(row.league) ?? {}).id);
    const teamId = numberValue((objectValue(row.team) ?? {}).id);
    const sampleSize = numberValue(row.sampleSize);
    const rolling = objectValue(row.rolling) ?? {};
    const xgFor = numberValue(rolling.xgFor5);
    const xgAgainst = numberValue(rolling.xgAgainst5);
    const goalsFor = numberValue(rolling.goalsFor5);
    if (
      leagueId === null || teamId === null || sampleSize === null ||
      sampleSize <= 0 || xgFor === null || xgAgainst === null ||
      goalsFor === null
    ) continue;
    profiles.push({
      leagueId,
      teamId,
      sampleSize,
      xgFor,
      xgAgainst,
      goalsMinusXg: goalsFor / sampleSize - xgFor,
    });
  }
  return profiles;
}

function standingsByTeam(rows: JsonObject[]): Map<string, StandingProfile> {
  const result = new Map<string, StandingProfile>();
  for (const row of rows) {
    const league = objectValue(row.league) ?? {};
    const leagueId = numberValue(league.id);
    if (leagueId === null) continue;
    const groups = Array.isArray(league.standings) ? league.standings : [];
    for (const group of groups) {
      for (const standing of objectList(group)) {
        const teamId = numberValue((objectValue(standing.team) ?? {}).id);
        const rank = numberValue(standing.rank);
        const points = numberValue(standing.points);
        const played = numberValue((objectValue(standing.all) ?? {}).played);
        if (
          teamId === null || rank === null || points === null ||
          played === null || played <= 0
        ) {
          continue;
        }
        result.set(`${leagueId}:${teamId}`, { rank, points, played });
      }
    }
  }
  return result;
}

function highZoneTeamIds(
  profiles: GoalProfile[],
): Map<string, Set<number>> {
  const result = new Map<string, Set<number>>();
  const byLeague = new Map<number, GoalProfile[]>();
  for (const profile of profiles) {
    const leagueProfiles = byLeague.get(profile.leagueId) ?? [];
    leagueProfiles.push(profile);
    byLeague.set(profile.leagueId, leagueProfiles);
  }

  for (const [leagueId, leagueProfiles] of byLeague) {
    for (const definition of readingDefinitions) {
      const zone = isolatedEdgeZones(
        leagueProfiles.map((profile) => ({
          teamId: profile.teamId,
          value: definition.valueFor(profile),
        })),
      ).high;
      result.set(`${leagueId}:${definition.id}`, zone);
    }
  }
  return result;
}

function edgeZonesByLeague<T extends { leagueId: number; teamId: number }>(
  profiles: T[],
  valueFor: (profile: T) => number,
): Map<number, EdgeZones> {
  const byLeague = new Map<number, T[]>();
  for (const profile of profiles) {
    const leagueProfiles = byLeague.get(profile.leagueId) ?? [];
    leagueProfiles.push(profile);
    byLeague.set(profile.leagueId, leagueProfiles);
  }
  return new Map(
    [...byLeague].map(([leagueId, leagueProfiles]) => [
      leagueId,
      isolatedEdgeZones(leagueProfiles.map((profile) => ({
        teamId: profile.teamId,
        value: valueFor(profile),
      }))),
    ]),
  );
}

function performanceEdgeZones(
  profiles: Map<string, TeamPerformanceProfile>,
): Map<string, EdgeZones> {
  const values = [...profiles.values()];
  const goalsFor = edgeZonesByLeague(
    values,
    (profile) => profile.goalsFor / profile.played,
  );
  const goalsAgainst = edgeZonesByLeague(
    values,
    (profile) => profile.goalsAgainst / profile.played,
  );
  const result = new Map<string, EdgeZones>();
  for (const [leagueId, zones] of goalsFor) {
    result.set(`${leagueId}:goals_for`, zones);
  }
  for (const [leagueId, zones] of goalsAgainst) {
    result.set(`${leagueId}:goals_against`, zones);
  }
  return result;
}

function isolatedEdgeZones(
  source: { teamId: number; value: number }[],
): EdgeZones {
  if (source.length < minimumDistributionTeamCount) {
    return { high: new Set(), low: new Set() };
  }
  const values = [...source].sort((left, right) => right.value - left.value);
  const gaps = values.slice(0, -1).map((value, index) =>
    value.value - values[index + 1].value
  );
  const positiveGaps = gaps.filter((gap) => gap > 0).sort((a, b) => a - b);
  const q1 = lowerQuartile(positiveGaps);
  const q3 = upperQuartile(positiveGaps);
  const upperFence = q3 + 1.5 * (q3 - q1);
  const highCandidates: { gap: number; teamIds: number[] }[] = [];
  const lowCandidates: { gap: number; teamIds: number[] }[] = [];

  for (let index = 0; index < gaps.length; index += 1) {
    const gap = gaps[index];
    if (gap <= upperFence) continue;
    const highValues = values.slice(0, index + 1);
    const lowValues = values.slice(index + 1);
    const highSpan = span(highValues);
    const lowSpan = span(lowValues);
    if (highSpan < gap && highSpan < lowSpan) {
      highCandidates.push({
        gap,
        teamIds: highValues.map((value) => value.teamId),
      });
    } else if (lowSpan < gap && lowSpan < highSpan) {
      lowCandidates.push({
        gap,
        teamIds: lowValues.map((value) => value.teamId),
      });
    }
  }

  return {
    high: strongestUniqueZone(highCandidates),
    low: strongestUniqueZone(lowCandidates),
  };
}

function strongestUniqueZone(
  candidates: { gap: number; teamIds: number[] }[],
): Set<number> {
  if (candidates.length === 0) return new Set();
  const strongestGap = Math.max(
    ...candidates.map((candidate) => candidate.gap),
  );
  const strongest = candidates.filter((candidate) =>
    candidate.gap === strongestGap
  );
  return strongest.length === 1 ? new Set(strongest[0].teamIds) : new Set();
}

function announcementRows({
  snapshotId,
  capturedAt,
  fixtures,
  profiles,
  highZones,
}: {
  snapshotId: string;
  capturedAt: Date;
  fixtures: JsonObject[];
  profiles: GoalProfile[];
  highZones: Map<string, Set<number>>;
}): JsonObject[] {
  const profilesByTeam = new Map(
    profiles.map((
      profile,
    ) => [`${profile.leagueId}:${profile.teamId}`, profile]),
  );
  const rows: JsonObject[] = [];
  const seenFixtures = new Set<number>();

  for (const row of fixtures) {
    const fixture = objectValue(row.fixture) ?? {};
    const league = objectValue(row.league) ?? {};
    const teams = objectValue(row.teams) ?? {};
    const fixtureId = numberValue(fixture.id);
    const kickoffAt = dateValue(fixture.date);
    const leagueId = numberValue(league.id);
    if (
      fixtureId === null || seenFixtures.has(fixtureId) || kickoffAt === null ||
      kickoffAt <= capturedAt || leagueId === null
    ) {
      continue;
    }
    seenFixtures.add(fixtureId);

    for (
      const subject of [
        { side: "home", team: objectValue(teams.home) ?? {} },
        { side: "away", team: objectValue(teams.away) ?? {} },
      ]
    ) {
      const teamId = numberValue(subject.team.id);
      if (teamId === null) continue;
      const profile = profilesByTeam.get(`${leagueId}:${teamId}`);
      if (profile === undefined || profile.played <= 0) continue;

      for (const definition of readingDefinitions) {
        const zone = highZones.get(`${leagueId}:${definition.id}`) ?? new Set();
        if (!zone.has(teamId)) continue;
        const value = definition.valueFor(profile);
        const subjectTeamId = `api-team-${teamId}`;
        rows.push({
          announcement_key:
            `${fixtureId}:${definition.id}:${subject.side}:${subjectTeamId}:0`,
          fixture_id: fixtureId,
          source_snapshot_id: snapshotId,
          league_id: leagueId,
          kickoff_at: kickoffAt.toISOString(),
          announced_at: capturedAt.toISOString(),
          engine_version: "server_goal_profile_v1",
          reading_id: definition.id,
          reading_label: definition.label,
          subject_side: subject.side,
          subject_team_id: subjectTeamId,
          player_id: null,
          evidence: [{
            label: `${
              stringValue(subject.team.name) ?? profile.teamName
            } ${definition.evidenceVerb} dans ${
              Math.round(value * 100)
            }% de ses matchs, dans une zone haute du championnat.`,
            source_path: "league_fixtures.score.fulltime",
            value,
          }],
          sample_size: profile.played,
          outcome_rule: definition.outcomeRule,
          rule_version: 1,
        });
      }
    }
  }
  return rows;
}

/// Core attack, defence and match-goal-profile readings. These are materialised
/// independently before the scenario contract is checked, so the compact app
/// feed and the Bilan can both expose the exact evidence used by a scenario.
function attackDefenseAnnouncementRows({
  snapshotId,
  capturedAt,
  fixtures,
  profiles,
  totalGoalZones,
  performanceProfiles,
  performanceZones,
}: {
  snapshotId: string;
  capturedAt: Date;
  fixtures: JsonObject[];
  profiles: GoalProfile[];
  totalGoalZones: Map<number, EdgeZones>;
  performanceProfiles: Map<string, TeamPerformanceProfile>;
  performanceZones: Map<string, EdgeZones>;
}): JsonObject[] {
  const goals = new Map(
    profiles.map((value) => [`${value.leagueId}:${value.teamId}`, value]),
  );
  const rows: JsonObject[] = [];
  const seen = new Set<number>();
  for (const row of fixtures) {
    const fixture = objectValue(row.fixture) ?? {};
    const league = objectValue(row.league) ?? {};
    const teams = objectValue(row.teams) ?? {};
    const fixtureId = numberValue(fixture.id);
    const kickoffAt = dateValue(fixture.date);
    const leagueId = numberValue(league.id);
    if (
      fixtureId === null || kickoffAt === null || kickoffAt <= capturedAt ||
      leagueId === null || seen.has(fixtureId)
    ) continue;
    seen.add(fixtureId);
    const home = objectValue(teams.home) ?? {};
    const away = objectValue(teams.away) ?? {};
    const homeId = numberValue(home.id);
    const awayId = numberValue(away.id);
    if (homeId === null || awayId === null) continue;
    const attackZones = performanceZones.get(`${leagueId}:goals_for`);
    const defenseZones = performanceZones.get(`${leagueId}:goals_against`);
    for (
      const subject of [
        { side: "home", team: home, teamId: homeId },
        { side: "away", team: away, teamId: awayId },
      ]
    ) {
      const performance = performanceProfiles.get(
        `${leagueId}:${subject.teamId}`,
      );
      if (performance === undefined) continue;
      const subjectTeamId = `api-team-${subject.teamId}`;
      const name = teamName(subject.team);
      const create = (
        id: string,
        label: string,
        outcomeRule: string,
        evidence: string,
      ) =>
        rows.push({
          announcement_key:
            `${fixtureId}:${id}:${subject.side}:${subjectTeamId}:1`,
          fixture_id: fixtureId,
          source_snapshot_id: snapshotId,
          league_id: leagueId,
          kickoff_at: kickoffAt.toISOString(),
          announced_at: capturedAt.toISOString(),
          engine_version: "server_attack_defense_v1",
          reading_id: id,
          reading_label: label,
          subject_side: subject.side,
          subject_team_id: subjectTeamId,
          player_id: null,
          evidence: [{
            label: evidence,
            source_path: "teams/statistics.goals",
            value: {
              goals_for: performance.goalsFor / performance.played,
              goals_against: performance.goalsAgainst / performance.played,
            },
          }],
          sample_size: performance.played,
          outcome_rule: outcomeRule,
          rule_version: 1,
        });
      if (attackZones?.high.has(subject.teamId)) {
        create(
          "prolific_attack",
          "Attaque prolifique",
          "team_scores",
          `${name} marque ${
            goalRate(performance.goalsFor, performance.played)
          } but par match, dans une zone haute du championnat.`,
        );
      }
      if (attackZones?.low.has(subject.teamId)) {
        create(
          "scoring_difficulty",
          "Production offensive faible",
          "team_no_score",
          `${name} marque ${
            goalRate(performance.goalsFor, performance.played)
          } but par match, dans une zone basse du championnat.`,
        );
      }
      if (defenseZones?.low.has(subject.teamId)) {
        create(
          "solid_defense",
          "Défense solide",
          "team_clean_sheet",
          `${name} encaisse ${
            goalRate(performance.goalsAgainst, performance.played)
          } but par match, dans une zone basse du championnat.`,
        );
      }
      if (defenseZones?.high.has(subject.teamId)) {
        create(
          "fragile_defense",
          "Défense fragile",
          "team_concedes",
          `${name} encaisse ${
            goalRate(performance.goalsAgainst, performance.played)
          } but par match, dans une zone haute du championnat.`,
        );
      }
    }
    const homeGoal = goals.get(`${leagueId}:${homeId}`);
    const awayGoal = goals.get(`${leagueId}:${awayId}`);
    const totalZones = totalGoalZones.get(leagueId);
    if (
      homeGoal === undefined || awayGoal === undefined ||
      totalZones === undefined
    ) continue;
    const addProfile = (
      id: string,
      label: string,
      rule: string,
      evidence: string,
    ) =>
      rows.push({
        announcement_key: `${fixtureId}:${id}:match:fixture:1`,
        fixture_id: fixtureId,
        source_snapshot_id: snapshotId,
        league_id: leagueId,
        kickoff_at: kickoffAt.toISOString(),
        announced_at: capturedAt.toISOString(),
        engine_version: "server_attack_defense_v1",
        reading_id: id,
        reading_label: label,
        subject_side: "match",
        subject_team_id: `api-fixture-${fixtureId}`,
        player_id: null,
        evidence: [{
          label: evidence,
          source_path: "league_fixtures.score.fulltime",
          value: {
            home: homeGoal.totalGoals / homeGoal.played,
            away: awayGoal.totalGoals / awayGoal.played,
          },
        }],
        sample_size: Math.min(homeGoal.played, awayGoal.played),
        outcome_rule: rule,
        rule_version: 1,
      });
    if (totalZones.high.has(homeId) && totalZones.high.has(awayId)) {
      addProfile(
        "open_match_profile",
        "Profil de match ouvert",
        "over_25",
        `Les matchs de ${teamName(home)} et ${
          teamName(away)
        } présentent un total de buts élevé dans le championnat.`,
      );
    }
    if (totalZones.low.has(homeId) && totalZones.low.has(awayId)) {
      addProfile(
        "closed_match_profile",
        "Profil de match fermé",
        "under_25",
        `Les matchs de ${teamName(home)} et ${
          teamName(away)
        } présentent un total de buts faible dans le championnat.`,
      );
    }
  }
  return rows;
}

function goalRate(goals: number, played: number): string {
  return played > 0 ? (goals / played).toFixed(2) : "0.00";
}

function timingAnnouncementRows(
  { snapshotId, capturedAt, fixtures, teamStatistics }: {
    snapshotId: string;
    capturedAt: Date;
    fixtures: JsonObject[];
    teamStatistics: JsonObject[];
  },
): JsonObject[] {
  type Rates = {
    leagueId: number;
    teamId: number;
    played: number;
    firstFor: number;
    firstAgainst: number;
    secondFor: number;
    secondAgainst: number;
  };
  const profiles: Rates[] = [];
  const count = (value: JsonObject, buckets: string[]) =>
    buckets.reduce((sum, bucket) => sum + (numberValue(value[bucket]) ?? 0), 0);
  for (const row of teamStatistics) {
    const leagueId = numberValue((objectValue(row.league) ?? {}).id);
    const teamId = numberValue((objectValue(row.team) ?? {}).id);
    const played = numberValue(
      (objectValue(objectValue(row.fixtures)?.played) ?? {}).total,
    );
    const goals = objectValue(row.goals) ?? {};
    const forMinute = objectValue(objectValue(goals.for)?.minute) ?? {};
    const againstMinute = objectValue(objectValue(goals.against)?.minute) ?? {};
    if (
      leagueId === null || teamId === null || played === null || played <= 0
    ) continue;
    profiles.push({
      leagueId,
      teamId,
      played,
      firstFor: count(forMinute, ["0-15", "16-30", "31-45"]),
      firstAgainst: count(againstMinute, ["0-15", "16-30", "31-45"]),
      secondFor: count(forMinute, ["46-60", "61-75", "76-90"]),
      secondAgainst: count(againstMinute, ["46-60", "61-75", "76-90"]),
    });
  }
  const byKey = new Map(
    profiles.map((value) => [`${value.leagueId}:${value.teamId}`, value]),
  );
  const average = (
    leagueId: number,
    metric: keyof Omit<Rates, "leagueId" | "teamId" | "played">,
  ) => {
    const values = profiles.filter((value) => value.leagueId === leagueId).map((
      value,
    ) => value[metric] / value.played);
    return values.length === 0
      ? null
      : values.reduce((sum, value) => sum + value, 0) / values.length;
  };
  const rows: JsonObject[] = [];
  for (const row of fixtures) {
    const fixture = objectValue(row.fixture) ?? {};
    const league = objectValue(row.league) ?? {};
    const teams = objectValue(row.teams) ?? {};
    const fixtureId = numberValue(fixture.id);
    const leagueId = numberValue(league.id);
    const kickoffAt = dateValue(fixture.date);
    if (
      fixtureId === null || leagueId === null || kickoffAt === null ||
      kickoffAt <= capturedAt
    ) continue;
    for (
      const subject of [{ side: "home", team: objectValue(teams.home) ?? {} }, {
        side: "away",
        team: objectValue(teams.away) ?? {},
      }]
    ) {
      const teamId = numberValue(subject.team.id);
      const profile = teamId === null
        ? undefined
        : byKey.get(`${leagueId}:${teamId}`);
      if (profile === undefined) continue;
      const add = (
        metric: keyof Omit<Rates, "leagueId" | "teamId" | "played">,
        id: string,
        label: string,
        rule: string,
      ) => {
        const rate = profile[metric] / profile.played;
        const leagueAverage = average(leagueId, metric);
        if (leagueAverage === null || rate <= leagueAverage) return;
        rows.push({
          announcement_key:
            `${fixtureId}:${id}:${subject.side}:api-team-${teamId}:1`,
          fixture_id: fixtureId,
          source_snapshot_id: snapshotId,
          league_id: leagueId,
          kickoff_at: kickoffAt.toISOString(),
          announced_at: capturedAt.toISOString(),
          engine_version: "server_period_profile_v1",
          reading_id: id,
          reading_label: label,
          subject_side: subject.side,
          subject_team_id: `api-team-${teamId}`,
          player_id: null,
          evidence: [{
            label: `${teamName(subject.team)} présente ${
              rate.toFixed(2)
            } but par match sur cette période, au-dessus de la moyenne de son championnat.`,
            source_path: "teams/statistics.goals.minute",
            value: rate,
          }],
          sample_size: profile.played,
          outcome_rule: rule,
          rule_version: 1,
        });
      };
      add(
        "firstFor",
        "frequent_first_half_scoring",
        "Marque souvent en première mi-temps",
        "first_half_scores",
      );
      add(
        "firstAgainst",
        "frequent_first_half_conceding",
        "Encaisse souvent en première mi-temps",
        "first_half_concedes",
      );
      add(
        "secondFor",
        "frequent_second_half_scoring",
        "Marque souvent en seconde mi-temps",
        "second_half_scores",
      );
      add(
        "secondAgainst",
        "frequent_second_half_conceding",
        "Encaisse souvent en seconde mi-temps",
        "second_half_concedes",
      );
    }
  }
  return rows;
}

function playerAnnouncementRows({
  snapshotId,
  capturedAt,
  fixtures,
  playerRecentPerformances,
  injuries,
}: {
  snapshotId: string;
  capturedAt: Date;
  fixtures: JsonObject[];
  playerRecentPerformances: JsonObject[];
  injuries: JsonObject[];
}): JsonObject[] {
  type RecentPlayerProfile = {
    playerId: number;
    name: string;
    photoUrl: string | null;
    appearances: number;
    substituteAppearances: number;
    minutes: number;
    goals: number;
    assists: number;
    contributions: number;
    matchesWithContribution: number;
    recentRate: number;
  };

  // The decisive-player model deliberately uses neither a season total nor a
  // hard minutes floor. It measures the player over their team's three latest
  // completed fixtures, using actual minutes. A recurring super-sub can then
  // qualify on merit, while a one-off cameo cannot.
  const profilesByTeam = new Map<string, RecentPlayerProfile[]>();
  for (const row of playerRecentPerformances) {
    const leagueId = numberValue((objectValue(row.league) ?? {}).id);
    const teamId = numberValue((objectValue(row.team) ?? {}).id);
    const matchesConsidered = numberValue(row.matches_considered) ?? 0;
    const fixturesWithPlayerStatistics =
      numberValue(row.fixtures_with_player_statistics) ?? 0;
    if (
      leagueId === null || teamId === null ||
      matchesConsidered < 3 ||
      fixturesWithPlayerStatistics < matchesConsidered
    ) continue;

    const values: RecentPlayerProfile[] = [];
    for (const playerValue of objectList(row.players)) {
      const player = objectValue(playerValue.player) ?? {};
      const playerId = numberValue(player.id);
      const name = stringValue(player.name);
      const appearances = numberValue(playerValue.appearances) ?? 0;
      const substituteAppearances =
        numberValue(playerValue.substitute_appearances) ?? 0;
      const minutes = numberValue(playerValue.minutes) ?? 0;
      const goals = numberValue(playerValue.goals) ?? 0;
      const assists = numberValue(playerValue.assists) ?? 0;
      const contributions = numberValue(playerValue.contributions) ??
        goals + assists;
      const matchesWithContribution =
        numberValue(playerValue.matches_with_contribution) ?? 0;
      if (
        playerId === null || name === null || minutes <= 0 ||
        appearances < 2 || matchesWithContribution < 2 ||
        contributions <= 0
      ) continue;
      const recentRate = contributions * 90 / minutes;
      // 0.80 is the explicit product threshold for a player described as
      // "décisif à surveiller". It is applied to the recent window only.
      if (recentRate < 0.8) continue;
      values.push({
        playerId,
        name,
        photoUrl: stringValue(player.photo),
        appearances,
        substituteAppearances,
        minutes,
        goals,
        assists,
        contributions,
        matchesWithContribution,
        recentRate,
      });
    }
    if (values.length === 0) continue;
    values.sort((left, right) =>
      right.recentRate - left.recentRate ||
      right.matchesWithContribution - left.matchesWithContribution ||
      right.contributions - left.contributions ||
      right.minutes - left.minutes
    );
    profilesByTeam.set([leagueId, teamId].join(":"), values);
  }

  const injuryKeys = new Set<string>();
  for (const injury of injuries) {
    const fixtureId = numberValue((objectValue(injury.fixture) ?? {}).id);
    const teamId = numberValue((objectValue(injury.team) ?? {}).id);
    const playerId = numberValue((objectValue(injury.player) ?? {}).id);
    if (fixtureId !== null && teamId !== null && playerId !== null) {
      injuryKeys.add([fixtureId, teamId, playerId].join(":"));
    }
  }

  const rows: JsonObject[] = [];
  for (const row of fixtures) {
    const fixture = objectValue(row.fixture) ?? {};
    const league = objectValue(row.league) ?? {};
    const teams = objectValue(row.teams) ?? {};
    const fixtureId = numberValue(fixture.id);
    const leagueId = numberValue(league.id);
    const kickoffAt = dateValue(fixture.date);
    if (
      fixtureId === null || leagueId === null || kickoffAt === null ||
      kickoffAt <= capturedAt
    ) continue;
    const withinAbsenceWindow = kickoffAt.getTime() - capturedAt.getTime() <=
      24 * 60 * 60 * 1000;

    for (
      const subject of [{ side: "home", team: objectValue(teams.home) ?? {} }, {
        side: "away",
        team: objectValue(teams.away) ?? {},
      }]
    ) {
      const teamId = numberValue(subject.team.id);
      if (teamId === null) continue;
      const profiles = profilesByTeam.get([leagueId, teamId].join(":")) ?? [];
      const subjectTeamId = "api-team-" + teamId;
      for (const [profileIndex, profile] of profiles.entries()) {
        const unavailable = withinAbsenceWindow && injuryKeys.has(
          [fixtureId, teamId, profile.playerId].join(":"),
        );
        const baseProfile = profile.goals >= profile.assists * 1.5
          ? "buteur"
          : profile.assists >= profile.goals * 1.5
          ? "passeur"
          : "décisif";
        const isSuperSub = profile.substituteAppearances * 2 >
          profile.appearances;
        const profileLabel = isSuperSub
          ? baseProfile + " · super-sub"
          : baseProfile;
        const sharedValue = {
          player_name: profile.name,
          player_photo_url: profile.photoUrl,
          profile: baseProfile,
          profile_label: profileLabel,
          is_super_sub: isSuperSub,
          recent: {
            player_rank: profileIndex + 1,
            matches_considered: 3,
            appearances: profile.appearances,
            substitute_appearances: profile.substituteAppearances,
            matches_with_contribution: profile.matchesWithContribution,
            goals: profile.goals,
            assists: profile.assists,
            contributions: profile.contributions,
            minutes: profile.minutes,
            contributions_per_90: Number(profile.recentRate.toFixed(2)),
          },
        };
        if (unavailable) {
          rows.push({
            announcement_key: [
              fixtureId,
              "key_player_unavailable",
              subject.side,
              subjectTeamId,
              profile.playerId,
            ].join(":"),
            fixture_id: fixtureId,
            source_snapshot_id: snapshotId,
            league_id: leagueId,
            kickoff_at: kickoffAt.toISOString(),
            announced_at: capturedAt.toISOString(),
            engine_version: "server_recent_player_profile_v3",
            reading_id: "key_player_unavailable",
            reading_label: "Joueur important absent",
            subject_side: subject.side,
            subject_team_id: subjectTeamId,
            player_id: profile.playerId,
            player_name: profile.name,
            evidence: [{
              label: profile.name +
                " est signalé absent dans les 24 heures précédant le match.",
              source_path: "injuries + fixtures/players",
              value: sharedValue,
            }],
            sample_size: 3,
            outcome_rule: null,
            rule_version: 3,
          });
          continue;
        }
        const recurrence = profile.matchesWithContribution +
          "/3 derniers matchs";
        const entrance = isSuperSub
          ? profile.substituteAppearances + " entrée(s) en jeu"
          : profile.appearances + " apparition(s)";
        rows.push({
          announcement_key: [
            fixtureId,
            "standout_decisive_player",
            subject.side,
            subjectTeamId,
            profile.playerId,
          ].join(":"),
          fixture_id: fixtureId,
          source_snapshot_id: snapshotId,
          league_id: leagueId,
          kickoff_at: kickoffAt.toISOString(),
          announced_at: capturedAt.toISOString(),
          engine_version: "server_recent_player_profile_v3",
          reading_id: "standout_decisive_player",
          reading_label: "Joueur décisif à surveiller",
          subject_side: subject.side,
          subject_team_id: subjectTeamId,
          player_id: profile.playerId,
          player_name: profile.name,
          evidence: [{
            label: profile.name + ", profil " + profileLabel + ", affiche " +
              profile.recentRate.toFixed(2) +
              " action(s) décisive(s) / 90 sur ses " +
              "trois derniers matchs (" + profile.contributions +
              " action(s) en " +
              profile.minutes + " min, " + recurrence + ", " + entrance + ").",
            source_path: "fixtures/players (three completed fixtures)",
            value: sharedValue,
          }],
          sample_size: 3,
          outcome_rule: "player_decisive",
          rule_version: 3,
        });
      }
    }
  }
  return rows;
}

function nuanceAnnouncementRows({
  snapshotId,
  capturedAt,
  fixtures,
  recentForms,
  expectedGoals,
}: {
  snapshotId: string;
  capturedAt: Date;
  fixtures: JsonObject[];
  recentForms: Map<string, RecentForm>;
  expectedGoals: ExpectedGoalProfile[];
}): JsonObject[] {
  const zones = edgeZonesByLeague(expectedGoals, (value) => value.goalsMinusXg);
  const rows: JsonObject[] = [];
  for (const row of fixtures) {
    const fixture = objectValue(row.fixture) ?? {};
    const league = objectValue(row.league) ?? {};
    const teams = objectValue(row.teams) ?? {};
    const fixtureId = numberValue(fixture.id);
    const leagueId = numberValue(league.id);
    const kickoffAt = dateValue(fixture.date);
    if (
      fixtureId === null || leagueId === null || kickoffAt === null ||
      kickoffAt <= capturedAt
    ) continue;
    for (
      const subject of [
        { side: "home", team: objectValue(teams.home) ?? {} },
        { side: "away", team: objectValue(teams.away) ?? {} },
      ]
    ) {
      const teamId = numberValue(subject.team.id);
      if (teamId === null) continue;
      const form = recentForms.get(`${leagueId}:${teamId}`);
      const points = form?.results.map(pointsForResult) ?? [];
      const positive = points.length === 3 && !points.includes(0) &&
        points.reduce((sum, value) => sum + value, 0) >= 5;
      const zone = zones.get(leagueId)?.high;
      const profile = expectedGoals.find((value) =>
        value.leagueId === leagueId && value.teamId === teamId
      );
      if (!positive || !zone?.has(teamId) || profile === undefined) continue;
      const subjectTeamId = `api-team-${teamId}`;
      rows.push({
        announcement_key:
          `${fixtureId}:misleading_result:${subject.side}:${subjectTeamId}:1`,
        fixture_id: fixtureId,
        source_snapshot_id: snapshotId,
        league_id: leagueId,
        kickoff_at: kickoffAt.toISOString(),
        announced_at: capturedAt.toISOString(),
        engine_version: "server_xg_nuance_v1",
        announcement_kind: "nuance",
        reading_id: "misleading_result",
        reading_label: "Résultat à nuancer",
        subject_side: subject.side,
        subject_team_id: subjectTeamId,
        player_id: null,
        parent_announcement_key:
          `${fixtureId}:positive_streak:${subject.side}:${subjectTeamId}:1`,
        required_reading_ids: ["positive_streak", "offensive_overperformance"],
        evidence: [{
          label: `${
            teamName(subject.team)
          } reste invaincu, mais ses buts dépassent ses xG récents de ${
            profile.goalsMinusXg.toFixed(2)
          } par match.`,
          source_path: "expected_goals.rolling",
          value: profile.goalsMinusXg,
        }],
        sample_size: profile.sampleSize,
        outcome_rule: null,
        rule_version: 1,
      });
    }
  }
  return rows;
}

function technicalProjectionAnnouncementRows({
  snapshotId,
  capturedAt,
  fixtures,
  performanceStatistics,
}: {
  snapshotId: string;
  capturedAt: Date;
  fixtures: JsonObject[];
  performanceStatistics: JsonObject[];
}): JsonObject[] {
  const valuesByTeam = new Map<string, JsonObject>();
  for (const row of performanceStatistics) {
    const leagueId = numberValue((objectValue(row.league) ?? {}).id);
    const teamId = numberValue((objectValue(row.team) ?? {}).id);
    if (leagueId !== null && teamId !== null) {
      valuesByTeam.set(`${leagueId}:${teamId}`, row);
    }
  }
  const rows: JsonObject[] = [];
  for (const row of fixtures) {
    const fixture = objectValue(row.fixture) ?? {};
    const league = objectValue(row.league) ?? {};
    const teams = objectValue(row.teams) ?? {};
    const fixtureId = numberValue(fixture.id);
    const leagueId = numberValue(league.id);
    const kickoffAt = dateValue(fixture.date);
    const home = objectValue(teams.home) ?? {};
    const away = objectValue(teams.away) ?? {};
    const homeId = numberValue(home.id);
    const awayId = numberValue(away.id);
    if (
      fixtureId === null || leagueId === null || kickoffAt === null ||
      kickoffAt <= capturedAt || homeId === null || awayId === null
    ) continue;
    const homeStats = valuesByTeam.get(`${leagueId}:${homeId}`);
    const awayStats = valuesByTeam.get(`${leagueId}:${awayId}`);
    if (homeStats === undefined || awayStats === undefined) continue;
    const homeValues = objectValue(homeStats.averages) ?? {};
    const awayValues = objectValue(awayStats.averages) ?? {};
    const homeSample = numberValue(homeStats.sampleSize) ?? 0;
    const awaySample = numberValue(awayStats.sampleSize) ?? 0;
    const add = (
      id: string,
      label: string,
      ownKey: string,
      concededKey: string,
      sourcePath: string,
    ) => {
      const homeOwn = numberValue(homeValues[ownKey]);
      const homeConceded = numberValue(homeValues[concededKey]);
      const awayOwn = numberValue(awayValues[ownKey]);
      const awayConceded = numberValue(awayValues[concededKey]);
      if (
        homeOwn === null || homeConceded === null || awayOwn === null ||
        awayConceded === null
      ) return;
      const homeProjection = (homeOwn + awayConceded) / 2;
      const awayProjection = (awayOwn + homeConceded) / 2;
      rows.push({
        announcement_key: `${fixtureId}:${id}:match:fixture:1`,
        fixture_id: fixtureId,
        source_snapshot_id: snapshotId,
        league_id: leagueId,
        kickoff_at: kickoffAt.toISOString(),
        announced_at: capturedAt.toISOString(),
        engine_version: "server_technical_projection_v1",
        reading_id: id,
        reading_label: label,
        subject_side: "match",
        subject_team_id: `api-fixture-${fixtureId}`,
        player_id: null,
        evidence: [{
          label: `${label} : ${teamName(home)} ${homeProjection.toFixed(1)}, ${
            teamName(away)
          } ${awayProjection.toFixed(1)}, soit ${
            (homeProjection + awayProjection).toFixed(1)
          } au total.`,
          source_path: sourcePath,
          value: {
            home: homeProjection,
            away: awayProjection,
            total: homeProjection + awayProjection,
          },
        }],
        sample_size: Math.min(homeSample, awaySample),
        outcome_rule: null,
        rule_version: 1,
      });
    };
    add(
      "match_shot_profile",
      "Projection de tirs",
      "shotsFor",
      "shotsAgainst",
      "fixtures/statistics.Total Shots",
    );
    add(
      "match_corner_profile",
      "Projection de corners",
      "cornersFor",
      "cornersAgainst",
      "fixtures/statistics.Corner Kicks",
    );
    add(
      "match_card_profile",
      "Projection de cartons",
      "cardsFor",
      "cardsAgainst",
      "fixtures/statistics.Cards",
    );
  }
  return rows;
}

type ScenarioSubject =
  | "subject"
  | "opponent"
  | "home"
  | "away"
  | "match"
  | "both_teams"
  | "at_least_one_team";

type ScenarioContract = {
  id: string;
  label: string;
  scope: "team" | "match";
  outcomeRule: string | null;
  requirements: { readingId: string; subject: ScenarioSubject }[];
};

// This is the server-side counterpart of FootballScenarioCatalog. A scenario
// is persisted only when every requirement exists before kickoff.
const scenarioContracts: ScenarioContract[] = [
  {
    id: "solid_favorite",
    label: "Domination attendue",
    scope: "team",
    outcomeRule: "team_win",
    requirements: [{ readingId: "ranking_superiority", subject: "subject" }, {
      readingId: "form_advantage",
      subject: "subject",
    }, { readingId: "structural_level_gap", subject: "subject" }],
  },
  {
    id: "struggling_team",
    label: "Équipe en difficulté",
    scope: "team",
    outcomeRule: "team_loss",
    requirements: [{ readingId: "negative_streak", subject: "subject" }, {
      readingId: "scoring_difficulty",
      subject: "subject",
    }],
  },
  {
    id: "offensive_match",
    label: "Match ouvert",
    scope: "match",
    outcomeRule: "over_25",
    requirements: [
      { readingId: "open_match_profile", subject: "match" },
      { readingId: "frequent_over_25", subject: "at_least_one_team" },
    ],
  },
  {
    id: "defensive_match",
    label: "Match fermé",
    scope: "match",
    outcomeRule: "under_25",
    requirements: [{ readingId: "closed_match_profile", subject: "match" }, {
      readingId: "frequent_under_25",
      subject: "at_least_one_team",
    }],
  },
  {
    id: "ranking_gap",
    label: "Écart de niveau",
    scope: "team",
    outcomeRule: "team_win",
    requirements: [{ readingId: "ranking_superiority", subject: "subject" }, {
      readingId: "structural_level_gap",
      subject: "subject",
    }],
  },
  {
    id: "credible_outsider",
    label: "Outsider crédible",
    scope: "team",
    outcomeRule: "team_not_lose",
    requirements: [
      { readingId: "ranking_inferiority", subject: "subject" },
      { readingId: "positive_streak", subject: "subject" },
      { readingId: "form_advantage", subject: "subject" },
    ],
  },
  {
    id: "fragile_defense",
    label: "Défense fragile",
    scope: "team",
    outcomeRule: "team_concedes",
    requirements: [{ readingId: "fragile_defense", subject: "subject" }, {
      readingId: "high_xg_conceded",
      subject: "subject",
    }],
  },
  {
    id: "prolific_attack",
    label: "Attaque prolifique",
    scope: "team",
    outcomeRule: "team_scores",
    requirements: [{ readingId: "prolific_attack", subject: "subject" }, {
      readingId: "high_xg_creation",
      subject: "subject",
    }],
  },
  {
    id: "positive_series",
    label: "Série positive",
    scope: "team",
    outcomeRule: "team_not_lose",
    requirements: [{ readingId: "positive_streak", subject: "subject" }, {
      readingId: "improving_form",
      subject: "subject",
    }],
  },
  {
    id: "negative_series",
    label: "Série négative",
    scope: "team",
    outcomeRule: "team_loss",
    requirements: [{ readingId: "negative_streak", subject: "subject" }, {
      readingId: "declining_form",
      subject: "subject",
    }],
  },
];

function scenarioAnnouncementRows(
  { snapshotId, capturedAt, fixtures, readings }: {
    snapshotId: string;
    capturedAt: Date;
    fixtures: JsonObject[];
    readings: JsonObject[];
  },
): JsonObject[] {
  const rows: JsonObject[] = [];
  for (const row of fixtures) {
    const fixture = objectValue(row.fixture) ?? {};
    const league = objectValue(row.league) ?? {};
    const teams = objectValue(row.teams) ?? {};
    const fixtureId = numberValue(fixture.id);
    const leagueId = numberValue(league.id);
    const kickoffAt = dateValue(fixture.date);
    if (
      fixtureId === null || leagueId === null || kickoffAt === null ||
      kickoffAt <= capturedAt
    ) continue;
    const fixtureReadings = readings.filter((value) =>
      numberValue(value.fixture_id) === fixtureId &&
      stringValue(value.announcement_kind) !== "nuance"
    );
    const has = (id: string, side: string) =>
      fixtureReadings.some((value) =>
        stringValue(value.reading_id) === id &&
        stringValue(value.subject_side) === side
      );
    const resolve = (
      contract: ScenarioContract,
      side: "home" | "away" | "match",
    ) =>
      contract.requirements.every((requirement) => {
        const target = requirement.subject;
        if (target === "match") return has(requirement.readingId, "match");
        if (target === "home") return has(requirement.readingId, "home");
        if (target === "away") return has(requirement.readingId, "away");
        if (target === "both_teams") {
          return has(requirement.readingId, "home") &&
            has(requirement.readingId, "away");
        }
        if (target === "at_least_one_team") {
          return has(requirement.readingId, "home") ||
            has(requirement.readingId, "away");
        }
        if (target === "opponent") {
          return has(requirement.readingId, side === "home" ? "away" : "home");
        }
        return has(requirement.readingId, side);
      });
    for (const contract of scenarioContracts) {
      const sides: ("home" | "away" | "match")[] = contract.scope === "match"
        ? ["match"]
        : ["home", "away"];
      for (const side of sides) {
        if (!resolve(contract, side)) continue;
        const earlyHierarchy = contract.id === "ranking_gap" &&
          fixtureReadings.some((value) =>
            stringValue(value.reading_id) === "structural_level_gap" &&
            stringValue(value.reading_label) === "Écart de hiérarchie précoce"
          );
        const team = side === "home"
          ? objectValue(teams.home) ?? {}
          : objectValue(teams.away) ?? {};
        const teamId = side === "match"
          ? `api-fixture-${fixtureId}`
          : `api-team-${numberValue(team.id) ?? fixtureId}`;
        rows.push({
          announcement_key: `${fixtureId}:${contract.id}:${side}:scenario:1`,
          fixture_id: fixtureId,
          source_snapshot_id: snapshotId,
          league_id: leagueId,
          kickoff_at: kickoffAt.toISOString(),
          announced_at: capturedAt.toISOString(),
          engine_version: "server_scenario_contract_v2",
          announcement_kind: "scenario",
          reading_id: contract.id,
          reading_label: earlyHierarchy
            ? "Écart de hiérarchie précoce"
            : contract.label,
          subject_side: side,
          subject_team_id: teamId,
          player_id: null,
          required_reading_ids: [
            ...new Set(contract.requirements.map((item) => item.readingId)),
          ],
          evidence: contract.requirements.map((item) =>
            scenarioEvidence(
              "Lecture confirmée",
              `${item.readingId} est présent avant le coup d’envoi.`,
              item.readingId,
              item.subject,
            )
          ),
          sample_size: 0,
          outcome_rule: contract.outcomeRule,
          rule_version: 2,
        });
      }
    }
  }
  return rows;
}

function scenarioTechnicalSupportAnnouncementRows({
  snapshotId,
  capturedAt,
  fixtures,
  expectedGoals,
  performanceStatistics,
}: {
  snapshotId: string;
  capturedAt: Date;
  fixtures: JsonObject[];
  expectedGoals: ExpectedGoalProfile[];
  performanceStatistics: JsonObject[];
}): JsonObject[] {
  type Technical = {
    leagueId: number;
    teamId: number;
    sampleSize: number;
    values: Map<string, number>;
  };
  const technical: Technical[] = [];
  for (const row of performanceStatistics) {
    const leagueId = numberValue((objectValue(row.league) ?? {}).id);
    const teamId = numberValue((objectValue(row.team) ?? {}).id);
    const averages = objectValue(row.averages) ?? {};
    if (leagueId === null || teamId === null) continue;
    const values = new Map<string, number>();
    for (
      const key of [
        "shotsFor",
        "shotsOnTargetFor",
        "shotsOnTargetAgainst",
        "cornersFor",
        "cornersAgainst",
        "cardsFor",
        "totalCards",
      ]
    ) {
      const value = numberValue(averages[key]);
      if (value !== null) values.set(key, value);
    }
    technical.push({
      leagueId,
      teamId,
      sampleSize: numberValue(row.sampleSize) ?? 0,
      values,
    });
  }
  const xgHighFor = edgeZonesByLeague(expectedGoals, (item) => item.xgFor);
  const xgHighAgainst = edgeZonesByLeague(
    expectedGoals,
    (item) => item.xgAgainst,
  );
  const zones = new Map<string, Map<number, EdgeZones>>();
  for (
    const key of [
      "shotsFor",
      "shotsOnTargetFor",
      "shotsOnTargetAgainst",
      "cornersFor",
      "cornersAgainst",
      "cardsFor",
    ]
  ) {
    zones.set(
      key,
      edgeZonesByLeague(
        technical.filter((item) => item.values.has(key)),
        (item) => item.values.get(key)!,
      ),
    );
  }
  const technicalByTeam = new Map(
    technical.map((item) => [`${item.leagueId}:${item.teamId}`, item]),
  );
  const xgByTeam = new Map(
    expectedGoals.map((item) => [`${item.leagueId}:${item.teamId}`, item]),
  );
  const rows: JsonObject[] = [];
  for (const row of fixtures) {
    const fixture = objectValue(row.fixture) ?? {};
    const league = objectValue(row.league) ?? {};
    const teams = objectValue(row.teams) ?? {};
    const fixtureId = numberValue(fixture.id);
    const leagueId = numberValue(league.id);
    const kickoffAt = dateValue(fixture.date);
    if (
      fixtureId === null || leagueId === null || kickoffAt === null ||
      kickoffAt <= capturedAt
    ) continue;
    const add = (
      id: string,
      label: string,
      side: "home" | "away" | "match",
      teamId: number | null,
      sampleSize: number,
      evidence: string,
    ) =>
      rows.push({
        announcement_key: `${fixtureId}:${id}:${side}:${teamId ?? fixtureId}:2`,
        fixture_id: fixtureId,
        source_snapshot_id: snapshotId,
        league_id: leagueId,
        kickoff_at: kickoffAt.toISOString(),
        announced_at: capturedAt.toISOString(),
        engine_version: "server_scenario_technical_support_v1",
        reading_id: id,
        reading_label: label,
        subject_side: side,
        subject_team_id: side === "match"
          ? `api-fixture-${fixtureId}`
          : `api-team-${teamId}`,
        player_id: null,
        evidence: [{
          label: evidence,
          source_path: "snapshot.raw.performance",
          value: null,
        }],
        sample_size: sampleSize,
        outcome_rule: null,
        rule_version: 1,
      });
    const teamEntries = [{
      side: "home" as const,
      team: objectValue(teams.home) ?? {},
    }, { side: "away" as const, team: objectValue(teams.away) ?? {} }];
    for (const entry of teamEntries) {
      const teamId = numberValue(entry.team.id);
      if (teamId === null) continue;
      const xg = xgByTeam.get(`${leagueId}:${teamId}`);
      if (xgHighFor.get(leagueId)?.high.has(teamId)) {
        add(
          "high_xg_creation",
          "Création d'xG élevée",
          entry.side,
          teamId,
          xg?.sampleSize ?? 0,
          `${
            teamName(entry.team)
          } crée des occasions de qualité au-dessus du championnat.`,
        );
      }
      if (xgHighFor.get(leagueId)?.low.has(teamId)) {
        add(
          "low_xg_creation",
          "Création d'xG faible",
          entry.side,
          teamId,
          xg?.sampleSize ?? 0,
          `${teamName(entry.team)} crée peu d'occasions de qualité.`,
        );
      }
      if (xgHighAgainst.get(leagueId)?.high.has(teamId)) {
        add(
          "high_xg_conceded",
          "xG concédés élevés",
          entry.side,
          teamId,
          xg?.sampleSize ?? 0,
          `${teamName(entry.team)} concède des occasions de qualité.`,
        );
      }
      const stats = technicalByTeam.get(`${leagueId}:${teamId}`);
      if (stats === undefined) continue;
      const signals: [string, string, string][] = [
        ["shotsFor", "high_shot_volume", "Volume de tirs élevé"],
        ["shotsOnTargetFor", "high_shots_on_target", "Tirs cadrés élevés"],
        [
          "shotsOnTargetAgainst",
          "high_shots_on_target_conceded",
          "Tirs cadrés concédés élevés",
        ],
        ["cornersFor", "high_corner_creation", "Corners obtenus élevés"],
        ["cornersAgainst", "high_corners_conceded", "Corners concédés élevés"],
        ["cardsFor", "high_card_rate", "Cartons reçus élevés"],
      ];
      for (const [metric, id, label] of signals) {
        if (zones.get(metric)?.get(leagueId)?.high.has(teamId)) {
          add(
            id,
            label,
            entry.side,
            teamId,
            stats.sampleSize,
            `${
              teamName(entry.team)
            } se situe dans la zone haute du championnat pour cet indicateur.`,
          );
        }
      }
    }
    const homeId = numberValue((objectValue(teams.home) ?? {}).id);
    const awayId = numberValue((objectValue(teams.away) ?? {}).id);
    const homeStats = homeId === null
      ? undefined
      : technicalByTeam.get(`${leagueId}:${homeId}`);
    const awayStats = awayId === null
      ? undefined
      : technicalByTeam.get(`${leagueId}:${awayId}`);
    if (
      homeStats !== undefined && awayStats !== undefined &&
      zones.get("cardsFor")?.get(leagueId)?.high.has(homeStats.teamId) &&
      zones.get("cardsFor")?.get(leagueId)?.high.has(awayStats.teamId)
    ) {
      add(
        "high_total_cards_profile",
        "Profil de cartons élevé",
        "match",
        null,
        Math.min(homeStats.sampleSize, awayStats.sampleSize),
        "Les deux équipes reçoivent beaucoup de cartons dans leur championnat.",
      );
    }
  }
  return rows;
}

function scenarioSupportAnnouncementRows({
  snapshotId,
  capturedAt,
  fixtures,
  recentForms,
  venueProfiles,
  standings,
}: {
  snapshotId: string;
  capturedAt: Date;
  fixtures: JsonObject[];
  recentForms: Map<string, RecentForm>;
  venueProfiles: Map<string, VenueProfile>;
  standings: Map<string, StandingProfile>;
}): JsonObject[] {
  const rows: JsonObject[] = [];
  for (const row of fixtures) {
    const fixture = objectValue(row.fixture) ?? {};
    const league = objectValue(row.league) ?? {};
    const teams = objectValue(row.teams) ?? {};
    const fixtureId = numberValue(fixture.id);
    const leagueId = numberValue(league.id);
    const kickoffAt = dateValue(fixture.date);
    const home = objectValue(teams.home) ?? {};
    const away = objectValue(teams.away) ?? {};
    const homeId = numberValue(home.id);
    const awayId = numberValue(away.id);
    if (
      fixtureId === null || leagueId === null || kickoffAt === null ||
      kickoffAt <= capturedAt || homeId === null || awayId === null
    ) continue;
    const add = (
      id: string,
      label: string,
      side: "home" | "away",
      teamId: number,
      evidence: string,
    ) =>
      rows.push({
        announcement_key: `${fixtureId}:${id}:${side}:api-team-${teamId}:2`,
        fixture_id: fixtureId,
        source_snapshot_id: snapshotId,
        league_id: leagueId,
        kickoff_at: kickoffAt.toISOString(),
        announced_at: capturedAt.toISOString(),
        engine_version: "server_scenario_support_v1",
        reading_id: id,
        reading_label: label,
        subject_side: side,
        subject_team_id: `api-team-${teamId}`,
        player_id: null,
        evidence: [{
          label: evidence,
          source_path: "snapshot.raw",
          value: null,
        }],
        sample_size: 3,
        outcome_rule: null,
        rule_version: 1,
      });
    const homeStanding = standings.get(`${leagueId}:${homeId}`);
    const awayStanding = standings.get(`${leagueId}:${awayId}`);
    if (
      homeStanding !== undefined && awayStanding !== undefined &&
      homeStanding.rank !== awayStanding.rank
    ) {
      const superiorHome = homeStanding.rank < awayStanding.rank;
      const superior = superiorHome ? homeStanding : awayStanding;
      const inferior = superiorHome ? awayStanding : homeStanding;
      const superiorTeam = superiorHome ? home : away;
      const inferiorTeam = superiorHome ? away : home;
      const superiorId = superiorHome ? homeId : awayId;
      const inferiorId = superiorHome ? awayId : homeId;
      const superiorSide = superiorHome ? "home" : "away";
      const inferiorSide = superiorHome ? "away" : "home";
      if (
        superior.points / superior.played > inferior.points / inferior.played
      ) {
        add(
          "ranking_superiority",
          "Supériorité au classement",
          superiorSide,
          superiorId,
          `${teamName(superiorTeam)} devance son adversaire au classement.`,
        );
        add(
          "ranking_inferiority",
          "Infériorité au classement",
          inferiorSide,
          inferiorId,
          `${
            teamName(inferiorTeam)
          } est derrière son adversaire au classement.`,
        );
      }
    }
    for (
      const subject of [{
        side: "home" as const,
        team: home,
        teamId: homeId,
        opponentId: awayId,
      }, {
        side: "away" as const,
        team: away,
        teamId: awayId,
        opponentId: homeId,
      }]
    ) {
      const form = recentForms.get(`${leagueId}:${subject.teamId}`);
      const opponentForm = recentForms.get(`${leagueId}:${subject.opponentId}`);
      const formPoints = form?.results.map(pointsForResult).reduce(
        (total, value) => total + value,
        0,
      );
      const opponentPoints = opponentForm?.results.map(pointsForResult).reduce(
        (total, value) => total + value,
        0,
      );
      if (
        formPoints !== undefined && opponentPoints !== undefined &&
        formPoints > opponentPoints
      ) {
        add(
          "form_advantage",
          "Avantage de forme",
          subject.side,
          subject.teamId,
          `${
            teamName(subject.team)
          } totalise davantage de points sur les trois derniers matchs.`,
        );
      }
      const venue = venueProfiles.get(`${leagueId}:${subject.teamId}`);
      if (venue !== undefined) {
        const strong = subject.side === "home"
          ? isStrong(venue.homePlayed, venue.homeWins, venue.homeLosses)
          : isStrong(venue.awayPlayed, venue.awayWins, venue.awayLosses);
        if (strong) {
          add(
            "venue_strength",
            "Avantage sur le lieu",
            subject.side,
            subject.teamId,
            `${teamName(subject.team)} présente un bilan solide sur ce lieu.`,
          );
        }
      }
    }
  }
  return rows;
}

function scenarioEvidence(
  title: string,
  label: string,
  readingId: string,
  subject: string,
): JsonObject {
  return { title, label, reading_id: readingId, subject };
}

function goalAverage(profile: GoalProfile): string {
  return (profile.totalGoals / profile.played).toFixed(2);
}

function levelFormVenueAnnouncementRows({
  snapshotId,
  capturedAt,
  fixtures,
  recentForms,
  venueProfiles,
  standings,
}: {
  snapshotId: string;
  capturedAt: Date;
  fixtures: JsonObject[];
  recentForms: Map<string, RecentForm>;
  venueProfiles: Map<string, VenueProfile>;
  standings: Map<string, StandingProfile>;
}): JsonObject[] {
  const rows: JsonObject[] = [];
  const seenFixtures = new Set<number>();
  for (const row of fixtures) {
    const fixture = objectValue(row.fixture) ?? {};
    const league = objectValue(row.league) ?? {};
    const teams = objectValue(row.teams) ?? {};
    const fixtureId = numberValue(fixture.id);
    const kickoffAt = dateValue(fixture.date);
    const leagueId = numberValue(league.id);
    const home = objectValue(teams.home) ?? {};
    const away = objectValue(teams.away) ?? {};
    const homeId = numberValue(home.id);
    const awayId = numberValue(away.id);
    if (
      fixtureId === null || seenFixtures.has(fixtureId) || kickoffAt === null ||
      kickoffAt <= capturedAt || leagueId === null || homeId === null ||
      awayId === null
    ) continue;
    seenFixtures.add(fixtureId);

    const subjects = [
      { side: "home", team: home, teamId: homeId },
      { side: "away", team: away, teamId: awayId },
    ] as const;
    for (const subject of subjects) {
      const form = recentForms.get(`${leagueId}:${subject.teamId}`);
      if (form !== undefined) {
        rows.push(...formAnnouncementRows({
          snapshotId,
          capturedAt,
          fixtureId,
          kickoffAt,
          leagueId,
          subject,
          form,
        }));
      }
      const venue = venueProfiles.get(`${leagueId}:${subject.teamId}`);
      if (venue !== undefined) {
        rows.push(...venueAnnouncementRows({
          snapshotId,
          capturedAt,
          fixtureId,
          kickoffAt,
          leagueId,
          subject,
          venue,
        }));
      }
    }

    const homeVenue = venueProfiles.get(`${leagueId}:${homeId}`);
    const awayVenue = venueProfiles.get(`${leagueId}:${awayId}`);
    const homeStanding = standings.get(`${leagueId}:${homeId}`);
    const awayStanding = standings.get(`${leagueId}:${awayId}`);
    if (homeStanding !== undefined && awayStanding !== undefined) {
      const superior = homeStanding.rank < awayStanding.rank
        ? {
          subject: subjects[0],
          standing: homeStanding,
          opponent: awayStanding,
        }
        : awayStanding.rank < homeStanding.rank
        ? {
          subject: subjects[1],
          standing: awayStanding,
          opponent: homeStanding,
        }
        : null;
      const structuralGap = superior === null
        ? null
        : assessStructuralGap(superior.standing, superior.opponent);
      if (superior !== null && structuralGap !== null) {
        rows.push(directionAnnouncement({
          snapshotId,
          capturedAt,
          fixtureId,
          kickoffAt,
          leagueId,
          readingId: "structural_level_gap",
          label: structuralGap.phase === "early"
            ? "Écart de hiérarchie précoce"
            : "Écart de niveau structurel",
          subject: superior.subject,
          sampleSize: Math.min(
            superior.standing.played,
            superior.opponent.played,
          ),
          evidence: `${
            teamName(superior.subject.team)
          } devance son adversaire de ${
            Math.abs(homeStanding.rank - awayStanding.rank)
          } rangs et ${
            (superior.standing.points / superior.standing.played -
              superior.opponent.points / superior.opponent.played).toFixed(2)
          } point par match, au-dessus du seuil de ${
            structuralGap.minimumPointsPerGameGap.toFixed(2)
          } après ${structuralGap.comparedMatches} journées comparables.`,
        }));
      }
    }
    if (homeVenue !== undefined && awayVenue !== undefined) {
      if (
        isStrong(
          homeVenue.homePlayed,
          homeVenue.homeWins,
          homeVenue.homeLosses,
        ) &&
        isWeak(awayVenue.awayPlayed, awayVenue.awayWins, awayVenue.awayLosses)
      ) {
        rows.push(directionAnnouncement({
          snapshotId,
          capturedAt,
          fixtureId,
          kickoffAt,
          leagueId,
          readingId: "home_away_advantage",
          label: "Avantage domicile / extérieur",
          subject: subjects[0],
          sampleSize: Math.min(homeVenue.homePlayed, awayVenue.awayPlayed),
          evidence: `${teamName(home)} est solide à domicile et ${
            teamName(away)
          } fragile à l’extérieur.`,
        }));
      }
      if (
        isStrong(
          awayVenue.awayPlayed,
          awayVenue.awayWins,
          awayVenue.awayLosses,
        ) &&
        isWeak(homeVenue.homePlayed, homeVenue.homeWins, homeVenue.homeLosses)
      ) {
        rows.push(directionAnnouncement({
          snapshotId,
          capturedAt,
          fixtureId,
          kickoffAt,
          leagueId,
          readingId: "away_home_advantage",
          label: "Avantage extérieur / domicile",
          subject: subjects[1],
          sampleSize: Math.min(homeVenue.homePlayed, awayVenue.awayPlayed),
          evidence: `${teamName(away)} est solide à l’extérieur et ${
            teamName(home)
          } fragile à domicile.`,
        }));
      }
    }
  }
  return rows;
}

function formAnnouncementRows({
  snapshotId,
  capturedAt,
  fixtureId,
  kickoffAt,
  leagueId,
  subject,
  form,
}: {
  snapshotId: string;
  capturedAt: Date;
  fixtureId: number;
  kickoffAt: Date;
  leagueId: number;
  subject: { side: "home" | "away"; team: JsonObject; teamId: number };
  form: RecentForm;
}): JsonObject[] {
  const points = form.results.map(pointsForResult);
  const total = points.reduce((sum, value) => sum + value, 0);
  const label = form.results.join("");
  const rows: JsonObject[] = [];
  if (!points.includes(0) && total >= 5) {
    rows.push(directionAnnouncement({
      snapshotId,
      capturedAt,
      fixtureId,
      kickoffAt,
      leagueId,
      subject,
      readingId: "positive_streak",
      label: "Dynamique positive",
      sampleSize: 3,
      evidence: `${
        teamName(subject.team)
      } reste invaincu sur ses trois derniers matchs (${label}, ${total}/9).`,
      outcomeRule: "team_not_lose",
    }));
  }
  if (!points.includes(3) && total <= 2) {
    rows.push(directionAnnouncement({
      snapshotId,
      capturedAt,
      fixtureId,
      kickoffAt,
      leagueId,
      subject,
      readingId: "negative_streak",
      label: "Dynamique négative",
      sampleSize: 3,
      evidence: `${
        teamName(subject.team)
      } reste sans victoire sur ses trois derniers matchs (${label}, ${total}/9).`,
      outcomeRule: "team_loss",
    }));
  }
  const trend = ((points[0] + points[1]) / 2) - points[2];
  if (Math.abs(trend) >= 1) {
    const improving = trend > 0;
    rows.push(directionAnnouncement({
      snapshotId,
      capturedAt,
      fixtureId,
      kickoffAt,
      leagueId,
      subject,
      readingId: improving ? "improving_form" : "declining_form",
      label: improving ? "Forme en hausse" : "Forme en baisse",
      sampleSize: 3,
      evidence: `${teamName(subject.team)} ${
        improving ? "progresse" : "recule"
      } sur ses trois derniers matchs (${label}).`,
      outcomeRule: improving ? "team_not_lose" : "team_loss",
    }));
  }
  return rows;
}

function venueAnnouncementRows({
  snapshotId,
  capturedAt,
  fixtureId,
  kickoffAt,
  leagueId,
  subject,
  venue,
}: {
  snapshotId: string;
  capturedAt: Date;
  fixtureId: number;
  kickoffAt: Date;
  leagueId: number;
  subject: { side: "home" | "away"; team: JsonObject; teamId: number };
  venue: VenueProfile;
}): JsonObject[] {
  const isHome = subject.side === "home";
  const played = isHome ? venue.homePlayed : venue.awayPlayed;
  const wins = isHome ? venue.homeWins : venue.awayWins;
  const losses = isHome ? venue.homeLosses : venue.awayLosses;
  const place = isHome ? "domicile" : "extérieur";
  const rows: JsonObject[] = [];
  if (isStrong(played, wins, losses)) {
    rows.push(directionAnnouncement({
      snapshotId,
      capturedAt,
      fixtureId,
      kickoffAt,
      leagueId,
      subject,
      readingId: isHome ? "strong_home_team" : "strong_away_team",
      label: isHome ? "Solide à domicile" : "Solide à l’extérieur",
      sampleSize: played,
      evidence: `${teamName(subject.team)} gagne ${
        Math.round(wins / played * 100)
      }% de ses matchs à ${place}.`,
      outcomeRule: "team_not_lose",
    }));
  }
  if (isWeak(played, wins, losses)) {
    rows.push(directionAnnouncement({
      snapshotId,
      capturedAt,
      fixtureId,
      kickoffAt,
      leagueId,
      subject,
      readingId: isHome ? "weak_home_team" : "weak_away_team",
      label: isHome ? "Fragile à domicile" : "Fragile à l’extérieur",
      sampleSize: played,
      evidence: `${teamName(subject.team)} perd ${
        Math.round(losses / played * 100)
      }% de ses matchs à ${place}.`,
      outcomeRule: "team_loss",
    }));
  }
  return rows;
}

function directionAnnouncement({
  snapshotId,
  capturedAt,
  fixtureId,
  kickoffAt,
  leagueId,
  readingId,
  label,
  subject,
  sampleSize,
  evidence,
  outcomeRule = "team_win",
}: {
  snapshotId: string;
  capturedAt: Date;
  fixtureId: number;
  kickoffAt: Date;
  leagueId: number;
  readingId: string;
  label: string;
  subject: { side: "home" | "away"; team: JsonObject; teamId: number };
  sampleSize: number;
  evidence: string;
  outcomeRule?: string;
}): JsonObject {
  const subjectTeamId = `api-team-${subject.teamId}`;
  return {
    announcement_key:
      `${fixtureId}:${readingId}:${subject.side}:${subjectTeamId}:1`,
    fixture_id: fixtureId,
    source_snapshot_id: snapshotId,
    league_id: leagueId,
    kickoff_at: kickoffAt.toISOString(),
    announced_at: capturedAt.toISOString(),
    engine_version: "server_level_form_venue_v1",
    reading_id: readingId,
    reading_label: label,
    subject_side: subject.side,
    subject_team_id: subjectTeamId,
    player_id: null,
    evidence: [{
      label: evidence,
      source_path: "snapshot.raw",
      value: { window: sampleSize },
    }],
    sample_size: sampleSize,
    outcome_rule: outcomeRule,
    rule_version: 1,
  };
}

function pointsForResult(result: string): number {
  return result === "W" ? 3 : result === "D" ? 1 : 0;
}

function isStrong(played: number, wins: number, losses: number): boolean {
  return played > 0 && wins > losses;
}

function isWeak(played: number, wins: number, losses: number): boolean {
  return played > 0 && losses > wins;
}

function teamName(team: JsonObject): string {
  return stringValue(team.name) ?? "Cette équipe";
}

async function insertAnnouncements({
  supabaseUrl,
  serviceRoleKey,
  announcements,
}: {
  supabaseUrl: string;
  serviceRoleKey: string;
  announcements: JsonObject[];
}): Promise<number> {
  let inserted = 0;
  for (let index = 0; index < announcements.length; index += 100) {
    // PostgREST requires every object in a bulk insert to expose the same
    // columns. Scenarios and nuances add fields that ordinary readings do not
    // use, so make the complete persisted contract explicit for every row.
    const rowsToInsert = announcements.slice(index, index + 100).map((row) => ({
      ...row,
      announcement_kind: row.announcement_kind ?? "reading",
      parent_announcement_key: row.parent_announcement_key ?? null,
      required_reading_ids: row.required_reading_ids ?? [],
      player_name: row.player_name ?? null,
    }));
    const rows = await supabaseFetch({
      supabaseUrl,
      serviceRoleKey,
      path: "/rest/v1/match_reading_announcements?on_conflict=announcement_key",
      method: "POST",
      body: rowsToInsert,
      prefer: "resolution=ignore-duplicates,return=representation",
    });
    inserted += rows.length;
  }
  return inserted;
}

function lowerQuartile(values: number[]): number {
  if (values.length === 0) return Number.POSITIVE_INFINITY;
  return median(values.slice(0, Math.floor(values.length / 2)));
}

function upperQuartile(values: number[]): number {
  if (values.length === 0) return Number.POSITIVE_INFINITY;
  const middle = Math.floor(values.length / 2);
  return median(
    values.length % 2 === 0 ? values.slice(middle) : values.slice(middle + 1),
  );
}

function median(values: number[]): number {
  if (values.length === 0) return Number.POSITIVE_INFINITY;
  const middle = Math.floor(values.length / 2);
  return values.length % 2 === 1
    ? values[middle]
    : (values[middle - 1] + values[middle]) / 2;
}

function span(values: { value: number }[]): number {
  return values[0].value - values[values.length - 1].value;
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
  const payload = await response.json();
  return Array.isArray(payload) ? payload : [];
}

function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing ${name}`);
  return value;
}

function objectValue(value: unknown): JsonObject | null {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? value as JsonObject
    : null;
}

function objectList(value: unknown): JsonObject[] {
  return Array.isArray(value)
    ? value.map(objectValue).filter((item): item is JsonObject => item !== null)
    : [];
}

function stringValue(value: unknown): string | null {
  return typeof value === "string" && value.length > 0 ? value : null;
}

function numberValue(value: unknown): number | null {
  if (value === null || value === undefined || value === "") return null;
  const parsed = typeof value === "number" ? value : Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function dateValue(value: unknown): Date | null {
  const text = stringValue(value);
  if (text === null) return null;
  const date = new Date(text);
  return Number.isNaN(date.getTime()) ? null : date;
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
