import 'package:copilot/app/theme/app_theme.dart';
import 'package:copilot/features/appearance/data/appearance_preview_fixture.dart';
import 'package:copilot/features/matches/data/match_reading_bilan_repository.dart';
import 'package:copilot/features/matches/domain/live_match_state.dart';
import 'package:copilot/features/matches/domain/match_board_item.dart';
import 'package:copilot/features/matches/presentation/match_detail_page.dart';
import 'package:copilot/features/matches/presentation/widgets/live_match_status.dart';
import 'package:copilot/features/matches/presentation/widgets/match_reading_bilan_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

final _kickoff = DateTime.utc(2026, 10, 8, 15);
MatchBoardItem _match({
  bool finished = true,
  bool priced = true,
  DateTime? quoteAt,
}) {
  final original = appearancePreviewMatch.fixture;
  return appearancePreviewMatch.copyWith(
    fixture: NormalizedFixture(
      id: 'api-fixture-1638102',
      apiFootballFixtureId: 1638102,
      competition: original.competition,
      homeTeam: const TeamInfo(id: 'home', name: 'HJK Helsinki'),
      awayTeam: const TeamInfo(id: 'away', name: 'VPS'),
      kickoffLabel: '17:00',
      kickoff: _kickoff,
      status: finished ? FixtureStatus.finished : FixtureStatus.scheduled,
      score: finished ? const FixtureScore(home: 6, away: 0) : null,
    ),
    analysis: const MatchAnalysisData(),
    betRecommendations: const [],
    availableMarkets: !priced
        ? const []
        : [
            MatchMarket(
              id: 'matchResult',
              label: 'Résultat du match',
              bookmakerName: '1xBet',
              updatedAt: quoteAt ?? DateTime.utc(2026, 10, 8, 2, 13),
              selections: const [
                MarketOdds(
                  id: 'home',
                  label: 'Domicile',
                  apiFootballValue: 'Home',
                  odds: 1.57,
                ),
                MarketOdds(
                  id: 'draw',
                  label: 'Nul',
                  apiFootballValue: 'Draw',
                  odds: 4.15,
                ),
                MarketOdds(
                  id: 'away',
                  label: 'Extérieur',
                  apiFootballValue: 'Away',
                  odds: 5.21,
                ),
              ],
            ),
          ],
  );
}

MatchReadingBilanEntry _entry(
  String id,
  String label,
  String verdict, {
  String side = 'home',
  String rule = 'team_win',
}) => MatchReadingBilanEntry(
  announcementId: id,
  fixtureId: 1638102,
  kickoffAt: _kickoff,
  readingId: id,
  readingLabel: label,
  verdict: verdict,
  explanation: 'Évaluation de la lecture annoncée avant le coup d’envoi.',
  announcementKind: 'reading',
  subjectSide: side,
  homeTeamName: 'HJK Helsinki',
  awayTeamName: 'VPS',
  homeGoals: 6,
  awayGoals: 0,
  outcomeRule: rule,
  sampleSize: 5,
  competitionName: 'Veikkausliiga',
  evidence: [
    {
      'label': id == 'declining_form'
          ? 'HJK Helsinki suit une trajectoire en baisse sur ses cinq derniers matchs.'
          : side == 'home'
          ? 'HJK Helsinki est solide à domicile et VPS fragile à l’extérieur.'
          : 'VPS enchaîne trois défaites à l’extérieur.',
    },
  ],
);

final _entries = [
  _entry('home_away_advantage', 'Avantage domicile / extérieur', 'confirmed'),
  _entry(
    'weak_away_team',
    'Fragile à l’extérieur',
    'confirmed',
    side: 'away',
    rule: 'team_loss',
  ),
  _entry(
    'declining_form',
    'Trajectoire en baisse',
    'contradicted',
    rule: 'team_loss',
  ),
];

void main() {
  setUpAll(() => initializeDateFormatting('fr'));
  for (final width in [320.0, 390.0]) {
    testWidgets(
      'match bilan keeps participants, result and frozen rules explicit at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var opened = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: LiveReadingSummary(
                match: _match(),
                state: LiveMatchState(
                  fixtureId: 1638102,
                  status: 'FT',
                  capturedAt: DateTime.now(),
                ),
                entries: _entries,
                onOpenMatch: () => opened++,
              ),
            ),
          ),
        );
        await tester.tap(find.text('Voir les lectures'));
        await tester.pumpAndSettle();
        expect(find.text('Veikkausliiga'), findsOneWidget);
        expect(find.text('6 – 0'), findsOneWidget);
        expect(find.text('Lectures confirmées · 2'), findsOneWidget);
        expect(find.text('Concerne : HJK Helsinki · domicile'), findsWidgets);
        expect(find.text('Résultat : VPS perd 0–6'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Trajectoire en baisse'),
          250,
          scrollable: find.descendant(
            of: find.byType(MatchReadingBilanSheet),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Contredite'), findsOneWidget);
        expect(
          find.text('Critère : L’équipe concernée perd le match.'),
          findsWidgets,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Voir les données du match'));
        await tester.pumpAndSettle();
        expect(opened, 1);
        expect(find.byType(MatchReadingBilanSheet), findsNothing);
      },
    );
  }

  for (final theme in [AppTheme.dark, AppTheme.light]) {
    testWidgets(
      'Context shows archived factual odds without a recommended selection in ${theme.brightness}',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: MatchDetailPage(match: _match()),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Contexte'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Cotes avant-match'));
        expect(find.text('1,57'), findsOneWidget);
        expect(find.text('4,15'), findsOneWidget);
        expect(find.text('5,21'), findsOneWidget);
        expect(
          find.textContaining('1xBet · Relevées le 08/10'),
          findsOneWidget,
        );
        expect(find.text('MARCHÉS ASSOCIÉS'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'Context does not present a post-kickoff quote as an archived prematch price',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: MatchDetailPage(
            match: _match(quoteAt: _kickoff.add(const Duration(minutes: 40))),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Contexte'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Cotes avant-match'));
      expect(
        find.text('Aucune cote d’avant-match archivée pour cette rencontre.'),
        findsOneWidget,
      );
      expect(find.text('1,57'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
