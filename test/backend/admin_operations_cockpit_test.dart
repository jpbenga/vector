import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Admin operations cockpit', () {
    late String migration;
    late String function;
    late String repository;

    setUpAll(() {
      migration = File(
        'supabase/migrations/20260816153000_admin_operations_cockpit.sql',
      ).readAsStringSync();
      function = File(
        'supabase/functions/admin-ops/index.ts',
      ).readAsStringSync();
      repository = File(
        'lib/features/admin/data/admin_ops_repository.dart',
      ).readAsStringSync();
    });

    test('exposes curated cron views without leaking command secrets', () {
      expect(
        migration,
        contains('create or replace view public.admin_cron_jobs'),
      );
      expect(
        migration,
        contains('create or replace view public.admin_cron_job_runs'),
      );
      expect(migration, contains('Intentionally excludes command text'));
      expect(migration, isNot(contains('job.command')));
      expect(migration, isNot(contains('details.command')));
      expect(migration, contains('grant select on public.admin_cron_jobs'));
      expect(migration, contains('to service_role'));
      expect(migration, contains('from anon, authenticated'));
    });

    test('requires an authenticated allow-listed admin email', () {
      expect(function, contains('ADMIN_EMAILS'));
      expect(function, contains('/auth/v1/user'));
      expect(function, contains('Admin access denied.'));
      expect(function, contains('Missing bearer token.'));
    });

    test('relays manual league reruns through server-side functions', () {
      expect(function, contains('action === "rerun_league"'));
      expect(function, contains('api-football-sync'));
      expect(function, contains('build-match-feed-snapshot'));
      expect(function, contains('API_FOOTBALL_SYNC_SECRET'));
      expect(function, contains('admin_operation_runs'));
    });

    test('front calls admin-ops with the current user token only', () {
      expect(
        repository,
        contains("_client.functions.invoke(\n      'admin-ops'"),
      );
      expect(repository, contains('_client.auth.currentSession?.accessToken'));
      expect(repository, isNot(contains('SUPABASE_SERVICE_ROLE_KEY')));
      expect(repository, isNot(contains('API_FOOTBALL_SYNC_SECRET')));
    });
  });
}
