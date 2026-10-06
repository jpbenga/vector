import 'package:flutter/material.dart';
import '../theme/app_components.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import 'sports_asset_badge.dart';

/// Presentation data only. Sport adapters determine eligibility, activity and
/// ranking. Null presence means the provider did not supply a lineup.
class LectorPlayerActivity {
  const LectorPlayerActivity({
    required this.contributions,
    required this.label,
    this.appeared,
    this.substitute = false,
  });
  final int? contributions;
  final String label;
  final bool? appeared;
  final bool substitute;
}

class LectorRadarPlayerRow extends StatelessWidget {
  const LectorRadarPlayerRow({
    required this.rank,
    required this.name,
    required this.teamName,
    required this.recentLine,
    required this.stats,
    required this.activity,
    this.photoUrl,
    this.teamLogoUrl,
    this.onTap,
    super.key,
  });
  final int rank;
  final String name, teamName, recentLine, stats;
  final String? photoUrl, teamLogoUrl;
  final VoidCallback? onTap;
  final Widget activity;
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: '$name, $recentLine',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
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
                size: 38,
                imageUrl: photoUrl,
                fallbackLabel: name,
                borderRadius: 19,
                backgroundColor: AppColors.transparent,
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
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        SportsAssetBadge(
                          size: 15,
                          imageUrl: teamLogoUrl,
                          fallbackLabel: teamName,
                          borderRadius: 4,
                          contrastPlate: true,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            teamName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: context.textColors.secondary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      recentLine,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: context.semantic.success,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      stats,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: context.textColors.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              activity,
            ],
          ),
        ),
      ),
    );
  }
}

class LectorPlayerActivityMatrix extends StatelessWidget {
  const LectorPlayerActivityMatrix({
    required this.activity,
    required this.columnCount,
    this.recentWindow = 3,
    this.onMatchTap,
    super.key,
  });
  final List<LectorPlayerActivity> activity;
  final int columnCount, recentWindow;
  final ValueChanged<int>? onMatchTap;
  @override
  Widget build(BuildContext context) {
    final history = (columnCount - recentWindow).clamp(0, 99);
    final split = (activity.length - recentWindow).clamp(0, activity.length);
    Widget strip(int start, int end) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = start; i < end; i++) ...[
          Semantics(
            button: onMatchTap != null,
            label: activity[i].label,
            child: InkWell(
              onTap: onMatchTap == null ? null : () => onMatchTap!(i),
              child: Tooltip(
                message: activity[i].label,
                child: LectorPlayerActivityCell(activity: activity[i]),
              ),
            ),
          ),
          if (i < end - 1) const SizedBox(width: 3),
        ],
      ],
    );
    return SizedBox(
      width: lectorPlayerMatrixWidth(columnCount, recentWindow: recentWindow),
      child: Row(
        children: [
          if (history > 0) ...[
            SizedBox(
              width: _cellsWidth(history),
              child: Align(
                alignment: Alignment.centerRight,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: strip(0, split),
                ),
              ),
            ),
            const _PlayerMatrixDivider(),
          ],
          SizedBox(
            width: _cellsWidth(recentWindow),
            child: strip(split, activity.length),
          ),
        ],
      ),
    );
  }
}

class LectorPlayerPeriodLabel extends StatelessWidget {
  const LectorPlayerPeriodLabel({
    required this.columnCount,
    this.recentWindow = 3,
    super.key,
  });
  final int columnCount, recentWindow;
  @override
  Widget build(BuildContext context) {
    final history = (columnCount - recentWindow).clamp(0, 99);
    Widget label(String text, double width, Color color, String semantics) =>
        SizedBox(
          width: width,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              text,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.clip,
              textAlign: TextAlign.center,
              semanticsLabel: semantics,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        );
    return SizedBox(
      width: lectorPlayerMatrixWidth(columnCount, recentWindow: recentWindow),
      child: Row(
        children: [
          if (history > 0) ...[
            label(
              'Avant',
              _cellsWidth(history),
              context.textColors.secondary,
              'Matchs précédents',
            ),
            const _PlayerMatrixDivider(),
          ],
          label(
            '$recentWindow récents',
            _cellsWidth(recentWindow),
            context.brand.accent,
            '$recentWindow derniers matchs',
          ),
        ],
      ),
    );
  }
}

