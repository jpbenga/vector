import '../../../core/domain/lector_head_to_head_policy.dart';
import '../../../core/sports/data/sport_live_repository.dart';
import '../../../core/widgets/lector_match_form_view.dart';
import '../../../core/widgets/lector_match_insights.dart';
import '../domain/hockey_feed_readings.dart';
import '../../../core/theme/app_components.dart';
import '../../../core/widgets/lector_match_stats.dart';
import '../../../core/sports/domain/sport_module.dart';
import '../../../core/sports/presentation/sport_reading_insights.dart';
import '../domain/hockey_module.dart';
import '../../../core/sports/domain/sport_match_history.dart';
import '../../../core/widgets/lector_head_to_head_data.dart';
import '../../../core/widgets/lector_head_to_head_timeline_panel.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../app/deck/lector_deck.dart';
import '../../../core/sports/domain/sport_fixture.dart';
import '../../../core/sports/domain/sport_competition_context.dart';
import '../../../core/widgets/lector_glass_card.dart';
import '../../../core/widgets/lector_match_detail_view.dart';
import '../../../core/widgets/lector_match_hero_view.dart';
import '../../../core/widgets/lector_match_section_card.dart';
import 'hockey_context_panels.dart';
import '../../../core/widgets/lector_standing_table.dart';

/// Hockey adapter for the shared Lector detail page and section navigation.
/// Missing collection scopes remain missing; they are never inferred from
/// final scores or presented as a complete historical table.
class HockeyMatchDetailPage extends StatefulWidget {
  const HockeyMatchDetailPage({
    required this.fixture,
    this.competition,
    this.liveController,
    this.readings = const [],
    super.key,
  });
  final SportFixture fixture;
  final SportLiveController? liveController;
  final SportCompetitionContext? competition;
  final List<SportReadingAssessment> readings;
  @override
  State<HockeyMatchDetailPage> createState() => _HockeyMatchDetailPageState();
}

class _HockeyMatchDetailPageState extends State<HockeyMatchDetailPage> {
  @override
  void initState() {
    super.initState();
    widget.liveController?.addListener(_liveChanged);
  }

