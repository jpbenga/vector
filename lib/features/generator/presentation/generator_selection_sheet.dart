import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_components.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/sports_asset_badge.dart';
import '../domain/generator_context.dart';
import 'generator_formatters.dart';

Future<void> showGeneratorSelectionDetail(
  BuildContext context, {
  required Map<String, dynamic> pick,
  required VoidCallback onOpenMatch,
  required VoidCallback onReplace,
  bool inTicket = true,
  bool analysisOnly = false,
}) {
  FocusManager.instance.primaryFocus?.unfocus();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: context.surfaces.backgroundSecondary,
    constraints: const BoxConstraints(maxWidth: 720),
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      side: BorderSide(color: context.surfaces.border),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (context) => SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .92,
        child: GeneratorSelectionSheet(
          pick: pick,
          inTicket: inTicket,
          analysisOnly: analysisOnly,
          onClose: () => Navigator.pop(context),
          onOpenMatch: () {
            Navigator.pop(context);
            onOpenMatch();
          },
          onReplace: () {
            Navigator.pop(context);
            onReplace();
          },
        ),
      ),
    ),
  );
}

/// One selection object, four views. This surface is shared by every sport.
class GeneratorSelectionSheet extends StatefulWidget {
  const GeneratorSelectionSheet({
    required this.pick,
    required this.onClose,
    required this.onOpenMatch,
    required this.onReplace,
    this.inTicket = true,
    this.analysisOnly = false,
    super.key,
  });
  final Map<String, dynamic> pick;
  final VoidCallback onClose, onOpenMatch, onReplace;
  final bool inTicket;
  final bool analysisOnly;
  @override
  State<GeneratorSelectionSheet> createState() =>
      _GeneratorSelectionSheetState();
}

class _GeneratorSelectionSheetState extends State<GeneratorSelectionSheet> {
  int _tab = 0;
  final _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: ListView(
          key: const ValueKey('generator-selection-scroll'),
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          children: [
            _CompetitionHeader(pick: widget.pick, onClose: widget.onClose),
            const SizedBox(height: 14),
            _Opposition(pick: widget.pick),
            const SizedBox(height: 18),
            _SelectionProposal(
              pick: widget.pick,
              inTicket: widget.inTicket,
              analysisOnly: widget.analysisOnly,
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: context.surfaces.border),
                borderRadius: BorderRadius.circular(AppRadius.card),
                color: context.surfaces.surface,
              ),
              child: Row(
                children: [
                  for (final entry in [
                    'Analyse',
                    'Données',
                    'Signaux Radar',
                    'Marchés',
                  ].indexed) ...[
                    if (entry.$1 > 0)
                      Container(
                        height: 24,
                        width: 1,
                        color: context.surfaces.border,
                      ),
                    Expanded(
                      child: InkWell(
                        key: ValueKey('selection-tab-${entry.$1}'),
                        onTap: () => setState(() => _tab = entry.$1),
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                width: 3,
                                color: _tab == entry.$1
                                    ? context.brand.accent
                                    : Theme.of(context).colorScheme.surface
                                          .withValues(alpha: 0),
                              ),
                            ),
                          ),
                          child: Text(
                            entry.$2,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: _tab == entry.$1
                                      ? context.brand.accent
                                      : context.textColors.secondary,
                                  fontWeight: _tab == entry.$1
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            GeneratorSelectionEvidence(pick: widget.pick, tab: _tab),
          ],
        ),
      ),
      Container(
        key: const ValueKey('selection-fixed-actions'),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: context.surfaces.backgroundSecondary,
          border: Border(top: BorderSide(color: context.surfaces.border)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final style = ButtonStyle(
              minimumSize: const WidgetStatePropertyAll(Size(0, 58)),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              ),
              textStyle: WidgetStatePropertyAll(
                Theme.of(context).textTheme.labelMedium,
              ),
            );
            final buttons = [
              OutlinedButton.icon(
                style: style,
                onPressed: widget.onOpenMatch,
                icon: const Icon(Icons.bar_chart_rounded, size: 22),
                label: const Text(
                  'Voir les données du match',
                  textAlign: TextAlign.center,
                ),
              ),
              FilledButton.icon(
                style: style,
                onPressed: widget.onReplace,
                icon: const Icon(Icons.swap_horiz_rounded, size: 22),
                label: Text(
                  widget.analysisOnly
                      ? 'Comparer les autres marchés'
                      : 'Remplacer cette sélection',
                  textAlign: TextAlign.center,
                ),
              ),
            ];
            return constraints.maxWidth >= 320
                ? Row(
                    children: [
                      Expanded(child: buttons[0]),
                      const SizedBox(width: 8),
                      Expanded(child: buttons[1]),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      buttons[0],
                      const SizedBox(height: 6),
                      buttons[1],
                    ],
                  );
          },
        ),
      ),
    ],
  );
}

