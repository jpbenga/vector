import 'package:copilot/app/theme/app_theme.dart';
import 'package:copilot/core/domain/lector_head_to_head_policy.dart';
import 'package:copilot/core/widgets/lector_head_to_head_data.dart';
import 'package:copilot/core/widgets/lector_head_to_head_timeline_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

LectorHeadToHeadMeeting meeting(
  String id,
  String name,
  LectorMeetingKind kind,
) => LectorHeadToHeadMeeting(
  competitionId: id,
  competitionName: name,
  competitionKind: kind,
  fixtureId: id,
  playedAt: DateTime.utc(2026, 9, 20),
  homeTeamId: '1',
  homeTeamName: 'Atlas',
  awayTeamId: '2',
  awayTeamName: 'Rivage',
  homeGoals: 3,
  awayGoals: 1,
);
void main() {
  setUpAll(() => initializeDateFormatting('fr'));
  testWidgets(
    'common confrontation component separates cups and league at mobile width',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: SingleChildScrollView(
              child: LectorHeadToHeadTimelinePanel(
                data: LectorHeadToHeadData(
                  competitionId: '35',
                  firstTeamId: '1',
                  secondTeamId: '2',
                  firstTeamName: 'Atlas',
                  secondTeamName: 'Rivage',
                  emptyDescription: 'Empty',
                  meetings: [
                    meeting('35', 'KHL', LectorMeetingKind.league),
                    meeting('99', 'National Cup', LectorMeetingKind.cup),
                    meeting('100', 'Exhibition', LectorMeetingKind.excluded),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Championnat (1)'), findsOneWidget);
      expect(find.text('Coupes (1)'), findsOneWidget);
      expect(find.text('KHL'), findsWidgets);
      expect(find.text('National Cup'), findsNothing);
      await tester.ensureVisible(find.text('Coupes (1)'));
      await tester.tap(find.text('Coupes (1)'));
      await tester.pumpAndSettle();
      expect(find.text('National Cup'), findsWidgets);
      expect(find.text('KHL'), findsNothing);
      expect(find.text('Exhibition'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
