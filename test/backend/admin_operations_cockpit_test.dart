import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Admin operations cockpit', () {
    late String migration;
    late String previewLinksMigration;
    late String function;
    late String repository;

    setUpAll(() {
      migration = File(
        'supabase/migrations/20260816153000_admin_operations_cockpit.sql',
      ).readAsStringSync();
      previewLinksMigration = File(
        'supabase/migrations/20260816170000_admin_preview_links.sql',
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

    test('creates hashed one-hour tester links without exposing tokens', () {
      expect(
        previewLinksMigration,
        contains('create table public.admin_preview_links'),
      );
      expect(
        previewLinksMigration,
        contains('token_hash text not null unique'),
      );
      expect(previewLinksMigration, isNot(contains(' token text')));
      expect(previewLinksMigration, contains('from anon, authenticated'));
      expect(previewLinksMigration, contains('to service_role'));
      expect(function, contains('action === "create_test_link"'));
      expect(function, contains('sha256Hex(token)'));
      expect(function, contains('duration_minutes'));
      expect(function, contains('tester_token'));
    });

    test(
      'redeems tester links without admin bearer but never creates them',
      () {
        expect(function, contains('action === "redeem_test_link"'));
        expect(function, contains('Temporary tester link has expired.'));
        expect(function, contains('Temporary tester link is invalid.'));
        expect(
          function.indexOf('action === "redeem_test_link"'),
          lessThan(function.indexOf('const admin = await authorizeAdmin')),
        );
        expect(
          function.indexOf('action === "create_test_link"'),
          greaterThan(function.indexOf('const admin = await authorizeAdmin')),
        );
      },
    );

    test('front calls admin-ops with the current user token only', () {
      expect(
        repository,
        contains("_client.functions.invoke(\n      'admin-ops'"),
      );
      expect(repository, contains('_client.auth.currentSession?.accessToken'));
      expect(repository, contains("'action': 'create_test_link'"));
      expect(repository, isNot(contains('SUPABASE_SERVICE_ROLE_KEY')));
      expect(repository, isNot(contains('API_FOOTBALL_SYNC_SECRET')));
    });
  });
}