class _CompetitionHeader extends StatelessWidget {
  const _CompetitionHeader({required this.pick, required this.onClose});
  final Map<String, dynamic> pick;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      SportsAssetBadge(
        size: 34,
        imageUrl:
            pick['countryFlag']?.toString() ??
            pick['competitionLogo']?.toString(),
        fallbackLabel: '',
        icon: Icons.emoji_events_outlined,
        borderRadius: AppRadius.tight,
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              pick['competition']?.toString() ?? '',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              generatorKickoff(pick),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.textColors.secondary,
              ),
            ),
          ],
        ),
      ),
      IconButton(
        tooltip: 'Fermer le détail',
        onPressed: onClose,
        icon: const Icon(Icons.close_rounded),
      ),
    ],
  );
}

class _Opposition extends StatelessWidget {
  const _Opposition({required this.pick});
  final Map<String, dynamic> pick;
  @override
  Widget build(BuildContext context) {
    final sides = pick['sport'] == 'hockey'
        ? ['away', 'home']
        : ['home', 'away'];
    Widget team(String side, bool right) => Expanded(
      child: Row(
        mainAxisAlignment: right
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!right)
            SportsAssetBadge(
              size: 40,
              imageUrl: pick['${side}Logo']?.toString(),
              fallbackLabel: pick[side]?.toString() ?? '',
              padding: 0,
              borderRadius: AppRadius.tight,
            ),
          if (!right) const SizedBox(width: 8),
          Flexible(
            child: Text(
              pick[side]?.toString() ?? '',
              maxLines: 3,
              textAlign: right ? TextAlign.right : TextAlign.left,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          if (right) const SizedBox(width: 8),
          if (right)
            SportsAssetBadge(
              size: 40,
              imageUrl: pick['${side}Logo']?.toString(),
              fallbackLabel: pick[side]?.toString() ?? '',
              padding: 0,
              borderRadius: AppRadius.tight,
            ),
        ],
      ),
    );
    return Row(
      children: [
        team(sides[0], false),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            '—',
            style: TextStyle(color: context.textColors.secondary),
          ),
        ),
        team(sides[1], true),
      ],
    );
  }
}

