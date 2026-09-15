import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_components.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../onboarding/domain/decision_profile.dart';
import '../../onboarding/domain/decision_profile_catalogs.dart';

@immutable
class LectorExplorationSelection {
  LectorExplorationSelection({
    required Set<String> readingIds,
    required Set<String> scenarioIds,
  }) : readingIds = Set.unmodifiable(readingIds),
       scenarioIds = Set.unmodifiable(scenarioIds);

  factory LectorExplorationSelection.fromProfile(DecisionProfile profile) {
    return LectorExplorationSelection(
      readingIds: profile.optionIdsFor('readings').toSet(),
      scenarioIds: profile.optionIdsFor('opportunity_profiles').toSet(),
    );
  }

  final Set<String> readingIds;
  final Set<String> scenarioIds;

  int get activeFilterCount => readingIds.length + scenarioIds.length;

  DecisionProfile applyTo(DecisionProfile profile) {
    return profile
        .withOptionIds('readings', [
          for (final definition in ReadingPreferenceCatalog.values)
            if (readingIds.contains(definition.id)) definition.id,
        ])
        .withOptionIds('opportunity_profiles', [
          for (final definition in OpportunityProfileCatalog.values)
            if (scenarioIds.contains(definition.id)) definition.id,
        ]);
  }

  bool matchesProfile(DecisionProfile profile) {
    return _sameIds(readingIds, profile.optionIdsFor('readings')) &&
        _sameIds(scenarioIds, profile.optionIdsFor('opportunity_profiles'));
  }
}

typedef LectorExplorationResultCounter =
    int Function(LectorExplorationSelection selection);

Future<LectorExplorationSelection?> showLectorExplorerSheet({
  required BuildContext context,
  required DecisionProfile profile,
  required LectorExplorationSelection? currentSelection,
  required LectorExplorationResultCounter resultCountFor,
}) {
  return showModalBottomSheet<LectorExplorationSelection>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.transparent,
    barrierColor: context.surfaces.scrim.withValues(alpha: 0.54),
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.84,
      child: _LectorExplorerSheet(
        profile: profile,
        initialSelection:
            currentSelection ?? LectorExplorationSelection.fromProfile(profile),
        resultCountFor: resultCountFor,
      ),
    ),
  );
}

enum _ExplorerTab { readings, scenarios }

class _LectorExplorerSheet extends StatefulWidget {
  const _LectorExplorerSheet({
    required this.profile,
    required this.initialSelection,
    required this.resultCountFor,
  });

  final DecisionProfile profile;
  final LectorExplorationSelection initialSelection;
  final LectorExplorationResultCounter resultCountFor;

  @override
  State<_LectorExplorerSheet> createState() => _LectorExplorerSheetState();
}

class _LectorExplorerSheetState extends State<_LectorExplorerSheet> {
  final TextEditingController _searchController = TextEditingController();
  late Set<String> _readingIds;
  late Set<String> _scenarioIds;
  _ExplorerTab _tab = _ExplorerTab.readings;

  @override
  void initState() {
    super.initState();
    _readingIds = {...widget.initialSelection.readingIds};
    _scenarioIds = {...widget.initialSelection.scenarioIds};
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  LectorExplorationSelection get _selection => LectorExplorationSelection(
    readingIds: _readingIds,
    scenarioIds: _scenarioIds,
  );

  @override
  Widget build(BuildContext context) {
    final selection = _selection;
    final resultCount = widget.resultCountFor(selection);
    final usesProfile = selection.matchesProfile(widget.profile);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.surfaces.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
        border: Border.all(color: context.surfaces.border),
        boxShadow: [
          BoxShadow(
            color: context.surfaces.shadow.withValues(alpha: 0.34),
            blurRadius: 28,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xs),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.textColors.secondary.withValues(alpha: 0.66),
              borderRadius: BorderRadius.circular(AppRadius.chip),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
            child: _ExplorerHeader(
              usesProfile: usesProfile,
              onClose: () => Navigator.of(context).pop(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<_ExplorerTab>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: _ExplorerTab.readings,
                        icon: const Icon(Icons.auto_stories_outlined),
                        label: Text('Lectures · ${_readingIds.length}'),
                      ),
                      ButtonSegment(
                        value: _ExplorerTab.scenarios,
                        icon: const Icon(Icons.track_changes_rounded),
                        label: Text('Scénarios · ${_scenarioIds.length}'),
                      ),
                    ],
                    selected: {_tab},
                    onSelectionChanged: (selection) {
                      setState(() => _tab = selection.first);
                    },
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: _tab == _ExplorerTab.readings
                        ? 'Rechercher une lecture'
                        : 'Rechercher un scénario',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Effacer la recherche',
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _tab == _ExplorerTab.readings
                  ? _ReadingExplorerList(
                      key: const ValueKey('explorer-readings'),
                      query: _searchController.text,
                      selectedIds: _readingIds,
                      onToggle: _toggleReading,
                    )
                  : _ScenarioExplorerList(
                      key: const ValueKey('explorer-scenarios'),
                      query: _searchController.text,
                      selectedIds: _scenarioIds,
                      onToggle: _toggleScenario,
                    ),
            ),
          ),
          _ExplorerFooter(
            resultCount: resultCount,
            activeFilterCount: selection.activeFilterCount,
            usesProfile: usesProfile,
            onReset: usesProfile ? null : _resetToProfile,
            onApply: () => Navigator.of(context).pop(selection),
          ),
        ],
      ),
    );
  }

  void _toggleReading(String id) {
    setState(() {
      _readingIds.contains(id) ? _readingIds.remove(id) : _readingIds.add(id);
    });
  }

  void _toggleScenario(String id) {
    setState(() {
      _scenarioIds.contains(id)
          ? _scenarioIds.remove(id)
          : _scenarioIds.add(id);
    });
  }

  void _resetToProfile() {
    final profileSelection = LectorExplorationSelection.fromProfile(
      widget.profile,
    );
    setState(() {
      _readingIds = {...profileSelection.readingIds};
      _scenarioIds = {...profileSelection.scenarioIds};
    });
  }
}

