import 'dart:convert';
import 'dart:io';
import 'package:copilot/core/domain/lector_head_to_head_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'client and collector share verified phase scenarios, including legacy NHL preseason',
    () {
      final cases =
          jsonDecode(
                File(
                  'test/fixtures/sports/hockey_meeting_phases.json',
                ).readAsStringSync(),
              )
              as List;
      for (final c in cases) {
        expect(
          LectorHeadToHeadPolicy.classifyHockey(
            name: c['name'] as String,
            competitionId: c['id'] as String,
            playedAt: DateTime.parse(c['date'] as String),
            phase: c['phase'] as String?,
            declaredKind: LectorMeetingKind.values.byName(
              c['declared'] as String,
            ),
          ).name,
          c['expected'],
          reason: c.toString(),
        );
      }
    },
  );
}
