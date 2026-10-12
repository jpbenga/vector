import '../theme/app_colors.dart';
import 'lector_reading_pill.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../domain/compact_match_data.dart';
import '../theme/app_components.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/competition_card_theme.dart';
import 'recent_form_strip.dart';
import 'sports_asset_badge.dart';

/// Shared reference composition: competition, teams/time, signals/odds.
/// The sport adapter supplies facts; this widget only presents them.
class LectorCompactMatchCard extends StatelessWidget {
  const LectorCompactMatchCard({
    required this.data,
    required this.onOpen,
    required this.preparationAction,
    this.onReadings,
    this.referenceDate,
    this.supplement,
    this.statusWidget,
    this.liveFooter,
    super.key,
  });
  final CompactMatchData data;
  final VoidCallback onOpen;
  final VoidCallback? onReadings;
  final Widget preparationAction;
  final DateTime? referenceDate;
  final Widget? supplement, statusWidget, liveFooter;

  String get _status =>
      data.statusLabel ??
      switch (data.phase) {
        CompactMatchPhase.upcoming => 'À venir',
        CompactMatchPhase.live => data.liveLabel ?? 'En direct',
        CompactMatchPhase.finished => 'Terminé',
        CompactMatchPhase.postponed => 'Reporté',
        CompactMatchPhase.cancelled => 'Annulé',
        CompactMatchPhase.unknown => 'À confirmer',
      };
  String get _roundLabel {
    final round = data.round ?? '';
    final regular = RegExp(r'^Regular Season - (\d+)$').firstMatch(round);
    if (regular != null) return 'Journée ${regular.group(1)}';
    final league = RegExp(r'^League Stage - (\d+)$').firstMatch(round);
    if (league != null) return 'Phase de ligue · J${league.group(1)}';
    return round;
  }

  String get _competitionLabel => switch (data.identity) {
    CompetitionCardIdentity.champions => 'Ligue des champions',
    CompetitionCardIdentity.europa => 'Europa League',
    CompetitionCardIdentity.conference => 'Conference League',
    _ => data.competitionName,
  };
  String get _formLabel => data.home.form.scope != data.away.form.scope
      ? 'Forme non comparable'
      : switch (data.home.form.scope) {
          MatchFormScope.championship => 'Forme (championnat)',
          MatchFormScope.competition => switch (data.identity) {
            CompetitionCardIdentity.champions => 'Forme (Ligue des champions)',
            CompetitionCardIdentity.europa => 'Forme (Europa League)',
            CompetitionCardIdentity.conference => 'Forme (Conference League)',
            _ => 'Forme (compétition)',
          },
          MatchFormScope.allCompetitions => 'Forme (toutes compétitions)',
        };
  String get _dayLabel {
    final kickoff = data.kickoff?.toLocal();
    if (kickoff == null) return 'À confirmer';
    final day = referenceDate ?? DateTime.now();
    final delta = DateTime.utc(
      kickoff.year,
      kickoff.month,
      kickoff.day,
    ).difference(DateTime.utc(day.year, day.month, day.day)).inDays;
    return switch (delta) {
      0 => 'Aujourd’hui',
      1 => 'Demain',
      -1 => 'Hier',
      _ => DateFormat('dd/MM').format(kickoff),
    };
  }

