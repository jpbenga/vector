import 'package:copilot/features/matches/data/server_computed_match_analysis_adapter.dart';
import 'package:copilot/features/matches/domain/football_reading.dart';
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
                'side': 'home',
                'subject_team_id': 'api-team-7',
                'sample_size': 3,
                'evidence': [
                  {'label': 'Série positive.', 'source_path': 'server.form'},
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
          },
        ],
      },
    });

    final analysis = decoded['api-fixture-42'];
    expect(analysis, isNotNull);
    expect(analysis!.analysis.readings.single.id, 'positive_streak');
    expect(analysis.analysis.readings.single.status, ReadingStatus.detected);
    expect(
      analysis.scenarios.single.supportingReadings.single.id,
      'positive_streak',
    );
  });
}
