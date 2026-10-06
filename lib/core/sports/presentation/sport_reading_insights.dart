import '../../theme/app_colors.dart';
import 'package:flutter/material.dart';
import '../../theme/app_components.dart';
import '../../widgets/lector_reading_pill.dart';
import '../../widgets/lector_glass_card.dart';
import '../../widgets/lector_match_insights.dart';
import '../domain/sport_module.dart';

/// Shared evidence presentation. No thresholds or sport algorithms in widgets.
class SportReadingInsights extends StatelessWidget {
  const SportReadingInsights({
    required this.readings,
    required this.definition,
    required this.subjectName,
    this.detailed = false,
    this.subjectLogoUrl,
    super.key,
  });
  final List<SportReadingAssessment> readings;
  final SportModuleDefinition definition;
  final String Function(SportReadingAssessment) subjectName;
  final bool detailed;
  final String? Function(SportReadingAssessment)? subjectLogoUrl;

  @override
  Widget build(BuildContext context) {
    final detected = readings
        .where((r) => r.status == SportReadingStatus.detected)
        .toList();
    String label(SportReadingAssessment r) {
      final base = definition.readings.firstWhere((d) => d.id == r.id).label;
      return r.id == 'head_to_head_dominance'
          ? '$base · ${r.evidence['competitionKind'] == 'cup' ? 'Coupes' : 'Championnat'}'
          : base;
    }

    if (!detailed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (detected.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 5,
              children: [
                for (final r in detected)
                  LectorReadingPill(
                    label:
                        '${label(r)}${(r.evidence['consecutiveResults'] ?? r.evidence['consecutiveWins']) == null ? '' : ' · ${r.evidence['exact'] == true ? '' : '≥'}${(r.evidence['consecutiveResults'] ?? r.evidence['consecutiveWins'])}'} · ${subjectName(r)}',
                    style: context.opportunities.badgeFor(
                      r.id,
                      variant: AppReadingBadgeVariant.soft,
                    ),
                    icon:
                        {
                          'negative_streak',
                          'weak_home_team',
                          'weak_away_team',
                        }.contains(r.id)
                        ? Icons.trending_down_rounded
                        : Icons.trending_up_rounded,
                  ),
              ],
            ),
          if (detected.isEmpty && readings.isNotEmpty)
            Text(
              readings.every(
                    (r) => r.status == SportReadingStatus.insufficientData,
                  )
                  ? 'Données insuffisantes pour vos lectures.'
                  : 'Aucune de vos lectures détectée.',
            ),
        ],
      );
    }
    return LectorGlassCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, color: context.brand.accent),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VOS LECTURES',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                Text(
                  '${detected.length} lecture${detected.length == 1 ? '' : 's'} détectée${detected.length == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.textColors.secondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _showDetails(context),
            child: const Text('Voir le détail'),
          ),
        ],
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.transparent,
      barrierColor: context.surfaces.scrim.withValues(alpha: .56),
      builder: (context) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .92,
        ),
        child: LectorAnalysisSheet(
          children: [
            if (readings.isEmpty)
              Text(
                'Configurez vos lectures ${definition.sport.label.toLowerCase()} pour personnaliser cette analyse.',
              ),
            for (final status in [
              SportReadingStatus.detected,
              SportReadingStatus.notDetected,
              SportReadingStatus.insufficientData,
            ])
              if (readings.any((r) => r.status == status)) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    switch (status) {
                      SportReadingStatus.detected => 'Autres lectures du match',
                      SportReadingStatus.notDetected =>
                        'Lectures non détectées',
                      SportReadingStatus.insufficientData =>
                        'Limites des données',
                    },
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: context.brand.accent,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                for (final subject
                    in readings
                        .where((r) => r.status == status)
                        .map((r) => r.subject)
                        .toSet()) ...[
                  LectorEvidenceTeamCard(
                    analysis: true,
                    title: subjectName(
                      readings.firstWhere((r) => r.subject == subject),
                    ),
                    logoUrl: subjectLogoUrl?.call(
                      readings.firstWhere((r) => r.subject == subject),
                    ),
                    children: [
                      for (final r in readings.where(
                        (r) => r.subject == subject && r.status == status,
                      )) ...[
                        LectorEvidenceRow(
                          analysis: true,
                          title: definition.readings
                              .firstWhere((d) => d.id == r.id)
                              .label,
                          icon:
                              {
                                'negative_streak',
                                'weak_home_team',
                                'weak_away_team',
                              }.contains(r.id)
                              ? Icons.trending_down_rounded
                              : r.id == 'standing_advantage'
                              ? Icons.bar_chart_rounded
                              : Icons.trending_up_rounded,
                          color: status == SportReadingStatus.detected
                              ? {
                                      'negative_streak',
                                      'weak_home_team',
                                      'weak_away_team',
                                    }.contains(r.id)
                                    ? context.semantic.error
                                    : context.semantic.success
                              : context.textColors.secondary,
                          evidence: Text(
                            r.explanation,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: context.textColors.secondary,
                                  height: 1.25,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        if (r.sampleSize > 0)
                          Text(
                            'Échantillon : ${r.sampleSize} matchs',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: context.textColors.secondary),
                          ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ],
          ],
        ),
      ),
    );
  }
}
