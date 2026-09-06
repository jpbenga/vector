import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_components.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../onboarding/domain/decision_profile.dart';
import '../../onboarding/domain/decision_profile_catalogs.dart';
import '../../tickets/domain/ticket_strategy.dart';
import 'widgets/sports_asset_badge.dart';

typedef ProfilePreferenceSaver = Future<void> Function(DecisionProfile profile);
typedef TicketStrategyPreferenceSaver =
    Future<void> Function(List<TicketStrategy> strategies);

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

Future<void> showTicketBuilderPreferencesSheet({
  required BuildContext context,
  required List<TicketStrategy> strategies,
  required TicketStrategyPreferenceSaver onTicketStrategiesChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return _TicketBuilderPreferencesEditor(
        strategies: strategies,
        onTicketStrategiesChanged: onTicketStrategiesChanged,
      );
    },
  );
}

Future<TicketStrategy?> showTicketStrategyEditorSheet({
  required BuildContext context,
  required TicketStrategy strategy,
}) {
  return showTicketStrategyManagementSheet(
    context: context,
    strategy: strategy,
    rank: strategy.priority,
    style: context.strategies.styleForIndex(
      (strategy.priority - 1).clamp(0, 999),
    ),
    canDelete: false,
  ).then((result) => result?.strategy);
}

Future<TicketStrategySheetResult?> showTicketStrategyManagementSheet({
  required BuildContext context,
  required TicketStrategy strategy,
  required int rank,
  required AppStrategyVisualStyle style,
  bool isNew = false,
  bool canDelete = true,
}) {
  return showModalBottomSheet<TicketStrategySheetResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: AppColors.transparent,
    barrierColor: context.surfaces.scrim.withValues(alpha: 0.36),
    builder: (context) => _TicketStrategyEditorSheet(
      strategy: strategy,
      rank: rank,
      style: style,
      isNew: isNew,
      canDelete: canDelete,
    ),
  );
}

class TicketStrategySheetResult {
  const TicketStrategySheetResult.saved(this.strategy) : isDeleted = false;

  const TicketStrategySheetResult.deleted() : strategy = null, isDeleted = true;

  final TicketStrategy? strategy;
  final bool isDeleted;
}

