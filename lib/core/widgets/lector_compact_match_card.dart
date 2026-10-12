import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../domain/compact_match_data.dart';
import '../theme/app_components.dart';
import '../theme/app_radius.dart';
import '../theme/competition_card_theme.dart';
import 'recent_form_strip.dart';
import 'sports_asset_badge.dart';

/// Data-driven shared layout. Sport adapters own meanings and availability.
class LectorCompactMatchCard extends StatelessWidget {
  const LectorCompactMatchCard({
    required this.data,
    required this.onOpen,
    required this.preparationAction,
    this.onReadings,
    super.key,
  });
  final CompactMatchData data;
  final VoidCallback onOpen;
  final VoidCallback? onReadings;
  final Widget preparationAction;
  String get _status => switch (data.phase) {
    CompactMatchPhase.upcoming => 'À venir',
    CompactMatchPhase.live => data.liveLabel ?? 'En direct',
    CompactMatchPhase.finished => 'Terminé',
    CompactMatchPhase.postponed => 'Reporté',
    CompactMatchPhase.cancelled => 'Annulé',
    CompactMatchPhase.unknown => 'Statut à confirmer',
  };
  String get _formLabel => data.home.form.scope != data.away.form.scope
      ? 'Forme non comparable'
      : switch (data.home.form.scope) {
          MatchFormScope.championship => 'Forme (championnat)',
          MatchFormScope.competition => 'Forme (compétition)',
          MatchFormScope.allCompetitions => 'Forme (toutes compétitions)',
        };
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
          if (data.identity.backgroundAsset != null)
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: palette.light ? .08 : .36,
                  child: Image.asset(
                    data.identity.backgroundAsset!,
                    fit: BoxFit.cover,
                    alignment: Alignment.centerRight,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
            ),
          InkWell(
            key: ValueKey('compact-open:${data.id}'),
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 10, 10),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final expanded =
                      constraints.maxWidth < 260 ||
                      MediaQuery.textScalerOf(context).scale(12) > 16;
                  final comparable =
                      data.home.form.scope == data.away.form.scope;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          SportsAssetBadge(
                            size: 22,
                            imageUrl: data.competitionLogo,
                            contrastPlate: true,
                            fallbackLabel: data.competitionName,
                            padding: 0,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data.competitionName,
                                  maxLines: expanded ? null : 1,
                                  overflow: expanded
                                      ? TextOverflow.visible
                                      : TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: palette.accent,
                                  ),
                                ),
                                if (data.round?.isNotEmpty == true)
                                  Text(
                                    data.round!,
                                    maxLines: expanded ? null : 1,
                                    overflow: expanded
                                        ? TextOverflow.visible
                                        : TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: context.textColors.secondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _status,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: data.phase == CompactMatchPhase.live
                                  ? context.semantic.live
                                  : context.textColors.secondary,
                            ),
                          ),
                          preparationAction,
                        ],
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _formLabel,
                              style: TextStyle(
                                fontSize: 9,
                                color: context.textColors.secondary,
                              ),
                            ),
                          ),
                          if (data.phase == CompactMatchPhase.finished &&
                              data.formBeforeKickoff)
                            Text(
                              'Avant match',
                              style: TextStyle(
                                fontSize: 9,
                                color: context.textColors.secondary,
                              ),
                            ),
                          if (data.phase == CompactMatchPhase.upcoming &&
                              data.kickoff != null)
                            Text(
                              DateFormat(
                                'dd/MM · HH:mm',
                              ).format(data.kickoff!.toLocal()),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      _team(
                        context,
                        data.home,
                        data.homeScore,
                        expanded: expanded,
                        comparable: comparable,
                      ),
                      const SizedBox(height: 5),
                      _team(
                        context,
                        data.away,
                        data.awayScore,
                        expanded: expanded,
                        comparable: comparable,
                      ),
                      const SizedBox(height: 8),
                      Divider(
                        height: 1,
                        color: context.surfaces.border.withValues(alpha: .65),
                      ),
                      const SizedBox(height: 7),
                      LayoutBuilder(
                        builder: (context, box) {
                          final quotePanel =
                              data.phase == CompactMatchPhase.upcoming
                              ? _quotes(context)
                              : null;
                          final readingPanel = _readings(context);
                          if (expanded && quotePanel != null) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                readingPanel,
                                const SizedBox(height: 8),
                                quotePanel,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(child: readingPanel),
                              if (quotePanel != null) ...[
                                const SizedBox(width: 9),
                                SizedBox(
                                  width: box.maxWidth < 300 ? 119 : 135,
                                  child: quotePanel,
                                ),
                              ],
                              const SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: context.textColors.secondary,
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _team(
    BuildContext context,
    CompactMatchTeam team,
    int? score, {
    required bool expanded,
    required bool comparable,
  }) {
    final identity = Row(
      children: [
        SportsAssetBadge(
          size: 25,
          imageUrl: team.logoUrl,
          fallbackLabel: team.name,
          padding: 0,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                team.name,
                maxLines: expanded ? null : 1,
                overflow: expanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (team.domesticCompetition?.isNotEmpty == true)
                Text(
                  team.domesticCompetition!,
                  style: TextStyle(
                    fontSize: 9,
                    color: context.textColors.secondary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
    final form = comparable
        ? RecentFormStrip(snapshot: team.form, teamName: team.name)
        : Text('—', style: TextStyle(color: context.textColors.secondary));
    final scored =
        score == null ||
            ![
              CompactMatchPhase.live,
              CompactMatchPhase.finished,
            ].contains(data.phase)
        ? null
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: data.phase == CompactMatchPhase.live
                ? BoxDecoration(
                    color: context.features.liveScoreFill,
                    borderRadius: BorderRadius.circular(AppRadius.control),
                  )
                : null,
            child: Text(
              '$score',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          );
    return expanded
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              identity,
              Padding(
                padding: const EdgeInsets.only(left: 32, top: 5),
                child: Row(children: [form, const Spacer(), ?scored]),
              ),
            ],
          )
        : Row(
            children: [
              Expanded(child: identity),
              const SizedBox(width: 6),
              form,
              if (scored != null) ...[const SizedBox(width: 8), scored],
            ],
          );
  }

  Widget _readings(BuildContext context) => InkWell(
    onTap: onReadings ?? onOpen,
    borderRadius: BorderRadius.circular(AppRadius.control),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (data.readingCount != null)
            Row(
              children: [
                Icon(
                  Icons.bar_chart_rounded,
                  size: 13,
                  color: context.semantic.info,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '${data.readingCount} lecture${data.readingCount == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: context.semantic.info,
                    ),
                  ),
                ),
              ],
            ),
          if (data.readings.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 3,
              children: [
                for (final reading in data.readings.take(2))
                  Tooltip(
                    message: reading.label,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: context.surfaces.backgroundSecondary.withValues(
                          alpha: .65,
                        ),
                        border: Border.all(color: context.surfaces.border),
                        borderRadius: BorderRadius.circular(AppRadius.control),
                      ),
                      child: Text(
                        reading.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9,
                          color: context.textColors.secondary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    ),
  );

  Widget _quotes(BuildContext context) {
    final complete =
        data.hasCompleteQuotes &&
        data.quoteState != CompactQuoteState.unavailable;
    final stale = data.quoteState == CompactQuoteState.stale;
    return Tooltip(
      message: data.quotesUpdatedAt == null
          ? 'Horodatage des cotes non renseigné'
          : '${data.bookmaker ?? 'Cotes relevées'} · ${DateFormat('dd/MM HH:mm').format(data.quotesUpdatedAt!.toLocal())}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            stale
                ? 'Cotes à actualiser'
                : !complete
                ? 'Cotes indisponibles'
                : 'Cotes 1N2',
            style: TextStyle(
              fontSize: 9,
              color: stale
                  ? context.semantic.warning
                  : context.textColors.secondary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final outcome in const ['1', 'N', '2']) ...[
                if (outcome != '1') const SizedBox(width: 4),
                Expanded(
                  child: Semantics(
                    label:
                        '${switch (outcome) {
                          '1' => 'Domicile',
                          'N' => 'Nul',
                          _ => 'Extérieur',
                        }} : ${complete ? data.quotes.firstWhere((q) => q.outcome == outcome).value.toStringAsFixed(2) : 'indisponible'}${stale ? ', cote obsolète' : ''}',
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        color: context.surfaces.backgroundSecondary.withValues(
                          alpha: .7,
                        ),
                        border: Border.all(color: context.surfaces.border),
                        borderRadius: BorderRadius.circular(AppRadius.odds),
                      ),
                      child: Column(
                        children: [
                          Text(
                            outcome,
                            style: TextStyle(
                              fontSize: 9,
                              color: context.textColors.secondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            complete
                                ? data.quotes
                                      .firstWhere((q) => q.outcome == outcome)
                                      .value
                                      .toStringAsFixed(2)
                                : '—',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
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
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
