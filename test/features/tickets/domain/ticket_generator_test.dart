import 'package:copilot/features/matches/domain/match_board_item.dart';
import 'package:copilot/features/onboarding/domain/compiled_decision_profile.dart';
import 'package:copilot/features/onboarding/domain/decision_profile.dart';
import 'package:copilot/features/onboarding/domain/decision_profile_catalogs.dart';
import 'package:copilot/features/onboarding/domain/onboarding_answer.dart';
import 'package:copilot/features/onboarding/domain/profile_compiler.dart';
import 'package:copilot/features/opportunities/domain/opportunity.dart';
import 'package:copilot/features/tickets/domain/generated_ticket.dart';
import 'package:copilot/features/tickets/domain/generated_ticket_pick.dart';
import 'package:copilot/features/tickets/domain/ticket_generation_result.dart';
import 'package:copilot/features/tickets/domain/ticket_generator.dart';
import 'package:copilot/features/tickets/domain/ticket_strategy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TicketGenerator', () {
    test('classifies pick types at inclusive odds boundaries', () {
      expect(pickTypeForOdds(1.19), isNull);
      expect(pickTypeForOdds(1.20), PickType.prudent);
      expect(pickTypeForOdds(1.49), PickType.prudent);
      expect(pickTypeForOdds(1.50), PickType.normal);
      expect(pickTypeForOdds(2.19), PickType.normal);
      expect(pickTypeForOdds(2.20), PickType.audacious);
    });

    test('excludes opportunities without recommended market or low odds', () {
      final result = const TicketGenerator().generate(
        opportunities: [
          _opportunity('a', odds: null),
          _opportunity('b', odds: 1.19),
        ],
        strategies: [
          _strategy(pickTypes: const [PickType.prudent]),
        ],
        profile: _profile(),
        generatedAt: _now,
      );

      expect(result.status, TicketGenerationStatus.noUsableOpportunity);
      expect(result.tickets, isEmpty);
    });

    test('uses the strategy pick types as an actual generation constraint', () {
      final result = const TicketGenerator().generate(
        opportunities: [_opportunity('audacious', odds: 2.20)],
        strategies: [
          _strategy(
            pickTypes: const [PickType.prudent],
            minimumIndividualOdds: 1.20,
            maximumIndividualOdds: 3.00,
          ),
        ],
        profile: _profile(),
        generatedAt: _now,
      );

      expect(result.status, TicketGenerationStatus.noUsableOpportunity);
      expect(result.tickets, isEmpty);
    });

    test(
      'generates tickets respecting inclusive selection and total odds bounds',
      () {
        final result = const TicketGenerator().generate(
          opportunities: [
            _opportunity('a', odds: 1.20),
            _opportunity('b', odds: 1.50),
          ],
          strategies: [
            _strategy(
              pickTypes: const [PickType.prudent, PickType.normal],
              minimumSelections: 2,
              maximumSelections: 2,
              minimumTotalOdds: 1.80,
              maximumTotalOdds: 1.80,
            ),
          ],
          profile: _profile(),
          generatedAt: _now,
        );

        expect(result.status, TicketGenerationStatus.generated);
        expect(result.tickets.single.selectionCount, 2);
        expect(result.tickets.single.totalOdds, 1.80);
        expect(result.tickets.single.origin, TicketOrigin.copilotGenerated);
        expect(
          result.tickets.single.lifecycleStatus,
          TicketLifecycleStatus.proposed,
        );
        expect(result.tickets.single.constraintValidation.isValid, isTrue);
        expect(
          result.tickets.single.constraintValidation.satisfiedRuleIds,
          containsAll([
            'individual_odds',
            'selection_count',
            'total_odds',
            'unique_matches',
            'single_ticket_day',
          ]),
        );
      },
    );

    test('accepts open maximum total odds and multiple pickTypes', () {
      final result = const TicketGenerator().generate(
        opportunities: [
          _opportunity('a', odds: 1.55),
          _opportunity('b', odds: 2.20),
          _opportunity('c', odds: 1.42),
        ],
        strategies: [
          _strategy(
            pickTypes: const [PickType.normal, PickType.audacious],
            minimumSelections: 2,
            maximumSelections: 3,
            minimumTotalOdds: 3.40,
            maximumTotalOdds: null,
          ),
        ],
        profile: _profile(),
        generatedAt: _now,
      );

      expect(result.status, TicketGenerationStatus.generated);
      expect(result.tickets.first.matchIds, containsAll(['a', 'b']));
      expect(result.tickets.first.totalOdds, greaterThanOrEqualTo(3.40));
      expect(result.tickets.first.picks.map((pick) => pick.pickType).toSet(), {
        PickType.normal,
        PickType.audacious,
      });
    });

    test('returns notEnoughCompatiblePicks without relaxing selections', () {
      final result = const TicketGenerator().generate(
        opportunities: [_opportunity('a', odds: 1.50)],
        strategies: [
          _strategy(
            pickTypes: const [PickType.normal],
            minimumSelections: 2,
            maximumSelections: 3,
          ),
        ],
        profile: _profile(),
        generatedAt: _now,
      );

      expect(result.status, TicketGenerationStatus.notEnoughCompatiblePicks);
      expect(result.tickets, isEmpty);
    });

    test(
      'returns noCombinationWithinTotalOdds without relaxing odds range',
      () {
        final result = const TicketGenerator().generate(
          opportunities: [
            _opportunity('a', odds: 1.50),
            _opportunity('b', odds: 1.60),
          ],
          strategies: [
            _strategy(
              pickTypes: const [PickType.normal],
              minimumSelections: 2,
              maximumSelections: 2,
              minimumTotalOdds: 3.00,
              maximumTotalOdds: 3.10,
            ),
          ],
          profile: _profile(),
          generatedAt: _now,
        );

        expect(
          result.status,
          TicketGenerationStatus.noCombinationWithinTotalOdds,
        );
        expect(result.tickets, isEmpty);
      },
    );

    test('rejects invalid strategy configuration explicitly', () {
      final result = const TicketGenerator().generate(
        opportunities: [_opportunity('a', odds: 1.50)],
        strategies: [
          _strategy(
            pickTypes: const [],
            minimumSelections: 3,
            maximumSelections: 2,
          ),
        ],
        profile: _profile(),
        generatedAt: _now,
      );

      expect(
        result.status,
        TicketGenerationStatus.invalidStrategyConfiguration,
      );
    });

    test('generates stable, unique variants capped at three per strategy', () {
      final opportunities = [
        for (var index = 0; index < 7; index++)
          _opportunity(
            'match-$index',
            odds: 1.50 + (index * 0.02),
            score: 90 - index,
          ),
      ];
      final strategy = _strategy(
        pickTypes: const [PickType.normal],
        minimumSelections: 2,
        maximumSelections: 2,
        minimumTotalOdds: 2.20,
        maximumTotalOdds: 2.80,
      );
      const generator = TicketGenerator();

      final first = generator.generate(
        opportunities: opportunities,
        strategies: [strategy],
        profile: _profile(),
        generatedAt: _now,
      );
      final second = generator.generate(
        opportunities: opportunities,
        strategies: [strategy],
        profile: _profile(),
        generatedAt: _now,
      );

      expect(first.tickets, hasLength(3));
      expect(
        first.tickets.map((ticket) => ticket.matchIds.join('|')).toSet(),
        hasLength(3),
      );
      expect(
        first.tickets.map((ticket) => ticket.matchIds),
        second.tickets.map((ticket) => ticket.matchIds),
      );
      expect(
        first.tickets.map((ticket) => ticket.totalOdds),
        second.tickets.map((ticket) => ticket.totalOdds),
      );
    });

    test('keeps generated pick matchIds inside personalized opportunities', () {
      final opportunities = [
        _opportunity('visible-a', odds: 1.50),
        _opportunity('visible-b', odds: 1.60),
      ];
      final result = const TicketGenerator().generate(
        opportunities: opportunities,
        strategies: [
          _strategy(
            pickTypes: const [PickType.normal],
            minimumSelections: 1,
            maximumSelections: 2,
            minimumTotalOdds: 1.50,
          ),
        ],
        profile: _profile(),
        generatedAt: _now,
      );

      final personalizedIds = opportunities.map((item) => item.matchId).toSet();
      for (final ticket in result.tickets) {
        expect(ticket.matchIds.toSet().difference(personalizedIds), isEmpty);
      }
    });

    test('never mixes picks from different fixture days in one ticket', () {
      final day = DateTime.utc(2026, 8, 2, 20);
      final nextDay = DateTime.utc(2026, 8, 3, 20);
      final result = const TicketGenerator().generate(
        opportunities: [
          _opportunity('today-a', odds: 1.50, score: 95, kickoff: day),
          _opportunity('tomorrow-a', odds: 1.60, score: 94, kickoff: nextDay),
          _opportunity('today-b', odds: 1.55, score: 60, kickoff: day),
        ],
        strategies: [
          _strategy(
            pickTypes: const [PickType.normal],
            minimumSelections: 2,
            maximumSelections: 2,
            minimumTotalOdds: 2.20,
            maximumTotalOdds: 2.80,
          ),
        ],
        profile: _profile(),
        generatedAt: _now,
      );

      expect(result.status, TicketGenerationStatus.generated);
      expect(result.tickets, isNotEmpty);
      for (final ticket in result.tickets) {
        final ticketDays = ticket.picks
            .map(
              (pick) => DateTime(
                pick.kickoff!.year,
                pick.kickoff!.month,
                pick.kickoff!.day,
              ),
            )
            .toSet();
        expect(ticketDays, hasLength(1));
      }
      expect(
        result.tickets.first.matchIds,
        containsAll(['today-a', 'today-b']),
      );
    });

    test(
      'applies candidate limits per fixture day after the single-day rule',
      () {
        final day = DateTime.utc(2026, 8, 2, 20);
        final nextDay = DateTime.utc(2026, 8, 3, 20);
        final result = const TicketGenerator(maxCandidatesPerStrategy: 2)
            .generate(
              opportunities: [
                _opportunity('today-a', odds: 1.50, score: 100, kickoff: day),
                _opportunity(
                  'tomorrow-a',
                  odds: 1.60,
                  score: 99,
                  kickoff: nextDay,
                ),
                _opportunity('today-b', odds: 1.55, score: 10, kickoff: day),
              ],
              strategies: [
                _strategy(
                  pickTypes: const [PickType.normal],
                  minimumSelections: 2,
                  maximumSelections: 2,
                  minimumTotalOdds: 2.20,
                  maximumTotalOdds: 2.80,
                ),
              ],
              profile: _profile(),
              generatedAt: _now,
            );

        expect(result.status, TicketGenerationStatus.generated);
        expect(
          result.tickets.single.matchIds,
          containsAll(['today-a', 'today-b']),
        );
        expect(
          result.tickets.single.constraintValidation.satisfiedRuleIds,
          contains('single_ticket_day'),
        );
      },
    );

    test(
      'generates two-pick tickets for normal odds inside a narrow total range',
      () {
        final day = DateTime.utc(2026, 8, 2, 20);
        final result = const TicketGenerator().generate(
          opportunities: [
            _opportunity('match-1', odds: 1.50, score: 99, kickoff: day),
            _opportunity('match-2', odds: 1.90, score: 98, kickoff: day),
            _opportunity('match-3', odds: 1.55, score: 97, kickoff: day),
            _opportunity('match-4', odds: 1.62, score: 96, kickoff: day),
            _opportunity('match-5', odds: 1.72, score: 95, kickoff: day),
            _opportunity('match-6', odds: 1.82, score: 94, kickoff: day),
            _opportunity('match-7', odds: 1.95, score: 93, kickoff: day),
            _opportunity('match-8', odds: 2.05, score: 92, kickoff: day),
            _opportunity('match-9', odds: 2.19, score: 91, kickoff: day),
          ],
          strategies: [
            TicketStrategy(
              schemaVersion: TicketStrategy.currentSchemaVersion,
              id: 'normal-narrow',
              userId: 'user',
              name: 'Normal narrow',
              isActive: true,
              pickTypes: const [PickType.normal],
              minimumIndividualOdds: 1.50,
              maximumIndividualOdds: 2.19,
              minimumSelections: 2,
              maximumSelections: 3,
              minimumTotalOdds: 2.80,
              maximumTotalOdds: 3.10,
              priority: 1,
              createdAt: _now,
              updatedAt: _now,
            ),
          ],
          profile: _profile(),
          generatedAt: _now,
        );

        expect(result.status, TicketGenerationStatus.generated);
        expect(result.tickets, isNotEmpty);
        for (final ticket in result.tickets) {
          expect(ticket.selectionCount, 2);
          expect(ticket.totalOdds, greaterThanOrEqualTo(2.80));
          expect(ticket.totalOdds, lessThanOrEqualTo(3.10));
          expect(
            ticket.constraintValidation.satisfiedRuleIds,
            contains('single_ticket_day'),
          );
        }
      },
    );

    test('uses only opportunities from the requested target day', () {
      final day = DateTime.utc(2026, 8, 2, 20);
      final nextDay = DateTime.utc(2026, 8, 3, 20);
      final result = const TicketGenerator().generate(
        opportunities: [
          _opportunity('today-a', odds: 1.50, kickoff: day),
          _opportunity('tomorrow-a', odds: 1.60, kickoff: nextDay),
        ],
        strategies: [
          _strategy(
            pickTypes: const [PickType.normal],
            minimumSelections: 2,
            maximumSelections: 2,
            minimumTotalOdds: 2.20,
            maximumTotalOdds: 2.80,
          ),
        ],
        profile: _profile(),
        targetDate: day,
        generatedAt: _now,
      );

      expect(result.status, TicketGenerationStatus.notEnoughCompatiblePicks);
      expect(result.tickets, isEmpty);
    });

    test(
      'returns noActiveStrategy and profileIncomplete states explicitly',
      () {
        final noStrategy = const TicketGenerator().generate(
          opportunities: [_opportunity('a', odds: 1.50)],
          strategies: const [],
          profile: _profile(),
          generatedAt: _now,
        );
        final incomplete = const TicketGenerator().generate(
          opportunities: [_opportunity('a', odds: 1.50)],
          strategies: [_strategy()],
          profile: const ProfileCompiler().compile(
            const DecisionProfile(onboardingVersion: 'test', answers: []),
          ),
          generatedAt: _now,
        );

        expect(noStrategy.status, TicketGenerationStatus.noActiveStrategy);
        expect(incomplete.status, TicketGenerationStatus.profileIncomplete);
      },
    );
  });
}