TicketStrategy createTicketStrategyDraft({required int index}) {
  final now = DateTime.now().toUtc();
  return TicketStrategy(
    schemaVersion: TicketStrategy.currentSchemaVersion,
    id: 'strategy-${now.microsecondsSinceEpoch}',
    userId: 'local-user',
    name: 'Configuration $index',
    isActive: true,
    pickTypes: const [PickType.prudent, PickType.normal],
    minimumIndividualOdds: 0,
    maximumIndividualOdds: 2.19,
    minimumSelections: 2,
    maximumSelections: 3,
    minimumTotalOdds: 2.00,
    maximumTotalOdds: 3.00,
    priority: index,
    createdAt: now,
    updatedAt: now,
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
  late Set<String> _selectedIds;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.profile.optionIdsFor('readings').toSet();
  }

  @override
  Widget build(BuildContext context) {
    final readings = ReadingPreferenceCatalog.values;

    return _PreferenceEditorScaffold(
      title: 'Mes lectures',
      subtitle:
          'Choisissez les faits observés qui peuvent faire apparaître un match dans Pour moi.',
      isSaving: _isSaving,
      selectedCount: _selectedIds.length,
      onClear: _selectedIds.isEmpty
          ? null
          : () {
              setState(_selectedIds.clear);
            },
      onSave: _save,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        itemCount: readings.length,
        separatorBuilder: (_, _) =>
            const SizedBox(height: _PreferenceScale.rowGap),
        itemBuilder: (context, index) {
          final reading = readings[index];
          final isSelected = _selectedIds.contains(reading.id);

          return _PreferenceToggleTile(
            icon: _readingPreferenceIcon(reading.id),
            title: reading.label,
            subtitle: reading.description,
            isSelected: isSelected,
            onChanged: (value) {
              setState(() {
                if (value) {
                  _selectedIds.add(reading.id);
                } else {
                  _selectedIds.remove(reading.id);
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
    'positive_streak' || 'improving_form' => Icons.trending_up_rounded,
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
    _ => Icons.insights_outlined,
  };
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

class _TicketBuilderPreferencesEditor extends StatefulWidget {
  const _TicketBuilderPreferencesEditor({
    required this.strategies,
    required this.onTicketStrategiesChanged,
  });

  final List<TicketStrategy> strategies;
  final TicketStrategyPreferenceSaver onTicketStrategiesChanged;

  @override
  State<_TicketBuilderPreferencesEditor> createState() =>
      _TicketBuilderPreferencesEditorState();
}

class _TicketBuilderPreferencesEditorState
    extends State<_TicketBuilderPreferencesEditor> {
  late List<TicketStrategy> _strategies;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _strategies = [...widget.strategies];
  }

  @override
  Widget build(BuildContext context) {
    return _PreferenceEditorScaffold(
      title: 'Mes stratégies',
      subtitle: 'Définissez comment Lector construit vos tickets.',
      isSaving: _isSaving,
      selectedCount: _strategies.where((strategy) => strategy.isActive).length,
      onClear: null,
      onSave: _save,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            key: const ValueKey('create-ticket-strategy-button'),
            onPressed: _createStrategy,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(
                _PreferenceScale.compactButtonHeight,
              ),
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Créer une stratégie'),
          ),
          const SizedBox(height: AppSpacing.xs),
          Expanded(
            child: _strategies.isEmpty
                ? const _PreferenceEmptyState(
                    icon: Icons.confirmation_number_outlined,
                    title: 'Aucune stratégie',
                    subtitle:
                        'Créez une première stratégie pour personnaliser vos tickets.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    itemCount: _strategies.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: _PreferenceScale.rowGap),
                    itemBuilder: (context, index) {
                      final strategy = _strategies[index];

                      return _TicketStrategyTile(
                        strategy: strategy,
                        onTap: () => _editStrategy(index),
                        onToggle: (value) {
                          setState(() {
                            _strategies[index] = strategy.copyWith(
                              isActive: value,
                              updatedAt: DateTime.now().toUtc(),
                            );
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

  Future<void> _createStrategy() async {
    final strategy = await _openStrategyEditor(_newStrategyDraft());
    if (strategy == null) {
      return;
    }

    setState(() {
      _strategies = [..._strategies, strategy];
    });
  }

  Future<void> _editStrategy(int index) async {
    final strategy = await _openStrategyEditor(_strategies[index]);
    if (strategy == null) {
      return;
    }

    setState(() {
      _strategies[index] = strategy;
    });
  }

  Future<TicketStrategy?> _openStrategyEditor(TicketStrategy strategy) {
    return showTicketStrategyEditorSheet(context: context, strategy: strategy);
  }

  TicketStrategy _newStrategyDraft() {
    return createTicketStrategyDraft(index: _strategies.length + 1);
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
    });
    await widget.onTicketStrategiesChanged(
      List.unmodifiable([
        for (var index = 0; index < _strategies.length; index++)
          _strategies[index].copyWith(priority: index + 1),
      ]),
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }
}

class _TicketStrategyTile extends StatelessWidget {
  const _TicketStrategyTile({
    required this.strategy,
    required this.onTap,
    required this.onToggle,
  });

  final TicketStrategy strategy;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: strategy.isActive
          ? context.brand.accent.withValues(alpha: 0.12)
          : context.surfaces.backgroundSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_PreferenceScale.rowRadius),
        side: BorderSide(
          color: strategy.isActive
              ? context.brand.accent
              : context.surfaces.border,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_PreferenceScale.rowRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: _PreferenceScale.rowHorizontalPadding,
            vertical: _PreferenceScale.rowVerticalPadding,
          ),
          child: Row(
            children: [
              Icon(
                Icons.confirmation_number_outlined,
                size: _PreferenceScale.iconSize,
                color: strategy.isActive
                    ? context.brand.accent
                    : context.textColors.secondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      strategy.name.isEmpty ? 'Configuration' : strategy.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${strategy.minimumSelections}-${strategy.maximumSelections} sélections · ${strategy.minimumIndividualOdds.toStringAsFixed(2)}-${strategy.maximumIndividualOdds?.toStringAsFixed(2) ?? '+'}',
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
                child: Switch(value: strategy.isActive, onChanged: onToggle),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TicketStrategyEditorSheet extends StatefulWidget {
  const _TicketStrategyEditorSheet({
    required this.strategy,
    required this.rank,
    required this.style,
    required this.isNew,
    required this.canDelete,
  });

  final TicketStrategy strategy;
  final int rank;
  final AppStrategyVisualStyle style;
  final bool isNew;
  final bool canDelete;

  @override
  State<_TicketStrategyEditorSheet> createState() =>
      _TicketStrategyEditorSheetState();
}

class _TicketStrategyEditorSheetState
    extends State<_TicketStrategyEditorSheet> {
  late final DraggableScrollableController _sheetController;
  late final TextEditingController _nameController;
  late final TextEditingController _minimumIndividualController;
  late final TextEditingController _maximumIndividualController;
  late final TextEditingController _minimumSelectionsController;
  late final TextEditingController _maximumSelectionsController;
  late final TextEditingController _minimumTotalController;
  late final TextEditingController _maximumTotalController;
  late bool _isActive;
  late bool _isEditing;
  bool _isConfirmingDelete = false;

  @override
  void initState() {
    super.initState();
    _sheetController = DraggableScrollableController();
    final strategy = widget.strategy;
    _nameController = TextEditingController(text: strategy.name);
    _minimumIndividualController = TextEditingController(
      text: strategy.minimumIndividualOdds.toStringAsFixed(2),
    );
    _maximumIndividualController = TextEditingController(
      text: strategy.maximumIndividualOdds?.toStringAsFixed(2) ?? '',
    );
    _minimumSelectionsController = TextEditingController(
      text: strategy.minimumSelections.toString(),
    );
    _maximumSelectionsController = TextEditingController(
      text: strategy.maximumSelections.toString(),
    );
    _minimumTotalController = TextEditingController(
      text: strategy.minimumTotalOdds.toStringAsFixed(2),
    );
    _maximumTotalController = TextEditingController(
      text: strategy.maximumTotalOdds?.toStringAsFixed(2) ?? '',
    );
    _isActive = strategy.isActive;
    _isEditing = widget.isNew;
  }

  @override
  void dispose() {
    _sheetController.dispose();
    _nameController.dispose();
    _minimumIndividualController.dispose();
    _maximumIndividualController.dispose();
    _minimumSelectionsController.dispose();
    _maximumSelectionsController.dispose();
    _minimumTotalController.dispose();
    _maximumTotalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final validationMessage = _validationMessage;
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    final isKeyboardOpen = viewInsets > 0;

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: viewInsets),
        child: DraggableScrollableSheet(
          controller: _sheetController,
          expand: false,
          initialChildSize: widget.isNew ? 0.82 : 0.44,
          minChildSize: 0.34,
          maxChildSize: isKeyboardOpen ? 0.94 : 0.88,
          builder: (context, scrollController) {
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.card),
              ),
              child: Material(
                color: context.surfaces.surface.withValues(alpha: 0.98),
                child: Stack(
                  children: [
                    ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(
                        _PreferenceScale.sheetHorizontalPadding,
                        8,
                        _PreferenceScale.sheetHorizontalPadding,
                        _PreferenceScale.sheetBottomPadding,
                      ),
                      children: [
                        const _SheetHandle(),
                        const SizedBox(height: AppSpacing.xs),
                        _StrategySheetHeader(
                          rank: widget.rank,
                          strategy: _draft,
                          style: widget.style,
                          onToggleActive: (value) {
                            setState(() {
                              _isActive = value;
                            });
                            if (!_isEditing && !widget.isNew) {
                              Navigator.of(
                                context,
                              ).pop(TicketStrategySheetResult.saved(_draft));
                            }
                          },
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 240),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          child: _isEditing
                              ? _StrategyEditingContent(
                                  key: const ValueKey('strategy-editing'),
                                  nameController: _nameController,
                                  minimumSelectionsController:
                                      _minimumSelectionsController,
                                  maximumSelectionsController:
                                      _maximumSelectionsController,
                                  minimumIndividualController:
                                      _minimumIndividualController,
                                  maximumIndividualController:
                                      _maximumIndividualController,
                                  minimumTotalController:
                                      _minimumTotalController,
                                  maximumTotalController:
                                      _maximumTotalController,
                                  validationMessage: validationMessage,
                                  summary: _summary,
                                  canDelete: widget.canDelete,
                                  isNew: widget.isNew,
                                  onChanged: (_) => setState(() {}),
                                  onDelete: _askDeleteConfirmation,
                                  onSubmit: validationMessage == null
                                      ? _submit
                                      : null,
                                )
                              : _StrategyReadOnlyContent(
                                  key: const ValueKey('strategy-summary'),
                                  strategy: _draft,
                                  style: widget.style,
                                  canDelete: widget.canDelete,
                                  onEdit: _enterEditMode,
                                  onDelete: _askDeleteConfirmation,
                                ),
                        ),
                      ],
                    ),
                    if (_isConfirmingDelete)
                      _DeleteStrategyConfirmation(
                        onCancel: () {
                          setState(() {
                            _isConfirmingDelete = false;
                          });
                        },
                        onConfirm: _delete,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _enterEditMode() {
    setState(() {
      _isEditing = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_sheetController.isAttached) {
        _sheetController.animateTo(
          0.82,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _askDeleteConfirmation() {
    if (!widget.canDelete) {
      return;
    }
    setState(() {
      _isConfirmingDelete = true;
    });
  }

  void _delete() {
    Navigator.of(context).pop(const TicketStrategySheetResult.deleted());
  }

  String get _summary {
    return 'Cette stratégie génère des tickets avec $_selectionRangeLabel, une cote par sélection ${_oddsSummary(_minimumIndividualOdds, _maximumIndividualOdds)} et une cote totale ${_oddsSummary(_minimumTotalOdds, _maximumTotalOdds)}.';
  }

  String get _selectionRangeLabel {
    final min = _minimumSelections;
    final max = _maximumSelections;
    if (min == null || max == null) {
      return 'les sélections configurées';
    }
    if (min == max) {
      return '$min sélection${min > 1 ? 's' : ''}';
    }
    return '$min à $max sélections';
  }

  String _oddsSummary(double? minimum, double? maximum) {
    if (minimum == null) {
      return maximum == null ? 'configurée' : 'jusqu’à ${_formatOdds(maximum)}';
    }
    if (maximum == null) {
      return 'à partir de ${_formatOdds(minimum)}';
    }
    return 'entre ${_formatOdds(minimum)} et ${_formatOdds(maximum)}';
  }

  String? get _validationMessage {
    if (_nameController.text.trim().isEmpty) {
      return 'Donnez un nom à cette configuration.';
    }
    if (_minimumSelections == null ||
        _maximumSelections == null ||
        _minimumSelections! <= 0 ||
        _maximumSelections! <= 0) {
      return 'Le nombre de sélections doit être valide.';
    }
    if (_minimumSelections! > _maximumSelections!) {
      return 'Le maximum doit être supérieur au minimum.';
    }
    if (_minimumIndividualOdds == null || _minimumIndividualOdds! < 1.01) {
      return 'La valeur individuelle minimum doit être au moins égale à 1.01.';
    }
    if (_maximumIndividualOdds != null &&
        _maximumIndividualOdds! < _minimumIndividualOdds!) {
      return 'La valeur individuelle maximum doit être supérieure au minimum.';
    }
    if (_minimumTotalOdds == null || _minimumTotalOdds! < 1) {
      return 'La valeur totale minimum doit être valide.';
    }
    if (_maximumTotalOdds != null && _maximumTotalOdds! < _minimumTotalOdds!) {
      return 'La valeur totale maximum doit être supérieure au minimum.';
    }
    if (!_draft.hasMathematicallyPossibleTicket) {
      return 'Cette configuration ne peut produire aucun ticket. Ajustez les valeurs ou le nombre de sélections.';
    }

    return null;
  }

  int? get _minimumSelections =>
      int.tryParse(_minimumSelectionsController.text.trim());

  int? get _maximumSelections =>
      int.tryParse(_maximumSelectionsController.text.trim());

  double? get _minimumIndividualOdds =>
      _doubleValue(_minimumIndividualController.text);

  double? get _maximumIndividualOdds =>
      _nullableDoubleValue(_maximumIndividualController.text);

  double? get _minimumTotalOdds => _doubleValue(_minimumTotalController.text);

  double? get _maximumTotalOdds =>
      _nullableDoubleValue(_maximumTotalController.text);

  TicketStrategy get _draft {
    final minimumIndividualOdds =
        _minimumIndividualOdds ?? widget.strategy.minimumIndividualOdds;
    final maximumIndividualOdds = _maximumIndividualOdds;
    return widget.strategy.copyWith(
      name: _nameController.text.trim(),
      isActive: _isActive,
      pickTypes: TicketStrategy.pickTypesForIndividualOdds(
        minimumIndividualOdds,
        maximumIndividualOdds,
      ),
      minimumIndividualOdds: minimumIndividualOdds,
      maximumIndividualOdds: maximumIndividualOdds,
      clearsMaximumIndividualOdds: maximumIndividualOdds == null,
      minimumSelections:
          _minimumSelections ?? widget.strategy.minimumSelections,
      maximumSelections:
          _maximumSelections ?? widget.strategy.maximumSelections,
      minimumTotalOdds: _minimumTotalOdds ?? widget.strategy.minimumTotalOdds,
      maximumTotalOdds: _maximumTotalOdds,
      clearsMaximumTotalOdds: _maximumTotalOdds == null,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  void _submit() {
    Navigator.of(context).pop(TicketStrategySheetResult.saved(_draft));
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.textColors.secondary.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        child: const SizedBox(width: 32, height: 4),
      ),
    );
  }
}

class _StrategySheetHeader extends StatelessWidget {
  const _StrategySheetHeader({
    required this.rank,
    required this.strategy,
    required this.style,
    required this.onToggleActive,
  });

  final int rank;
  final TicketStrategy strategy;
  final AppStrategyVisualStyle style;
  final ValueChanged<bool> onToggleActive;

  @override
  Widget build(BuildContext context) {
    final isActive = strategy.isActive;
    return Row(
      children: [
        _SheetRankBadge(rank: rank, color: style.color),
        const SizedBox(width: AppSpacing.sm),
        _SheetIconBadge(icon: style.icon, color: style.color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            _strategyName(strategy),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          isActive ? 'Activée' : 'Inactive',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: isActive
                ? context.brand.accent
                : context.textColors.secondary,
            fontWeight: FontWeight.w900,
          ),
        ),
        Transform.scale(
          scale: _PreferenceScale.switchScale,
          child: Switch(
            value: isActive,
            onChanged: onToggleActive,
            activeThumbColor: context.brand.accent,
            activeTrackColor: context.brand.accent.withValues(alpha: 0.48),
          ),
        ),
      ],
    );
  }
}

class _SheetRankBadge extends StatelessWidget {
  const _SheetRankBadge({required this.rank, required this.color});

  final int rank;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color, width: 1.4),
      ),
      child: Text(
        '$rank',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SheetIconBadge extends StatelessWidget {
  const _SheetIconBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.control),
        color: color.withValues(alpha: 0.14),
      ),
      child: Icon(icon, color: color, size: 17),
    );
  }
}

class _StrategyReadOnlyContent extends StatelessWidget {
  const _StrategyReadOnlyContent({
    super.key,
    required this.strategy,
    required this.style,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
  });

  final TicketStrategy strategy;
  final AppStrategyVisualStyle style;
  final bool canDelete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('ticket-strategy-summary-mode'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: context.surfaces.backgroundSecondary.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(AppRadius.odds),
            border: Border.all(color: context.surfaces.border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Column(
              children: [
                _StrategySummaryLine(
                  icon: Icons.bar_chart_rounded,
                  label: 'Sélections',
                  value: _selectionRange(strategy),
                  color: style.color,
                ),
                Divider(height: 1, color: context.surfaces.border),
                _StrategySummaryLine(
                  icon: Icons.confirmation_number_outlined,
                  label: 'Cote par sélection',
                  value: _oddsRange(
                    strategy.minimumIndividualOdds,
                    strategy.maximumIndividualOdds,
                  ),
                  color: style.color,
                ),
                Divider(height: 1, color: context.surfaces.border),
                _StrategySummaryLine(
                  icon: Icons.request_quote_outlined,
                  label: 'Cote totale',
                  value: _oddsRange(
                    strategy.minimumTotalOdds,
                    strategy.maximumTotalOdds,
                  ),
                  color: style.color,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _StrategySheetActions(
          canDelete: canDelete,
          primaryLabel: 'Modifier',
          primaryIcon: Icons.edit_rounded,
          onPrimary: onEdit,
          onDelete: onDelete,
        ),
      ],
    );
  }
}

class _StrategySummaryLine extends StatelessWidget {
  const _StrategySummaryLine({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 39,
      child: Row(
        children: [
          _SheetIconBadge(icon: icon, color: context.textColors.secondary),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: context.textColors.secondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            value,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _StrategyEditingContent extends StatelessWidget {
  const _StrategyEditingContent({
    super.key,
    required this.nameController,
    required this.minimumSelectionsController,
    required this.maximumSelectionsController,
    required this.minimumIndividualController,
    required this.maximumIndividualController,
    required this.minimumTotalController,
    required this.maximumTotalController,
    required this.validationMessage,
    required this.summary,
    required this.canDelete,
    required this.isNew,
    required this.onChanged,
    required this.onDelete,
    required this.onSubmit,
  });

  final TextEditingController nameController;
  final TextEditingController minimumSelectionsController;
  final TextEditingController maximumSelectionsController;
  final TextEditingController minimumIndividualController;
  final TextEditingController maximumIndividualController;
  final TextEditingController minimumTotalController;
  final TextEditingController maximumTotalController;
  final String? validationMessage;
  final String summary;
  final bool canDelete;
  final bool isNew;
  final ValueChanged<String> onChanged;
  final VoidCallback onDelete;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final error = validationMessage;
    return Column(
      key: const ValueKey('ticket-strategy-edit-mode'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EditorGroup(
          title: 'Configuration',
          child: TextField(
            key: const ValueKey('ticket-strategy-name-field'),
            controller: nameController,
            onChanged: onChanged,
            style: Theme.of(context).textTheme.bodySmall,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Nom de la stratégie',
              hintText: 'Ex. Configuration week-end',
              suffixIcon: nameController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Effacer',
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        nameController.clear();
                        onChanged('');
                      },
                    ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 9,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        _StrategyEditorSection(
          title: 'Sélections',
          children: [
            _NumberField(
              controller: minimumSelectionsController,
              label: 'Minimum',
              onChanged: onChanged,
            ),
            _NumberField(
              controller: maximumSelectionsController,
              label: 'Maximum',
              onChanged: onChanged,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        _StrategyEditorSection(
          title: 'Cote par sélection',
          children: [
            _NumberField(
              controller: minimumIndividualController,
              label: 'Minimum',
              decimal: true,
              onChanged: onChanged,
            ),
            _NumberField(
              controller: maximumIndividualController,
              label: 'Maximum',
              hintText: 'Ouverte',
              decimal: true,
              onChanged: onChanged,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        _StrategyEditorSection(
          title: 'Cote totale',
          children: [
            _NumberField(
              controller: minimumTotalController,
              label: 'Minimum',
              decimal: true,
              onChanged: onChanged,
            ),
            _NumberField(
              controller: maximumTotalController,
              label: 'Maximum',
              hintText: 'Ouverte',
              decimal: true,
              onChanged: onChanged,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: error != null
              ? _SheetMessage(
                  key: const ValueKey('strategy-validation-error'),
                  icon: Icons.error_outline_rounded,
                  color: context.semantic.error,
                  text: error,
                )
              : _SheetMessage(
                  key: const ValueKey('strategy-validation-summary'),
                  icon: Icons.auto_awesome_rounded,
                  color: context.textColors.secondary,
                  text: summary,
                ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _StrategySheetActions(
          canDelete: canDelete,
          primaryLabel: isNew
              ? 'Créer la stratégie'
              : 'Valider les modifications',
          primaryIcon: Icons.check_rounded,
          onPrimary: onSubmit,
          onDelete: onDelete,
        ),
      ],
    );
  }
}

class _EditorGroup extends StatelessWidget {
  const _EditorGroup({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.surfaces.backgroundSecondary.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(_PreferenceScale.rowRadius),
        border: Border.all(color: context.surfaces.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xs,
          AppSpacing.xxs,
          AppSpacing.xs,
          AppSpacing.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.textColors.secondary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            child,
          ],
        ),
      ),
    );
  }
}

class _SheetMessage extends StatelessWidget {
  const _SheetMessage({
    super.key,
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}

class _StrategySheetActions extends StatelessWidget {
  const _StrategySheetActions({
    required this.canDelete,
    required this.primaryLabel,
    required this.primaryIcon,
    required this.onPrimary,
    required this.onDelete,
  });

  final bool canDelete;
  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback? onPrimary;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final primary = SizedBox(
      height: _PreferenceScale.compactButtonHeight,
      child: FilledButton.icon(
        key: const ValueKey('save-ticket-strategy-button'),
        onPressed: onPrimary,
        icon: Icon(primaryIcon, size: 16),
        label: Text(primaryLabel),
      ),
    );

    if (!canDelete) {
      return primary;
    }

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: _PreferenceScale.compactButtonHeight,
            child: OutlinedButton.icon(
              key: const ValueKey('delete-ticket-strategy-button'),
              onPressed: onDelete,
              style: OutlinedButton.styleFrom(
                foregroundColor: context.semantic.error,
                side: BorderSide(
                  color: context.semantic.error.withValues(alpha: 0.70),
                ),
              ),
              icon: const Icon(Icons.delete_outline_rounded, size: 16),
              label: const Text('Supprimer la stratégie'),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(child: primary),
      ],
    );
  }
}

class _DeleteStrategyConfirmation extends StatelessWidget {
  const _DeleteStrategyConfirmation({
    required this.onCancel,
    required this.onConfirm,
  });

  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: context.surfaces.shadow.withValues(alpha: 0.58),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.surfaces.surface,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: context.surfaces.border),
                boxShadow: [
                  BoxShadow(
                    color: context.surfaces.shadow.withValues(alpha: 0.36),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: context.semantic.error.withValues(alpha: 0.85),
                        ),
                      ),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        size: 20,
                        color: context.semantic.error,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Supprimer cette stratégie ?',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Cette action est irréversible. La stratégie sera supprimée de vos configurations.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.textColors.secondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: _PreferenceScale.compactButtonHeight,
                            child: OutlinedButton(
                              onPressed: onCancel,
                              child: const Text('Annuler'),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: SizedBox(
                            height: _PreferenceScale.compactButtonHeight,
                            child: FilledButton(
                              key: const ValueKey(
                                'confirm-delete-ticket-strategy-button',
                              ),
                              onPressed: onConfirm,
                              style: FilledButton.styleFrom(
                                backgroundColor: context.semantic.error,
                                foregroundColor: context.surfaces.background,
                              ),
                              child: const Text('Supprimer'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StrategyEditorSection extends StatelessWidget {
  const _StrategyEditorSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.surfaces.backgroundSecondary,
        borderRadius: BorderRadius.circular(_PreferenceScale.rowRadius),
        border: Border.all(color: context.surfaces.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                for (var index = 0; index < children.length; index++) ...[
                  Expanded(child: children[index]),
                  if (index != children.length - 1)
                    const SizedBox(width: AppSpacing.xs),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.onChanged,
    this.hintText,
    this.decimal = false,
  });

  final TextEditingController controller;
  final String label;
  final String? hintText;
  final bool decimal;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: Theme.of(context).textTheme.bodySmall,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      ),
    );
  }
}

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
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
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
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final ValueChanged<bool> onChanged;
  final String? imageUrl;
  final String? fallbackLabel;

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
  });

  final IconData icon;
  final String fallbackLabel;
  final bool isSelected;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final logoUrl = imageUrl;
    if (logoUrl != null && logoUrl.isNotEmpty) {
      return SportsAssetBadge(
        size: _PreferenceScale.logoSize,
        imageUrl: logoUrl,
        fallbackLabel: fallbackLabel,
        icon: icon,
        backgroundColor: context.surfaces.surface,
        padding: 2,
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

String _strategyName(TicketStrategy strategy) {
  final name = strategy.name.trim();
  return name.isEmpty ? 'Configuration' : name;
}

String _selectionRange(TicketStrategy strategy) {
  if (strategy.minimumSelections == strategy.maximumSelections) {
    return '${strategy.minimumSelections}';
  }
  return '${strategy.minimumSelections} – ${strategy.maximumSelections}';
}

String _oddsRange(double minimum, double? maximum) {
  final min = _formatOdds(minimum);
  if (maximum == null) {
    return '$min+';
  }
  final max = _formatOdds(maximum);
  if (min == max) {
    return min;
  }
  return '$min – $max';
}

String _formatOdds(double value) {
  return value.toStringAsFixed(2).replaceAll('.', ',');
}

double? _doubleValue(String value) {
  return double.tryParse(value.replaceAll(',', '.').trim());
}

double? _nullableDoubleValue(String value) {
  final normalized = value.replaceAll(',', '.').trim();
  if (normalized.isEmpty) {
    return null;
  }

  return double.tryParse(normalized);
}
