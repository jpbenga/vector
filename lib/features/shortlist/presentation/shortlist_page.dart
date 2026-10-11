import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../app/auth/lector_account_sheet.dart';
import '../../../app/sports/generator_match_navigation.dart';
import '../../../core/theme/app_components.dart';
import '../../../core/widgets/lector_loading.dart';
import '../../../core/widgets/lector_match_card.dart';
import '../../../core/widgets/lector_responsive_layout.dart';
import '../../generator/domain/generator_context.dart';
import '../application/shortlist_controller.dart';
import '../domain/shortlist.dart';
import 'shortlist_conversation_page.dart';
import 'shortlist_comparison_page.dart';

class ShortlistPage extends StatefulWidget {
  const ShortlistPage({required this.controller, super.key});
  final ShortlistController controller;
  @override
  State<ShortlistPage> createState() => _ShortlistPageState();
}

class _ShortlistPageState extends State<ShortlistPage> {
  String _group = 'upcoming';
  ShortlistController get c => widget.controller;
  @override
  void initState() {
    super.initState();
    c.refresh();
  }

  Future<void> _perform(
    String action, {
    String? session,
    ShortlistFixture? fixture,
    DateTime? until,
    int? revision,
  }) async {
    try {
      await c.mutate(
        action,
        session: session,
        fixture: fixture,
        until: until,
        revision: revision,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(c.error ?? 'Action indisponible.')),
        );
      }
    }
  }

  Future<void> _clear() async {
    final session = c.active;
    if (session == null || session.items.isEmpty) return;
    await _perform('clear');
    if (!mounted || c.error != null) return;
    final revision = c.active?.revision;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Shortlist vidée'),
        action: SnackBarAction(
          label: 'Annuler',
          onPressed: () =>
              _perform('undo_clear', session: session.id, revision: revision),
        ),
      ),
    );
  }

  Future<void> _extend() async {
    final options = generatorRows(c.active?.json['extensionOptions']);
    final until = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.more_time_rounded,
                size: 40,
                color: context.brand.accent,
              ),
              const SizedBox(height: 14),
              Text(
                'Conserver ma Shortlist',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Choisissez jusqu’à quand garder votre préparation.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              for (final option in options)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(
                      context,
                      DateTime.parse(option['until'].toString()),
                    ),
                    child: Text(option['label'].toString()),
                  ),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
            ],
          ),
        ),
      ),
    );
    if (until != null) await _perform('extend', until: until);
  }

  void _prepare({String? prompt}) {
    final keys = c.selected.where((k) => c.contains(k)).toList();
    if (keys.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ShortlistConversationPage(
          controller: c,
          keys: keys,
          prompt: prompt,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final items = c.items,
          selected = c.selected.where((k) => c.contains(k)).toList();
      final active = c.active;
      final remaining = active?.expiresAt.difference(c.now);
      final body = items
          .where(
            (f) =>
                f.phase(c.now) == _group ||
                (_group == 'other' &&
                    ['other', 'unavailable'].contains(f.phase(c.now))),
          )
          .toList();
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Ma Shortlist${items.isEmpty ? '' : ' · ${items.length}'}',
          ),
          actions: [
            IconButton(
              tooltip: 'Actualiser',
              onPressed: c.loading ? null : c.refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        bottomNavigationBar: active == null || items.isEmpty
            ? null
            : SafeArea(
                child: LectorContent(
                  maxWidth: 544,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${selected.length} rencontre${selected.length > 1 ? 's' : ''} sélectionnée${selected.length > 1 ? 's' : ''}',
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: !c.loading && selected.length == 2
                                    ? () => Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              ShortlistComparisonPage(
                                                controller: c,
                                                keys: selected,
                                              ),
                                        ),
                                      )
                                    : null,
                                icon: const Icon(Icons.compare_arrows_rounded),
                                label: const Text('Comparer'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor:
                                      context.strategies.violetStyle.color,
                                ),
                                onPressed: c.loading || selected.isEmpty
                                    ? null
                                    : () => _prepare(),
                                icon: const Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 18,
                                ),
                                label: const Text('Préparer'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        body: RefreshIndicator(
          onRefresh: c.refresh,
          child: ListView(
            key: const PageStorageKey('shortlist-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            children: [
              LectorContent(
                maxWidth: 544,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (c.account == null) ...[
                      const Text(
                        'Connectez-vous pour conserver votre préparation et la retrouver sur vos appareils.',
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => showLectorAccountSheet(context),
                        child: const Text('Se connecter'),
                      ),
                    ] else if (c.loading && c.snapshot == null)
                      const LectorLoading(
                        label: 'Chargement de votre Shortlist…',
                      )
                    else ...[
                      if (c.loading)
                        const LinearProgressIndicator(minHeight: 2),
                      if (c.error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            c.error!,
                            style: TextStyle(color: context.semantic.warning),
                          ),
                        ),
                      if (active != null)
                        LectorMatchCardFrame(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.schedule_rounded,
                                    color: context.brand.accent,
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text('Session temporaire'),
                                  ),
                                  if (remaining != null &&
                                      remaining.inHours < 3)
                                    Text(
                                      'Expire dans ${remaining.inMinutes < 60 ? '${remaining.inMinutes} min' : '${remaining.inHours} h'}',
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Rencontres conservées jusqu’au ${DateFormat('dd/MM à HH:mm').format(active.expiresAt.toLocal())}.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: c.loading ? null : _extend,
                                      icon: const Icon(
                                        Icons.more_time_rounded,
                                        size: 18,
                                      ),
                                      label: const Text('Prolonger'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextButton.icon(
                                      onPressed: c.loading || items.isEmpty
                                          ? null
                                          : _clear,
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 18,
                                      ),
                                      label: const Text('Vider la liste'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      for (final session in c.recoverable)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: LectorMatchCardFrame(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Une préparation de ${session.items.length} rencontres a expiré. Vous pouvez encore la récupérer.',
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton(
                                  onPressed: c.loading
                                      ? null
                                      : () => _perform(
                                          active == null ? 'restore' : 'merge',
                                          session: session.id,
                                        ),
                                  child: Text(
                                    active == null
                                        ? 'Restaurer'
                                        : 'Fusionner avec ma Shortlist',
                                  ),
                                ),
                                if (active == null)
                                  TextButton(
                                    onPressed: () => _perform('new'),
                                    child: const Text(
                                      'Commencer une nouvelle Shortlist',
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      if (items.isEmpty) ...[
                        const SizedBox(height: 32),
                        Icon(
                          Icons.bookmark_add_outlined,
                          size: 42,
                          color: context.brand.accent,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Votre espace de préparation',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Ajoutez des rencontres depuis Pour moi, Radar, Tous ou leur détail, puis comparez-les et préparez vos tickets avec Lector.',
                          textAlign: TextAlign.center,
                        ),
                      ] else ...[
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final g in const {
                              'upcoming': 'À étudier',
                              'live': 'En direct',
                              'finished': 'Terminés',
                              'other': 'Indisponibles',
                            }.entries)
                              ChoiceChip(
                                label: Text(
                                  '${g.value} ${items.where((f) => f.phase(c.now) == g.key || (g.key == 'other' && f.phase(c.now) == 'unavailable')).length}',
                                ),
                                selected: _group == g.key,
                                onSelected: (_) =>
                                    setState(() => _group = g.key),
                              ),
                          ],
                        ),
                        TextButton(
                          onPressed: () {
                            for (final f in body) {
                              c.choose(f.key, true);
                            }
                          },
                          child: const Text('Sélectionner ces rencontres'),
                        ),
                        if (body.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Aucune rencontre dans cette catégorie.',
                            ),
                          ),
                        for (final f in body)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: LectorMatchCardFrame(
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: c.selected.contains(f.key),
                                    onChanged: (v) =>
                                        c.choose(f.key, v == true),
                                  ),
                                  Expanded(
                                    child: InkWell(
                                      onTap: f.available
                                          ? () => openGeneratorMatch(
                                              context,
                                              f.navigation,
                                            )
                                          : null,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          LectorTeamLine(
                                            name: f.home,
                                            logoUrl: f.json['homeLogo']
                                                ?.toString(),
                                          ),
                                          const SizedBox(height: 6),
                                          LectorTeamLine(
                                            name: f.away,
                                            logoUrl: f.json['awayLogo']
                                                ?.toString(),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            '${f.sport == 'hockey' ? 'Hockey' : 'Football'} · ${f.json['competition'] ?? 'Compétition à confirmer'}',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                          Text(
                                            f.kickoff == null
                                                ? 'Publication indisponible'
                                                : DateFormat(
                                                    'EEE dd/MM · HH:mm',
                                                    'fr',
                                                  ).format(
                                                    f.kickoff!.toLocal(),
                                                  ),
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                          if (_group != 'upcoming')
                                            const Text(
                                              'Consultable · exclue des tickets prématch',
                                              style: TextStyle(fontSize: 11),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Retirer de la Shortlist',
                                    onPressed: c.loading
                                        ? null
                                        : () => _perform('remove', fixture: f),
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 19,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ],
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
