import 'package:flutter_test/flutter_test.dart';

import '../../tool/publish_match_reading_announcements.dart' as publisher;

void main() {
  test('uses the latest snapshot strictly before each kickoff', () {
    final chosen = publisher.selectPreKickoffSnapshots(
      metadata: [
        {'id': 'early', 'captured_at': '2026-09-16T10:00:00Z'},
        {'id': 'latest-valid', 'captured_at': '2026-09-16T16:00:00Z'},
        {'id': 'at-kickoff', 'captured_at': '2026-09-16T18:00:00Z'},
        {'id': 'after', 'captured_at': '2026-09-16T19:00:00Z'},
      ],
      fixtureIndex: [
        for (final snapshot in ['early', 'latest-valid', 'at-kickoff', 'after'])
          {
            'snapshot_id': snapshot,
            'api_football_fixture_id': 101,
            'kickoff_at': '2026-09-16T18:00:00Z',
          },
        {
          'snapshot_id': 'after',
          'api_football_fixture_id': 102,
          'kickoff_at': '2026-09-16T20:00:00Z',
        },
      ],
    );

    expect(chosen[101], 'latest-valid');
    expect(chosen[102], 'after');
  });
}