final _now = DateTime.utc(2026, 8, 2, 12);

CompiledDecisionProfile _profile() {
  return const ProfileCompiler().compile(
    DecisionProfile(
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
    ),
  );
}

TicketStrategy _strategy({
  List<PickType> pickTypes = const [PickType.normal],
  double? minimumIndividualOdds,
  double? maximumIndividualOdds,
  int minimumSelections = 1,
  int maximumSelections = 3,
  double minimumTotalOdds = 1.20,
  double? maximumTotalOdds = 10,
}) {
  return TicketStrategy(
    schemaVersion: TicketStrategy.currentSchemaVersion,
    id: 'strategy',
    userId: 'user',
    name: 'Strategy',
    isActive: true,
    pickTypes: pickTypes,
    minimumIndividualOdds:
        minimumIndividualOdds ??
        TicketStrategy.defaultMinimumIndividualOddsFor(pickTypes),
    maximumIndividualOdds:
        maximumIndividualOdds ??
        TicketStrategy.defaultMaximumIndividualOddsFor(pickTypes),
    minimumSelections: minimumSelections,
    maximumSelections: maximumSelections,
    minimumTotalOdds: minimumTotalOdds,
    maximumTotalOdds: maximumTotalOdds,
    priority: 1,
    createdAt: _now,
    updatedAt: _now,
  );
}

