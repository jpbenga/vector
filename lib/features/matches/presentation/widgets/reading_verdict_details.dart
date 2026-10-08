import 'package:flutter/material.dart';

import '../../../../core/theme/app_components.dart';
import '../../../../core/theme/app_radius.dart';
import '../../data/match_reading_bilan_repository.dart';
import '../../domain/reading_bilan_analysis.dart';

String readingVerdictLabel(String? verdict) => switch (verdict) {
  'confirmed' => 'Confirmée',
  'contradicted' => 'Contredite',
  'not_evaluable' => 'Non évaluable',
  'context_only' => 'Sans règle de résultat',
  'caution_confirmed' => 'Nuance pertinente',
  'caution_not_confirmed' => 'Nuance non confirmée',
  _ => 'En attente',
};

Color readingVerdictColor(BuildContext context, String? verdict) =>
    switch (verdict) {
      'confirmed' => context.semantic.success,
      'contradicted' => context.semantic.error,
      'not_evaluable' || 'caution_confirmed' => context.semantic.warning,
      _ => context.textColors.secondary,
    };

/// Frozen reading, explicit participant and observed result, shared by the
/// match sheet and the global Bilan. This widget does not recompute verdicts.
class ReadingVerdictDetails extends StatelessWidget {
  const ReadingVerdictDetails({required this.entry, super.key});
  final MatchReadingBilanEntry entry;

  @override
  Widget build(BuildContext context) {
    final subject = switch (entry.subjectSide) {
      'home' => '${entry.homeTeamName ?? 'Équipe à domicile'} · domicile',
      'away' => '${entry.awayTeamName ?? 'Équipe à l’extérieur'} · extérieur',
      _ => 'Match entier',
    };
    final color = readingVerdictColor(context, entry.verdict);
    final evidence = entry.evidence
        .map((e) => e['label']?.toString().trim() ?? '')
        .where((text) => text.isNotEmpty)
        .toSet()
        .join('\n');
    final identity = context.opportunities.readingIdentityForId(
      entry.readingId,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: context.brand.accent.withValues(alpha: .12),
                shape: BoxShape.circle,
              ),
              child: Icon(identity.icon, color: context.brand.accent, size: 23),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 5,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        entry.readingLabel,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(AppRadius.chip),
                          border: Border.all(
                            color: color.withValues(alpha: .4),
                          ),
                        ),
                        child: Text(
                          readingVerdictLabel(entry.verdict),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: color,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Concerne : $subject',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.brand.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (evidence.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      evidence,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  if (entry.sampleSize != null && entry.sampleSize! > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Échantillon : ${entry.sampleSize} matchs',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.textColors.secondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Critère : ${bilanOutcomeRuleText(entry.outcomeRule)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.textColors.secondary,
                    ),
                  ),
                  if (entry.hasResult) ...[
                    const SizedBox(height: 4),
                    Text(
                      _observedResult(entry),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.textColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String _observedResult(MatchReadingBilanEntry entry) {
  if (!const {'home', 'away'}.contains(entry.subjectSide)) {
    return 'Résultat : ${entry.homeGoals} – ${entry.awayGoals}';
  }
  final home = entry.subjectSide == 'home';
  final name = home ? entry.homeTeamName : entry.awayTeamName;
  final scored = home ? entry.homeGoals! : entry.awayGoals!;
  final conceded = home ? entry.awayGoals! : entry.homeGoals!;
  final result = scored > conceded
      ? 'gagne'
      : scored < conceded
      ? 'perd'
      : 'fait match nul';
  return 'Résultat : ${name ?? 'L’équipe concernée'} $result $scored–$conceded';
}
