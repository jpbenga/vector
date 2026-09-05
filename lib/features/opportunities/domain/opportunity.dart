import '../../matches/domain/match_board_item.dart';
import '../../matches/domain/football_reading.dart';
import '../../onboarding/domain/decision_profile_catalogs.dart';

enum ThesisAssessmentStatus { supported, eligibleButUnsupported, notEligible }

enum ThesisEvidenceRelation {
  coreSupport,
  additionalSupport,
  contradiction,
  resistance,
  nonDiscriminating,
  notRelevant,
  evidenceUnavailable,
}

extension ThesisEvidenceRelationCode on ThesisEvidenceRelation {
  String get code {
    return switch (this) {
      ThesisEvidenceRelation.coreSupport => 'CORE_SUPPORT',
      ThesisEvidenceRelation.additionalSupport => 'ADDITIONAL_SUPPORT',
      ThesisEvidenceRelation.contradiction => 'CONTRADICTION',
      ThesisEvidenceRelation.resistance => 'RESISTANCE',
      ThesisEvidenceRelation.nonDiscriminating => 'NON_DISCRIMINATING',
      ThesisEvidenceRelation.notRelevant => 'NOT_RELEVANT',
      ThesisEvidenceRelation.evidenceUnavailable => 'EVIDENCE_UNAVAILABLE',
    };
  }
}

class ThesisEvidenceAssessment {
  const ThesisEvidenceAssessment({
    required this.relation,
    required this.family,
    required this.label,
    this.reading,
  });

  final ThesisEvidenceRelation relation;
  final CopilotArgumentFamily family;
  final String label;
  final FootballReading? reading;
}

class ThesisAssessment {
  const ThesisAssessment({
    required this.id,
    required this.title,
    required this.subjectSide,
    required this.status,
    required this.clarityScore,
    required this.evidence,
    this.failedGate,
  });

  final String id;
  final String title;
  final ReadingSubjectSide subjectSide;
  final ThesisAssessmentStatus status;
  final int clarityScore;
  final List<ThesisEvidenceAssessment> evidence;
  final String? failedGate;

  bool get isSupported => status == ThesisAssessmentStatus.supported;

  List<ThesisEvidenceAssessment> get coreSupport => evidence
      .where((item) => item.relation == ThesisEvidenceRelation.coreSupport)
      .toList(growable: false);

  List<ThesisEvidenceAssessment> get additionalSupport => evidence
      .where(
        (item) => item.relation == ThesisEvidenceRelation.additionalSupport,
      )
      .toList(growable: false);

  List<ThesisEvidenceAssessment> get contradictions => evidence
      .where((item) => item.relation == ThesisEvidenceRelation.contradiction)
      .toList(growable: false);

  List<ThesisEvidenceAssessment> get resistances => evidence
      .where((item) => item.relation == ThesisEvidenceRelation.resistance)
      .toList(growable: false);

  List<ThesisEvidenceAssessment> get nonDiscriminating => evidence
      .where(
        (item) => item.relation == ThesisEvidenceRelation.nonDiscriminating,
      )
      .toList(growable: false);
}

/// Business contract for a detected opportunity.
///
/// Pipeline boundaries:
/// Match -> analysis -> Opportunity -> recommended market -> Pick -> Ticket.
///
/// An [Opportunity] is still match-centered: it means the engine detected at
/// least one relevant sporting thesis for a match selected by the user's
/// opportunity profile. It is not a pick and it is not a ticket.
class Opportunity {
  const Opportunity({
    required this.sourceMatch,
    required this.engineScore,
    required this.detectedSignals,
    required this.retainedTheses,
    required this.compatibleMarkets,
    this.recommendedMarket,
    this.supportingReadings = const [],
    this.contradictoryReadings = const [],
    this.thesisAssessments = const [],
    this.asOf,
  });

  final MatchBoardItem sourceMatch;
  final int engineScore;
  final List<MatchSignal> detectedSignals;
  final List<MatchThesis> retainedTheses;
  final List<OpportunityMarketCompatibility> compatibleMarkets;
  final RecommendedMarket? recommendedMarket;
  final List<FootballReading> supportingReadings;
  final List<FootballReading> contradictoryReadings;
  final List<ThesisAssessment> thesisAssessments;
  final DateTime? asOf;

