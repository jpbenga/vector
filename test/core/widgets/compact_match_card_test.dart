import 'dart:convert';
import 'dart:io';
import 'package:copilot/features/matches/data/match_feed_repository.dart';
import 'package:copilot/core/domain/compact_match_data.dart';
import 'package:copilot/core/theme/app_theme.dart';
import 'package:copilot/core/widgets/lector_compact_match_card.dart';
import 'package:copilot/features/appearance/data/appearance_preview_fixture.dart';
import 'package:copilot/features/matches/domain/match_board_item.dart';
import 'package:copilot/features/matches/presentation/compact_football_match_adapter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'form uses chronological prematch history, excludes current and future matches',
    () {
      final kickoff = DateTime.utc(2026, 10, 13);
      final base = appearancePreviewMatch;
      final fixture = NormalizedFixture(
        id: base.id,
        apiFootballFixtureId: 8,
        competition: base.competition,
        homeTeam: base.homeTeam,
        awayTeam: base.awayTeam,
        kickoffLabel: '21:00',
        kickoff: kickoff,
        status: FixtureStatus.scheduled,
      );
      TeamRecentMatchSnapshot game(int id, int day, String result) =>
          TeamRecentMatchSnapshot(
            fixtureId: id,
            opponentName: 'Adversaire',
            venue: RecentMatchVenue.home,
            result: result,
            playedAt: DateTime.utc(2026, 10, day),
          );
      final data = compactFootballMatch(
        match: base.copyWith(
          fixture: fixture,
          analysis: MatchAnalysisData(
            asOf: DateTime.utc(2026, 10, 12),
            homeRecentLeagueMatches: [
              game(9, 14, 'W'),
              game(4, 11, 'L'),
              game(8, 10, 'W'),
              game(3, 7, 'D'),
              game(2, 4, 'W'),
            ],
          ),
        ),
        showReadings: false,
      );
      expect(data.home.form.latest.map((r) => r.code), ['W', 'D', 'L']);
      expect(data.readingCount, isNull);
    },
  );
  test(
    'only result-market outcomes provide 1 N 2, independently from supplied order',
    () {
      const selections = [
        MarketOdds(id: 'a', label: 'Away', apiFootballValue: 'Away', odds: 3.2),
        MarketOdds(id: 'h', label: 'Home', apiFootballValue: 'Home', odds: 1.7),
        MarketOdds(id: 'd', label: 'Draw', apiFootballValue: 'Draw', odds: 3.4),
      ];
      final match = appearancePreviewMatch.copyWith(
        availableMarkets: const [
          MatchMarket(
            id: 'matchResult',
            label: 'Résultat',
            selections: selections,
          ),
        ],
      );
      final data = compactFootballMatch(match: match, showReadings: false);
      expect(data.quotes.map((q) => q.outcome), ['1', 'N', '2']);
      expect(data.quotes.map((q) => q.value), [1.7, 3.4, 3.2]);
      expect(
        compactFootballMatch(
          match: match.copyWith(availableMarkets: const []),
          showReadings: false,
        ).quoteState,
        CompactQuoteState.unavailable,
      );
    },
  );
  test('unscoped published readings never create card badges or counters', () {
    final snapshot =
        jsonDecode(File('assets/design_preview/league.json').readAsStringSync())
            as Map<String, dynamic>;
    final match = SnapshotMatchFeedRepository(
      snapshot: snapshot,
    ).allMatches().single;
    expect(
      compactFootballMatch(match: match, showReadings: true).readingCount,
      isNull,
    );
    expect(
      compactFootballMatch(match: match, showReadings: false).readingCount,
      isNull,
    );
    expect(
      compactFootballMatch(
        match: match,
        analyzedMatch: match,
        showReadings: true,
      ).readingCount,
      isNull,
    );
  });
  testWidgets(
    'card actions are independent, score is factual and finished odds are hidden',
    (tester) async {
      final base = appearancePreviewMatch;
      final match = base.copyWith(
        fixture: NormalizedFixture(
          id: base.id,
          competition: base.competition,
          homeTeam: base.homeTeam,
          awayTeam: base.awayTeam,
          kickoffLabel: '21:00',
          status: FixtureStatus.finished,
          score: const FixtureScore(home: 2, away: 1),
        ),
      );
      var opened = 0, saved = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: CopilotTheme.dark,
          home: Scaffold(
            body: LectorCompactMatchCard(
              data: compactFootballMatch(match: match, showReadings: true),
              onOpen: () => opened++,
              preparationAction: IconButton(
                tooltip: 'Ajouter à la Shortlist',
                onPressed: () => saved++,
                icon: const Icon(Icons.add),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Ajouter à la Shortlist'));
      await tester.pump();
      expect(saved, 1);
      expect(opened, 0);
      expect(find.text('Terminé'), findsOneWidget);
      expect(find.text('Cotes 1N2'), findsNothing);
      await tester.tap(find.byKey(ValueKey('compact-open:${base.id}')));
      expect(opened, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
