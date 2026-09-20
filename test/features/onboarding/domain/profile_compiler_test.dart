import 'package:copilot/features/onboarding/domain/decision_profile.dart';
import 'package:copilot/features/onboarding/domain/decision_profile_catalogs.dart';
import 'package:copilot/features/onboarding/domain/onboarding_answer.dart';
import 'package:copilot/features/onboarding/domain/profile_compiler.dart';
import 'package:flutter_test/flutter_test.dart';

const _canonicalReadingIds = <String>[
  'structural_level_gap',
  'positive_streak',
  'negative_streak',
  'improving_form',
  'declining_form',
  'form_gap',
  'strong_home_team',
  'weak_home_team',
  'strong_away_team',
  'weak_away_team',
  'home_away_advantage',
  'away_home_advantage',
  'prolific_attack',
  'scoring_difficulty',
  'solid_defense',
  'fragile_defense',
  'frequent_clean_sheet',
  'frequent_over_25',
  'frequent_btts',
  'frequent_under_25',
  'misleading_result',
  'head_to_head_dominance',
  'frequent_first_half_scoring',
  'frequent_first_half_conceding',
  'frequent_second_half_scoring',
  'frequent_second_half_conceding',
  'standout_decisive_player',
  'key_player_unavailable',
];

const _canonicalScenarioIds = <String>[
  'solid_favorite',
  'struggling_team',
  'offensive_match',
  'defensive_match',
  'ranking_gap',
  'credible_outsider',
  'fragile_defense',
  'prolific_attack',
  'positive_series',
  'negative_series',
];

