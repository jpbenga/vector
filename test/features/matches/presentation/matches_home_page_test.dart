import 'package:copilot/core/theme/app_theme.dart';
import 'package:copilot/features/matches/data/match_feed_repository.dart';
import 'package:copilot/features/matches/domain/match_board_item.dart';
import 'package:copilot/features/matches/presentation/matches_home_page.dart';
import 'package:copilot/features/onboarding/domain/decision_profile.dart';
import 'package:copilot/features/onboarding/domain/decision_profile_catalogs.dart';
import 'package:copilot/features/onboarding/domain/onboarding_answer.dart';
import 'package:copilot/features/opportunities/domain/opportunity.dart';
import 'package:copilot/features/tickets/domain/ticket_strategy.dart';
import 'package:copilot/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MatchesHomePage redesign', () {
    testWidgets('starts on For me with Lector readings', (tester) async {
      await _pumpPage(
        tester,
        repository: _FakeMatchFeedRepository(
          opportunities: [
            _opportunity(
              match: _match(
                id: 'chelsea-spurs',
                homeName: 'Chelsea',
                awayName: 'Tottenham',
                kickoff: _relativeKickoff(0, hour: 20),
              ),
              retainedTheses: [
                _thesis(id: 'open_match', title: 'Match ouvert'),
              ],
            ),
          ],
          matches: [
            _match(
              id: 'chelsea-spurs',
              homeName: 'Chelsea',
              awayName: 'Tottenham',
              kickoff: _relativeKickoff(0, hour: 20),
            ),
          ],
        ),
      );

      expect(find.text('A suivre aujourd’hui'), findsOneWidget);
      expect(find.text('Ma sélection'), findsOneWidget);
      expect(find.text('Chelsea'), findsWidgets);
      expect(find.text('Tottenham'), findsWidgets);
      expect(find.text('Tous les matchs'), findsNothing);
    });

    testWidgets('keeps All matches separated and folded by default', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        repository: _FakeMatchFeedRepository(
          opportunities: [
            _opportunity(
              match: _match(
                id: 'chelsea-spurs',
                homeName: 'Chelsea',
                awayName: 'Tottenham',
                kickoff: _relativeKickoff(0, hour: 20),
              ),
              retainedTheses: [
                _thesis(id: 'open_match', title: 'Match ouvert'),
              ],
            ),
          ],
          matches: [
            _match(
              id: 'chelsea-spurs',
              homeName: 'Chelsea',
              awayName: 'Tottenham',
              kickoff: _relativeKickoff(0, hour: 20),
            ),
            _match(
              id: 'arsenal-liverpool',
              homeName: 'Arsenal',
              awayName: 'Liverpool',
              competitionId: '39',
              competitionName: 'Premier League',
              kickoff: _relativeKickoff(0, hour: 21),
            ),
          ],
        ),
      );

      await tester.tap(find.text('Tous'));
      await tester.pumpAndSettle();

      expect(find.text('Tous les matchs'), findsOneWidget);
      expect(find.text('A suivre aujourd’hui'), findsNothing);
      expect(find.text('Premier League'), findsOneWidget);
      for (final crossFade in tester.widgetList<AnimatedCrossFade>(
        find.byType(AnimatedCrossFade),
      )) {
        expect(crossFade.crossFadeState, CrossFadeState.showFirst);
      }

      await tester.tap(find.text('Premier League'));
      await tester.pumpAndSettle();

      expect(find.text('Arsenal'), findsOneWidget);
      expect(find.text('Liverpool'), findsOneWidget);
    });

    testWidgets('opens the redesigned match detail from For me', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        repository: _FakeMatchFeedRepository(
          opportunities: [
            _opportunity(
              match: _match(
                id: 'bodo-rosenborg',
                homeName: 'Bodo/Glimt',
                awayName: 'Rosenborg',
                competitionName: 'Eliteserien',
                kickoff: _relativeKickoff(0, hour: 14),
                analysis: _analysisData(
                  homeName: 'Bodo/Glimt',
                  awayName: 'Rosenborg',
                ),
              ),
              retainedTheses: [
                _thesis(id: 'level_gap', title: 'Domination attendue'),
              ],
            ),
          ],
        ),
      );

      await tester.tap(find.text('Bodo/Glimt').first);
      await tester.pumpAndSettle();

      expect(find.text('Repères Lector'), findsOneWidget);
      expect(find.text('Contexte rapide'), findsOneWidget);
      expect(find.text('Derniers matchs'), findsOneWidget);
      expect(find.text('Avant-match'), findsWidgets);
    });

    testWidgets('opens match detail from a folded All matches league', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        repository: _FakeMatchFeedRepository(
          opportunities: const [],
          matches: [
            _match(
              id: 'psg-dortmund',
              homeName: 'Paris SG',
              awayName: 'Dortmund',
              competitionId: '2',
              competitionName: 'Ligue des champions',
              kickoff: _relativeKickoff(0, hour: 18),
              analysis: _analysisData(
                homeName: 'Paris SG',
                awayName: 'Dortmund',
              ),
            ),
          ],
        ),
      );

      await tester.tap(find.text('Tous'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ligue des champions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paris SG'));
      await tester.pumpAndSettle();

      expect(find.text('Repères Lector'), findsOneWidget);
      expect(find.text('Paris SG'), findsWidgets);
      expect(find.text('Dortmund'), findsWidgets);
    });

    testWidgets('opens the generator from the top mode control', (
      tester,
    ) async {
      final market = _doubleChanceMarket();
      await _pumpPage(
        tester,
        strategies: [_strategy()],
        repository: _FakeMatchFeedRepository(
          opportunities: [
            _opportunity(
              retainedTheses: [
                _thesis(id: 'solid_favorite', title: 'Domination attendue'),
              ],
              recommendedMarket: RecommendedMarket(
                market: market,
                selection: market.selections.first,
              ),
            ),
          ],
        ),
      );

      await tester.tap(find.text('Générateur'));
      await tester.pumpAndSettle();

      expect(find.text('Générateur de tickets'), findsOneWidget);
      expect(find.text('Tous les matchs'), findsNothing);
    });

    testWidgets('opens Lector preferences instead of onboarding', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        repository: _FakeMatchFeedRepository(opportunities: const []),
      );

      await tester.tap(find.byTooltip('Profil'));
      await tester.pumpAndSettle();

      expect(find.text('Paramètres Lector'), findsOneWidget);
      expect(find.text('Championnats'), findsWidgets);
      expect(find.text('Lectures'), findsWidgets);
      expect(find.text('Ticket builder'), findsWidgets);
      expect(find.text('Onboarding'), findsNothing);
    });
  });
}

