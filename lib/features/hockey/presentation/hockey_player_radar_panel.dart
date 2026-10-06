import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/lector_player_radar.dart';
import '../../../core/widgets/lector_form_radar_signal_panel.dart';
import '../../../core/widgets/lector_match_card.dart';
import '../../../core/sports/domain/sport_player_activity.dart';
import '../domain/hockey_player_radar.dart';

String hockeyPlayerMetric(HockeyPlayerRadarEntry e) =>
    '${e.decisiveMatches}/3 décisif · série ${e.streakLimitedByUnknown ? '≥ ' : ''}${e.streak}';
LectorPlayerActivity hockeyActivity(
  SportPlayerMatchActivity m,
) => LectorPlayerActivity(
  contributions: m.contributions,
  label:
      '${DateFormat('dd/MM').format(m.result.startsAt.toLocal())} · ${m.result.opponent} · ${m.contributionsKnown ? '${m.goals} buts · ${m.assists} passes' : 'Contributions inconnues'}',
);
Widget hockeyPlayerMatrix(
  BuildContext context,
  HockeyPlayerRadarEntry entry, {
  int? columnCount,
}) => LectorPlayerActivityMatrix(
  activity: entry.profile.activity.map(hockeyActivity).toList(),
  columnCount: columnCount ?? entry.profile.activity.length,
  onMatchTap: (index) =>
      showHockeyPlayerActivity(context, entry, selected: index),
);
void showHockeyPlayerActivity(
  BuildContext context,
  HockeyPlayerRadarEntry entry, {
  int? selected,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.profile.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(entry.profile.team.name),
            const SizedBox(height: 12),
            for (final indexed in entry.profile.activity.indexed)
              LectorMatchCardFrame(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${DateFormat('dd/MM/yyyy').format(indexed.$2.result.startsAt.toLocal())} · ${indexed.$2.result.home ? 'Domicile' : 'Extérieur'}',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Text(
                      '${indexed.$2.result.opponent} · ${indexed.$2.result.scored}–${indexed.$2.result.conceded}',
                    ),
                    Text(
                      indexed.$2.contributionsKnown
                          ? '${indexed.$2.goals} buts · ${indexed.$2.assists} passes'
                          : 'Contributions inconnues',
                      style: selected == indexed.$1
                          ? Theme.of(context).textTheme.titleMedium
                          : null,
                    ),
                  ],
                ),
              ),
            const Text(
              'Une contribution correspond à un but ou une passe. Un zéro ne signifie pas que le joueur était absent.',
            ),
          ],
        ),
      ),
    ),
  );
}

class HockeyPlayerSignalPanel extends StatelessWidget {
  const HockeyPlayerSignalPanel({required this.entries, super.key});
  final List<HockeyPlayerRadarEntry> entries;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final count = entries.fold<int>(
        3,
        (n, e) => e.profile.activity.length > n ? e.profile.activity.length : n,
      );
      final columns = lectorPlayerMatrixColumns(count, constraints.maxWidth);
      return LectorFormRadarSignalPanel(
        periodLabel: LectorPlayerPeriodLabel(columnCount: columns),
        rows: [
          for (final e in entries)
            LectorFormRadarSignalRow(
              name: e.profile.name,
              description: LectorPlayerSignalDescription(
                name: e.profile.name,
                teamName: e.profile.team.name,
                teamLogoUrl: e.profile.team.logoUrl,
                metric: hockeyPlayerMetric(e),
              ),
              activity: hockeyPlayerMatrix(context, e, columnCount: columns),
            ),
        ],
      );
    },
  );
}