  void _liveChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.liveController?.removeListener(_liveChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.liveController?.display(widget.fixture) ?? widget.fixture;
    final score =
        f.scoreFor(SportScoreScope.finalResult) ??
        f.scoreFor(const SportScoreScope('current'));
    final starts = f.startsAt?.toLocal();
    final date = starts == null
        ? 'Horaire à confirmer'
        : '${DateUtils.isSameDay(starts, DateTime.now()) ? 'Aujourd’hui' : DateFormat('dd/MM/yyyy').format(starts)} · ${DateFormat('HH:mm').format(starts)}';
    return LectorMatchDetailView(
      openStats: f.temporal.isLive || f.status == SportFixtureStatus.finished,
      stats:
          f.status == SportFixtureStatus.live ||
              f.status == SportFixtureStatus.finished
          ? LectorMatchStats(
              isLive: f.temporal.isLive,
              isFinal: f.status == SportFixtureStatus.finished,
              summary: score == null
                  ? null
                  : score.away == score.home
                  ? 'Les deux équipes sont à égalité (${score.away}–${score.home}).'
                  : '${score.away > score.home ? f.away.name : f.home.name} ${f.status == SportFixtureStatus.finished ? 'remporte le match' : 'mène'} ${score.away > score.home ? '${score.away}–${score.home}' : '${score.home}–${score.away}'}${['AP', 'APEN'].contains(f.providerStatus)
                        ? ' après tirs au but'
                        : f.providerStatus == 'AOT'
                        ? ' après prolongation'
                        : ''}.',
              finalStatistics: f.status == SportFixtureStatus.finished,
              sceneAsset: 'assets/backgrounds/hockey-rink-stats.png',
              eventsCapturedAt: f.matchEventsCapturedAt,
              clockLabel: f.temporal.compactLabel,
              periods: const [
                LectorMatchPeriod('P1', 0, 20),
                LectorMatchPeriod('P2', 20, 40),
                LectorMatchPeriod('P3', 40, 60),
              ],
              events: [
                for (final e in f.matchEvents.where(
                  (e) => ['goal', 'penalty'].contains(e.type.toLowerCase()),
                ))
                  LectorMatchEvent(
                    clock:
                        '${e.period} · ${e.minute == null ? '—' : '${e.minute}′'}',
                    order: e.elapsed,
                    position: e.elapsed?.toDouble(),
                    kind: e.type.toLowerCase() == 'goal'
                        ? LectorMatchEventKind.goal
                        : LectorMatchEventKind.warning,
                    firstTeam: e.teamId == f.away.id.value,
                    label:
                        '${e.type.toLowerCase() == 'goal' ? 'But' : 'Pénalité'} · ${e.teamId == f.away.id.value ? f.away.name : f.home.name}',
                    icon: e.type.toLowerCase() == 'goal'
                        ? Icons.sports_hockey_rounded
                        : Icons.timer_outlined,
                    detail: [
                      ...e.players,
                      if (e.detail.isNotEmpty) e.detail,
                      if (e.assists.isNotEmpty)
                        'Passes : ${e.assists.join(', ')}',
                    ].join(' · '),
                  ),
              ],
              capturedAt: f.capturedAt,
              firstTeam: f.away.name,
              secondTeam: f.home.name,
              scoreLabel: score == null
                  ? null
                  : '${score.away} – ${score.home}',
              scopes: [
                for (final key in ['first', 'second', 'third', 'overtime'])
                  if (f.scoreFor(SportScoreScope(key)) case final period?)
                    LectorMatchStatScope(
                      label: switch (key) {
                        'first' => 'P1',
                        'second' => 'P2',
                        'third' => 'P3',
                        _ => 'Prol.',
                      },
                      rows: [
                        LectorMatchStatistic(
                          label: 'Buts de la période',
                          first: '${period.away}',
                          second: '${period.home}',
                        ),
                      ],
                    ),
              ],
              rows: [
                for (final scope in f.scores.keys.where(
                  (s) => const {
                    'regulation',
                    'final',
                    'first',
                    'second',
                    'third',
                    'overtime',
                    'penalties',
                  }.contains(s.key),
                ))
                  LectorMatchStatistic(
                    label: switch (scope.key) {
                      'regulation' => 'À 60 minutes',
                      'final' => 'Score final',
                      'first' => '1re période',
                      'second' => '2e période',
                      'third' => '3e période',
                      'penalties' => 'Tirs au but',
                      _ => 'Prolongation',
                    },
                    first: '${f.scores[scope]!.away}',
                    second: '${f.scores[scope]!.home}',
                  ),
              ],
            )
          : null,
      hero: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LectorMatchHeroView(
            backgroundAsset:
                'assets/backgrounds/match-card-hockey-arena-premium.png',
            match: LectorMatchHeroData(
              competitionName: f.competitionName,
              temporal: f.temporal,
              competitionLogoUrl: widget.competition?.logoUrl,
              dateLabel: date,
              firstTeam: LectorMatchTeamData(
                name: f.away.name,
                logoUrl: f.away.logoUrl,
                role: 'Extérieur',
              ),
              secondTeam: LectorMatchTeamData(
                name: f.home.name,
                logoUrl: f.home.logoUrl,
                role: 'Domicile',
              ),
              isLive: f.status == SportFixtureStatus.live,
              isFinished: f.status == SportFixtureStatus.finished,
              statusLabel: switch (f.status) {
                SportFixtureStatus.live => 'EN COURS',
                SportFixtureStatus.finished => 'TERMINÉ',
                SportFixtureStatus.postponed => 'REPORTÉ',
                SportFixtureStatus.cancelled => 'ANNULÉ',
                SportFixtureStatus.unknown => 'À CONFIRMER',
                _ => 'Avant-match',
              },
              scoreLabel: score == null
                  ? null
                  : '${score.away} - ${score.home}',
            ),
          ),
        ],
      ),
      synthesis: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LectorGlassCard(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
            child: LectorMatchSynthesisHeader(
              subtitle:
                  '${widget.readings.where((r) => r.status == SportReadingStatus.detected).length} lecture(s) détectée(s)',
            ),
          ),
          const SizedBox(height: 12),
          SportReadingInsights(
            readings: widget.readings,
            definition: HockeyModule.definition,
            detailed: true,
            subjectLogoUrl: (r) =>
                r.subject == f.home.id ? f.home.logoUrl : f.away.logoUrl,
            subjectName: (r) =>
                r.subject == f.home.id ? f.home.name : f.away.name,
          ),
        ],
      ),
      overlay: LectorDeck(
        maxWidth: MediaQuery.sizeOf(context).width - 28,
        deckContext: const LectorDeckContext(
          scope: LectorDeckScope.matchDetail,
        ),
        capabilities: const LectorDeckCapabilities(),
      ),
      tabBuilder: (context, index) => switch (index) {
        0 => _context(),
        1 => _standings(),
        2 => _form(),
        _ => _headToHead(),
      },
    );
  }

  Widget _context() {
    final f = widget.fixture;
    final detected = widget.readings
        .where((r) => r.status == SportReadingStatus.detected)
        .toList();
    return LectorMatchContextView(
      count: detected.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (detected.isEmpty)
            Text(
              widget.readings.isEmpty
                  ? 'Configurez vos lectures hockey pour personnaliser cette analyse.'
                  : 'Aucune clé du match détectée avec les données d’avant-match disponibles.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.textColors.secondary,
              ),
            ),
          for (final team in [f.away, f.home])
            if (detected.any((r) => r.subject == team.id))
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: LectorEvidenceTeamCard(
                  title: team.name,
                  logoUrl: team.logoUrl,
                  children: [
                    for (final r in detected.where(
                      (r) => r.subject == team.id,
                    )) ...[
                      LectorEvidenceRow(
                        title: HockeyModule.definition.readings
                            .firstWhere((d) => d.id == r.id)
                            .label,
                        icon: r.id == 'standing_advantage'
                            ? Icons.bar_chart_rounded
                            : Icons.trending_up_rounded,
                        color: context.semantic.success,
                        evidence: Text(
                          r.explanation,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: context.textColors.secondary,
                                height: 1.25,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _standings() => widget.competition == null
      ? LectorStandingPanel<int>(
          description: 'Position et points dans le championnat.',
          views: const [],
          selectedView: 0,
          onSelected: (_) {},
          child: const Text('Classement non fourni dans cette publication.'),
        )
      : HockeyStandingsPanel(
          competition: widget.competition!,
          homeTeamId: widget.fixture.home.id,
          awayTeamId: widget.fixture.away.id,
        );
  Widget _form() {
    final f = widget.fixture;
    const adapter = HockeyFeedReadings();
    final rules = adapter.pointsRulesFor(f);
    LectorFormSide side(SportParticipant team, List<SportFormResult> form) {
      final games = [...form]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
      final last = games.length > 5 ? games.sublist(games.length - 5) : games;
      final valid =
          rules != null && last.every((r) => adapter.resultFor(r) != null);
      final points = valid
          ? last.fold<int>(0, (n, r) => n + rules.points(adapter.resultFor(r)!))
          : 0;
      return LectorFormSide(
        team: LectorFormTeam(name: team.name, logoUrl: team.logoUrl),
        results: [
          for (final r in last)
            switch (r.outcome) {
              SportFormOutcome.win => 'W',
              SportFormOutcome.loss => 'L',
              SportFormOutcome.draw => 'D',
            },
        ],
        summary: LectorFormSummary(
          points: points,
          maximumPoints: 5 * (rules?.maximumPointsPerGame ?? 0),
          hasResults: valid && last.isNotEmpty,
        ),
        matches: [
          for (final r in last)
            LectorRecentFormMatch(
              playedAt: r.startsAt,
              home: r.home,
              opponentName: r.opponent,
              opponentLogoUrl: widget.competition?.tables
                  .expand((t) => t.rows)
                  .where((row) => row.team.name == r.opponent)
                  .firstOrNull
                  ?.team
                  .logoUrl,
              result: r.outcome == SportFormOutcome.win
                  ? 'W'
                  : r.outcome == SportFormOutcome.loss
                  ? 'L'
                  : 'D',
              scoreLabel: '${r.scored}-${r.conceded}',
            ),
        ],
      );
    }

    final first = side(f.away, f.awayForm), second = side(f.home, f.homeForm);
    final complete =
        first.results.length == 5 &&
        second.results.length == 5 &&
        first.summary.hasResults &&
        second.summary.hasResults;
    final gap = (first.summary.points - second.summary.points).abs();
    final leader = first.summary.points > second.summary.points
        ? first.team.name
        : second.team.name;
    return LectorMatchFormView(
      data: LectorFormComparisonData(
        first: first,
        second: second,
        takeaway: !complete
            ? 'La forme récente sera plus parlante dès que les deux séries seront complètes.'
            : gap == 0
            ? '${first.team.name} et ${second.team.name} arrivent avec une dynamique récente comparable.'
            : '$leader affiche la meilleure dynamique récente avec $gap point${gap > 1 ? 's' : ''} d’avance sur les 5 derniers matchs.',
        coverageNote:
            'Résultats avant cette rencontre. Les victoires et défaites après prolongation ou tirs au but sont comptabilisées selon le barème de ${f.competitionName}.',
      ),
    );
  }

  Widget _headToHead() {
    final fixture = widget.fixture, history = fixture.headToHead;
    final reference = fixture.startsAt ?? DateTime.now();
    final lower = LectorHeadToHeadPolicy.lowerBound(reference);
    return LectorHeadToHeadTimelinePanel(
      data: LectorHeadToHeadData(
        competitionId: fixture.competition.value,
        allowUnknownCompetitionFallback: false,
        firstTeamId: fixture.away.id.value,
        secondTeamId: fixture.home.id.value,
        firstTeamName: fixture.away.name,
        secondTeamName: fixture.home.name,
        firstTeamLogoUrl: fixture.away.logoUrl,
        secondTeamLogoUrl: fixture.home.logoUrl,
        emptyDescription: history == null
            ? 'L’historique des confrontations n’est pas encore inclus dans la collecte hockey. Cela ne signifie pas que ces équipes ne se sont jamais rencontrées.'
            : 'Aucune confrontation exploitable dans cette vue sur les trois dernières années. Les rencontres dont la phase n’est pas confirmée restent consultables dans « Toutes compétitions ».',
        coverageNote: history == null
            ? null
            : 'Jusqu’à 6 confrontations par vue, avant cette rencontre. Scores finaux, prolongations incluses. Amicaux et préparation exclus ; championnat et coupes séparés selon les informations du fournisseur.',
        meetings: [
          for (final meeting
              in history?.meetings ?? const <SportHistoricalMatch>[])
            if (meeting.fixture.startsAt != null &&
                !meeting.fixture.startsAt!.isBefore(lower) &&
                meeting.fixture.startsAt!.isBefore(reference))
              _presentMeeting(meeting),
        ],
      ),
    );
  }
}

LectorHeadToHeadMeeting _presentMeeting(SportHistoricalMatch match) {
  final m = match.fixture, score = m.scoreFor(SportScoreScope.finalResult)!;
  return LectorHeadToHeadMeeting(
    competitionKind: LectorHeadToHeadPolicy.classifyHockey(
      name: m.competitionName,
      competitionId: m.competition.value,
      playedAt: m.startsAt,
      phase: match.competitionPhase,
      declaredKind: match.competitionKind,
    ),
    fixtureId: m.id.value,
    competitionId: m.competition.value,
    competitionName: m.competitionName,
    playedAt: m.startsAt!,
    homeTeamId: m.home.id.value,
    awayTeamId: m.away.id.value,
    homeTeamName: m.home.name,
    awayTeamName: m.away.name,
    homeTeamLogoUrl: m.home.logoUrl,
    awayTeamLogoUrl: m.away.logoUrl,
    homeGoals: score.home,
    awayGoals: score.away,
    regulationMinutes: 60,
    tickMinutes: 20,
    showVenue: true,
    orderByVenue: true,
    resultLabel: m.providerStatus == 'AOT'
        ? 'Après prolongation'
        : ['AP', 'APEN'].contains(m.providerStatus)
        ? 'Après tirs au but'
        : 'Temps réglementaire',
    eventsUnavailableLabel: match.eventDataIssue != null
        ? 'Les événements reçus présentent une incohérence et ne peuvent pas être affichés.'
        : match.eventsCollected
        ? 'Aucun événement renvoyé pour cette confrontation.'
        : 'Le fournisseur ne propose pas les événements de cette confrontation.',
    events: [
      for (final e in match.events.where(
        (e) => ['goal', 'penalty'].contains(e.type.toLowerCase()),
      ))
        LectorHeadToHeadEvent(
          minute: e.elapsed,
          teamId: e.teamId,
          label: e.type.toLowerCase() == 'penalty'
              ? 'Pénalité${e.detail.isEmpty ? '' : ' · ${e.detail}'}'
              : 'But${e.detail.isEmpty ? '' : ' · ${e.detail}'}',
          clockLabel:
              '${e.period} · ${e.minute == null ? 'minute non renseignée' : '${e.minute} min'}',
          playerName: e.players.isEmpty ? null : e.players.join(', '),
          icon: e.type.toLowerCase() == 'penalty'
              ? Icons.timer_outlined
              : Icons.sports_hockey_rounded,
          danger: e.type.toLowerCase() == 'penalty',
        ),
    ],
  );
}