  @override
  Widget build(BuildContext context) {
    final palette = CompetitionCardTheme(context, data.identity);
    return Material(
      key: ValueKey('compact-match:${data.id}'),
      color: palette.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(child: _background(context, palette)),
          ),
          InkWell(
            key: ValueKey('compact-open:${data.id}'),
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: LayoutBuilder(
                builder: (context, box) {
                  final enlarged =
                      MediaQuery.textScalerOf(context).scale(12) > 16;
                  final narrow = box.maxWidth < 310;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _competition(context, palette, enlarged),
                      const SizedBox(height: AppSpacing.xxs),
                      if (enlarged)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _teams(context, enlarged),
                            const SizedBox(height: AppSpacing.xs),
                            Align(
                              alignment: Alignment.centerRight,
                              child: SizedBox(
                                width: 145,
                                child: _timeOrScore(context, enlarged),
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _teams(context, enlarged),
                                  if (data.readingCount != null ||
                                      data.readings.isNotEmpty ||
                                      data.signals.isNotEmpty) ...[
                                    const SizedBox(height: AppSpacing.xxs),
                                    _readings(
                                      context,
                                      enlarged,
                                      narrow: narrow,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            SizedBox(
                              width: 114,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _timeOrScore(context, enlarged),
                                      ),
                                      SizedBox(
                                        width: 28,
                                        child: IconButton(
                                          tooltip:
                                              data.phase ==
                                                  CompactMatchPhase.live
                                              ? 'Suivre le match'
                                              : 'Voir l’analyse',
                                          onPressed: onOpen,
                                          constraints: const BoxConstraints(
                                            minWidth: 28,
                                            minHeight: 44,
                                          ),
                                          padding: EdgeInsets.zero,
                                          icon: Icon(
                                            Icons.chevron_right_rounded,
                                            size: 23,
                                            color: context.textColors.secondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (data.phase ==
                                      CompactMatchPhase.upcoming) ...[
                                    const SizedBox(height: AppSpacing.xs),
                                    _quotes(context),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      if (enlarged) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        _readings(context, enlarged, narrow: narrow),
                        if (data.phase == CompactMatchPhase.upcoming) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Align(
                            alignment: Alignment.centerRight,
                            child: SizedBox(
                              width: 166,
                              child: _quotes(context),
                            ),
                          ),
                        ],
                      ],
                      ?liveFooter,
                      if (supplement != null) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        supplement!,
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
          Positioned(top: 0, right: 0, child: preparationAction),
        ],
      ),
    );
  }

  Widget _background(BuildContext context, CompetitionCardTheme palette) {
    final asset = data.identity.backgroundAsset;
    return Stack(
      children: [
        if (asset != null)
          Positioned.fill(
            child: Opacity(
              opacity: palette.light ? .10 : .95,
              child: Image.asset(
                asset,
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
                excludeFromSemantics: true,
              ),
            ),
          )
        else if (data.competitionLogo?.isNotEmpty == true)
          Positioned(
            right: -18,
            top: 28,
            bottom: 12,
            width: 150,
            child: Opacity(
              opacity: palette.light ? .12 : .32,
              child: Image.network(
                data.competitionLogo!,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  palette.background,
                  palette.background.withValues(alpha: .94),
                  palette.background.withValues(
                    alpha: palette.light ? .9 : .08,
                  ),
                ],
                stops: const [0, .47, 1],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _competition(
    BuildContext context,
    CompetitionCardTheme palette,
    bool enlarged,
  ) => Padding(
    // The independent 44 px Shortlist target sits above the composition.
    padding: const EdgeInsets.only(right: 32),
    child: Row(
      children: [
        SportsAssetBadge(
          size: 28,
          imageUrl: data.competitionLogo,
          fallbackLabel: data.competitionName,
          padding: 0,
          backgroundColor: AppColors.transparent,
          contrastPlate: data.identity == CompetitionCardIdentity.generic,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Tooltip(
            message: data.competitionName,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _competitionLabel.toUpperCase(),
                  maxLines: enlarged ? null : 1,
                  overflow: enlarged
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.05,
                    height: 1.15,
                    color: palette.title,
                  ),
                ),
                if (data.round?.isNotEmpty == true)
                  Text(
                    _roundLabel,
                    maxLines: enlarged ? null : 1,
                    overflow: enlarged
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.15,
                      color: context.textColors.secondary,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xxs),
        statusWidget ??
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: palette.background.withValues(alpha: .7),
                borderRadius: BorderRadius.circular(AppRadius.chip),
                border: Border.all(
                  color: data.phase == CompactMatchPhase.live
                      ? context.semantic.live.withValues(alpha: .55)
                      : palette.statusBorder,
                ),
              ),
              child: Text(
                _status,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: data.phase == CompactMatchPhase.live
                      ? context.semantic.live
                      : palette.statusText,
                ),
              ),
            ),
      ],
    ),
  );

  Widget _teams(BuildContext context, bool enlarged) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _team(context, data.reverseTeams ? data.away : data.home, enlarged),
      Padding(
        padding: const EdgeInsets.only(left: 38),
        child: Text(
          'vs',
          style: TextStyle(
            fontSize: 9,
            height: 1,
            color: context.textColors.secondary,
          ),
        ),
      ),
      _team(context, data.reverseTeams ? data.home : data.away, enlarged),
    ],
  );

  Widget _team(BuildContext context, CompactMatchTeam team, bool enlarged) =>
      Row(
        children: [
          SportsAssetBadge(
            size: 30,
            imageUrl: team.logoUrl,
            padding: 0,
            backgroundColor: AppColors.transparent,
            fallbackLabel: team.name,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tooltip(
                  message: team.name,
                  child: Text(
                    team.name,
                    maxLines: enlarged ? null : 1,
                    overflow: enlarged
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                ),
                if (team.venueLabel != null)
                  Text(
                    team.venueLabel!,
                    style: TextStyle(
                      fontSize: 8,
                      color: context.textColors.secondary,
                    ),
                  ),
                if (team.domesticCompetition?.isNotEmpty == true)
                  Tooltip(
                    message: team.domesticCompetition!,
                    child: Text(
                      team.domesticCompetition!,
                      maxLines: enlarged ? null : 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9,
                        color: context.textColors.secondary,
                      ),
                    ),
                  ),
                const SizedBox(height: 3),
                if (data.home.form.scope == data.away.form.scope)
                  RecentFormStrip(
                    snapshot: team.form,
                    teamName: team.name,
                    compact: true,
                  )
                else
                  Text(
                    '—',
                    style: TextStyle(color: context.textColors.secondary),
                  ),
              ],
            ),
          ),
        ],
      );

  Widget _timeOrScore(BuildContext context, bool enlarged) {
    final scored =
        data.phase == CompactMatchPhase.live ||
        data.phase == CompactMatchPhase.finished;
    return Container(
      padding: const EdgeInsets.only(left: AppSpacing.xs),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: context.surfaces.border.withValues(alpha: .8),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (scored)
            Container(
              key: ValueKey(
                data.phase == CompactMatchPhase.live
                    ? 'match-score-live'
                    : 'match-score-final',
              ),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
              decoration: data.phase == CompactMatchPhase.live
                  ? BoxDecoration(
                      color: context.features.liveScoreFill,
                      borderRadius: BorderRadius.circular(AppRadius.tight),
                    )
                  : null,
              child: DefaultTextStyle.merge(
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(data.reverseTeams ? data.awayScore : data.homeScore) ?? '—'}',
                      ),
                      const Text(' – '),
                      Text(
                        '${(data.reverseTeams ? data.homeScore : data.awayScore) ?? '—'}',
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Text(
              data.kickoff == null
                  ? '—'
                  : DateFormat('HH:mm').format(data.kickoff!.toLocal()),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          const SizedBox(height: 3),
          Text(
            _dayLabel,
            maxLines: enlarged ? null : 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, color: context.textColors.secondary),
          ),
          const SizedBox(height: 4),
          Tooltip(
            message: _formLabel,
            child: Text(
              '${data.phase == CompactMatchPhase.finished && data.formBeforeKickoff ? 'Avant match · ' : ''}${data.home.form.scope == MatchFormScope.competition ? 'Forme (compétition)' : _formLabel}',
              maxLines: enlarged ? null : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 8,
                height: 1.15,
                color: context.textColors.secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _readings(BuildContext context, bool enlarged, {bool narrow = false}) {
    if (data.readingCount == null &&
        data.readings.isEmpty &&
        data.signals.isEmpty) {
      return const SizedBox.shrink();
    }
    final chips = <Widget>[
      if (data.readingCount != null)
        _pill(
          context,
          label:
              '${data.readingCount} lecture${data.readingCount == 1 ? '' : 's'}',
          icon: Icons.bar_chart_rounded,
          foreground: context.semantic.info,
          fill: context.semantic.info.withValues(alpha: .10),
          border: AppColors.transparent,
        ),
      for (final reading in [
        ...data.signals,
        ...data.readings,
      ].take(narrow && !enlarged ? 1 : 2))
        _reading(context, reading),
    ];
    return InkWell(
      onTap: onReadings ?? onOpen,
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: Wrap(
        spacing: AppSpacing.xxs,
        runSpacing: AppSpacing.xxs,
        children: chips,
      ),
    );
  }

  Widget _reading(BuildContext context, CompactMatchReading reading) {
    final scenario = reading.id.startsWith('scenario:');
    final style = scenario
        ? AppReadingBadgeStyle(
            foreground: context.features.generatorAccent,
            background: context.features.generatorFill,
            border: context.features.generatorAccent.withValues(alpha: .35),
            iconColor: context.features.generatorAccent,
          )
        : context.opportunities.badgeFor(
            reading.id,
            variant: AppReadingBadgeVariant.soft,
          );
    return Tooltip(
      message: reading.label,
      child: LectorReadingPill(
        compact: true,
        label: switch (reading.id) {
          'declining_form' => 'Baisse',
          'form_advantage' || 'recent_form_advantage' => 'Forme +',
          _ => reading.label,
        },
        icon: scenario
            ? Icons.auto_awesome_rounded
            : context.opportunities.readingIdentityForId(reading.id).icon,
        style: style,
      ),
    );
  }

  Widget _pill(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color foreground,
    required Color fill,
    required Color border,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    decoration: BoxDecoration(
      color: fill,
      borderRadius: BorderRadius.circular(AppRadius.chip),
      border: Border.all(color: border),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: foreground),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _quotes(BuildContext context) {
    final complete =
        data.hasCompleteQuotes &&
        data.quoteState != CompactQuoteState.unavailable;
    final stale = data.quoteState == CompactQuoteState.stale;
    final availability = stale
        ? 'Cotes à actualiser'
        : !complete
        ? 'Cotes indisponibles'
        : 'Cotes 1N2';
    return Tooltip(
      key: ValueKey('story-match-result-odds-${data.id}'),
      message:
          '$availability · ${data.quotesUpdatedAt == null ? 'Horodatage non renseigné' : '${data.bookmaker ?? 'Cotes relevées'} · ${DateFormat('dd/MM HH:mm').format(data.quotesUpdatedAt!.toLocal())}'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (data.quoteScopeLabel != null)
            Text(
              data.quoteScopeLabel!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 8,
                color: context.textColors.secondary,
              ),
            ),
          if (!complete || stale) ...[
            Text(
              availability,
              style: TextStyle(
                fontSize: 9,
                color: stale
                    ? context.semantic.warning
                    : context.textColors.secondary,
              ),
            ),
            const SizedBox(height: 3),
          ],
          DecoratedBox(
            decoration: BoxDecoration(
              color: context.surfaces.backgroundSecondary.withValues(alpha: .6),
              borderRadius: BorderRadius.circular(AppRadius.odds),
              border: Border.all(
                color: context.surfaces.border.withValues(alpha: .8),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  for (final outcome in const ['1', 'N', '2'])
                    Expanded(
                      child: Semantics(
                        label:
                            '${switch (outcome) {
                              '1' => 'Domicile',
                              'N' => 'Nul',
                              _ => 'Extérieur',
                            }} : ${complete ? data.quotes.firstWhere((q) => q.outcome == outcome).value.toStringAsFixed(2) : 'indisponible'}${stale ? ', cote obsolète' : ''}',
                        child: Column(
                          children: [
                            Text(
                              outcome,
                              style: TextStyle(
                                fontSize: 9,
                                height: 1,
                                color: context.textColors.secondary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              complete
                                  ? data.quotes
                                        .firstWhere((q) => q.outcome == outcome)
                                        .value
                                        .toStringAsFixed(2)
                                  : '—',
                              style: TextStyle(
                                fontSize: 11,
                                height: 1,
                                fontWeight: FontWeight.w600,
                                color: stale
                                    ? context.textColors.secondary
                                    : context.textColors.primary,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
