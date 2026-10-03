import 'package:copilot/app/theme/app_theme.dart';
import 'package:copilot/core/widgets/lector_responsive_layout.dart';
import 'package:copilot/features/appearance/data/appearance_preview_fixture.dart';
import 'package:copilot/features/matches/presentation/lector_competitions_page.dart';
import 'package:copilot/features/matches/presentation/lector_scenarios_page.dart';
import 'package:copilot/features/matches/presentation/lector_space_page.dart';
import 'package:copilot/features/matches/presentation/lector_strategies_page.dart';
import 'package:copilot/features/matches/presentation/lector_preferences_sheet.dart';
import 'package:copilot/features/matches/presentation/match_detail_page.dart';
import 'package:copilot/features/onboarding/domain/decision_profile.dart';
import 'package:copilot/features/onboarding/presentation/onboarding_page.dart';
import 'package:copilot/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _profile = DecisionProfile(onboardingVersion: 'responsive', answers: []);

void main() {
  for (final width in [320.0, 390.0, 768.0, 1280.0, 1920.0]) {
    testWidgets('Mon espace adapts its cards at width $width', (tester) async {
      await _pump(tester, width, _space());
      final grid = find.byType(LectorAdaptiveCards);
      expect(tester.getSize(grid).width, lessThanOrEqualTo(1092));
      final cards = find.descendant(of: grid, matching: find.byType(SizedBox));
      final first = tester.getRect(cards.at(0));
      // The direct SizedBoxes are the card wrappers, identified by their width.
      final wrappers = cards.evaluate().where((element) {
        final box = element.widget as SizedBox;
        return box.width != null && box.width! > 200;
      }).toList();
      final rects = wrappers
          .map((element) => tester.getRect(find.byWidget(element.widget)))
          .toList();
      expect(rects, hasLength(6));
      expect(first.width, lessThanOrEqualTo(width));
      if (width >= 1280) {
        expect(rects[0].top, rects[1].top);
        expect(rects[1].left, greaterThan(rects[0].right));
      } else {
        expect(rects[0].left, rects[1].left);
        expect(rects[1].top, greaterThan(rects[0].bottom));
      }
      // Navigation remains usable in both layouts.
      await tester.ensureVisible(find.text('Mes scénarios'));
      await tester.tap(find.text('Mes scénarios'));
      await tester.pumpAndSettle();
      expect(find.byType(LectorScenariosPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Preference pages stay readable at width $width', (
      tester,
    ) async {
      for (final page in <Widget>[
        LectorCompetitionsPage(
          profile: _profile,
          onProfileChanged: (_) async {},
        ),
        LectorScenariosPage(profile: _profile, onProfileChanged: (_) async {}),
        LectorStrategiesPage(
          strategies: const [],
          onTicketStrategiesChanged: (_) async {},
        ),
        OnboardingPage(onCompleted: (_) {}),
      ]) {
        await _pump(tester, width, page);
        final list = find.byType(ListView).first;
        final rect = tester.getRect(list);
        expect(rect.width, lessThanOrEqualTo(LectorLayout.readingWidth));
        if (width > LectorLayout.readingWidth) {
          expect(rect.center.dx, closeTo(width / 2, .1));
        }
        expect(tester.takeException(), isNull, reason: '${page.runtimeType}');
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('Match details and reading editor fit width $width', (
      tester,
    ) async {
      await _pump(
        tester,
        width,
        MatchDetailPage(match: appearancePreviewMatch),
      );
      final rect = tester.getRect(find.byType(CustomScrollView).first);
      expect(rect.width, lessThanOrEqualTo(LectorLayout.workspaceWidth));
      expect(rect.center.dx, closeTo(width / 2, .1));
      expect(tester.takeException(), isNull);
      await _pump(
        tester,
        width,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showReadingPreferencesSheet(
                context: context,
                profile: _profile,
                onProfileChanged: (_) async {},
              ),
              child: const Text('Lectures'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Lectures'));
      await tester.pumpAndSettle();
      final editor = tester.getRect(find.text('Mes lectures'));
      expect(editor.left, greaterThanOrEqualTo(0));
      expect(
        tester.getSize(find.byType(ListView).last).width,
        lessThanOrEqualTo(LectorLayout.readingWidth),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Large text returns the desktop cards to one column', (
    tester,
  ) async {
    await _pump(tester, 1280, _space(), scale: 1.5);
    final grid = find.byType(LectorAdaptiveCards);
    final appearance = tester.getRect(
      find.descendant(of: grid, matching: find.text('Apparence')),
    );
    final competitions = tester.getRect(
      find.descendant(of: grid, matching: find.text('Mes compétitions')),
    );
    expect(appearance.left, competitions.left);
    expect(competitions.top, greaterThan(appearance.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Responsive footer keeps its natural height', (tester) async {
    await _pump(
      tester,
      1280,
      const Scaffold(
        bottomNavigationBar: LectorContent(child: SizedBox(height: 60)),
        body: SizedBox.expand(),
      ),
    );
    expect(tester.getSize(find.byType(LectorContent)).height, 60);
  });
}

Widget _space() => LectorSpacePage(
  profile: _profile,
  ticketStrategies: const [],
  onProfileChanged: (_) async {},
  onTicketStrategiesChanged: (_) async {},
);

Future<void> _pump(
  WidgetTester tester,
  double width,
  Widget page, {
  double scale = 1,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('fr'),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: page,
    ),
  );
  await tester.pumpAndSettle();
}
