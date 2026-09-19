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
    expect(analyzer, contains('const presentationStandings'));
    expect(analyzer, contains('const presentationRecentMatches'));
    expect(analyzer, contains('standings: presentationStandings'));
    expect(
      analyzer,
      contains('recent_league_matches: presentationRecentMatches'),
    );
    expect(analyzer, contains('computed: {'));
    expect(analyzer, contains(r'fixture_id=in.(${'));
    expect(analyzer, contains('fixtureIds.join(",")'));
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

  test(
    'derives recent player contributions before the public compact feed',
    () {
      final snapshot = File(
        'supabase/functions/build-match-feed-snapshot/index.ts',
      ).readAsStringSync();
      final publisher = File(
        'supabase/functions/publish-reading-announcements/index.ts',
      ).readAsStringSync();

      expect(snapshot, contains('player_recent_contributions'));
      expect(snapshot, contains('playerRecentContributionSnapshots'));
      expect(snapshot, contains('matches_with_contribution'));
      expect(publisher, contains('recent.matchesWithContribution < 2'));
      expect(publisher, contains('minutes + 270'));
      expect(publisher, contains('player_photo_url'));
      expect(publisher, contains('Joueur décisif à surveiller'));
      expect(publisher, contains('profile_label'));
      expect(publisher, contains('is_super_sub'));
    },
  );

  test('keeps statistical projections out of published Lector readings', () {
    final publisher = File(
      'supabase/functions/publish-reading-announcements/index.ts',
    ).readAsStringSync();
    final baseStart = publisher.indexOf('const baseAnnouncements = [');
    final baseEnd = publisher.indexOf(
      'const hiddenPreMatchStatisticalReadingIds',
    );
    final base = publisher.substring(baseStart, baseEnd);

    expect(base, isNot(contains('technicalProjectionAnnouncements')));
    for (final readingId in const [
      'high_shot_volume',
      'high_shots_on_target',
      'high_shots_on_target_conceded',
      'high_corner_creation',
      'high_corners_conceded',
      'high_card_rate',
      'high_total_cards_profile',
    ]) {
      expect(publisher, contains('"$readingId"'));
    }
  });

  test('refreshes only future decisive-player announcements', () {
    final migration = File(
      'supabase/migrations/20260919043000_decisive_player_v2.sql',
    ).readAsStringSync();

    expect(migration, contains('where kickoff_at > now()'));
    expect(migration, contains("'standout_decisive_player'"));
    expect(migration, contains("'key_player_unavailable'"));
    expect(migration, isNot(contains('match_result_snapshots')));
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
    expect(publisher, contains('player_name: row.player_name ?? null'));
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
      ]) {
        expect(publisher, contains('id: "$scenarioId"'));
      }
      expect(publisher, contains('scenarioTechnicalSupportAnnouncementRows'));
      expect(publisher, contains('high_xg_creation'));
      expect(publisher, contains('hiddenPreMatchStatisticalReadingIds'));
    },
  );

  test(
    'uses an adaptive structural-gap policy before the table stabilizes',
    () {
      final publisher = File(
        'supabase/functions/publish-reading-announcements/index.ts',
      ).readAsStringSync();
      final policy = File(
        'supabase/functions/_shared/structural_gap_policy.ts',
      ).readAsStringSync();

      expect(publisher, contains('assessStructuralGap'));
      expect(publisher, contains('Écart de hiérarchie précoce'));
      expect(policy, contains('comparedMatches < 5'));
      expect(policy, contains('opponent.rank - superior.rank < 6'));
      expect(policy, contains('if (comparedMatches <= 6) return 1.0'));
      expect(policy, contains('if (comparedMatches === 11) return 0.5'));
      expect(policy, contains('return 0.4'));
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