Opportunity _opportunity(
  String id, {
  double? odds,
  int score = 80,
  DateTime? kickoff,
}) {
  final market = odds == null
      ? null
      : MatchMarket(
          id: 'doubleChance',
          label: 'Double chance',
          selections: [
            MarketOdds(id: 'selection-$id', label: '1X', odds: odds),
          ],
          bookmakerName: 'Demo',
        );
  final recommendedMarket = market == null
      ? null
      : RecommendedMarket(market: market, selection: market.selections.first);

  return Opportunity(
    sourceMatch: MatchBoardItem(
      fixture: NormalizedFixture(
        id: id,
        competition: const CompetitionInfo(
          id: '61',
          name: 'Ligue 1',
          country: CountryInfo(code: 'FR', name: 'France'),
          season: 2026,
        ),
        homeTeam: TeamInfo(id: 'home-$id', name: 'Home $id'),
        awayTeam: TeamInfo(id: 'away-$id', name: 'Away $id'),
        kickoffLabel: '20:00',
        kickoff: kickoff ?? DateTime.utc(2026, 8, 2, 20),
        status: FixtureStatus.scheduled,
      ),
      primaryMarket: const MarketOdds(
        id: 'market_unavailable',
        label: 'Marché indisponible',
        odds: 0,
      ),
      availableMarkets: [?market],
      compatibility: 0,
      signals: const [],
    ),
    engineScore: score,
    detectedSignals: const [
      MatchSignal(
        id: 'signal',
        title: 'Signal',
        summary: 'Signal détecté',
        proofs: ['Preuve'],
      ),
    ],
    retainedTheses: [
      MatchThesis(
        id: 'solid_favorite',
        title: 'Favori solide',
        summary: 'Lecture Copilot',
        status: recommendedMarket == null
            ? MatchThesisStatus.watchlist
            : MatchThesisStatus.recommended,
        confidence: recommendedMarket == null ? 0 : score,
        supportingEvidence: const [],
        limits: const [],
        profileReasons: const [],
        recommendedMarket: recommendedMarket,
      ),
    ],
    compatibleMarkets: const [],
    recommendedMarket: recommendedMarket,
  );
}
