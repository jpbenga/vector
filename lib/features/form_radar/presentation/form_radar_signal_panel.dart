import '../../../core/widgets/lector_player_radar.dart';
import '../../../core/widgets/lector_form_radar_signal_panel.dart';
import 'package:flutter/material.dart';

import '../../matches/domain/match_board_item.dart';
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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final uniqueEntries = PlayerFormRadarRanker.rank(
        entries.map((entry) => entry.profile),
      );
      if (uniqueEntries.isEmpty) return const SizedBox.shrink();
      final historyCount = uniqueEntries.fold<int>(
        PlayerFormRadarRanker.recentWindow,
        (current, entry) => entry.profile.activity.length > current
            ? entry.profile.activity.length
            : current,
      );
      final matrixColumns = lectorPlayerMatrixColumns(
        historyCount,
        constraints.maxWidth,
      );
      return LectorFormRadarSignalPanel(
        isLocalPreview: isLocalPreview,
        periodLabel: FormRadarPeriodLabel(columnCount: matrixColumns),
        rows: [
          for (final entry in uniqueEntries)
            _FormRadarSignalRow(entry: entry, matrixColumns: matrixColumns),
        ],
      );
    },
  );
}

class _FormRadarSignalRow extends StatelessWidget {
  const _FormRadarSignalRow({required this.entry, required this.matrixColumns});

  final PlayerFormRadarEntry entry;
  final int matrixColumns;

  @override
  Widget build(BuildContext context) => LectorFormRadarSignalRow(
    name: entry.profile.playerName,
    logoUrl: entry.profile.photoUrl,
    description: LectorPlayerSignalDescription(
      name: entry.profile.playerName,
      teamName: entry.profile.teamName,
      teamLogoUrl: entry.profile.teamLogoUrl,
      metric:
          '${entry.recentDecisiveMatches}/3 décisif · série ${entry.decisiveStreak}',
    ),
    activity: LectorPlayerActivityMatrix(
      activity: entry.profile.activity.map(footballPlayerActivity).toList(),
      columnCount: matrixColumns,
    ),
  );
}

LectorPlayerActivity footballPlayerActivity(
  PlayerFormRadarMatchSnapshot match,
) => LectorPlayerActivity(
  contributions: match.contributions,
  appeared: match.appeared,
  substitute: match.substitute,
  label:
      'Match du ${match.playedAt.day}/${match.playedAt.month} · ${match.goals} buts · ${match.assists} passes',
);

class FormRadarPeriodLabel extends StatelessWidget {
  const FormRadarPeriodLabel({required this.columnCount, super.key});
  final int columnCount;
  @override
  Widget build(BuildContext context) =>
      LectorPlayerPeriodLabel(columnCount: columnCount);
}

double formRadarMatrixWidth(int columnCount) =>
    lectorPlayerMatrixWidth(columnCount);
