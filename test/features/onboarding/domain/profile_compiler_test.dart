import 'package:copilot/features/onboarding/domain/decision_profile.dart';
import 'package:copilot/features/onboarding/domain/decision_profile_catalogs.dart';
import 'package:copilot/features/onboarding/domain/onboarding_answer.dart';
import 'package:copilot/features/onboarding/domain/profile_compiler.dart';
import 'package:flutter_test/flutter_test.dart';

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
      expect(profile.competitions['2'], isNull);
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
