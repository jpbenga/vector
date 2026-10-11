import '../../../core/widgets/lector_horizontal_transition.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_components.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/lector_responsive_layout.dart';
import '../../onboarding/domain/decision_profile.dart';
import '../../onboarding/domain/decision_profile_catalogs.dart';
import 'lector_guide_page.dart';
import 'widgets/sports_asset_badge.dart';

typedef ProfilePreferenceSaver = Future<void> Function(DecisionProfile profile);

class _PreferenceScale {
  static const sheetHorizontalPadding = 14.0;
  static const sheetBottomPadding = 14.0;
  static const rowHorizontalPadding = 10.0;
  static const rowVerticalPadding = 8.0;
  static const editorHeightFactor = 0.84;
  static const rowRadius = AppRadius.odds;
  static const rowGap = AppSpacing.xxs;
  static const compactButtonHeight = 40.0;
  static const logoSize = 28.0;
  static const iconSize = 20.0;
  static const switchScale = 0.78;

  const _PreferenceScale._();
}

Future<void> showCompetitionPreferencesSheet({
  required BuildContext context,
  required DecisionProfile profile,
  required ProfilePreferenceSaver onProfileChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    sheetAnimationStyle: lectorSheetAnimationStyle(context),
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return _CompetitionPreferencesEditor(
        profile: profile,
        onProfileChanged: onProfileChanged,
      );
    },
  );
}

Future<void> showReadingPreferencesSheet({
  required BuildContext context,
  required DecisionProfile profile,
  required ProfilePreferenceSaver onProfileChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    sheetAnimationStyle: lectorSheetAnimationStyle(context),
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return _ReadingPreferencesEditor(
        profile: profile,
        onProfileChanged: onProfileChanged,
      );
    },
  );
}

Future<void> showMarketPreferencesSheet({
  required BuildContext context,
  required DecisionProfile profile,
  required ProfilePreferenceSaver onProfileChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    sheetAnimationStyle: lectorSheetAnimationStyle(context),
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return _MarketPreferencesEditor(
        profile: profile,
        onProfileChanged: onProfileChanged,
      );
    },
  );
}

class _CompetitionPreferencesEditor extends StatefulWidget {
  const _CompetitionPreferencesEditor({
    required this.profile,
    required this.onProfileChanged,
  });

  final DecisionProfile profile;
  final ProfilePreferenceSaver onProfileChanged;

  @override
  State<_CompetitionPreferencesEditor> createState() =>
      _CompetitionPreferencesEditorState();
}

