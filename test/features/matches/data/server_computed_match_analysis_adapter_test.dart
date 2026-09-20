import 'package:copilot/features/matches/data/server_computed_match_analysis_adapter.dart';
import 'package:copilot/features/matches/domain/football_reading.dart';
import 'package:copilot/features/matches/domain/structural_tiers/tier_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decodes server readings and scenarios without a football analyzer', () {
    final decoded = const ServerComputedMatchAnalysisAdapter().fromSnapshot({
      'captured_at': '2026-09-18T06:00:00Z',
      'computed': {
        'fixtures': [
          {
            'fixture_id': 42,
            'readings': [
              {
                'id': 'positive_streak',
                'label': 'Dynamique positive',
                'side': 'home',
                'subject_team_id': 'api-team-7',
                'sample_size': 3,
                'player_id': 278,
                'player_name': 'Kylian Mbappé',
                'evidence': [
                  {
                    'label': 'Série positive.',
                    'source_path': 'server.form',
                    'value': {
                      'player_photo_url':
                          'https://media.api-sports.io/football/players/278.png',
                    },
                  },
                ],
              },
              {
                'id': 'misleading_result',
                'side': 'home',
                'subject_team_id': 'api-team-7',
                'is_contradiction': true,
                'evidence': [
                  {'label': 'Résultat à nuancer.', 'source_path': 'server.xg'},
                ],
              },
            ],
            'scenarios': [
              {
                'id': 'solid_favorite',
                'side': 'home',
                'subject_team_id': 'api-team-7',
                'required_reading_ids': ['positive_streak'],
              },
            ],
            'tier_snapshot': {
              'competition_id': '61',
              'season': 2026,
              'analysis_as_of': '2026-09-18T06:00:00Z',
              'tier_system_version': 'tier-server-v1',
              'standings_snapshot_identity': 'server-tier-test',
              'status': 'immature',
              'maturity': 'immature',
              'team_count': 10,
              'confirmed_boundaries': [
                {
                  'boundary_index': 5,
                  'upper_rank': 5,
                  'lower_rank': 6,
                  'raw_gap': 4,
                  'score': 81,
                  'strength': 'strong',
                },
              ],
              'tier_partition_boundaries': [
                {'boundary_index': 5, 'score': 81, 'strength': 'strong'},
              ],
              'team_assignments': [
                {
                  'team_id': 7,
                  'team_name': 'Paris FC',
                  'rank': 2,
                  'points': 13,
                  'played': 5,
                  'points_per_game': 2.6,
                  'assigned_tier': 'TIER_1',
                },
                {
                  'team_id': 8,
                  'team_name': 'Lens',
                  'rank': 8,
                  'points': 4,
                  'played': 5,
                  'points_per_game': 0.8,
                  'assigned_tier': 'TIER_5',
                },
              ],
            },
          },
        ],
      },
    });

    final analysis = decoded['api-fixture-42'];
    expect(analysis, isNotNull);
    expect(analysis!.analysis.supportingReadings.single.id, 'positive_streak');
    expect(
      analysis.analysis.contradictoryReadings.single.id,
      'misleading_result',
    );
    expect(
      analysis.analysis.contradictoryReadings.single.status,
      ReadingStatus.detected,
    );
    expect(
      analysis.scenarios.single.supportingReadings.single.id,
      'positive_streak',
    );
    expect(analysis.displayReadings, hasLength(2));
    expect(analysis.displayReadings.first.evidenceLabel, 'Série positive.');
    expect(analysis.displayReadings.first.label, 'Dynamique positive');
    expect(
      analysis.displayReadings.first.playerPhotoUrl,
      'https://media.api-sports.io/football/players/278.png',
    );
    expect(analysis.championshipTierSnapshot, isNotNull);
    expect(analysis.championshipTierSnapshot!.teamAssignments, hasLength(2));
    expect(
      analysis.championshipTierSnapshot!.assignmentForTeam(7)!.assignedTier,
      TierLabel.tier1Podium,
    );
    expect(
      analysis
          .championshipTierSnapshot!
          .confirmedStructuralBoundaries
          .single
          .boundaryIndex,
      5,
    );
  });
}
