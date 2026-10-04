import 'package:flutter/material.dart';

import '../../../core/sports/domain/sport.dart';
import '../../../core/sports/domain/sport_module.dart';
import '../../../core/theme/app_components.dart';
import '../../../core/widgets/lector_brand_mark.dart';
import '../../../core/widgets/lector_responsive_layout.dart';
import '../../sports/domain/sport_module_registry.dart';

/// A browsable preparation workspace, with no fabricated production fixtures.
class HockeyWorkspace extends StatefulWidget {
  const HockeyWorkspace({this.sport = SportId.hockey, super.key});
  final SportId sport;

  @override
  State<HockeyWorkspace> createState() => _HockeyWorkspaceState();
}

class _HockeyWorkspaceState extends State<HockeyWorkspace> {
  int _section = 0;

  @override
  Widget build(BuildContext context) {
    final module = SportModuleRegistry.forSport(widget.sport);
    return ListView(
      key: const ValueKey('hockey-workspace'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
      children: [
        LectorContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const LectorBrandMark(size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Lector · ${widget.sport.label}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.sport == SportId.hockey
                    ? 'Les mêmes principes d’analyse, adaptés au hockey.'
                    : 'Cette discipline sera intégrée dans un prochain module.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: context.brand.accent,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'En préparation',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Les rencontres apparaîtront après la connexion '
                              'd’une source de données pour cette discipline.',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.sport == SportId.hockey) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (index, label) in [
                      'Matchs',
                      'Lectures',
                      'Scénarios',
                    ].indexed)
                      ChoiceChip(
                        key: ValueKey('hockey-section-$index'),
                        label: Text(label),
                        selected: _section == index,
                        onSelected: (_) => setState(() => _section = index),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_section == 0)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: SizedBox(
                        width: double.infinity,
                        child: Column(
                          children: [
                            Icon(Icons.sports_hockey_rounded, size: 40),
                            SizedBox(height: 12),
                            Text('Aucune rencontre hockey chargée'),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (_section != 0) ...[
                  Text(
                    'Premières règles à valider',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Ces exemples expliquent les règles proposées. '
                    'Ils ne décrivent pas des matchs réels.',
                  ),
                  const SizedBox(height: 12),
                ],
                if (_section == 1)
                  for (final reading in module.readings)
                    _readingCard(context, reading),
                if (_section == 2)
                  for (final scenario in module.scenarios)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              scenario.label,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(scenario.description),
                            const SizedBox(height: 12),
                            for (final id in scenario.requiredReadingIds)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  '• ${module.readings.firstWhere((r) => r.id == id).label}',
                                ),
                              ),
                            const Text('Toutes requises pour la même équipe.'),
                          ],
                        ),
                      ),
                    ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _readingCard(BuildContext context, SportReadingDefinition reading) =>
      Card(
        child: ExpansionTile(
          key: ValueKey('hockey-reading-${reading.id}'),
          title: Text(reading.label),
          subtitle: Text(
            reading.implemented
                ? 'Règle initiale à valider'
                : 'À étudier avec les données',
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(reading.description),
            const SizedBox(height: 12),
            Text('Conditions', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(reading.condition),
            const SizedBox(height: 12),
            Text(
              'Exemple illustratif',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(reading.example),
          ],
        ),
      );
}
