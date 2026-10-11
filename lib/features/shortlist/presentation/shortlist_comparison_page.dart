import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/supabase/supabase_initializer.dart';
import '../../../core/theme/app_components.dart';
import '../../../core/widgets/lector_loading.dart';
import '../../../core/widgets/lector_match_card.dart';
import '../../../core/widgets/lector_responsive_layout.dart';
import '../../generator/data/generator_repository.dart';
import '../../generator/domain/generator_context.dart';
import '../application/shortlist_controller.dart';
import 'shortlist_conversation_page.dart';

class ShortlistComparisonPage extends StatefulWidget {
  const ShortlistComparisonPage({
    required this.controller,
    required this.keys,
    this.repository,
    super.key,
  });
  final ShortlistController controller;
  final List<String> keys;
  final GeneratorRepository? repository;
  @override
  State<ShortlistComparisonPage> createState() =>
      _ShortlistComparisonPageState();
}

class _ShortlistComparisonPageState extends State<ShortlistComparisonPage> {
  Map<String, dynamic>? _data;
  String? _error;
  late final String? _account = widget.controller.account;
  late final String? _session = widget.controller.active?.id;
  bool get _available =>
      _account != null &&
      _account == widget.controller.account &&
      _session == widget.controller.active?.id;
  void _changed() {
    if (!_available && mounted) {
      setState(() {
        _data = null;
        _error = 'Cette préparation n’est plus active.';
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _load();
  }

  Future<void> _load() async {
    try {
      if (!_available) throw StateError('Cette préparation n’est plus active.');
      final repository =
          widget.repository ??
          SupabaseGeneratorRepository(getIt<SupabaseInitializer>().client!);
      final session = widget.controller.active;
      if (session == null) throw StateError('La Shortlist a expiré.');
      final data = await repository.request({
        'action': 'shortlist_inspect',
        'shortlist': session.reference(widget.keys),
      });
      if (mounted && _available) setState(() => _data = data);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Bad state: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Comparer deux rencontres')),
    body: ListView(
      padding: const EdgeInsets.all(12),
      children: [
        LectorContent(
          maxWidth: 544,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Chaque rencontre garde ses deux équipes et son contexte sportif.',
              ),
              const SizedBox(height: 12),
              if (_data == null && _error == null)
                const LectorLoading(label: 'Lecture des données comparées…'),
              if (_error != null) Text(_error!),
              for (final row in generatorRows(_data?['matches'])) ...[
                LectorMatchCardFrame(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        row['competition']?.toString() ?? '',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${row['home']} — ${row['away']}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${row['sport'] == 'hockey' ? 'Hockey' : 'Football'} · ${DateTime.tryParse(row['kickoff']?.toString() ?? '') == null ? 'Horaire à confirmer' : DateFormat('EEE d MMM · HH:mm', 'fr').format(DateTime.parse(row['kickoff'].toString()).toLocal())}',
                      ),
                      const Divider(),
                      Text(
                        'Lectures et observations',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (generatorRows(row['evidence']).isEmpty)
                        const Text(
                          'Aucune lecture documentée dans la publication disponible.',
                        ),
                      for (final fact in generatorRows(row['evidence']))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Text(
                            '${fact['label'] ?? fact['id']} : ${fact['text'] ?? ''}',
                          ),
                        ),
                      const Divider(),
                      Text(
                        'Marchés documentés',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (generatorRows(row['candidates']).isEmpty)
                        const Text(
                          'Aucun marché admissible avec une cote récente et un soutien suffisant.',
                        ),
                      for (final market in generatorRows(row['candidates']))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            '${market['selection']} · ${market['odds']}',
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              for (final missing in _data?['missing'] as List? ?? [])
                Text(
                  missing.toString(),
                  style: TextStyle(color: context.semantic.warning),
                ),
              const Text(
                'Les rangs de championnats différents ne constituent pas une comparaison directe. Les observations ne sont pas des probabilités de réussite.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _data == null
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ShortlistConversationPage(
                            controller: widget.controller,
                            keys: widget.keys,
                            prompt:
                                'Compare ces deux rencontres de ma sélection Shortlist : lectures complémentaires, forme, marchés étayés et points de vigilance. Explique ce qui les distingue sans supposer un vainqueur.',
                          ),
                        ),
                      ),
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Approfondir avec Lector'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