Future<void> _pumpPage(
  WidgetTester tester, {
  DecisionProfile? profile,
  required MatchFeedRepository repository,
  List<TicketStrategy> strategies = const [],
  Size viewSize = const Size(390, 844),
}) async {
  tester.view.physicalSize = viewSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: CopilotTheme.dark.copyWith(splashFactory: NoSplash.splashFactory),
      home: MatchesHomePage(
        profile: profile ?? _completedProfile(),
        ticketStrategies: strategies,
        repositoryOverride: repository,
        onEditProfile: () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

DecisionProfile _completedProfile() {
  return const DecisionProfile(
    onboardingVersion: 'test',
    answers: [
      OnboardingAnswer(questionId: 'competitions', orderedOptionIds: ['61']),
      OnboardingAnswer(
        questionId: 'markets',
        orderedOptionIds: ['double_chance'],
      ),
      OnboardingAnswer(
        questionId: 'opportunity_profiles',
        orderedOptionIds: ['solid_favorite', 'ranking_gap', 'offensive_match'],
      ),
    ],
  );
}

Opportunity _opportunity({
  MatchBoardItem? match,
  required List<MatchThesis> retainedTheses,
  List<OpportunityMarketCompatibility> compatibleMarkets = const [],
  RecommendedMarket? recommendedMarket,
  int engineScore = 82,
}) {
  final sourceMatch = match ?? _match();

  return Opportunity(
    sourceMatch: sourceMatch,
    engineScore: engineScore,
    detectedSignals: const [
      MatchSignal(
        id: 'signal',
        title: 'Signal',
        summary: 'Signal détecté',
        proofs: ['Preuve'],
      ),
    ],
    retainedTheses: retainedTheses,
    compatibleMarkets: compatibleMarkets,
    recommendedMarket: recommendedMarket,
  );
}

MatchThesis _thesis({
  required String id,
  required String title,
  MatchThesisStatus status = MatchThesisStatus.watchlist,
  RecommendedMarket? recommendedMarket,
}) {
  return MatchThesis(
    id: id,
    title: title,
    summary: 'Lecture Lector claire pour cette rencontre.',
    status: status,
    confidence: status == MatchThesisStatus.recommended ? 82 : 0,
    supportingEvidence: const [
      ThesisEvidence(
        label: 'Preuve statistique',
        tone: ThesisEvidenceTone.positive,
      ),
    ],
    limits: const [],
    profileReasons: const [],
    arguments: const [],
    recommendedMarket: recommendedMarket,
  );
}

MatchBoardItem _match({
  String id = 'fixture',
  String homeName = 'Home',
  String awayName = 'Away',
  String countryCode = 'FR',
  String countryName = 'France',
  String competitionId = '61',
  String competitionName = 'Ligue 1',
  FixtureStatus status = FixtureStatus.scheduled,
  String kickoffLabel = '20:00',
  DateTime? kickoff,
  FixtureScore? score,
  List<MatchMarket>? markets,
  MatchAnalysisData analysis = const MatchAnalysisData(),
  MatchThesis? thesis,
}) {
  return MatchBoardItem(
    fixture: NormalizedFixture(
      id: id,
      competition: CompetitionInfo(
        id: competitionId,
        name: competitionName,
        country: CountryInfo(code: countryCode, name: countryName),
        season: 2026,
      ),
      homeTeam: TeamInfo(id: '$id-home', name: homeName),
      awayTeam: TeamInfo(id: '$id-away', name: awayName),
      kickoffLabel: kickoffLabel,
      kickoff: kickoff,
      status: status,
      score: score,
    ),
    primaryMarket: const MarketOdds(
      id: 'market_unavailable',
      label: 'Marché indisponible',
      odds: 0,
    ),
    availableMarkets: markets ?? [_doubleChanceMarket()],
    analysis: analysis,
    compatibility: 0,
    signals: const [],
    thesis: thesis,
  );
}

MatchAnalysisData _analysisData({
  String homeName = 'Home',
  String awayName = 'Away',
}) {
  return MatchAnalysisData(
    homeStanding: TeamStandingSnapshot(
      teamId: 1,
      teamName: homeName,
      rank: 5,
      points: 33,
      played: 16,
      goalsFor: 28,
      goalsAgainst: 16,
      goalDiff: 12,
      form: 'WWDWW',
    ),
    awayStanding: TeamStandingSnapshot(
      teamId: 2,
      teamName: awayName,
      rank: 12,
      points: 18,
      played: 16,
      goalsFor: 18,
      goalsAgainst: 24,
      goalDiff: -6,
      form: 'LDWWL',
    ),
    homeRecentLeagueMatches: [
      TeamRecentMatchSnapshot(
        opponentName: 'West Ham',
        venue: RecentMatchVenue.home,
        result: 'W',
        goalsFor: 3,
        goalsAgainst: 1,
      ),
    ],
    awayRecentLeagueMatches: [
      TeamRecentMatchSnapshot(
        opponentName: 'Newcastle',
        venue: RecentMatchVenue.away,
        result: 'D',
        goalsFor: 1,
        goalsAgainst: 1,
      ),
    ],
  );
}

DateTime _relativeKickoff(int dayOffset, {required int hour}) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + dayOffset, hour);
}

