import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Daily Football Sync MVP', () {
    late String migration;
    late String supabaseFunction;
    late String vercelConfig;
    late String docs;

    setUpAll(() {
      migration = File(
        'supabase/migrations/20260813080000_backend_daily_football_sync.sql',
      ).readAsStringSync();
      supabaseFunction = File(
        'supabase/functions/daily-football-sync/index.ts',
      ).readAsStringSync();
      vercelConfig = File('vercel.json').readAsStringSync();
      docs = File('docs/backend-daily-football-sync.md').readAsStringSync();
    });

    test('logs daily orchestration and storage monitoring in Supabase', () {
      expect(
        migration,
        contains('create table public.daily_football_sync_runs'),
      );
      expect(migration, contains('results_window_start date not null'));
      expect(migration, contains('feed_window_start date not null'));
      expect(migration, contains('api_request_delay_ms integer not null'));
      expect(migration, contains('database_size_bytes bigint'));
      expect(migration, contains('database_size_ratio numeric(6, 5)'));
      expect(
        migration,
        contains(
          "storage_warning_level in ('ok', 'warning_80', 'warning_90', 'critical_95')",
        ),
      );
      expect(
        migration,
        contains('current_database_size_bytes()'),
        reason: 'the backend must be able to record the current database size',
      );
      expect(
        migration,
        contains(
          'grant execute on function public.current_database_size_bytes()',
        ),
        reason: 'storage measurement should stay server-side',
      );
    });

    test('keeps daily sync logs read-only for client roles', () {
      expect(
        migration,
        contains(
          'alter table public.daily_football_sync_runs enable row level security;',
        ),
      );
      expect(
        migration,
        contains(
          'alter table public.daily_football_sync_runs force row level security;',
        ),
      );
      expect(
        migration,
        contains(
          'revoke insert, update, delete on table public.daily_football_sync_runs',
        ),
      );
      expect(
        migration,
        contains('grant select on table public.daily_football_sync_runs'),
      );
    });

    test('orchestrates collection then snapshot build server-side', () {
      expect(supabaseFunction, contains('name: "api-football-sync"'));
      expect(supabaseFunction, contains('name: "build-match-feed-snapshot"'));
      expect(supabaseFunction, contains('API_FOOTBALL_SYNC_SECRET'));
      expect(
        supabaseFunction,
        isNot(contains('API_FOOTBALL_KEY')),
        reason:
            'daily orchestration should not read the football API key directly',
      );
      expect(supabaseFunction, contains('results_days_back'));
      expect(supabaseFunction, contains('future_days'));
      expect(supabaseFunction, contains('api_request_delay_ms'));
      expect(supabaseFunction, contains('defaultResultsDaysBack = 2'));
      expect(supabaseFunction, contains('defaultFutureDays = 3'));
      expect(supabaseFunction, contains('markStaleDailyRuns'));
    });

    test('applies a polite API-Football request delay', () {
      final apiFunction = File(
        'supabase/functions/api-football-sync/index.ts',
      ).readAsStringSync();

      expect(apiFunction, contains('defaultApiRequestDelayMs = 750'));
      expect(apiFunction, contains('API_FOOTBALL_REQUEST_DELAY_MS'));
      expect(apiFunction, contains('requestDelayMs: apiRequestDelayMs'));
      expect(apiFunction, contains('await delay(options.requestDelayMs)'));
    });

    test(
      'resolves the active season per league instead of using a hardcoded season',
      () {
        final apiFunction = File(
          'supabase/functions/api-football-sync/index.ts',
        ).readAsStringSync();
        final snapshotBuilder = File(
          'supabase/functions/build-match-feed-snapshot/index.ts',
        ).readAsStringSync();

        expect(apiFunction, contains('current: "true"'));
        expect(apiFunction, contains('currentSeasonFromLeaguesPayload'));
        expect(apiFunction, contains('leagueSeasons'));
        expect(supabaseFunction, contains('season_by_league'));
        expect(snapshotBuilder, contains('seasonByLeague'));
        expect(snapshotBuilder, contains('seasonForLeague(options, leagueId)'));
        expect(docs, contains("La saison n'est pas configuree"));
      },
    );

    test('keeps the long-running data cron out of Vercel', () {
      expect(vercelConfig, isNot(contains('"crons"')));
      expect(docs, contains('Supabase Cron'));
      expect(docs, contains('La collecte peut depasser le timeout'));
      expect(docs, contains('une collecte par ligue'));
      expect(docs, contains('snapshot final unique'));
      expect(docs, contains('daily-football-sync'));
      expect(docs, contains('307,98,188'));
      expect(docs, isNot(contains('CRON_SECRET')));
    });

    test('documents manual deployment and validation steps', () {
      expect(docs, contains('00:00 UTC'));
      expect(docs, contains('Resultats : J-2 -> J-1'));
      expect(docs, contains('Feed front : J -> J+3'));
      expect(docs, contains('tool/generate_supabase_cron_sql.dart'));
      expect(docs, contains('npx supabase db push'));
      expect(
        docs,
        contains(
          'npx supabase functions deploy daily-football-sync --no-verify-jwt',
        ),
      );
      expect(docs, contains('SUPABASE_DATABASE_SIZE_LIMIT_BYTES'));
    });

    test('generates one Supabase cron job per league plus final snapshot', () {
      final generator = File(
        'tool/generate_supabase_cron_sql.dart',
      ).readAsStringSync();

      expect(generator, contains('api-football-league-\$leagueId'));
      expect(generator, contains('api-football-build-snapshot'));
      expect(generator, contains('final minuteOffset = index * 4'));
      expect(generator, contains('leagues.length'));
      expect(generator, contains('API_FOOTBALL_SYNC_SECRET'));
      expect(generator, contains('build-match-feed-snapshot'));
    });
  });
}
