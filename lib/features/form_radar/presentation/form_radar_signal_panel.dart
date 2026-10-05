import 'package:flutter/material.dart';

import '../../../core/theme/app_components.dart';
import '../../../core/widgets/lector_form_radar_signal_panel.dart';
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
    final uniqueEntries = PlayerFormRadarRanker.rank(
      entries.map((entry) => entry.profile),
    );
    if (uniqueEntries.isEmpty) return const SizedBox.shrink();
    final matrixColumns = uniqueEntries.fold<int>(
      PlayerFormRadarRanker.recentWindow,
      (current, entry) => entry.profile.activity.length > current
          ? entry.profile.activity.length
          : current,
    );
    return LectorFormRadarSignalPanel(
      isLocalPreview: isLocalPreview,
      periodLabel: FormRadarPeriodLabel(columnCount: matrixColumns),
      rows: [
        for (final entry in uniqueEntries)
          _FormRadarSignalRow(entry: entry, matrixColumns: matrixColumns),
      ],
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

class FormRadarPeriodLabel extends StatelessWidget {
  const FormRadarPeriodLabel({required this.columnCount, super.key});
  final int columnCount;

  @override
  Widget build(BuildContext context) {
    final historyColumns = _historyColumns(columnCount);
    return SizedBox(
      width: formRadarMatrixWidth(columnCount),
      child: Row(
        children: [
          if (historyColumns > 0) ...[
            SizedBox(
              width: _cellsWidth(historyColumns),
              child: Text(
                'Avant',
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.clip,
                textAlign: TextAlign.center,
                semanticsLabel: 'Matchs précédents',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.textColors.secondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _FormRadarDivider(color: context.brand.accent),
          ],
          SizedBox(
            width: _cellsWidth(PlayerFormRadarRanker.recentWindow),
            child: Semantics(
              label: 'Trois derniers matchs',
              child: Text(
                '3 récents',
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.clip,
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
      width: formRadarMatrixWidth(columnCount),
      child: Row(
        children: [
          if (historyColumns > 0) ...[
            SizedBox(
              width: _cellsWidth(historyColumns),
              child: Align(
                alignment: Alignment.centerRight,
                child: _FormRadarCellStrip(matches: prior),
              ),
            ),
            _FormRadarDivider(color: context.brand.accent),
          ],
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

double formRadarMatrixWidth(int columnCount) {
  final historyColumns = _historyColumns(columnCount);
  return _cellsWidth(historyColumns) +
      (historyColumns > 0 ? 2 + _dividerGap * 2 : 0) +
      _cellsWidth(PlayerFormRadarRanker.recentWindow);
}
