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

  test('normalizes every optional announcement column before bulk insert', () {
    final publisher = File(
      'supabase/functions/publish-reading-announcements/index.ts',
    ).readAsStringSync();

    expect(publisher, contains('announcement_kind: row.announcement_kind'));
    expect(
      publisher,
      contains('parent_announcement_key: row.parent_announcement_key'),
    );
    expect(
      publisher,
      contains('required_reading_ids: row.required_reading_ids ?? []'),
    );
  });

  test(
    'materializes every scenario contract from server-computed readings',
    () {
      final publisher = File(
        'supabase/functions/publish-reading-announcements/index.ts',
      ).readAsStringSync();

      expect(
        publisher,
        contains('const scenarioContracts: ScenarioContract[]'),
      );
      for (final scenarioId in const [
        'solid_favorite',
        'struggling_team',
        'offensive_match',
        'defensive_match',
        'ranking_gap',
        'credible_outsider',
        'fragile_defense',
        'prolific_attack',
        'positive_series',
        'negative_series',
        'corner_pressure',
        'disciplinary_tension',
      ]) {
        expect(publisher, contains('id: "$scenarioId"'));
      }
      expect(publisher, contains('scenarioTechnicalSupportAnnouncementRows'));
      expect(publisher, contains('high_xg_creation'));
      expect(publisher, contains('high_shots_on_target_conceded'));
      expect(publisher, contains('high_corner_creation'));
      expect(publisher, contains('high_card_rate'));
    },
  );

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
