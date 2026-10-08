import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_components.dart';
import '../../../core/widgets/lector_match_card.dart';
import '../../../core/widgets/sports_asset_badge.dart';
import '../domain/generator_context.dart';

String generatorAnalysisScope(Map<String, dynamic> data) {
  final date = DateTime.tryParse(data['date']?.toString() ?? '');
  final view = switch (data['view']) {
    'profile' => 'Pour moi',
    'radar' => 'Radar',
    'all' => 'Tous',
    _ => 'Pour moi + Radar',
  };
  final sports = (data['sports'] as List? ?? [])
      .map((s) => s == 'hockey' ? 'Hockey' : 'Football')
      .join(' + ');
  return [
    sports,
    if (date != null) DateFormat('EEE d MMM', 'fr').format(date),
    view,
  ].where((s) => s.isNotEmpty).join(' · ');
}

/// Stages come from actual server operations. The optional summary is supplied
/// by the model API; no private chain of thought or simulated steps are shown.
class GeneratorAnalysisProgress extends StatelessWidget {
  const GeneratorAnalysisProgress({
    required this.phase,
    required this.progress,
    super.key,
  });
  final String phase;
  final Map<String, dynamic> progress;
  @override
  Widget build(BuildContext context) {
    final scope = generatorMap(progress['context']);
    final steps = generatorRows(progress['steps']);
    final summary = progress['summary']?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: LectorMatchCardFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              liveRegion: true,
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.brand.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      phase,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: context.brand.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (scope.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                generatorAnalysisScope(scope),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                '${scope['matchCount'] ?? 0} rencontres dans ce périmètre',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (steps.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final step in steps.take(8))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        steps.last == step
                            ? Icons.more_horiz
                            : Icons.check_rounded,
                        size: 16,
                        color: context.brand.accent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          step['detail']?.toString() ?? '',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            if (summary.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Résumé de l’analyse en cours'),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      summary,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class GeneratorAnalysisResult extends StatelessWidget {
  const GeneratorAnalysisResult({
    required this.analysis,
    required this.onInspect,
    super.key,
  });
  final Map<String, dynamic> analysis;
  final ValueChanged<Map<String, dynamic>> onInspect;
  @override
  Widget build(BuildContext context) {
    final scope = generatorMap(analysis['context']);
    final choices = generatorRows(analysis['selections']);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '${generatorAnalysisScope(scope)}\n${scope['matchCount'] ?? 0} rencontres examinables · ${choices.length} choix à examiner',
            style: theme.textTheme.bodySmall,
          ),
        ),
        for (final (index, choice) in choices.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: LectorMatchCardFrame(
              child: InkWell(
                onTap: () => onInspect(generatorMap(choice['candidate'])),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${index + 1}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: context.brand.accent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            generatorMap(
                                  choice['candidate'],
                                )['competition']?.toString() ??
                                '',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        Icon(Icons.chevron_right, color: context.brand.accent),
                      ],
                    ),
                    const SizedBox(height: 10),
                    for (final side in ['home', 'away'])
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            SportsAssetBadge(
                              size: 28,
                              imageUrl: generatorMap(
                                choice['candidate'],
                              )['${side}Logo']?.toString(),
                              fallbackLabel: '',
                              icon: Icons.shield_outlined,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                generatorMap(
                                      choice['candidate'],
                                    )[side]?.toString() ??
                                    '',
                                style: theme.textTheme.titleSmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            generatorMap(
                                  choice['candidate'],
                                )['selection']?.toString() ??
                                '',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: context.brand.accent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          (generatorMap(choice['candidate'])['odds'] as num?)
                                  ?.toStringAsFixed(2) ??
                              '',
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      choice['reason']?.toString() ?? '',
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (choice['vigilance']?.toString().isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      Text(
                        'À considérer : ${choice['vigilance']}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Voir les lectures et les données',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.brand.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if ((analysis['limitations'] as List? ?? []).isNotEmpty)
          ExpansionTile(
            title: const Text('Données et limites de cette analyse'),
            children: [
              for (final limit in analysis['limitations'] as List)
                ListTile(
                  dense: true,
                  title: Text(
                    limit.toString(),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
