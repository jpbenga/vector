import 'package:copilot/core/auth/supabase_auth_controller.dart';
import 'package:copilot/core/config/app_config.dart';
import 'package:copilot/core/config/app_environment.dart';
import 'package:copilot/core/di/service_locator.dart';
import 'package:copilot/core/identity/identity_scope.dart';
import 'package:copilot/core/supabase/supabase_initializer.dart';
import 'package:copilot/core/theme/app_theme.dart';
import 'package:copilot/core/theme/app_theme_controller.dart';
import 'package:copilot/features/matches/data/match_feed_repository.dart';
import 'package:copilot/features/matches/domain/football_reading.dart';
import 'package:copilot/features/matches/domain/analysis_maturity.dart';
import 'package:copilot/features/matches/domain/match_board_item.dart';
import 'package:copilot/features/matches/domain/match_context_key_models.dart';
import 'package:copilot/features/matches/domain/structural_tiers/tier_models.dart';
import 'package:copilot/features/matches/presentation/lector_space_page.dart';
import 'package:copilot/features/matches/presentation/lector_strategies_page.dart';
import 'package:copilot/features/matches/presentation/matches_home_page.dart';
import 'package:copilot/features/matches/presentation/match_detail_page.dart';
import 'package:copilot/features/onboarding/domain/decision_profile.dart';
import 'package:copilot/features/onboarding/domain/decision_profile_catalogs.dart';
import 'package:copilot/features/onboarding/domain/onboarding_answer.dart';
import 'package:copilot/features/opportunities/domain/opportunity.dart';
import 'package:copilot/features/tickets/domain/ticket_strategy.dart';
import 'package:copilot/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
                _thesis(
                  id: 'open_match',
                  title: 'Match ouvert',
                  arguments: [
                    _argument('structural_level_gap'),
                    _argument('ranking_superiority'),
                    _argument(
                      'positive_streak',
                      type: CopilotArgumentType.strongRecentForm,
                      family: CopilotArgumentFamily.form,
                      evidenceAction: CopilotEvidenceAction.form,
                    ),
                  ],
                ),
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

      expect(find.text('À suivre aujourd’hui'), findsOneWidget);
      expect(find.text('Ma sélection'), findsNothing);
      expect(find.text('Chelsea'), findsWidgets);
      expect(find.text('Tottenham'), findsWidgets);
      expect(find.text('3 lectures'), findsOneWidget);
      expect(find.text('Écart de niveau structurel'), findsOneWidget);
      expect(find.text('Tous les matchs'), findsNothing);
    });

    testWidgets('shows only an interpretable provider round in match detail', (
      tester,
    ) async {
      await _pumpMatchDetail(
        tester,
        match: _match(round: 'Regular Season - 27'),
      );

      expect(find.text('Journée 27'), findsOneWidget);
      expect(find.text('Journée 34'), findsNothing);

      await _pumpMatchDetail(
        tester,
        match: _match(round: 'Regular Season - 8'),
      );

      expect(find.text('Journée 8'), findsOneWidget);

      await _pumpMatchDetail(tester, match: _match(round: 'Playoffs - Final'));

      expect(find.textContaining('Journée'), findsNothing);
    });

    testWidgets(
      'renders only an established opportunity pick without truncation',
      (tester) async {
        const homeName = 'Association Sportive de la Métropole Universitaire';
        final market = _doubleChanceMarket();
        final recommendedMarket = RecommendedMarket(
          market: market,
          selection: market.selections.first,
        );

        await _pumpMatchDetail(
          tester,
          match: _match(homeName: homeName),
          opportunity: _opportunity(
            match: _match(homeName: homeName),
            retainedTheses: [
              _thesis(
                id: 'solid_favorite',
                title: 'Avantage domicile',
                status: MatchThesisStatus.recommended,
                recommendedMarket: recommendedMarket,
              ),
            ],
            recommendedMarket: recommendedMarket,
          ),
        );

        final pick = find.text('$homeName ou nul');
        expect(pick, findsOneWidget);
        expect(tester.widget<Text>(pick).maxLines, 2);
        expect(tester.widget<Text>(pick).overflow, TextOverflow.clip);
        expect(find.text('1.42'), findsOneWidget);
      },
    );

    testWidgets('hides the pick for an early or marketless opportunity', (
      tester,
    ) async {
      final market = _doubleChanceMarket();
      final recommendedMarket = RecommendedMarket(
        market: market,
        selection: market.selections.first,
      );
      final match = _match();

      await _pumpMatchDetail(
        tester,
        match: match,
        opportunity: _opportunity(
          match: match,
          maturity: AnalysisMaturity.early,
          retainedTheses: [
            _thesis(id: 'solid_favorite', title: 'Avantage domicile'),
          ],
          recommendedMarket: recommendedMarket,
        ),
      );

      expect(find.text('Pari recommandé'), findsNothing);

      await _pumpMatchDetail(
        tester,
        match: match,
        opportunity: _opportunity(
          match: match,
          retainedTheses: [
            _thesis(id: 'solid_favorite', title: 'Avantage domicile'),
          ],
        ),
      );

      expect(find.text('Pari recommandé'), findsNothing);

      await _pumpMatchDetail(
        tester,
        match: match.copyWith(
          thesis: _thesis(
            id: 'solid_favorite',
            title: 'Avantage domicile',
            status: MatchThesisStatus.recommended,
            recommendedMarket: recommendedMarket,
          ),
        ),
      );

      expect(find.text('Pari recommandé'), findsNothing);
    });

    testWidgets('keeps the selected opportunity pick when several exist', (
      tester,
    ) async {
      final market = _doubleChanceMarket();
      final recommendedMarket = RecommendedMarket(
        market: market,
        selection: market.selections.first,
      );
      final firstMatch = _match(
        id: 'first-opportunity',
        homeName: 'Premier Club',
        awayName: 'Premier Adversaire',
        kickoff: _relativeKickoff(0, hour: 18),
      );
      final secondMatch = _match(
        id: 'second-opportunity',
        homeName: 'Second Club',
        awayName: 'Second Adversaire',
        kickoff: _relativeKickoff(0, hour: 20),
      );

      await _pumpPage(
        tester,
        repository: _FakeMatchFeedRepository(
          opportunities: [
            _opportunity(
              match: firstMatch,
              retainedTheses: [_thesis(id: 'first', title: 'Premier scénario')],
              recommendedMarket: recommendedMarket,
            ),
            _opportunity(
              match: secondMatch,
              retainedTheses: [_thesis(id: 'second', title: 'Second scénario')],
              recommendedMarket: recommendedMarket,
            ),
          ],
          matches: [firstMatch, secondMatch],
        ),
      );

      await tester.tap(find.text('Second Club').first);
      await tester.pumpAndSettle();

      expect(find.text('Second Club ou nul'), findsOneWidget);
      expect(find.text('Premier Club ou nul'), findsNothing);
    });

    testWidgets(
      'keeps repository-personalized matches visible without re-filtering them',
      (tester) async {
        final personalizedMatch =
            _match(
              id: 'repository-personalized',
              homeName: 'Regression FC',
              awayName: 'Reference United',
              kickoff: _relativeKickoff(0, hour: 20),
            ).copyWith(
              compatibility: 58,
              signals: const [
                MatchSignal(
                  id: 'engine_reading_not_in_presentation_catalog',
                  title: 'Lecture moteur personnalisée',
                  summary: 'Le moteur a retenu cette rencontre pour le profil.',
                  proofs: ['Signal produit par le moteur.'],
                ),
              ],
            );

        await _pumpPage(
          tester,
          repository: _FakeMatchFeedRepository(
            opportunities: const [],
            matches: [personalizedMatch],
            personalizedMatches: [personalizedMatch],
          ),
        );

        expect(find.text('À suivre aujourd’hui'), findsOneWidget);
        expect(find.text('Regression FC'), findsOneWidget);
        expect(find.text('Reference United'), findsOneWidget);
        expect(find.text('Rien de vraiment lisible'), findsNothing);
      },
    );

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
      expect(find.text('À suivre aujourd’hui'), findsNothing);
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

    testWidgets(
      'For me filters reading-only matches by selected calendar date',
      (tester) async {
        MatchBoardItem readingMatch(String id, String home, int dayOffset) {
          return _match(
            id: id,
            homeName: home,
            awayName: 'Away $home',
            kickoff: _relativeKickoff(dayOffset, hour: 20),
          ).copyWith(
            signals: [
              MatchSignal(
                id: 'positive_streak',
                title: 'Dynamique positive pour $home',
                summary: 'Lecture détectée',
                proofs: const ['Lecture positive_streak détectée.'],
              ),
            ],
            compatibility: 72,
          );
        }

        final personalizedMatches = [
          readingMatch('past-reading', 'Past Club', -1),
          readingMatch('today-reading', 'Today Club', 0),
          readingMatch('future-reading', 'Future Club', 1),
        ];

        await _pumpPage(
          tester,
          repository: _FakeMatchFeedRepository(
            opportunities: const [],
            matches: personalizedMatches,
            personalizedMatches: personalizedMatches,
          ),
        );

        expect(find.text('À suivre aujourd’hui'), findsOneWidget);
        expect(find.text('Past Club'), findsNothing);
        expect(find.text('Today Club'), findsWidgets);
        expect(find.text('Future Club'), findsNothing);

        await tester.tap(
          find.text(_calendarLabel(_relativeKickoff(1, hour: 20))),
        );
        await tester.pumpAndSettle();

        expect(find.text('Past Club'), findsNothing);
        expect(find.text('Today Club'), findsNothing);
        expect(find.text('Future Club'), findsWidgets);

        await tester.tap(
          find.text(_calendarLabel(_relativeKickoff(-1, hour: 20))),
        );
        await tester.pumpAndSettle();

        expect(find.text('Past Club'), findsWidgets);
        expect(find.text('Today Club'), findsNothing);
        expect(find.text('Future Club'), findsNothing);
      },
    );

    testWidgets('filters the personalized list locally by selected reading', (
      tester,
    ) async {
      MatchBoardItem readingMatch({
        required String id,
        required String homeName,
        required String readingId,
        required String title,
      }) {
        return _match(
          id: id,
          homeName: homeName,
          awayName: 'Away $homeName',
          kickoff: _relativeKickoff(0, hour: 20),
        ).copyWith(
          signals: [
            MatchSignal(
              id: readingId,
              title: title,
              summary: '$title détecté.',
              proofs: ['$title confirmé par les données disponibles.'],
            ),
          ],
        );
      }

      final rankingMatch = readingMatch(
        id: 'ranking-match',
        homeName: 'Ranking FC',
        readingId: 'structural_level_gap',
        title: 'Écart de niveau structurel',
      );
      final attackMatch = readingMatch(
        id: 'attack-match',
        homeName: 'Attack FC',
        readingId: 'prolific_attack',
        title: 'Attaque efficace',
      );

      await _pumpPage(
        tester,
        profile: _completedProfile().withOptionIds('opportunity_profiles', [
          'ranking_gap',
          'prolific_attack',
        ]),
        repository: _FakeMatchFeedRepository(
          opportunities: const [],
          matches: [rankingMatch, attackMatch],
          personalizedMatches: [rankingMatch, attackMatch],
        ),
      );

      expect(find.text('Tout'), findsOneWidget);
      expect(find.text('(2)'), findsOneWidget);
      expect(find.text('Avantage classement'), findsWidgets);
      expect(find.text('Attaque efficace'), findsWidgets);

      await tester.tap(find.text('Avantage classement').first);
      await tester.pumpAndSettle();

      expect(find.text('Ranking FC'), findsOneWidget);
      expect(find.text('Attack FC'), findsNothing);

      await tester.tap(find.text('Attaque efficace').first);
      await tester.pumpAndSettle();

      expect(find.text('Ranking FC'), findsNothing);
      expect(find.text('Attack FC'), findsOneWidget);
    });

    testWidgets(
      'deduplicates fragile-defense filters into one canonical preference',
      (tester) async {
        MatchBoardItem readingMatch(String id, String homeName) {
          return _match(
            id: id,
            homeName: homeName,
            awayName: 'Away $homeName',
            kickoff: _relativeKickoff(0, hour: 20),
          ).copyWith(
            signals: [
              MatchSignal(
                id: 'fragile_defense',
                title: '$homeName fragile à domicile',
                summary: 'Défense fragile détectée.',
                proofs: const ['Lecture fragile_defense détectée.'],
              ),
            ],
          );
        }

        final first = readingMatch('fragile-a', 'Alpha FC');
        final second = readingMatch('fragile-b', 'Beta FC');
        await _pumpPage(
          tester,
          profile: _completedProfile().withOptionIds('opportunity_profiles', [
            'fragile_defense',
          ]),
          repository: _FakeMatchFeedRepository(
            opportunities: const [],
            matches: [first, second],
            personalizedMatches: [first, second],
          ),
        );

        final filter = find.byKey(
          const ValueKey('for-me-filter-fragile_defense'),
        );
        expect(filter, findsOneWidget);
        expect(
          find.descendant(of: filter, matching: find.text('Défense fragile')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: filter, matching: find.text('(2)')),
          findsOneWidget,
        );

        await tester.tap(filter);
        await tester.pumpAndSettle();

        expect(find.text('Alpha FC'), findsOneWidget);
        expect(find.text('Beta FC'), findsOneWidget);
      },
    );

    testWidgets(
      'groups home and away variants under their selected canonical preference',
      (tester) async {
        MatchBoardItem readingMatch({
          required String id,
          required String homeName,
          required String readingId,
          required String title,
        }) {
          return _match(
            id: id,
            homeName: homeName,
            awayName: 'Away $homeName',
            kickoff: _relativeKickoff(0, hour: 20),
          ).copyWith(
            signals: [
              MatchSignal(
                id: readingId,
                title: title,
                summary: '$title détecté.',
                proofs: const ['Lecture détectée.'],
              ),
            ],
          );
        }

        final home = readingMatch(
          id: 'weak-home',
          homeName: 'Home Weak FC',
          readingId: 'weak_home_team',
          title: 'Home Weak FC fragile à domicile',
        );
        final away = readingMatch(
          id: 'weak-away',
          homeName: 'Away Weak FC',
          readingId: 'weak_away_team',
          title: 'Away Weak FC fragile à l’extérieur',
        );
        await _pumpPage(
          tester,
          profile: _completedProfile().withOptionIds('opportunity_profiles', [
            'struggling_team',
          ]),
          repository: _FakeMatchFeedRepository(
            opportunities: const [],
            matches: [home, away],
            personalizedMatches: [home, away],
          ),
        );

        final filter = find.byKey(
          const ValueKey('for-me-filter-struggling_team'),
        );
        expect(filter, findsOneWidget);
        expect(
          find.descendant(
            of: filter,
            matching: find.text('Équipe en difficulté'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: filter, matching: find.text('(2)')),
          findsOneWidget,
        );

        await tester.tap(filter);
        await tester.pumpAndSettle();

        expect(find.text('Home Weak FC'), findsOneWidget);
        expect(find.text('Away Weak FC'), findsOneWidget);
      },
    );

    testWidgets(
      'Voir tout expands only every personalized story for the selected date',
      (tester) async {
        MatchBoardItem readingMatch(String id, String home, int dayOffset) {
          return _match(
            id: id,
            homeName: home,
            awayName: 'Away $home',
            kickoff: _relativeKickoff(dayOffset, hour: 14),
          ).copyWith(
            signals: [
              MatchSignal(
                id: 'ranking_superiority',
                title: 'Écart au classement pour $home',
                summary: 'Lecture classement détectée',
                proofs: const ['Lecture ranking_superiority détectée.'],
              ),
            ],
            compatibility: 88,
          );
        }

        final personalizedMatches = [
          for (var index = 0; index < 5; index++)
            readingMatch('for-me-$index', 'Home $index', 0),
          readingMatch('for-me-tomorrow', 'Tomorrow Club', 1),
        ];

        await _pumpPage(
          tester,
          repository: _FakeMatchFeedRepository(
            opportunities: const [],
            matches: personalizedMatches,
            personalizedMatches: personalizedMatches,
          ),
        );

        expect(find.text('Voir tout (5)'), findsOneWidget);
        expect(find.text('Home 0'), findsWidgets);
        expect(find.text('Home 1'), findsWidgets);
        expect(find.text('Home 2'), findsWidgets);
        expect(find.text('1 lecture'), findsNWidgets(3));
        expect(find.text('Tomorrow Club'), findsNothing);

        await tester.tap(find.text('Voir tout (5)'));
        await tester.pumpAndSettle();

        expect(find.text('Home 3'), findsOneWidget);
        expect(find.text('Away Home 3'), findsOneWidget);
        expect(find.text('Home 4'), findsOneWidget);
        expect(find.text('Away Home 4'), findsOneWidget);
        expect(find.text('Tomorrow Club'), findsNothing);
        expect(find.text('Réduire'), findsOneWidget);
      },
    );

    testWidgets('Voir les lectures displays real reading-only signals', (
      tester,
    ) async {
      final readingOnlyMatch =
          _match(
            id: 'reading-only-detail',
            homeName: 'Signal-only FC',
            awayName: 'Proof Town',
            kickoff: _relativeKickoff(0, hour: 19),
          ).copyWith(
            signals: const [
              MatchSignal(
                id: 'ranking_superiority',
                title: 'Écart au classement pour Signal-only FC',
                summary: 'Signal-only FC possède un écart au classement.',
                proofs: ['Signal-only FC possède 6 rangs d’avance.'],
              ),
              MatchSignal(
                id: 'prolific_attack',
                title: 'Attaque productive pour Signal-only FC',
                summary: 'Signal-only FC marque régulièrement.',
                proofs: ['Signal-only FC a marqué 9 buts récemment.'],
              ),
            ],
            compatibility: 76,
          );

      await _pumpPage(
        tester,
        repository: _FakeMatchFeedRepository(
          opportunities: const [],
          matches: [readingOnlyMatch],
          personalizedMatches: [readingOnlyMatch],
        ),
      );

      await tester.tap(find.text('Signal-only FC').first);
      await tester.pumpAndSettle();

      expect(find.text('Voir les 2 lectures'), findsOneWidget);

      await tester.tap(find.text('Voir les 2 lectures'));
      await tester.pumpAndSettle();

      expect(find.text('Écart au classement'), findsOneWidget);
      expect(find.text('Ce qui soutient cette lecture (2)'), findsOneWidget);
      expect(
        find.text('Aucune résistance ou contradiction explicite produite.'),
        findsOneWidget,
      );
      expect(
        find.text('Signal-only FC possède 6 rangs d’avance.'),
        findsWidgets,
      );
      expect(
        find.text('Signal-only FC a marqué 9 buts récemment.'),
        findsWidgets,
      );
      expect(
        find.text(
          'Aucune lecture moteur détaillée disponible pour cette rencontre.',
        ),
        findsNothing,
      );
    });

    testWidgets(
      'shows engine support, resistance and contradiction in reading sheet',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final match = _match(
          id: 'assessment-detail',
          homeName: 'Alpha FC',
          awayName: 'Beta FC',
          kickoff: _relativeKickoff(0, hour: 19),
        );
        final now = DateTime(2026, 9, 4, 12);
        FootballReading reading({
          required String id,
          required ReadingStrength strength,
          required String label,
        }) {
          return FootballReading(
            id: id,
            subjectTeamId: match.homeTeam.id,
            subjectSide: ReadingSubjectSide.home,
            status: ReadingStatus.detected,
            strength: strength,
            evidence: [
              ReadingEvidence(
                label: label,
                kind: ReadingEvidenceKind.form,
                sourcePath: 'test.$id',
              ),
            ],
            warnings: const [],
            asOf: now,
            sampleSize: 5,
          );
        }

        final supporting = reading(
          id: 'positive_streak',
          strength: ReadingStrength.strong,
          label: 'Alpha FC reste sur une série favorable.',
        );
        final resistance = reading(
          id: 'strong_home_team',
          strength: ReadingStrength.moderate,
          label: 'Beta FC conserve un bon rendement à domicile.',
        );
        final contradiction = reading(
          id: 'negative_streak',
          strength: ReadingStrength.moderate,
          label: 'Une donnée récente va dans le sens inverse.',
        );

        await _pumpPage(
          tester,
          repository: _FakeMatchFeedRepository(
            opportunities: [
              _opportunity(
                match: match,
                retainedTheses: [
                  _thesis(
                    id: 'expected_domination',
                    title: 'Domination attendue',
                  ),
                ],
                thesisAssessments: [
                  ThesisAssessment(
                    id: 'expected_domination',
                    title: 'Domination attendue',
                    subjectSide: ReadingSubjectSide.home,
                    status: ThesisAssessmentStatus.supported,
                    clarityScore: 74,
                    evidence: [
                      ThesisEvidenceAssessment(
                        relation: ThesisEvidenceRelation.coreSupport,
                        family: CopilotArgumentFamily.form,
                        label: 'Série favorable',
                        reading: supporting,
                      ),
                      ThesisEvidenceAssessment(
                        relation: ThesisEvidenceRelation.resistance,
                        family: CopilotArgumentFamily.form,
                        label: 'Rendement adverse',
                        reading: resistance,
                      ),
                      ThesisEvidenceAssessment(
                        relation: ThesisEvidenceRelation.contradiction,
                        family: CopilotArgumentFamily.form,
                        label: 'Signal contraire',
                        reading: contradiction,
                      ),
                    ],
                  ),
                  ThesisAssessment(
                    id: 'convergent_open_match',
                    title: 'Match ouvert',
                    subjectSide: ReadingSubjectSide.match,
                    status: ThesisAssessmentStatus.supported,
                    clarityScore: 58,
                    evidence: [
                      ThesisEvidenceAssessment(
                        relation: ThesisEvidenceRelation.additionalSupport,
                        family: CopilotArgumentFamily.rhythm,
                        label: 'Rythme favorable',
                        reading: supporting,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );

        await tester.tap(find.text('Alpha FC').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Voir les 1 lectures'));
        await tester.pumpAndSettle();

        expect(find.text('Domination attendue pour Alpha FC'), findsOneWidget);
        expect(find.text('Ce qui soutient cette lecture (1)'), findsOneWidget);
        expect(
          find.text('Ce qui contredit ou tempère cette lecture (2)'),
          findsOneWidget,
        );
        expect(find.text('Résistances (1)'), findsOneWidget);
        expect(find.text('Contradictions (1)'), findsOneWidget);
        expect(
          find.text('Alpha FC reste sur une série favorable.'),
          findsOneWidget,
        );
        expect(
          find.text('Beta FC conserve un bon rendement à domicile.'),
          findsOneWidget,
        );

        await tester.scrollUntilVisible(
          find.byTooltip('Lecture suivante'),
          180,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(find.byTooltip('Lecture suivante'));
        await tester.pumpAndSettle();

        expect(find.text('Match ouvert'), findsOneWidget);
        expect(find.text('2 / 2'), findsOneWidget);
      },
    );

    testWidgets(
      'keeps selected opportunity contradictions when assessments are absent',
      (tester) async {
        final match = _match(
          id: 'legacy-opportunity-evidence',
          homeName: 'Alpha FC',
          awayName: 'Beta FC',
          kickoff: _relativeKickoff(0, hour: 19),
        );
        final now = DateTime(2026, 9, 4, 12);
        FootballReading reading(String id, String label) {
          return FootballReading(
            id: id,
            subjectTeamId: match.homeTeam.id,
            subjectSide: ReadingSubjectSide.home,
            status: ReadingStatus.detected,
            strength: ReadingStrength.moderate,
            evidence: [
              ReadingEvidence(
                label: label,
                kind: ReadingEvidenceKind.form,
                sourcePath: 'test.$id',
              ),
            ],
            warnings: const [],
            asOf: now,
            sampleSize: 5,
          );
        }

        await _pumpPage(
          tester,
          repository: _FakeMatchFeedRepository(
            opportunities: [
              _opportunity(
                match: match,
                retainedTheses: [
                  _thesis(
                    id: 'expected_domination',
                    title: 'Domination attendue',
                  ),
                ],
                supportingReadings: [
                  reading('positive_streak', 'Alpha FC reste en forme.'),
                ],
                contradictoryReadings: [
                  reading(
                    'negative_streak',
                    'Une tendance va contre Alpha FC.',
                  ),
                ],
              ),
            ],
          ),
        );

        await tester.tap(find.text('Alpha FC').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Voir les 1 lectures'));
        await tester.pumpAndSettle();

        expect(find.text('Ce qui soutient cette lecture (1)'), findsOneWidget);
        expect(
          find.text('Ce qui contredit ou tempère cette lecture (1)'),
          findsOneWidget,
        );
        expect(
          find.text('Aucune résistance ou contradiction explicite produite.'),
          findsNothing,
        );
      },
    );

    testWidgets('keeps a manually selected date outside the snapshot window', (
      tester,
    ) async {
      final today = _dayOnly(DateTime.now());
      final previousDay = DateTime(today.year, today.month, today.day - 1);

      await _pumpPage(
        tester,
        repository: _FakeMatchFeedRepository(
          metadata: MatchFeedSnapshotMetadata(
            source: 'test',
            capturedAt: DateTime.now(),
            timezone: 'Europe/Paris',
            matchCount: 1,
            windowStart: today,
            windowEnd: DateTime(today.year, today.month, today.day + 3),
          ),
          opportunities: [
            _opportunity(
              match: _match(
                id: 'today-match',
                homeName: 'Nice',
                awayName: 'Lille',
                kickoff: _relativeKickoff(0, hour: 20),
              ),
              retainedTheses: [
                _thesis(id: 'open_match', title: 'Match ouvert'),
              ],
            ),
          ],
        ),
      );

      await tester.tap(find.text(_calendarLabel(previousDay)));
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'Aucune donnée snapshot pour le ${_shortDateLabel(previousDay)}',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'shows For me matches from the first fixture date when today is covered but empty',
      (tester) async {
        final today = _dayOnly(DateTime.now());
        final firstFixtureDate = DateTime(
          today.year,
          today.month,
          today.day + 3,
          20,
        );

        await _pumpPage(
          tester,
          repository: _FakeMatchFeedRepository(
            metadata: MatchFeedSnapshotMetadata(
              source: 'test',
              capturedAt: DateTime.now(),
              timezone: 'Europe/Paris',
              matchCount: 1,
              windowStart: today,
              windowEnd: DateTime(today.year, today.month, today.day + 3),
            ),
            opportunities: [
              _opportunity(
                match: _match(
                  id: 'future-window-match',
                  homeName: 'Jeonbuk Motors',
                  awayName: 'Pohang Steelers',
                  competitionId: '292',
                  competitionName: 'K League 1',
                  kickoff: firstFixtureDate,
                ),
                retainedTheses: [
                  _thesis(
                    id: 'controlled_favorite',
                    title: 'Favori en contrôle',
                  ),
                ],
              ),
            ],
            matches: [
              _match(
                id: 'future-window-match',
                homeName: 'Jeonbuk Motors',
                awayName: 'Pohang Steelers',
                competitionId: '292',
                competitionName: 'K League 1',
                kickoff: firstFixtureDate,
              ),
            ],
          ),
          profile: _completedProfile().withOptionIds('competitions', ['292']),
        );

        expect(find.text('Jeonbuk Motors'), findsWidgets);
        expect(find.text('Pohang Steelers'), findsWidgets);
        expect(find.text('Domination attendue'), findsWidgets);
      },
    );

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

      expect(find.text('DOMINATION ATTENDUE'), findsOneWidget);
      expect(find.text('Clés du match'), findsOneWidget);
      expect(
        find.text(
          'Peu d’éléments différenciants ressortent avant cette rencontre.',
        ),
        findsOneWidget,
      );
      expect(find.text('Avant-match'), findsWidgets);

      await tester.tap(find.text('Classement'));
      await tester.pumpAndSettle();

      expect(
        find.text('Position, points et dynamique dans le championnat.'),
        findsOneWidget,
      );
      expect(find.text('Bodo/Glimt'), findsWidgets);
      expect(find.text('Rosenborg'), findsWidgets);
    });

    testWidgets('renders the semantic highlight carried by a context key', (
      tester,
    ) async {
      final match = _match(
        id: 'semantic-context-key',
        homeName: 'Alpha FC',
        awayName: 'Beta FC',
        kickoff: _relativeKickoff(0, hour: 20),
        homeApiTeamId: 1,
        awayApiTeamId: 2,
        analysis: const MatchAnalysisData(
          contextKeys: [
            MatchContextKey(
              family: MatchContextKeyFamily.defense,
              semanticScope: 'defensive_exposure',
              subjectTeamIds: [1, 2],
              facts: {
                'homegoalsAgainstPerGame': 0.75,
                'awaygoalsAgainstPerGame': 1.80,
              },
              highlights: [
                MatchContextKeyHighlight(
                  teamId: 1,
                  direction: ChampionshipContextZoneSide.low,
                ),
                MatchContextKeyHighlight(
                  teamId: 2,
                  direction: ChampionshipContextZoneSide.high,
                ),
              ],
              sourcePaths: ['standings[].all.goals.against'],
            ),
          ],
          contextKeyAvailability: MatchContextKeyAvailability.available,
        ),
      );
      await _pumpPage(
        tester,
        repository: _FakeMatchFeedRepository(
          opportunities: [
            _opportunity(
              match: match,
              retainedTheses: [_thesis(id: 'context', title: 'Contexte')],
            ),
          ],
          matches: [match],
        ),
      );

      await tester.tap(find.text('Alpha FC').first);
      await tester.pumpAndSettle();

      expect(find.text('Clés du match'), findsOneWidget);
      expect(find.text('DÉFENSE'), findsOneWidget);
      expect(
        find.text('Beta FC parmi les défenses les plus exposées'),
        findsOneWidget,
      );
      expect(find.text('0.75'), findsOneWidget);
      expect(find.text('1.80'), findsOneWidget);
    });

    testWidgets('keeps two context keys as two developed cards', (
      tester,
    ) async {
      final match = _contextKeyMatch(_contextKeyFixtures().take(2).toList());
      await _pumpPage(
        tester,
        repository: _FakeMatchFeedRepository(
          opportunities: [
            _opportunity(
              match: match,
              retainedTheses: [_thesis(id: 'two-keys', title: 'Contexte')],
            ),
          ],
          matches: [match],
        ),
      );

      await tester.tap(find.text('Horizon Athletic Association').first);
      await tester.pumpAndSettle();

      expect(find.text('2 clés'), findsOneWidget);
      expect(find.text('HIÉRARCHIE'), findsOneWidget);
      expect(find.text('FORME'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders every retained context key up to four', (
      tester,
    ) async {
      final match = _contextKeyMatch(_contextKeyFixtures());
      await _pumpPage(
        tester,
        repository: _FakeMatchFeedRepository(
          opportunities: [
            _opportunity(
              match: match,
              retainedTheses: [_thesis(id: 'four-keys', title: 'Contexte')],
            ),
          ],
          matches: [match],
        ),
      );

      await tester.tap(find.text('Horizon Athletic Association').first);
      await tester.pumpAndSettle();

      expect(find.text('4 clés'), findsOneWidget);
      expect(find.text('HIÉRARCHIE'), findsOneWidget);
      expect(find.text('FORME'), findsOneWidget);
      expect(find.text('ATTAQUE'), findsOneWidget);
      expect(find.text('DÉFENSE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders only the active Lector Tiers and official zones', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        repository: _FakeMatchFeedRepository(
          opportunities: [
            _opportunity(
              match: _match(
                id: 'tiered-standing',
                homeName: 'Alpha FC',
                awayName: 'Delta FC',
                kickoff: _relativeKickoff(0, hour: 18),
                analysis: _tieredAnalysisData(),
              ),
              retainedTheses: [
                _thesis(id: 'level_gap', title: 'Domination attendue'),
              ],
            ),
          ],
        ),
      );

      await tester.tap(find.text('Alpha FC').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Classement'));
      await tester.pumpAndSettle();

      expect(find.text('Tiers Lector'), findsOneWidget);
      expect(find.text('Tier 1 - Podium'), findsOneWidget);
      expect(find.text('Tier 3 - Milieu de tableau'), findsOneWidget);
      expect(find.text('Tier 2 - Haut de tableau'), findsNothing);
      expect(find.text('Tier 4 - Bas de tableau'), findsNothing);

      await tester.tap(find.text('Enjeux'));
      await tester.pumpAndSettle();

      expect(find.text('Promotion - Champions League'), findsOneWidget);
      expect(find.text('Relegation'), findsOneWidget);
      expect(find.text('Tier 1 - Podium'), findsNothing);
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

      expect(find.text('LECTURE DISPONIBLE'), findsOneWidget);
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

      expect(find.text('Mes tickets'), findsOneWidget);
      expect(find.text('Tous les matchs'), findsNothing);
    });

    testWidgets('opens generator from the compact floating Lector dock', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        strategies: [_strategy()],
        repository: _FakeMatchFeedRepository(opportunities: const []),
      );

      expect(
        find.byKey(const ValueKey('lector-floating-dock')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('lector-floating-dock-Générateur')),
        findsNothing,
      );
      expect(find.text('Recherche'), findsNothing);
      expect(find.byType(ActionChip), findsNothing);

      await tester.tap(find.byKey(const ValueKey('lector-floating-dock-logo')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('lector-floating-dock-Générateur')),
        findsOneWidget,
      );
      expect(find.text('Recherche'), findsNothing);
      expect(find.byType(ActionChip), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('lector-floating-dock-Générateur')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mes tickets'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('lector-floating-dock-Générateur')),
        findsNothing,
      );
    });

    testWidgets(
      'match detail deck adds then opens the current ticket locally',
      (tester) async {
        final market = _doubleChanceMarket();
        final recommendedMarket = RecommendedMarket(
          market: market,
          selection: market.selections.first,
        );

        await _pumpPage(
          tester,
          strategies: [_strategy()],
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
                  _thesis(
                    id: 'level_gap',
                    title: 'Domination attendue',
                    status: MatchThesisStatus.recommended,
                    recommendedMarket: recommendedMarket,
                  ),
                ],
                recommendedMarket: recommendedMarket,
              ),
            ],
          ),
        );

        await tester.tap(find.text('Bodo/Glimt').first);
        await tester.pumpAndSettle();

        expect(
          find.byWidgetPredicate((widget) {
            if (widget is! Text) {
              return false;
            }
            return widget.data == 'Bodo/Glimt ou nul' ||
                widget.textSpan?.toPlainText() ==
                    'Pronostic envisagé · Bodo/Glimt ou nul';
          }),
          findsOneWidget,
        );
        expect(find.text('1.42'), findsOneWidget);

        await tester.tap(
          find.byKey(const ValueKey('lector-floating-dock-logo')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('lector-floating-dock-Ajouter au ticket')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('lector-floating-dock-Voir mon ticket')),
          findsNothing,
        );

        await tester.tap(
          find.byKey(const ValueKey('lector-floating-dock-Ajouter au ticket')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Mon ticket'), findsOneWidget);
        expect(find.text('Voir le ticket'), findsOneWidget);

        await tester.tap(
          find.byKey(const ValueKey('lector-floating-dock-logo')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('lector-floating-dock-Voir mon ticket')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('lector-floating-dock-Retirer')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('lector-floating-dock-Générateur')),
          findsNothing,
        );

        await tester.tap(
          find.byKey(const ValueKey('lector-floating-dock-Voir mon ticket')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Valider le ticket'), findsOneWidget);
        expect(find.text('1X (Double chance)'), findsOneWidget);
      },
    );

    testWidgets(
      'opens Lector space and appearance submenu instead of onboarding',
      (tester) async {
        await _pumpPage(
          tester,
          repository: _FakeMatchFeedRepository(opportunities: const []),
        );

        await tester.tap(find.byTooltip('Paramètres'));
        await tester.pumpAndSettle();

        expect(find.text('Mon espace'), findsOneWidget);
        expect(find.text('Mes compétitions'), findsOneWidget);
        expect(find.text('Mes lectures'), findsOneWidget);
        expect(find.text('Mes scénarios'), findsOneWidget);
        expect(find.text('Mes stratégies'), findsOneWidget);
        expect(find.text('Onboarding'), findsNothing);

        await tester.scrollUntilVisible(find.text('Apparence'), 300);
        await tester.pumpAndSettle();
        expect(find.text('Apparence'), findsOneWidget);

        await tester.tap(find.text('Apparence'));
        await tester.pumpAndSettle();

        expect(find.text('Choisir un thème'), findsOneWidget);
        expect(
          find.text('Sélectionnez le thème qui vous convient.'),
          findsOneWidget,
        );
        expect(find.text('Dark'), findsOneWidget);
        expect(find.text('Light'), findsOneWidget);
        expect(find.text('Système'), findsNothing);
        expect(
          find.byKey(const ValueKey('appearance-theme-vectorDark')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('appearance-theme-preview-vectorDark')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const ValueKey('appearance-theme-vectorLight')),
        );
        await tester.pumpAndSettle();

        expect(appThemeController.variant, AppThemeVariant.vectorLight);
      },
    );

    testWidgets('toggles light and dark directly from the header', (
      tester,
    ) async {
      appThemeController.select(AppThemeVariant.vectorDark);
      addTearDown(() {
        appThemeController.select(AppThemeVariant.vectorDark);
      });

      await _pumpPage(
        tester,
        repository: _FakeMatchFeedRepository(opportunities: const []),
      );

      await tester.tap(find.byTooltip('Passer en thème clair'));
      await tester.pumpAndSettle();

      expect(appThemeController.variant, AppThemeVariant.vectorLight);

      await tester.tap(find.byTooltip('Passer en thème sombre'));
      await tester.pumpAndSettle();

      expect(appThemeController.variant, AppThemeVariant.vectorDark);
    });

    testWidgets(
      'opens a sign-in sheet when the header auth action is signed out',
      (tester) async {
        final authController = _SignedOutAuthController();
        await getIt.reset();
        getIt.registerSingleton<SupabaseAuthController>(authController);
        addTearDown(getIt.reset);

        await _pumpPage(
          tester,
          repository: _FakeMatchFeedRepository(opportunities: const []),
        );

        expect(find.byTooltip('Connexion'), findsOneWidget);

        await tester.tap(find.byTooltip('Connexion'));
        await tester.pumpAndSettle();

        expect(find.text('Se connecter'), findsWidgets);
        expect(find.text('Adresse e-mail'), findsOneWidget);
        expect(find.text('Mot de passe'), findsOneWidget);
        expect(find.text('Continuer avec Google'), findsOneWidget);
        expect(find.text('Pas encore de compte ? '), findsOneWidget);
        expect(find.text('Mon profil'), findsNothing);
        expect(find.text('Sécurité'), findsNothing);
        expect(find.text('Appareils connectés'), findsNothing);

        await tester.enterText(
          find.widgetWithText(TextField, 'Adresse e-mail'),
          'julien@example.com',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Mot de passe'),
          'secret123',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Se connecter'));
        await tester.pumpAndSettle();

        expect(authController.passwordSignInEmail, 'julien@example.com');
      },
    );

    testWidgets(
      'opens an account sheet when the header auth action is signed in',
      (tester) async {
        final authController = _SignedInAuthController(
          user: _user(
            email: 'julien.bernard@example.com',
            fullName: 'Julien Bernard',
            provider: 'google',
          ),
        );
        await getIt.reset();
        getIt.registerSingleton<SupabaseAuthController>(authController);
        addTearDown(getIt.reset);

        await _pumpPage(
          tester,
          repository: _FakeMatchFeedRepository(opportunities: const []),
        );

        expect(find.text('JB'), findsOneWidget);
        expect(find.byTooltip('Compte'), findsOneWidget);

        await tester.tap(find.byTooltip('Compte'));
        await tester.pumpAndSettle();

        expect(find.text('Julien Bernard'), findsOneWidget);
        expect(find.text('julien.bernard@example.com'), findsOneWidget);
        expect(find.text('Mon profil'), findsOneWidget);
        expect(find.text('Sécurité'), findsOneWidget);
        expect(find.text('Appareils connectés'), findsOneWidget);
        expect(find.text('Se déconnecter de Google'), findsOneWidget);
        expect(find.text('Se déconnecter de Lector'), findsOneWidget);
        expect(find.text('Adresse e-mail'), findsNothing);
        expect(find.text('Mot de passe'), findsNothing);

        await tester.tap(find.text('Se déconnecter de Google'));
        await tester.pumpAndSettle();

        expect(authController.didSignOutFromGoogle, isTrue);
        expect(authController.didSignOut, isTrue);
      },
    );

    testWidgets('does not show Google sign out for a non-Google account', (
      tester,
    ) async {
      final authController = _SignedInAuthController(
        user: _user(
          email: 'julien.bernard@example.com',
          fullName: 'Julien Bernard',
        ),
      );
      await getIt.reset();
      getIt.registerSingleton<SupabaseAuthController>(authController);
      addTearDown(getIt.reset);

      await _pumpPage(
        tester,
        repository: _FakeMatchFeedRepository(opportunities: const []),
      );

      await tester.tap(find.byTooltip('Compte'));
      await tester.pumpAndSettle();

      expect(find.text('Se déconnecter de Google'), findsNothing);
      expect(find.text('Se déconnecter de Lector'), findsOneWidget);

      await tester.tap(find.text('Se déconnecter de Lector'));
      await tester.pumpAndSettle();

      expect(authController.didSignOut, isTrue);
    });

    testWidgets('shows sign out at the bottom of Lector space when signed in', (
      tester,
    ) async {
      final authController = _SignedInAuthController(
        user: _user(email: 'julien.bernard@example.com'),
      );
      await getIt.reset();
      getIt.registerSingleton<SupabaseAuthController>(authController);
      addTearDown(getIt.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: CopilotTheme.dark.copyWith(
            splashFactory: NoSplash.splashFactory,
          ),
          home: LectorSpacePage(
            profile: _completedProfile(),
            ticketStrategies: const [],
            onProfileChanged: (_) async {},
            onTicketStrategiesChanged: (_) async {},
          ),
        ),
      );

      await tester.drag(find.byType(ListView), const Offset(0, -420));
      await tester.pumpAndSettle();

      final signOut = find.text('Se déconnecter');
      expect(signOut, findsOneWidget);
      await tester.ensureVisible(signOut);
      await tester.pumpAndSettle();

      await tester.tap(signOut);
      await tester.pumpAndSettle();

      expect(authController.didSignOut, isTrue);
    });

    testWidgets('keeps Lector strategy cards compact on mobile', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final strategies = [
        _strategy().copyWith(id: 'strategy-1', name: 'Nouvelle stratégie'),
        _strategy().copyWith(
          id: 'strategy-2',
          name: 'jackpot',
          minimumSelections: 4,
          maximumSelections: 7,
          minimumIndividualOdds: 1.20,
          maximumIndividualOdds: null,
          clearsMaximumIndividualOdds: true,
          minimumTotalOdds: 8,
          maximumTotalOdds: 15,
        ),
        _strategy().copyWith(
          id: 'strategy-3',
          name: 'Vercel',
          minimumSelections: 7,
          maximumSelections: 12,
          minimumIndividualOdds: 1.50,
          maximumIndividualOdds: 6,
          minimumTotalOdds: 10,
          maximumTotalOdds: null,
          clearsMaximumTotalOdds: true,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: CopilotTheme.dark.copyWith(
            splashFactory: NoSplash.splashFactory,
          ),
          home: LectorStrategiesPage(
            strategies: strategies,
            onTicketStrategiesChanged: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final strategy in strategies) {
        final cardBox = tester.renderObject<RenderBox>(
          find.byKey(ValueKey('lector-strategy-card-${strategy.id}')),
        );
        expect(cardBox.size.height, lessThanOrEqualTo(118));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'opens an existing strategy as a compact summary before editing',
      (tester) async {
        final strategy = _strategy().copyWith(
          id: 'strategy-summary',
          name: 'Nouvelle stratégie',
          minimumSelections: 2,
          maximumSelections: 3,
          minimumIndividualOdds: 1.50,
          maximumIndividualOdds: 2.19,
          minimumTotalOdds: 2.50,
          maximumTotalOdds: 3.10,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: CopilotTheme.dark.copyWith(
              splashFactory: NoSplash.splashFactory,
            ),
            home: LectorStrategiesPage(
              strategies: [strategy],
              onTicketStrategiesChanged: (_) async {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Nouvelle stratégie').first);
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('strategy-summary')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('ticket-strategy-name-field')),
          findsNothing,
        );
        expect(find.text('Sélections'), findsWidgets);
        expect(find.text('2 – 3'), findsWidgets);
        expect(find.text('1,50 – 2,19'), findsWidgets);
        expect(find.text('2,50 – 3,10'), findsWidgets);
        expect(find.text('Modifier'), findsOneWidget);

        await tester.tap(find.text('Modifier'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('ticket-strategy-name-field')),
          findsOneWidget,
        );
        expect(find.text('Valider les modifications'), findsOneWidget);
      },
    );

    testWidgets('confirms and persists strategy deletion from the sheet', (
      tester,
    ) async {
      final strategies = [
        _strategy().copyWith(id: 'strategy-delete', name: 'À supprimer'),
        _strategy().copyWith(id: 'strategy-keep', name: 'À garder'),
      ];
      var savedStrategies = <TicketStrategy>[];

      await tester.pumpWidget(
        MaterialApp(
          theme: CopilotTheme.dark.copyWith(
            splashFactory: NoSplash.splashFactory,
          ),
          home: LectorStrategiesPage(
            strategies: strategies,
            onTicketStrategiesChanged: (next) async {
              savedStrategies = next;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('À supprimer').first);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('delete-ticket-strategy-button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Supprimer cette stratégie ?'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('confirm-delete-ticket-strategy-button')),
      );
      await tester.pumpAndSettle();

      expect(savedStrategies, hasLength(1));
      expect(savedStrategies.single.id, 'strategy-keep');
      expect(find.text('À supprimer'), findsNothing);
      expect(find.text('À garder'), findsOneWidget);
    });

    testWidgets(
      'persists active state changes from the strategy sheet header',
      (tester) async {
        final strategy = _strategy().copyWith(
          id: 'strategy-toggle',
          name: 'À désactiver',
          isActive: true,
        );
        var savedStrategies = <TicketStrategy>[];

        await tester.pumpWidget(
          MaterialApp(
            theme: CopilotTheme.dark.copyWith(
              splashFactory: NoSplash.splashFactory,
            ),
            home: LectorStrategiesPage(
              strategies: [strategy],
              onTicketStrategiesChanged: (next) async {
                savedStrategies = next;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('À désactiver').first);
        await tester.pumpAndSettle();
        await tester.tap(find.byType(Switch).last);
        await tester.pumpAndSettle();

        expect(savedStrategies, hasLength(1));
        expect(savedStrategies.single.id, 'strategy-toggle');
        expect(savedStrategies.single.isActive, isFalse);
        expect(find.text('Inactif'), findsOneWidget);
      },
    );
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
        identityScope: const IdentityScope.guest('test-guest'),
        ticketStrategies: strategies,
        repositoryOverride: repository,
        onEditProfile: () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpMatchDetail(
  WidgetTester tester, {
  required MatchBoardItem match,
  Opportunity? opportunity,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      theme: CopilotTheme.dark.copyWith(splashFactory: NoSplash.splashFactory),
      home: MatchDetailPage(match: match, opportunity: opportunity),
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
  List<FootballReading> supportingReadings = const [],
  List<FootballReading> contradictoryReadings = const [],
  List<ThesisAssessment> thesisAssessments = const [],
  int engineScore = 82,
  AnalysisMaturity maturity = AnalysisMaturity.established,
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
    supportingReadings: supportingReadings,
    contradictoryReadings: contradictoryReadings,
    thesisAssessments: thesisAssessments,
    maturity: maturity,
  );
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
    arguments: arguments,
    recommendedMarket: recommendedMarket,
  );
}

CopilotArgument _argument(
  String readingId, {
  CopilotArgumentType type = CopilotArgumentType.rankingGap,
  CopilotArgumentFamily family = CopilotArgumentFamily.hierarchy,
  CopilotEvidenceAction evidenceAction = CopilotEvidenceAction.standings,
}) {
  return CopilotArgument(
    id: '${readingId}_test-team',
    type: type,
    family: family,
    severity: CopilotArgumentSeverity.strong,
    subjectName: 'Chelsea',
    parameters: {'readingId': readingId},
    evidence: const [],
    evidenceAction: evidenceAction,
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
  int? homeApiTeamId,
  int? awayApiTeamId,
  String? round,
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
      homeTeam: TeamInfo(
        id: '$id-home',
        name: homeName,
        apiFootballTeamId: homeApiTeamId,
      ),
      awayTeam: TeamInfo(
        id: '$id-away',
        name: awayName,
        apiFootballTeamId: awayApiTeamId,
      ),
      kickoffLabel: kickoffLabel,
      round: round,
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

MatchBoardItem _contextKeyMatch(List<MatchContextKey> keys) {
  return _match(
    id: 'context-key-fixture',
    homeName: 'Horizon Athletic Association',
    awayName: 'Metropolitan Football Collective',
    kickoff: _relativeKickoff(0, hour: 20),
    homeApiTeamId: 1,
    awayApiTeamId: 2,
    analysis: MatchAnalysisData(
      contextKeys: keys,
      contextKeyAvailability: MatchContextKeyAvailability.available,
    ),
  );
}

List<MatchContextKey> _contextKeyFixtures() {
  const hierarchy = MatchContextKey(
    family: MatchContextKeyFamily.hierarchy,
    semanticScope: 'official_positioning',
    subjectTeamIds: [1, 2],
    facts: {'homeRank': 1, 'awayRank': 8, 'homePoints': 56, 'awayPoints': 34},
    highlights: [
      MatchContextKeyHighlight(
        teamId: 1,
        direction: ChampionshipContextZoneSide.high,
      ),
    ],
    sourcePaths: ['standings'],
  );
  const form = MatchContextKey(
    family: MatchContextKeyFamily.form,
    semanticScope: 'recent_form',
    subjectTeamIds: [1, 2],
    facts: {
      'homeForm': 'WWWWD',
      'awayForm': 'DLWDD',
      'homePoints': 13,
      'awayPoints': 6,
    },
    highlights: [
      MatchContextKeyHighlight(
        teamId: 1,
        direction: ChampionshipContextZoneSide.high,
      ),
    ],
    sourcePaths: ['standings.form'],
  );
  const attack = MatchContextKey(
    family: MatchContextKeyFamily.attack,
    semanticScope: 'offensive_production',
    subjectTeamIds: [1, 2],
    facts: {'homegoalsForPerGame': 1.92, 'awaygoalsForPerGame': 1.08},
    highlights: [
      MatchContextKeyHighlight(
        teamId: 1,
        direction: ChampionshipContextZoneSide.high,
      ),
    ],
    sourcePaths: ['standings.goalsFor'],
  );
  const defense = MatchContextKey(
    family: MatchContextKeyFamily.defense,
    semanticScope: 'defensive_exposure',
    subjectTeamIds: [1, 2],
    facts: {'homegoalsAgainstPerGame': 0.87, 'awaygoalsAgainstPerGame': 1.64},
    highlights: [
      MatchContextKeyHighlight(
        teamId: 2,
        direction: ChampionshipContextZoneSide.high,
      ),
    ],
    sourcePaths: ['standings.goalsAgainst'],
  );
  return const [hierarchy, form, attack, defense];
}

MatchAnalysisData _tieredAnalysisData() {
  const rows = [
    TeamStandingSnapshot(
      teamId: 1,
      teamName: 'Alpha FC',
      rank: 1,
      points: 43,
      played: 20,
      wins: 13,
      draws: 4,
      losses: 3,
      goalsFor: 38,
      goalsAgainst: 16,
      goalDiff: 22,
      description: 'Promotion - Champions League',
    ),
    TeamStandingSnapshot(
      teamId: 2,
      teamName: 'Bravo FC',
      rank: 2,
      points: 41,
      played: 20,
      wins: 12,
      draws: 5,
      losses: 3,
      goalsFor: 34,
      goalsAgainst: 18,
      goalDiff: 16,
    ),
    TeamStandingSnapshot(
      teamId: 3,
      teamName: 'Charlie FC',
      rank: 3,
      points: 28,
      played: 20,
      wins: 8,
      draws: 4,
      losses: 8,
      goalsFor: 24,
      goalsAgainst: 25,
      goalDiff: -1,
    ),
    TeamStandingSnapshot(
      teamId: 4,
      teamName: 'Delta FC',
      rank: 4,
      points: 22,
      played: 20,
      wins: 6,
      draws: 4,
      losses: 10,
      goalsFor: 20,
      goalsAgainst: 31,
      goalDiff: -11,
      description: 'Relegation',
    ),
  ];
  const assignments = [
    TeamTierAssignment(
      teamId: 1,
      teamName: 'Alpha FC',
      officialRank: 1,
      points: 43,
      played: 20,
      pointsPerGame: 2.15,
      assignedTier: TierLabel.tier1Podium,
    ),
    TeamTierAssignment(
      teamId: 2,
      teamName: 'Bravo FC',
      officialRank: 2,
      points: 41,
      played: 20,
      pointsPerGame: 2.05,
      assignedTier: TierLabel.tier1Podium,
    ),
    TeamTierAssignment(
      teamId: 3,
      teamName: 'Charlie FC',
      officialRank: 3,
      points: 28,
      played: 20,
      pointsPerGame: 1.4,
      assignedTier: TierLabel.tier3MiddleChampionship,
    ),
    TeamTierAssignment(
      teamId: 4,
      teamName: 'Delta FC',
      officialRank: 4,
      points: 22,
      played: 20,
      pointsPerGame: 1.1,
      assignedTier: TierLabel.tier3MiddleChampionship,
    ),
  ];

  return MatchAnalysisData(
    homeStanding: rows.first,
    awayStanding: rows.last,
    leagueStandings: rows,
    championshipTierSnapshot: ChampionshipTierSnapshot(
      competitionId: '61',
      season: 2026,
      analysisAsOf: DateTime.utc(2026, 9, 5, 8),
      tierSystemVersion: 'tier-v1',
      standingsSnapshotIdentity: 'tiered-test-snapshot',
      status: TierSystemStatus.mature,
      maturity: TierMaturity.mature,
      teamCount: rows.length,
      pointDistribution: null,
      ppgDistribution: null,
      boundaryCandidates: const [],
      confirmedStructuralBoundaries: const [],
      tierPartitionBoundaries: const [],
      tierPresence: const {
        TierLabel.tier1Podium,
        TierLabel.tier3MiddleChampionship,
      },
      teamAssignments: assignments,
      warnings: const [],
      unavailabilityReasons: const [],
    ),
  );
}

DateTime _relativeKickoff(int dayOffset, {required int hour}) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + dayOffset, hour);
}

DateTime _dayOnly(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

String _calendarLabel(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}';
}

String _shortDateLabel(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
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
  const _FakeMatchFeedRepository({
    required this.opportunities,
    this.matches,
    this.personalizedMatches,
    this.metadata,
  });

  final List<Opportunity> opportunities;
  final List<MatchBoardItem>? matches;
  final List<MatchBoardItem>? personalizedMatches;
  final MatchFeedSnapshotMetadata? metadata;

  @override
  MatchDataSourceMode get mode => MatchDataSourceMode.demo;

  @override
  MatchFeedSnapshotMetadata? get snapshotMetadata => metadata;

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
    return personalizedMatches ??
        [
          for (final opportunity in opportunities)
            opportunity.toMatchBoardItem(),
        ];
  }
}

class _SignedOutAuthController extends SupabaseAuthController {
  _SignedOutAuthController()
    : super(
        SupabaseInitializer(
          const AppConfig(
            environment: AppEnvironment.development,
            supabaseUrl: null,
            supabaseAnonKey: null,
          ),
        ),
        const AppConfig(
          environment: AppEnvironment.development,
          supabaseUrl: null,
          supabaseAnonKey: null,
        ),
      );

  String? passwordSignInEmail;
  bool didStartGoogle = false;

  @override
  bool get isConfigured => true;

  @override
  bool get isSignedIn => false;

  @override
  User? get user => null;

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    passwordSignInEmail = email;
  }

  @override
  Future<void> signUpWithPassword({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signInWithGoogle() async {
    didStartGoogle = true;
  }
}

class _SignedInAuthController extends SupabaseAuthController {
  _SignedInAuthController({required User user}) : this._(user);

  _SignedInAuthController._(this._user)
    : super(
        SupabaseInitializer(
          const AppConfig(
            environment: AppEnvironment.development,
            supabaseUrl: null,
            supabaseAnonKey: null,
          ),
        ),
        const AppConfig(
          environment: AppEnvironment.development,
          supabaseUrl: null,
          supabaseAnonKey: null,
        ),
      );

  final User _user;
  bool didSignOut = false;
  bool didSignOutFromGoogle = false;

  @override
  bool get isConfigured => true;

  @override
  User? get user => didSignOut ? null : _user;

  @override
  bool get isSignedIn => !didSignOut;

  @override
  Future<void> signOut() async {
    didSignOut = true;
    notifyListeners();
  }

  @override
  Future<void> signOutFromGoogle() async {
    didSignOutFromGoogle = true;
    await signOut();
  }
}

User _user({required String email, String? fullName, String? provider}) {
  return User(
    id: 'user-test-id',
    appMetadata: provider == null ? const {} : {'provider': provider},
    userMetadata: fullName == null ? null : {'full_name': fullName},
    aud: 'authenticated',
    email: email,
    identities: provider == null
        ? null
        : [
            UserIdentity(
              id: 'identity-test-id',
              userId: 'user-test-id',
              identityData: const {},
              identityId: 'identity-test-id',
              provider: provider,
              createdAt: DateTime(2026).toIso8601String(),
              lastSignInAt: DateTime(2026).toIso8601String(),
            ),
          ],
    createdAt: DateTime(2026).toIso8601String(),
  );
}
