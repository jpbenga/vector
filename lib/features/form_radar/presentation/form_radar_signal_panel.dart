import 'package:flutter/material.dart';

import '../../../core/theme/app_components.dart';
import '../../../core/theme/app_radius.dart';
import '../../matches/domain/match_board_item.dart';
import '../../matches/presentation/widgets/sports_asset_badge.dart';
import '../domain/player_form_radar.dart';

/// Compact Form Radar context embedded in an existing “Pour moi” match card.
///
/// It never decides whether a match belongs to “Pour moi”. It only describes
/// hot players already attached to the teams in that selected match.
class FormRadarSignalPanel extends StatelessWidget {
  const FormRadarSignalPanel({
    required this.entries,
    this.isLocalPreview = false,
    super.key,
  });

  final List<PlayerFormRadarEntry> entries;
  final bool isLocalPreview;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final matrixColumns = entries.fold<int>(
      PlayerFormRadarRanker.recentWindow,
      (current, entry) => entry.profile.activity.length > current
          ? entry.profile.activity.length
          : current,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.surfaces.background.withValues(alpha: .45),
        border: Border.all(color: context.surfaces.border),
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bar_chart_rounded,
                  color: context.brand.accent,
                  size: 19,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Signaux Form Radar',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.textColors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '${entries.length} signal${entries.length > 1 ? 's' : ''} de forme',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.textColors.secondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (isLocalPreview) ...[
                  const SizedBox(width: 6),
                  Text(
                    'aperçu local',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: context.brand.accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 7),
            Align(
              alignment: Alignment.centerRight,
              child: _FormRadarPeriodMarker(columnCount: matrixColumns),
            ),
            const SizedBox(height: 4),
            for (final indexed in entries.indexed) ...[
              if (indexed.$1 > 0)
                Divider(height: 12, color: context.surfaces.border),
              _FormRadarSignalRow(
                entry: indexed.$2,
                matrixColumns: matrixColumns,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FormRadarSignalRow extends StatelessWidget {
  const _FormRadarSignalRow({required this.entry, required this.matrixColumns});

  final PlayerFormRadarEntry entry;
  final int matrixColumns;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SportsAssetBadge(
        size: 34,
        imageUrl: entry.profile.photoUrl,
        fallbackLabel: entry.profile.playerName,
        borderRadius: 17,
        contrastPlate: true,
      ),
      const SizedBox(width: 7),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.profile.playerName,
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
                  imageUrl: entry.profile.teamLogoUrl,
                  fallbackLabel: entry.profile.teamName,
                  borderRadius: 4,
                  contrastPlate: true,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    entry.profile.teamName,
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
              '${entry.recentDecisiveMatches}/3 décisif · série ${entry.decisiveStreak}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.semantic.success,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 7),
      _FormRadarActivityMatrix(
        activity: entry.profile.activity,
        columnCount: matrixColumns,
      ),
    ],
  );
}

class _FormRadarPeriodMarker extends StatelessWidget {
  const _FormRadarPeriodMarker({required this.columnCount});
  final int columnCount;

  @override
  Widget build(BuildContext context) {
    final historyColumns = _historyColumns(columnCount);
    return SizedBox(
      width: _matrixWidth(columnCount),
      child: Row(
        children: [
          SizedBox(
            width: _cellsWidth(historyColumns),
            child: Text(
              'Historique',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.textColors.secondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _FormRadarDivider(color: context.brand.accent),
          SizedBox(
            width: _cellsWidth(PlayerFormRadarRanker.recentWindow),
            child: Semantics(
              label: 'Trois derniers matchs',
              child: Text(
                '3 récents',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.brand.accent,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormRadarActivityMatrix extends StatelessWidget {
  const _FormRadarActivityMatrix({
    required this.activity,
    required this.columnCount,
  });

  final List<PlayerFormRadarMatchSnapshot> activity;
  final int columnCount;

  @override
  Widget build(BuildContext context) {
    final historyColumns = _historyColumns(columnCount);
    final allPrior = activity.length <= PlayerFormRadarRanker.recentWindow
        ? const <PlayerFormRadarMatchSnapshot>[]
        : activity.sublist(
            0,
            activity.length - PlayerFormRadarRanker.recentWindow,
          );
    final prior = allPrior.length <= historyColumns
        ? allPrior
        : allPrior.sublist(allPrior.length - historyColumns);
    final recent = activity.length < PlayerFormRadarRanker.recentWindow
        ? activity
        : activity.sublist(
            activity.length - PlayerFormRadarRanker.recentWindow,
          );
    return SizedBox(
      width: _matrixWidth(columnCount),
      child: Row(
        children: [
          SizedBox(
            width: _cellsWidth(historyColumns),
            child: Align(
              alignment: Alignment.centerRight,
              child: _FormRadarCellStrip(matches: prior),
            ),
          ),
          _FormRadarDivider(color: context.brand.accent),
          SizedBox(
            width: _cellsWidth(PlayerFormRadarRanker.recentWindow),
            child: _FormRadarCellStrip(matches: recent),
          ),
        ],
      ),
    );
  }
}

class _FormRadarCellStrip extends StatelessWidget {
  const _FormRadarCellStrip({required this.matches});
  final List<PlayerFormRadarMatchSnapshot> matches;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final indexed in matches.indexed) ...[
        _FormRadarCell(match: indexed.$2),
        if (indexed.$1 != matches.length - 1)
          const SizedBox(width: _cellSpacing),
      ],
    ],
  );
}

class _FormRadarCell extends StatelessWidget {
  const _FormRadarCell({required this.match});
  final PlayerFormRadarMatchSnapshot match;

  @override
  Widget build(BuildContext context) {
    if (!match.appeared) return _box(context);
    if (match.isDecisive) {
      return _box(
        context,
        color: context.semantic.success.withValues(
          alpha: match.contributions > 1 ? 1 : .58,
        ),
        bottomStrip: match.substitute,
      );
    }
    if (match.substitute) {
      return SizedBox(
        width: _cellSize,
        height: _cellSize,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: _cellSize,
            height: 6,
            decoration: BoxDecoration(
              color: context.semantic.warning,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );
    }
    return _box(
      context,
      color: context.textColors.secondary.withValues(alpha: .27),
    );
  }

  Widget _box(BuildContext context, {Color? color, bool bottomStrip = false}) =>
      Container(
        width: _cellSize,
        height: _cellSize,
        alignment: Alignment.bottomCenter,
        decoration: BoxDecoration(
          color: color,
          border: color == null
              ? Border.all(color: context.surfaces.border)
              : null,
          borderRadius: BorderRadius.circular(3),
        ),
        child: bottomStrip
            ? Container(height: 3, color: context.semantic.warning)
            : null,
      );
}

class _FormRadarDivider extends StatelessWidget {
  const _FormRadarDivider({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 2,
    height: 19,
    margin: const EdgeInsets.symmetric(horizontal: _dividerGap),
    color: color,
  );
}

const double _cellSize = 14;
const double _cellSpacing = 3;
const double _dividerGap = 5;

int _historyColumns(int columnCount) =>
    (columnCount - PlayerFormRadarRanker.recentWindow).clamp(0, 99);

double _cellsWidth(int count) =>
    count == 0 ? 0 : count * _cellSize + (count - 1) * _cellSpacing;

double _matrixWidth(int columnCount) =>
    _cellsWidth(_historyColumns(columnCount)) +
    _cellsWidth(PlayerFormRadarRanker.recentWindow) +
    2 +
    _dividerGap * 2;