  String get matchId => sourceMatch.id;
  NormalizedFixture get fixture => sourceMatch.fixture;
  CompetitionInfo get competition => sourceMatch.competition;
  TeamInfo get homeTeam => sourceMatch.homeTeam;
  TeamInfo get awayTeam => sourceMatch.awayTeam;
  DateTime? get kickoff => sourceMatch.fixture.kickoff;

  MatchThesis get primaryThesis => retainedTheses.first;

  List<String> get opportunityProfileIds {
    final ids = <String>{};

    for (final thesis in retainedTheses) {
      ids.addAll(OpportunityProfileCatalog.profileIdsForThesis(thesis.id));
    }

    return List.unmodifiable(ids);
  }

  List<CopilotArgument> get copilotArguments {
    final argumentsById = <String, CopilotArgument>{};

    for (final thesis in retainedTheses) {
      for (final argument in thesis.arguments) {
        argumentsById[argument.id] = argument;
      }
    }

    return List.unmodifiable(argumentsById.values);
  }

  List<CopilotArgument> get positiveArguments {
    if (supportingReadings.isNotEmpty) {
      return List.unmodifiable(
        supportingReadings.map(
          (reading) =>
              reading.toCopilotArgument(subjectName: _subjectNameFor(reading)),
        ),
      );
    }

    return List.unmodifiable(
      copilotArguments.where(
        (argument) => argument.family != CopilotArgumentFamily.contradiction,
      ),
    );
  }

  List<CopilotArgument> get contradictions {
    if (contradictoryReadings.isNotEmpty) {
      return List.unmodifiable(
        contradictoryReadings.map(
          (reading) =>
              reading.toCopilotArgument(subjectName: _subjectNameFor(reading)),
        ),
      );
    }

    return List.unmodifiable(
      copilotArguments.where(
        (argument) => argument.family == CopilotArgumentFamily.contradiction,
      ),
    );
  }

  int get argumentCount {
    if (positiveArguments.isNotEmpty || contradictions.isNotEmpty) {
      return positiveArguments.length;
    }

    return statisticalEvidence
        .where((evidence) => evidence.tone != ThesisEvidenceTone.warning)
        .length;
  }

  int get contradictionCount {
    if (positiveArguments.isNotEmpty || contradictions.isNotEmpty) {
      return contradictions.length;
    }

    return statisticalEvidence
        .where((evidence) => evidence.tone == ThesisEvidenceTone.warning)
        .length;
  }

  List<ThesisEvidence> get statisticalEvidence {
    final evidence = <ThesisEvidence>[];

    for (final thesis in retainedTheses) {
      evidence.addAll(thesis.supportingEvidence);
    }

    return List.unmodifiable(evidence);
  }

  bool get hasRecommendedMarket => recommendedMarket != null;

  String _subjectNameFor(FootballReading reading) {
    if (reading.subjectTeamId == sourceMatch.homeTeam.id ||
        reading.subjectTeamId ==
            sourceMatch.homeTeam.apiFootballTeamId?.toString() ||
        reading.subjectTeamId ==
            'api-team-${sourceMatch.homeTeam.apiFootballTeamId}') {
      return sourceMatch.homeTeam.name;
    }
    if (reading.subjectTeamId == sourceMatch.awayTeam.id ||
        reading.subjectTeamId ==
            sourceMatch.awayTeam.apiFootballTeamId?.toString() ||
        reading.subjectTeamId ==
            'api-team-${sourceMatch.awayTeam.apiFootballTeamId}') {
      return sourceMatch.awayTeam.name;
    }
    if (reading.subjectTeamId == sourceMatch.id) {
      return 'La rencontre';
    }
    return reading.subjectTeamId;
  }

  MatchBoardItem toMatchBoardItem({
    MatchProfileStatus profileStatus = MatchProfileStatus.inProfile,
  }) {
    return sourceMatch.copyWith(
      primaryMarket: recommendedMarket?.selection,
      profileStatus: profileStatus,
      compatibility: recommendedMarket == null ? 0 : engineScore,
      signals: detectedSignals,
      thesis: primaryThesis,
    );
  }
}

class OpportunityMarketCompatibility {
  const OpportunityMarketCompatibility({
    required this.thesisId,
    required this.market,
    required this.selection,
    required this.isRecommended,
  });

  final String thesisId;
  final MatchMarket market;
  final MarketOdds selection;
  final bool isRecommended;
}