void main() {
  group('ProfileCompiler', () {
    test('compiles completed V3 answers into a versioned decision profile', () {
      const sourceProfile = DecisionProfile(
        onboardingVersion: '3.0',
        answers: [
          OnboardingAnswer(
            questionId: 'competitions',
            orderedOptionIds: ['fr_ligue_1', '39'],
          ),
          OnboardingAnswer(
            questionId: 'markets',
            orderedOptionIds: ['double_chance', 'match_result'],
          ),
          OnboardingAnswer(
            questionId: 'opportunity_profiles',
            orderedOptionIds: ['ranking_gap', 'solid_favorite'],
          ),
        ],
      );

      final profile = const ProfileCompiler().compile(sourceProfile);

      expect(profile.profileSchemaVersion, 3);
      expect(profile.onboardingVersion, '3.0');
      expect(profile.configurationState, ProfileConfigurationState.completed);
      expect(profile.competitions['61']?.enabled, isTrue);
      expect(profile.competitions['61']?.apiFootballLeagueId, 61);
      expect(profile.competitions['39']?.enabled, isTrue);
      expect(profile.competitions['135']?.enabled, isFalse);
      expect(profile.competitions['2']?.enabled, isFalse);
      expect(profile.markets['doubleChance']?.enabled, isTrue);
      expect(profile.markets['doubleChance']?.sourceOptionId, 'double_chance');
      expect(profile.markets['matchResult']?.enabled, isTrue);
      expect(profile.markets['goalsTotal']?.enabled, isFalse);
      expect(profile.markets['playerAnytimeScorer']?.enabled, isFalse);
      expect(profile.matchTypes['ranking_gap']?.enabled, isTrue);
      expect(profile.opportunityProfiles['solid_favorite']?.enabled, isTrue);
      expect(profile.matchTypes['credible_outsider']?.enabled, isFalse);
      expect(profile.compatibility.migratedFromSchemaVersion, isNull);
      expect(profile.compatibility.ignoredLegacyQuestionIds, isEmpty);
    });

    test('migrates legacy matchTypes into opportunityProfiles', () {
      const sourceProfile = DecisionProfile(
        onboardingVersion: '1.1',
        answers: [
          OnboardingAnswer(
            questionId: 'competitions',
            orderedOptionIds: ['fr_ligue_1'],
          ),
          OnboardingAnswer(
            questionId: 'markets',
            orderedOptionIds: ['double_chance'],
          ),
          OnboardingAnswer(
            questionId: 'match_types',
            orderedOptionIds: ['ranking_gap'],
          ),
          OnboardingAnswer(
            questionId: 'market_minimum_odds',
            orderedOptionIds: [],
            marketMinimumOdds: {'double_chance': 1.80},
          ),
        ],
      );

      final profile = const ProfileCompiler().compile(sourceProfile);

      expect(profile.configurationState, ProfileConfigurationState.completed);
      expect(profile.isCompetitionEnabled('61'), isTrue);
      expect(profile.enabledMarket('doubleChance'), isNotNull);
      expect(profile.opportunityProfiles['ranking_gap']?.enabled, isTrue);
      expect(profile.compatibility.migratedFromSchemaVersion, 1);
      expect(profile.compatibility.ignoredLegacyQuestionIds, [
        'market_minimum_odds',
      ]);
    });

    test('does not promote former scorer and creator ids into a reading', () {
      const sourceProfile = DecisionProfile(
        onboardingVersion: '3.0',
        answers: [
          OnboardingAnswer(
            questionId: 'competitions',
            orderedOptionIds: ['39'],
          ),
          OnboardingAnswer(
            questionId: 'readings',
            orderedOptionIds: ['standout_goal_scorer', 'standout_creator'],
          ),
        ],
      );

      final profile = const ProfileCompiler().compile(sourceProfile);

      expect(profile.readings['standout_decisive_player']?.enabled, isFalse);
      expect(profile.isReadingAllowed('standout_goal_scorer'), isFalse);
      expect(profile.isReadingAllowed('standout_creator'), isFalse);
      expect(profile.isReadingAllowed('standout_decisive_player'), isFalse);
      expect(profile.isReadingAllowed('high_volume_shooter'), isFalse);
    });

    test(
      'keeps an empty profile unconfigured without questionnaire defaults',
      () {
        const sourceProfile = DecisionProfile(
          onboardingVersion: '2.0',
          answers: [],
        );

        final profile = const ProfileCompiler().compile(sourceProfile);

        expect(
          profile.configurationState,
          ProfileConfigurationState.notStarted,
        );
        expect(profile.competitions['61']?.enabled, isFalse);
        expect(profile.markets['matchResult']?.enabled, isFalse);
        expect(profile.matchTypes['solid_favorite']?.enabled, isFalse);
      },
    );

    test('keeps readings separate from scenarios', () {
      const sourceProfile = DecisionProfile(
        onboardingVersion: '3.0',
        answers: [
          OnboardingAnswer(
            questionId: 'competitions',
            orderedOptionIds: ['eng_premier_league'],
          ),
          OnboardingAnswer(
            questionId: 'markets',
            orderedOptionIds: ['double_chance'],
          ),
          OnboardingAnswer(
            questionId: 'opportunity_profiles',
            orderedOptionIds: ['ranking_gap'],
          ),
          OnboardingAnswer(
            questionId: 'readings',
            orderedOptionIds: ['structural_level_gap'],
          ),
        ],
      );

      final profile = const ProfileCompiler().compile(sourceProfile);

      expect(profile.isReadingAllowed('balanced_hierarchy'), isFalse);
      expect(profile.isReadingAllowed('ranking_superiority'), isFalse);
      expect(profile.isReadingAllowed('structural_level_gap'), isTrue);
      expect(profile.isReadingAllowed('positive_streak'), isFalse);
      expect(profile.isOpportunityProfileEnabled('ranking_gap'), isTrue);
    });

    test('locks the canonical reading and scenario contracts', () {
      expect(
        ReadingPreferenceCatalog.values.map((reading) => reading.id),
        _canonicalReadingIds,
      );
      expect(
        OpportunityProfileCatalog.values.map((scenario) => scenario.id),
        _canonicalScenarioIds,
      );
    });

    test('matches every selected reading only by its exact canonical id', () {
      for (final selectedId in _canonicalReadingIds) {
        final profile = const ProfileCompiler().compile(
          DecisionProfile(
            onboardingVersion: '3.0',
            answers: [
              const OnboardingAnswer(
                questionId: 'competitions',
                orderedOptionIds: ['eng_premier_league'],
              ),
              OnboardingAnswer(
                questionId: 'readings',
                orderedOptionIds: [selectedId],
              ),
            ],
          ),
        );

        for (final candidateId in _canonicalReadingIds) {
          expect(
            profile.isReadingAllowed(candidateId),
            candidateId == selectedId,
            reason: '$selectedId must not authorize $candidateId.',
          );
        }
      }
    });

    test('never promotes technical signals into selected readings', () {
      const technicalIds = [
        'ranking_superiority',
        'ranking_inferiority',
        'standout_goal_scorer',
        'standout_creator',
        'form_advantage',
        'venue_strength',
        'high_xg_creation',
        'attack_in_form',
        'low_xg_creation',
        'offensive_underperformance',
        'high_xg_conceded',
        'defensive_underperformance',
      ];

      for (final selectedId in _canonicalReadingIds) {
        final profile = const ProfileCompiler().compile(
          DecisionProfile(
            onboardingVersion: '3.0',
            answers: [
              const OnboardingAnswer(
                questionId: 'competitions',
                orderedOptionIds: ['eng_premier_league'],
              ),
              OnboardingAnswer(
                questionId: 'readings',
                orderedOptionIds: [selectedId],
              ),
            ],
          ),
        );
        for (final technicalId in technicalIds) {
          expect(
            profile.isReadingAllowed(technicalId),
            isFalse,
            reason: '$technicalId must never be promoted to $selectedId.',
          );
        }
      }
    });

    test('matches every selected scenario only by its exact id', () {
      for (final selectedId in _canonicalScenarioIds) {
        final profile = const ProfileCompiler().compile(
          DecisionProfile(
            onboardingVersion: '3.0',
            answers: [
              const OnboardingAnswer(
                questionId: 'competitions',
                orderedOptionIds: ['eng_premier_league'],
              ),
              OnboardingAnswer(
                questionId: 'opportunity_profiles',
                orderedOptionIds: [selectedId],
              ),
            ],
          ),
        );

        for (final candidateId in _canonicalScenarioIds) {
          expect(
            profile.isOpportunityProfileEnabled(candidateId),
            candidateId == selectedId,
            reason: '$selectedId must not authorize $candidateId.',
          );
        }
      }
    });

    test('allows a completed reading-only profile', () {
      const sourceProfile = DecisionProfile(
        onboardingVersion: '3.0',
        answers: [
          OnboardingAnswer(
            questionId: 'competitions',
            orderedOptionIds: ['eng_premier_league'],
          ),
          OnboardingAnswer(
            questionId: 'readings',
            orderedOptionIds: ['positive_streak'],
          ),
        ],
      );

      final profile = const ProfileCompiler().compile(sourceProfile);

      expect(profile.isCompleted, isTrue);
      expect(profile.hasEnabledReadings, isTrue);
      expect(profile.isReadingAllowed('positive_streak'), isTrue);
      expect(profile.hasEnabledOpportunityProfiles, isFalse);
    });

    test('keeps technical server signals separate from user readings', () {
      const sourceProfile = DecisionProfile(
        onboardingVersion: '3.0',
        answers: [
          OnboardingAnswer(
            questionId: 'competitions',
            orderedOptionIds: ['eng_premier_league'],
          ),
          OnboardingAnswer(
            questionId: 'readings',
            orderedOptionIds: ['positive_streak', 'strong_away_team'],
          ),
        ],
      );

      final profile = const ProfileCompiler().compile(sourceProfile);

      expect(profile.isReadingAllowed('form_advantage'), isFalse);
      expect(profile.isReadingAllowed('venue_strength'), isFalse);
      expect(profile.isReadingAllowed('match_card_profile'), isFalse);
    });

    test(
      'migrates the former combined venue advantage into both directions',
      () {
        const sourceProfile = DecisionProfile(
          onboardingVersion: '3.0',
          answers: [
            OnboardingAnswer(
              questionId: 'competitions',
              orderedOptionIds: ['eng_premier_league'],
            ),
            OnboardingAnswer(
              questionId: 'readings',
              orderedOptionIds: ['home_away_mismatch'],
            ),
          ],
        );

        final profile = const ProfileCompiler().compile(sourceProfile);

        expect(profile.isReadingAllowed('home_away_advantage'), isTrue);
        expect(profile.isReadingAllowed('away_home_advantage'), isTrue);
      },
    );

    test(
      'keeps the seven validated reading categories exhaustive and disjoint',
      () {
        final categories = ReadingPreferenceCategoryCatalog.values;
        final categoryIds = categories.map((category) => category.id).toList();
        final allReadingIds = [
          for (final category in categories) ...category.readingIds,
        ];

        expect(categoryIds, [
          'ranking_form',
          'attack_defense',
          'goals',
          'match_periods',
          'availability',
          'context',
          'player_statistics',
        ]);
        expect(allReadingIds.toSet(), hasLength(allReadingIds.length));
        expect(allReadingIds.toSet(), {
          for (final reading in ReadingPreferenceCatalog.values) reading.id,
        });
        expect(
          ReadingPreferenceCategoryCatalog.byId(
            'player_statistics',
          )!.readingIds,
          ['standout_decisive_player'],
        );
      },
    );

    test('keeps xG signals out of selectable reading preferences', () {
      expect(ReadingPreferenceCatalog.contains('high_xg_creation'), isFalse);
      expect(
        ReadingPreferenceCatalog.contains('offensive_underperformance'),
        isFalse,
      );
    });

    test('keeps match profiles inside scenarios, not reading preferences', () {
      expect(ReadingPreferenceCatalog.contains('open_match_profile'), isFalse);
      expect(
        ReadingPreferenceCatalog.contains('closed_match_profile'),
        isFalse,
      );
    });

    test('drops legacy statistical selections from the reading profile', () {
      expect(
        ReadingPreferenceCatalog.normalizeSelectionIds([
          'high_shot_volume',
          'low_total_corners_profile',
          'high_card_rate',
        ]),
        isEmpty,
      );
    });

    test(
      'serializes and restores a decision profile for local development',
      () {
        const sourceProfile = DecisionProfile(
          onboardingVersion: 'test',
          answers: [
            OnboardingAnswer(
              questionId: 'markets',
              orderedOptionIds: ['double_chance'],
              marketMinimumOdds: {'double_chance': 1.45},
            ),
            OnboardingAnswer(
              questionId: 'ticket_odds_ranges',
              orderedOptionIds: ['range_2_00_4_00'],
              oddsRanges: {'range_2_00_4_00': OddsRange(min: 2, max: 4)},
            ),
          ],
        );

        final restored = DecisionProfile.fromJson(sourceProfile.toJson());

        expect(restored.onboardingVersion, 'test');
        expect(restored.answers, hasLength(2));
        expect(restored.answers.first.questionId, 'markets');
        expect(restored.answers.first.orderedOptionIds, ['double_chance']);
        expect(restored.answers.first.marketMinimumOdds['double_chance'], 1.45);
        expect(restored.answers.last.oddsRanges['range_2_00_4_00']?.min, 2);
        expect(restored.answers.last.oddsRanges['range_2_00_4_00']?.max, 4);
      },
    );

    test(
      'keeps compiled markets identical after a persisted profile reload',
      () {
        const saved = DecisionProfile(
          onboardingVersion: '3.0',
          answers: [
            OnboardingAnswer(
              questionId: 'competitions',
              orderedOptionIds: ['fr_ligue_1'],
            ),
            OnboardingAnswer(
              questionId: 'markets',
              orderedOptionIds: ['matchResult', 'player_scorer'],
            ),
            OnboardingAnswer(
              questionId: 'opportunity_profiles',
              orderedOptionIds: ['ranking_gap'],
            ),
          ],
        );

        final reloaded = DecisionProfile.fromJson(saved.toJson());
        final before = const ProfileCompiler().compile(saved);
        final after = const ProfileCompiler().compile(reloaded);

        expect(
          MarketCatalog.sourceOptionIdsFor(saved.optionIdsFor('markets')),
          {'match_result', 'player_scorer'},
        );
        expect(
          MarketCatalog.enabledMarketIdsFor(saved.optionIdsFor('markets')),
          {'matchResult', 'playerAnytimeScorer'},
        );
        expect(
          before.markets.entries
              .where((entry) => entry.value.enabled)
              .map((entry) => entry.key)
              .toSet(),
          after.markets.entries
              .where((entry) => entry.value.enabled)
              .map((entry) => entry.key)
              .toSet(),
        );
        expect(after.markets['matchResult']?.enabled, isTrue);
        expect(after.markets['playerAnytimeScorer']?.enabled, isTrue);
      },
    );
  });
}
