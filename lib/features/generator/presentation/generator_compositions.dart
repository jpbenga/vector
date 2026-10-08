import 'package:flutter/material.dart';
import '../../../core/theme/app_components.dart';
import '../../../core/theme/app_radius.dart';
import '../domain/generator_context.dart';
import 'generator_formatters.dart';

String generatorApproach(Object? value) => switch (value) {
  'fewer_matches' => 'Moins de rencontres',
  'other_markets' => 'Autres marchés',
  'different_matches' => 'Autres rencontres',
  _ => 'Arguments complémentaires',
};

class GeneratorCompositionOptions extends StatelessWidget {
  const GeneratorCompositionOptions({
    required this.tickets,
    required this.onInspect,
    required this.onChoose,
    this.selectedId,
    super.key,
  });
  final List<Map<String, dynamic>> tickets;
  final String? selectedId;
  final ValueChanged<Map<String, dynamic>> onInspect;
  final ValueChanged<Map<String, dynamic>>? onChoose;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 8),
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
          'Compositions à examiner',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Plusieurs approches pour une même mise. Choisissez une seule composition.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.textColors.secondary),
        ),
        const SizedBox(height: 10),
        for (final entry in tickets.indexed) ...[
          if (entry.$1 > 0) const Divider(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: context.brand.accent.withValues(alpha: .12),
                child: Text(
                  String.fromCharCode(65 + entry.$1),
                  style: TextStyle(color: context.brand.accent),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      generatorApproach(
                        generatorMap(entry.$2['workshop'])['approach'],
                      ),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${generatorRows(entry.$2['picks']).length} sélections · cote ${generatorOdds(entry.$2['totalOdds'])}',
                    ),
                    Text(
                      'Retour potentiel ${generatorMoney(entry.$2['returnTotal'])}',
                      style: TextStyle(
                        color: context.brand.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: () => onInspect(entry.$2),
                          child: const Text('Examiner'),
                        ),
                        if (entry.$2['id'] == selectedId)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('Composition retenue'),
                          )
                        else if (onChoose != null)
                          TextButton(
                            onPressed: () => onChoose!(entry.$2),
                            child: const Text('Retenir cette composition'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

class GeneratorCompositionAnalysis extends StatelessWidget {
  const GeneratorCompositionAnalysis({required this.ticket, super.key});
  final Map<String, dynamic> ticket;
  @override
  Widget build(BuildContext context) {
    final workshop = generatorMap(ticket['workshop']);
    if (workshop.isEmpty) return const SizedBox.shrink();
    final notes = generatorRows(workshop['notes']);
    final comparison = generatorMap(workshop['comparison']);
    final before = generatorRows(generatorMap(workshop['comparedTo'])['picks']);
    final after = generatorRows(ticket['picks']);
    String name(Object? id, bool original) {
      final candidates = original ? before : after;
      final match = candidates.where((p) => p['id'] == id).firstOrNull;
      if (match == null) return 'Sélection';
      return '${original ? match['match'] : '${match['home']} — ${match['away']}'} : ${match['selection']}';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: context.surfaces.surface,
        border: Border.all(color: context.surfaces.border),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: ExpansionTile(
        title: const Text('Pourquoi cette composition ?'),
        leading: Icon(
          Icons.compare_arrows_rounded,
          color: context.brand.accent,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        children: [
          for (final note in notes)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    note['code'] == 'support'
                        ? Icons.menu_book_outlined
                        : Icons.info_outline_rounded,
                    size: 18,
                    color: note['code'] == 'support'
                        ? context.brand.accent
                        : context.semantic.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(note['text']?.toString() ?? '')),
                ],
              ),
            ),
          if (comparison.isNotEmpty) ...[
            const Divider(),
            Text(
              'Ce qui change',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            for (final id in comparison['removed'] as List? ?? [])
              _Change(label: 'Retirée', text: name(id, true)),
            for (final id in comparison['added'] as List? ?? [])
              _Change(label: 'Ajoutée', text: name(id, false)),
            for (final item in generatorRows(comparison['replaced']))
              _Change(
                label: 'Marché changé',
                text:
                    '${name(item['before'], true)}\n→ ${name(item['after'], false)}',
              ),
            Text(
              '${comparison['sharedFixtures'] ?? 0} rencontres communes avec la composition de référence.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _Change extends StatelessWidget {
  const _Change({required this.label, required this.text});
  final String label, text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: context.brand.accent),
          ),
        ),
        Align(alignment: Alignment.centerLeft, child: Text(text)),
      ],
    ),
  );
}
