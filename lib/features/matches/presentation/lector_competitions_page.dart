import 'package:flutter/material.dart';

import '../../../core/theme/app_components.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../onboarding/domain/decision_profile.dart';
import '../../onboarding/domain/decision_profile_catalogs.dart';
import 'lector_preferences_sheet.dart';
import 'widgets/sports_asset_badge.dart';

class LectorCompetitionsPage extends StatefulWidget {
  const LectorCompetitionsPage({
    required this.profile,
    required this.onProfileChanged,
    super.key,
  });

  final DecisionProfile profile;
  final ProfilePreferenceSaver onProfileChanged;

  @override
  State<LectorCompetitionsPage> createState() => _LectorCompetitionsPageState();
}

class _LectorCompetitionsPageState extends State<LectorCompetitionsPage> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _expandedCountryCodes = {};

  late DecisionProfile _profile;
  late Set<String> _selectedIds;
  bool _showAllFollowed = false;
  bool _isSaving = false;
  int _saveSerial = 0;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    _selectedIds = _selectedCompetitionIds(widget.profile);
    _expandSelectedCountries();
  }

  @override
  void didUpdateWidget(covariant LectorCompetitionsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile != widget.profile) {
      _profile = widget.profile;
      _selectedIds = _selectedCompetitionIds(widget.profile);
      _expandSelectedCountries();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _normalizedQuery;
    final selectedCompetitions = _filteredCompetitions(
      RuntimeCompetitionCatalog.values
          .where((competition) => _selectedIds.contains(competition.id))
          .toList(),
      query,
    );
    final groupedCompetitions = _groupCompetitions(
      _filteredCompetitions(RuntimeCompetitionCatalog.values, query),
    );

    return Scaffold(
      backgroundColor: context.surfaces.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
          children: [
            _CompetitionsHeader(
              count: _selectedIds.length,
              isSaving: _isSaving,
              onBack: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: AppSpacing.md),
            _CompetitionSearchField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.lg),
            _SectionIntro(
              title: 'Suivies',
              count: _selectedIds.length,
              subtitle: 'Vos compétitions suivies apparaissent en premier.',
            ),
            const SizedBox(height: AppSpacing.xs),
            _FollowedCompetitionsCard(
              competitions: selectedCompetitions,
              totalSelectedCount: _selectedIds.length,
              query: query,
              showAll: _showAllFollowed || query.isNotEmpty,
              selectedIds: _selectedIds,
              onToggleShowAll: () {
                setState(() {
                  _showAllFollowed = !_showAllFollowed;
                });
              },
              onToggleCompetition: _toggleCompetition,
            ),
            const SizedBox(height: AppSpacing.lg),
            Divider(height: 1, color: context.surfaces.border),
            const SizedBox(height: AppSpacing.lg),
            const _SectionIntro(
              title: 'Toutes les compétitions',
              subtitle: 'Parcourir et ajouter d’autres compétitions.',
            ),
            const SizedBox(height: AppSpacing.xs),
            if (groupedCompetitions.isEmpty)
              const _CompetitionsEmptyState()
            else
              _CountryGroupList(
                groups: groupedCompetitions,
                selectedIds: _selectedIds,
                expandedCountryCodes: _expandedCountryCodes,
                query: query,
                onToggleCountry: _toggleCountry,
                onToggleCompetition: _toggleCompetition,
              ),
            const SizedBox(height: AppSpacing.lg),
            const _CompetitionsInfoCard(),
          ],
        ),
      ),
    );
  }

  String get _normalizedQuery => _searchController.text.trim().toLowerCase();

  void _expandSelectedCountries() {
    for (final competition in RuntimeCompetitionCatalog.values) {
      if (_selectedIds.contains(competition.id)) {
        _expandedCountryCodes.add(competition.countryCode);
      }
    }
  }

  void _toggleCountry(String countryCode) {
    setState(() {
      if (_expandedCountryCodes.contains(countryCode)) {
        _expandedCountryCodes.remove(countryCode);
      } else {
        _expandedCountryCodes.add(countryCode);
      }
    });
  }

  void _toggleCompetition(DecisionCompetitionDefinition competition) {
    if (_isSaving) {
      return;
    }

    final previousIds = {..._selectedIds};
    final nextIds = {..._selectedIds};
    if (nextIds.contains(competition.id)) {
      nextIds.remove(competition.id);
    } else {
      nextIds.add(competition.id);
      _expandedCountryCodes.add(competition.countryCode);
    }

    setState(() {
      _selectedIds = nextIds;
      _isSaving = true;
    });
    _persistSelection(nextIds, previousIds);
  }

  Future<void> _persistSelection(
    Set<String> selectedIds,
    Set<String> previousIds,
  ) async {
    final serial = ++_saveSerial;
    final orderedIds = [
      for (final competition in RuntimeCompetitionCatalog.values)
        if (selectedIds.contains(competition.id)) competition.id,
    ];
    final updatedProfile = _profile.withOptionIds('competitions', orderedIds);

    try {
      await widget.onProfileChanged(updatedProfile);
      if (!mounted || serial != _saveSerial) {
        return;
      }
      setState(() {
        _profile = updatedProfile;
        _isSaving = false;
      });
    } catch (_) {
      if (!mounted || serial != _saveSerial) {
        return;
      }
      setState(() {
        _selectedIds = previousIds;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de mettre à jour vos compétitions.'),
        ),
      );
    }
  }
}

