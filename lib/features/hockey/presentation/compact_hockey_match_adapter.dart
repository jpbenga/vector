import '../../../core/domain/compact_match_data.dart';
import '../../../core/theme/competition_card_theme.dart';
import '../../../core/sports/domain/sport_fixture.dart';
import '../../../core/sports/domain/sport_competition_context.dart';
import '../../../core/sports/domain/sport_module.dart';
import '../domain/hockey_module.dart';
import 'hockey_quote_presentation.dart';

/// Published facts and the incumbent quote selector; no hockey rules here.
CompactMatchData compactHockeyMatch({
  required SportFixture fixture,
  SportCompetitionContext? competition,
  List<SportReadingAssessment> readings = const [],
  DateTime? now,
}) {
  final cutoff = now ?? DateTime.now().toUtc();
  RecentFormSnapshot form(
    SportParticipant team,
    List<SportFormResult> supplied,
  ) {
    final row = competition?.tables
        .expand((t) => t.rows)
        .where((r) => r.team.id == team.id)
        .firstOrNull;
    final history = competition?.formPhaseVerified == false
        ? <SportFormResult>[]
        : supplied.isNotEmpty
        ? supplied
        : row?.formHistory ?? <SportFormResult>[];
    final completed =
        history
            .where(
              (g) =>
                  g.matchId != fixture.id &&
                  (fixture.startsAt == null ||
                      g.startsAt.isBefore(fixture.startsAt!)) &&
                  !g.startsAt.isAfter(fixture.capturedAt ?? cutoff),
            )
            .toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return RecentFormSnapshot(
      teamId: team.id.key,
      scope: MatchFormScope.competition,
      updatedAt: fixture.capturedAt,
      results: [
        for (final g in completed)
          RecentFormObservation(
            result: switch (g.outcome) {
              SportFormOutcome.win => 'W',
              SportFormOutcome.draw => 'D',
              SportFormOutcome.loss => 'L',
            },
            playedAt: g.startsAt,
            fixtureId: g.matchId.key,
          ),
      ],
    );
  }

  final market = hockeyOddsMarkets(fixture, cutoff)
      .where((m) => m.label == HockeyModule.definition.markets.first.label)
      .firstOrNull;
  final detected = readings
      .where((r) => r.status == SportReadingStatus.detected)
      .toList();
  String caption(SportReadingAssessment reading) {
    final base =
        HockeyModule.definition.readings
            .where((d) => d.id == reading.id)
            .firstOrNull
            ?.label ??
        reading.id;
    final count =
        reading.evidence['consecutiveResults'] ??
        reading.evidence['consecutiveWins'];
    final series = count == null
        ? ''
        : ' · ${reading.evidence['exact'] == true ? '' : '≥'}$count';
    return '$base$series · ${reading.subject == fixture.home.id ? fixture.home.name : fixture.away.name}';
  }

  final score =
      fixture.scoreFor(SportScoreScope.finalResult) ??
      fixture.scoreFor(const SportScoreScope('current'));
  return CompactMatchData(
    id: fixture.id.key,
    competitionName: fixture.competitionName,
    competitionLogo: competition?.logoUrl,
    identity: CompetitionCardIdentity.generic,
    home: CompactMatchTeam(
      id: fixture.home.id.key,
      name: fixture.home.name,
      logoUrl: fixture.home.logoUrl,
      venueLabel: 'Domicile',
      form: form(fixture.home, fixture.homeForm),
    ),
    away: CompactMatchTeam(
      id: fixture.away.id.key,
      name: fixture.away.name,
      logoUrl: fixture.away.logoUrl,
      venueLabel: 'Extérieur',
      form: form(fixture.away, fixture.awayForm),
    ),
    reverseTeams: true,
    kickoff: fixture.startsAt,
    homeScore: score?.home,
    awayScore: score?.away,
    liveLabel: fixture.temporal.compactLabel,
    statusLabel: switch (fixture.providerStatus) {
      'AOT' => 'Terminé · Prol.',
      'AP' || 'APEN' => 'Terminé · TAB',
      _ => null,
    },
    phase: switch (fixture.status) {
      SportFixtureStatus.scheduled => CompactMatchPhase.upcoming,
      SportFixtureStatus.live => CompactMatchPhase.live,
      SportFixtureStatus.finished => CompactMatchPhase.finished,
      SportFixtureStatus.postponed => CompactMatchPhase.postponed,
      SportFixtureStatus.cancelled => CompactMatchPhase.cancelled,
      _ => CompactMatchPhase.unknown,
    },
    readingCount: detected.isEmpty ? null : detected.length,
    readings: [
      for (final reading in detected)
        CompactMatchReading(id: reading.id, label: caption(reading)),
    ],
    quoteScopeLabel: '60 min',
    bookmaker: market?.bookmaker,
    quotesUpdatedAt: market?.recordedAt,
    quoteState: market == null
        ? CompactQuoteState.unavailable
        : CompactQuoteState.published,
    quotes: [
      for (final (code, label) in [
        ('1', fixture.home.name),
        ('N', 'Nul'),
        ('2', fixture.away.name),
      ])
        if (market?.selections.where((q) => q.label == label).singleOrNull
            case final q?)
          CompactMatchQuote(outcome: code, value: q.odds),
    ],
  );
}
