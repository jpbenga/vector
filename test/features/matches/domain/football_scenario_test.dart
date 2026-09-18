import 'package:copilot/features/matches/domain/football_reading.dart';
import 'package:copilot/features/matches/domain/football_scenario.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FootballScenarioDetector', () {
    test(
      'detects expected domination only when its strict AND is complete',
      () {
        const detector = FootballScenarioDetector();
        final readings = [
          _reading('ranking_superiority', 'home', ReadingSubjectSide.home),
          _reading('form_advantage', 'home', ReadingSubjectSide.home),
          _reading('structural_level_gap', 'home', ReadingSubjectSide.home),
        ];

        final matches = detector.detect(
          analysis: _analysis(readings),
          homeTeamId: 'home',
          awayTeamId: 'away',
        );

        expect(matches, hasLength(2));
        expect(
          matches.map((match) => match.scenarioId),
          containsAll(['solid_favorite', 'ranking_gap']),
        );
        final domination = matches.singleWhere(
          (match) => match.scenarioId == 'solid_favorite',
        );
        expect(domination.subjectTeamId, 'home');
        expect(domination.subjectSide, ReadingSubjectSide.home);
        expect(
          domination.supportingReadings.map((reading) => reading.id),
          containsAll([
            'ranking_superiority',
            'form_advantage',
            'structural_level_gap',
          ]),
        );
      },
    );

    for (final missingId in [
      'ranking_superiority',
      'form_advantage',
      'structural_level_gap',
    ]) {
      test('does not detect expected domination without $missingId', () {
        final readings = [
          _reading('ranking_superiority', 'home', ReadingSubjectSide.home),
          _reading('form_advantage', 'home', ReadingSubjectSide.home),
          _reading('structural_level_gap', 'home', ReadingSubjectSide.home),
        ]..removeWhere((reading) => reading.id == missingId);

        final matches = const FootballScenarioDetector().detect(
          analysis: _analysis(readings),
          homeTeamId: 'home',
          awayTeamId: 'away',
        );

        expect(
          matches.where((match) => match.scenarioId == 'solid_favorite'),
          isEmpty,
        );
      });
    }

    test('does not combine readings carried by different teams', () {
      final matches = const FootballScenarioDetector().detect(
        analysis: _analysis([
          _reading('ranking_superiority', 'home', ReadingSubjectSide.home),
          _reading('form_advantage', 'away', ReadingSubjectSide.away),
          _reading('structural_level_gap', 'home', ReadingSubjectSide.home),
        ]),
        homeTeamId: 'home',
        awayTeamId: 'away',
      );

      expect(
        matches.where((match) => match.scenarioId == 'solid_favorite'),
        isEmpty,
      );
    });

    test('detects a struggling team only for the common subject', () {
      final matches = const FootballScenarioDetector().detect(
        analysis: _analysis([
          _reading('negative_streak', 'away', ReadingSubjectSide.away),
          _reading('scoring_difficulty', 'away', ReadingSubjectSide.away),
          _reading('fragile_defense', 'away', ReadingSubjectSide.away),
        ]),
        homeTeamId: 'home',
        awayTeamId: 'away',
      );

      final difficulty = matches.singleWhere(
        (match) => match.scenarioId == 'struggling_team',
      );
      expect(difficulty.subjectTeamId, 'away');
      expect(difficulty.subjectSide, ReadingSubjectSide.away);
    });

    test('ignores a contradictory reading in a required slot', () {
      final matches = const FootballScenarioDetector().detect(
        analysis: _analysis([
          _reading('negative_streak', 'away', ReadingSubjectSide.away),
          _reading('scoring_difficulty', 'away', ReadingSubjectSide.away),
          _reading(
            'fragile_defense',
            'away',
            ReadingSubjectSide.away,
            isContradiction: true,
          ),
        ]),
        homeTeamId: 'home',
        awayTeamId: 'away',
      );

      expect(
        matches.where((match) => match.scenarioId == 'struggling_team'),
        isEmpty,
      );
    });

    test('detects the open-match contract when every reading is present', () {
      final matches = const FootballScenarioDetector().detect(
        analysis: _analysis([
          _reading('open_match_profile', 'fixture', ReadingSubjectSide.match),
          _reading('prolific_attack', 'home', ReadingSubjectSide.home),
          _reading('prolific_attack', 'away', ReadingSubjectSide.away),
          _reading('fragile_defense', 'away', ReadingSubjectSide.away),
        ]),
        homeTeamId: 'home',
        awayTeamId: 'away',
      );

      expect(
        matches.where((match) => match.scenarioId == 'offensive_match'),
        hasLength(1),
      );
    });

    test('supports match, both-team and at-least-one-team requirements', () {
      const definition = FootballScenarioDefinition(
        id: 'test_match_contract',
        scope: FootballScenarioScope.match,
        requirements: [
          ScenarioReadingRequirement(
            readingId: 'open_match_profile',
            subject: ScenarioRequirementSubject.match,
          ),
          ScenarioReadingRequirement(
            readingId: 'prolific_attack',
            subject: ScenarioRequirementSubject.bothTeams,
          ),
          ScenarioReadingRequirement(
            readingId: 'fragile_defense',
            subject: ScenarioRequirementSubject.atLeastOneTeam,
          ),
        ],
      );
      final matches = const FootballScenarioDetector(definitions: [definition])
          .detect(
            analysis: _analysis([
              _reading(
                'open_match_profile',
                'fixture',
                ReadingSubjectSide.match,
              ),
              _reading('prolific_attack', 'home', ReadingSubjectSide.home),
              _reading('prolific_attack', 'away', ReadingSubjectSide.away),
              _reading('fragile_defense', 'away', ReadingSubjectSide.away),
            ]),
            homeTeamId: 'home',
            awayTeamId: 'away',
          );

      expect(matches, hasLength(1));
      expect(matches.single.subjectSide, ReadingSubjectSide.match);
      expect(matches.single.supportingReadings, hasLength(4));
    });

    for (final scenario in <String, List<(String, String, ReadingSubjectSide)>>{
      'corner_pressure': [
        ('high_corner_creation', 'home', ReadingSubjectSide.home),
        ('high_corners_conceded', 'away', ReadingSubjectSide.away),
        ('high_shot_volume', 'home', ReadingSubjectSide.home),
      ],
    }.entries) {
      test('${scenario.key} needs every reading on the correct side', () {
        final readings = [
          for (final item in scenario.value)
            _reading(item.$1, item.$2, item.$3),
        ];
        List<FootballScenarioMatch> detect(List<FootballReading> input) =>
            const FootballScenarioDetector()
                .detect(
                  analysis: _analysis(input),
                  homeTeamId: 'home',
                  awayTeamId: 'away',
                )
                .where((match) => match.scenarioId == scenario.key)
                .toList();
        expect(detect(readings), hasLength(1));
        for (var index = 0; index < readings.length; index += 1) {
          expect(detect([...readings]..removeAt(index)), isEmpty);
        }
      });
    }

    test('disciplinary tension requires both teams and the match profile', () {
      final readings = [
        _reading('high_card_rate', 'home', ReadingSubjectSide.home),
        _reading('high_card_rate', 'away', ReadingSubjectSide.away),
        _reading(
          'high_total_cards_profile',
          'fixture',
          ReadingSubjectSide.match,
        ),
      ];
      List<FootballScenarioMatch> detect(List<FootballReading> input) =>
          const FootballScenarioDetector()
              .detect(
                analysis: _analysis(input),
                homeTeamId: 'home',
                awayTeamId: 'away',
              )
              .where((match) => match.scenarioId == 'disciplinary_tension')
              .toList();
      expect(detect(readings), hasLength(1));
      for (var index = 0; index < readings.length; index += 1) {
        expect(detect([...readings]..removeAt(index)), isEmpty);
      }
    });
  });
}

FootballAnalysis _analysis(List<FootballReading> readings) {
  return FootballAnalysis(
    fixtureId: 'fixture',
    asOf: DateTime.utc(2026, 9, 14),
    readings: readings,
  );
}

FootballReading _reading(
  String id,
  String teamId,
  ReadingSubjectSide side, {
  bool isContradiction = false,
  int? playerId,
}) {
  return FootballReading(
    id: id,
    subjectTeamId: teamId,
    subjectSide: side,
    subjectKind: playerId == null
        ? ReadingSubjectKind.team
        : ReadingSubjectKind.player,
    playerId: playerId,
    playerName: playerId == null ? null : 'Player $playerId',
    status: ReadingStatus.detected,
    strength: ReadingStrength.moderate,
    evidence: const [],
    warnings: const [],
    asOf: DateTime.utc(2026, 9, 14),
    sampleSize: 5,
    isContradiction: isContradiction,
  );
}