class _CompetitionsHeader extends StatelessWidget {
  const _CompetitionsHeader({
    required this.count,
    required this.isSaving,
    required this.onBack,
  });

  final int count;
  final bool isSaving;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: IconButton(
            tooltip: 'Retour',
            onPressed: onBack,
            icon: const Icon(Icons.chevron_left_rounded, size: 26),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mes compétitions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Choisissez les championnats que vous souhaitez suivre.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.textColors.secondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _HeaderCountBadge(count: count, isSaving: isSaving),
      ],
    );
  }
}

class _HeaderCountBadge extends StatelessWidget {
  const _HeaderCountBadge({required this.count, required this.isSaving});

  final int count;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    final accent = context.brand.accent;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        shape: BoxShape.circle,
        border: Border.all(color: accent.withValues(alpha: 0.50)),
      ),
      child: SizedBox.square(
        dimension: 34,
        child: Center(
          child: isSaving
              ? SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: accent,
                  ),
                )
              : Text(
                  '$count',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w900,
                  ),
                ),
        ),
      ),
    );
  }
}

class _CompetitionSearchField extends StatelessWidget {
  const _CompetitionSearchField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: Theme.of(context).textTheme.titleSmall,
      decoration: InputDecoration(
        hintText: 'Rechercher une compétition ou un pays',
        hintStyle: TextStyle(color: context.textColors.secondary),
        prefixIcon: Icon(Icons.search_rounded, color: context.textColors.weak),
        filled: true,
        fillColor: context.surfaces.surface.withValues(alpha: 0.70),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: context.surfaces.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: context.surfaces.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: context.brand.accent),
        ),
      ),
    );
  }
}

class _SectionIntro extends StatelessWidget {
  const _SectionIntro({required this.title, this.count, this.subtitle});

  final String title;
  final int? count;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
            children: [
              TextSpan(text: title),
              if (count != null) ...[
                TextSpan(
                  text: ' · ',
                  style: TextStyle(color: context.textColors.primary),
                ),
                TextSpan(
                  text: '$count',
                  style: TextStyle(color: context.brand.accent),
                ),
              ],
            ],
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.textColors.secondary,
              height: 1.3,
            ),
          ),
        ],
      ],
    );
  }
}

class _FollowedCompetitionsCard extends StatelessWidget {
  const _FollowedCompetitionsCard({
    required this.competitions,
    required this.totalSelectedCount,
    required this.query,
    required this.showAll,
    required this.selectedIds,
    required this.onToggleShowAll,
    required this.onToggleCompetition,
  });

  static const _collapsedLimit = 6;

  final List<DecisionCompetitionDefinition> competitions;
  final int totalSelectedCount;
  final String query;
  final bool showAll;
  final Set<String> selectedIds;
  final VoidCallback onToggleShowAll;
  final ValueChanged<DecisionCompetitionDefinition> onToggleCompetition;