class _ExplorerHeader extends StatelessWidget {
  const _ExplorerHeader({required this.usesProfile, required this.onClose});

  final bool usesProfile;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: context.brand.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.input),
            border: Border.all(
              color: context.brand.accent.withValues(alpha: 0.4),
            ),
          ),
          child: SizedBox.square(
            dimension: 42,
            child: Icon(
              Icons.filter_alt_outlined,
              color: context.brand.accent,
              size: 23,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EXPLORATION RAPIDE',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: context.brand.accent,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.7,
                ),
              ),
              Text(
                'Changer les propositions',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: context.textColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                usesProfile
                    ? 'Sélection actuelle de votre profil.'
                    : 'Filtres temporaires · votre profil reste inchangé.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: context.textColors.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Fermer',
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }
}

class _ReadingExplorerList extends StatelessWidget {
  const _ReadingExplorerList({
    required this.query,
    required this.selectedIds,
    required this.onToggle,
    super.key,
  });

  final String query;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = query.trim().toLowerCase();
    final definitions = ReadingPreferenceCatalog.values
        .where((definition) {
          return normalizedQuery.isEmpty ||
              definition.label.toLowerCase().contains(normalizedQuery) ||
              definition.description.toLowerCase().contains(normalizedQuery);
        })
        .toList(growable: false);

    return _ExplorerList(
      emptyLabel: 'Aucune lecture ne correspond à cette recherche.',
      children: [
        for (final definition in definitions)
          _ExplorerOptionTile(
            icon: context.opportunities
                .readingIdentityForId(definition.id)
                .icon,
            title: definition.label,
            subtitle: definition.description,
            color: context.opportunities
                .readingIdentityForId(definition.id)
                .color,
            isSelected: selectedIds.contains(definition.id),
            onTap: () => onToggle(definition.id),
          ),
      ],
    );
  }
}

class _ScenarioExplorerList extends StatelessWidget {
  const _ScenarioExplorerList({
    required this.query,
    required this.selectedIds,
    required this.onToggle,
    super.key,
  });

  final String query;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = query.trim().toLowerCase();
    final definitions = OpportunityProfileCatalog.values
        .where((definition) {
          return normalizedQuery.isEmpty ||
              definition.displayLabel.toLowerCase().contains(normalizedQuery) ||
              definition.description.toLowerCase().contains(normalizedQuery);
        })
        .toList(growable: false);
    final color = context.strategies.violetStyle.color;

    return _ExplorerList(
      emptyLabel: 'Aucun scénario ne correspond à cette recherche.',
      children: [
        for (final definition in definitions)
          _ExplorerOptionTile(
            icon: Icons.track_changes_rounded,
            title: definition.displayLabel,
            subtitle: definition.isSupported
                ? definition.description
                : 'Indisponible avec les données actuelles.',
            color: color,
            isSelected: selectedIds.contains(definition.id),
            isEnabled:
                definition.isSupported || selectedIds.contains(definition.id),
            onTap: () => onToggle(definition.id),
          ),
      ],
    );
  }
}

class _ExplorerList extends StatelessWidget {
  const _ExplorerList({required this.children, required this.emptyLabel});

  final List<Widget> children;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            emptyLabel,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.textColors.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      itemCount: children.length,
      separatorBuilder: (_, _) => const SizedBox(height: 7),
      itemBuilder: (_, index) => children[index],
    );
  }
}

class _ExplorerOptionTile extends StatelessWidget {
  const _ExplorerOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.isSelected,
    required this.onTap,
    this.isEnabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = isEnabled ? color : context.textColors.disabled;
    return Material(
      color: isSelected
          ? effectiveColor.withValues(alpha: 0.1)
          : context.surfaces.surfaceHover.withValues(alpha: 0.38),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        side: BorderSide(
          color: isSelected
              ? effectiveColor.withValues(alpha: 0.52)
              : context.surfaces.border,
        ),
      ),
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: effectiveColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                child: SizedBox.square(
                  dimension: 34,
                  child: Icon(icon, color: effectiveColor, size: 19),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: isEnabled
                            ? context.textColors.primary
                            : context.textColors.disabled,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isEnabled
                            ? context.textColors.secondary
                            : context.textColors.disabled,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.add_circle_outline_rounded,
                color: effectiveColor,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExplorerFooter extends StatelessWidget {
  const _ExplorerFooter({
    required this.resultCount,
    required this.activeFilterCount,
    required this.usesProfile,
    required this.onReset,
    required this.onApply,
  });

  final int resultCount;
  final int activeFilterCount;
  final bool usesProfile;
  final VoidCallback? onReset;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.surfaces.backgroundSecondary,
        border: Border(top: BorderSide(color: context.surfaces.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$activeFilterCount filtre${activeFilterCount > 1 ? 's' : ''} actif${activeFilterCount > 1 ? 's' : ''}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: context.textColors.secondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (!usesProfile)
                      TextButton(
                        onPressed: onReset,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 28),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Réinitialiser'),
                      ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: onApply,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: Text(
                  'Voir $resultCount rencontre${resultCount == 1 ? '' : 's'}',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _sameIds(Set<String> left, Iterable<String> right) {
  final rightSet = right.toSet();
  return left.length == rightSet.length && left.containsAll(rightSet);
}
