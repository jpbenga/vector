import 'package:copilot/features/matches/domain/football_reading.dart';
import 'package:copilot/features/matches/domain/football_scenario.dart';
import 'package:copilot/features/matches/domain/lector_guide_catalog.dart';
import 'package:copilot/features/onboarding/domain/decision_profile_catalogs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Every selectable reading and every scenario requirement has a complete guide',
    () {
      final ids = {
        ...ReadingPreferenceCatalog.values.map((reading) => reading.id),
        for (final scenario in FootballScenarioCatalog.values)
          ...scenario.requirements.map((requirement) => requirement.readingId),
      };
      expect(LectorGuideCatalog.readings.keys.toSet(), ids);
      for (final id in ids) {
        final guide = LectorGuideCatalog.readings[id]!;
        expect(LectorGuideCatalog.readingLabel(id), isNot(id), reason: id);
        expect(guide.meaning, isNotEmpty, reason: id);
        expect(guide.conditions, isNotEmpty, reason: id);
        expect(guide.facts, isNotEmpty, reason: id);
        expect(guide.conclusion, isNotEmpty, reason: id);
        expect(guide.counterExample, isNotEmpty, reason: id);
      }
    },
  );

  for (final scenario in FootballScenarioCatalog.values.where(
    (definition) => definition.isAvailable,
  )) {
    test(
      '${scenario.id} example satisfies the real detector only with every requirement',
      () {
        final example = LectorScenarioExample(scenario);
        expect(example.detected(), isTrue);
        expect(example.detected(omitLast: true), isFalse);
        expect(
          example.readings().map((reading) => reading.id).toSet(),
          scenario.requirements
              .map((requirement) => requirement.readingId)
              .toSet(),
        );
      },
    );
  }

  test(
    'A superiority for Atlas and a form advantage for Rivage do not combine in the guide example',
    () {
      final definition = FootballScenarioCatalog.byId('solid_favorite')!;
      final readings = LectorScenarioExample(definition).readings();
      final formIndex = readings.indexWhere(
        (reading) => reading.id == 'form_advantage',
      );
      readings[formIndex] = FootballReading(
        id: 'form_advantage',
        subjectTeamId: LectorScenarioExample.awayId,
        subjectSide: ReadingSubjectSide.away,
        status: ReadingStatus.detected,
        strength: ReadingStrength.moderate,
        evidence: const [],
        warnings: const [],
        asOf: DateTime.utc(2026, 1, 1),
        sampleSize: 5,
      );
      final result = FootballScenarioDetector(definitions: [definition]).detect(
        analysis: FootballAnalysis(
          fixtureId: LectorScenarioExample.fixtureId,
          asOf: DateTime.utc(2026, 1, 1),
          readings: readings,
        ),
        homeTeamId: LectorScenarioExample.homeId,
        awayTeamId: LectorScenarioExample.awayId,
      );
      expect(result, isEmpty);
    },
  );
}
