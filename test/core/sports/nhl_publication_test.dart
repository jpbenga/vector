import 'package:copilot/core/widgets/lector_match_stats.dart';
import 'package:copilot/core/widgets/lector_match_insights.dart';
import 'dart:convert';
import 'dart:io';

import 'package:copilot/app/theme/app_theme.dart';
import 'package:copilot/core/sports/data/published_sport_feed_repository.dart';
import 'package:copilot/core/sports/domain/sport.dart';
import 'package:copilot/core/sports/domain/sport_feed_repository.dart';
import 'package:copilot/core/sports/domain/sport_fixture.dart';
import 'package:copilot/features/hockey/domain/hockey_module.dart';
import 'package:copilot/features/hockey/presentation/hockey_workspace.dart';
import 'package:copilot/core/widgets/lector_match_card.dart';
import 'package:copilot/core/widgets/lector_match_detail_view.dart';
import 'package:copilot/core/widgets/lector_match_hero_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

class _Source implements SportPublicationSource {
  _Source(this.payload);
  Map<String, dynamic>? payload;
  bool fail = false;
  @override
  Future<Map<String, dynamic>?> read(SportId sport) async {
    if (fail) throw StateError('Network offline');
    return payload;
  }
}

Map<String, dynamic> fixture() =>
    jsonDecode(File('test/fixtures/sports/nhl_compact.json').readAsStringSync())
        as Map<String, dynamic>;
SportFeedRepository _repository(_Source source) => ValidatedSportFeedRepository(
  delegate: PublishedSportFeedRepository(sport: SportId.hockey, source: source),
  policy: HockeyModule.definition.dataPolicy,
  clock: () => DateTime.utc(2026, 10, 4, 10),
);

void main() {
  setUpAll(() => initializeDateFormatting('fr'));
  test(
    'backend public contract loads day fourteen and preserves regulation and final scores',
    () async {
      final source = _Source(fixture());
      final result = await _repository(source).load(DateTime(2026, 10, 17));
      expect(result.isAvailable, isTrue);
      final game = result.snapshot!.items.single;
      expect(game.home.name, 'Winnipeg Jets');
      expect(game.away.name, 'Boston Bruins');
      expect(game.scoreFor(SportScoreScope.finalResult)!.away, 4);
      expect(game.scoreFor(SportScoreScope.regulation)!.away, 3);
      expect(
        (await _repository(
          source,
        ).load(DateTime(2026, 10, 18))).unavailableReason,
        SportFeedUnavailableReason.outsideWindow,
      );
      source.payload = {...fixture(), 'items': <Object>[]};
      expect(
        (await _repository(source).load(DateTime(2026, 10, 4))).isAvailable,
        isTrue,
      );
      source.payload = {...fixture(), 'sport': 'football'};
      await expectLater(
        _repository(source).load(DateTime(2026, 10, 4)),
        throwsFormatException,
      );
    },
  );

  for (final width in [360.0, 1100.0]) {
    testWidgets(
      'NHL uses the shared match card and full detail route at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 950);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final source = _Source(fixture());
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: HockeyWorkspace(
                repository: _repository(source),
                initialDate: DateTime(2026, 10, 3),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(LectorMatchCard), findsNothing);
        await tester.tap(find.text('Tous'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('International'));
        await tester.tap(find.text('International'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('NHL'));
        await tester.tap(find.text('NHL'));
        await tester.pumpAndSettle();
        expect(find.text('Boston Bruins'), findsOneWidget);
        expect(find.text('Winnipeg Jets'), findsOneWidget);
        expect(
          tester.getCenter(find.text('Boston Bruins')).dy,
          lessThan(tester.getCenter(find.text('Winnipeg Jets')).dy),
        );
        expect(find.byType(LectorMatchCard), findsOneWidget);
        expect(find.text('4'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
        expect(find.text('Extérieur'), findsOneWidget);
        expect(find.text('Domicile'), findsOneWidget);
        await tester.tap(find.byTooltip('Voir l’analyse'));
        await tester.pumpAndSettle();
        expect(find.byType(LectorMatchDetailView), findsOneWidget);
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.byType(LectorMatchHeroView), findsOneWidget);
        expect(
          tester
              .getCenter(
                find.descendant(
                  of: find.byType(LectorMatchHeroView),
                  matching: find.text('Boston Bruins'),
                ),
              )
              .dx,
          lessThan(
            tester
                .getCenter(
                  find.descendant(
                    of: find.byType(LectorMatchHeroView),
                    matching: find.text('Winnipeg Jets'),
                  ),
                )
                .dx,
          ),
        );
        for (final tab in ['Contexte', 'Classement', 'Forme', 'TAT']) {
          expect(find.text(tab), findsOneWidget);
        }
        // Actual period/result facts belong to Stats. Contexte shares the
        // prematch-keys component with football rather than duplicating scores.
        final stats = tester.widget<LectorMatchStats>(
          find.byType(LectorMatchStats),
        );
        final regulation = stats.rows.singleWhere(
          (r) => r.label == 'À 60 minutes',
        );
        expect(regulation.first, '3');
        expect(regulation.second, '3');
        final finalScore = stats.rows.singleWhere(
          (r) => r.label == 'Score final',
        );
        expect(finalScore.first, '4');
        expect(finalScore.second, '3');
        await tester.ensureVisible(find.text('Contexte'));
        await tester.tap(find.text('Contexte'));
        await tester.pumpAndSettle();
        expect(find.byType(LectorMatchContextView), findsOneWidget);
        expect(find.text('Clés du match'), findsOneWidget);
        await tester.ensureVisible(find.text('Classement'));
        await tester.tap(find.text('Classement'));
        await tester.pumpAndSettle();
        // This minimal contract contains scores only, with no standing table.
        expect(
          find.text('Classement non fourni dans cette publication.'),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('hockey-standing-scope-1')),
          findsNothing,
        );
        await tester.tap(find.text('TAT'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('ne se sont jamais rencontrées'),
          findsOneWidget,
        );
        await tester.tap(find.byTooltip('Retour'));
        await tester.pumpAndSettle();
        expect(find.byType(LectorMatchDetailView), findsNothing);
        expect(find.byType(LectorMatchCard), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'empty day and failed source keep calendar and readings accessible',
    (tester) async {
      final source = _Source({...fixture(), 'items': <Object>[]});
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: HockeyWorkspace(
              repository: _repository(source),
              initialDate: DateTime(2026, 10, 4),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tous'));
      await tester.pumpAndSettle();
      expect(
        find.text('Aucune rencontre hockey programmée pour ce jour.'),
        findsOneWidget,
      );
      source.fail = true;
      await tester.tap(find.byKey(const ValueKey('hockey-refresh')));
      await tester.pumpAndSettle();
      expect(find.textContaining('momentanément indisponible'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('hockey-rules')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('hockey-section-1')));
      await tester.pumpAndSettle();
      expect(find.text('Avantage au classement'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
