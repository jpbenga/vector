import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Supabase Lot 2 API-Football server foundation', () {
    late String migration;
    late String enrichmentMigration;
    late String functionSource;
    late String envExample;

    setUpAll(() {
      migration = File(
        'supabase/migrations/20260811103000_backend_lot_2_api_football_server.sql',
      ).readAsStringSync();
      enrichmentMigration = File(
        'supabase/migrations/20260812103000_backend_lot_3c_snapshot_enrichment.sql',
      ).readAsStringSync();
      functionSource = File(
        'supabase/functions/api-football-sync/index.ts',
      ).readAsStringSync();
      envExample = File('.env.example').readAsStringSync();
    });

    test('creates server-only sync logs and raw response cache', () {
      expect(migration, contains('create table public.api_football_sync_runs'));
      expect(
        migration,
        contains('create table public.api_football_cached_responses'),
      );
      expect(migration, contains("kind in ('match_feed_window')"));
      expect(
        migration,
        contains("status in ('running', 'succeeded', 'failed', 'partial')"),
      );
    });

    test('stores provenance and idempotent cache keys', () {
      final cacheTable = _tableBlock(
        migration,
        'api_football_cached_responses',
      );

      expect(
        cacheTable,
        contains("source text not null default 'api-football'"),
      );
      expect(cacheTable, contains('query_hash text not null'));
      expect(cacheTable, contains('query_params jsonb not null'));
      expect(cacheTable, contains('response_body jsonb not null'));
      expect(cacheTable, contains('rate_limit jsonb not null'));
      expect(cacheTable, contains('fetched_at timestamptz not null'));
      expect(cacheTable, contains('as_of timestamptz not null'));
      expect(cacheTable, contains('expires_at timestamptz'));
      expect(
        cacheTable,
        contains('primary key (source, endpoint, query_hash)'),
      );
    });

    test('limits Lot 2 cache to raw API-Football endpoints', () {
      final cacheTable = _tableBlock(
        migration,
        'api_football_cached_responses',
      );
      final cacheEndpointContract = '$cacheTable\n$enrichmentMigration';

      for (final endpoint in [
        '/leagues',
        '/fixtures',
        '/standings',
        '/teams/statistics',
        '/fixtures/statistics',
        '/odds',
      ]) {
        expect(cacheEndpointContract, contains("'$endpoint'"));
      }

      expect(
        migration.toLowerCase(),
        isNot(contains('create table public.match_snapshots')),
        reason: 'Immutable match snapshots belong to Lot 3, not Lot 2.',
      );
    });

    test('keeps API-Football tables inaccessible to client roles', () {
      for (final table in [
        'api_football_sync_runs',
        'api_football_cached_responses',
      ]) {
        expect(
          migration,
          contains('alter table public.$table enable row level security;'),
        );
        expect(
          migration,
          contains('alter table public.$table force row level security;'),
        );
        expect(migration, contains('revoke all on table public.$table'));
        expect(
          migration,
          isNot(contains('create policy')),
          reason:
              'Lot 2 raw cache is server-only and should not expose client RLS policies.',
        );
      }
    });

    test('edge function keeps API-Football secret server-side', () {
      expect(functionSource, contains('requireEnv("API_FOOTBALL_KEY")'));
      expect(functionSource, contains('"x-apisports-key": options.apiKey'));
      expect(
        functionSource,
        contains('requireEnv("SUPABASE_SERVICE_ROLE_KEY")'),
      );
      expect(functionSource, contains('API_FOOTBALL_SYNC_SECRET'));
      expect(functionSource, contains('request.headers.get("authorization")'));
      expect(functionSource, contains(r'replace(/^Bearer\s+/i'));
      expect(functionSource, isNot(contains('service_role secret')));
    });

    test('edge function protects quotas and writes cache idempotently', () {
      expect(functionSource, contains('const maxDays = 7;'));
      expect(functionSource, contains('const maxLeagues = 40;'));
      expect(
        functionSource,
        contains('const maxTeamStatisticsRequests = 120;'),
      );
      expect(functionSource, contains('const maxRecentFixtureRequests = 160;'));
      expect(
        functionSource,
        contains('const maxFixtureStatisticsRequests = 240;'),
      );
      expect(functionSource, contains('prefer: "resolution=merge-duplicates'));
      expect(functionSource, contains('sha256Hex'));
      expect(functionSource, contains('sortedObject(options.query)'));
      expect(functionSource, contains('rateLimitHeaders(response.headers)'));
    });

    test('collects factual recent form and historical fixture statistics', () {
      expect(functionSource, contains('include_recent_form'));
      expect(functionSource, contains('include_expected_goals'));
      expect(functionSource, contains('endpoint: "/fixtures/statistics"'));
      expect(functionSource, contains('recentFixtureIdsForTeam'));
      expect(functionSource, contains('["FT", "AET", "PEN"]'));
      expect(
        functionSource,
        isNot(contains('endpoint: "/predictions"')),
        reason: 'Predictions remain out of this factual pre-match collection.',
      );
    });

    test('documents required secrets without leaking values', () {
      for (final key in [
        'API_FOOTBALL_KEY=',
        'API_FOOTBALL_SYNC_SECRET=',
        'SUPABASE_URL=',
        'SUPABASE_ANON_KEY=',
        'SUPABASE_SERVICE_ROLE_KEY=',
      ]) {
        expect(envExample, contains(key));
      }

      expect(envExample, isNot(contains('eyJ')));
    });
  });
}

String _tableBlock(String sql, String table) {
  final start = sql.indexOf('create table public.$table');
  expect(start, isNot(-1), reason: '$table table not found');
  final next = sql.indexOf('\ncreate table public.', start + 1);
  return sql.substring(start, next == -1 ? sql.length : next);
}
