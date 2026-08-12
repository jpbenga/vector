import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Supabase Lot 1A migration', () {
    late String sql;

    setUpAll(() {
      sql = File(
        'supabase/migrations/20260809224753_init_backend_lot_1a.sql',
      ).readAsStringSync();
    });

    test('creates the expected user-owned product tables', () {
      for (final table in _userOwnedTables) {
        expect(
          sql,
          contains('create table public.$table'),
          reason: '$table must be created by the Lot 1A migration',
        );
      }
    });

    test('links every user-owned table to auth.users', () {
      final expectedReferences = {
        'user_profiles': 'id uuid primary key references auth.users(id)',
        'profiles': 'user_id uuid not null references auth.users(id)',
        'ticket_strategies': 'user_id uuid not null references auth.users(id)',
        'match_favorites': 'user_id uuid not null references auth.users(id)',
        'saved_tickets': 'user_id uuid not null references auth.users(id)',
        'saved_ticket_selections':
            'user_id uuid not null references auth.users(id)',
      };

      for (final entry in expectedReferences.entries) {
        expect(
          _tableBlock(sql, entry.key),
          contains(entry.value),
          reason: '${entry.key} must be directly owned by auth.users',
        );
      }
    });

    test('enables and forces RLS on every user-owned table', () {
      for (final table in _userOwnedTables) {
        expect(
          sql,
          contains('alter table public.$table enable row level security;'),
          reason: '$table must enable RLS',
        );
        expect(
          sql,
          contains('alter table public.$table force row level security;'),
          reason: '$table must force RLS',
        );
      }
    });

    test('defines auth.uid policies for every mutable table', () {
      final expectedPolicyCounts = {
        'user_profiles': 4,
        'profiles': 4,
        'ticket_strategies': 4,
        'match_favorites': 3,
        'saved_tickets': 4,
        'saved_ticket_selections': 4,
      };

      for (final entry in expectedPolicyCounts.entries) {
        final policyCount = RegExp(
          'create policy "[^"]+"\\s+on public\\.${entry.key}',
          multiLine: true,
        ).allMatches(sql).length;
        expect(
          policyCount,
          entry.value,
          reason: '${entry.key} has an unexpected policy count',
        );
      }

      expect(
        RegExp(r'auth\.uid\(\)').allMatches(sql).length,
        greaterThanOrEqualTo(20),
        reason: 'RLS policies must be based on auth.uid()',
      );
    });

    test('keeps TicketStrategy constraints aligned with the Dart contract', () {
      final table = _tableBlock(sql, 'ticket_strategies');

      expect(table, contains('schema_version integer not null default 2'));
      expect(
        table,
        contains("pick_types text[] not null default '{}'::text[]"),
      );
      expect(table, contains("array['prudent', 'normal', 'audacious']"));
      expect(table, contains('minimum_individual_odds numeric(8, 2)'));
      expect(table, contains('minimum_individual_odds >= 1.01'));
      expect(
        table,
        contains('maximum_individual_odds >= minimum_individual_odds'),
      );
      expect(table, contains('minimum_selections > 0'));
      expect(table, contains('maximum_selections >= minimum_selections'));
      expect(table, contains('minimum_total_odds >= 1'));
      expect(table, contains('maximum_total_odds >= minimum_total_odds'));
      expect(table, contains('primary key (user_id, id)'));
    });

    test(
      'keeps SavedTicket enums and selections aligned with the Dart contract',
      () {
        final tickets = _tableBlock(sql, 'saved_tickets');
        final selections = _tableBlock(sql, 'saved_ticket_selections');

        expect(
          tickets,
          contains("source in ('copilot', 'copilotModified', 'manual')"),
        );
        expect(
          tickets,
          contains("status in ('saved', 'played', 'won', 'lost', 'cancelled')"),
        );
        expect(tickets, contains('opportunity_ids text[]'));
        expect(tickets, contains('modification_details text[]'));
        expect(tickets, contains('played_actual_total_odds'));

        expect(selections, contains('foreign key (user_id, ticket_id)'));
        expect(selections, contains('unique (user_id, ticket_id, position)'));
        expect(selections, contains('unique (user_id, ticket_id, match_id)'));
        expect(selections, contains('odds numeric(8, 2) not null'));
      },
    );

    test('stores both raw and compiled decision profile payloads', () {
      final table = _tableBlock(sql, 'profiles');

      expect(table, contains('decision_profile jsonb'));
      expect(table, contains('compiled_profile jsonb not null'));
    });

    test('does not introduce sports data ingestion in Lot 1A', () {
      final forbidden = [
        'api_football',
        'fixtures',
        'standings',
        'bookmakers',
        'odds_snapshots',
        'match_snapshots',
        'sync_jobs',
      ];

      for (final token in forbidden) {
        expect(
          sql.toLowerCase(),
          isNot(contains('create table public.$token')),
          reason: 'Lot 1A must not create sports ingestion table $token',
        );
      }
    });
  });
}

const _userOwnedTables = [
  'user_profiles',
  'profiles',
  'ticket_strategies',
  'match_favorites',
  'saved_tickets',
  'saved_ticket_selections',
];

String _tableBlock(String sql, String table) {
  final start = sql.indexOf('create table public.$table');
  expect(start, isNot(-1), reason: '$table table not found');
  final next = sql.indexOf('\ncreate table public.', start + 1);
  return sql.substring(start, next == -1 ? sql.length : next);
}
