import 'package:flutter/material.dart';

import '../../../core/theme/app_components.dart';
import '../domain/operations_models.dart';
import 'operations_issue_card.dart';

class OperationsHistory extends StatefulWidget {
  const OperationsHistory({
    super.key,
    required this.data,
    required this.onCycle,
  });
  final OpsOverview data;
  final ValueChanged<String> onCycle;
  @override
  State<OperationsHistory> createState() => _OperationsHistoryState();
}

class _OperationsHistoryState extends State<OperationsHistory> {
  late String _source;
  String _search = '';
  String? _mobileResult;
  final _pages = <String, int>{};
  final _searchController = TextEditingController();
  static const _pageSize = 10;
  @override
  void initState() {
    super.initState();
    _source = widget.data.cycles.isEmpty ? 'runs' : 'cycles';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _name(Map<String, dynamic> row) => _source == 'runs'
      ? (row['league_ids'] as List<Object?>? ?? [])
            .whereType<num>()
            .map((id) => widget.data.competitionName(id.toInt()))
            .join(', ')
      : '${row[_source == 'cycles' ? 'label' : 'message'] ?? ''}';

  String _result(Map<String, dynamic> row) {
    if (_source == 'cycles') {
      if ((row['failed'] as num? ?? 0) > 0) return 'failed';
      final total = row['total'] as num? ?? 0;
      return total > 0 && row['succeeded'] == total ? 'succeeded' : 'other';
    }
    if (_source == 'runs') {
      if (['failed', 'partial'].contains(row['status']) ||
          '${row['error_message'] ?? ''}'.isNotEmpty) {
        return 'failed';
      }
      return row['status'] == 'succeeded' ? 'succeeded' : 'other';
    }
    return ['dispatch_error', 'failed', 'timeout'].contains(row['kind'])
        ? 'failed'
        : 'other';
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final all = switch (_source) {
      'cycles' => data.cycles,
      'runs' => data.legacy,
      _ => opsRows(data.json['audit']),
    };
    final rows = all
        .where(
          (row) => '${_name(row)} ${row['error_message'] ?? ''}'
              .toLowerCase()
              .contains(_search.toLowerCase()),
        )
        .toList();
    final failed = rows.where((row) => _result(row) == 'failed').toList();
    final succeeded = rows.where((row) => _result(row) == 'succeeded').toList();
    final other = rows.where((row) => _result(row) == 'other').toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Historique des exécutions',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in [
                      ('cycles', 'Cycles de pilotage', data.cycles.length),
                      (
                        'runs',
                        'Batchs lancés hors pilotage',
                        data.legacy.length,
                      ),
                      (
                        'audit',
                        'Journal des commandes',
                        opsRows(data.json['audit']).length,
                      ),
                    ])
                      ChoiceChip(
                        label: Text('${item.$2} (${item.$3})'),
                        selected: _source == item.$1,
                        onSelected: (_) => setState(() {
                          _source = item.$1;
                          _pages.clear();
                          _search = '';
                          _searchController.clear();
                          _mobileResult = null;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(switch (_source) {
                  'runs' =>
                    'Batchs lancés directement par les tâches programmées dans Supabase ou le terminal. Les 100 plus récents sont consultables ici, sans commande d’interruption.',
                  'cycles' =>
                    'Les 50 derniers cycles. Un cycle est réussi lorsque tous ses batchs sont réussis. Un cycle avec au moins un échec figure dans « En erreur », même si d’autres batchs continuent.',
                  _ =>
                    'Les 100 dernières commandes : lancements, pauses, interruptions et changements de planification.',
                }),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Rechercher dans cet historique',
                  ),
                  onChanged: (v) => setState(() {
                    _search = v;
                    _pages.clear();
                  }),
                ),
                if (_source != 'audit')
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'Réussites et erreurs ont chacune leur liste et leur pagination. Les résultats partiels figurent dans « En erreur ».',
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_source == 'audit')
          _list(
            context,
            'audit',
            'Journal des commandes',
            rows,
            context.textColors.secondary,
          )
        else ...[
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 1000) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _list(
                        context,
                        'failed',
                        'En erreur',
                        failed,
                        context.semantic.error,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _list(
                        context,
                        'succeeded',
                        'Réussis',
                        succeeded,
                        context.semantic.success,
                      ),
                    ),
                  ],
                );
              }
              final selection =
                  _mobileResult ?? (failed.isNotEmpty ? 'failed' : 'succeeded');
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final item in [
                        (
                          'failed',
                          'En erreur',
                          failed.length,
                          context.semantic.error,
                        ),
                        (
                          'succeeded',
                          'Réussis',
                          succeeded.length,
                          context.semantic.success,
                        ),
                      ])
                        ChoiceChip(
                          avatar: Icon(
                            item.$1 == 'failed'
                                ? Icons.error_outline
                                : Icons.check_circle_outline,
                            color: item.$4,
                            size: 18,
                          ),
                          label: Text('${item.$2} (${item.$3})'),
                          selected: selection == item.$1,
                          onSelected: (_) =>
                              setState(() => _mobileResult = item.$1),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  selection == 'failed'
                      ? _list(
                          context,
                          'failed',
                          'En erreur',
                          failed,
                          context.semantic.error,
                        )
                      : _list(
                          context,
                          'succeeded',
                          'Réussis',
                          succeeded,
                          context.semantic.success,
                        ),
                ],
              );
            },
          ),
          if (other.isNotEmpty) ...[
            const SizedBox(height: 16),
            _list(
              context,
              'other',
              'En cours, en attente ou interrompus',
              other,
              context.textColors.secondary,
            ),
          ],
        ],
      ],
    );
  }

  Widget _list(
    BuildContext context,
    String group,
    String title,
    List<Map<String, dynamic>> rows,
    Color color,
  ) {
    final pages = (rows.length / _pageSize).ceil().clamp(1, 100000);
    final page = (_pages[group] ?? 0).clamp(0, pages - 1);
    final start = page * _pageSize;
    final visible = rows.skip(start).take(_pageSize).toList();
    return Builder(
      builder: (panelContext) {
        void go(int value) {
          setState(() => _pages[group] = value);
          Scrollable.ensureVisible(
            panelContext,
            alignment: 0,
            duration: const Duration(milliseconds: 200),
          );
        }

        Widget pager() => Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              rows.isEmpty
                  ? '0 résultat'
                  : '${start + 1}–${start + visible.length} sur ${rows.length} · Page ${page + 1}/$pages',
            ),
            IconButton(
              key: ValueKey('$group-previous'),
              tooltip: 'Page précédente — $title',
              onPressed: page > 0 ? () => go(page - 1) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              key: ValueKey('$group-next'),
              tooltip: 'Page suivante — $title',
              onPressed: page + 1 < pages ? () => go(page + 1) : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        );
        return Card(
          key: ValueKey('history-$group'),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '$title (${rows.length})',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 8),
                pager(),
                const Divider(height: 24),
                if (rows.isEmpty)
                  Text(
                    'Aucun résultat dans cette liste${_search.isNotEmpty ? ' pour cette recherche' : ''}.',
                  ),
                for (final row in visible)
                  Padding(
                    key: ValueKey('${_source}_${row['id']}'),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            _result(row) == 'failed'
                                ? Icons.error_outline
                                : _result(row) == 'succeeded'
                                ? Icons.check_circle_outline
                                : Icons.history,
                            color: color,
                          ),
                          title: Text(
                            _name(row).isEmpty
                                ? 'Compétition non renseignée'
                                : _name(row),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${_date(row[_source == 'runs' ? 'started_at' : 'created_at'])}${_source == 'runs' ? ' · ${opsStatus('${row['status']}')}' : ' · ${row['actor'] ?? ''}'}${_source == 'cycles' ? '\n${row['succeeded'] ?? 0}/${row['total'] ?? 0} réussis · ${row['failed'] ?? 0} erreurs · ${row['running'] ?? 0} en cours · ${row['pending'] ?? 0} en attente · ${row['cancelled'] ?? 0} interrompus' : ''}',
                          ),
                          trailing: _source == 'cycles'
                              ? const Icon(Icons.arrow_forward)
                              : null,
                          onTap: _source == 'cycles'
                              ? () => widget.onCycle('${row['id']}')
                              : null,
                        ),
                        if (_source == 'runs' && _result(row) == 'failed')
                          OperationsIssueCard(
                            message: '${row['error_message'] ?? ''}',
                          ),
                        if (_source == 'audit' && _result(row) == 'failed')
                          OperationsIssueCard(
                            message: '${row['message'] ?? ''}',
                          ),
                        const Divider(),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

String _date(Object? value) {
  final d = DateTime.tryParse('$value')?.toLocal();
  if (d == null) return 'Date non renseignée';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}
