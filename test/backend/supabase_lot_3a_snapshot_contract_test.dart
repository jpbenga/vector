import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Supabase Lot 3A match feed snapshot contract', () {
    late String migration;
    late String docs;

    setUpAll(() {
      migration = File(
        'supabase/migrations/20260811113000_backend_lot_3a_match_feed_snapshots.sql',
      ).readAsStringSync();
      docs = File(
        'docs/backend-lot-3a-snapshot-contract.md',
      ).readAsStringSync();
    });

    test('creates the immutable snapshot read-model tables', () {
      for (final table in [
        'match_feed_snapshots',
        'match_feed_snapshot_fixtures',
        'match_feed_snapshot_sources',
      ]) {
        expect(
          migration,
          contains('create table public.$table'),
          reason: '$table must be part of the Lot 3A read model',
        );
      }

      expect(
        migration,
        contains("kind text not null default 'pre_match_feed'"),
      );
    });

    test(
      'keeps the main payload compatible with the local V1 adapter contract',
      () {
        final snapshots = _tableBlock(migration, 'match_feed_snapshots');

        for (final requiredPayloadKey in [
          'schema_version',
          'source',
          'captured_at',
          'timezone',
          'window_start',
          'window_end',
          'date_window',
          'raw',
        ]) {
          expect(
            snapshots,
            contains("check (payload ? '$requiredPayloadKey')"),
            reason:
                'match_feed_snapshots.payload must keep $requiredPayloadKey for ApiFootballMatchAdapter',
          );
        }

        expect(docs, contains('"raw": {'));
        for (final rawKey in [
          'fixtures',
          'odds',
          'standings',
          'team_statistics',
          'recent_league_matches',
          'expected_goals',
          'predictions',
        ]) {
          expect(docs, contains('"$rawKey"'));
        }
      },
    );

    test('stores freshness, coverage and provenance metadata', () {
      final snapshots = _tableBlock(migration, 'match_feed_snapshots');

      for (final column in [
        'captured_at timestamptz not null',
        'as_of timestamptz not null',
        'snapshot_created_at timestamptz not null default now()',
        'coverage_summary jsonb not null',
        'provenance jsonb not null',
        'source_sync_run_ids uuid[] not null',
      ]) {
        expect(snapshots, contains(column));
      }

      expect(
        snapshots,
        contains(
          'source,\n'
          '    schema_version,\n'
          '    season,\n'
          '    timezone,\n'
          '    window_start,\n'
          '    window_end,\n'
          '    as_of',
        ),
        reason: 'the snapshot identity must allow versioned immutable windows',
      );
    });

    test('indexes fixtures for day league and team browsing', () {
      final fixtures = _tableBlock(migration, 'match_feed_snapshot_fixtures');

      for (final column in [
        'fixture_date date not null',
        'kickoff_at timestamptz',
        'api_football_fixture_id integer',
        'api_football_league_id integer',
        'competition_name text not null',
        'home_team_name text not null',
        'away_team_name text not null',
        'has_odds boolean not null default false',
        'has_standings boolean not null default false',
        'has_team_statistics boolean not null default false',
        'has_recent_form boolean not null default false',
        'has_expected_goals boolean not null default false',
      ]) {
        expect(fixtures, contains(column));
      }

      expect(
        migration,
        contains('create index match_feed_snapshot_fixtures_date_idx'),
      );
      expect(
        migration,
        contains('create index match_feed_snapshot_fixtures_league_date_idx'),
      );
    });

    test('links every snapshot to raw Lot 2 cache provenance', () {
      final sources = _tableBlock(migration, 'match_feed_snapshot_sources');

      expect(sources, contains('endpoint text not null'));
      expect(sources, contains('query_hash text not null'));
      expect(
        sources,
        contains(
          'sync_run_id uuid references public.api_football_sync_runs(id)',
        ),
      );
      expect(
        sources,
        contains('references public.api_football_cached_responses'),
      );
      expect(
        sources,
        contains(
          'source,\n'
          '      endpoint,\n'
          '      query_hash',
        ),
      );
      expect(sources, contains('response_status integer not null'));
    });

    test('enforces append-only semantics with mutation blockers', () {
      expect(
        migration,
        contains('create or replace function public.prevent_snapshot_mutation'),
      );

      for (final table in [
        'match_feed_snapshots',
        'match_feed_snapshot_fixtures',
        'match_feed_snapshot_sources',
      ]) {
        expect(
          migration,
          contains('before update on public.$table'),
          reason: '$table must reject updates',
        );
        expect(
          migration,
          contains('before delete on public.$table'),
          reason: '$table must reject deletes',
        );
      }
    });

    test('exposes snapshots as read-only public product data', () {
      for (final table in [
        'match_feed_snapshots',
        'match_feed_snapshot_fixtures',
        'match_feed_snapshot_sources',
      ]) {
        expect(
          migration,
          contains('alter table public.$table enable row level security;'),
        );
        expect(
          migration,
          contains('alter table public.$table force row level security;'),
        );
        expect(
          migration,
          contains('revoke insert, update, delete on table public.$table'),
        );
        expect(migration, contains('grant select on table public.$table'));
      }

      for (final policy in [
        'match_feed_snapshots_select_public',
        'match_feed_snapshot_fixtures_select_public',
        'match_feed_snapshot_sources_select_public',
      ]) {
        expect(migration, contains('create policy "$policy"'));
        expect(migration, contains('to anon, authenticated'));
        expect(migration, contains('using (true)'));
      }
    });

    test('documents the Lot 3B transformation boundary', () {
      expect(docs, contains('api_football_cached_responses'));
      expect(docs, contains('transformation serveur Lot 3B'));
      expect(docs, contains('ApiFootballMatchAdapter'));
      expect(docs, contains('aucune mutation retroactive'));
      expect(docs, contains('aucune substitution silencieuse de bookmaker'));
    });
  });
}

String _tableBlock(String sql, String table) {
  final start = sql.indexOf('create table public.$table');
  expect(start, isNot(-1), reason: '$table table not found');
  final next = sql.indexOf('\ncreate table public.', start + 1);
  return sql.substring(start, next == -1 ? sql.length : next);
}
