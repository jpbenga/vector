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
  group('MatchesHomePage opportunities', () {
    testWidgets('blocks personalized For me when profile is incomplete', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        profile: const DecisionProfile(onboardingVersion: 'test', answers: []),
        repository: _FakeMatchFeedRepository(opportunities: const []),
      );

      expect(find.text('Configurez vos préférences'), findsOneWidget);
      expect(find.text('Configurer mon profil'), findsOneWidget);
    });

    testWidgets('renders one card with several profiles and no market', (
      tester,
    ) async {
      final opportunity = _opportunity(
        retainedTheses: [
          _thesis(id: 'solid_favorite', title: 'Favori solide'),
          _thesis(id: 'level_gap', title: 'Écart de niveau'),
        ],
      );

      await _pumpPage(
        tester,
        profile: _completedProfile(),
        repository: _FakeMatchFeedRepository(opportunities: [opportunity]),
      );

      expect(find.text('Home'), findsWidgets);
      expect(find.text('Away'), findsWidgets);
      expect(find.text('Favoris solides'), findsWidgets);
      expect(find.text('Mes lectures combinées'), findsOneWidget);
      expect(find.text('Affichage'), findsOneWidget);
      expect(find.text('Trier'), findsOneWidget);
      expect(find.text('AUJ'), findsWidgets);
      expect(find.text('Aucun marché recommandé'), findsOneWidget);
      expect(
        find.text('Lecture conservée sans sélection ajoutable.'),
        findsOneWidget,
      );
      expect(find.text('Lecture Copilot'), findsOneWidget);
      expect(find.text('2 arguments'), findsWidgets);
      expect(find.text('0 contradiction'), findsWidgets);
    });

    testWidgets(
      'renders a single recommended market without duplicating match',
      (tester) async {
        final market = _doubleChanceMarket();
        final recommended = RecommendedMarket(
          market: market,
          selection: market.selections.first,
        );
        final opportunity = _opportunity(
          retainedTheses: [
            _thesis(
              id: 'solid_favorite',
              title: 'Favori solide',
              recommendedMarket: recommended,
              status: MatchThesisStatus.recommended,
            ),
            _thesis(id: 'level_gap', title: 'Écart de niveau'),
          ],
          compatibleMarkets: [
            OpportunityMarketCompatibility(
              thesisId: 'solid_favorite',
              market: market,
              selection: market.selections.first,
              isRecommended: true,
            ),
            OpportunityMarketCompatibility(
              thesisId: 'level_gap',
              market: market,
              selection: market.selections.first,
              isRecommended: false,
            ),
          ],
          recommendedMarket: recommended,
        );

        await _pumpPage(
          tester,
          profile: _completedProfile(),
          repository: _FakeMatchFeedRepository(opportunities: [opportunity]),
        );

        expect(find.text('Home'), findsWidgets);
        expect(find.text('Away'), findsWidgets);
        expect(find.text('1X (Double chance)'), findsOneWidget);
        expect(find.text('1.42'), findsOneWidget);
        expect(find.text('Favoris solides'), findsWidgets);
        expect(find.text('Mes lectures combinées'), findsOneWidget);
      },
    );

    testWidgets('For me adds and removes a recommended pick from Mon ticket', (
      tester,
    ) async {
      final market = _doubleChanceMarket();
      final recommended = RecommendedMarket(
        market: market,
        selection: market.selections.first,
      );
      final opportunity = _opportunity(
        retainedTheses: [
          _thesis(
            id: 'solid_favorite',
            title: 'Favori solide',
            recommendedMarket: recommended,
            status: MatchThesisStatus.recommended,
          ),
        ],
        recommendedMarket: recommended,
      );

      await _pumpPage(
        tester,
        profile: _completedProfile(),
        repository: _FakeMatchFeedRepository(opportunities: [opportunity]),
      );

      expect(find.text('Mon ticket'), findsNothing);

      final detailAddButton = find.byTooltip('Ajouter au ticket').last;
      await tester.scrollUntilVisible(
        detailAddButton,
        280,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(detailAddButton);
      await tester.pumpAndSettle();

      expect(find.text('Mon ticket'), findsOneWidget);
      expect(find.text('Ajouté'), findsOneWidget);
      expect(find.text('Cote totale'), findsOneWidget);
      expect(find.text('1.42'), findsWidgets);

      await tester.tap(find.text('Mon ticket'));
      await tester.pumpAndSettle();
      expect(find.text('Home - Away'), findsOneWidget);
      expect(find.text('1X (Double chance)'), findsWidgets);

      await tester.tap(find.byTooltip('Retirer la sélection'));
      await tester.pumpAndSettle();

      expect(find.text('Mon ticket'), findsNothing);
    });

    testWidgets('Mon ticket validates and appears in saved tickets', (
      tester,
    ) async {
      final market = _doubleChanceMarket();
      final recommended = RecommendedMarket(
        market: market,
        selection: market.selections.first,
      );
      final opportunity = _opportunity(
        retainedTheses: [
          _thesis(
            id: 'solid_favorite',
            title: 'Favori solide',
            recommendedMarket: recommended,
            status: MatchThesisStatus.recommended,
          ),
        ],
        recommendedMarket: recommended,
      );

      await _pumpPage(
        tester,
        profile: _completedProfile(),
        strategies: [_strategy()],
        repository: _FakeMatchFeedRepository(opportunities: [opportunity]),
      );

      final detailAddButton = find.byTooltip('Ajouter au ticket').last;
      await tester.ensureVisible(detailAddButton);
      await tester.pumpAndSettle();
      await tester.tap(detailAddButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mon ticket'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Valider le ticket'));
      await tester.pumpAndSettle();

      expect(find.text('Valider le ticket'), findsWidgets);
      expect(find.text('Récapitulatif'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Ticket du soir');
      await tester.tap(find.text('Enregistrer le ticket'));
      await tester.pumpAndSettle();

      expect(find.text('Ticket enregistré !'), findsOneWidget);
      expect(find.text('Prêt à être joué !'), findsOneWidget);
      expect(find.textContaining('gain'), findsNothing);

      await tester.tap(find.text('Voir mes tickets'));
      await tester.pumpAndSettle();

      expect(find.text('Mes tickets enregistrés'), findsOneWidget);
      expect(find.text('Ticket du soir'), findsOneWidget);
      expect(find.text('Enregistré'), findsWidgets);
    });

    testWidgets('For me display sheet filters the reading only', (
      tester,
    ) async {
      final opportunity = _opportunity(
        retainedTheses: [_thesis(id: 'solid_favorite', title: 'Favori solide')],
      );

      await _pumpPage(
        tester,
        profile: _completedProfile(),
        repository: _FakeMatchFeedRepository(opportunities: [opportunity]),
      );

      await tester.tap(find.text('Affichage'));
      await tester.pumpAndSettle();

      expect(find.text('AFFICHAGE'), findsOneWidget);
      expect(find.text('PROFILS'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('COMPÉTITIONS'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('COMPÉTITIONS'), findsOneWidget);
      expect(find.text('Bookmaker'), findsNothing);
      expect(find.text('Heure'), findsNothing);

      await tester.scrollUntilVisible(
        find.text('Lectures sans marché'),
        -300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Lectures sans marché'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Appliquer'));
      await tester.pumpAndSettle();

      expect(
        find.text('Aucune lecture combinée pour cet affichage'),
        findsOneWidget,
      );
      expect(find.text('1'), findsWidgets);
    });

    testWidgets('For me calendar filters combined readings by day', (
      tester,
    ) async {
      final todayKickoff = _relativeKickoff(0, hour: 18);
      final tomorrowKickoff = _relativeKickoff(1, hour: 20);

      await _pumpPage(
        tester,
        profile: _completedProfile(),
        repository: _FakeMatchFeedRepository(
          opportunities: [
            _opportunity(
              match: _match(
                id: 'today',
                homeName: 'Today Home',
                awayName: 'Today Away',
                kickoff: todayKickoff,
                kickoffLabel: '18:00',
              ),
              retainedTheses: [
                _thesis(id: 'solid_favorite', title: 'Favori solide'),
              ],
            ),
            _opportunity(
              match: _match(
                id: 'tomorrow',
                homeName: 'Tomorrow Home',
                awayName: 'Tomorrow Away',
                kickoff: tomorrowKickoff,
                kickoffLabel: '20:00',
              ),
              retainedTheses: [
                _thesis(id: 'solid_favorite', title: 'Favori solide'),
              ],
            ),
          ],
        ),
      );

      expect(find.text('Today Home'), findsOneWidget);
      expect(find.text('Tomorrow Home'), findsNothing);

      await tester.tap(find.text(_calendarDateLabel(tomorrowKickoff)).first);
      await tester.pumpAndSettle();

      expect(find.text('Today Home'), findsNothing);
      expect(find.text('Tomorrow Home'), findsOneWidget);
    });

    testWidgets('For me sort menu can order readings by kickoff', (
      tester,
    ) async {
      final today = _relativeKickoff(0, hour: 0);
      final market = _doubleChanceMarket();
      final recommended = RecommendedMarket(
        market: market,
        selection: market.selections.first,
      );

      await _pumpPage(
        tester,
        profile: _completedProfile(),
        repository: _FakeMatchFeedRepository(
          opportunities: [
            _opportunity(
              match: _match(
                id: 'strong-late',
                homeName: 'Strong Late',
                awayName: 'Away',
                kickoff: DateTime(today.year, today.month, today.day, 21),
                kickoffLabel: '21:00',
              ),
              engineScore: 95,
              retainedTheses: [
                _thesis(
                  id: 'solid_favorite',
                  title: 'Favori solide',
                  recommendedMarket: recommended,
                  status: MatchThesisStatus.recommended,
                ),
              ],
              recommendedMarket: recommended,
            ),
            _opportunity(
              match: _match(
                id: 'early',
                homeName: 'Early Match',
                awayName: 'Away',
                kickoff: DateTime(today.year, today.month, today.day, 14),
                kickoffLabel: '14:00',
              ),
              engineScore: 50,
              retainedTheses: [
                _thesis(
                  id: 'solid_favorite',
                  title: 'Favori solide',
                  recommendedMarket: recommended,
                  status: MatchThesisStatus.recommended,
                ),
              ],
              recommendedMarket: recommended,
            ),
          ],
        ),
      );

      expect(
        tester.getTopLeft(find.text('Strong Late').first).dy,
        lessThan(tester.getTopLeft(find.text('Early Match').first).dy),
      );

      await tester.tap(find.text('Trier'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Heure').last);
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.text('Early Match').first).dy,
        lessThan(tester.getTopLeft(find.text('Strong Late').first).dy),
      );
    });

    testWidgets('opens opportunity detail with decision-first hierarchy', (
      tester,
    ) async {
      final market = _doubleChanceMarket();
      final recommended = RecommendedMarket(
        market: market,
        selection: market.selections.first,
      );
      final opportunity = _opportunity(
        retainedTheses: [
          _thesis(
            id: 'solid_favorite',
            title: 'Favori solide',
            recommendedMarket: recommended,
            status: MatchThesisStatus.recommended,
            arguments: const [
              CopilotArgument(
                id: 'ranking_gap',
                type: CopilotArgumentType.rankingGap,
                family: CopilotArgumentFamily.hierarchy,
                severity: CopilotArgumentSeverity.strong,
                subjectName: 'Home',
                parameters: {'pointsGap': 11, 'played': 18},
                evidence: [
                  ThesisEvidence(
                    label: 'Home possède 11 points d’avance.',
                    tone: ThesisEvidenceTone.positive,
                  ),
                ],
                evidenceAction: CopilotEvidenceAction.standings,
              ),
              CopilotArgument(
                id: 'away_form_warning',
                type: CopilotArgumentType.contradiction,
                family: CopilotArgumentFamily.contradiction,
                severity: CopilotArgumentSeverity.moderate,
                subjectName: 'Away',
                parameters: {'wins': 3, 'played': 5},
                evidence: [
                  ThesisEvidence(
                    label: 'Away reste sur 3 victoires en 5 matchs.',
                    tone: ThesisEvidenceTone.warning,
                  ),
                ],
                evidenceAction: CopilotEvidenceAction.form,
              ),
            ],
          ),
          _thesis(
            id: 'ranking_gap',
            title: 'Écart de niveau',
            recommendedMarket: recommended,
            status: MatchThesisStatus.recommended,
          ),
        ],
        compatibleMarkets: [
          OpportunityMarketCompatibility(
            thesisId: 'solid_favorite',
            market: market,
            selection: market.selections.first,
            isRecommended: true,
          ),
        ],
        recommendedMarket: recommended,
      );

      await _pumpPage(
        tester,
        profile: _completedProfile(),
        repository: _FakeMatchFeedRepository(opportunities: [opportunity]),
      );

      await tester.tap(find.text('Home').first);
      await tester.pumpAndSettle();

      expect(find.text('Lecture Copilot'), findsOneWidget);
      expect(find.text('Lectures simples retenues'), findsOneWidget);
      await tester.tap(find.text('Lecture Copilot'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Lecture combinée validée par 1 argument convergent et 1 point de vigilance.',
        ),
        findsOneWidget,
      );
      expect(find.text('FAVORI SOLIDE CONFIRMÉ'), findsOneWidget);
      await tester.tap(find.text('Lectures simples retenues'));
      await tester.pumpAndSettle();
      expect(find.text('Écart de niveau'), findsOneWidget);
      expect(find.text('Lectures retenues'), findsOneWidget);
      expect(find.text('Points de vigilance'), findsOneWidget);
      expect(find.text('Home possède 11 points d’avance.'), findsOneWidget);
      expect(find.textContaining('api-team-'), findsNothing);
      expect(find.text('Marchés et cotes'), findsOneWidget);
      await tester.ensureVisible(find.text('Marchés et cotes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Marchés et cotes'));
      await tester.pumpAndSettle();
      expect(find.text('Pourquoi ce marché ?'), findsOneWidget);
      expect(find.text('Vérifier les données'), findsOneWidget);
      expect(find.text('Cotes disponibles'), findsOneWidget);
    });

    testWidgets(
      'match detail groups reading proofs and verifies available data',
      (tester) async {
        final market = _doubleChanceMarket();
        final recommended = RecommendedMarket(
          market: market,
          selection: market.selections.first,
        );
        final opportunity = _opportunity(
          match: _match(analysis: _analysisData()),
          retainedTheses: [
            _thesis(
              id: 'open_match',
              title: 'Match ouvert',
              recommendedMarket: recommended,
              status: MatchThesisStatus.recommended,
              arguments: const [
                CopilotArgument(
                  id: 'open_home',
                  type: CopilotArgumentType.openMatch,
                  family: CopilotArgumentFamily.rhythm,
                  severity: CopilotArgumentSeverity.strong,
                  subjectName: 'Home',
                  parameters: {'climate': 3.1},
                  evidence: [
                    ThesisEvidence(
                      label: 'Home marque et encaisse régulièrement.',
                      tone: ThesisEvidenceTone.positive,
                    ),
                  ],
                  evidenceAction: CopilotEvidenceAction.rhythm,
                ),
                CopilotArgument(
                  id: 'open_away',
                  type: CopilotArgumentType.openMatch,
                  family: CopilotArgumentFamily.rhythm,
                  severity: CopilotArgumentSeverity.moderate,
                  subjectName: 'Away',
                  parameters: {'climate': 2.9},
                  evidence: [
                    ThesisEvidence(
                      label: 'Away participe à des matchs ouverts.',
                      tone: ThesisEvidenceTone.positive,
                    ),
                  ],
                  evidenceAction: CopilotEvidenceAction.rhythm,
                ),
              ],
            ),
          ],
          compatibleMarkets: [
            OpportunityMarketCompatibility(
              thesisId: 'open_match',
              market: market,
              selection: market.selections.first,
              isRecommended: true,
            ),
            OpportunityMarketCompatibility(
              thesisId: 'open_match',
              market: market,
              selection: market.selections.last,
              isRecommended: false,
            ),
          ],
          recommendedMarket: recommended,
        );

        await _pumpPage(
          tester,
          profile: _completedProfile(),
          repository: _FakeMatchFeedRepository(opportunities: [opportunity]),
        );

        await tester.tap(find.text('Home').first);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Lectures simples retenues'));
        await tester.pumpAndSettle();
        expect(find.text('Match ouvert'), findsWidgets);
        expect(
          find.text('Home marque et encaisse régulièrement.'),
          findsOneWidget,
        );
        expect(
          find.text('Away participe à des matchs ouverts.'),
          findsOneWidget,
        );
        expect(find.textContaining('api-team-'), findsNothing);

        await tester.scrollUntilVisible(
          find.text('Vérifier les données'),
          260,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Vérifier les données'));
        await tester.pumpAndSettle();

        expect(find.text('Classement'), findsOneWidget);
        expect(find.text('Forme (5 matchs)'), findsOneWidget);
        expect(find.text('Domicile / Extérieur'), findsOneWidget);
        expect(find.text('Attaque / Défense'), findsOneWidget);
        expect(find.text('Séries'), findsOneWidget);
        expect(find.text('Places d’écart'), findsOneWidget);

        await tester.tap(find.text('Forme (5 matchs)'));
        await tester.pumpAndSettle();
        expect(find.text('Adversaire'), findsWidgets);
        expect(find.text('Lieu'), findsWidgets);
        expect(find.text('Score'), findsWidgets);
        expect(find.text('Résultat'), findsWidgets);
        expect(find.text('Sirius'), findsOneWidget);
        expect(find.text('1-2'), findsWidgets);
        expect(find.text('1V'), findsOneWidget);
        expect(find.text('3D'), findsOneWidget);
        expect(find.text('Buts marqués : 5 (1.00/m)'), findsOneWidget);
        expect(find.text('Buts encaissés : 9 (1.80/m)'), findsOneWidget);

        await tester.tap(find.text('Attaque / Défense'));
        await tester.pumpAndSettle();
        expect(find.text('Buts marqués / match'), findsOneWidget);
        expect(find.text('xG'), findsOneWidget);
        expect(find.text('xGA'), findsOneWidget);

        await tester.ensureVisible(find.text('Marchés et cotes'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Marchés et cotes'));
        await tester.pumpAndSettle();
        expect(find.text('Autres marchés compatibles'), findsOneWidget);
      },
    );

    testWidgets('opens match detail from All matches', (tester) async {
      final market = _doubleChanceMarket();
      final recommended = RecommendedMarket(
        market: market,
        selection: market.selections.first,
      );

      await _pumpPage(
        tester,
        profile: _completedProfile(),
        repository: _FakeMatchFeedRepository(
          opportunities: const [],
          matches: [
            _match(
              homeName: 'Lille',
              awayName: 'Rennes',
              thesis: _thesis(
                id: 'solid_favorite',
                title: 'Favori solide',
                recommendedMarket: recommended,
                status: MatchThesisStatus.recommended,
              ),
            ),
          ],
        ),
      );

      await tester.tap(find.text('Toutes les rencontres'));
      await tester.pumpAndSettle();
      await _openAllMatchesLeague(tester);
      await tester.tap(find.text('Lille'));
      await tester.pumpAndSettle();

      expect(find.text('Lecture Copilot'), findsOneWidget);
      expect(find.text('Lectures simples retenues'), findsOneWidget);
      expect(find.text('Marchés et cotes'), findsOneWidget);
    });

    testWidgets('keeps All matches accessible', (tester) async {
      await _pumpPage(
        tester,
        profile: const DecisionProfile(onboardingVersion: 'test', answers: []),
        repository: _FakeMatchFeedRepository(opportunities: const []),
      );

      await tester.tap(find.text('Toutes les rencontres'));
      await tester.pumpAndSettle();

      expect(find.text('France'), findsWidgets);
      expect(find.text('Ligue 1'), findsNothing);
      await _openAllMatchesLeague(tester);
      expect(find.text('Home'), findsWidgets);
      expect(find.text('Away'), findsWidgets);
    });

    testWidgets('All matches surfaces an empty snapshot state', (tester) async {
      final today = _today();

      await _pumpPage(
        tester,
        profile: _completedProfile(),
        repository: _FakeMatchFeedRepository(
          opportunities: const [],
          matches: const [],
          snapshotMetadata: MatchFeedSnapshotMetadata(
            source: 'api-football',
            capturedAt: DateTime.now(),
            timezone: 'Europe/Paris',
            matchCount: 0,
            windowStart: today,
            windowEnd: today,
          ),
        ),
      );

      await tester.tap(find.text('Toutes les rencontres'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Snapshot vide'), findsOneWidget);
      expect(find.text('Aucune rencontre à cette date'), findsOneWidget);
    });

    testWidgets('All matches warns when snapshot no longer covers today', (
      tester,
    ) async {
      final staleDay = _today().subtract(const Duration(days: 3));

      await _pumpPage(
        tester,
        profile: _completedProfile(),
        repository: _FakeMatchFeedRepository(
          opportunities: const [],
          matches: const [],
          snapshotMetadata: MatchFeedSnapshotMetadata(
            source: 'api-football',
            capturedAt: staleDay,
            timezone: 'Europe/Paris',
            matchCount: 4,
            windowStart: staleDay,
            windowEnd: staleDay,
          ),
        ),
      );

      await tester.tap(find.text('Toutes les rencontres'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Aucune donnée snapshot pour le'),
        findsOneWidget,
      );
    });

    testWidgets('All matches marks a covered but stale snapshot obsolete', (
      tester,
    ) async {
      final today = _today();

      await _pumpPage(
        tester,
        profile: _completedProfile(),
        repository: _FakeMatchFeedRepository(
          opportunities: const [],
          matches: const [],
          snapshotMetadata: MatchFeedSnapshotMetadata(
            source: 'api-football',
            capturedAt: today.subtract(const Duration(days: 1)),
            timezone: 'Europe/Paris',
            matchCount: 3,
            windowStart: today,
            windowEnd: today,
          ),
        ),
      );

      await tester.tap(find.text('Toutes les rencontres'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Snapshot obsolète'), findsOneWidget);
    });

    testWidgets('All matches opens followed competitions inline', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        profile: _completedProfile(),
        repository: _FakeMatchFeedRepository(
          opportunities: const [],
          matches: [_match(homeName: 'Lille', awayName: 'Rennes')],
        ),
      );

      await tester.tap(find.text('Toutes les rencontres'));
      await tester.pumpAndSettle();

      expect(find.text('Lille'), findsNothing);
      expect(find.byTooltip('Réduire le pays'), findsNothing);

      await tester.tap(find.text('Ligue 1').first);
      await tester.pumpAndSettle();

      expect(find.text('Lille'), findsOneWidget);
      expect(find.text('Rennes'), findsOneWidget);
      expect(find.byTooltip('Réduire le pays'), findsNothing);
    });

    testWidgets(
      'All matches does not filter by profile, opportunity or odds by default',
      (tester) async {
        await _pumpPage(
          tester,
          profile: _completedProfile(),
          repository: _FakeMatchFeedRepository(
            opportunities: const [],
            matches: [
              _match(
                id: 'fixture-with-odds',
                homeName: 'Lille',
                awayName: 'Rennes',
                markets: [_matchResultMarket(), _doubleChanceMarket()],
              ),
              _match(
                id: 'fixture-without-odds',
                homeName: 'Arsenal',
                awayName: 'Tottenham Hotspur Long Name',
                countryCode: 'GB',
                countryName: 'Royaume-Uni',
                competitionId: '39',
                competitionName: 'Premier League',
                markets: const [],
              ),
            ],
          ),
        );

        await tester.tap(find.text('Toutes les rencontres'));
        await tester.pumpAndSettle();

        expect(find.text('Lille'), findsNothing);
        expect(find.text('Arsenal'), findsNothing);
        await _openAllMatchesLeague(tester);
        await _openAllMatchesLeague(
          tester,
          country: 'Royaume-Uni',
          competition: 'Premier League',
        );

        expect(find.text('Lille'), findsOneWidget);
        expect(find.text('Arsenal'), findsOneWidget);
        expect(find.text('Football'), findsOneWidget);
        expect(find.text('Mes compétitions'), findsOneWidget);
        expect(find.text('Résultat du match (1N2)'), findsNothing);
        expect(find.text('2.10'), findsOneWidget);
        expect(find.text('3.35'), findsOneWidget);
        expect(find.text('3.50'), findsOneWidget);
        expect(find.text('Cotes indisponibles'), findsOneWidget);
      },
    );

    testWidgets('All matches uses one selected market for every row', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        profile: _completedProfile(),
        repository: _FakeMatchFeedRepository(
          opportunities: const [],
          matches: [
            _match(
              id: 'lille',
              homeName: 'Lille',
              awayName: 'Rennes',
              markets: [_matchResultMarket(), _doubleChanceMarket()],
            ),
            _match(
              id: 'arsenal',
              homeName: 'Arsenal',
              awayName: 'Chelsea',
              countryCode: 'GB',
              countryName: 'Royaume-Uni',
              competitionId: '39',
              competitionName: 'Premier League',
              markets: [
                _matchResultMarket(home: 1.80, draw: 3.40, away: 4.20),
                _doubleChanceMarket(
                  homeDraw: 1.25,
                  homeAway: 1.30,
                  drawAway: 1.75,
                ),
              ],
            ),
          ],
        ),
      );

      await tester.tap(find.text('Toutes les rencontres'));
      await tester.pumpAndSettle();
      await _openAllMatchesLeague(tester);
      await _openAllMatchesLeague(
        tester,
        country: 'Royaume-Uni',
        competition: 'Premier League',
      );

      expect(find.text('1'), findsWidgets);
      expect(find.text('N'), findsWidgets);
      expect(find.text('2'), findsWidgets);
      expect(find.text('2.10'), findsOneWidget);
      expect(find.text('1.80'), findsOneWidget);
      expect(find.text('1X'), findsNothing);

      await _openAllMatchesFilters(tester);
      await tester.tap(find.text('Double chance').first);
      await tester.scrollUntilVisible(
        find.textContaining('Appliquer'),
        500,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.textContaining('Appliquer'));
      await tester.pumpAndSettle();

      expect(find.text('1X'), findsWidgets);
      expect(find.text('12'), findsWidgets);
      expect(find.text('X2'), findsWidgets);
      expect(find.text('1.42'), findsOneWidget);
      expect(find.text('1.75'), findsOneWidget);
      expect(find.text('2.10'), findsNothing);
    });

    testWidgets(
      'All matches adds the displayed market selection to Mon ticket',
      (tester) async {
        await _pumpPage(
          tester,
          profile: _completedProfile(),
          repository: _FakeMatchFeedRepository(
            opportunities: const [],
            matches: [
              _match(
                id: 'lille',
                homeName: 'Lille',
                awayName: 'Rennes',
                markets: [_matchResultMarket(), _doubleChanceMarket()],
              ),
            ],
          ),
        );

        await tester.tap(find.text('Toutes les rencontres'));
        await tester.pumpAndSettle();
        await _openAllMatchesLeague(tester);
        await tester.drag(
          find.byKey(const PageStorageKey<String>('all-matches-explorer')),
          const Offset(0, -260),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('2.10'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('3.35'));
        await tester.pumpAndSettle();

        expect(find.text('Mon ticket'), findsOneWidget);
        expect(find.text('Cote totale'), findsOneWidget);
        expect(find.text('2.10'), findsWidgets);

        await tester.tap(find.text('Mon ticket'));
        await tester.pumpAndSettle();

        expect(find.text('Lille - Rennes'), findsOneWidget);
        expect(find.text('1 (Résultat du match)'), findsOneWidget);
        expect(find.text('N (Résultat du match)'), findsNothing);
      },
    );

    testWidgets('opens match detail from Mon ticket selection', (tester) async {
      final market = _matchResultMarket();

      await _pumpPage(
        tester,
        profile: _completedProfile(),
        repository: _FakeMatchFeedRepository(
          opportunities: const [],
          matches: [
            _match(
              id: 'lille',
              homeName: 'Lille',
              awayName: 'Rennes',
              markets: [market],
              thesis: _thesis(
                id: 'solid_favorite',
                title: 'Favori solide',
                status: MatchThesisStatus.recommended,
                recommendedMarket: RecommendedMarket(
                  market: market,
                  selection: market.selections.first,
                ),
              ),
            ),
          ],
        ),
      );

      await tester.tap(find.text('Toutes les rencontres'));
      await tester.pumpAndSettle();
      await _openAllMatchesLeague(tester);
      await tester.drag(
        find.byKey(const PageStorageKey<String>('all-matches-explorer')),
        const Offset(0, -260),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('2.10'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mon ticket'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lille - Rennes'));
      await tester.pumpAndSettle();

      expect(find.text('Lecture Copilot'), findsOneWidget);
      expect(find.text('Lectures simples retenues'), findsOneWidget);
      expect(find.text('Vérifier les données'), findsOneWidget);
      await tester.tap(find.text('Lecture Copilot'));
      await tester.pumpAndSettle();
      expect(find.text('FAVORI SOLIDE'), findsOneWidget);
    });

    testWidgets('All matches does not mix bookmakers silently', (tester) async {
      await _pumpPage(
        tester,
        profile: _completedProfile(),
        repository: _FakeMatchFeedRepository(
          opportunities: const [],
          matches: [
            _match(
              id: 'unibet',
              homeName: 'Lille',
              awayName: 'Rennes',
              markets: [
                _matchResultMarket(bookmakerId: 16, bookmakerName: 'Unibet'),
              ],
            ),
            _match(
              id: 'bet365',
              homeName: 'Arsenal',
              awayName: 'Chelsea',
              markets: [
                _matchResultMarket(
                  home: 9.99,
                  draw: 8.88,
                  away: 7.77,
                  bookmakerId: 8,
                  bookmakerName: 'Bet365',
                ),
              ],
            ),
          ],
        ),
      );

      await tester.tap(find.text('Toutes les rencontres'));
      await tester.pumpAndSettle();
      await _openAllMatchesLeague(tester);

      expect(find.text('Unibet'), findsNothing);
      expect(find.text('2.10'), findsOneWidget);
      expect(find.text('9.99'), findsNothing);
      expect(find.text('Cotes indisponibles'), findsOneWidget);

      await _openAllMatchesFilters(tester);
      expect(find.text('Unibet'), findsOneWidget);
    });

    testWidgets(
      'All matches keeps followed and global competition expansion isolated',
      (tester) async {
        await _pumpPage(
          tester,
          profile: _completedProfile(),
          repository: _FakeMatchFeedRepository(
            opportunities: const [],
            matches: [
              _match(
                id: 'followed-ligue-1',
                homeName: 'Lille',
                awayName: 'Rennes',
              ),
            ],
          ),
        );

        await tester.tap(find.text('Toutes les rencontres'));
        await tester.pumpAndSettle();

        expect(find.text('Lille'), findsNothing);
        expect(find.byTooltip('Réduire le pays'), findsNothing);

        await tester.tap(find.byKey(const ValueKey('favorite-competition-61')));
        await tester.pumpAndSettle();

        expect(find.text('Lille'), findsOneWidget);
        expect(find.byTooltip('Réduire le pays'), findsNothing);

        await tester.tap(find.text('France').last);
        await tester.pumpAndSettle();

        expect(find.byTooltip('Réduire le pays'), findsOneWidget);
        expect(find.byTooltip('Réduire cette compétition'), findsNothing);
      },
    );

    testWidgets('All matches searches by team, competition and country', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        profile: _completedProfile(),
        repository: _FakeMatchFeedRepository(
          opportunities: const [],
          matches: [
            _match(homeName: 'Lille', awayName: 'Rennes'),
            _match(
              id: 'arsenal',
              homeName: 'Arsenal',
              awayName: 'Chelsea',
              countryCode: 'GB',
              countryName: 'Royaume-Uni',
              competitionId: '39',
              competitionName: 'Premier League',
            ),
          ],
        ),
      );

      await tester.tap(find.text('Toutes les rencontres'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Rechercher'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Premier League');
      await tester.pumpAndSettle();

      expect(find.text('Royaume-Uni'), findsOneWidget);
      expect(find.text('Lille'), findsNothing);

      await tester.tap(find.byTooltip('Effacer la recherche'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'France');
      await tester.pumpAndSettle();

      expect(find.text('France'), findsWidgets);
      expect(find.text('Arsenal'), findsNothing);
    });

    testWidgets('All matches applies cumulative filters and reset', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        profile: _completedProfile(),
        repository: _FakeMatchFeedRepository(
          opportunities: const [],
          matches: [
            _match(homeName: 'Lille', awayName: 'Rennes'),
            _match(
              id: 'arsenal',
              homeName: 'Arsenal',
              awayName: 'Chelsea',
              countryCode: 'GB',
              countryName: 'Royaume-Uni',
              competitionId: '39',
              competitionName: 'Premier League',
              markets: const [],
            ),
          ],
        ),
      );

      await tester.tap(find.text('Toutes les rencontres'));
      await tester.pumpAndSettle();
      await _openAllMatchesFilters(tester);
      await tester.tap(find.text('France').last);
      await tester.tap(find.text('Avec cotes'));
      await tester.tap(find.text('Double chance').last);
      await tester.scrollUntilVisible(
        find.textContaining('Appliquer'),
        500,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.textContaining('Appliquer'));
      await tester.pumpAndSettle();
      await _openAllMatchesLeague(tester);

      expect(find.text('Lille'), findsOneWidget);
      expect(find.text('Arsenal'), findsNothing);
      expect(find.byTooltip('Filtres'), findsOneWidget);

      await _openAllMatchesFilters(tester);
      await tester.tap(find.text('Réinitialiser'));
      await tester.pumpAndSettle();
      await _openAllMatchesLeague(
        tester,
        country: 'Royaume-Uni',
        competition: 'Premier League',
      );

      expect(find.text('Arsenal'), findsOneWidget);
      expect(find.byTooltip('Filtres'), findsOneWidget);
    });

    testWidgets('All matches filters live and finished states', (tester) async {
      await _pumpPage(
        tester,
        profile: _completedProfile(),
        repository: _FakeMatchFeedRepository(
          opportunities: const [],
          matches: [
            _match(
              id: 'live',
              homeName: 'Arsenal',
              awayName: 'Chelsea',
              status: FixtureStatus.live,
              kickoffLabel: "63'",
              score: const FixtureScore(home: 2, away: 1),
            ),
            _match(
              id: 'finished',
              homeName: 'Lille',
              awayName: 'Rennes',
              status: FixtureStatus.finished,
              score: const FixtureScore(home: 1, away: 0),
            ),
          ],
        ),
      );

      await tester.tap(find.text('Toutes les rencontres'));
      await tester.pumpAndSettle();
      await _openAllMatchesFilters(tester);
      await tester.tap(find.text('Live'));
      await tester.scrollUntilVisible(
        find.textContaining('Appliquer'),
        500,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.textContaining('Appliquer'));
      await tester.pumpAndSettle();
      await _openAllMatchesLeague(tester, expectedMatch: 'Arsenal');

      expect(find.text('Arsenal'), findsOneWidget);
      expect(find.text('Lille'), findsNothing);
      expect(find.text('2-1'), findsOneWidget);

      await _openAllMatchesFilters(tester);
      await tester.tap(find.text('Résultats'));
      await tester.scrollUntilVisible(
        find.textContaining('Appliquer'),
        500,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.textContaining('Appliquer'));
      await tester.pumpAndSettle();
      await _openAllMatchesLeague(tester, expectedMatch: 'Lille');

      expect(find.text('Terminé'), findsOneWidget);
      expect(find.text('Lille'), findsOneWidget);
      expect(find.text('Arsenal'), findsNothing);
    });

    testWidgets('All matches stays compact on a mobile viewport', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        profile: _completedProfile(),
        viewSize: const Size(390, 844),
        repository: _FakeMatchFeedRepository(
          opportunities: const [],
          matches: [
            _match(
              id: 'lille',
              homeName: 'Lille',
              awayName: 'Rennes',
              markets: [_matchResultMarket(), _doubleChanceMarket()],
            ),
          ],
        ),
      );

      await tester.tap(find.text('Toutes les rencontres'));
      await tester.pumpAndSettle();

      expect(find.text('Football'), findsOneWidget);
      expect(find.text('Mes compétitions'), findsOneWidget);
      expect(find.text('Toutes les compétitions'), findsOneWidget);
      expect(find.text('Tout développer'), findsNothing);
      expect(find.text('Tout réduire'), findsNothing);
      expect(find.text('Résultat du match (1N2)'), findsNothing);

      await _openAllMatchesFilters(tester);

      expect(find.text('Marché affiché'), findsOneWidget);
      expect(find.text('Bookmaker'), findsOneWidget);
      expect(find.text('État'), findsOneWidget);
    });

    testWidgets('main mobile screens render without Flutter exceptions', (
      tester,
    ) async {
      final market = _doubleChanceMarket();
      final recommended = RecommendedMarket(
        market: market,
        selection: market.selections.first,
      );
      final opportunity = _opportunity(
        retainedTheses: [
          _thesis(
            id: 'solid_favorite',
            title: 'Favori solide',
            recommendedMarket: recommended,
            status: MatchThesisStatus.recommended,
          ),
        ],
        recommendedMarket: recommended,
      );

      await _pumpPage(
        tester,
        profile: _completedProfile(),
        strategies: [_strategy()],
        viewSize: const Size(390, 844),
        repository: _FakeMatchFeedRepository(
          opportunities: [opportunity],
          matches: [
            _match(
              id: 'lille',
              homeName: 'Lille',
              awayName: 'Rennes',
              markets: [_matchResultMarket(), market],
            ),
          ],
        ),
      );

      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Générateur'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Toutes les rencontres'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await _openAllMatchesLeague(tester, expectedMatch: 'Lille');
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Lille'));
      await tester.pumpAndSettle();
      expect(find.text('Lecture Copilot'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders generated tickets grouped by strategy', (
      tester,
    ) async {
      final market = _doubleChanceMarket();
      final recommended = RecommendedMarket(
        market: market,
        selection: market.selections.first,
      );
      await _pumpPage(
        tester,
        profile: _completedProfile(),
        strategies: [_strategy()],
        repository: _FakeMatchFeedRepository(
          opportunities: [
            _opportunity(
              retainedTheses: [
                _thesis(
                  id: 'solid_favorite',
                  title: 'Favori solide',
                  recommendedMarket: recommended,
                  status: MatchThesisStatus.recommended,
                ),
              ],
              recommendedMarket: recommended,
            ),
          ],
        ),
      );

      await tester.tap(find.text('Générateur'));
      await tester.pumpAndSettle();

      expect(find.text('Générateur de tickets'), findsOneWidget);
      expect(find.text('Propositions Copilot'), findsOneWidget);
      expect(find.textContaining('Valeur :'), findsNothing);
      expect(find.text('Stratégie : Safe'), findsOneWidget);
      expect(find.text('Généré par Copilot'), findsOneWidget);
      expect(find.text('Cote totale'), findsOneWidget);
      expect(find.text('Sélections'), findsNothing);
      expect(find.text('Home — Away'), findsOneWidget);
      expect(find.text('Double chance'), findsOneWidget);
      expect(find.text('1X'), findsOneWidget);
      expect(find.text('Enregistrer'), findsOneWidget);
      expect(find.text('Modifier'), findsOneWidget);
      expect(find.text('Gain potentiel'), findsNothing);
      expect(find.textContaining('Confiance'), findsNothing);
      expect(find.textContaining('Score'), findsNothing);
    });

    testWidgets('saves Copilot and modified tickets into history', (
      tester,
    ) async {
      final market = _doubleChanceMarket();
      final recommended = RecommendedMarket(
        market: market,
        selection: market.selections.first,
      );
      await _pumpPage(
        tester,
        profile: _completedProfile(),
        strategies: [
          _strategy(
            minimumSelections: 2,
            maximumSelections: 2,
            maximumTotalOdds: 3,
          ),
        ],
        repository: _FakeMatchFeedRepository(
          opportunities: [
            _opportunity(
              match: _match(
                id: 'fixture-a',
                homeName: 'Home A',
                awayName: 'Away A',
              ),
              retainedTheses: [
                _thesis(
                  id: 'solid_favorite',
                  title: 'Favori solide',
                  recommendedMarket: recommended,
                  status: MatchThesisStatus.recommended,
                ),
              ],
              recommendedMarket: recommended,
            ),
            _opportunity(
              match: _match(
                id: 'fixture-b',
                homeName: 'Home B',
                awayName: 'Away B',
              ),
              retainedTheses: [
                _thesis(
                  id: 'solid_favorite',
                  title: 'Favori solide',
                  recommendedMarket: recommended,
                  status: MatchThesisStatus.recommended,
                ),
              ],
              recommendedMarket: recommended,
            ),
          ],
        ),
      );

      await tester.tap(find.text('Générateur'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Historique'));
      await tester.pumpAndSettle();

      expect(find.text('Ticket Copilot'), findsOneWidget);
      await tester.tap(find.byTooltip('Fermer'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Modifier').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enregistrer la version modifiée'));
      await tester.pumpAndSettle();
      await _tapModifiedTicketsTab(tester);

      expect(find.text('Ticket Copilot modifié'), findsOneWidget);
      expect(find.text('1 sélection supprimée'), findsOneWidget);
      expect(
        find.text('Sélection supprimée : Home A - Away A'),
        findsOneWidget,
      );
    });

    testWidgets(
      'modified ticket editor replaces a compatible market and recalculates odds',
      (tester) async {
        final market = _doubleChanceMarket();
        final recommended = RecommendedMarket(
          market: market,
          selection: market.selections.first,
        );
        await _pumpPage(
          tester,
          profile: _completedProfile(),
          strategies: [
            _strategy(
              minimumSelections: 2,
              maximumSelections: 2,
              maximumTotalOdds: 3,
            ),
          ],
          repository: _FakeMatchFeedRepository(
            opportunities: [
              _opportunity(
                match: _match(
                  id: 'fixture-a',
                  homeName: 'Home A',
                  awayName: 'Away A',
                ),
                retainedTheses: [
                  _thesis(
                    id: 'solid_favorite',
                    title: 'Favori solide',
                    recommendedMarket: recommended,
                    status: MatchThesisStatus.recommended,
                  ),
                ],
                compatibleMarkets: _compatibleMarkets(market),
                recommendedMarket: recommended,
              ),
              _opportunity(
                match: _match(
                  id: 'fixture-b',
                  homeName: 'Home B',
                  awayName: 'Away B',
                ),
                retainedTheses: [
                  _thesis(
                    id: 'solid_favorite',
                    title: 'Favori solide',
                    recommendedMarket: recommended,
                    status: MatchThesisStatus.recommended,
                  ),
                ],
                compatibleMarkets: _compatibleMarkets(market),
                recommendedMarket: recommended,
              ),
            ],
          ),
        );

        await tester.tap(find.text('Générateur'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(OutlinedButton, 'Modifier').first);
        await tester.pumpAndSettle();

        expect(find.text('Cote totale 2.02'), findsOneWidget);
        expect(find.text('Conforme à Safe'), findsOneWidget);

        await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Double chance · 12 · 1.35').last);
        await tester.pumpAndSettle();

        expect(find.text('Cote totale 1.92'), findsOneWidget);
        await tester.tap(find.text('Enregistrer la version modifiée'));
        await tester.pumpAndSettle();
        await _tapModifiedTicketsTab(tester);

        expect(find.text('Ticket Copilot modifié'), findsOneWidget);
        expect(find.text('1 marché remplacé'), findsOneWidget);
        expect(
          find.text(
            'Marché remplacé : Home A - Away A · Double chance 1X → Double chance 12',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'modified ticket editor replaces a selection with another compatible opportunity',
      (tester) async {
        final market = _doubleChanceMarket();
        final thirdMarket = _doubleChanceMarket(homeDraw: 1.35);
        final recommended = RecommendedMarket(
          market: market,
          selection: market.selections.first,
        );
        final thirdRecommended = RecommendedMarket(
          market: thirdMarket,
          selection: thirdMarket.selections.first,
        );
        await _pumpPage(
          tester,
          profile: _completedProfile(),
          strategies: [
            _strategy(
              minimumSelections: 2,
              maximumSelections: 2,
              maximumTotalOdds: 3,
            ),
          ],
          repository: _FakeMatchFeedRepository(
            opportunities: [
              _opportunity(
                match: _match(
                  id: 'fixture-a',
                  homeName: 'Home A',
                  awayName: 'Away A',
                ),
                retainedTheses: [
                  _thesis(
                    id: 'solid_favorite',
                    title: 'Favori solide',
                    recommendedMarket: recommended,
                    status: MatchThesisStatus.recommended,
                  ),
                ],
                compatibleMarkets: _compatibleMarkets(market),
                recommendedMarket: recommended,
              ),
              _opportunity(
                match: _match(
                  id: 'fixture-b',
                  homeName: 'Home B',
                  awayName: 'Away B',
                ),
                retainedTheses: [
                  _thesis(
                    id: 'solid_favorite',
                    title: 'Favori solide',
                    recommendedMarket: recommended,
                    status: MatchThesisStatus.recommended,
                  ),
                ],
                compatibleMarkets: _compatibleMarkets(market),
                recommendedMarket: recommended,
              ),
              _opportunity(
                match: _match(
                  id: 'fixture-c',
                  homeName: 'Home C',
                  awayName: 'Away C',
                ),
                retainedTheses: [
                  _thesis(
                    id: 'solid_favorite',
                    title: 'Favori solide',
                    recommendedMarket: thirdRecommended,
                    status: MatchThesisStatus.recommended,
                  ),
                ],
                compatibleMarkets: _compatibleMarkets(thirdMarket),
                recommendedMarket: thirdRecommended,
              ),
            ],
          ),
        );

        await tester.tap(find.text('Générateur'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(OutlinedButton, 'Modifier').first);
        await tester.pumpAndSettle();

        await tester.tap(find.byType(DropdownButtonFormField<String>).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ligue 1 · Home C - Away C').last);
        await tester.pumpAndSettle();

        expect(find.text('Cote totale 1.92'), findsOneWidget);
        await tester.tap(find.text('Enregistrer la version modifiée'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Historique'));
        await tester.pumpAndSettle();
        await _tapModifiedTicketsTab(tester);

        expect(find.text('Ticket Copilot modifié'), findsOneWidget);
        expect(find.text('1 rencontre remplacée'), findsOneWidget);
      },
    );

    testWidgets('modified tickets can be edited again from the modified tab', (
      tester,
    ) async {
      final market = _doubleChanceMarket();
      final recommended = RecommendedMarket(
        market: market,
        selection: market.selections.first,
      );
      await _pumpPage(
        tester,
        profile: _completedProfile(),
        strategies: [
          _strategy(
            minimumSelections: 2,
            maximumSelections: 2,
            maximumTotalOdds: 3,
          ),
        ],
        repository: _FakeMatchFeedRepository(
          opportunities: [
            _opportunity(
              match: _match(
                id: 'fixture-a',
                homeName: 'Home A',
                awayName: 'Away A',
              ),
              retainedTheses: [
                _thesis(
                  id: 'solid_favorite',
                  title: 'Favori solide',
                  recommendedMarket: recommended,
                  status: MatchThesisStatus.recommended,
                ),
              ],
              compatibleMarkets: _compatibleMarkets(market),
              recommendedMarket: recommended,
            ),
            _opportunity(
              match: _match(
                id: 'fixture-b',
                homeName: 'Home B',
                awayName: 'Away B',
              ),
              retainedTheses: [
                _thesis(
                  id: 'solid_favorite',
                  title: 'Favori solide',
                  recommendedMarket: recommended,
                  status: MatchThesisStatus.recommended,
                ),
              ],
              compatibleMarkets: _compatibleMarkets(market),
              recommendedMarket: recommended,
            ),
          ],
        ),
      );

      await tester.tap(find.text('Générateur'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Modifier').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Double chance · 12 · 1.35').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enregistrer la version modifiée'));
      await tester.pumpAndSettle();

      await _tapModifiedTicketsTab(tester);
      await tester.pumpAndSettle();
      expect(find.text('Mes tickets modifiés'), findsOneWidget);
      expect(find.text('Ticket Copilot modifié'), findsOneWidget);

      await tester.tap(find.byTooltip('Modifier le ticket'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Double chance · X2 · 1.68').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enregistrer la version modifiée'));
      await tester.pumpAndSettle();

      expect(find.text('Ticket Copilot modifié'), findsOneWidget);
      expect(find.text('1 marché remplacé'), findsOneWidget);
      expect(find.textContaining('X2'), findsWidgets);
    });

    testWidgets('opens history and performance screen from generator', (
      tester,
    ) async {
      final market = _doubleChanceMarket();
      final recommended = RecommendedMarket(
        market: market,
        selection: market.selections.first,
      );
      await _pumpPage(
        tester,
        profile: _completedProfile(),
        strategies: [_strategy()],
        repository: _FakeMatchFeedRepository(
          opportunities: [
            _opportunity(
              retainedTheses: [
                _thesis(
                  id: 'solid_favorite',
                  title: 'Favori solide',
                  recommendedMarket: recommended,
                  status: MatchThesisStatus.recommended,
                ),
              ],
              recommendedMarket: recommended,
            ),
          ],
        ),
      );

      await tester.tap(find.text('Générateur'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Historique'));
      await tester.pumpAndSettle();

      expect(find.text('Historique & performances'), findsOneWidget);
      expect(find.text('Aucun ticket dans l’historique'), findsOneWidget);
      expect(find.text('Ticket Copilot'), findsNothing);
      expect(find.byTooltip('Fermer'), findsOneWidget);
      expect(find.text('Exporter'), findsNothing);

      await tester.tap(find.byTooltip('Fermer'));
      await tester.pumpAndSettle();

      expect(find.text('Historique & performances'), findsNothing);
      expect(find.text('Générateur de tickets'), findsOneWidget);
    });

    testWidgets('shows no active strategy state', (tester) async {
      await _pumpPage(
        tester,
        profile: _completedProfile(),
        repository: _FakeMatchFeedRepository(opportunities: const []),
      );

      await tester.tap(find.text('Générateur'));
      await tester.pumpAndSettle();

      expect(find.text('Aucune stratégie active'), findsOneWidget);
      expect(find.text('Gérer mes stratégies'), findsOneWidget);
    });

    testWidgets('ignores inactive strategies for Copilot generation', (
      tester,
    ) async {
      final market = _doubleChanceMarket();
      final recommended = RecommendedMarket(
        market: market,
        selection: market.selections.first,
      );

      await _pumpPage(
        tester,
        profile: _completedProfile(),
        strategies: [_strategy(isActive: false)],
        repository: _FakeMatchFeedRepository(
          opportunities: [
            _opportunity(
              retainedTheses: [
                _thesis(
                  id: 'solid_favorite',
                  title: 'Favori solide',
                  recommendedMarket: recommended,
                  status: MatchThesisStatus.recommended,
                ),
              ],
              recommendedMarket: recommended,
            ),
          ],
        ),
      );

      await tester.tap(find.text('Générateur'));
      await tester.pumpAndSettle();

      expect(find.text('Aucune stratégie active'), findsOneWidget);
      expect(find.text('Propositions d’aujourd’hui'), findsNothing);
      expect(find.text('Enregistrer'), findsNothing);
    });

    testWidgets('shows invalid strategy without relaxing constraints', (
      tester,
    ) async {
      final market = _doubleChanceMarket();
      final recommended = RecommendedMarket(
        market: market,
        selection: market.selections.first,
      );

      await _pumpPage(
        tester,
        profile: _completedProfile(),
        strategies: [_strategy(minimumSelections: 3, maximumSelections: 2)],
        repository: _FakeMatchFeedRepository(
          opportunities: [
            _opportunity(
              retainedTheses: [
                _thesis(
                  id: 'solid_favorite',
                  title: 'Favori solide',
                  recommendedMarket: recommended,
                  status: MatchThesisStatus.recommended,
                ),
              ],
              recommendedMarket: recommended,
            ),
          ],
        ),
      );

      await tester.tap(find.text('Générateur'));
      await tester.pumpAndSettle();

      expect(
        find.text('Cette stratégie possède une configuration invalide.'),
        findsOneWidget,
      );
      expect(find.text('Propositions d’aujourd’hui'), findsNothing);
      expect(find.text('Enregistrer'), findsNothing);
    });

    testWidgets('switches ticket origin tabs to empty states', (tester) async {
      await _pumpPage(
        tester,
        profile: _completedProfile(),
        strategies: [_strategy()],
        repository: _FakeMatchFeedRepository(opportunities: const []),
      );

      await tester.tap(find.text('Générateur'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mes modifications'));
      await tester.pumpAndSettle();
      expect(find.text('Aucun ticket modifié'), findsOneWidget);

      await tester.tap(find.text('Mes tickets'));
      await tester.pumpAndSettle();
      expect(find.text('Aucun ticket manuel'), findsOneWidget);
    });

    testWidgets('shows all generated picks and expands key readings', (
      tester,
    ) async {
      final market = _doubleChanceMarket();
      final recommended = RecommendedMarket(
        market: market,
        selection: market.selections.first,
      );
      await _pumpPage(
        tester,
        profile: _completedProfile(),
        strategies: [
          _strategy(
            minimumSelections: 4,
            maximumSelections: 4,
            maximumTotalOdds: 5,
          ),
        ],
        repository: _FakeMatchFeedRepository(
          opportunities: [
            for (var index = 1; index <= 4; index++)
              _opportunity(
                match: _match(id: 'fixture-$index', homeName: 'Home $index'),
                retainedTheses: [
                  _thesis(
                    id: 'solid_favorite',
                    title: 'Favori solide',
                    recommendedMarket: recommended,
                    status: MatchThesisStatus.recommended,
                  ),
                ],
                recommendedMarket: recommended,
              ),
          ],
        ),
      );

      await tester.tap(find.text('Générateur'));
      await tester.pumpAndSettle();

      expect(find.text('Home 1 — Away'), findsOneWidget);
      expect(find.text('Home 2 — Away'), findsOneWidget);
      expect(find.text('Home 3 — Away'), findsOneWidget);
      expect(find.text('Home 4 — Away'), findsOneWidget);
      expect(find.text('+1 autre sélection'), findsNothing);
      expect(find.text('1 lecture clé'), findsOneWidget);
      expect(find.text('Favoris solides'), findsNothing);

      await tester.tap(find.text('1 lecture clé'));
      await tester.pumpAndSettle();

      expect(find.text('Favoris solides'), findsOneWidget);
    });

    testWidgets('explains readings and combined readings in generator help', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        profile: _completedProfile(),
        strategies: [_strategy()],
        repository: _FakeMatchFeedRepository(opportunities: const []),
      );

      await tester.tap(find.text('Générateur'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Comment ça fonctionne ?').last);
      await tester.tap(find.text('Comment ça fonctionne ?').last);
      await tester.pumpAndSettle();

      expect(find.text('Lectures'), findsOneWidget);
      expect(find.text('Lectures combinées'), findsOneWidget);
      expect(
        find.textContaining('Une lecture est un signal simple'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Faites glisser pour voir toutes les familles'),
        findsOneWidget,
      );
      expect(find.text('Ce que cela signifie'), findsOneWidget);

      await tester.tap(find.text('Lectures combinées'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Une lecture combinée apparaît'),
        findsOneWidget,
      );
      expect(find.text('Quand est-elle validée ?'), findsOneWidget);
      expect(find.text('Votre configuration'), findsOneWidget);
    });

    testWidgets('Mon ticket shows three rows then expands long tickets', (
      tester,
    ) async {
      final market = _doubleChanceMarket();
      final recommended = RecommendedMarket(
        market: market,
        selection: market.selections.first,
      );
      await _pumpPage(
        tester,
        profile: _completedProfile(),
        repository: _FakeMatchFeedRepository(
          opportunities: [
            for (var index = 1; index <= 4; index++)
              _opportunity(
                match: _match(id: 'fixture-$index', homeName: 'Home $index'),
                retainedTheses: [
                  _thesis(
                    id: 'solid_favorite',
                    title: 'Favori solide',
                    recommendedMarket: recommended,
                    status: MatchThesisStatus.recommended,
                  ),
                ],
                recommendedMarket: recommended,
              ),
          ],
        ),
      );

      for (var index = 0; index < 4; index++) {
        final addButton = find.byTooltip('Ajouter au ticket').first;
        await tester.ensureVisible(addButton);
        await tester.pumpAndSettle();
        await tester.tap(addButton);
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('Mon ticket'));
      await tester.pumpAndSettle();

      expect(find.text('Home 1 - Away'), findsOneWidget);
      expect(find.text('Home 2 - Away'), findsOneWidget);
      expect(find.text('Home 3 - Away'), findsOneWidget);
      expect(find.text('Home 4 - Away'), findsNothing);
      expect(find.text('Voir 1 sélection supplémentaire'), findsOneWidget);

      await tester.tap(find.text('Voir 1 sélection supplémentaire'));
      await tester.pumpAndSettle();

      expect(find.text('Home 4 - Away'), findsOneWidget);
      expect(find.text('Réduire'), findsOneWidget);
    });
  });
}

Future<void> _openAllMatchesLeague(
  WidgetTester tester, {
  String country = 'France',
  String competition = 'Ligue 1',
  String? expectedMatch,
}) async {
  if (expectedMatch != null && find.text(expectedMatch).evaluate().isNotEmpty) {
    return;
  }

  await _scrollAllMatchesToTop(tester);
  await tester.scrollUntilVisible(
    find.text(country),
    260,
    scrollable: _allMatchesScrollable(),
  );
  await tester.pumpAndSettle();

  final countryFinder = find.text(country).first;
  await tester.ensureVisible(countryFinder);
  await tester.pumpAndSettle();

  if (find.text(competition).evaluate().isEmpty) {
    await tester.tap(countryFinder);
    await tester.pumpAndSettle();
  }

  final competitionFinder = find.text(competition).first;
  await tester.ensureVisible(competitionFinder);
  await tester.pumpAndSettle();

  if (expectedMatch == null || find.text(expectedMatch).evaluate().isEmpty) {
    await tester.tap(competitionFinder);
    await tester.pumpAndSettle();
  }

  if (expectedMatch != null && find.text(expectedMatch).evaluate().isNotEmpty) {
    await tester.ensureVisible(find.text(expectedMatch).first);
    await tester.pumpAndSettle();
  }
}

Future<void> _openAllMatchesFilters(WidgetTester tester) async {
  await _scrollAllMatchesToTop(tester);
  await tester.tap(find.byTooltip('Filtres'));
  await tester.pumpAndSettle();
}

Future<void> _scrollAllMatchesToTop(WidgetTester tester) async {
  final scrollable = _allMatchesScrollable();
  for (var index = 0; index < 4; index++) {
    await tester.drag(scrollable, const Offset(0, 700));
    await tester.pumpAndSettle();
  }
}

Finder _allMatchesScrollable() {
  return find
      .descendant(
        of: find.byKey(const PageStorageKey<String>('all-matches-explorer')),
        matching: find.byType(Scrollable),
      )
      .first;
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required DecisionProfile profile,
  required MatchFeedRepository repository,
  List<TicketStrategy> strategies = const [],
  Size viewSize = const Size(1200, 900),
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
      theme: ThemeData.dark().copyWith(splashFactory: NoSplash.splashFactory),
      home: MatchesHomePage(
        profile: profile,
        ticketStrategies: strategies,
        repositoryOverride: repository,
        onEditProfile: () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapModifiedTicketsTab(WidgetTester tester) async {
  final compactTab = find.text('Modifiés');
  if (compactTab.evaluate().isNotEmpty) {
    await tester.tap(compactTab.first);
  } else {
    await tester.tap(find.text('Mes modifications').first);
  }
  await tester.pumpAndSettle();
}

TicketStrategy _strategy({
  bool isActive = true,
  int minimumSelections = 1,
  int maximumSelections = 2,
  double minimumTotalOdds = 1.20,
  double? maximumTotalOdds = 2,
}) {
  final now = DateTime.utc(2026, 8, 2, 12);
  return TicketStrategy(
    schemaVersion: TicketStrategy.currentSchemaVersion,
    id: 'safe',
    userId: 'user',
    name: 'Safe',
    isActive: isActive,
    pickTypes: const [PickType.prudent],
    minimumIndividualOdds: 1.20,
    maximumIndividualOdds: 1.49,
    minimumSelections: minimumSelections,
    maximumSelections: maximumSelections,
    minimumTotalOdds: minimumTotalOdds,
    maximumTotalOdds: maximumTotalOdds,
    priority: 1,
    createdAt: now,
    updatedAt: now,
  );
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
        orderedOptionIds: ['solid_favorite', 'ranking_gap'],
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

List<OpportunityMarketCompatibility> _compatibleMarkets(MatchMarket market) {
  return [
    for (final selection in market.selections)
      OpportunityMarketCompatibility(
        thesisId: 'solid_favorite',
        market: market,
        selection: selection,
        isRecommended: selection.id == market.selections.first.id,
      ),
  ];
}

MatchThesis _thesis({
  required String id,
  required String title,
  MatchThesisStatus status = MatchThesisStatus.watchlist,
  RecommendedMarket? recommendedMarket,
  List<CopilotArgument> arguments = const [],
}) {
  return MatchThesis(
    id: id,
    title: title,
    summary: 'Lecture Copilot claire pour cette rencontre.',
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
    arguments: arguments,
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

MatchAnalysisData _analysisData() {
  return MatchAnalysisData(
    homeStanding: const TeamStandingSnapshot(
      teamId: 1,
      teamName: 'Home',
      rank: 13,
      points: 16,
      played: 16,
      goalsFor: 17,
      goalsAgainst: 22,
      goalDiff: -5,
      form: 'WWDLLW',
    ),
    awayStanding: const TeamStandingSnapshot(
      teamId: 2,
      teamName: 'Away',
      rank: 10,
      points: 18,
      played: 16,
      goalsFor: 18,
      goalsAgainst: 19,
      goalDiff: -1,
      form: 'LDWWWL',
    ),
    homeRecentLeagueMatches: const [
      TeamRecentMatchSnapshot(
        opponentName: 'Sirius',
        venue: RecentMatchVenue.home,
        result: 'L',
        goalsFor: 1,
        goalsAgainst: 2,
      ),
      TeamRecentMatchSnapshot(
        opponentName: 'Hammarby',
        venue: RecentMatchVenue.away,
        result: 'D',
        goalsFor: 1,
        goalsAgainst: 1,
      ),
      TeamRecentMatchSnapshot(
        opponentName: 'AIK',
        venue: RecentMatchVenue.home,
        result: 'L',
        goalsFor: 0,
        goalsAgainst: 3,
      ),
      TeamRecentMatchSnapshot(
        opponentName: 'Häcken',
        venue: RecentMatchVenue.away,
        result: 'L',
        goalsFor: 1,
        goalsAgainst: 2,
      ),
      TeamRecentMatchSnapshot(
        opponentName: 'Norrköping',
        venue: RecentMatchVenue.home,
        result: 'W',
        goalsFor: 2,
        goalsAgainst: 1,
      ),
    ],
    awayRecentLeagueMatches: const [
      TeamRecentMatchSnapshot(
        opponentName: 'Örebro SK',
        venue: RecentMatchVenue.away,
        result: 'L',
        goalsFor: 0,
        goalsAgainst: 1,
      ),
      TeamRecentMatchSnapshot(
        opponentName: 'Västerås SK',
        venue: RecentMatchVenue.home,
        result: 'W',
        goalsFor: 1,
        goalsAgainst: 0,
      ),
      TeamRecentMatchSnapshot(
        opponentName: 'BP',
        venue: RecentMatchVenue.away,
        result: 'D',
        goalsFor: 2,
        goalsAgainst: 2,
      ),
      TeamRecentMatchSnapshot(
        opponentName: 'Mjällby AIF',
        venue: RecentMatchVenue.home,
        result: 'W',
        goalsFor: 3,
        goalsAgainst: 1,
      ),
      TeamRecentMatchSnapshot(
        opponentName: 'Helsingborgs IF',
        venue: RecentMatchVenue.away,
        result: 'L',
        goalsFor: 0,
        goalsAgainst: 1,
      ),
    ],
    homeStatistics: const TeamStatisticsSnapshot(
      teamId: 1,
      teamName: 'Home',
      form: 'WWDLLW',
      playedHome: 8,
      winsHome: 4,
      drawsHome: 2,
      lossesHome: 2,
      goalsForHome: 12,
      goalsAgainstHome: 7,
      goalsForTotal: 17,
      goalsAgainstTotal: 22,
      goalsForAverageTotal: 1.10,
      goalsAgainstAverageTotal: 1.40,
      goalsForAverageHome: 1.50,
      goalsAgainstAverageHome: 0.88,
      cleanSheetsTotal: 3,
      cleanSheetsHome: 2,
      failedToScoreTotal: 2,
      failedToScoreHome: 1,
    ),
    awayStatistics: const TeamStatisticsSnapshot(
      teamId: 2,
      teamName: 'Away',
      form: 'LDWWWL',
      playedAway: 8,
      winsAway: 2,
      drawsAway: 2,
      lossesAway: 4,
      goalsForAway: 7,
      goalsAgainstAway: 10,
      goalsForTotal: 18,
      goalsAgainstTotal: 19,
      goalsForAverageTotal: 0.90,
      goalsAgainstAverageTotal: 1.20,
      goalsForAverageAway: 0.88,
      goalsAgainstAverageAway: 1.25,
      cleanSheetsTotal: 4,
      cleanSheetsAway: 2,
      failedToScoreTotal: 3,
      failedToScoreAway: 2,
    ),
    homeExpectedGoals: TeamExpectedGoalsSnapshot(
      teamId: 1,
      teamName: 'Home',
      asOf: DateTime.utc(2026, 8, 8, 8),
      sampleSize: 5,
      rollingXgFor5: 1.35,
      rollingXgAgainst5: 1.55,
      seasonXgForAverage: 1.35,
      seasonXgAgainstAverage: 1.55,
    ),
    awayExpectedGoals: TeamExpectedGoalsSnapshot(
      teamId: 2,
      teamName: 'Away',
      asOf: DateTime.utc(2026, 8, 8, 8),
      sampleSize: 5,
      rollingXgFor5: 1.05,
      rollingXgAgainst5: 1.20,
      seasonXgForAverage: 1.05,
      seasonXgAgainstAverage: 1.20,
    ),
  );
}

DateTime _relativeKickoff(int dayOffset, {required int hour}) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + dayOffset, hour);
}

String _calendarDateLabel(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}';
}

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

MatchMarket _doubleChanceMarket({
  double homeDraw = 1.42,
  double homeAway = 1.35,
  double drawAway = 1.68,
  int bookmakerId = 16,
  String bookmakerName = 'Unibet',
}) {
  return MatchMarket(
    id: 'doubleChance',
    label: 'Double chance',
    selections: [
      MarketOdds(
        id: 'double_chance_1x',
        label: '1X',
        odds: homeDraw,
        apiFootballValue: 'Home/Draw',
        bookmakerId: bookmakerId,
        bookmakerName: bookmakerName,
      ),
      MarketOdds(
        id: 'double_chance_12',
        label: '12',
        odds: homeAway,
        apiFootballValue: 'Home/Away',
        bookmakerId: bookmakerId,
        bookmakerName: bookmakerName,
      ),
      MarketOdds(
        id: 'double_chance_x2',
        label: 'X2',
        odds: drawAway,
        apiFootballValue: 'Draw/Away',
        bookmakerId: bookmakerId,
        bookmakerName: bookmakerName,
      ),
    ],
    bookmakerId: bookmakerId,
    bookmakerName: bookmakerName,
  );
}

MatchMarket _matchResultMarket({
  double home = 2.10,
  double draw = 3.35,
  double away = 3.50,
  int bookmakerId = 16,
  String bookmakerName = 'Unibet',
}) {
  return MatchMarket(
    id: 'matchResult',
    label: 'Résultat du match',
    selections: [
      MarketOdds(
        id: 'match_result_home',
        label: '1',
        odds: home,
        apiFootballValue: 'Home',
        bookmakerId: bookmakerId,
        bookmakerName: bookmakerName,
      ),
      MarketOdds(
        id: 'match_result_draw',
        label: 'N',
        odds: draw,
        apiFootballValue: 'Draw',
        bookmakerId: bookmakerId,
        bookmakerName: bookmakerName,
      ),
      MarketOdds(
        id: 'match_result_away',
        label: '2',
        odds: away,
        apiFootballValue: 'Away',
        bookmakerId: bookmakerId,
        bookmakerName: bookmakerName,
      ),
    ],
    bookmakerId: bookmakerId,
    bookmakerName: bookmakerName,
  );
}

class _FakeMatchFeedRepository implements MatchFeedRepository {
  const _FakeMatchFeedRepository({
    required this.opportunities,
    this.matches,
    this.snapshotMetadata,
  });

  final List<Opportunity> opportunities;
  final List<MatchBoardItem>? matches;

  @override
  MatchDataSourceMode get mode => MatchDataSourceMode.demo;

  @override
  final MatchFeedSnapshotMetadata? snapshotMetadata;

  @override
  List<MatchBoardItem> allMatches() => matches ?? [_match()];

  @override
  MatchBoardItem analyzeFor(DecisionProfile profile, MatchBoardItem match) {
    return match;
  }

  @override
  List<Opportunity> opportunitiesFor(DecisionProfile profile) => opportunities;

  @override
  List<MatchBoardItem> personalizedFor(DecisionProfile profile) {
    throw StateError('For me must consume opportunitiesFor directly.');
  }
}