  @override
  Widget build(BuildContext context) {
    if (totalSelectedCount == 0) {
      return const _InlineEmptyCard(
        title: 'Aucune compétition suivie',
        subtitle: 'Ajoutez vos premiers championnats depuis la liste par pays.',
      );
    }

    if (competitions.isEmpty) {
      return const _InlineEmptyCard(
        title: 'Aucune compétition suivie ne correspond',
        subtitle: 'Essayez un autre nom de compétition ou de pays.',
      );
    }

    final visibleCompetitions = showAll
        ? competitions
        : competitions.take(_collapsedLimit).toList();
    final hiddenCount = competitions.length - visibleCompetitions.length;

    return _LectorSurface(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final entry in visibleCompetitions.indexed) ...[
            _CompetitionRow(
              competition: entry.$2,
              isSelected: selectedIds.contains(entry.$2.id),
              onTap: () => onToggleCompetition(entry.$2),
            ),
            if (entry.$1 != visibleCompetitions.length - 1 || hiddenCount > 0)
              Divider(height: 1, indent: 52, color: context.surfaces.border),
          ],
          if (hiddenCount > 0)
            _ShowMoreRow(
              hiddenCount: hiddenCount,
              isExpanded: showAll,
              onTap: onToggleShowAll,
            )
          else if (showAll &&
              query.isEmpty &&
              competitions.length > _collapsedLimit)
            _ShowMoreRow(
              hiddenCount: 0,
              isExpanded: showAll,
              onTap: onToggleShowAll,
            ),
        ],
      ),
    );
  }
}

class _CountryGroupList extends StatelessWidget {
  const _CountryGroupList({
    required this.groups,
    required this.selectedIds,
    required this.expandedCountryCodes,
    required this.query,
    required this.onToggleCountry,
    required this.onToggleCompetition,
  });

  final List<_CompetitionCountryGroup> groups;
  final Set<String> selectedIds;
  final Set<String> expandedCountryCodes;
  final String query;
  final ValueChanged<String> onToggleCountry;
  final ValueChanged<DecisionCompetitionDefinition> onToggleCompetition;

  @override
  Widget build(BuildContext context) {
    return _LectorSurface(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final groupEntry in groups.indexed) ...[
            _CountryGroupSection(
              group: groupEntry.$2,
              selectedIds: selectedIds,
              isExpanded:
                  query.isNotEmpty ||
                  expandedCountryCodes.contains(groupEntry.$2.country.code),
              onToggleCountry: () =>
                  onToggleCountry(groupEntry.$2.country.code),
              onToggleCompetition: onToggleCompetition,
            ),
            if (groupEntry.$1 != groups.length - 1)
              Divider(
                height: 1,
                indent: AppSpacing.md,
                color: context.surfaces.border,
              ),
          ],
        ],
      ),
    );
  }
}

class _CountryGroupSection extends StatelessWidget {
  const _CountryGroupSection({
    required this.group,
    required this.selectedIds,
    required this.isExpanded,
    required this.onToggleCountry,
    required this.onToggleCompetition,
  });

  final _CompetitionCountryGroup group;
  final Set<String> selectedIds;
  final bool isExpanded;
  final VoidCallback onToggleCountry;
  final ValueChanged<DecisionCompetitionDefinition> onToggleCompetition;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onToggleCountry,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  SportsAssetBadge(
                    size: 28,
                    imageUrl: group.country.flagUrl,
                    fallbackLabel: group.country.code,
                    borderRadius: 5,
                    padding: 0,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      group.country.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    _competitionCountLabel(group.competitions.length),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.textColors.secondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: context.textColors.secondary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: _NestedCompetitionList(
              competitions: group.competitions,
              selectedIds: selectedIds,
              onToggleCompetition: onToggleCompetition,
            ),
          ),
      ],
    );
  }
}

class _NestedCompetitionList extends StatelessWidget {
  const _NestedCompetitionList({
    required this.competitions,
    required this.selectedIds,
    required this.onToggleCompetition,
  });

  final List<DecisionCompetitionDefinition> competitions;
  final Set<String> selectedIds;
  final ValueChanged<DecisionCompetitionDefinition> onToggleCompetition;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.surfaces.backgroundSecondary.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: context.surfaces.border),
      ),
      child: Column(
        children: [
          for (final entry in competitions.indexed) ...[
            _CompetitionRow(
              competition: entry.$2,
              isSelected: selectedIds.contains(entry.$2.id),
              compact: true,
              onTap: () => onToggleCompetition(entry.$2),
            ),
            if (entry.$1 != competitions.length - 1)
              Divider(height: 1, indent: 48, color: context.surfaces.border),
          ],
        ],
      ),
    );
  }
}

class _CompetitionRow extends StatelessWidget {
  const _CompetitionRow({
    required this.competition,
    required this.isSelected,
    required this.onTap,
    this.compact = false,
  });

