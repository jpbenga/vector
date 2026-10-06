import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../theme/app_components.dart';
import '../theme/app_radius.dart';
import 'sports_asset_badge.dart';
import 'lector_glass_card.dart';
import 'lector_result_badge.dart';

class LectorFormTeam {
  const LectorFormTeam({required this.name, this.logoUrl});
  final String name;
  final String? logoUrl;
}

class LectorFormSummary {
  const LectorFormSummary({
    required this.points,
    required this.maximumPoints,
    required this.hasResults,
  });
  final int points, maximumPoints;
  final bool hasResults;
}

class LectorRecentFormMatch {
  const LectorRecentFormMatch({
    required this.playedAt,
    required this.home,
    required this.opponentName,
    required this.result,
    required this.scoreLabel,
    this.opponentLogoUrl,
  });
  final DateTime? playedAt;
  final bool home;
  final String opponentName, result, scoreLabel;
  final String? opponentLogoUrl;
}

class LectorFormSide {
  const LectorFormSide({
    required this.team,
    required this.results,
    required this.summary,
    required this.matches,
  });
  final LectorFormTeam team;
  final List<String> results;
  final LectorFormSummary summary;
  final List<LectorRecentFormMatch> matches;
}

class LectorFormComparisonData {
  const LectorFormComparisonData({
    required this.first,
    required this.second,
    required this.takeaway,
    this.coverageNote,
  });
  final LectorFormSide first, second;
  final String takeaway;
  final String? coverageNote;
}

/// The actual football form presentation, shared by every sport. Adapters
/// supply participant order, chronology and points; no sport rules live here.
class LectorMatchFormView extends StatelessWidget {
  const LectorMatchFormView({required this.data, super.key});
  final LectorFormComparisonData data;
  @override
  Widget build(BuildContext context) => LectorGlassCard(
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _LectorFormHeading(),
        const SizedBox(height: 3),
        Text(
          'Du plus ancien au plus récent',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: context.textColors.secondary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        _LectorFormDuelSummary(
          data: data,
          firstResults: data.first.results,
          secondResults: data.second.results,
          firstStats: data.first.summary,
          secondStats: data.second.summary,
        ),
        const SizedBox(height: 14),
        _LectorRecentFormSection(
          data: data,
          firstMatches: data.first.matches,
          secondMatches: data.second.matches,
          firstResults: data.first.results,
          secondResults: data.second.results,
        ),
        const SizedBox(height: 12),
        _LectorFormTakeaway(text: data.takeaway),
        if (data.coverageNote != null) ...[
          const SizedBox(height: 8),
          Text(
            data.coverageNote!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.textColors.secondary,
            ),
          ),
        ],
      ],
    ),
  );
}

class _FormChronologyHint extends StatelessWidget {
  const _FormChronologyHint({this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) => Text(
    'Du plus ancien au plus récent',
    style: Theme.of(context).textTheme.labelSmall?.copyWith(
      color: context.textColors.secondary,
      fontSize: compact ? 9 : 10,
      fontWeight: FontWeight.w700,
    ),
  );
}

String _lectorFormResultLabel(String result) => switch (result.toUpperCase()) {
  'W' || 'V' => 'V',
  'D' || 'N' => 'N',
  'L' || 'P' => 'D',
  _ => '-',
};

class _LectorFormHeading extends StatelessWidget {
  const _LectorFormHeading();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = context.brand;
    final textColors = context.textColors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.trending_up_rounded, color: brand.accent, size: 23),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FORME RÉCENTE',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: textColors.primary,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Les 5 derniers résultats disponibles.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: textColors.secondary,
                  fontSize: 11,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LectorFormDuelSummary extends StatelessWidget {
  const _LectorFormDuelSummary({
    required this.data,
    required this.firstResults,
    required this.secondResults,
    required this.firstStats,
    required this.secondStats,
  });

  final LectorFormComparisonData data;
  final List<String> firstResults;
  final List<String> secondResults;
  final LectorFormSummary firstStats;
  final LectorFormSummary secondStats;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 390;
    final homeCard = _LectorFormTeamCard(
      team: data.first.team,
      results: firstResults,
      stats: firstStats,
    );
    final awayCard = _LectorFormTeamCard(
      team: data.second.team,
      results: secondResults,
      stats: secondStats,
      alignEnd: true,
    );
    final delta = _LectorFormDeltaPill(
      firstStats: firstStats,
      secondStats: secondStats,
    );

    if (compact) {
      return Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: homeCard),
              const SizedBox(width: 10),
              delta,
            ],
          ),
          const SizedBox(height: 10),
          awayCard,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: homeCard),
        const SizedBox(width: 10),
        delta,
        const SizedBox(width: 10),
        Expanded(child: awayCard),
      ],
    );
  }
}

