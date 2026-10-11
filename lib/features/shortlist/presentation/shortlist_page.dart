import 'package:flutter/material.dart';
import '../../../app/auth/lector_account_sheet.dart';
import '../../../app/sports/generator_match_navigation.dart';
import '../../../core/theme/app_components.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/lector_loading.dart';
import '../../../core/widgets/lector_match_card.dart';
import '../../../core/widgets/lector_responsive_layout.dart';
import '../../generator/domain/generator_context.dart';
import '../application/shortlist_controller.dart';
import '../domain/shortlist.dart';
import 'shortlist_conversation_page.dart';
import 'shortlist_comparison_page.dart';
import 'shortlist_view.dart';
import 'shortlist_widgets.dart';
import '../../../core/widgets/lector_horizontal_transition.dart';

class ShortlistPage extends StatefulWidget {
  const ShortlistPage({required this.controller, super.key});
  final ShortlistController controller;
  @override
  State<ShortlistPage> createState() => _ShortlistPageState();
}

class _ShortlistPageState extends State<ShortlistPage> {
  ShortlistSort _sort = ShortlistSort.dateAscending;
  ShortlistViewFilter _filter = const ShortlistViewFilter();
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

  Future<void> _extend() async {
    final options = generatorRows(c.active?.json['extensionOptions']);
    final until = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      sheetAnimationStyle: lectorSheetAnimationStyle(context),
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

  Future<void> _filters() async {
    final result = await showShortlistFilters(context, _filter, c.items);
    if (result != null && mounted) setState(() => _filter = result);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final items = c.items, active = c.active;
      final selected = c.selected.where(c.contains).toList();
      final visible = shortlistVisibleFixtures(
        items,
        sort: _sort,
        filter: _filter,
      );
      final allSelected =
          visible.isNotEmpty &&
          visible.every((f) => c.selected.contains(f.key));
      return Scaffold(
        appBar: AppBar(
          toolbarHeight: 52,
          titleSpacing: 0,
          title: Row(
            children: [
              const Flexible(
                child: Text(
                  'Ma Shortlist',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              if (items.isNotEmpty) ...[
                const SizedBox(width: 9),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: shortlistAccent(context).withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(AppRadius.control),
                  ),
                  child: Text(
                    '${items.length}',
                    style: TextStyle(
                      color: shortlistAccent(context),
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            PopupMenuButton<String>(
              tooltip: 'Options de la Shortlist',
              onSelected: (_) => c.refresh(),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'refresh',
                  enabled: !c.loading,
                  child: const Row(
                    children: [
                      Icon(Icons.refresh_rounded, size: 19),
                      SizedBox(width: 10),
                      Text('Actualiser'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        bottomNavigationBar: c.account == null
            ? null
            : ShortlistActionBar(
                count: selected.length,
                allSelected: allSelected,
                onSelectAll: visible.isEmpty
                    ? null
                    : () {
                        for (final f in visible) {
                          c.choose(f.key, !allSelected);
                        }
                      },
                onCompare: !c.loading && selected.length == 2
                    ? () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ShortlistComparisonPage(
                            controller: c,
                            keys: selected,
                          ),
                        ),
                      )
                    : null,
                onPrepare:
                    !c.loading &&
                        selected.any(
                          (key) => items.any(
                            (f) => f.key == key && f.phase(c.now) == 'upcoming',
                          ),
                        )
                    ? () => _prepare()
                    : null,
              ),
        body: RefreshIndicator(
          onRefresh: c.refresh,
          child: ListView(
            key: const PageStorageKey('shortlist-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            children: [
              LectorContent(
                maxWidth: 544,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        'Vos matchs sélectionnés pour analyse et tickets.',
                        style: TextStyle(
                          color: context.textColors.secondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (c.account == null) ...[
                      const SizedBox(height: 24),
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
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                      if (c.error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            c.error!,
                            style: TextStyle(color: context.semantic.warning),
                          ),
                        ),
                      if (active != null)
                        ShortlistSessionCard(
                          session: active,
                          now: c.now,
                          onExtend: c.loading ? null : _extend,
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
                          color: shortlistAccent(context),
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
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: PopupMenuButton<ShortlistSort>(
                                key: const ValueKey('shortlist-sort'),
                                tooltip: 'Trier les rencontres',
                                initialValue: _sort,
                                onSelected: (sort) =>
                                    setState(() => _sort = sort),
                                itemBuilder: (_) => [
                                  for (final sort in ShortlistSort.values)
                                    PopupMenuItem(
                                      value: sort,
                                      child: Text(sort.label),
                                    ),
                                ],
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.swap_vert_rounded,
                                        size: 19,
                                        color: context.textColors.secondary,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          'Tri : ${_sort.label.toLowerCase()}',
                                          maxLines: 2,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: context.textColors.secondary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        Icons.expand_more_rounded,
                                        size: 17,
                                        color: context.textColors.secondary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            OutlinedButton.icon(
                              key: const ValueKey('shortlist-filters'),
                              onPressed: _filters,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                minimumSize: const Size(0, 40),
                              ),
                              icon: const Icon(Icons.tune_rounded, size: 18),
                              label: Text(
                                'Filtres${_filter.count == 0 ? '' : ' · ${_filter.count}'}',
                                style: const TextStyle(fontSize: 11.5),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (visible.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                const Text(
                                  'Aucune rencontre ne correspond aux filtres.',
                                  textAlign: TextAlign.center,
                                ),
                                if (_filter.count > 0)
                                  TextButton(
                                    onPressed: () => setState(
                                      () =>
                                          _filter = const ShortlistViewFilter(),
                                    ),
                                    child: const Text('Effacer les filtres'),
                                  ),
                              ],
                            ),
                          ),
                        for (final f in visible)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: ShortlistFixtureTile(
                              fixture: f,
                              now: c.now,
                              selected: c.selected.contains(f.key),
                              onSelected: (v) => c.choose(f.key, v),
                              onRemove: c.loading
                                  ? null
                                  : () => _perform('remove', fixture: f),
                              onOpen: f.available
                                  ? () => openGeneratorMatch(
                                      context,
                                      f.navigation,
                                    )
                                  : null,
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
