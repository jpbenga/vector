import 'match_board_item.dart';

enum ReadingStatus { detected, notDetected, insufficientData }

enum ReadingStrength { weak, moderate, strong }

enum ReadingSubjectSide { match, home, away }

enum ReadingEvidenceKind {
  standing,
  form,
  homeAway,
  goals,
  expectedGoals,
  market,
  availability,
  sample,
}

class ReadingEvidence {
  const ReadingEvidence({
    required this.label,
    required this.kind,
    required this.sourcePath,
    this.value,
    this.isPostMatchOnly = false,
  });

  final String label;
  final ReadingEvidenceKind kind;
  final String sourcePath;
  final Object? value;
  final bool isPostMatchOnly;
}

class ReadingWarning {
  const ReadingWarning({
    required this.id,
    required this.label,
    required this.sourcePath,
  });

  final String id;
  final String label;
  final String sourcePath;
}

class FootballReading {
  const FootballReading({
    required this.id,
    required this.subjectTeamId,
    required this.subjectSide,
    required this.status,
    required this.strength,
    required this.evidence,
    required this.warnings,
    required this.asOf,
    required this.sampleSize,
    this.isContradiction = false,
  });

  final String id;
  final String subjectTeamId;
  final ReadingSubjectSide subjectSide;
  final ReadingStatus status;
  final ReadingStrength strength;
  final List<ReadingEvidence> evidence;
  final List<ReadingWarning> warnings;
  final DateTime asOf;
  final int sampleSize;
  final bool isContradiction;

  bool get isDetected => status == ReadingStatus.detected;

  ThesisEvidence toThesisEvidence() {
    return ThesisEvidence(
      label: evidence.isEmpty ? id : evidence.first.label,
      tone: isContradiction
          ? ThesisEvidenceTone.warning
          : ThesisEvidenceTone.positive,
    );
  }

  CopilotArgument toCopilotArgument({String? subjectName}) {
    final firstEvidence = evidence.isEmpty ? null : evidence.first;
    final parameters = <String, Object>{
      'readingId': id,
      'sampleSize': sampleSize,
      'asOf': asOf.toIso8601String(),
    };
    if (firstEvidence != null) {
      parameters['evidenceKind'] = firstEvidence.kind.name;
      final evidenceValue = firstEvidence.value;
      if (evidenceValue != null) {
        parameters['evidenceValue'] = evidenceValue;
      }
    }

    return CopilotArgument(
      id: '${id}_$subjectTeamId',
      type: _argumentType,
      family: isContradiction ? CopilotArgumentFamily.contradiction : _family,
      severity: strength == ReadingStrength.strong
          ? CopilotArgumentSeverity.strong
          : CopilotArgumentSeverity.moderate,
      subjectName: subjectName ?? subjectTeamId,
      parameters: parameters,
      evidence: [toThesisEvidence()],
      evidenceAction: _evidenceAction,
    );
  }

  CopilotArgumentType get _argumentType {
    if (isContradiction) {
      return CopilotArgumentType.contradiction;
    }

    return switch (id) {
      'ranking_superiority' ||
      'structural_level_gap' => CopilotArgumentType.rankingGap,
      'negative_streak' ||
      'declining_form' ||
      'scoring_difficulty' => CopilotArgumentType.weakRecentForm,
      'positive_streak' ||
      'improving_form' => CopilotArgumentType.strongRecentForm,
      'fragile_defense' ||
      'high_xg_conceded' ||
      'defensive_underperformance' => CopilotArgumentType.fragileDefense,
      'prolific_attack' ||
      'high_xg_creation' ||
      'attack_in_form' => CopilotArgumentType.strongAttack,
      'open_match_profile' ||
      'frequent_over_25' ||
      'frequent_btts' => CopilotArgumentType.openMatch,
      'closed_match_profile' ||
      'frequent_under_25' => CopilotArgumentType.closedMatch,
      _ => CopilotArgumentType.rankingGap,
    };
  }

  CopilotArgumentFamily get _family {
    return switch (id) {
      'ranking_superiority' ||
      'balanced_hierarchy' ||
      'structural_level_gap' => CopilotArgumentFamily.hierarchy,
      'positive_streak' ||
      'negative_streak' ||
      'improving_form' ||
      'declining_form' => CopilotArgumentFamily.form,
      'strong_home_team' ||
      'weak_home_team' ||
      'strong_away_team' ||
      'weak_away_team' ||
      'home_away_mismatch' => CopilotArgumentFamily.performance,
      'prolific_attack' ||
      'attack_in_form' ||
      'scoring_difficulty' ||
      'high_xg_creation' ||
      'low_xg_creation' ||
      'offensive_underperformance' ||
      'offensive_overperformance' => CopilotArgumentFamily.attack,
      'solid_defense' ||
      'fragile_defense' ||
      'declining_defense' ||
      'frequent_clean_sheet' ||
      'high_xg_conceded' ||
      'defensive_underperformance' ||
      'defensive_overperformance' => CopilotArgumentFamily.defense,
      'open_match_profile' ||
      'closed_match_profile' ||
      'frequent_btts' ||
      'frequent_over_25' ||
      'frequent_under_25' => CopilotArgumentFamily.rhythm,
      _ => CopilotArgumentFamily.performance,
    };
  }

  CopilotEvidenceAction get _evidenceAction {
    return switch (_family) {
      CopilotArgumentFamily.market => CopilotEvidenceAction.market,
      CopilotArgumentFamily.hierarchy => CopilotEvidenceAction.standings,
      CopilotArgumentFamily.performance => CopilotEvidenceAction.results,
      CopilotArgumentFamily.defense => CopilotEvidenceAction.defensiveStats,
      CopilotArgumentFamily.attack => CopilotEvidenceAction.offensiveStats,
      CopilotArgumentFamily.form => CopilotEvidenceAction.form,
      CopilotArgumentFamily.rhythm => CopilotEvidenceAction.rhythm,
      CopilotArgumentFamily.contradiction => CopilotEvidenceAction.results,
    };
  }
}

class FootballAnalysis {
  const FootballAnalysis({
    required this.fixtureId,
    required this.asOf,
    required this.readings,
  });

  final String fixtureId;
  final DateTime asOf;
  final List<FootballReading> readings;

  List<FootballReading> detected({
    String? id,
    String? subjectTeamId,
    ReadingSubjectSide? side,
  }) {
    return readings
        .where((reading) {
          if (!reading.isDetected) {
            return false;
          }
          if (id != null && reading.id != id) {
            return false;
          }
          if (subjectTeamId != null && reading.subjectTeamId != subjectTeamId) {
            return false;
          }
          if (side != null && reading.subjectSide != side) {
            return false;
          }

          return true;
        })
        .toList(growable: false);
  }

  bool has(String id, {String? subjectTeamId}) {
    return detected(id: id, subjectTeamId: subjectTeamId).isNotEmpty;
  }

  List<FootballReading> get supportingReadings {
    return readings
        .where((reading) => reading.isDetected && !reading.isContradiction)
        .toList(growable: false);
  }

  List<FootballReading> get contradictoryReadings {
    return readings
        .where((reading) => reading.isDetected && reading.isContradiction)
        .toList(growable: false);
  }
}