class _LectorFormTeamCard extends StatelessWidget {
  const _LectorFormTeamCard({
    required this.team,
    required this.results,
    required this.stats,
    this.alignEnd = false,
  });

  final LectorFormTeam team;
  final List<String> results;
  final LectorFormSummary stats;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = context.surfaces;
    final textColors = context.textColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaces.surfaceHover.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: surfaces.border.withValues(alpha: 0.78)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: alignEnd
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: alignEnd
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              children: [
                if (!alignEnd) ...[
                  SportsAssetBadge(
                    size: 27,
                    imageUrl: team.logoUrl,
                    fallbackLabel: team.name,
                    backgroundColor: AppColors.transparent,
                    padding: 1,
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    team.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: alignEnd ? TextAlign.right : TextAlign.left,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: textColors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (alignEnd) ...[
                  const SizedBox(width: 8),
                  SportsAssetBadge(
                    size: 27,
                    imageUrl: team.logoUrl,
                    fallbackLabel: team.name,
                    backgroundColor: AppColors.transparent,
                    padding: 1,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 9),
            _LectorFormDotsRow(results: results, alignEnd: alignEnd),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: stats.hasResults ? '${stats.points}' : '-',
                    style: TextStyle(
                      color: stats.points * 3 >= stats.maximumPoints * 2
                          ? context.semantic.success
                          : stats.points * 3 <= stats.maximumPoints
                          ? context.semantic.error
                          : textColors.secondary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  TextSpan(
                    text: stats.maximumPoints == 0
                        ? ' / — pts'
                        : ' / ${stats.maximumPoints} pts',
                    style: TextStyle(
                      color: textColors.secondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _LectorFormDeltaPill extends StatelessWidget {
  const _LectorFormDeltaPill({
    required this.firstStats,
    required this.secondStats,
  });

  final LectorFormSummary firstStats;
  final LectorFormSummary secondStats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = context.surfaces;
    final textColors = context.textColors;
    final gap = firstStats.hasResults && secondStats.hasResults
        ? (firstStats.points - secondStats.points).abs()
        : null;

    return Container(
      width: 70,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
      decoration: BoxDecoration(
        color: surfaces.surfaceHover.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: surfaces.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            gap == null ? 'Écart' : '+$gap pts',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelLarge?.copyWith(
              color: gap == null || gap == 0
                  ? textColors.secondary
                  : context.semantic.success,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'forme',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: textColors.secondary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LectorFormDotsRow extends StatelessWidget {
  const _LectorFormDotsRow({required this.results, this.alignEnd = false});

  final List<String> results;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final values = results.isEmpty ? const ['-', '-', '-', '-', '-'] : results;

    return Wrap(
      alignment: alignEnd ? WrapAlignment.end : WrapAlignment.start,
      spacing: 5,
      runSpacing: 4,
      children: [
        for (final result in values.take(5))
          Container(
            width: 23,
            height: 23,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _formDotColor(context, result),
            ),
            child: Text(
              _lectorFormResultLabel(result),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: _formDotForeground(context, result),
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
      ],
    );
  }
}

class _LectorSubsectionTitle extends StatelessWidget {
  const _LectorSubsectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = context.brand;
    final textColors = context.textColors;

    return Row(
      children: [
        Icon(icon, color: brand.accent, size: 19),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: textColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _LectorRecentFormSection extends StatelessWidget {
  const _LectorRecentFormSection({
    required this.data,
    required this.firstMatches,
    required this.secondMatches,
    required this.firstResults,
    required this.secondResults,
  });

  final LectorFormComparisonData data;
  final List<LectorRecentFormMatch> firstMatches;
  final List<LectorRecentFormMatch> secondMatches;
  final List<String> firstResults;
  final List<String> secondResults;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _LectorSubsectionTitle(
          icon: Icons.calendar_month_rounded,
          title: 'DERNIERS MATCHS',
        ),
        const SizedBox(height: 3),
        const _FormChronologyHint(compact: true),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final stack = constraints.maxWidth < 390;
            if (stack) {
              return Column(
                children: [
                  _LectorCompactRecentFormList(
                    teamName: data.first.team.name,
                    matches: firstMatches,
                    fallbackResults: firstResults,
                  ),
                  const SizedBox(height: 8),
                  _LectorCompactRecentFormList(
                    teamName: data.second.team.name,
                    matches: secondMatches,
                    fallbackResults: secondResults,
                  ),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _LectorCompactRecentFormList(
                    teamName: data.first.team.name,
                    matches: firstMatches,
                    fallbackResults: firstResults,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _LectorCompactRecentFormList(
                    teamName: data.second.team.name,
                    matches: secondMatches,
                    fallbackResults: secondResults,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _LectorCompactRecentFormList extends StatelessWidget {
  const _LectorCompactRecentFormList({
    required this.teamName,
    required this.matches,
    required this.fallbackResults,
  });

  final String teamName;
  final List<LectorRecentFormMatch> matches;
  final List<String> fallbackResults;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = context.surfaces;
    final textColors = context.textColors;

    final orderedMatches = matches.take(5).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          teamName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelMedium?.copyWith(
            color: textColors.primary,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        DecoratedBox(
          decoration: BoxDecoration(
            color: surfaces.surfaceHover.withValues(alpha: 0.34),
            borderRadius: BorderRadius.circular(AppRadius.input),
            border: Border.all(color: surfaces.border.withValues(alpha: 0.75)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.input),
            child: Column(
              children: [
                if (orderedMatches.isNotEmpty)
                  for (var index = 0; index < orderedMatches.length; index++)
                    _LectorCompactRecentFormRow(
                      match: orderedMatches[index],
                      showDivider: index < orderedMatches.length - 1,
                    )
                else
                  for (
                    var index = 0;
                    index < fallbackResults.take(5).length;
                    index++
                  )
                    _LectorFallbackFormRow(
                      result: fallbackResults[index],
                      index: index,
                      showDivider: index < fallbackResults.take(5).length - 1,
                    ),
                if (matches.isEmpty && fallbackResults.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(9),
                    child: Text(
                      'Résultats indisponibles.',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: textColors.secondary,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LectorCompactRecentFormRow extends StatelessWidget {
  const _LectorCompactRecentFormRow({
    required this.match,
    required this.showDivider,
  });

  final LectorRecentFormMatch match;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(
                  color: surfaces.border.withValues(alpha: 0.62),
                ),
              )
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 43,
              child: Text(
                match.playedAt == null
                    ? '—'
                    : DateFormat('dd.MM.yy').format(match.playedAt!.toLocal()),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.textColors.secondary,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SizedBox(
              width: 28,
              child: Text(
                match.home ? 'Dom.' : 'Ext.',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.textColors.secondary,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SportsAssetBadge(
              size: 19,
              imageUrl: match.opponentLogoUrl,
              fallbackLabel: match.opponentName,
              backgroundColor: AppColors.transparent,
              padding: 1,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                match.opponentName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.textColors.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              match.scoreLabel,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.textColors.primary,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 5),
            _LectorTinyResultBadge(result: match.result),
          ],
        ),
      ),
    );
  }
}

class _LectorFallbackFormRow extends StatelessWidget {
  const _LectorFallbackFormRow({
    required this.result,
    required this.index,
    required this.showDivider,
  });

  final String result;
  final int index;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final textColors = context.textColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(
                  color: surfaces.border.withValues(alpha: 0.62),
                ),
              )
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Match J-${5 - index}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: textColors.secondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _LectorTinyResultBadge(result: result),
          ],
        ),
      ),
    );
  }
}

class _LectorTinyResultBadge extends StatelessWidget {
  const _LectorTinyResultBadge({required this.result});

  final String result;

  @override
  Widget build(BuildContext context) {
    return LectorResultBadge(result: result);
  }
}

class _LectorFormTakeaway extends StatelessWidget {
  const _LectorFormTakeaway({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = context.surfaces;
    final textColors = context.textColors;
    final accent = context.opportunities.levelGap;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaces.surfaceHover.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: surfaces.border.withValues(alpha: 0.75)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.auto_awesome_rounded, size: 19, color: accent),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'À RETENIR',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    text,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: textColors.secondary,
                      fontSize: 11,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _formDotColor(BuildContext context, String result) {
  final value = result.toUpperCase();
  if (value == 'W' || value == 'V') {
    return context.semantic.success;
  }
  if (value == 'D' || value == 'N') {
    return context.textColors.secondary;
  }
  if (value == 'L' || value == 'P') {
    return context.semantic.error;
  }
  return context.surfaces.border;
}

Color _formDotForeground(BuildContext context, String result) {
  final value = result.toUpperCase();
  if (value == 'W' || value == 'V') return context.semantic.onSuccess;
  if (value == 'D' || value == 'N') return context.semantic.onNeutral;
  if (value == 'L' || value == 'P') return context.semantic.onError;
  return context.textColors.primary;
}
