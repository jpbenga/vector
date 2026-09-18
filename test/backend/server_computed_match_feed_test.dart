import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('publishes a compact computed feed after the private raw snapshot', () {
    final migration = File(
      'supabase/migrations/20260918110000_server_computed_match_feed.sql',
    ).readAsStringSync();
    final daily = File(
      'supabase/functions/daily-football-sync/index.ts',
    ).readAsStringSync();
    final analyzer = File(
      'supabase/functions/analyze-match-feed-snapshot/index.ts',
    ).readAsStringSync();

    expect(
      migration,
      contains('create table public.match_feed_analysis_snapshots'),
    );
    expect(migration, contains('source_snapshot_id uuid not null unique'));
    expect(migration, contains("check (payload ? 'computed')"));
    expect(daily, contains('name: "analyze-match-feed-snapshot"'));
    expect(analyzer, contains('name: "publish-reading-announcements"'));
    expect(analyzer, contains('raw: { fixtures, odds }'));
    expect(analyzer, contains('computed: {'));
    expect(analyzer, contains(r'fixture_id=in.(${fixtureIds.join(",")})'));
  });

  test('keeps detailed final provider calls limited to announced fixtures', () {
    final results = File(
      'supabase/functions/sync-match-results/index.ts',
    ).readAsStringSync();

    expect(results, contains('announcedFixtureIdsFor'));
    expect(results, contains('announcedFixtureIds.has(fixtureId)'));
    expect(results, contains('completedFixtureEnrichment'));
    expect(results, contains('player_decisive'));
  });

  test('evaluates server reading contracts and nuances in the database', () {
    final migration = File(
      'supabase/migrations/20260918113000_bilan_reading_outcomes_and_nuances.sql',
    ).readAsStringSync();

    expect(migration, contains("'team_scores'"));
    expect(migration, contains("'first_half_scores'"));
    expect(migration, contains("'second_half_concedes'"));
    expect(migration, contains("'caution_confirmed'"));
    expect(migration, contains('parent_announcement_key'));
  });
}
