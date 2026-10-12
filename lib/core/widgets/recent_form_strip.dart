import 'package:flutter/material.dart';
import '../domain/compact_match_data.dart';
import '../theme/app_components.dart';
import 'lector_radar.dart';

/// The same chronological cells and semantic colors as Form Radar.
class RecentFormStrip extends StatelessWidget {
  const RecentFormStrip({required this.snapshot, this.teamName, super.key});
  final RecentFormSnapshot snapshot;
  final String? teamName;
  @override
  Widget build(BuildContext context) {
    final results = snapshot.latest;
    final summary = results
        .map(
          (r) => switch (r.code) {
            'W' => 'victoire',
            'D' => 'nul',
            'L' => 'défaite',
            _ => 'résultat inconnu',
          },
        )
        .join(', ');
    return Semantics(
      label:
          'Forme ${teamName ?? snapshot.teamId}, du plus ancien au plus récent : ${summary.isEmpty ? 'indisponible' : summary}',
      child: results.isEmpty
          ? Text(
              'Indisponible',
              style: TextStyle(
                fontSize: 10,
                color: context.textColors.secondary,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                LectorFormResultStrip(
                  results: results.map((r) => r.code).toList(growable: false),
                ),
                if (results.length < 5) ...[
                  const SizedBox(width: 4),
                  Text(
                    '${results.length}/5',
                    style: TextStyle(
                      fontSize: 9,
                      color: context.textColors.secondary,
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