class _CompetitionPreferencesEditorState
    extends State<_CompetitionPreferencesEditor> {
  final TextEditingController _searchController = TextEditingController();
  late Set<String> _selectedIds;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedIds = _selectedCompetitionIds(widget.profile);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final competitions = RuntimeCompetitionCatalog.values.where((competition) {
      if (query.isEmpty) {
        return true;
      }

      return competition.name.toLowerCase().contains(query) ||
          competition.countryName.toLowerCase().contains(query);
    }).toList();

    return _PreferenceEditorScaffold(
      title: 'Championnats suivis',
      subtitle:
          '${RuntimeCompetitionCatalog.values.length} championnats disponibles. Cette sélection nourrit Pour moi, Tous reste inchangé.',
      isSaving: _isSaving,
      selectedCount: _selectedIds.length,
      onClear: _selectedIds.isEmpty
          ? null
          : () {
              setState(_selectedIds.clear);
            },
      onSave: _save,
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            style: Theme.of(context).textTheme.bodySmall,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              prefixIconConstraints: BoxConstraints.tightFor(
                width: 38,
                height: 38,
              ),
              hintText: 'Rechercher un championnat ou un pays',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Expanded(
            child: competitions.isEmpty
                ? const _PreferenceEmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Aucun championnat trouvé',
                    subtitle: 'Essayez un autre nom ou un autre pays.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    itemCount: competitions.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: _PreferenceScale.rowGap),
                    itemBuilder: (context, index) {
                      final competition = competitions[index];
                      final isSelected = _selectedIds.contains(competition.id);

                      return _PreferenceToggleTile(
                        icon: Icons.emoji_events_outlined,
                        imageUrl: competition.logoUrl,
                        fallbackLabel: competition.name,
                        contrastPlate: true,
                        title: competition.name,
                        subtitle: competition.countryName,
                        isSelected: isSelected,
                        onChanged: (value) {
                          setState(() {
                            if (value) {
                              _selectedIds.add(competition.id);
                            } else {
                              _selectedIds.remove(competition.id);
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
    });
    final orderedIds = [
      for (final competition in RuntimeCompetitionCatalog.values)
        if (_selectedIds.contains(competition.id)) competition.id,
    ];
    await widget.onProfileChanged(
      widget.profile.withOptionIds('competitions', orderedIds),
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }
}

class _ReadingPreferencesEditor extends StatefulWidget {
  const _ReadingPreferencesEditor({
    required this.profile,
    required this.onProfileChanged,
  });

  final DecisionProfile profile;
  final ProfilePreferenceSaver onProfileChanged;

  @override
  State<_ReadingPreferencesEditor> createState() =>
      _ReadingPreferencesEditorState();
}

class _ReadingPreferencesEditorState extends State<_ReadingPreferencesEditor> {
  final TextEditingController _searchController = TextEditingController();
  late Set<String> _selectedIds;
  bool _isSaving = false;
  bool _showSelectedOnly = false;
  String? _expandedGroupId = 'ranking_form';

  @override
  void initState() {
    super.initState();
    _selectedIds = ReadingPreferenceCatalog.normalizeSelectionIds(
      widget.profile.optionIdsFor('readings'),
    );
    if (_selectedIds.remove('home_away_mismatch')) {
      _selectedIds.addAll({'home_away_advantage', 'away_home_advantage'});
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final selectedCount = ReadingPreferenceCatalog.values
        .where((reading) => _selectedIds.contains(reading.id))
        .length;
    final visibleGroups = [
      for (final group in _readingPreferenceGroups)
        (
          group: group,
          readings: group.readings
              .where((reading) {
                if (_showSelectedOnly && !_selectedIds.contains(reading.id)) {
                  return false;
                }
                return query.isEmpty ||
                    reading.label.toLowerCase().contains(query) ||
                    reading.description.toLowerCase().contains(query) ||
                    group.label.toLowerCase().contains(query);
              })
              .toList(growable: false),
        ),
    ]..removeWhere((entry) => entry.readings.isEmpty);

    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: _PreferenceScale.editorHeightFactor,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            _PreferenceScale.sheetHorizontalPadding,
            0,
            _PreferenceScale.sheetHorizontalPadding,
            _PreferenceScale.sheetBottomPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ReadingPreferencesHeader(count: selectedCount),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: ListView(
                  children: [
                    _ReadingSelectionSummary(
                      count: selectedCount,
                      isActive: _showSelectedOnly,
                      onTap: () => setState(
                        () => _showSelectedOnly = !_showSelectedOnly,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      key: const ValueKey('reading-search'),
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Rechercher une lecture',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Effacer la recherche',
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                        filled: true,
                        fillColor: context.surfaces.surface.withValues(
                          alpha: 0.70,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.input),
                          borderSide: BorderSide(
                            color: context.surfaces.border,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _ReadingSectionHeading(
                      title: query.isNotEmpty
                          ? 'Résultats'
                          : _showSelectedOnly
                          ? 'Lectures suivies'
                          : 'Parcourir par thème',
                      count: query.isNotEmpty
                          ? visibleGroups.fold<int>(
                              0,
                              (sum, entry) => sum + entry.readings.length,
                            )
                          : _showSelectedOnly
                          ? selectedCount
                          : _readingPreferenceGroups.length,
                      onSelectAll:
                          _isSaving ||
                              selectedCount ==
                                  ReadingPreferenceCatalog.values.length
                          ? null
                          : () => setState(() {
                              _selectedIds.addAll(
                                ReadingPreferenceCatalog.values.map(
                                  (reading) => reading.id,
                                ),
                              );
                            }),
                      onDeselectAll: _isSaving || selectedCount == 0
                          ? null
                          : () => setState(_selectedIds.clear),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    if (visibleGroups.isEmpty)
                      const _PreferenceEmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'Aucune lecture trouvée',
                        subtitle:
                            'Essayez un autre terme ou affichez toutes les lectures.',
                      )
                    else
                      for (final entry in visibleGroups) ...[
                        _ReadingGroupCard(
                          group: entry.group,
                          readings: entry.readings,
                          selectedIds: _selectedIds,
                          isExpanded:
                              query.isNotEmpty ||
                              _expandedGroupId == entry.group.id,
                          isSaving: _isSaving,
                          onToggleExpanded: () => setState(() {
                            _expandedGroupId =
                                _expandedGroupId == entry.group.id
                                ? null
                                : entry.group.id;
                          }),
                          onSelectGroup: () => setState(() {
                            _selectedIds.addAll(
                              entry.group.readings.map((reading) => reading.id),
                            );
                          }),
                          onDeselectGroup: () => setState(() {
                            _selectedIds.removeAll(
                              entry.group.readings.map((reading) => reading.id),
                            );
                          }),
                          onToggleReading: (reading) => setState(() {
                            if (!_selectedIds.add(reading.id)) {
                              _selectedIds.remove(reading.id);
                            }
                          }),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              SizedBox(
                height: _PreferenceScale.compactButtonHeight,
                child: FilledButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Enregistrer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
    });
    final orderedIds = [
      for (final reading in ReadingPreferenceCatalog.values)
        if (_selectedIds.contains(reading.id)) reading.id,
    ];
    await widget.onProfileChanged(
      widget.profile.withOptionIds('readings', orderedIds),
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }
}

IconData _readingPreferenceIcon(String readingId) {
  return switch (readingId) {
    'winning_streak' ||
    'home_winning_streak' ||
    'away_winning_streak' ||
    'positive_streak' ||
    'improving_form' ||
    'form_gap' => Icons.trending_up_rounded,
    'head_to_head_dominance' => Icons.handshake_outlined,
    'negative_streak' || 'declining_form' => Icons.trending_down_rounded,
    'prolific_attack' || 'scoring_difficulty' => Icons.sports_soccer_rounded,
    'solid_defense' ||
    'fragile_defense' ||
    'frequent_clean_sheet' => Icons.shield_outlined,
    'open_match_profile' ||
    'frequent_over_25' ||
    'frequent_btts' => Icons.local_fire_department_outlined,
    'closed_match_profile' || 'frequent_under_25' => Icons.lock_outline,
    'high_xg_creation' ||
    'low_xg_creation' ||
    'high_xg_conceded' => Icons.query_stats_rounded,
    'frequent_first_half_scoring' ||
    'frequent_first_half_conceding' ||
    'frequent_second_half_scoring' ||
    'frequent_second_half_conceding' => Icons.timelapse_rounded,
    _ => Icons.insights_outlined,
  };
}

class _ReadingPreferenceGroup {
  const _ReadingPreferenceGroup({
    required this.id,
    required this.label,
    required this.icon,
    required this.ids,
  });

  final String id;
  final String label;
  final IconData icon;
  final Set<String> ids;

  List<ReadingPreferenceDefinition> get readings => [
    for (final reading in ReadingPreferenceCatalog.values)
      if (ids.contains(reading.id)) reading,
  ];
}

List<_ReadingPreferenceGroup> get _readingPreferenceGroups {
  final classifiedIds = {
    for (final category in ReadingPreferenceCategoryCatalog.values)
      ...category.readingIds,
  };
  final otherIds = {
    for (final reading in ReadingPreferenceCatalog.values)
      if (!classifiedIds.contains(reading.id)) reading.id,
  };
  return [
    for (final category in ReadingPreferenceCategoryCatalog.values)
      _ReadingPreferenceGroup(
        id: category.id,
        label: category.label,
        icon: _readingPreferenceCategoryIcon(category.id),
        ids: category.readingIds.toSet(),
      ),
    if (otherIds.isNotEmpty)
      _ReadingPreferenceGroup(
        id: 'other',
        label: 'Autres lectures',
        icon: Icons.insights_outlined,
        ids: otherIds,
      ),
  ];
}

IconData _readingPreferenceCategoryIcon(String categoryId) {
  return switch (categoryId) {
    'ranking_form' => Icons.trending_up_rounded,
    'attack_defense' => Icons.track_changes_rounded,
    'goals' => Icons.sports_soccer_rounded,
    'match_periods' => Icons.timelapse_rounded,
    'player_statistics' => Icons.person_search_rounded,
    'availability' => Icons.person_off_outlined,
    'context' => Icons.info_outline_rounded,
    _ => Icons.insights_outlined,
  };
}

class _ReadingPreferencesHeader extends StatelessWidget {
  const _ReadingPreferencesHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final accent = context.brand.accent;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mes lectures',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'Choisissez les faits observés que Lector doit rechercher pour vous.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.textColors.secondary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        DecoratedBox(
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            shape: BoxShape.circle,
            border: Border.all(color: accent.withValues(alpha: 0.50)),
          ),
          child: SizedBox.square(
            dimension: 34,
            child: Center(
              child: Text(
                '$count',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReadingSelectionSummary extends StatelessWidget {
  const _ReadingSelectionSummary({
    required this.count,
    required this.isActive,
    required this.onTap,
  });

  final int count;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final identity = context.opportunities.scenarioIdentityForProfileId(
      'ranking_gap',
    );
    final badge = identity.badgeFor(AppReadingBadgeVariant.combined);
    return Material(
      color: isActive
          ? badge.background
          : context.surfaces.surface.withValues(alpha: 0.70),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: badge.border),
      ),
      child: InkWell(
        key: const ValueKey('reading-followed-summary'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: badge.background,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                child: SizedBox.square(
                  dimension: 44,
                  child: Icon(identity.icon, color: badge.iconColor, size: 22),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '$count',
                            style: TextStyle(color: context.brand.accent),
                          ),
                          TextSpan(
                            text:
                                ' lecture${count == 1 ? '' : 's'} suivie${count == 1 ? '' : 's'}',
                          ),
                        ],
                      ),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      isActive
                          ? 'Afficher à nouveau toutes les lectures.'
                          : 'Retrouvez les lectures qui alimentent Pour moi.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.textColors.secondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.chevron_right_rounded, color: badge.iconColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadingSectionHeading extends StatelessWidget {
  const _ReadingSectionHeading({
    required this.title,
    required this.count,
    required this.onSelectAll,
    required this.onDeselectAll,
  });

  final String title;
  final int count;
  final VoidCallback? onSelectAll;
  final VoidCallback? onDeselectAll;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.sm,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '$title · '),
              TextSpan(
                text: '$count',
                style: TextStyle(color: context.brand.accent),
              ),
            ],
          ),
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        Wrap(
          spacing: AppSpacing.xs,
          children: [
            TextButton(
              key: const ValueKey('reading-select-all'),
              onPressed: onSelectAll,
              child: const Text('Tout sélectionner'),
            ),
            TextButton(
              key: const ValueKey('reading-deselect-all'),
              onPressed: onDeselectAll,
              child: const Text('Tout désélectionner'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReadingGroupCard extends StatelessWidget {
  const _ReadingGroupCard({
    required this.group,
    required this.readings,
    required this.selectedIds,
    required this.isExpanded,
    required this.isSaving,
    required this.onToggleExpanded,
    required this.onSelectGroup,
    required this.onDeselectGroup,
    required this.onToggleReading,
  });

  final _ReadingPreferenceGroup group;
  final List<ReadingPreferenceDefinition> readings;
  final Set<String> selectedIds;
  final bool isExpanded;
  final bool isSaving;
  final VoidCallback onToggleExpanded;
  final VoidCallback onSelectGroup;
  final VoidCallback onDeselectGroup;
  final ValueChanged<ReadingPreferenceDefinition> onToggleReading;

  @override
  Widget build(BuildContext context) {
    final allReadings = group.readings;
    final selectedCount = allReadings
        .where((reading) => selectedIds.contains(reading.id))
        .length;
    final accent = context.brand.accent;

    return Material(
      color: context.surfaces.surface.withValues(alpha: 0.70),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(
          color: isExpanded
              ? accent.withValues(alpha: 0.55)
              : context.surfaces.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            key: ValueKey('reading-category-${group.id}'),
            onTap: onToggleExpanded,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.control),
                      border: Border.all(color: accent.withValues(alpha: 0.35)),
                    ),
                    child: SizedBox.square(
                      dimension: 40,
                      child: Icon(group.icon, color: accent, size: 20),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.label,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          '${allReadings.length} lectures · $selectedCount suivie${selectedCount == 1 ? '' : 's'}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: context.textColors.secondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '$selectedCount/${allReadings.length}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.chevron_right_rounded,
                    color: context.textColors.secondary,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            Divider(height: 1, color: context.surfaces.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: AppSpacing.xs,
                      children: [
                        TextButton(
                          key: ValueKey('reading-select-group-${group.id}'),
                          onPressed:
                              isSaving || selectedCount == allReadings.length
                              ? null
                              : onSelectGroup,
                          child: const Text('Tout sélectionner dans ce thème'),
                        ),
                        TextButton(
                          key: ValueKey('reading-deselect-group-${group.id}'),
                          onPressed: isSaving || selectedCount == 0
                              ? null
                              : onDeselectGroup,
                          child: const Text('Tout retirer'),
                        ),
                      ],
                    ),
                  ),
                  for (final entry in readings.indexed) ...[
                    if (entry.$1 > 0)
                      Divider(height: 1, color: context.surfaces.border),
                    _ReadingChoiceRow(
                      reading: entry.$2,
                      isSelected: selectedIds.contains(entry.$2.id),
                      isSaving: isSaving,
                      onToggle: () => onToggleReading(entry.$2),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReadingChoiceRow extends StatelessWidget {
  const _ReadingChoiceRow({
    required this.reading,
    required this.isSelected,
    required this.isSaving,
    required this.onToggle,
  });

  final ReadingPreferenceDefinition reading;
  final bool isSelected;
  final bool isSaving;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final accent = context.brand.accent;
    return InkWell(
      key: ValueKey('reading-${reading.id}'),
      onTap: isSaving ? null : onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppRadius.control),
                border: Border.all(color: accent.withValues(alpha: 0.28)),
              ),
              child: SizedBox.square(
                dimension: 34,
                child: Icon(
                  _readingPreferenceIcon(reading.id),
                  color: accent,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reading.label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    reading.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.textColors.secondary,
                      height: 1.28,
                    ),
                  ),
                  TextButton(
                    key: ValueKey('reading-guide-${reading.id}'),
                    onPressed: () => openReadingGuide(
                      context,
                      reading.id,
                      isFollowed: isSelected,
                    ),
                    child: const Text('Comprendre cette lecture'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Transform.scale(
              scale: _PreferenceScale.switchScale,
              child: Switch(
                value: isSelected,
                activeThumbColor: context.brand.onAccent,
                activeTrackColor: accent,
                inactiveThumbColor: context.textColors.secondary,
                inactiveTrackColor: context.surfaces.border,
                onChanged: isSaving ? null : (_) => onToggle(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketPreferencesEditor extends StatefulWidget {
  const _MarketPreferencesEditor({
    required this.profile,
    required this.onProfileChanged,
  });

  final DecisionProfile profile;
  final ProfilePreferenceSaver onProfileChanged;

  @override
  State<_MarketPreferencesEditor> createState() =>
      _MarketPreferencesEditorState();
}

class _MarketPreferencesEditorState extends State<_MarketPreferencesEditor> {
  late Set<String> _selectedIds;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedIds = MarketCatalog.sourceOptionIdsFor(
      widget.profile.optionIdsFor('markets'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _PreferenceEditorScaffold(
      title: 'Marchés autorisés',
      subtitle: 'Lector ne recommande que les marchés que vous activez ici.',
      isSaving: _isSaving,
      selectedCount: _selectedIds.length,
      onClear: _selectedIds.isEmpty ? null : () => setState(_selectedIds.clear),
      onSave: _save,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        itemCount: _marketOptions.length,
        separatorBuilder: (_, _) =>
            const SizedBox(height: _PreferenceScale.rowGap),
        itemBuilder: (context, index) {
          final option = _marketOptions[index];
          return _PreferenceToggleTile(
            icon: option.icon,
            title: option.label,
            subtitle: option.description,
            isSelected: _selectedIds.contains(option.id),
            onChanged: (value) {
              setState(() {
                if (value) {
                  _selectedIds.add(option.id);
                } else {
                  _selectedIds.remove(option.id);
                }
              });
            },
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
    });
    await widget.onProfileChanged(
      widget.profile.withOptionIds('markets', [
        for (final option in _marketOptions)
          if (_selectedIds.contains(option.id)) option.id,
      ]),
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }
}

class _MarketPreferenceOption {
  const _MarketPreferenceOption({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
  });

  final String id;
  final String label;
  final String description;
  final IconData icon;
}

const _marketOptions = [
  _MarketPreferenceOption(
    id: 'match_result',
    label: 'Résultat du match',
    description:
        'Victoire de l’équipe à domicile, nul ou victoire à l’extérieur.',
    icon: Icons.emoji_events_outlined,
  ),
  _MarketPreferenceOption(
    id: 'double_chance',
    label: 'Double chance',
    description: 'Deux issues couvertes pour un scénario plus protégé.',
    icon: Icons.shield_outlined,
  ),
  _MarketPreferenceOption(
    id: 'goals_over_under',
    label: 'Total de buts',
    description: 'Scénarios ouverts ou fermés sur le nombre de buts.',
    icon: Icons.sports_soccer_outlined,
  ),
  _MarketPreferenceOption(
    id: 'both_teams_score',
    label: 'Les deux équipes marquent',
    description: 'Lecture offensive favorable aux buts des deux équipes.',
    icon: Icons.swap_horiz_rounded,
  ),
  _MarketPreferenceOption(
    id: 'team_scores',
    label: 'Buts d’une équipe',
    description: 'Total de buts d’une équipe dans le match.',
    icon: Icons.query_stats_rounded,
  ),
  _MarketPreferenceOption(
    id: 'corners',
    label: 'Corners',
    description: 'Marchés de total de corners.',
    icon: Icons.turn_right_rounded,
  ),
  _MarketPreferenceOption(
    id: 'cards',
    label: 'Cartons',
    description: 'Marchés de total de cartons.',
    icon: Icons.style_outlined,
  ),
  _MarketPreferenceOption(
    id: 'player_scorer',
    label: 'Buteur',
    description: 'Marchés individuels lorsqu’ils sont disponibles.',
    icon: Icons.person_outline_rounded,
  ),
];

class _PreferenceEditorScaffold extends StatelessWidget {
  const _PreferenceEditorScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.isSaving,
    required this.selectedCount,
    required this.onClear,
    required this.onSave,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final bool isSaving;
  final int selectedCount;
  final VoidCallback? onClear;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LectorContent(
        child: FractionallySizedBox(
          heightFactor: _PreferenceScale.editorHeightFactor,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              _PreferenceScale.sheetHorizontalPadding,
              0,
              _PreferenceScale.sheetHorizontalPadding,
              _PreferenceScale.sheetBottomPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    Text(
                      '$selectedCount',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: context.brand.accent,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.textColors.secondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                if (onClear != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: onClear,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Réinitialiser'),
                    ),
                  ),
                const SizedBox(height: AppSpacing.xxs),
                Expanded(child: child),
                const SizedBox(height: AppSpacing.xs),
                SizedBox(
                  height: _PreferenceScale.compactButtonHeight,
                  child: FilledButton(
                    onPressed: isSaving ? null : onSave,
                    child: isSaving
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Enregistrer'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreferenceToggleTile extends StatelessWidget {
  const _PreferenceToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onChanged,
    this.imageUrl,
    this.fallbackLabel,
    this.contrastPlate = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final ValueChanged<bool> onChanged;
  final String? imageUrl;
  final String? fallbackLabel;
  final bool contrastPlate;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? context.brand.accent.withValues(alpha: 0.12)
          : context.surfaces.backgroundSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_PreferenceScale.rowRadius),
        side: BorderSide(
          color: isSelected ? context.brand.accent : context.surfaces.border,
        ),
      ),
      child: InkWell(
        onTap: () => onChanged(!isSelected),
        borderRadius: BorderRadius.circular(_PreferenceScale.rowRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: _PreferenceScale.rowHorizontalPadding,
            vertical: _PreferenceScale.rowVerticalPadding,
          ),
          child: Row(
            children: [
              _PreferenceTileLeading(
                icon: icon,
                imageUrl: imageUrl,
                fallbackLabel: fallbackLabel ?? title,
                isSelected: isSelected,
                contrastPlate: contrastPlate,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: context.textColors.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Transform.scale(
                scale: _PreferenceScale.switchScale,
                child: Switch(value: isSelected, onChanged: onChanged),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreferenceTileLeading extends StatelessWidget {
  const _PreferenceTileLeading({
    required this.icon,
    required this.fallbackLabel,
    required this.isSelected,
    this.imageUrl,
    this.contrastPlate = false,
  });

  final IconData icon;
  final String fallbackLabel;
  final bool isSelected;
  final String? imageUrl;
  final bool contrastPlate;

  @override
  Widget build(BuildContext context) {
    final logoUrl = imageUrl;
    if (logoUrl != null && logoUrl.isNotEmpty) {
      return SportsAssetBadge(
        size: _PreferenceScale.logoSize,
        imageUrl: logoUrl,
        fallbackLabel: fallbackLabel,
        icon: icon,
        backgroundColor: contrastPlate ? null : context.surfaces.surface,
        padding: contrastPlate ? null : 2,
        contrastPlate: contrastPlate,
      );
    }

    return Icon(
      icon,
      size: _PreferenceScale.iconSize,
      color: isSelected ? context.brand.accent : context.textColors.secondary,
    );
  }
}

class _PreferenceEmptyState extends StatelessWidget {
  const _PreferenceEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: context.textColors.secondary),
            const SizedBox(height: AppSpacing.sm),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.textColors.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Set<String> _selectedCompetitionIds(DecisionProfile profile) {
  return {
    for (final id in profile.optionIdsFor('competitions'))
      if (RuntimeCompetitionCatalog.resolveId(id) != null)
        RuntimeCompetitionCatalog.resolveId(id)!,
  };
}
