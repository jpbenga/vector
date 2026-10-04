import 'dart:convert';
import 'dart:io';

import 'package:copilot/app/theme/app_theme.dart';
import 'package:copilot/core/sports/data/published_sport_feed_repository.dart';
import 'package:copilot/core/sports/domain/sport.dart';
import 'package:copilot/core/sports/domain/sport_feed_repository.dart';
import 'package:copilot/core/sports/domain/sport_fixture.dart';
import 'package:copilot/features/hockey/domain/hockey_module.dart';
import 'package:copilot/features/hockey/presentation/hockey_workspace.dart';
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
      'real compact NHL displays away-left, home-right and period details at $width',
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
        expect(find.text('Boston Bruins'), findsOneWidget);
        expect(find.text('Winnipeg Jets'), findsOneWidget);
        expect(
          tester.getCenter(find.text('Boston Bruins')).dx,
          lessThan(tester.getCenter(find.text('Winnipeg Jets')).dx),
        );
        expect(find.text('4 – 3'), findsOneWidget);
        expect(find.text('Extérieur'), findsOneWidget);
        expect(find.text('Domicile'), findsOneWidget);
        await tester.tap(find.text('Détail du match'));
        await tester.pumpAndSettle();
        expect(find.text('À 60 minutes'), findsOneWidget);
        expect(find.text('3 – 3'), findsOneWidget);
        expect(find.text('Score final'), findsOneWidget);
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
      expect(
        find.text('Aucune rencontre NHL programmée pour ce jour.'),
        findsOneWidget,
      );
      source.fail = true;
      await tester.tap(find.byKey(const ValueKey('hockey-refresh')));
      await tester.pumpAndSettle();
      expect(find.textContaining('momentanément indisponible'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('hockey-section-1')));
      await tester.pumpAndSettle();
      expect(find.text('Avantage au classement'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
