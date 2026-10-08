import 'dart:async';
import 'package:copilot/app/theme/app_theme.dart';
import 'package:copilot/core/sports/domain/sport.dart';
import 'package:copilot/core/sports/domain/sport_feed_repository.dart';
import 'package:copilot/core/widgets/lector_loading.dart';
import 'package:copilot/features/hockey/presentation/hockey_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:copilot/l10n/generated/app_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../../../fixtures/sports/hockey_readings_fixture.dart';

class _RecoveringFeed implements SportFeedRepository {
  int calls = 0;
  @override
  SportId get sport => SportId.hockey;
  @override
  Future<SportFeedResult> load(DateTime date) async {
    if (++calls <= 2) throw TimeoutException('temporary network interruption');
    return SportFeedResult.available(
      hockeyReadingSnapshot(hockeyReadingFixture()),
    );
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('fr'));
  testWidgets(
    'hockey calendar recovers with the shared skeleton and keeps navigation',
    (tester) async {
      final repository = _RecoveringFeed();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.dark,
          home: Scaffold(
            body: HockeyWorkspace(
              repository: repository,
              initialDate: readingCutoff,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Tous'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(LectorLoading), findsOneWidget);
      expect(find.text('Réessayer'), findsNothing);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(repository.calls, 3);
      expect(find.text('Réessayer'), findsNothing);
      expect(find.byType(LectorLoading), findsNothing);
      expect(
        find.byKey(const ValueKey('home-primary-navigation')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
