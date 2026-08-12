import 'package:flutter_test/flutter_test.dart';
import 'package:copilot/features/matches/domain/match_board_item.dart';
import 'package:copilot/features/matches/presentation/opportunity_decision_presenter.dart';

void main() {
  group('FootballReadingCopyCatalog', () {
    test('keeps distinct labels for different simple readings', () {
      const negativeStreak = CopilotArgument(
        id: 'negative_streak_home',
        type: CopilotArgumentType.weakRecentForm,
        family: CopilotArgumentFamily.form,
        severity: CopilotArgumentSeverity.moderate,
        subjectName: 'Halmstad',
        parameters: {
          'readingId': 'negative_streak',
          'sampleSize': 5,
          'evidenceValue': 'LDLLL',
        },
        evidence: [
          ThesisEvidence(
            label: 'Halmstad traverse une dynamique négative (LDLLL).',
            tone: ThesisEvidenceTone.positive,
          ),
        ],
        evidenceAction: CopilotEvidenceAction.form,
      );
      const scoringDifficulty = CopilotArgument(
        id: 'scoring_difficulty_home',
        type: CopilotArgumentType.weakRecentForm,
        family: CopilotArgumentFamily.attack,
        severity: CopilotArgumentSeverity.moderate,
        subjectName: 'Halmstad',
        parameters: {
          'readingId': 'scoring_difficulty',
          'sampleSize': 16,
          'evidenceValue': 0.70,
        },
        evidence: [
          ThesisEvidence(
            label: 'Halmstad produit peu au score (0.70 but/match).',
            tone: ThesisEvidenceTone.positive,
          ),
        ],
        evidenceAction: CopilotEvidenceAction.offensiveStats,
      );

      expect(
        FootballReadingCopyCatalog.titleFor(negativeStreak),
        'Dynamique négative',
      );
      expect(
        FootballReadingCopyCatalog.titleFor(scoringDifficulty),
        'Production offensive faible',
      );
      expect(
        FootballReadingCopyCatalog.summaryFor(negativeStreak),
        'LDLLL sur les 5 derniers matchs · 1 nul · 4 défaites.',
      );
      expect(
        FootballReadingCopyCatalog.summaryFor(scoringDifficulty),
        '0.70 but(s) marqué(s) par match · échantillon 16 matchs.',
      );
    });
  });
}
