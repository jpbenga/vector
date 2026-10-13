import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/domain/compact_match_data.dart';
import '../../../core/theme/app_components.dart';
import '../../../core/widgets/lector_match_card.dart';
import '../../../core/widgets/lector_horizontal_transition.dart';
import '../../../core/widgets/recent_form_strip.dart';
import '../../../core/widgets/sports_asset_badge.dart';
import '../domain/generator_context.dart';
import 'generator_analysis.dart';

typedef ExplorationRead =
    Future<Map<String, dynamic>> Function(
      String action,
      Map<String, Object?> parameters,
    );

/// Prefer the model's specific explanation; legacy generic explanations fall
/// back only to an explicitly cited sporting fact, never to an inferred claim.
String generatorExplorationArgument(Map<String, dynamic> row) {
  final reason = row['reason']?.toString().trim() ?? '';
  final generic =
      reason.isEmpty ||
      reason.startsWith('Adéquation documentée') ||
      reason == 'Lecture publiée correspondant au critère.';
  if (!generic) return reason;
  final cited = generatorRows(row['favorable']);
  final evidence = generatorRows(row['evidence']);
  for (final index in row['supportingFactIndexes'] as List? ?? []) {
    if (index is int && index >= 0 && index < evidence.length) {
      cited.add(evidence[index]);
    }
  }
  if (cited.isNotEmpty) return generatorExplorationFact(cited.first, row: row);
  return reason.isEmpty ? 'Aucun argument archivé.' : reason;
}

String generatorExplorationFact(
  Map<String, dynamic> fact, {
  Map<String, dynamic>? row,
}) {
  final text = fact['text']?.toString() ?? fact['label']?.toString() ?? '';
  if (fact['family'] == 'form' && fact['source'] == 'scenario') {
    final form = generatorMap(row?['form']);
    if (row?['sport'] == 'football') {
      for (final side in ['home', 'away']) {
        final team = generatorMap(form[side]),
            results = generatorRows(team['results']);
        if (team['teamId']?.toString() != fact['subject']?.toString() ||
            team['state'] == 'unverified' ||
            results.isEmpty ||
            !results.every((r) => ['W', 'D', 'L'].contains(r['result']))) {
          continue;
        }
        final points = results.fold<int>(
          0,
          (n, r) =>
              n +
              (r['result'] == 'W'
                  ? 3
                  : r['result'] == 'D'
                  ? 1
                  : 0),
        );
        return '${row?[side]} : $points/${results.length * 3} points sur ${results.length} matchs publiés.';
      }
    }

    for (final marker in ['. Source :', '. [']) {
      final index = text.indexOf(marker);
      if (index >= 0) return text.substring(0, index + 1);
    }
  }
  return text;
}

/// An archived preparation. Comparison selection is local and never changes
/// Shortlist membership. Reads and explanations do not submit a model request.
class GeneratorExplorationResult extends StatefulWidget {
  const GeneratorExplorationResult({
    required this.report,
    required this.read,
    required this.onAction,
    required this.onOpenMatch,
    this.busy = false,
    super.key,
  });
  final Map<String, dynamic> report;
  final ExplorationRead read;
  final void Function(String evaluationId, String mode) onAction;
  final ValueChanged<Map<String, dynamic>> onOpenMatch;
  final bool busy;
  @override
  State<GeneratorExplorationResult> createState() =>
      _GeneratorExplorationResultState();
}

