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
            'supabase/migrations/20260831120000_backend_reject_empty_api_football_snapshots.sql',
          ).readAsStringSync();
    });

    test('resolves seasons from league fixture coverage, not current year', () {
      for (final source in [apiSync, snapshotBuilder]) {
        expect(source, contains('seasonForWindowFromLeaguesPayload'));
        expect(source, contains('coverage.fixtures'));
        expect(source, contains('dateRangesOverlap'));
        expect(source, isNot(contains('current: "true"')));
        expect(source, isNot(contains('current=true')));
      }

      expect(apiSync, contains('summary.leagueSeasons'));
      expect(snapshotBuilder, contains('seasonForLeagueFromRows'));
      expect(snapshotBuilder, contains('numberValue(league.season)'));
    });

    test('does not inject one global season into scheduled jobs', () {
      expect(cronGenerator, isNot(contains("'season'")));
      expect(cronGenerator, isNot(contains('"season"')));
      expect(dailySync, contains('season: number | null'));
      expect(dailySync, contains('if (options.season !== null)'));
      expect(
        dailySync,
        isNot(contains('season: options.season,')),
        reason: 'season can only be forwarded as an explicit override',
      );
    });

    test('keeps one staggered sync and one snapshot job per MVP league', () {
      expect(
        cronGenerator,
        contains('RuntimeCompetitionCatalog.apiFootballLeagueIds'),
      );
      expect(cronGenerator, contains('final syncMinuteOffset = index * 4'));
      expect(
        cronGenerator,
        contains('final snapshotMinuteOffset = syncMinuteOffset + 3'),
      );
      expect(cronGenerator, contains("'api-football-league-\$leagueId'"));
      expect(
        cronGenerator,
        contains("'api-football-league-\$leagueId-snapshot'"),
      );
      expect(cronGenerator, contains("where jobname like 'api-football-%'"));
      expect(
        cronGenerator,
        contains("and jobname not like 'api-football-run-now-%'"),
      );
      expect(cronGenerator, isNot(contains('api-football-build-snapshot')));
      expect(cronGenerator, contains("now() at time zone 'UTC'"));
      expect(cronGenerator, isNot(contains('DateTime.now()')));
    });

    test('documents the operational invariants', () {
      expect(docs, contains('/leagues?id=<league_id>'));
      expect(docs, contains('coverage.fixtures.start'));
      expect(docs, contains('coverage.fixtures.end'));
      expect(docs, contains('season_by_league'));
      expect(docs, contains('API-Football peut repondre en HTTP 200'));
      expect(docs, contains('une saison API-Football `2027`'));
      expect(docs, contains('une collecte par ligue'));
      expect(docs, contains('un snapshot par ligue'));
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