class _PlayerMatrixDivider extends StatelessWidget {
  const _PlayerMatrixDivider();
  @override
  Widget build(BuildContext context) => Container(
    width: 2,
    height: 19,
    margin: const EdgeInsets.symmetric(horizontal: 5),
    color: context.brand.accent,
  );
}

double _cellsWidth(int count) => count == 0 ? 0 : count * 14 + (count - 1) * 3;
double lectorPlayerMatrixWidth(int columnCount, {int recentWindow = 3}) {
  final history = (columnCount - recentWindow).clamp(0, 99);
  return _cellsWidth(history) +
      (history > 0 ? 12 : 0) +
      _cellsWidth(recentWindow);
}

/// Keep the recent window fixed and allow older matches to scroll inside the
/// previous-history area. Headers and rows must use this same slot count.
int lectorPlayerMatrixColumns(int activityCount, double availableWidth) {
  if (!availableWidth.isFinite) return activityCount.clamp(3, 102);
  final width = availableWidth * .45;
  final olderSlots = ((width - _cellsWidth(3) - 12 + 3) / 17).floor().clamp(
    0,
    99,
  );
  return activityCount.clamp(3, 3 + olderSlots);
}

class LectorPlayerActivityCell extends StatelessWidget {
  const LectorPlayerActivityCell({required this.activity, super.key});
  final LectorPlayerActivity activity;
  @override
  Widget build(BuildContext context) {
    if (activity.contributions == null) {
      return Container(
        width: 14,
        height: 14,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: context.textColors.secondary),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          '?',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontSize: 9,
            color: context.textColors.secondary,
          ),
        ),
      );
    }
    final decisive = activity.contributions! > 0 && activity.appeared != false;
    if (!decisive && activity.substitute && activity.appeared != false) {
      return SizedBox(
        width: 14,
        height: 14,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: 14,
            height: 6,
            decoration: BoxDecoration(
              color: context.semantic.warning,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );
    }
    final color = activity.appeared == false
        ? null
        : decisive
        ? context.semantic.success.withValues(
            alpha: activity.contributions! > 1 ? 1 : .58,
          )
        : context.textColors.secondary.withValues(alpha: .27);
    return Container(
      width: 14,
      height: 14,
      alignment: Alignment.bottomCenter,
      decoration: BoxDecoration(
        color: color,
        border: color == null
            ? Border.all(color: context.surfaces.border)
            : null,
        borderRadius: BorderRadius.circular(3),
      ),
      child: decisive && activity.substitute
          ? Container(height: 3, color: context.semantic.warning)
          : null,
    );
  }
}

class LectorPlayerRadarLegend extends StatelessWidget {
  const LectorPlayerRadarLegend({
    this.presenceKnown = true,
    this.showUnknown = false,
    super.key,
  });
  final bool presenceKnown, showUnknown;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 7,
    children: [
      if (presenceKnown) ...[
        _item(context, false, false, 0, 'Absent'),
        _item(context, true, false, 0, 'Titulaire'),
        _item(context, true, true, 0, 'Entrée'),
      ] else
        _item(context, null, false, 0, '0 contribution'),
      _item(context, true, false, 1, '1 action'),
      _item(context, true, false, 2, '2+ actions'),
      if (showUnknown) _item(context, null, false, null, 'Inconnu'),
    ],
  );
  Widget _item(
    BuildContext context,
    bool? appeared,
    bool substitute,
    int? count,
    String text,
  ) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: 16,
        child: Center(
          child: LectorPlayerActivityCell(
            activity: LectorPlayerActivity(
              contributions: count,
              label: text,
              appeared: appeared,
              substitute: substitute,
            ),
          ),
        ),
      ),
      const SizedBox(width: 4),
      Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: context.textColors.secondary,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

/// Identity/metric block shared by both sports' embedded player signals.
class LectorPlayerSignalDescription extends StatelessWidget {
  const LectorPlayerSignalDescription({
    required this.name,
    required this.teamName,
    required this.metric,
    this.teamLogoUrl,
    super.key,
  });
  final String name, teamName, metric;
  final String? teamLogoUrl;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: context.textColors.primary,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 1),
      Row(
        children: [
          SportsAssetBadge(
            size: 14,
            imageUrl: teamLogoUrl,
            fallbackLabel: teamName,
            borderRadius: 4,
            contrastPlate: true,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              teamName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.textColors.secondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      Text(
        metric,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: context.semantic.success,
          fontWeight: FontWeight.w900,
        ),
      ),
    ],
  );
}