MatchMarket _doubleChanceMarket() {
  return const MatchMarket(
    id: 'doubleChance',
    label: 'Double chance',
    selections: [
      MarketOdds(
        id: 'double_chance_1x',
        label: '1X',
        odds: 1.42,
        apiFootballValue: 'Home/Draw',
        bookmakerId: 16,
        bookmakerName: 'Unibet',
      ),
    ],
    bookmakerId: 16,
    bookmakerName: 'Unibet',
  );
}

TicketStrategy _strategy() {
  final now = DateTime.utc(2026, 8, 2, 12);
  return TicketStrategy(
    schemaVersion: TicketStrategy.currentSchemaVersion,
    id: 'safe',
    userId: 'user',
    name: 'Safe',
    isActive: true,
    pickTypes: const [PickType.prudent],
    minimumIndividualOdds: 1.20,
    maximumIndividualOdds: 1.49,
    minimumSelections: 1,
    maximumSelections: 2,
    minimumTotalOdds: 1.20,
    maximumTotalOdds: 2,
    priority: 1,
    createdAt: now,
    updatedAt: now,
  );
}

class _FakeMatchFeedRepository implements MatchFeedRepository {
  const _FakeMatchFeedRepository({required this.opportunities, this.matches});

  final List<Opportunity> opportunities;
  final List<MatchBoardItem>? matches;

  @override
  MatchDataSourceMode get mode => MatchDataSourceMode.demo;

  @override
  MatchFeedSnapshotMetadata? get snapshotMetadata => null;

  @override
  List<MatchBoardItem> allMatches() {
    return matches ??
        [
          for (final opportunity in opportunities)
            opportunity.toMatchBoardItem(),
        ];
  }

  @override
  MatchBoardItem analyzeFor(DecisionProfile profile, MatchBoardItem match) {
    for (final opportunity in opportunities) {
      if (opportunity.matchId == match.fixture.id) {
        return opportunity.toMatchBoardItem();
      }
    }
    return match;
  }

  @override
  List<Opportunity> opportunitiesFor(DecisionProfile profile) => opportunities;

  @override
  List<MatchBoardItem> personalizedFor(DecisionProfile profile) {
    throw StateError('For me consumes opportunitiesFor directly.');
  }
}
