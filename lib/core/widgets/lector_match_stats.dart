import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_components.dart';
import '../theme/app_radius.dart';

class LectorMatchStatistic {
  const LectorMatchStatistic({required this.label, this.first, this.second});
  final String label;
  final String? first, second;
}

/// The sport adapter orders teams and supplies current-match facts only.
class LectorMatchStats extends StatelessWidget {
  const LectorMatchStats({
    required this.firstTeam,
    required this.secondTeam,
    required this.rows,
    this.capturedAt,
    this.scoreLabel,
    this.isLive = false,
    super.key,
  });
  final String firstTeam, secondTeam;
  final String? scoreLabel;
  final List<LectorMatchStatistic> rows;
  final DateTime? capturedAt;
  final bool isLive;
  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('current-match-stats'),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: context.surfaces.surface,
      border: Border.all(color: context.surfaces.border),
      borderRadius: BorderRadius.circular(AppRadius.card),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Statistiques du match',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                firstTeam,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            if (scoreLabel != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  scoreLabel!,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            Expanded(
              child: Text(
                secondTeam,
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        if (capturedAt != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Statistiques reçues à ${DateFormat('HH:mm').format(capturedAt!.toLocal())}',
              style: TextStyle(
                color: context.textColors.secondary,
                fontSize: 12,
              ),
            ),
          ),
        if (isLive &&
            capturedAt != null &&
            DateTime.now().difference(capturedAt!) > const Duration(minutes: 3))
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Statistiques en attente d’actualisation',
              style: TextStyle(color: context.semantic.warning),
            ),
          ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          Text(
            'Les statistiques de cette rencontre ne sont pas encore disponibles.',
            style: TextStyle(color: context.textColors.secondary),
          ),
        for (final row in rows) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  child: Text(
                    row.first ?? '—',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                Expanded(child: Text(row.label, textAlign: TextAlign.center)),
                SizedBox(
                  width: 48,
                  child: Text(
                    row.second ?? '—',
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.surfaces.border),
        ],
      ],
    ),
  );
}
