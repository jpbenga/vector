import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_components.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../onboarding/domain/decision_profile.dart';
import '../../onboarding/domain/decision_profile_catalogs.dart';
import 'lector_preferences_sheet.dart';

class LectorScenariosPage extends StatefulWidget {
  const LectorScenariosPage({
    required this.profile,
    required this.onProfileChanged,
    super.key,
  });

  final DecisionProfile profile;
  final ProfilePreferenceSaver onProfileChanged;

  @override
  State<LectorScenariosPage> createState() => _LectorScenariosPageState();
}

class _LectorScenariosPageState extends State<LectorScenariosPage> {
  final TextEditingController _searchController = TextEditingController();

  late DecisionProfile _profile;
  late Set<String> _selectedIds;
  bool _isSaving = false;
  int _saveSerial = 0;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    _selectedIds = widget.profile.optionIdsFor('opportunity_profiles').toSet();
  }

  @override
  void didUpdateWidget(covariant LectorScenariosPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile != widget.profile) {
      _profile = widget.profile;
      _selectedIds = widget.profile
          .optionIdsFor('opportunity_profiles')
          .toSet();
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
    final scenarios = _filteredScenarios(
      OpportunityProfileCatalog.values,
      query,
    );
    final followed = scenarios
        .where((scenario) => _selectedIds.contains(scenario.id))
        .toList();
    final others = scenarios
        .where((scenario) => !_selectedIds.contains(scenario.id))
        .toList();

    return Scaffold(
      backgroundColor: context.surfaces.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
          children: [
            _ScenariosHeader(
              count: _selectedIds.length,
              isSaving: _isSaving,
              onBack: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: AppSpacing.md),
            _ScenarioSummaryCard(count: _selectedIds.length),
            const SizedBox(height: AppSpacing.md),
            _ScenarioSearchField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.lg),
            _SectionIntro(
              title: 'Suivis',
              count: _selectedIds.length,
              subtitle: 'Ces scénarios sont prioritaires pour Lector.',
            ),
            const SizedBox(height: AppSpacing.xs),
            followed.isEmpty
                ? _ScenarioEmptyCard(query: query, isFollowedSection: true)
                : _ScenarioListCard(
                    scenarios: followed,
                    selectedIds: _selectedIds,
                    isSaving: _isSaving,
                    onToggleScenario: _toggleScenario,
                  ),
            const SizedBox(height: AppSpacing.lg),
            const _SectionIntro(
              title: 'Autres scénarios',
              subtitle: 'Lector les utilisera uniquement si vous les activez.',
            ),
            const SizedBox(height: AppSpacing.xs),
            others.isEmpty
                ? _ScenarioEmptyCard(query: query, isFollowedSection: false)
                : _ScenarioListCard(
                    scenarios: others,
                    selectedIds: _selectedIds,
                    isSaving: _isSaving,
                    onToggleScenario: _toggleScenario,
                  ),
            const SizedBox(height: AppSpacing.lg),
            const _ScenariosInfoCard(),
            const SizedBox(height: AppSpacing.lg),
            _AutosaveNotice(isSaving: _isSaving),
          ],
        ),
      ),
    );
  }

  void _toggleScenario(OpportunityProfileDefinition scenario) {
    if (_isSaving || !scenario.isSupported) {
      return;
    }

    final previousIds = {..._selectedIds};
    final nextIds = {..._selectedIds};
    if (nextIds.contains(scenario.id)) {
      nextIds.remove(scenario.id);
    } else {
      nextIds.add(scenario.id);
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
      for (final scenario in OpportunityProfileCatalog.values)
        if (selectedIds.contains(scenario.id)) scenario.id,
    ];
    final updatedProfile = _profile.withOptionIds(
      'opportunity_profiles',
      orderedIds,
    );

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
          content: Text('Impossible de mettre à jour vos scénarios.'),
        ),
      );
    }
  }
}

