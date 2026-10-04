import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps the raw-to-public snapshot chain readable by the Flutter client', () {
    final migration = File(
      'supabase/migrations/20260918110000_server_computed_match_feed.sql',
    ).readAsStringSync();
    final repairMigration = File(
      'supabase/migrations/20261003140000_restore_public_compact_match_feed.sql',
    ).readAsStringSync();
    final daily = File(
      'supabase/functions/daily-football-sync/index.ts',
    ).readAsStringSync();
    final analyzer = File(
      'supabase/functions/analyze-match-feed-snapshot/index.ts',
    ).readAsStringSync();
    final client = File(
      'lib/features/matches/data/supabase_match_feed_snapshot_repository.dart',
    ).readAsStringSync();
    final loader = File(
      'lib/features/matches/data/match_feed_repository_loader.dart',
    ).readAsStringSync();

    // The compact table is intentionally the only public mobile read model.
    // The provider cache and raw snapshot are not part of the client query.
    expect(
      migration,
      contains(
        'grant select on public.match_feed_analysis_snapshots to anon, authenticated;',
      ),
    );
    expect(migration, contains('match_feed_analysis_snapshots_public_select'));
    expect(migration, contains('using (true)'));
    expect(repairMigration, contains('enable row level security'));
    expect(repairMigration, contains('force row level security'));
    expect(
      repairMigration,
      contains(
        'drop policy if exists match_feed_analysis_snapshots_public_select',
      ),
    );
    expect(repairMigration, contains('to anon, authenticated'));

    // Every collected raw snapshot must be materialised before the run can
    // complete. An empty but verified fixture collection follows the same
    // path and becomes an empty client feed rather than an old fallback.
    expect(
      daily.indexOf('name: "build-match-feed-snapshot"'),
      lessThan(daily.indexOf('name: "analyze-match-feed-snapshot"')),
    );
    expect(daily, isNot(contains('skipped: "no_upcoming_fixtures"')));
    expect(analyzer, contains('source_snapshot_id: snapshotId'));
    expect(
      analyzer,
      contains('path: "/rest/v1/match_feed_analysis_snapshots"'),
    );
    expect(analyzer, contains('payload: compactPayload'));

    // This is the exact relation and payload used by the Flutter reader.
    expect(client, contains(".from('match_feed_analysis_snapshots')"));
    expect(client, contains(".select('id,scope,league_ids,payload')"));
    expect(loader, contains('EmptyMatchFeedRepository'));
    expect(loader, isNot(contains('localSnapshotAsset')));
  });
}