class _SelectionProposal extends StatelessWidget {
  const _SelectionProposal({
    required this.pick,
    required this.inTicket,
    this.analysisOnly = false,
  });
  final Map<String, dynamic> pick;
  final bool inTicket;
  final bool analysisOnly;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: context.brand.accent.withValues(alpha: .04),
      border: Border.all(color: context.brand.accent.withValues(alpha: .8)),
      borderRadius: BorderRadius.circular(AppRadius.card),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SÉLECTION PROPOSÉE',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.textColors.secondary,
                  letterSpacing: .7,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    pick['selection']?.toString() ?? '',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: context.surfaces.surfaceHover,
                      borderRadius: BorderRadius.circular(AppRadius.odds),
                    ),
                    child: Text(
                      generatorOdds(pick['odds']),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                pick['market']?.toString() ?? '',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.textColors.secondary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _quoteSource(pick),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.textColors.secondary,
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 84,
          width: 1,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          color: context.surfaces.border,
        ),
        SizedBox(
          width: 62,
          child: Column(
            children: [
              Icon(
                inTicket
                    ? Icons.check_circle_outline_rounded
                    : Icons.edit_note_rounded,
                color: context.brand.accent,
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                analysisOnly
                    ? 'À examiner'
                    : inTicket
                    ? 'Dans le ticket'
                    : 'Changement proposé',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: context.brand.accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

String _quoteSource(Map<String, dynamic> pick) {
  final date = DateTime.tryParse(pick['oddsAt']?.toString() ?? '')?.toLocal();
  return '${pick['bookmaker'] ?? 'Bookmaker non renseigné'} · ${date == null ? 'date de cote non renseignée' : 'cote relevée le ${DateFormat('d/MM à HH:mm', 'fr').format(date)}'}';
}

/// Analysis cards are also reused inside the whole-ticket view.
class GeneratorSelectionEvidence extends StatelessWidget {
  const GeneratorSelectionEvidence({
    required this.pick,
    this.tab = 0,
    super.key,
  });
  final Map<String, dynamic> pick;
  final int tab;
  @override
  Widget build(BuildContext context) {
    final readings = generatorEvidence(pick, 'reading');
    final support = readings
        .where((e) => e['supportsMarket'] != false)
        .toList();
    final contextReadings = readings
        .where((e) => e['supportsMarket'] == false)
        .toList();
    final radar = generatorEvidence(pick, 'radar');
    final shared = generatorRows(
      pick['evidence'],
    ).where((e) => e['reusesReading'] == true).toList();
    if (tab == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Panel(
            title: 'Données de la sélection',
            icon: Icons.dataset_outlined,
            children: [
              _DataFact(
                label: 'Compétition',
                value: pick['competition']?.toString() ?? 'Non renseignée',
              ),
              _DataFact(label: 'Date du match', value: generatorKickoff(pick)),
              _DataFact(
                label: 'Cote et source',
                value: '${generatorOdds(pick['odds'])} · ${_quoteSource(pick)}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Panel(
            title: 'Échantillons observés',
            icon: Icons.query_stats_rounded,
            count:
                '${readings.length} lecture${readings.length == 1 ? '' : 's'}',
            children: [
              for (final e in readings) _EvidenceRow(evidence: e),
              if (readings.isEmpty)
                const Text('Aucune lecture documentée dans cette sélection.'),
            ],
          ),
        ],
      );
    }
    if (tab == 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Panel(
            title: 'Signaux Radar complémentaires',
            icon: Icons.bar_chart_rounded,
            count: _signals(radar.length),
            children: [
              for (final e in radar) _EvidenceRow(evidence: e),
              if (radar.isEmpty)
                const Text('Aucun signal Radar complémentaire documenté.'),
            ],
          ),
          if (shared.isNotEmpty) ...[
            const SizedBox(height: 12),
            _Panel(
              title: 'Déjà pris en compte dans les lectures',
              icon: Icons.link_rounded,
              children: [
                for (final e in shared) _EvidenceRow(evidence: e),
                const Text(
                  'Ces signaux reposent sur la même série et ne comptent pas comme des confirmations indépendantes.',
                ),
              ],
            ),
          ],
        ],
      );
    }
    if (tab == 3) {
      return _Panel(
        title: 'Marché retenu',
        icon: Icons.tune_rounded,
        children: [
          _DataFact(
            label: 'Marché',
            value: pick['market']?.toString() ?? 'Non renseigné',
          ),
          _DataFact(
            label: 'Sélection',
            value: pick['selection']?.toString() ?? '',
          ),
          _DataFact(label: 'Cote', value: generatorOdds(pick['odds'])),
          _DataFact(label: 'Source', value: _quoteSource(pick)),
          const Text(
            'Utilisez « Remplacer cette sélection » pour demander une autre proposition avec vos marchés autorisés.',
          ),
        ],
      );
    }
    final warnings = (pick['warnings'] as List? ?? [])
        .map((w) => w.toString())
        .where(
          (w) =>
              !w.contains('preuve indépendante') &&
              !w.contains('se recouper') &&
              !w.contains('réutilise ses lectures'),
        )
        .toSet();
    final cautionRows = <Widget>[
      if (shared.isNotEmpty)
        _FactRow(
          icon: Icons.link_rounded,
          title: 'Signaux corrélés',
          body:
              'Les lectures et les signaux Radar correspondants reposent sur les mêmes résultats. Ils ne sont pas indépendants.',
          warning: true,
        ),
      if (radar.any((e) => e['family'] == 'player'))
        _FactRow(
          icon: Icons.person_outline_rounded,
          title: 'Contribution des joueurs',
          body:
              'Un joueur décisif récemment est un élément de contexte, sans garantie de contribution au prochain match.',
          warning: true,
        ),
      for (final warning in warnings)
        _FactRow(
          icon: Icons.info_outline_rounded,
          title: 'À prendre en compte',
          body: warning,
          warning: true,
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Panel(
          title: 'Lectures qui soutiennent ce marché',
          icon: Icons.menu_book_rounded,
          count: '${support.length} lecture${support.length == 1 ? '' : 's'}',
          children: [
            for (final e in support) _EvidenceRow(evidence: e, active: true),
            if (support.isEmpty)
              const Text(
                'Aucune lecture documentée ne soutient directement ce marché.',
              ),
          ],
        ),
        if (contextReadings.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Panel(
            title: 'Contexte complémentaire',
            icon: Icons.compare_arrows_rounded,
            count:
                '${contextReadings.length} lecture${contextReadings.length == 1 ? '' : 's'}',
            children: [
              for (final e in contextReadings) _EvidenceRow(evidence: e),
            ],
          ),
        ],
        if (radar.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Panel(
            title: 'Signaux Radar complémentaires',
            icon: Icons.bar_chart_rounded,
            count: _signals(radar.length),
            children: [
              for (final e in radar.take(3)) _EvidenceRow(evidence: e),
              if (radar.length > 3)
                Text(
                  '${radar.length - 3} autres signaux dans l’onglet Signaux Radar.',
                ),
            ],
          ),
        ],
        if (cautionRows.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Panel(
            title: 'Points de vigilance',
            icon: Icons.warning_amber_rounded,
            warning: true,
            count:
                '${cautionRows.length} élément${cautionRows.length == 1 ? '' : 's'}',
            children: cautionRows,
          ),
        ],
      ],
    );
  }
}

String _signals(int count) => '$count signal${count == 1 ? '' : 's'}';

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.icon,
    required this.children,
    this.count,
    this.warning = false,
  });
  final String title;
  final IconData icon;
  final List<Widget> children;
  final String? count;
  final bool warning;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: context.surfaces.surface,
      border: Border.all(color: context.surfaces.border),
      borderRadius: BorderRadius.circular(AppRadius.card),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: warning ? context.semantic.warning : context.brand.accent,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: context.surfaces.surfaceHover,
                  border: Border.all(color: context.surfaces.border),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                child: Text(
                  count!,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            border: Border.all(color: context.surfaces.border),
            borderRadius: BorderRadius.circular(AppRadius.input),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final e in children.indexed) ...[
                if (e.$1 > 0)
                  Divider(height: 1, color: context.surfaces.border),
                e.$2,
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _EvidenceRow extends StatelessWidget {
  const _EvidenceRow({required this.evidence, this.active = false});
  final Map<String, dynamic> evidence;
  final bool active;
  @override
  Widget build(BuildContext context) => _FactRow(
    icon: switch (evidence['family']) {
      'standing' => Icons.bar_chart_rounded,
      'venue' => Icons.home_rounded,
      'player' => Icons.person_rounded,
      'production' => Icons.insights_rounded,
      'h2h' => Icons.compare_arrows_rounded,
      _ => Icons.trending_up_rounded,
    },
    photo: evidence['photo']?.toString(),
    title: evidence['label']?.toString() ?? '',
    body: _evidenceText(evidence),
    active: active,
    sample: (evidence['sample'] is num && (evidence['sample'] as num) > 0)
        ? 'Échantillon : ${evidence['sample']} matchs'
        : 'Échantillon non précisé',
    onTap: () => _showEvidence(context, evidence),
  );
}

String _evidenceText(Map<String, dynamic> evidence) {
  final metrics = generatorRows(
    evidence['metrics'],
  ).where((e) => e['label']?.toString().isNotEmpty == true);
  if (metrics.isNotEmpty) {
    return metrics
        .map(
          (m) =>
              '${m['label']}${m['value']?.toString().isNotEmpty == true ? ' : ${m['value']}' : ''}',
        )
        .join(' · ');
  }
  return (evidence['text']?.toString() ?? '')
      .split(' Un signal')
      .first
      .split(' Le Radar')
      .first;
}

class _FactRow extends StatelessWidget {
  const _FactRow({
    required this.icon,
    required this.title,
    required this.body,
    this.photo,
    this.sample,
    this.active = false,
    this.warning = false,
    this.onTap,
  });
  final IconData icon;
  final String title, body;
  final String? photo, sample;
  final bool active, warning;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final color = warning ? context.semantic.warning : context.brand.accent;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                shape: BoxShape.circle,
              ),
              child: photo?.isNotEmpty == true
                  ? ClipOval(
                      child: SportsAssetBadge(
                        size: 34,
                        imageUrl: photo,
                        fallbackLabel: '',
                        icon: icon,
                        borderRadius: AppRadius.chip,
                      ),
                    )
                  : Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 3,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (active)
                        Container(
                          padding: const EdgeInsets.only(left: 7),
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                color: context.brand.accent,
                                width: 2,
                              ),
                            ),
                          ),
                          child: Text(
                            'Lecture active',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: context.brand.accent),
                          ),
                        ),
                    ],
                  ),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(height: 1.4),
                    ),
                  ],
                  if (sample != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      sample!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: context.textColors.secondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onTap != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: context.brand.accent,
                  size: 22,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DataFact extends StatelessWidget {
  const _DataFact({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: context.textColors.secondary),
        ),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );
}

void _showEvidence(BuildContext context, Map<String, dynamic> evidence) {
  final at = DateTime.tryParse(evidence['asOf']?.toString() ?? '')?.toLocal();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: context.surfaces.backgroundSecondary,
    builder: (context) => SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              evidence['label']?.toString() ?? '',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(_evidenceText(evidence)),
            const SizedBox(height: 10),
            Text(
              evidence['sample'] is num && (evidence['sample'] as num) > 0
                  ? 'Échantillon : ${evidence['sample']} matchs'
                  : 'Échantillon non précisé',
            ),
            if (at != null)
              Text(
                'Observation du ${DateFormat('d/MM à HH:mm', 'fr').format(at)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Revenir à la sélection'),
            ),
          ],
        ),
      ),
    ),
  );
}
