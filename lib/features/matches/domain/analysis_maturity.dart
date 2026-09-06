import 'match_board_item.dart';

/// Seasonal confidence for a pre-match analysis.
///
/// A team has played five matches before its sixth scheduled match. Delayed
/// fixtures are handled from the standings, never from the round label.
enum AnalysisMaturity { early, established }

extension AnalysisMaturityX on AnalysisMaturity {
  bool get isEarly => this == AnalysisMaturity.early;

  bool get isEstablished => this == AnalysisMaturity.established;

  bool get allowsAutomaticOpportunity => isEstablished;
}

class AnalysisMaturityResolver {
  const AnalysisMaturityResolver._();

  static const establishedAfterPlayedMatches = 5;

  static AnalysisMaturity forMatch(MatchBoardItem match) {
    final homePlayed = match.analysis.homeStanding?.played;
    final awayPlayed = match.analysis.awayStanding?.played;
    return homePlayed != null &&
            awayPlayed != null &&
            homePlayed >= establishedAfterPlayedMatches &&
            awayPlayed >= establishedAfterPlayedMatches
        ? AnalysisMaturity.established
        : AnalysisMaturity.early;
  }
}
