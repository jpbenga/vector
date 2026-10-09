import 'package:flutter/material.dart';
import '../domain/lector_recorded_radar.dart';
import '../theme/app_components.dart';
import 'lector_form_radar_signal_panel.dart';
import 'lector_player_radar.dart';

/// Frozen pre-match histories with a separate factual current-match caption.
class LectorRecordedRadarPanel extends StatelessWidget {
  const LectorRecordedRadarPanel({
    required this.snapshot,
    required this.contributions,
    required this.isLive,
    super.key,
  });
  final LectorRecordedRadar snapshot;
  final List<LectorRadarContribution> contributions;
  final bool isLive;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final count = snapshot.players.fold(
        3,
        (int n, p) => p.activity.length > n ? p.activity.length : n,
      );
      final columns = lectorPlayerMatrixColumns(count, constraints.maxWidth);
      final byPlayer = <String, List<String>>{};
      for (final c in contributions) {
        byPlayer.putIfAbsent(c.playerId, () => []).add(c.label);
      }
      // Decisive players remain visible in the collapsed preview.
      final originalRank = {
        for (var i = 0; i < snapshot.players.length; i++)
          snapshot.players[i].id: i,
      };
      final players = [...snapshot.players]
        ..sort((a, b) {
          final d =
              (byPlayer.containsKey(b.id) ? 1 : 0) -
              (byPlayer.containsKey(a.id) ? 1 : 0);
          return d != 0
              ? d
              : originalRank[a.id]!.compareTo(originalRank[b.id]!);
        });
      return LectorFormRadarSignalPanel(
        decisiveCount: byPlayer.length,
        isLive: isLive,
        periodLabel: LectorPlayerPeriodLabel(columnCount: columns),
        rows: [
          for (final p in players)
            LectorFormRadarSignalRow(
              name: p.name,
              logoUrl: p.photoUrl,
              description: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LectorPlayerSignalDescription(
                    name: p.name,
                    teamName: p.teamName,
                    teamLogoUrl: p.teamLogoUrl,
                    metric: '${p.recentDecisive}/3 décisif · série ${p.streak}',
                  ),
                  if (byPlayer.containsKey(p.id))
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        byPlayer[p.id]!.join(' · '),
                        key: ValueKey('radar-contribution-${p.id}'),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: context.semantic.success,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
              activity: LectorPlayerActivityMatrix(
                columnCount: columns,
                activity: p.activity
                    .map(
                      (a) => LectorPlayerActivity(
                        contributions: a.contributions,
                        appeared: a.appeared,
                        substitute: a.substitute,
                        label:
                            'Match du ${a.playedAt.day}/${a.playedAt.month} · ${a.contributions == null ? 'Contributions inconnues' : '${a.contributions} actions'}',
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      );
    },
  );
}
