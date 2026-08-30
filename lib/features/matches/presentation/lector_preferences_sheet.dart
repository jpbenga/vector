import 'package:flutter/material.dart';

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
  static const sectionGap = AppSpacing.sm;
  static const compactButtonHeight = 40.0;
  static const logoSize = 28.0;
  static const iconSize = 20.0;
  static const switchScale = 0.78;

  const _PreferenceScale._();
}

Future<void> showLectorPreferencesSheet({
  required BuildContext context,
  required DecisionProfile profile,
  required List<TicketStrategy> ticketStrategies,
  required ProfilePreferenceSaver onProfileChanged,
  required TicketStrategyPreferenceSaver onTicketStrategiesChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            _PreferenceScale.sheetHorizontalPadding,
            4,
            _PreferenceScale.sheetHorizontalPadding,
            _PreferenceScale.sheetBottomPadding,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Paramètres Lector',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'Ces choix pilotent directement votre écran Pour moi.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.textColors.secondary,
                ),
              ),
              const SizedBox(height: _PreferenceScale.sectionGap),
              _PreferenceSheetAction(
                icon: Icons.emoji_events_outlined,
                title: 'Championnats',
                subtitle: _selectionSummary(
                  count: _selectedCompetitionIds(profile).length,
                  emptyLabel: 'Aucun filtre actif',
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  showCompetitionPreferencesSheet(
                    context: context,
                    profile: profile,
                    onProfileChanged: onProfileChanged,
                  );
                },
              ),
              _PreferenceSheetAction(
                icon: Icons.auto_stories_outlined,
                title: 'Lectures',
                subtitle: _selectionSummary(
                  count: profile.optionIdsFor('opportunity_profiles').length,
                  emptyLabel: 'Tous les repères lisibles',
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  showReadingPreferencesSheet(
                    context: context,
                    profile: profile,
                    onProfileChanged: onProfileChanged,
                  );
                },
              ),
              _PreferenceSheetAction(
                icon: Icons.confirmation_number_outlined,
                title: 'Ticket builder',
                subtitle: ticketStrategies.isEmpty
                    ? 'Aucune configuration active'
                    : '${ticketStrategies.where((strategy) => strategy.isActive).length}/${ticketStrategies.length} actives',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  showTicketBuilderPreferencesSheet(
                    context: context,
                    strategies: ticketStrategies,
                    onTicketStrategiesChanged: onTicketStrategiesChanged,
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
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
    _selectedIds = widget.profile.optionIdsFor('opportunity_profiles').toSet();
  }

  @override
  Widget build(BuildContext context) {
    final profiles = OpportunityProfileCatalog.values;

    return _PreferenceEditorScaffold(
      title: 'Lectures préférées',
      subtitle:
          'Choisissez les repères que Lector doit prioriser dans Pour moi.',
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
        itemCount: profiles.length,
        separatorBuilder: (_, _) =>
            const SizedBox(height: _PreferenceScale.rowGap),
        itemBuilder: (context, index) {
          final profile = profiles[index];
          final isSelected = _selectedIds.contains(profile.id);

          return _PreferenceToggleTile(
            icon: Icons.auto_stories_outlined,
            title: _readingLabel(profile),
            subtitle: '${profile.thesisIds.length} scénarios associés',
            isSelected: isSelected,
            onChanged: (value) {
              setState(() {
                if (value) {
                  _selectedIds.add(profile.id);
                } else {
                  _selectedIds.remove(profile.id);
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
      for (final profile in OpportunityProfileCatalog.values)
        if (_selectedIds.contains(profile.id)) profile.id,
    ];
    await widget.onProfileChanged(
      widget.profile.withOptionIds('opportunity_profiles', orderedIds),
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }
}

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
      title: 'Ticket builder',
      subtitle:
          'Créez et ajustez vos configurations sans repasser par l’onboarding.',
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
            label: const Text('Créer une configuration'),
          ),
          const SizedBox(height: AppSpacing.xs),
          Expanded(
            child: _strategies.isEmpty
                ? const _PreferenceEmptyState(
                    icon: Icons.confirmation_number_outlined,
                    title: 'Aucune configuration',
                    subtitle:
                        'Créez une première configuration pour personnaliser le ticket builder.',
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
    return showModalBottomSheet<TicketStrategy>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _TicketStrategyEditorSheet(strategy: strategy),
    );
  }

  TicketStrategy _newStrategyDraft() {
    final now = DateTime.now().toUtc();
    final index = _strategies.length + 1;
    return TicketStrategy(
      schemaVersion: TicketStrategy.currentSchemaVersion,
      id: 'strategy-${now.microsecondsSinceEpoch}',
      userId: 'local-user',
      name: 'Configuration $index',
      isActive: true,
      pickTypes: const [PickType.prudent, PickType.normal],
      minimumIndividualOdds: 1.20,
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
  const _TicketStrategyEditorSheet({required this.strategy});

  final TicketStrategy strategy;

  @override
  State<_TicketStrategyEditorSheet> createState() =>
      _TicketStrategyEditorSheetState();
}

class _TicketStrategyEditorSheetState
    extends State<_TicketStrategyEditorSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _minimumIndividualController;
  late final TextEditingController _maximumIndividualController;
  late final TextEditingController _minimumSelectionsController;
  late final TextEditingController _maximumSelectionsController;
  late final TextEditingController _minimumTotalController;
  late final TextEditingController _maximumTotalController;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
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
  }

  @override
  void dispose() {
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

    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: _PreferenceScale.editorHeightFactor,
        child: Padding(
          padding: EdgeInsets.only(
            left: _PreferenceScale.sheetHorizontalPadding,
            right: _PreferenceScale.sheetHorizontalPadding,
            bottom:
                _PreferenceScale.sheetBottomPadding +
                MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Configuration',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Transform.scale(
                    scale: _PreferenceScale.switchScale,
                    child: Switch(
                      value: _isActive,
                      onChanged: (value) {
                        setState(() {
                          _isActive = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Expanded(
                child: ListView(
                  children: [
                    TextField(
                      key: const ValueKey('ticket-strategy-name-field'),
                      controller: _nameController,
                      onChanged: (_) => setState(() {}),
                      style: Theme.of(context).textTheme.bodySmall,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Nom',
                        hintText: 'Ex. Configuration week-end',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _StrategyEditorSection(
                      title: 'Sélections',
                      children: [
                        _NumberField(
                          controller: _minimumSelectionsController,
                          label: 'Minimum',
                          onChanged: (_) => setState(() {}),
                        ),
                        _NumberField(
                          controller: _maximumSelectionsController,
                          label: 'Maximum',
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _StrategyEditorSection(
                      title: 'Valeur individuelle',
                      children: [
                        _NumberField(
                          controller: _minimumIndividualController,
                          label: 'Minimum',
                          decimal: true,
                          onChanged: (_) => setState(() {}),
                        ),
                        _NumberField(
                          controller: _maximumIndividualController,
                          label: 'Maximum',
                          hintText: 'Ouverte',
                          decimal: true,
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _StrategyEditorSection(
                      title: 'Valeur totale',
                      children: [
                        _NumberField(
                          controller: _minimumTotalController,
                          label: 'Minimum',
                          decimal: true,
                          onChanged: (_) => setState(() {}),
                        ),
                        _NumberField(
                          controller: _maximumTotalController,
                          label: 'Maximum',
                          hintText: 'Ouverte',
                          decimal: true,
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (validationMessage != null)
                      Text(
                        validationMessage,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.semantic.error,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    else
                      Text(
                        _summary,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.textColors.secondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: _PreferenceScale.compactButtonHeight,
                child: FilledButton(
                  key: const ValueKey('save-ticket-strategy-button'),
                  onPressed: validationMessage == null ? _submit : null,
                  child: const Text('Valider la configuration'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _summary {
    return 'Configuration active sur $_selectionRangeLabel avec une valeur individuelle ${_minimumIndividualOdds?.toStringAsFixed(2) ?? '-'}-${_maximumIndividualOdds?.toStringAsFixed(2) ?? '+'}.';
  }

  String get _selectionRangeLabel {
    final min = _minimumSelections;
    final max = _maximumSelections;
    if (min == null || max == null) {
      return 'les sélections';
    }
    if (min == max) {
      return '$min sélection${min > 1 ? 's' : ''}';
    }
    return '$min à $max sélections';
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
    Navigator.of(context).pop(_draft);
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

class _PreferenceSheetAction extends StatelessWidget {
  const _PreferenceSheetAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: _PreferenceScale.rowGap),
      child: Material(
        color: context.surfaces.backgroundSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_PreferenceScale.rowRadius),
          side: BorderSide(color: context.surfaces.border),
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
                  icon,
                  size: _PreferenceScale.iconSize,
                  color: context.brand.accent,
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
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: context.textColors.secondary,
                ),
              ],
            ),
          ),
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

String _selectionSummary({required int count, required String emptyLabel}) {
  if (count == 0) {
    return emptyLabel;
  }

  if (count == 1) {
    return '1 sélection active';
  }

  return '$count sélections actives';
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

String _readingLabel(OpportunityProfileDefinition profile) {
  return switch (profile.id) {
    'solid_favorite' => 'Dominations attendues',
    'struggling_team' => 'Équipes en difficulté',
    'offensive_match' => 'Matchs ouverts',
    'defensive_match' => 'Matchs fermés',
    'ranking_gap' => 'Écarts de niveau',
    'credible_outsider' => 'Outsiders crédibles',
    'fragile_defense' => 'Défenses fragiles',
    'prolific_attack' => 'Attaques prolifiques',
    'positive_series' => 'Séries positives',
    'negative_series' => 'Séries négatives',
    _ => profile.label,
  };
}
