import '../../../core/domain/compact_match_data.dart';
import '../../../core/theme/competition_card_theme.dart';
import '../domain/match_board_item.dart';
import 'widgets/match_feed_card.dart';

/// Presentation only: preserves the published match and profile calculations.
CompactMatchData compactFootballMatch({
  required MatchBoardItem match,
  required bool showReadings,
  MatchBoardItem? analyzedMatch,
  CompactQuoteState? quoteState,
  String? liveLabel,
  MatchFormScope? competitionFormScope,
}) {
  final analysis = match.analysis;
  final continental = match.competition.isContinentalTournament;
  final domestic =
      continental &&
      analysis.homeDomesticContext != null &&
      analysis.awayDomesticContext != null;
  final scope = domestic
      ? MatchFormScope.championship
      : competitionFormScope ?? MatchFormScope.competition;
  final homeHistory = domestic
      ? analysis.homeDomesticContext!.recentMatches
      : analysis.homeRecentLeagueMatches;
  final awayHistory = domestic
      ? analysis.awayDomesticContext!.recentMatches
      : analysis.awayRecentLeagueMatches;
  final kickoff = match.fixture.kickoff;
  final asOf = analysis.asOf;
  RecentFormSnapshot form(
    TeamInfo team,
    List<TeamRecentMatchSnapshot> history,
  ) {
    final items = history
        .where(
          (game) =>
              (game.fixtureId == null ||
                  game.fixtureId != match.fixture.apiFootballFixtureId) &&
              (game.playedAt == null ||
                  (kickoff == null || game.playedAt!.isBefore(kickoff)) &&
                      (asOf == null || !game.playedAt!.isAfter(asOf))),
        )
        .toList();
    if (items.every((game) => game.playedAt != null)) {
      items.sort((a, b) => a.playedAt!.compareTo(b.playedAt!));
    }
    return RecentFormSnapshot(
      teamId: team.id,
      scope: scope,
      updatedAt: asOf,
      results: [
        for (final game in items)
          RecentFormObservation(
            result: game.result,
            playedAt: game.playedAt,
            fixtureId: game.fixtureId?.toString(),
          ),
      ],
    );
  }

  final evidence = analyzedMatch ?? match;
  // A raw published snapshot can carry readings without personalized signals.
  // An explicitly analyzed profile, even an empty one, remains authoritative.
  final published =
      showReadings &&
          analyzedMatch == null &&
          evidence.signals.isEmpty &&
          evidence.thesis == null
      ? analysis.computedReadings
            .where(
              (r) =>
                  r.id != 'head_to_head_dominance' &&
                  r.id != 'standout_decisive_player',
            )
            .toList()
      : const <MatchComputedReading>[];
  final readings = !showReadings
      ? const <MatchCardReading>[]
      : published.isNotEmpty
      ? {
          for (final r in published)
            r.id: MatchCardReading(
              id: r.id,
              label:
                  r.label ??
                  matchReadingLabelForId(r.id, fallback: r.evidenceLabel),
            ),
        }.values.toList(growable: false)
      : publishedMatchCardReadings(evidence);
  final resultOdds = matchResultOddsFor(match);
  final market = match.availableMarkets
      .where((m) => m.id == 'matchResult')
      .firstOrNull;
  return CompactMatchData(
    id: match.id,
    competitionName: match.competition.name,
    competitionLogo: match.competition.logoUrl,
    round: match.fixture.round,
    identity: switch (match.competition.apiFootballLeagueId) {
      2 => CompetitionCardIdentity.champions,
      3 => CompetitionCardIdentity.europa,
      848 => CompetitionCardIdentity.conference,
      _ => CompetitionCardIdentity.generic,
    },
    home: CompactMatchTeam(
      id: match.homeTeam.id,
      name: match.homeTeam.name,
      logoUrl: match.homeTeam.logoUrl,
      domesticCompetition: continental
          ? analysis.homeDomesticContext?.competition.name
          : null,
      form: form(match.homeTeam, homeHistory),
    ),
    away: CompactMatchTeam(
      id: match.awayTeam.id,
      name: match.awayTeam.name,
      logoUrl: match.awayTeam.logoUrl,
      domesticCompetition: continental
          ? analysis.awayDomesticContext?.competition.name
          : null,
      form: form(match.awayTeam, awayHistory),
    ),
    phase: switch (match.fixture.status) {
      FixtureStatus.scheduled => CompactMatchPhase.upcoming,
      FixtureStatus.live => CompactMatchPhase.live,
      FixtureStatus.finished => CompactMatchPhase.finished,
      FixtureStatus.postponed => CompactMatchPhase.postponed,
      FixtureStatus.cancelled => CompactMatchPhase.cancelled,
    },
    kickoff: kickoff,
    homeScore: match.fixture.score?.home,
    awayScore: match.fixture.score?.away,
    liveLabel: liveLabel,
    signals: showReadings
        ? [
            for (final (index, scenario) in publishedMatchCardScenarios(
              evidence,
            ).indexed)
              CompactMatchReading(id: 'scenario:$index', label: scenario.label),
          ]
        : const [],
    readings: [
      for (final reading in readings)
        CompactMatchReading(id: reading.id, label: reading.label),
    ],
    readingCount: showReadings
        ? (published.isNotEmpty
              ? published.length
              : publishedMatchCardReadingCount(evidence))
        : null,
    quotes: [
      for (final quote in resultOdds)
        CompactMatchQuote(outcome: quote.label, value: quote.value.odds),
    ],
    quotesUpdatedAt: market?.updatedAt,
    bookmaker: market?.bookmakerName,
    quoteState:
        quoteState ??
        (resultOdds.length == 3
            ? CompactQuoteState.published
            : CompactQuoteState.unavailable),
  );
}
