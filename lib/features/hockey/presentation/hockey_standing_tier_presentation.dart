import 'package:flutter/material.dart';
import '../../../core/theme/app_components.dart';
import '../../../core/sports/domain/sport_competition_context.dart';
import '../../../core/widgets/lector_standing_table.dart';
import '../domain/hockey_standing_tiers.dart';

/// Both hockey table journeys supply their cells to the football/Lector table
/// renderer. The same domain classification supplies the bands and readings.
abstract final class HockeyStandingTierPresentation {
  static List<LectorStandingGroupData> groups(
    BuildContext context,
    List<LectorStandingEntry> entries,
    HockeyTierClassification tiers,
  ) {
    final groups = <LectorStandingGroupData>[];
    for (final row in entries) {
      final tier = tiers.tiers[row.identity];
      final label = tier == null ? null : 'T$tier';
      final color = tier == null
          ? null
          : lectorStandingTierColor(context, tier);
      if (groups.isEmpty || groups.last.label != label) {
        groups.add(
          LectorStandingGroupData(label: label, color: color, rows: [row]),
        );
      } else {
        final last = groups.removeLast();
        groups.add(
          LectorStandingGroupData(
            label: label,
            color: color,
            rows: [...last.rows, row],
          ),
        );
      }
    }
    return groups;
  }

  static Widget legend(
    BuildContext context,
    List<SportStandingRow> rows,
    HockeyTierClassification classification,
  ) {
    final tiers = classification.tiers.values.toSet().toList()..sort();
    final descriptions = rows
        .map((r) => r.description)
        .whereType<String>()
        .where((d) => d.isNotEmpty)
        .toSet();
    return LectorStandingLegend(
      officialZones: [
        for (final label in descriptions)
          LectorStandingLegendEntry(
            label: label,
            color: context.brand.accent,
            rankLabel: _rankLabel(
              rows.where((r) => r.description == label).map((r) => r.rank),
            ),
          ),
      ],
      tiers: [
        for (final tier in tiers)
          LectorStandingLegendEntry(
            label: 'T$tier · ${HockeyStandingTiers.labels[tier]}',
            color: lectorStandingTierColor(context, tier),
          ),
      ],
      tiersAreProvisional: classification.available,
      tierExplanation:
          classification.reason ??
          'Bandes T1–T5 : tiers Lector du groupe affiché. Au moins 5 matchs par équipe ; repères de tête et de fin, puis ruptures de points. Les tiers locaux de deux divisions différentes ne sont pas directement comparables. Ils ne désignent pas une qualification ou une relégation.',
    );
  }
}

String _rankLabel(Iterable<int> positions) {
  final ranks = positions.toList()..sort();
  final ranges = <String>[];
  for (var i = 0; i < ranks.length; i++) {
    final start = ranks[i];
    var end = start;
    while (i + 1 < ranks.length && ranks[i + 1] == end + 1) {
      end = ranks[++i];
    }
    ranges.add(start == end ? '$start' : '$start–$end');
  }
  return ranges.join(', ');
}