  final DecisionCompetitionDefinition competition;
  final bool isSelected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('lector-competition-${competition.id}'),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? AppSpacing.xs : AppSpacing.sm,
            vertical: compact ? AppSpacing.xs : 10,
          ),
          child: Row(
            children: [
              SportsAssetBadge(
                size: compact ? 28 : 32,
                imageUrl: competition.logoUrl,
                fallbackLabel: competition.name,
                borderRadius: 7,
                padding: 2,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      competition.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      competition.countryName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.textColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _SelectionMark(isSelected: isSelected),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionMark extends StatelessWidget {
  const _SelectionMark({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final accent = context.brand.accent;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: isSelected ? accent : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(
          color: isSelected ? accent : context.surfaces.border,
          width: 1.4,
        ),
      ),
      child: isSelected
          ? Icon(
              Icons.check_rounded,
              color: Theme.of(context).colorScheme.onPrimary,
              size: 18,
            )
          : Icon(
              Icons.add_rounded,
              color: context.textColors.secondary,
              size: 17,
            ),
    );
  }
}

class _ShowMoreRow extends StatelessWidget {
  const _ShowMoreRow({
    required this.hiddenCount,
    required this.isExpanded,
    required this.onTap,
  });

  final int hiddenCount;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = isExpanded
        ? 'Réduire'
        : 'Afficher $hiddenCount autre${hiddenCount > 1 ? 's' : ''}';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: context.brand.accent,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                isExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: context.brand.accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineEmptyCard extends StatelessWidget {
  const _InlineEmptyCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return _LectorSurface(
      child: Row(
        children: [
          Icon(Icons.emoji_events_outlined, color: context.brand.accent),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.textColors.secondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompetitionsEmptyState extends StatelessWidget {
  const _CompetitionsEmptyState();

  @override
  Widget build(BuildContext context) {
    return const _InlineEmptyCard(
      title: 'Aucune compétition trouvée',
      subtitle: 'Essayez un autre nom ou un autre pays.',
    );
  }
}

class _CompetitionsInfoCard extends StatelessWidget {
  const _CompetitionsInfoCard();

  @override
  Widget build(BuildContext context) {
    return _LectorSurface(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.brand.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Icon(
              Icons.lightbulb_outline_rounded,
              color: context.brand.accent,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pourquoi suivre des compétitions ?',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Lector utilise ces compétitions pour savoir quelles rencontres peuvent entrer dans “Pour moi”.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.textColors.secondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(Icons.chevron_right_rounded, color: context.brand.accent),
        ],
      ),
    );
  }
}

class _LectorSurface extends StatelessWidget {
  const _LectorSurface({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.sm),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.surfaces.surface.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.surfaces.border),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _CompetitionCountryGroup {
  const _CompetitionCountryGroup({
    required this.country,
    required this.competitions,
  });

  final CompetitionCountryDefinition country;
  final List<DecisionCompetitionDefinition> competitions;
}

List<DecisionCompetitionDefinition> _filteredCompetitions(
  Iterable<DecisionCompetitionDefinition> competitions,
  String query,
) {
  if (query.isEmpty) {
    return competitions.toList();
  }

  return [
    for (final competition in competitions)
      if (competition.name.toLowerCase().contains(query) ||
          competition.countryName.toLowerCase().contains(query))
        competition,
  ];
}

List<_CompetitionCountryGroup> _groupCompetitions(
  List<DecisionCompetitionDefinition> competitions,
) {
  final grouped = <String, List<DecisionCompetitionDefinition>>{};
  for (final competition in competitions) {
    grouped.putIfAbsent(competition.countryCode, () => []).add(competition);
  }

  return [
    for (final entry in grouped.entries)
      _CompetitionCountryGroup(
        country: entry.value.first.country,
        competitions: entry.value,
      ),
  ]..sort((a, b) => a.country.name.compareTo(b.country.name));
}

Set<String> _selectedCompetitionIds(DecisionProfile profile) {
  return {
    for (final id in profile.optionIdsFor('competitions'))
      if (RuntimeCompetitionCatalog.resolveId(id) != null)
        RuntimeCompetitionCatalog.resolveId(id)!,
  };
}

String _competitionCountLabel(int count) {
  if (count == 1) {
    return '1 compétition';
  }

  return '$count compétitions';
}
