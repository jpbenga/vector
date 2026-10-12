import '../theme/competition_card_theme.dart';

enum CompactMatchPhase {
  upcoming,
  live,
  finished,
  postponed,
  cancelled,
  unknown,
}

enum MatchFormScope { championship, competition, allCompetitions }

enum CompactQuoteState { published, unavailable, stale }

class RecentFormObservation {
  const RecentFormObservation({
    required this.result,
    this.playedAt,
    this.fixtureId,
  });
  final String result;
  final DateTime? playedAt;
  final String? fixtureId;
  String get code => switch (result.toUpperCase()) {
    'W' || 'V' => 'W',
    'D' || 'N' => 'D',
    'L' => 'L',
    _ => '?',
  };
}

class RecentFormSnapshot {
  const RecentFormSnapshot({
    required this.teamId,
    required this.scope,
    required this.results,
    this.updatedAt,
  });
  final String teamId;
  final MatchFormScope scope;

  /// Chronological source order, oldest first. No fabricated padding.
  final List<RecentFormObservation> results;
  final DateTime? updatedAt;
  List<RecentFormObservation> get latest => results
      .skip((results.length - 5).clamp(0, results.length))
      .toList(growable: false);
}

class CompactMatchTeam {
  const CompactMatchTeam({
    required this.id,
    required this.name,
    required this.form,
    this.logoUrl,
    this.domesticCompetition,
    this.venueLabel,
  });
  final String id, name;
  final String? logoUrl, domesticCompetition, venueLabel;
  final RecentFormSnapshot form;
}

class CompactMatchReading {
  const CompactMatchReading({required this.id, required this.label});
  final String id, label;
}

class CompactMatchQuote {
  const CompactMatchQuote({required this.outcome, required this.value});
  final String outcome;
  final double value;
}

class CompactMatchData {
  const CompactMatchData({
    required this.id,
    required this.competitionName,
    required this.identity,
    required this.home,
    required this.away,
    required this.phase,
    required this.quoteState,
    this.competitionLogo,
    this.round,
    this.kickoff,
    this.homeScore,
    this.awayScore,
    this.liveLabel,
    this.readings = const [],
    this.signals = const [],
    this.readingCount,
    this.quotes = const [],
    this.quotesUpdatedAt,
    this.bookmaker,
    this.formBeforeKickoff = true,
    this.reverseTeams = false,
    this.quoteScopeLabel,
    this.statusLabel,
  });
  final String id, competitionName;
  final CompetitionCardIdentity identity;
  final String? competitionLogo, round, liveLabel, bookmaker;
  final CompactMatchTeam home, away;
  final CompactMatchPhase phase;
  final DateTime? kickoff, quotesUpdatedAt;
  final int? homeScore, awayScore, readingCount;
  final List<CompactMatchReading> readings, signals;
  final List<CompactMatchQuote> quotes;
  final CompactQuoteState quoteState;
  final bool formBeforeKickoff, reverseTeams;
  final String? quoteScopeLabel, statusLabel;
  bool get hasCompleteQuotes => const ['1', 'N', '2'].every(
    (outcome) =>
        quotes
            .where(
              (q) => q.outcome == outcome && q.value.isFinite && q.value > 1,
            )
            .length ==
        1,
  );
}