class _GeneratorExplorationResultState
    extends State<GeneratorExplorationResult> {
  final _selected = <String>{};
  List<Map<String, dynamic>> _extra = [];
  int? _next;
  bool _loading = false, _expanded = false;
  String? _error;
  Map<String, dynamic>? _archive;
  bool _hydrating = false;
  Map<String, dynamic> get report => _archive ?? widget.report;

  @override
  void initState() {
    super.initState();
    if (widget.report['observations'] is! List) _hydrateArchive();
  }

  Future<void> _hydrateArchive() async {
    final originalId = id;
    setState(() {
      _hydrating = true;
      _error = null;
    });
    try {
      final data = await widget.read('exploration_read', {
        'evaluationId': originalId,
        'offset': 0,
        'limit': 1,
      });
      if (mounted && id == originalId) setState(() => _archive = data);
    } on Object {
      if (mounted && id == originalId) {
        setState(
          () => _error =
              'Les observations archivées sont indisponibles. Réessayez leur consultation.',
        );
      }
    } finally {
      if (mounted && id == originalId) setState(() => _hydrating = false);
    }
  }

  String get id => report['evaluationId'].toString();
  List<Map<String, dynamic>> get observations =>
      generatorRows(report['observations']);

  @override
  void didUpdateWidget(covariant GeneratorExplorationResult oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.report['evaluationId'] != widget.report['evaluationId']) {
      _selected.clear();
      _archive = null;
      _hydrating = false;
      _loading = false;
      _extra = [];
      _next = null;
      _expanded = false;
      _error = null;
      if (widget.report['observations'] is! List) _hydrateArchive();
    }
  }

  Future<void> _loadRows() async {
    if (_loading) return;
    final originalId = id;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.read('exploration_read', {
        'evaluationId': originalId,
        'offset': _next ?? 0,
        'limit': 40,
      });
      if (!mounted || id != originalId) return;
      setState(() {
        _extra.addAll(generatorRows(page['rows']));
        _next = page['nextOffset'] as int?;
        _expanded = true;
      });
    } on Object {
      if (mounted && id == originalId) {
        setState(
          () => _error =
              'La préparation est indisponible. Réessayez sa consultation.',
        );
      }
    } finally {
      if (mounted && id == originalId) setState(() => _loading = false);
    }
  }

  Future<void> _panel(
    String title,
    Future<Map<String, dynamic>> Function() load,
    Widget Function(Map<String, dynamic>) content,
  ) async {
    Future<Map<String, dynamic>> guardedLoad() {
      final future = Future<Map<String, dynamic>>.sync(load);
      // Subscribe before the modal animation begins, including immediate API
      // failures. FutureBuilder still receives the original error and retry.
      future.then<void>((_) {}, onError: (Object _, StackTrace _) {});
      return future;
    }

    var future = guardedLoad();
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      sheetAnimationStyle: lectorSheetAnimationStyle(context),
      builder: (context) => StatefulBuilder(
        builder: (context, setPanelState) => SizedBox(
          height: MediaQuery.sizeOf(context).height * .84,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fermer',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<Map<String, dynamic>>(
                  future: future,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Ces données archivées sont indisponibles. La préparation reste inchangée.',
                              ),
                              TextButton(
                                onPressed: () => setPanelState(() {
                                  future = guardedLoad();
                                }),
                                child: const Text('Réessayer la consultation'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                      child: content(snapshot.data!),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _proofs(Map<String, dynamic> row) => _panel(
    'Pourquoi cette rencontre ?',
    () => widget.read('exploration_explain', {
      'evaluationId': id,
      'matchKey': row['key'],
    }),
    (data) {
      final evaluation = generatorMap(data['evaluation']);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${row['home']} – ${row['away']}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            row['retained'] == true
                ? 'Retenue dans cette préparation'
                : 'Écartée de cette préparation',
          ),
          const SizedBox(height: 8),
          Text(switch (generatorMap(data['decision'])['reason']) {
            'selected' => 'Adéquation documentée au critère demandé.',
            'stable_tie_break' =>
              'Adéquation équivalente : départagée par l’ordre stable des identifiants.',
            'below_requested_count' =>
              'Classée après les rencontres retenues pour ce nombre d’observations.',
            'documented_reservations' =>
              'Des réserves documentées limitent son adéquation.',
            'insufficient_data' =>
              'Données insuffisantes pour appuyer ce critère.',
            'no_documented_fit' => 'Aucune adéquation documentée à ce critère.',
            _ => 'Cette rencontre n’a pas encore été évaluée.',
          }),
          if (row['rank'] is num)
            Text(
              'Rang ${row['rank']} parmi les rencontres évaluées.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: 8),
          Text(
            evaluation['reason']?.toString() ??
                row['reason']?.toString() ??
                'Rencontre non évaluée.',
          ),
          _facts('Preuves archivées', generatorRows(data['evidence'])),
          _form(row),
          for (final side in ['home', 'away'])
            for (final result in generatorRows(
              generatorMap(generatorMap(row['form'])[side])['results'],
            ))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${row[side]} · ${_date(result['playedAt'])} · ${result['opponent'] ?? 'Adversaire non publié'}'
                  '${result['goalsFor'] != null && result['goalsAgainst'] != null ? ' · ${result['goalsFor']}–${result['goalsAgainst']}' : ''}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          _strings('Limites', evaluation['limitations']),
        ],
      );
    },
  );

  void _compare() => _panel(
    'Comparer la préparation',
    () => widget.read('exploration_compare', {
      'evaluationId': id,
      'matchKeys': _selected.toList(),
    }),
    (data) => _comparisonMatrix(data),
  );

  Widget _comparisonMatrix(Map<String, dynamic> data) {
    final items = generatorRows(data['comparisons']);
    final paired = items.length == 2;
    final labels = [
      'Dynamique',
      'Arguments favorables',
      'Contradictions',
      'Qualité des données',
      'Pertinence pour le critère demandé',
    ];
    Widget identity(Map<String, dynamic> item) {
      final match = generatorMap(item['match']);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final side in ['home', 'away'])
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  SportsAssetBadge(
                    imageUrl: match['${side}Logo']?.toString(),
                    size: 20,
                    fallbackLabel: match[side]?.toString() ?? '',
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      match[side]?.toString() ?? 'Équipe non publiée',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
            ),
          Text(
            match['competition']?.toString() ?? '',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: context.textColors.secondary,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          generatorMap(data['criterion'])['criteria']?.toString() ?? '',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Text(
          'Faits archivés · ${items.length} rencontres',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.textColors.secondary),
        ),
        const SizedBox(height: 14),
        if (paired)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: identity(items[0])),
              const SizedBox(width: 16),
              Expanded(child: identity(items[1])),
            ],
          ),
        for (final label in labels) ...[
          _heading(label),
          if (paired)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _comparisonCell(label, items[0])),
                  const SizedBox(width: 8),
                  VerticalDivider(width: 1, color: context.surfaces.border),
                  const SizedBox(width: 8),
                  Expanded(child: _comparisonCell(label, items[1])),
                ],
              ),
            )
          else
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${generatorMap(item['match'])['home']} – ${generatorMap(item['match'])['away']}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: context.brand.accent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _comparisonCell(label, item),
                  ],
                ),
              ),
          Divider(height: 16, color: context.surfaces.border),
        ],
      ],
    );
  }

  Widget _comparisonCell(String label, Map<String, dynamic> item) {
    final facts = generatorRows(
      item[label == 'Contradictions' ? 'contradictions' : 'favorable'],
    );
    if (label == 'Dynamique') {
      final match = generatorMap(item['match']);
      final form = generatorMap(item['form']);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _form({...match, 'form': item['form']}, vertical: true),
          if (match['sport'] == 'football')
            for (final side in ['home', 'away'])
              if (generatorMap(form[side])['state'] != 'unverified' &&
                  generatorRows(
                    generatorMap(form[side])['results'],
                  ).isNotEmpty &&
                  generatorRows(
                    generatorMap(form[side])['results'],
                  ).every((r) => ['W', 'D', 'L'].contains(r['result'])))
                Builder(
                  builder: (context) {
                    final results = generatorRows(
                      generatorMap(form[side])['results'],
                    );
                    final points = results.fold<int>(
                      0,
                      (n, r) =>
                          n +
                          (r['result'] == 'W'
                              ? 3
                              : r['result'] == 'D'
                              ? 1
                              : 0),
                    );
                    return Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        '${side == 'home' ? 'Domicile' : 'Extérieur'} · $points/${results.length * 3} pts · ${results.length} matchs',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    );
                  },
                ),
        ],
      );
    }
    if (label == 'Qualité des données') {
      final missing = (item['missing'] as List? ?? [])
          .whereType<String>()
          .toList();
      final evidence = generatorRows(item['evidence']);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${evidence.length} fait${evidence.length == 1 ? '' : 's'} archivé${evidence.length == 1 ? '' : 's'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (evidence.isNotEmpty)
            Text(
              'Publication · ${_date(evidence.first['asOf'])}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          Text(
            missing.isEmpty
                ? 'Aucune limite supplémentaire documentée.'
                : missing.join('\n'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: missing.isEmpty
                  ? context.textColors.secondary
                  : context.semantic.warning,
            ),
          ),
        ],
      );
    }
    if (label == 'Pertinence pour le critère demandé') {
      final evaluation = generatorMap(item['evaluation']);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item['conclusion']?.toString() ?? 'Aucune conclusion documentée.',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 4),
          Text(
            generatorExplorationArgument({
              ...evaluation,
              'favorable': item['favorable'],
            }),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (facts.isEmpty)
          Text(
            label == 'Contradictions'
                ? 'Aucune contradiction documentée.'
                : 'Aucun argument documenté.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.textColors.secondary,
            ),
          ),
        for (final fact in facts)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              _evidenceText(
                fact,
                row: {...generatorMap(item['match']), 'form': item['form']},
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  void _changes() => _panel(
    'Ce qui a changé',
    () => widget.read('exploration_changes', {'evaluationId': id}),
    (data) {
      final scope = generatorMap(data['scope']),
          selection = generatorMap(data['selection']);
      Widget members(String title, List<Map<String, dynamic>> rows) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heading(title),
          if (rows.isEmpty)
            Text(
              'Aucune rencontre.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${row['home']} – ${row['away']}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Comparaison avec la version précédente · faits archivés',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          members('Périmètre · ajoutées', generatorRows(scope['added'])),
          members('Périmètre · retirées', generatorRows(scope['removed'])),
          _heading('Publications sportives modifiées'),
          if (generatorRows(data['publications']).isEmpty)
            const Text('Aucun fait sportif modifié.'),
          for (final change in generatorRows(data['publications']))
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              title: Text(
                '${generatorMap(change['match'])['home']} – ${generatorMap(change['match'])['away']}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              subtitle: Text(
                '${_date(change['beforeAsOf'])} → ${_date(change['afterAsOf'])}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              children: [
                if (change['available'] != true)
                  const Text('Le détail des anciens faits est indisponible.'),
                for (final field in generatorRows(change['fields']))
                  Text(
                    '${switch (field['field']) {
                      'status' => 'Statut',
                      'kickoff' => 'Horaire',
                      'competition' => 'Compétition',
                      'home' => 'Domicile',
                      'away' => 'Extérieur',
                      _ => 'Donnée',
                    }} : ${field['before']} → ${field['after']}',
                  ),
                _facts('Avant', generatorRows(change['removedFacts'])),
                if (change['beforeForm'] is Map)
                  _form({
                    ...generatorMap(change['match']),
                    'form': change['beforeForm'],
                  }, vertical: true),
                _facts('Après', generatorRows(change['addedFacts'])),
                if (change['afterForm'] is Map)
                  _form({
                    ...generatorMap(change['match']),
                    'form': change['afterForm'],
                  }, vertical: true),
              ],
            ),
          members(
            'Classement retenu · entrées',
            generatorRows(selection['entered']),
          ),
          members(
            'Classement retenu · sorties',
            generatorRows(selection['exited']),
          ),
        ],
      );
    },
  );

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 6),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
  String _evidenceText(
    Map<String, dynamic> fact, {
    Map<String, dynamic>? row,
  }) => generatorExplorationFact(fact, row: row);

  Widget _facts(String label, List<Map<String, dynamic>> facts) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _heading(label),
      if (facts.isEmpty) const Text('Aucun élément documenté.'),
      for (final fact in facts)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _evidenceText(fact),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                '${fact['label'] ?? ''} · ${_date(fact['asOf'])}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.textColors.secondary,
                ),
              ),
            ],
          ),
        ),
    ],
  );
  Widget _strings(String label, Object? source) {
    final values = source is List
        ? source.whereType<String>().toList()
        : <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(label),
        Text(
          values.isEmpty
              ? 'Aucune limite supplémentaire documentée.'
              : values.join('\n'),
        ),
      ],
    );
  }

  String _date(Object? value) {
    final at = DateTime.tryParse(value?.toString() ?? '');
    return at == null
        ? 'Date non publiée'
        : DateFormat('dd/MM · HH:mm', 'fr').format(at.toLocal());
  }

  Widget _form(Map<String, dynamic> row, {bool vertical = false}) {
    final form = generatorMap(row['form']);
    if (form.isEmpty) {
      return Text(
        'Forme non publiée',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            form['scope'] == 'competition'
                ? 'Forme · compétition'
                : 'Forme · championnat',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: context.textColors.secondary,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              for (final side in ['home', 'away'])
                SizedBox(
                  width: vertical ? double.infinity : null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SportsAssetBadge(
                        imageUrl: row['${side}Logo']?.toString(),
                        size: 18,
                        fallbackLabel: row[side]?.toString() ?? '',
                      ),
                      const SizedBox(width: 6),
                      RecentFormStrip(
                        teamName: row[side]?.toString(),
                        compact: true,
                        snapshot: RecentFormSnapshot(
                          teamId:
                              generatorMap(form[side])['teamId']?.toString() ??
                              side,
                          scope: form['scope'] == 'competition'
                              ? MatchFormScope.competition
                              : MatchFormScope.championship,
                          results: [
                            for (final result in generatorRows(
                              generatorMap(form[side])['results'],
                            ))
                              RecentFormObservation(
                                result: result['result']?.toString() ?? '',
                                playedAt: DateTime.tryParse(
                                  result['playedAt']?.toString() ?? '',
                                ),
                                fixtureId: result['fixtureId']?.toString(),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _teamForm(Map<String, dynamic> row, String side) {
    final form = generatorMap(row['form']);
    return RecentFormStrip(
      teamName: row[side]?.toString(),
      compact: true,
      snapshot: RecentFormSnapshot(
        teamId: generatorMap(form[side])['teamId']?.toString() ?? side,
        scope: form['scope'] == 'competition'
            ? MatchFormScope.competition
            : MatchFormScope.championship,
        results: [
          for (final result in generatorRows(
            generatorMap(form[side])['results'],
          ))
            RecentFormObservation(
              result: result['result']?.toString() ?? '',
              playedAt: DateTime.tryParse(result['playedAt']?.toString() ?? ''),
              fixtureId: result['fixtureId']?.toString(),
            ),
        ],
      ),
    );
  }

  Widget _observation(Map<String, dynamic> row) {
    final key = row['key'].toString(), selected = _selected.contains(key);
    final reserve = generatorRows(row['contradictions']);
    final limits = row['limitations'] as List? ?? [];
    final kickoff = DateTime.tryParse(row['kickoff']?.toString() ?? '');
    final status = switch (row['status']) {
      'NS' || 'scheduled' || 'upcoming' =>
        kickoff == null
            ? 'À venir'
            : DateFormat('HH:mm', 'fr').format(kickoff.toLocal()),
      'FT' || 'AET' || 'PEN' || 'finished' => 'Terminé',
      '1H' || '2H' || 'HT' || 'live' => 'En direct',
      _ => row['status']?.toString() ?? 'À confirmer',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: LectorMatchCardFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (row['rank'] is num)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      '${row['rank']}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: context.brand.accent,
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(
                    row['competition']?.toString() ?? '',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: context.textColors.secondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(status, style: Theme.of(context).textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Checkbox(
                  value: selected,
                  semanticLabel:
                      'Comparer ${row['home']} contre ${row['away']}',
                  onChanged: _selected.length >= 10 && !selected
                      ? null
                      : (_) => setState(() {
                          selected ? _selected.remove(key) : _selected.add(key);
                        }),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final side in ['home', 'away'])
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              SportsAssetBadge(
                                imageUrl: row['${side}Logo']?.toString(),
                                size: 24,
                                fallbackLabel: row[side]?.toString() ?? '',
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Tooltip(
                                      message: row[side]?.toString() ?? '',
                                      child: Text(
                                        row[side]?.toString() ??
                                            'Équipe non publiée',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleSmall,
                                      ),
                                    ),
                                    _teamForm(row, side),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Ouvrir la fiche match',
                  onPressed: () => widget.onOpenMatch({
                    ...row,
                    'matchId': row['sport'] == 'football'
                        ? 'api-fixture-${row['id']}'
                        : row['id'],
                  }),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            Text(
              generatorMap(row['form'])['scope'] == 'competition'
                  ? 'Forme · compétition'
                  : 'Forme · championnat',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.textColors.secondary,
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    generatorExplorationArgument(row),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Voir les preuves',
                  onPressed: widget.busy ? null : () => _proofs(row),
                  icon: const Icon(Icons.fact_check_outlined, size: 18),
                ),
              ],
            ),
            if (reserve.isNotEmpty || limits.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 14,
                      color: context.semantic.warning,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        reserve.isNotEmpty
                            ? _evidenceText(reserve.first)
                            : limits.first.toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: context.textColors.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final coverage = generatorMap(report['coverage']),
        criterion = generatorMap(report['criterion']);
    final version = generatorMap(report['version']);
    final complete = coverage['complete'] == true;
    final available =
        coverage['expected'] is num && (coverage['expected'] as num) > 0;
    final changed = version['changedKeys'] as List? ?? [];
    final added = version['addedKeys'] as List? ?? [],
        removed = version['removedKeys'] as List? ?? [];
    final stale = report['stale'] == true;
    final all = _expanded ? _extra : observations;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 6),
        Tooltip(
          message:
              '${generatorAnalysisScope(criterion)} · ${criterion['criteria'] ?? 'Critère non archivé'}',
          child: Text(
            '${generatorAnalysisScope(criterion)} · ${criterion['criteria'] ?? 'Critère non archivé'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '${coverage['evaluated'] ?? '—'} / ${coverage['expected'] ?? '—'} évaluées · ${report['observations'] is List ? observations.length : (report['selectedKeys'] as List? ?? []).length} retenues',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 3),
        Text(
          '${!available
              ? 'Sans données'
              : complete
              ? 'Complète'
              : 'Partielle'} · ${stale ? 'Archive' : 'Données'} du ${_date(report['dataAsOf'])}',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: context.textColors.secondary),
        ),
        Row(
          children: [
            IconButton(
              tooltip: 'Voir la préparation initiale',
              icon: const Icon(Icons.history, size: 20),
              onPressed: widget.busy
                  ? null
                  : () => _panel(
                      'Préparation initiale',
                      () => widget.read('exploration_read', {
                        'evaluationId': version['rootId'] ?? id,
                        'offset': 0,
                        'limit': 40,
                      }),
                      (data) => GeneratorExplorationResult(
                        report: data,
                        read: widget.read,
                        onAction: widget.onAction,
                        onOpenMatch: widget.onOpenMatch,
                        busy: widget.busy,
                      ),
                    ),
            ),
            TextButton.icon(
              onPressed: widget.busy
                  ? null
                  : () => widget.onAction(id, 'refresh'),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Actualiser'),
            ),
            if (!complete)
              TextButton.icon(
                onPressed: widget.busy
                    ? null
                    : () => widget.onAction(id, 'resume'),
                icon: const Icon(Icons.play_arrow_outlined, size: 18),
                label: const Text('Reprendre'),
              ),
          ],
        ),
        if (version['parentId'] != null) ...[
          Text(
            version['mode'] == 'refresh'
                ? 'Préparation actualisée'
                : 'Préparation reprise',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Périmètre · +${added.length} / −${removed.length} rencontres',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            'Publications · ${changed.length} rencontre${changed.length == 1 ? '' : 's'} modifiée${changed.length == 1 ? '' : 's'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            'Classement retenu · +${(version['selectedAddedKeys'] as List? ?? []).length} / −${(version['selectedRemovedKeys'] as List? ?? []).length}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.busy ? null : _changes,
              icon: const Icon(Icons.difference_outlined, size: 18),
              label: const Text('Voir les changements'),
            ),
          ),
        ],
        Divider(height: 10, color: context.surfaces.border),
        if (_hydrating)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text('Consultation de la préparation archivée…'),
          ),
        if (!_hydrating && all.isEmpty && report['observations'] is List)
          Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              available
                  ? 'Aucune observation défendable pour ce critère. Consultez les rencontres examinées et leurs limites.'
                  : 'Aucune rencontre disponible dans ce périmètre.',
            ),
          ),
        for (final row in all) _observation(row),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          children: [
            Text(
              '${_selected.length} pour comparaison',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            OutlinedButton.icon(
              onPressed: _selected.length < 2 || widget.busy ? null : _compare,
              icon: const Icon(Icons.compare_arrows),
              label: const Text('Comparer'),
            ),
            if (_selected.isNotEmpty)
              TextButton(
                onPressed: () => setState(_selected.clear),
                child: const Text('Désélectionner'),
              ),
          ],
        ),
        TextButton(
          onPressed: _loading || widget.busy
              ? null
              : () {
                  if (_expanded && _next == null) {
                    setState(() => _expanded = false);
                    return;
                  }
                  if (_extra.isNotEmpty && !_expanded) {
                    setState(() => _expanded = true);
                    return;
                  }
                  _loadRows();
                },
          child: Text(
            _loading
                ? 'Consultation…'
                : _expanded && _next == null
                ? 'Voir seulement les retenues'
                : _expanded
                ? 'Voir les rencontres suivantes'
                : 'Voir aussi les rencontres écartées',
          ),
        ),
        if (report['observations'] is! List && !_hydrating)
          TextButton(
            onPressed: _hydrateArchive,
            child: const Text('Retrouver les observations archivées'),
          ),
        if (_error != null)
          Text(
            _error!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.semantic.warning),
          ),
        for (final limit in report['limitations'] as List? ?? [])
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              limit.toString(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}
