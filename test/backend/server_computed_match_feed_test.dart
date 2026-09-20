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
    expect(analyzer, contains('const presentationHeadToHead'));
    expect(analyzer, contains('standings: presentationStandings'));
    expect(
      analyzer,
      contains('recent_league_matches: presentationRecentMatches'),
    );
    expect(analyzer, contains('head_to_head: presentationHeadToHead'));
    expect(analyzer, contains('function compactHeadToHead'));
    expect(analyzer, contains('computed: {'));
    expect(analyzer, contains(r'fixture_id=in.(${'));
    expect(analyzer, contains('fixtureIds.join(",")'));
  });

  test('keeps direct confrontations cache-backed and scoped per fixture', () {
    final sync = File(
      'supabase/functions/api-football-sync/index.ts',
    ).readAsStringSync();
    final snapshot = File(
      'supabase/functions/build-match-feed-snapshot/index.ts',
    ).readAsStringSync();

    expect(sync, contains('endpoint: "/fixtures/headtohead"'));
    expect(sync, contains('upcomingHeadToHeadPairs'));
    expect(sync, contains('ttlSeconds: 30 * 24 * 60 * 60'));
    expect(snapshot, contains('endpoint: "/fixtures/headtohead"'));
    expect(snapshot, contains('headToHeadRequests'));
    expect(snapshot, contains('head_to_head: build.rawHeadToHead'));
  });

  test('publishes server-computed Tier assignments with every fixture', () {
    final analyzer = File(
      'supabase/functions/analyze-match-feed-snapshot/index.ts',
    ).readAsStringSync();

    expect(analyzer, contains('const tiersByLeagueId = buildTierSnapshots'));
    expect(analyzer, contains('tier_snapshot:'));
    expect(analyzer, contains('function buildTierSnapshot'));
    expect(analyzer, contains('medianPlayed < 5'));
    expect(analyzer, contains('officialRelegationStart'));
    expect(analyzer, contains('selectTierBoundaries'));
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
    'derives decisive-player profiles from actual minutes over three matches',
    () {
      final snapshot = File(
        'supabase/functions/build-match-feed-snapshot/index.ts',
      ).readAsStringSync();
      final sync = File(
        'supabase/functions/api-football-sync/index.ts',
      ).readAsStringSync();
      final publisher = File(
        'supabase/functions/publish-reading-announcements/index.ts',
      ).readAsStringSync();

      expect(snapshot, contains('player_recent_contributions'));
      expect(snapshot, contains('playerRecentContributionSnapshots'));
      expect(snapshot, contains('player_recent_performances'));
      expect(snapshot, contains('playerRecentPerformanceSnapshots'));
      expect(snapshot, contains('fixtures_with_player_statistics'));
      expect(snapshot, contains('substitute_appearances'));
      expect(sync, contains('endpoint: "/fixtures/players"'));
      expect(sync, contains('includeRecentPlayerPerformances'));
      expect(sync, contains('ttlSeconds: 30 * 24 * 60 * 60'));
      expect(publisher, contains('matchesWithContribution < 2'));
      expect(publisher, contains('contributions * 90 / minutes'));
      expect(publisher, contains('recentRate < 0.8'));
      expect(publisher, contains('substituteAppearances * 2 >'));
      expect(publisher, contains('server_recent_player_profile_v3'));
      expect(publisher, contains('player_photo_url'));
      expect(publisher, contains('Joueur décisif à surveiller'));
      expect(publisher, contains('profile_label'));
      expect(publisher, contains('is_super_sub'));
      expect(publisher, contains('player_rank: profileIndex + 1'));
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
      'supabase/migrations/20260919050000_recent_decisive_player_window.sql',
    ).readAsStringSync();

    expect(migration, contains('where kickoff_at > now()'));
    expect(migration, contains("'standout_decisive_player'"));
    expect(migration, contains("'key_player_unavailable'"));
    expect(migration, isNot(contains('match_result_snapshots')));
  });

  test('derives form and trajectory readings from one five-match window', () {
    final publisher = File(
      'supabase/functions/publish-reading-announcements/index.ts',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/20260920030000_form_window_trajectory_v2.sql',
    ).readAsStringSync();

    expect(publisher, contains('.slice(0, 5)'));
    expect(publisher, contains('if (results.length === 5)'));
    expect(publisher, contains('const recentAverage'));
    expect(publisher, contains('const earlierAverage'));
    expect(publisher, contains(r'contre ${'));
    expect(publisher, contains('/15 sur les cinq derniers matchs'));
    expect(publisher, contains('Trajectoire en baisse'));
    expect(publisher, contains('label: "Méforme"'));
    expect(migration, contains('where kickoff_at > now()'));
    for (final readingId in const [
      'positive_streak',
      'negative_streak',
      'improving_form',
      'declining_form',
      'form_advantage',
    ]) {
      expect(migration, contains("'$readingId'"));
    }
    expect(migration, isNot(contains('match_result_snapshots')));
  });

  test('locks form-gap and TAT dominance to their server policy modules', () {
    final publisher = File(
      'supabase/functions/publish-reading-announcements/index.ts',
    ).readAsStringSync();
    final formPolicy = File(
      'supabase/functions/_shared/form_gap_policy.ts',
    ).readAsStringSync();
    final headToHeadPolicy = File(
      'supabase/functions/_shared/head_to_head_dominance_policy.ts',
    ).readAsStringSync();

    expect(publisher, contains('assessFormGap'));
    expect(publisher, contains('readingId: "form_gap"'));
    expect(publisher, contains('formGap.gap'));
    expect(publisher, contains('headToHeadDominanceAnnouncementRows'));
    expect(publisher, contains('readingId: "head_to_head_dominance"'));
    expect(publisher, contains('headToHeadMeetingsByFixtureId'));
    expect(formPolicy, contains('gap < 9'));
    expect(formPolicy, contains('homeResults.length !== 5'));
    expect(headToHeadPolicy, contains('.slice(0, 6)'));
    expect(headToHeadPolicy, contains('if (scoped.length !== 6) return []'));
    expect(
      headToHeadPolicy,
      contains('meeting.competitionId === competitionId'),
    );
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
