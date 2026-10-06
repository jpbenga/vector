import 'package:flutter/material.dart';
import '../theme/app_components.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import 'sports_asset_badge.dart';

class LectorRadarRankingPanel extends StatelessWidget {
  const LectorRadarRankingPanel({
    required this.title,
    required this.totalCount,
    required this.children,
    this.footer,
    this.emptyState,
    this.description,
    this.icon = Icons.groups_rounded,
    super.key,
  });
  final String title;
  final int totalCount;
  final List<Widget> children;
  final Widget? footer, emptyState, description;
  final IconData icon;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.surfaces.backgroundSecondary,
      borderRadius: BorderRadius.circular(AppRadius.card),
      border: Border.all(color: context.surfaces.border),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      child: totalCount == 0 && emptyState != null
          ? emptyState!
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      icon,
                      color: icon == Icons.local_fire_department_rounded
                          ? context.semantic.warning
                          : context.brand.accent,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: context.textColors.primary,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                    Text(
                      'Top $totalCount',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: context.textColors.secondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ?description,
                ...children,
                ?footer,
              ],
            ),
    ),
  );
}

/// The same ranked team row, irrespective of the scoring rules of its sport.
class LectorRadarTeamRow extends StatelessWidget {
  const LectorRadarTeamRow({
    required this.rank,
    required this.name,
    required this.competitionName,
    required this.activity,
    required this.metric,
    required this.streakLabel,
    this.logoUrl,
    super.key,
  });
  final int rank;
  final String name, competitionName, metric, streakLabel;
  final String? logoUrl;
  final Widget activity;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final identity = Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: context.textColors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SportsAssetBadge(
            size: 34,
            imageUrl: logoUrl,
            fallbackLabel: name,
            borderRadius: 17,
            contrastPlate: true,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.textColors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  competitionName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.textColors.secondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '$metric · $streakLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.semantic.success,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
      if (constraints.maxWidth < 360) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            identity,
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: activity),
          ],
        );
      }
      return Row(
        children: [
          Expanded(child: identity),
          const SizedBox(width: 8),
          activity,
        ],
      );
    },
  );
}

/// Chronological result cells with a fixed recent window and a scrollable past.
/// Tap indices always refer to the full input, including older matches.
class LectorFormResultStrip extends StatelessWidget {
  const LectorFormResultStrip({
    required this.results,
    this.onMatchTap,
    this.tooltips = const [],
    this.historyColumns = 0,
    super.key,
  }) : assert(historyColumns >= 0);
  final List<String> results, tooltips;
  final ValueChanged<int>? onMatchTap;
  final int historyColumns;
  static const recentWindow = 5;
  static const cellSize = 13.0, spacing = 3.0, separatorWidth = 11.0;
  static double widthFor(int count) =>
      count == 0 ? 0 : count * (cellSize + spacing) - spacing;

  Widget _cells(BuildContext context, int from, int to) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = from; i < to; i++) ...[
        Tooltip(
          message: i < tooltips.length
              ? tooltips[i]
              : switch (results[i].toUpperCase()) {
                  'W' || 'V' => 'Victoire',
                  'D' || 'N' => 'Nul',
                  _ => 'Défaite',
                },
          child: InkWell(
            key: ValueKey('team-form-result-$i'),
            onTap: onMatchTap == null ? null : () => onMatchTap!(i),
            borderRadius: BorderRadius.circular(3),
            child: Container(
              width: cellSize,
              height: cellSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: switch (results[i].toUpperCase()) {
                  'W' || 'V' => context.semantic.success,
                  'D' ||
                  'N' => context.textColors.secondary.withValues(alpha: .27),
                  _ => context.semantic.error,
                },
              ),
            ),
          ),
        ),
        if (i < to - 1) const SizedBox(width: spacing),
      ],
    ],
  );

  @override
  Widget build(BuildContext context) {
    final split = (results.length - recentWindow).clamp(0, results.length);
    if (historyColumns == 0) return _cells(context, split, results.length);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: widthFor(historyColumns),
          child: Align(
            alignment: Alignment.centerRight,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: _cells(context, 0, split),
            ),
          ),
        ),
        SizedBox(
          width: separatorWidth,
          child: Center(
            child: Container(
              key: const ValueKey('team-form-history-separator'),
              width: 2,
              height: 19,
              color: context.brand.accent,
            ),
          ),
        ),
        SizedBox(
          width: widthFor(recentWindow),
          child: Align(
            alignment: Alignment.centerRight,
            child: _cells(context, split, results.length),
          ),
        ),
      ],
    );
  }
}

class LectorTeamFormHistoryLegend extends StatelessWidget {
  const LectorTeamFormHistoryLegend({super.key});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: LectorFormResultStrip.widthFor(5),
        child: Text(
          'Avant',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: context.textColors.secondary),
        ),
      ),
      SizedBox(
        width: LectorFormResultStrip.separatorWidth,
        child: Center(
          child: Container(width: 2, height: 19, color: context.brand.accent),
        ),
      ),
      SizedBox(
        width: LectorFormResultStrip.widthFor(5),
        child: Text(
          '5 derniers',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: context.brand.accent,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ],
  );
}

class LectorRadarEntryCard extends StatelessWidget {
  const LectorRadarEntryCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.control);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Material(
        color: context.surfaces.surface,
        elevation: 2,
        shadowColor: context.surfaces.shadow.withValues(alpha: .16),
        borderRadius: radius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: context.surfaces.border.withValues(alpha: .8),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 9),
            child: child,
          ),
        ),
      ),
    );
  }
}

class LectorRadarPagination extends StatelessWidget {
  const LectorRadarPagination({
    required this.keyPrefix,
    required this.itemCount,
    required this.page,
    required this.pageSize,
    required this.onPageChanged,
    super.key,
  });

  final String keyPrefix;
  final int itemCount;
  final int page;
  final int pageSize;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final pageCount = (itemCount == 0 ? 1 : (itemCount - 1) ~/ pageSize + 1);
    final first = itemCount == 0 ? 0 : page * pageSize + 1;
    final last = ((page + 1) * pageSize).clamp(0, itemCount);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.surfaces.backgroundSecondary,
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(color: context.surfaces.border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Row(
            children: [
              IconButton(
                key: ValueKey('$keyPrefix-previous'),
                tooltip: 'Page précédente',
                onPressed: page > 0 ? () => onPageChanged(page - 1) : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '$first–$last sur $itemCount',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: context.textColors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Page ${page + 1} sur $pageCount',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: context.textColors.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: ValueKey('$keyPrefix-next'),
                tooltip: 'Page suivante',
                onPressed: page + 1 < pageCount
                    ? () => onPageChanged(page + 1)
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LectorRadarModeToggle extends StatelessWidget {
  const LectorRadarModeToggle({
    required this.firstLabel,
    required this.secondLabel,
    required this.secondSelected,
    required this.onChanged,
    super.key,
  });
  final String firstLabel, secondLabel;
  final bool secondSelected;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.surfaces.backgroundSecondary,
      borderRadius: BorderRadius.circular(AppRadius.card),
      border: Border.all(color: context.surfaces.border),
    ),
    child: Row(
      children: [
        for (final (second, label) in [
          (false, firstLabel),
          (true, secondLabel),
        ])
          Expanded(
            child: InkWell(
              onTap: () => onChanged(second),
              borderRadius: BorderRadius.circular(AppRadius.card - 1),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: secondSelected == second
                      ? context.brand.accent
                      : AppColors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.card - 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Center(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: secondSelected == second
                            ? context.brand.onAccent
                            : context.textColors.secondary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
