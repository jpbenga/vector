import 'dart:async';
import 'package:copilot/app/theme/app_theme.dart';
import 'package:copilot/core/sports/domain/sport.dart';
import 'package:copilot/core/sports/domain/sport_feed_repository.dart';
import 'package:copilot/core/sports/domain/sport_fixture.dart';
import 'package:copilot/core/sports/domain/sport_market_quote.dart';
import 'package:copilot/core/sports/domain/sport_policy.dart';
import 'package:copilot/core/sports/domain/sport_snapshot.dart';
import 'package:copilot/core/sports/presentation/sport_fixture_card.dart';
import 'package:copilot/core/widgets/lector_match_odds.dart';
import 'package:copilot/features/hockey/presentation/hockey_match_detail_page.dart';
import 'package:copilot/features/hockey/presentation/hockey_quote_presentation.dart';
import 'package:copilot/features/hockey/presentation/hockey_workspace.dart';
import 'package:copilot/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../../../fixtures/sports/hockey_readings_fixture.dart';

final at = DateTime.now().toUtc();
SportFixture fixture({String id = 'quoted', bool priced = false}) {
  final base = hockeyReadingFixture();
  final match = hockeyId(SportEntityKind.match, id);
  return SportFixture(
    id: match,
    competition: base.competition,
    competitionName: base.competitionName,
    season: base.season,
    home: base.home,
    away: base.away,
    startsAt: at.add(const Duration(hours: 4)),
    calendarDate: at.toLocal(),
    capturedAt: readingCutoff,
    status: SportFixtureStatus.scheduled,
    homeForm: base.homeForm,
    awayForm: base.awayForm,
    quotes: priced
        ? [
            for (final (code, price) in [
              ('home', 2.13),
              ('draw', 4.2),
              ('away', 2.62),
            ])
              SportMarketQuote(
                match: match,
                marketCode: 'result_regulation',
                selectionCode: code,
                scope: SportScoreScope.regulation,
                bookmaker: 'Book A',
                decimalOdds: price,
                capturedAt: at,
              ),
          ]
        : [],
  );
}

SportFeedResult result(SportFixture match) {
  final base = hockeyReadingSnapshot(match);
  return SportFeedResult.available(
    SportSnapshot<SportFixture>(
      sport: base.sport,
      schemaVersion: base.schemaVersion,
      capturedAt: base.capturedAt,
      windowStart: at.subtract(const Duration(days: 7)),
      windowEnd: at.add(const Duration(days: 13)),
      items: [match],
      sportOf: (f) => f.sport,
      competitions: base.competitions,
    ),
  );
}

class Feed implements ObservableSportFeedRepository {
  final controller = StreamController<SportFeedUpdate>.broadcast();
  @override
  SportId get sport => SportId.hockey;
  @override
  Stream<SportFeedUpdate> get updates => controller.stream;
  @override
  Future<SportFeedResult> load(DateTime date) async => result(fixture());
  void send(SportFixture match, {DateTime? date, bool detail = false}) =>
      controller.add(
        SportFeedUpdate(
          result: result(match),
          date: date,
          matchId: detail ? match.id.value : null,
        ),
      );
}

Widget app(Widget child) => MaterialApp(
  theme: AppTheme.dark,
  locale: const Locale('fr'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  setUpAll(() => initializeDateFormatting('fr'));
  testWidgets(
    'a narrow hockey card exposes 60 minute prices in away/N/home order',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final match = fixture(priced: true);
      await tester.pumpWidget(
        app(
          SportFixtureCard(
            fixture: match,
            order: SportParticipantOrder.awayHome,
            onTap: () {},
            odds: HockeyCardOdds(fixture: match),
          ),
        ),
      );
      expect(find.text('60 min'), findsOneWidget);
      final prices = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(HockeyCardOdds),
              matching: find.byType(Text),
            ),
          )
          .map((text) => text.data ?? text.textSpan?.toPlainText())
          .toList();
      expect(prices, ['60 min', '2 2.62', 'N 4.20', '1 2.13']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'an already opened detail replaces absent cached prices when the matching public response arrives',
    (tester) async {
      final feed = Feed();
      await tester.pumpWidget(
        app(HockeyMatchDetailPage(fixture: fixture(), repository: feed)),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<LectorMatchOdds>(find.byType(LectorMatchOdds)).markets,
        isEmpty,
      );
      feed.send(fixture(id: 'another', priced: true), detail: true);
      await tester.pump();
      expect(
        tester.widget<LectorMatchOdds>(find.byType(LectorMatchOdds)).markets,
        isEmpty,
      );
      feed.send(fixture(priced: true), detail: true);
      await tester.pumpAndSettle();
      final market = tester
          .widget<LectorMatchOdds>(find.byType(LectorMatchOdds))
          .markets
          .single;
      expect(market.selections.map((q) => q.odds), [2.13, 4.2, 2.62]);
      expect(market.bookmaker, 'Book A');
      await tester.pumpWidget(const SizedBox());
      await feed.controller.close();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'background prices appear in the current hockey day and a late response for another day is ignored',
    (tester) async {
      final feed = Feed();
      await tester.pumpWidget(
        app(HockeyWorkspace(repository: feed, initialDate: at.toLocal())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tous').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Test country'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('League 35'));
      await tester.pumpAndSettle();
      expect(find.text('Cotes indisponibles'), findsOneWidget);
      expect(find.text('2.13'), findsNothing);
      feed.send(
        fixture(priced: true),
        date: at.toLocal().subtract(const Duration(days: 1)),
      );
      await tester.pump();
      expect(find.text('Cotes indisponibles'), findsOneWidget);
      expect(find.text('2.13'), findsNothing);
      feed.send(fixture(priced: true), date: at.toLocal());
      await tester.pumpAndSettle();
      expect(find.text('60 min'), findsOneWidget);
      expect(find.text('2.13'), findsOneWidget);
      expect(find.text('Cotes indisponibles'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await feed.controller.close();
    },
  );
}
