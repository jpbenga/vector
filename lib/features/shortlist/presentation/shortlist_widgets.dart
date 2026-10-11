import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_components.dart';
import '../../../core/widgets/lector_responsive_layout.dart';
import '../../../core/widgets/lector_horizontal_transition.dart';
import '../../../core/widgets/lector_workspace_navigation.dart';
import '../../../core/widgets/sports_asset_badge.dart';
import '../domain/shortlist.dart';
import 'shortlist_view.dart';

Color shortlistAccent(BuildContext context) => context.features.shortlistAccent;

Future<ShortlistViewFilter?> showShortlistFilters(
  BuildContext context,
  ShortlistViewFilter filter,
  List<ShortlistFixture> fixtures,
) {
  final competitions = fixtures.map((f) => f.competition).toSet().toList()
    ..sort();
  String? sport = filter.sport, competition = filter.competition;
  var withReadings = filter.withReadings;
  return showModalBottomSheet<ShortlistViewFilter>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    sheetAnimationStyle: lectorSheetAnimationStyle(context),
    builder: (context) => StatefulBuilder(
      builder: (context, update) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Filtrer ma Shortlist',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    TextButton(
                      onPressed: () => update(() {
                        sport = null;
                        competition = null;
                        withReadings = false;
                      }),
                      child: const Text('Réinitialiser'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<String>(
                  key: ValueKey('shortlist-sport-filter-${sport ?? 'all'}'),
                  initialValue: sport ?? 'all',
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Sport'),
                  items: const [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text('Tous les sports'),
                    ),
                    DropdownMenuItem(
                      value: 'football',
                      child: Text('Football'),
                    ),
                    DropdownMenuItem(value: 'hockey', child: Text('Hockey')),
                  ],
                  onChanged: (value) =>
                      update(() => sport = value == 'all' ? null : value),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  key: ValueKey(
                    'shortlist-competition-filter-${competition ?? 'all'}',
                  ),
                  initialValue: competitions.contains(competition)
                      ? competition
                      : '',
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Compétition'),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Toutes les compétitions'),
                    ),
                    for (final name in competitions)
                      DropdownMenuItem(
                        value: name,
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) =>
                      update(() => competition = value == '' ? null : value),
                ),
                const SizedBox(height: 10),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Avec des lectures détectées'),
                  value: withReadings,
                  onChanged: (value) => update(() => withReadings = value),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(
                    context,
                    ShortlistViewFilter(
                      sport: sport,
                      competition: competition,
                      withReadings: withReadings,
                    ),
                  ),
                  child: const Text('Appliquer les filtres'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class ShortlistSessionCard extends StatelessWidget {
  const ShortlistSessionCard({
    required this.session,
    required this.now,
    required this.onExtend,
    required this.onClear,
    super.key,
  });
  final ShortlistSession session;
  final DateTime now;
  final VoidCallback? onExtend, onClear;
  @override
  Widget build(BuildContext context) {
    final accent = shortlistAccent(context);
    final remaining = session.expiresAt.difference(now);
    final minutes = remaining.inMinutes.clamp(0, 10080);
    final label = minutes < 60
        ? '$minutes min restantes'
        : '${(minutes / 60).ceil()} h restantes';
    final start =
        DateTime.tryParse(session.json['lastModifiedAt']?.toString() ?? '') ??
        session.expiresAt.subtract(const Duration(hours: 24));
    final total = session.expiresAt.difference(start).inSeconds;
    final progress = total > 0
        ? (remaining.inSeconds / total).clamp(0.0, 1.0)
        : 0.0;
    return Container(
      key: const ValueKey('shortlist-session-card'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.surfaces.backgroundSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.surfaces.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(Icons.schedule_rounded, size: 23, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            'Session temporaire',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 87,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                label,
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 5),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.indicator,
                                ),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 4,
                                  color: accent,
                                  backgroundColor:
                                      context.surfaces.surfaceHover,
                                  semanticsLabel:
                                      'Temps restant pour la session',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rencontres conservées jusqu’au ${DateFormat('dd/MM à HH:mm').format(session.expiresAt.toLocal())}.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.textColors.secondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onExtend,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accent,
                    backgroundColor: accent.withValues(alpha: .04),
                    side: BorderSide(color: accent.withValues(alpha: .45)),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.more_time_rounded, size: 18),
                  label: const Text(
                    'Prolonger',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onClear,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text(
                    'Vider la liste',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ShortlistStatusTabs extends StatelessWidget {
  const ShortlistStatusTabs({
    required this.counts,
    required this.group,
    required this.onChanged,
    super.key,
  });
  final Map<String, int> counts;
  final String group;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final (key, label) in const [
          ('upcoming', 'À étudier'),
          ('live', 'En direct'),
          ('finished', 'Terminés'),
          ('other', 'Indisponibles'),
        ])
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Semantics(
              selected: group == key,
              button: true,
              child: Material(
                color: group == key
                    ? shortlistAccent(context).withValues(alpha: .1)
                    : context.surfaces.backgroundSecondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(
                    color: group == key
                        ? shortlistAccent(context).withValues(alpha: .6)
                        : context.surfaces.border,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: ValueKey('shortlist-status-$key'),
                  onTap: () => onChanged(key),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: group == key
                        ? BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: shortlistAccent(context),
                                width: 2,
                              ),
                            ),
                          )
                        : null,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: group == key
                                ? shortlistAccent(context)
                                : context.textColors.secondary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: group == key
                                ? shortlistAccent(context)
                                : context.surfaces.surfaceHover,
                            borderRadius: BorderRadius.circular(
                              AppRadius.control,
                            ),
                          ),
                          child: Text(
                            '${counts[key] ?? 0}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: group == key
                                  ? context.features.shortlistOnAccent
                                  : context.textColors.secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class ShortlistFixtureTile extends StatelessWidget {
  const ShortlistFixtureTile({
    required this.fixture,
    required this.now,
    required this.selected,
    required this.onSelected,
    required this.onRemove,
    required this.onOpen,
    super.key,
  });
  final ShortlistFixture fixture;
  final DateTime now;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final VoidCallback? onRemove, onOpen;
  String get _day {
    final date = fixture.kickoff?.toLocal();
    if (date == null) return 'Indisponible';
    final today = now.toLocal();
    final delta = DateTime(
      date.year,
      date.month,
      date.day,
    ).difference(DateTime(today.year, today.month, today.day)).inDays;
    if (delta == 0) return 'Aujourd’hui';
    if (delta == 1) return 'Demain';
    return DateFormat('dd/MM').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final accent = shortlistAccent(context);
    final phase = fixture.phase(now);
    final tags = fixture.readingTags;
    return Material(
      key: ValueKey('shortlist-fixture:${fixture.key}'),
      color: selected
          ? Color.alphaBlend(
              accent.withValues(alpha: .035),
              context.surfaces.backgroundSecondary,
            )
          : context.surfaces.backgroundSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected
              ? accent.withValues(alpha: .55)
              : context.surfaces.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final expandedLayout =
              constraints.maxWidth < 340 ||
              MediaQuery.textScalerOf(context).scale(13) > 16;
          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 7, 6, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Checkbox(
                      key: ValueKey('shortlist-select:${fixture.key}'),
                      value: selected,
                      onChanged: (value) => onSelected(value == true),
                      activeColor: accent,
                      checkColor: context.features.shortlistOnAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: onOpen,
                        borderRadius: BorderRadius.circular(AppRadius.control),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _team(
                              context,
                              fixture.home,
                              fixture.json['homeLogo']?.toString(),
                              multiline: expandedLayout,
                            ),
                            const SizedBox(height: 2),
                            _team(
                              context,
                              fixture.away,
                              fixture.json['awayLogo']?.toString(),
                              multiline: expandedLayout,
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                SportsAssetBadge(
                                  size: 14,
                                  imageUrl: fixture.json['countryFlag']
                                      ?.toString(),
                                  fallbackLabel: fixture.sport == 'hockey'
                                      ? 'H'
                                      : 'F',
                                  icon: fixture.sport == 'hockey'
                                      ? Icons.sports_hockey_rounded
                                      : Icons.sports_soccer_rounded,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    fixture.competition,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: context.textColors.secondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!expandedLayout) ...[
                      const SizedBox(width: 8),
                      _timing(context, phase),
                      ..._actions(context),
                    ],
                  ],
                ),
                if (expandedLayout)
                  Padding(
                    padding: const EdgeInsets.only(left: 44, top: 4),
                    child: Row(
                      children: [
                        Expanded(child: _timing(context, phase)),
                        ..._actions(context),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(left: 44, top: 5),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    children: [
                      _tag(
                        context,
                        Icons.bar_chart_rounded,
                        fixture.readingsAvailable
                            ? '${fixture.readingCount} lecture${fixture.readingCount == 1 ? '' : 's'}'
                            : 'Lectures à actualiser',
                        accent,
                        filled: true,
                      ),
                      for (final tag in tags.take(2))
                        _tag(
                          context,
                          tag.kind == 'warning'
                              ? Icons.error_outline_rounded
                              : tag.kind == 'form'
                              ? Icons.trending_up_rounded
                              : Icons.stars_rounded,
                          tag.label,
                          tag.kind == 'warning'
                              ? context.semantic.warning
                              : tag.kind == 'form'
                              ? context.features.radarAccent
                              : context.features.generatorAccent,
                        ),
                      if (phase != 'upcoming')
                        Text(
                          'Exclue des tickets prématch',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: context.textColors.secondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _actions(BuildContext context) => [
    IconButton(
      key: ValueKey('shortlist-remove:${fixture.key}'),
      tooltip: 'Retirer ${fixture.home} – ${fixture.away} de la Shortlist',
      onPressed: onRemove,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      icon: Icon(
        Icons.bookmark_rounded,
        size: 20,
        color: shortlistAccent(context),
      ),
    ),
    IconButton(
      tooltip: 'Voir ${fixture.home} – ${fixture.away}',
      onPressed: onOpen,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      icon: Icon(
        Icons.chevron_right_rounded,
        color: context.textColors.secondary,
        size: 21,
      ),
    ),
  ];

  Widget _timing(BuildContext context, String phase) {
    final status = fixture.json['status']?.toString().toLowerCase();
    final label = phase == 'live'
        ? 'En direct'
        : phase == 'finished'
        ? 'Terminé'
        : ['pst', 'postponed'].contains(status)
        ? 'Reporté'
        : ['canc', 'cancelled'].contains(status)
        ? 'Annulé'
        : phase != 'upcoming'
        ? 'Indisponible'
        : DateFormat('HH:mm').format(fixture.kickoff!.toLocal());
    return Container(
      padding: const EdgeInsets.only(left: 9),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: context.surfaces.border.withValues(alpha: .6),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: phase == 'live'
                  ? context.semantic.live
                  : context.textColors.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _day,
            style: TextStyle(
              fontSize: 10.5,
              color: context.textColors.secondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _team(
    BuildContext context,
    String name,
    String? logo, {
    bool multiline = false,
  }) => Row(
    children: [
      SportsAssetBadge(
        size: 20,
        imageUrl: logo,
        fallbackLabel: name,
        padding: 0,
      ),
      const SizedBox(width: 7),
      Expanded(
        child: Text(
          name,
          maxLines: multiline ? null : 1,
          overflow: multiline ? TextOverflow.visible : TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: context.textColors.primary,
          ),
        ),
      ),
    ],
  );
  Widget _tag(
    BuildContext context,
    IconData icon,
    String label,
    Color color, {
    bool filled = false,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: filled ? .1 : .05),
      border: filled ? null : Border.all(color: color.withValues(alpha: .35)),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class ShortlistActionBar extends StatelessWidget {
  const ShortlistActionBar({
    required this.count,
    required this.allSelected,
    required this.onSelectAll,
    required this.onCompare,
    required this.onPrepare,
    required this.onNavigate,
    super.key,
  });
  final int count;
  final bool allSelected;
  final VoidCallback? onSelectAll, onCompare, onPrepare;
  final ValueChanged<LectorWorkspaceSection>? onNavigate;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.surfaces.backgroundSecondary,
      border: Border(top: BorderSide(color: context.surfaces.border)),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
    ),
    child: SafeArea(
      top: false,
      child: LectorContent(
        maxWidth: 544,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$count sélectionné${count > 1 ? 's' : ''}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Choisissez une action pour continuer.',
                              style: TextStyle(
                                fontSize: 11,
                                color: context.textColors.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: TextButton(
                          onPressed: onSelectAll,
                          child: Text(
                            allSelected
                                ? 'Tout désélectionner'
                                : 'Tout sélectionner',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final vertical =
                          constraints.maxWidth < 345 ||
                          MediaQuery.textScalerOf(context).scale(14) > 19;
                      final compare = OutlinedButton.icon(
                        key: const ValueKey('shortlist-compare'),
                        onPressed: onCompare,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                        icon: const Icon(
                          Icons.compare_arrows_rounded,
                          size: 18,
                        ),
                        label: const Text(
                          'Comparer (2)',
                          style: TextStyle(fontSize: 12),
                        ),
                      );
                      final prepare = FilledButton.icon(
                        key: const ValueKey('shortlist-prepare'),
                        onPressed: onPrepare,
                        style: FilledButton.styleFrom(
                          backgroundColor: context.features.generatorActionFill,
                          foregroundColor: context.features.generatorActionText,
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                        icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                        label: const Text(
                          'Préparer un ticket',
                          style: TextStyle(fontSize: 12),
                        ),
                      );
                      return vertical
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                compare,
                                const SizedBox(height: 7),
                                prepare,
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(child: compare),
                                const SizedBox(width: 9),
                                Expanded(child: prepare),
                              ],
                            );
                    },
                  ),
                ],
              ),
            ),
            if (onNavigate != null) ...[
              Divider(height: 1, color: context.surfaces.border),
              Row(
                children: [
                  for (final (section, label, icon) in const [
                    (
                      LectorWorkspaceSection.forMe,
                      'Pour moi',
                      Icons.person_outline_rounded,
                    ),
                    (
                      LectorWorkspaceSection.radar,
                      'Radar',
                      Icons.radar_rounded,
                    ),
                    (
                      LectorWorkspaceSection.all,
                      'Tous',
                      Icons.format_list_bulleted_rounded,
                    ),
                    (
                      LectorWorkspaceSection.generator,
                      'Générateur',
                      Icons.style_outlined,
                    ),
                    (
                      LectorWorkspaceSection.bilan,
                      'Bilan',
                      Icons.insights_outlined,
                    ),
                  ])
                    Expanded(
                      child: Semantics(
                        button: true,
                        label: label,
                        child: InkWell(
                          key: ValueKey('shortlist-nav-${section.name}'),
                          onTap: () => onNavigate!(section),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  icon,
                                  color: context.textColors.secondary,
                                  size: 21,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: context.textColors.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
