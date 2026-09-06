import 'analysis_maturity.dart';

enum MarketSelectionIntent {
  home,
  draw,
  away,
  homeOrDraw,
  homeOrAway,
  drawOrAway,
  over25,
  under25,
  over05,
  yes,
  no,
}

class MarketIntent {
  const MarketIntent(this.marketId, this.selection, {this.playerName});

  final String marketId;
  final MarketSelectionIntent selection;
  final String? playerName;
}

/// A real bookmaker selection justified by the match analysis.
///
/// It is deliberately profile-independent: user preferences decide whether it
/// is shown or used, never whether the analytical candidate exists.
class BetCandidate {
  const BetCandidate({
    required this.matchId,
    required this.marketId,
    required this.marketLabel,
    required this.selectionId,
    required this.selectionLabel,
    required this.selectionValue,
    required this.odds,
    required this.supportingReadingIds,
    required this.supportingThesisIds,
    required this.contradictionIds,
    required this.maturity,
    this.subjectTeamId,
    this.apiFootballBetId,
    this.bookmakerId,
    this.bookmakerName,
    this.subjectPlayerId,
    this.subjectPlayerName,
  });

  final String matchId;
  final String marketId;
  final String marketLabel;
  final String selectionId;
  final String selectionLabel;
  final String? selectionValue;
  final double odds;
  final String? subjectTeamId;
  final int? subjectPlayerId;
  final String? subjectPlayerName;
  final int? apiFootballBetId;
  final int? bookmakerId;
  final String? bookmakerName;
  final List<String> supportingReadingIds;
  final List<String> supportingThesisIds;
  final List<String> contradictionIds;
  final AnalysisMaturity maturity;

  bool get hasContradiction => contradictionIds.isNotEmpty;

  bool get isAutomaticallyUsable =>
      maturity.isEstablished && !hasContradiction && odds.isFinite && odds > 0;

  String? get abstentionReason {
    if (maturity.isEarly) {
      return 'Analyse encore précoce: aucune exploitation automatique.';
    }
    if (hasContradiction) {
      return 'Des signaux contradictoires empêchent une proposition automatique.';
    }
    if (!odds.isFinite || odds <= 0) {
      return 'Aucune cote exploitable n’est disponible pour cette sélection.';
    }
    return null;
  }
}

/// Selects the only analytically distinct automatic candidate, if one exists.
///
/// Callers pass candidates already compatible with the active profile. This
/// deliberately does not inspect odds, market type, or collection order: none
/// of those describes the quality of the analysis. An analytical tie remains
/// visible as multiple compatible candidates, rather than being promoted to an
/// arbitrary recommendation.
BetCandidate? selectSuggestedBetCandidate(Iterable<BetCandidate> candidates) {
  final automatic = candidates
      .where((candidate) => candidate.isAutomaticallyUsable)
      .toList(growable: false);
  if (automatic.isEmpty) {
    return null;
  }

  final withoutContradiction = automatic
      .where((candidate) => !candidate.hasContradiction)
      .toList(growable: false);
  final eligible = withoutContradiction.isEmpty
      ? automatic
      : withoutContradiction;

  final bestDepth = eligible
      .map(_supportDepthFor)
      .reduce((current, next) => current.index >= next.index ? current : next);
  final best = eligible
      .where((candidate) => _supportDepthFor(candidate) == bestDepth)
      .toList(growable: false);

  return best.length == 1 ? best.single : null;
}

enum _BetCandidateSupportDepth {
  none,
  thesisOnly,
  singleReading,
  multipleReadings,
  thesisAndReadings,
}

_BetCandidateSupportDepth _supportDepthFor(BetCandidate candidate) {
  final hasThesis = candidate.supportingThesisIds.toSet().isNotEmpty;
  final readingCount = candidate.supportingReadingIds.toSet().length;
  if (hasThesis && readingCount > 0) {
    return _BetCandidateSupportDepth.thesisAndReadings;
  }
  if (readingCount > 1) {
    return _BetCandidateSupportDepth.multipleReadings;
  }
  if (readingCount == 1) {
    return _BetCandidateSupportDepth.singleReading;
  }
  return hasThesis
      ? _BetCandidateSupportDepth.thesisOnly
      : _BetCandidateSupportDepth.none;
}

enum AttentionSignalType { reading, thesis, market, convergence }

class AttentionSignal {
  const AttentionSignal({
    required this.id,
    required this.type,
    this.sourceReadingIds = const [],
    this.thesisId,
    this.marketId,
  });

  final String id;
  final AttentionSignalType type;
  final List<String> sourceReadingIds;
  final String? thesisId;
  final String? marketId;
}
