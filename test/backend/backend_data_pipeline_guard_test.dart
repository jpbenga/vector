import 'dart:io';

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
      observabilityMigration = File(
        'supabase/migrations/20260815123000_backend_data_observability.sql',
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
      expect(cronGenerator, contains('const leagues = <int>['));
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
      expect(cronGenerator, isNot(contains('api-football-build-snapshot')));
      expect(cronGenerator, contains("now() at time zone 'UTC'"));
      expect(cronGenerator, isNot(contains('DateTime.now()')));
    });

    test('documents the operational invariants', () {
      expect(docs, contains('/leagues?id=<league_id>'));
      expect(docs, contains('coverage.fixtures.start'));
      expect(docs, contains('coverage.fixtures.end'));
      expect(docs, contains('season_by_league'));
      expect(docs, contains('une saison API-Football `2027`'));
      expect(docs, contains('une collecte par ligue'));
      expect(docs, contains('un snapshot par ligue'));
      expect(docs, contains('force_rebuild: true'));
    });

    test('exposes service-role observability for all MVP leagues', () {
      for (final leagueId in [
        39,
        61,
        140,
        78,
        135,
        94,
        88,
        144,
        179,
        203,
        197,
        119,
        207,
        218,
        40,
        62,
        136,
        79,
        141,
        106,
        210,
        209,
        283,
        253,
        71,
        128,
        262,
        307,
        98,
        188,
      ]) {
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
