import 'dart:io';

import 'package:copilot/features/onboarding/domain/decision_profile_catalogs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Backend data pipeline guards', () {
    late String apiSync;
    late String snapshotBuilder;
    late String dailySync;
    late String cronGenerator;
    late String docs;
    late String observabilityMigration;
    late String quotaGuardMigration;

    setUpAll(() {
      apiSync = File(
        'supabase/functions/api-football-sync/index.ts',
      ).readAsStringSync();
      snapshotBuilder = File(
        'supabase/functions/build-match-feed-snapshot/index.ts',
      ).readAsStringSync();
      dailySync = File(
        'supabase/functions/daily-football-sync/index.ts',
      ).readAsStringSync();
      cronGenerator = File(
        'tool/generate_supabase_cron_sql.dart',
      ).readAsStringSync();
      docs = File('docs/backend-daily-football-sync.md').readAsStringSync();
      observabilityMigration =
          File(
            'supabase/migrations/20260815123000_backend_data_observability.sql',
          ).readAsStringSync() +
          File(
            'supabase/migrations/20260816120000_backend_expand_active_league_scope.sql',
          ).readAsStringSync() +
          File(
            'supabase/migrations/20260915130000_backend_add_uefa_league_phase_scope.sql',
          ).readAsStringSync() +
          File(
            'supabase/migrations/20260920020000_backend_expand_approved_competition_scope.sql',
          ).readAsStringSync() +
          File(
            'supabase/migrations/20260926160000_backend_expand_radar_international_scope.sql',
          ).readAsStringSync() +
          File(
            'supabase/migrations/20260831120000_backend_reject_empty_api_football_snapshots.sql',
          ).readAsStringSync();
      quotaGuardMigration =
          File(
            'supabase/migrations/20260916170000_backend_api_football_quota_guard.sql',
          ).readAsStringSync() +
          File(
            'supabase/migrations/20260916183000_backend_api_football_ultra_quota.sql',
          ).readAsStringSync();
    });

    test('resolves seasons from league fixture coverage, not current year', () {
      for (final source in [apiSync, snapshotBuilder]) {
        expect(source, contains('seasonForWindowFromLeaguesPayload'));
        expect(source, contains('coverage.fixtures'));
        expect(source, contains('dateRangesOverlap'));
        expect(source, contains('return b.start.localeCompare(a.start);'));
        expect(
          source.indexOf('return b.start.localeCompare(a.start);'),
          lessThan(source.indexOf('return a.current ? -1 : 1;')),
          reason:
              'fixture coverage dates must outrank the provider current flag',
        );
        expect(source, isNot(contains('current: "true"')));
        expect(source, isNot(contains('current=true')));
      }

      expect(apiSync, contains('summary.leagueSeasons'));
      expect(snapshotBuilder, contains('seasonForLeagueFromRows'));
      expect(snapshotBuilder, contains('numberValue(league.season)'));
      expect(snapshotBuilder, isNot(contains('fallback: fallbackSeason')));
    });

    test('does not inject one global season into scheduled jobs', () {
      expect(cronGenerator, isNot(contains("'season'")));
      expect(cronGenerator, isNot(contains('"season"')));
      expect(dailySync, contains('season: number | null'));
      expect(dailySync, contains('if (options.season !== null)'));
      final syncPayloadSource = dailySync
          .split('function syncPayload(')
          .last
          .split('function snapshotPayload(')
          .first;
      expect(
        syncPayloadSource,
        isNot(contains('season: options.season,')),
        reason: 'season can only be forwarded as an explicit override',
      );
    });

    test('keeps one staggered orchestrated job per MVP league', () {
      expect(
        cronGenerator,
        contains('RuntimeCompetitionCatalog.apiFootballLeagueIds'),
      );
      expect(cronGenerator, contains('final dailyMinuteOffset = index * 4'));
      expect(cronGenerator, contains("'api-football-league-\$leagueId'"));
      expect(
        cronGenerator,
        isNot(contains("'api-football-league-\$leagueId-snapshot'")),
      );
      expect(cronGenerator, contains('daily-football-sync'));
      expect(cronGenerator, isNot(contains('api-football-sync')));
      expect(cronGenerator, isNot(contains('build-match-feed-snapshot')));
      expect(cronGenerator, contains("'results_days_back', 7"));
      expect(cronGenerator, contains("'future_days', 3"));
      expect(cronGenerator, contains("'include_player_statistics', false"));
      expect(cronGenerator, contains("'api-football-enrichment-\$leagueId'"));
      expect(cronGenerator, contains("'include_player_statistics', true"));
      expect(
        apiSync,
        contains('const registerPlayerStatisticsTeam'),
        reason:
            'the daily job must refresh player statistics for imminent fixtures',
      );
      expect(apiSync, contains('for (const side of ["home", "away"])'));
      expect(
        apiSync,
        contains('booleanValue(payload.include_player_statistics) ?? false'),
      );
      expect(cronGenerator, isNot(contains("'bookmaker_id', 16")));
      expect(dailySync, isNot(contains('defaultBookmakerId')));
      expect(snapshotBuilder, contains('filters: oddsFilters,\n        //'));
      expect(cronGenerator, contains("where jobname like 'api-football-%'"));
      expect(
        cronGenerator,
        contains("and jobname not like 'api-football-run-now-%'"),
      );
      expect(cronGenerator, isNot(contains('api-football-build-snapshot')));
      expect(cronGenerator, isNot(contains('DateTime.now()')));
    });

    test('keeps the approved 76-competition scope resolvable end to end', () {
      const approvedAdditions = <int>[
        531,
        45,
        48,
        528,
        66,
        526,
        81,
        529,
        96,
        550,
        143,
        556,
        137,
        547,
        90,
        543,
        147,
        519,
        181,
        185,
        551,
        1,
        32,
        4,
        5,
        38,
        10,
        9,
        6,
        7,
        22,
        536,
        64,
        525,
        1191,
        8,
      ];

      expect(RuntimeCompetitionCatalog.apiFootballLeagueIds, hasLength(76));
      expect(
        RuntimeCompetitionCatalog.apiFootballLeagueIds,
        containsAll(approvedAdditions),
      );
      expect(RuntimeCompetitionCatalog.values, hasLength(76));
      for (final leagueId in RuntimeCompetitionCatalog.apiFootballLeagueIds) {
        expect(
          CompetitionCatalog.byApiFootballLeagueId(leagueId),
          isNotNull,
          reason: 'competition $leagueId must be selectable in Flutter',
        );
      }
    });

    test('collects UEFA league phases and reuses factual domestic caches', () {
      expect(
        RuntimeCompetitionCatalog.apiFootballLeagueIds,
        containsAll([2, 3, 848]),
      );
      expect(snapshotBuilder, contains('domestic_team_contexts'));
      expect(
        snapshotBuilder,
        contains('domesticTeamContextsFromCachedStandings'),
      );
      expect(snapshotBuilder, contains('filters: {}'));
      expect(snapshotBuilder, isNot(contains('uefaCoefficient')));
      expect(snapshotBuilder, isNot(contains('leagueStrength')));
    });

    test('documents the operational invariants', () {
      expect(docs, contains('/leagues?id=<league_id>'));
      expect(docs, contains('coverage.fixtures.start'));
      expect(docs, contains('coverage.fixtures.end'));
      expect(docs, contains('season_by_league'));
      expect(docs, contains('API-Football peut repondre en HTTP 200'));
      expect(docs, contains('une saison API-Football `2027`'));
      expect(docs, contains('un run orchestre par ligue'));
      expect(docs, contains('seulement apres la'));
      expect(docs, contains('fin de la collecte'));
      expect(
        docs,
        contains('Ne pas programmer un job `build-match-feed-snapshot`'),
      );
      expect(docs, contains('force_rebuild: true'));
    });

    test('rejects API-Football error payloads and empty publications', () {
      expect(apiSync, contains('apiFootballErrorMessages'));
      expect(apiSync, contains('API-Football error for'));
      expect(apiSync, contains('payload.errors'));
      expect(snapshotBuilder, contains('Cached API-Football response for'));
      expect(snapshotBuilder, contains('emptySnapshotPublicationError'));
      expect(
        snapshotBuilder,
        contains('Refusing to publish an empty match feed snapshot.'),
      );
      expect(observabilityMigration, contains('empty_snapshot'));
    });

    test('enforces provider quotas across concurrent sync runs', () {
      expect(
        quotaGuardMigration,
        contains('public.reserve_api_football_request'),
      );
      expect(quotaGuardMigration, contains("interval '60 seconds'"));
      expect(quotaGuardMigration, contains("time zone 'UTC'"));
      expect(quotaGuardMigration, contains('pg_advisory_xact_lock'));
      expect(
        quotaGuardMigration,
        contains('p_daily_limit integer default 75000'),
      );
      expect(
        quotaGuardMigration,
        contains('p_minute_limit integer default 450'),
      );
      expect(apiSync, contains('reserveApiFootballRequest(options)'));
      expect(apiSync, contains('API-Football quota guard blocked'));
    });

    test('exposes service-role observability for all MVP leagues', () {
      for (final leagueId in RuntimeCompetitionCatalog.apiFootballLeagueIds) {
        expect(observabilityMigration, contains('($leagueId,'));
      }

      expect(
        observabilityMigration,
        contains('public.api_football_latest_league_sync_health'),
      );
      expect(
        observabilityMigration,
        contains('public.api_football_latest_league_snapshot_health'),
      );
      expect(
        observabilityMigration,
        contains('public.api_football_pipeline_health'),
      );
      expect(observabilityMigration, contains('resolved_season'));
      expect(observabilityMigration, contains('health_status'));
      expect(observabilityMigration, contains('missing_team_statistics'));
      expect(observabilityMigration, contains('missing_recent_form'));
      expect(observabilityMigration, contains('stale_running'));
      expect(observabilityMigration, contains('missing_snapshot'));
      expect(observabilityMigration, contains('grant select'));
      expect(observabilityMigration, contains('to service_role'));
      expect(observabilityMigration, isNot(contains('to anon, authenticated')));
    });
  });
}