class _ScenariosHeader extends StatelessWidget {
  const _ScenariosHeader({
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
                  'Mes scénarios',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Choisissez les situations de match que Lector doit rechercher pour vous.',
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

class _ScenarioSummaryCard extends StatelessWidget {
  const _ScenarioSummaryCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final identity = context.opportunities.scenarioIdentityForProfileId(
      'ranking_gap',
    );
    final badge = identity.badgeFor(AppReadingBadgeVariant.combined);
    return _LectorSurface(
      borderColor: badge.border,
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
                RichText(
                  text: TextSpan(
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                    children: [
                      TextSpan(
                        text: '$count',
                        style: TextStyle(color: context.brand.accent),
                      ),
                      TextSpan(
                        text:
                            ' scénario${count > 1 ? 's' : ''} suivi${count > 1 ? 's' : ''}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Ils alimentent vos opportunités dans Pour moi.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.textColors.secondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(Icons.chevron_right_rounded, color: badge.iconColor, size: 20),
        ],
      ),
    );
  }
}

class _ScenarioSearchField extends StatelessWidget {
  const _ScenarioSearchField({
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
        hintText: 'Rechercher un scénario',
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

class _ScenarioListCard extends StatelessWidget {
  const _ScenarioListCard({
    required this.scenarios,
    required this.selectedIds,
    required this.isSaving,
    required this.onToggleScenario,
  });

  final List<OpportunityProfileDefinition> scenarios;
  final Set<String> selectedIds;
  final bool isSaving;
  final ValueChanged<OpportunityProfileDefinition> onToggleScenario;

  @override
  Widget build(BuildContext context) {
    return _LectorSurface(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final entry in scenarios.indexed) ...[
            _ScenarioRow(
              scenario: entry.$2,
              isSelected: selectedIds.contains(entry.$2.id),
              isSaving: isSaving,
              onTap: () => onToggleScenario(entry.$2),
            ),
            if (entry.$1 != scenarios.length - 1)
              Divider(height: 1, indent: 64, color: context.surfaces.border),
          ],
        ],
      ),
    );
  }
}

class _ScenarioRow extends StatelessWidget {
  const _ScenarioRow({
    required this.scenario,
    required this.isSelected,
    required this.isSaving,
    required this.onTap,
  });

  final OpportunityProfileDefinition scenario;
  final bool isSelected;
  final bool isSaving;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final identity = context.opportunities.scenarioIdentityForProfileId(
      scenario.id,
    );
    final badge = identity.badgeFor(
      isSelected
          ? AppReadingBadgeVariant.combined
          : AppReadingBadgeVariant.soft,
    );

    return Material(
      color: AppColors.transparent,
      child: InkWell(
        key: ValueKey('lector-scenario-${scenario.id}'),
        onTap: isSaving || !scenario.isSupported ? null : onTap,
        child: IntrinsicHeight(
          child: Row(
            children: [
              SizedBox(
                width: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: badge.iconColor,
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(8),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Row(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: badge.background,
                          borderRadius: BorderRadius.circular(
                            AppRadius.control,
                          ),
                          border: Border.all(color: badge.border),
                        ),
                        child: SizedBox.square(
                          dimension: 40,
                          child: Icon(
                            identity.icon,
                            color: badge.iconColor,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    scenario.displayLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                ),
                                if (!scenario.isSupported) ...[
                                  const SizedBox(width: AppSpacing.xs),
                                  _ComingSoonBadge(color: badge.iconColor),
                                ],
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              scenario.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: context.textColors.secondary,
                                    height: 1.28,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Transform.scale(
                        scale: 0.78,
                        child: Switch(
                          value: isSelected,
                          activeThumbColor: context.brand.onAccent,
                          activeTrackColor: context.brand.accent,
                          inactiveThumbColor: context.textColors.secondary,
                          inactiveTrackColor: context.surfaces.border,
                          onChanged: isSaving || !scenario.isSupported
                              ? null
                              : (_) => onTap(),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: context.textColors.secondary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComingSoonBadge extends StatelessWidget {
  const _ComingSoonBadge({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.surfaces.backgroundSecondary,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: color),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Text(
          'À venir',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _ScenarioEmptyCard extends StatelessWidget {
  const _ScenarioEmptyCard({
    required this.query,
    required this.isFollowedSection,
  });

  final String query;
  final bool isFollowedSection;

  @override
  Widget build(BuildContext context) {
    final title = query.isEmpty
        ? isFollowedSection
              ? 'Aucun scénario suivi'
              : 'Tous les scénarios sont suivis'
        : isFollowedSection
        ? 'Aucun scénario suivi ne correspond'
        : 'Aucun autre scénario ne correspond';
    final subtitle = query.isEmpty
        ? isFollowedSection
              ? 'Activez un scénario pour personnaliser vos opportunités.'
              : 'Désactivez un scénario pour le retrouver ici.'
        : 'Essayez un autre terme de recherche.';

    return _LectorSurface(
      child: Row(
        children: [
          Icon(Icons.track_changes_rounded, color: context.brand.accent),
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

class _ScenariosInfoCard extends StatelessWidget {
  const _ScenariosInfoCard();

  @override
  Widget build(BuildContext context) {
    final identity = context.opportunities.scenarioIdentityForProfileId(
      'offensive_match',
    );
    final badge = identity.badgeFor(AppReadingBadgeVariant.combined);
    return _LectorSurface(
      borderColor: badge.border,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: badge.background,
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: SizedBox.square(
              dimension: 44,
              child: Icon(
                Icons.lightbulb_outline_rounded,
                color: badge.iconColor,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Comment fonctionnent les scénarios ?',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: badge.foreground,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Lector combine plusieurs lectures pour détecter ces situations dans les matchs et identifier les opportunités correspondant à votre profil.',
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
    );
  }
}

class _AutosaveNotice extends StatelessWidget {
  const _AutosaveNotice({required this.isSaving});

  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isSaving)
          SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: context.brand.accent,
            ),
          )
        else
          Icon(Icons.lock_rounded, color: context.brand.accent, size: 18),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            isSaving
                ? 'Enregistrement de vos choix...'
                : 'Vos choix sont enregistrés automatiquement.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.textColors.secondary,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}

class _LectorSurface extends StatelessWidget {
  const _LectorSurface({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.sm),
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.surfaces.surface.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: borderColor ?? context.surfaces.border),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

List<OpportunityProfileDefinition> _filteredScenarios(
  List<OpportunityProfileDefinition> scenarios,
  String query,
) {
  if (query.isEmpty) {
    return scenarios;
  }

  return [
    for (final scenario in scenarios)
      if (scenario.displayLabel.toLowerCase().contains(query) ||
          scenario.description.toLowerCase().contains(query) ||
          scenario.label.toLowerCase().contains(query))
        scenario,
  ];
}
