import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_components.dart';
import '../../../core/theme/app_radius.dart';
import '../../matches/domain/match_board_item.dart';
import '../../matches/domain/football_reading.dart';
import '../../matches/presentation/widgets/sports_asset_badge.dart';
import '../../onboarding/domain/compiled_decision_profile.dart';
import '../../onboarding/domain/decision_profile_catalogs.dart';
import '../../opportunities/domain/opportunity.dart';
import '../domain/generated_ticket.dart';
import '../domain/generated_ticket_pick.dart';
import '../domain/saved_ticket.dart';
import '../domain/ticket_generation_result.dart';
import '../domain/ticket_generator.dart';
import '../domain/ticket_strategy.dart';
import 'ticket_history_page.dart';

enum _TicketTab { copilot, edited, manual }

class TicketGeneratorPage extends StatefulWidget {
  const TicketGeneratorPage({
    required this.profile,
    required this.matches,
    required this.opportunities,
    required this.strategies,
    this.savedTickets = const [],
    this.manualTicketsOpenRequest = 0,
    required this.onEditProfile,
    required this.onEditStrategies,
    required this.onCreateManualTicket,
    required this.onOpenOpportunity,
    required this.onSaveTicket,
    required this.onDeleteSavedTicket,
    super.key,
  });

  final CompiledDecisionProfile profile;
  final List<MatchBoardItem> matches;
  final List<Opportunity> opportunities;
  final List<TicketStrategy> strategies;
  final List<SavedTicket> savedTickets;
  final int manualTicketsOpenRequest;
  final VoidCallback onEditProfile;
  final VoidCallback onEditStrategies;
  final VoidCallback onCreateManualTicket;
  final ValueChanged<Opportunity> onOpenOpportunity;
  final ValueChanged<SavedTicket> onSaveTicket;
  final ValueChanged<String> onDeleteSavedTicket;

  @override
  State<TicketGeneratorPage> createState() => _TicketGeneratorPageState();
}

class _TicketGeneratorPageState extends State<TicketGeneratorPage> {
  _TicketTab _selectedTab = _TicketTab.copilot;
  final Set<String> _expandedTicketIds = {};

  @override
  void initState() {
    super.initState();
    if (widget.manualTicketsOpenRequest > 0) {
      _selectedTab = _TicketTab.manual;
    }
  }

  @override
  void didUpdateWidget(TicketGeneratorPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.manualTicketsOpenRequest != widget.manualTicketsOpenRequest) {
      _selectedTab = _TicketTab.manual;
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = const TicketGenerator().generate(
      matches: widget.matches,
      strategies: widget.strategies,
      profile: widget.profile,
    );
    final copilotTickets = result.tickets;
    final activeStrategies = widget.strategies
        .where((strategy) => strategy.isActive)
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TicketsHeader(
                  onHistory: _openHistory,
                  onRefresh: _refreshProposals,
                  onSettings: widget.onEditStrategies,
                ),
                const SizedBox(height: 14),
                _TicketOriginTabs(
                  selectedTab: _selectedTab,
                  copilotCount: copilotTickets.length,
                  editedCount: widget.savedTickets
                      .where(
                        (ticket) =>
                            ticket.source == SavedTicketSource.copilotModified,
                      )
                      .length,
                  manualCount: widget.savedTickets
                      .where(
                        (ticket) => ticket.source == SavedTicketSource.manual,
                      )
                      .length,
                  onChanged: (tab) {
                    setState(() {
                      _selectedTab = tab;
                    });
                  },
                ),
                const SizedBox(height: 14),
                _TicketTabContent(
                  selectedTab: _selectedTab,
                  result: result,
                  expandedTicketIds: _expandedTicketIds,
                  onToggleTicketExpanded: _toggleTicketExpanded,
                  onEditProfile: widget.onEditProfile,
                  onEditStrategies: widget.onEditStrategies,
                  activeStrategyName: activeStrategies.isEmpty
                      ? null
                      : activeStrategies.first.name,
                  savedTickets: widget.savedTickets,
                  matches: widget.matches,
                  opportunities: widget.opportunities,
                  opportunityForMatchId: _opportunityForMatchId,
                  onOpenOpportunity: widget.onOpenOpportunity,
                  onSaveTicket: widget.onSaveTicket,
                ),
                const SizedBox(height: 12),
                _CreateManualTicketCta(onTap: widget.onCreateManualTicket),
                const SizedBox(height: 10),
                _HowItWorksLink(onTap: _showHowItWorks),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Opportunity? _opportunityForMatchId(String matchId) {
    for (final opportunity in widget.opportunities) {
      if (opportunity.matchId == matchId) {
        return opportunity;
      }
    }

    return null;
  }

  void _toggleTicketExpanded(String ticketId) {
    setState(() {
      if (!_expandedTicketIds.add(ticketId)) {
        _expandedTicketIds.remove(ticketId);
      }
    });
  }

  void _openHistory() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: TicketHistoryPage(
            savedTickets: widget.savedTickets,
            onTicketChanged: widget.onSaveTicket,
            onTicketDeleted: widget.onDeleteSavedTicket,
            onClose: () => Navigator.of(context).pop(),
          ),
        );
      },
    );
  }

  void _showHowItWorks() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: _HowItWorksSheet(
            profile: widget.profile,
            opportunities: widget.opportunities,
          ),
        );
      },
    );
  }

  void _refreshProposals() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Les propositions sont recalculées à partir des données disponibles.',
        ),
      ),
    );
    setState(() {});
  }
}

class _HowItWorksSheet extends StatefulWidget {
  const _HowItWorksSheet({required this.profile, required this.opportunities});

  final CompiledDecisionProfile profile;
  final List<Opportunity> opportunities;

  @override
  State<_HowItWorksSheet> createState() => _HowItWorksSheetState();
}

enum _HowItWorksTab { readings, combinedReadings }

class _HowItWorksSheetState extends State<_HowItWorksSheet> {
  _HowItWorksTab _selectedTab = _HowItWorksTab.readings;
  String _selectedCategory = 'Hiérarchie';
  String _query = '';
  String _selectedReadingId = _readingExplanations.first.id;
  String _selectedCombinedId = _combinedReadingExplanations.first.id;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HowItWorksHeader(onClose: () => Navigator.of(context).pop()),
            const SizedBox(height: 18),
            _HowItWorksTabs(
              selectedTab: _selectedTab,
              onChanged: (tab) {
                setState(() {
                  _selectedTab = tab;
                });
              },
            ),
            const SizedBox(height: 16),
            if (_selectedTab == _HowItWorksTab.readings)
              _ReadingsEducationView(
                query: _query,
                selectedCategory: _selectedCategory,
                selectedReadingId: _selectedReadingId,
                onQueryChanged: (value) {
                  setState(() {
                    _query = value;
                  });
                },
                onCategoryChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                    final first = _filteredReadings().firstOrNull;
                    if (first != null) {
                      _selectedReadingId = first.id;
                    }
                  });
                },
                onReadingSelected: (value) {
                  setState(() {
                    _selectedReadingId = value;
                  });
                },
                readings: _filteredReadings(),
              )
            else
              _CombinedReadingsEducationView(
                selectedCombinedId: _selectedCombinedId,
                onCombinedSelected: (value) {
                  setState(() {
                    _selectedCombinedId = value;
                  });
                },
                enabledReadingLabels: _enabledReadings(),
                activeCombinedLabels: _activeCombinedReadings(),
              ),
          ],
        ),
      ),
    );
  }

  List<_ReadingExplanation> _filteredReadings() {
    final normalizedQuery = _query.trim().toLowerCase();

    return [
      for (final reading in _readingExplanations)
        if (reading.category == _selectedCategory &&
            (normalizedQuery.isEmpty ||
                reading.title.toLowerCase().contains(normalizedQuery) ||
                reading.description.toLowerCase().contains(normalizedQuery)))
          reading,
    ];
  }

  List<String> _enabledReadings() {
    final labels = <String>[
      for (final preference in widget.profile.matchTypes.values)
        if (preference.enabled)
          OpportunityProfileCatalog.byId(preference.id)?.label ?? preference.id,
    ];

    if (labels.isEmpty) {
      return const ['Aucune famille activée'];
    }

    return labels.take(8).toList(growable: false);
  }

  List<String> _activeCombinedReadings() {
    final labels = <String>{};

    for (final opportunity in widget.opportunities) {
      for (final thesis in opportunity.retainedTheses) {
        labels.add(thesis.title);
      }
      if (labels.length >= 8) {
        break;
      }
    }

    if (labels.isEmpty) {
      return const ['Aucune lecture combinée disponible'];
    }

    return labels.take(8).toList(growable: false);
  }
}

class _HowItWorksHeader extends StatelessWidget {
  const _HowItWorksHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Comment ça fonctionne ?',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        IconButton(
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Fermer',
        ),
      ],
    );
  }
}

class _HowItWorksTabs extends StatelessWidget {
  const _HowItWorksTabs({required this.selectedTab, required this.onChanged});

  final _HowItWorksTab selectedTab;
  final ValueChanged<_HowItWorksTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          _HowItWorksTabButton(
            label: 'Lectures',
            isSelected: selectedTab == _HowItWorksTab.readings,
            onTap: () => onChanged(_HowItWorksTab.readings),
          ),
          _HowItWorksTabButton(
            label: 'Lectures combinées',
            isSelected: selectedTab == _HowItWorksTab.combinedReadings,
            onTap: () => onChanged(_HowItWorksTab.combinedReadings),
          ),
        ],
      ),
    );
  }
}

class _HowItWorksTabButton extends StatelessWidget {
  const _HowItWorksTabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isSelected
                      ? colorScheme.primary
                      : AppColors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReadingsEducationView extends StatelessWidget {
  const _ReadingsEducationView({
    required this.query,
    required this.selectedCategory,
    required this.selectedReadingId,
    required this.onQueryChanged,
    required this.onCategoryChanged,
    required this.onReadingSelected,
    required this.readings,
  });

  final String query;
  final String selectedCategory;
  final String selectedReadingId;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onReadingSelected;
  final List<_ReadingExplanation> readings;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedReading =
        readings
            .where((reading) => reading.id == selectedReadingId)
            .firstOrNull ??
        readings.firstOrNull ??
        _readingExplanations.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Une lecture est un signal simple détecté dans les données. Elle ne valide rien seule : elle sert de brique pour construire une lecture combinée.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        _ReadingSearchField(value: query, onChanged: onQueryChanged),
        const SizedBox(height: 12),
        _ReadingCategorySelector(
          selectedCategory: selectedCategory,
          onChanged: onCategoryChanged,
        ),
        const SizedBox(height: 12),
        for (final reading in readings)
          Column(
            children: [
              _ReadingExplanationTile(
                reading: reading,
                isSelected: reading.id == selectedReading.id,
                onTap: () => onReadingSelected(reading.id),
              ),
              if (reading.id == selectedReading.id) ...[
                const SizedBox(height: 4),
                _ReadingDetailCard(reading: selectedReading),
                const SizedBox(height: 8),
              ],
            ],
          ),
        if (readings.isEmpty)
          const _EmptyEducationMessage(
            message: 'Aucune lecture ne correspond à cette recherche.',
          ),
      ],
    );
  }
}

class _CombinedReadingsEducationView extends StatelessWidget {
  const _CombinedReadingsEducationView({
    required this.selectedCombinedId,
    required this.onCombinedSelected,
    required this.enabledReadingLabels,
    required this.activeCombinedLabels,
  });

  final String selectedCombinedId;
  final ValueChanged<String> onCombinedSelected;
  final List<String> enabledReadingLabels;
  final List<String> activeCombinedLabels;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final selected =
        _combinedReadingExplanations
            .where((combined) => combined.id == selectedCombinedId)
            .firstOrNull ??
        _combinedReadingExplanations.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Une lecture combinée apparaît quand plusieurs lectures compatibles racontent la même histoire. C’est elle qui peut ensuite être traduite en marchés cohérents.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        for (final combined in _combinedReadingExplanations)
          _CombinedReadingTile(
            combined: combined,
            isSelected: combined.id == selected.id,
            onTap: () => onCombinedSelected(combined.id),
          ),
        const SizedBox(height: 14),
        _CombinedReadingDetailCard(combined: selected),
        const SizedBox(height: 14),
        _HowItWorksGroup(
          icon: Icons.tune_rounded,
          title: 'Votre configuration',
          chips: enabledReadingLabels,
        ),
        const SizedBox(height: 12),
        _HowItWorksGroup(
          icon: Icons.auto_awesome_rounded,
          title: 'Lectures combinées actives',
          chips: activeCombinedLabels,
        ),
      ],
    );
  }
}

class _HowItWorksGroup extends StatelessWidget {
  const _HowItWorksGroup({
    required this.icon,
    required this.title,
    required this.chips,
  });

  final IconData icon;
  final String title;
  final List<String> chips;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colorScheme.primary, size: 19),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final chip in chips) _HowItWorksChip(label: chip),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HowItWorksChip extends StatelessWidget {
  const _HowItWorksChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              color: colorScheme.primary,
              size: 15,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadingSearchField extends StatelessWidget {
  const _ReadingSearchField({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search_rounded),
        hintText: 'Rechercher une lecture...',
        filled: true,
        fillColor: colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
    );
  }
}

class _ReadingCategorySelector extends StatelessWidget {
  const _ReadingCategorySelector({
    required this.selectedCategory,
    required this.onChanged,
  });

  final String selectedCategory;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              for (final category in _readingCategories)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(category),
                    selected: selectedCategory == category,
                    onSelected: (_) => onChanged(category),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(
              Icons.swipe_rounded,
              size: 14,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                'Faites glisser pour voir toutes les familles de lectures',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReadingExplanationTile extends StatelessWidget {
  const _ReadingExplanationTile({
    required this.reading,
    required this.isSelected,
    required this.onTap,
  });

  final _ReadingExplanation reading;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final badge = context.opportunities.badgeFor(
      reading.id,
      variant: isSelected
          ? AppReadingBadgeVariant.combined
          : AppReadingBadgeVariant.simple,
    );
    final softBadge = context.opportunities.badgeFor(
      reading.id,
      variant: AppReadingBadgeVariant.soft,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected ? badge.background : colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          side: BorderSide(color: isSelected ? badge.border : softBadge.border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.input),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(reading.icon, color: badge.iconColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reading.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        reading.shortDescription,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReadingDetailCard extends StatelessWidget {
  const _ReadingDetailCard({required this.reading});

  final _ReadingExplanation reading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final badge = context.opportunities.badgeFor(
      reading.id,
      variant: AppReadingBadgeVariant.combined,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(reading.icon, color: badge.iconColor, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    reading.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _EducationSection(
              title: 'Ce que cela signifie',
              child: Text(
                reading.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _EducationSection(
              title: 'Indicateurs utilisés',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final indicator in reading.indicators)
                    _HowItWorksChip(label: indicator),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _WarningEducationBox(text: reading.notMeaning),
            const SizedBox(height: 12),
            _EducationSection(
              title:
                  'Utilisée dans ${reading.usedIn.length} lecture${reading.usedIn.length > 1 ? 's' : ''} combinée${reading.usedIn.length > 1 ? 's' : ''}',
              child: Column(
                children: [
                  for (final combined in reading.usedIn)
                    _CompactEducationRow(
                      icon: Icons.hub_outlined,
                      label: combined,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CombinedReadingTile extends StatelessWidget {
  const _CombinedReadingTile({
    required this.combined,
    required this.isSelected,
    required this.onTap,
  });

  final _CombinedReadingExplanation combined;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected
            ? colorScheme.primary.withValues(alpha: 0.10)
            : colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          side: BorderSide(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outlineVariant,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.input),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(combined.icon, color: colorScheme.primary, size: 27),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        combined.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        combined.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CombinedReadingDetailCard extends StatelessWidget {
  const _CombinedReadingDetailCard({required this.combined});

  final _CombinedReadingExplanation combined;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              combined.title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              combined.description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            _EducationSection(
              title: 'Lectures nécessaires',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final reading in combined.requiredReadings)
                    _HowItWorksChip(label: reading),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _EducationSection(
              title: 'Quand est-elle validée ?',
              child: Text(
                'Elle est validée lorsque ces lectures sont détectées sur la même rencontre, se renforcent mutuellement et ne sont pas contredites par un signal majeur.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _EducationSection(
              title: 'Marchés compatibles possibles',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final market in combined.compatibleMarkets)
                    _PlainEducationChip(label: market),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _WarningEducationBox(
              text:
                  'Une lecture combinée ne garantit jamais le résultat. Elle indique seulement que plusieurs lectures compatibles pointent vers le même scénario.',
            ),
          ],
        ),
      ),
    );
  }
}

class _EducationSection extends StatelessWidget {
  const _EducationSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _WarningEducationBox extends StatelessWidget {
  const _WarningEducationBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _CompactEducationRow extends StatelessWidget {
  const _CompactEducationRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.onSurfaceVariant, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlainEducationChip extends StatelessWidget {
  const _PlainEducationChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _EmptyEducationMessage extends StatelessWidget {
  const _EmptyEducationMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ReadingExplanation {
  const _ReadingExplanation({
    required this.id,
    required this.category,
    required this.title,
    required this.shortDescription,
    required this.description,
    required this.indicators,
    required this.notMeaning,
    required this.usedIn,
    required this.icon,
  });

  final String id;
  final String category;
  final String title;
  final String shortDescription;
  final String description;
  final List<String> indicators;
  final String notMeaning;
  final List<String> usedIn;
  final IconData icon;
}

class _CombinedReadingExplanation {
  const _CombinedReadingExplanation({
    required this.id,
    required this.title,
    required this.description,
    required this.requiredReadings,
    required this.compatibleMarkets,
    required this.icon,
  });

  final String id;
  final String title;
  final String description;
  final List<String> requiredReadings;
  final List<String> compatibleMarkets;
  final IconData icon;
}

const _readingCategories = [
  'Hiérarchie',
  'Dynamique',
  'Domicile / extérieur',
  'Attaque',
  'Défense',
  'Buts',
  'xG',
  'Points de vigilance',
];

const _readingExplanations = [
  _ReadingExplanation(
    id: 'fragile_defense',
    category: 'Défense',
    title: 'Défense fragile',
    shortDescription:
        'L’équipe encaisse régulièrement ou concède beaucoup d’occasions.',
    description:
        'L’équipe présente plusieurs indicateurs de faiblesse défensive et concède plus d’occasions ou de buts que la moyenne.',
    indicators: [
      'Buts encaissés',
      'Clean sheets',
      'xG concédés',
      'Forme défensive',
    ],
    notMeaning:
        'Cela ne garantit pas que l’équipe encaissera au prochain match. C’est un signal statistique, pas une certitude.',
    usedIn: [
      'Match ouvert confirmé',
      'Domination attendue',
      'Équipe en grande difficulté',
      'Signal offensif',
    ],
    icon: Icons.security_rounded,
  ),
  _ReadingExplanation(
    id: 'home_strength',
    category: 'Domicile / extérieur',
    title: 'Domicile solide',
    shortDescription:
        'L’équipe obtient de meilleurs résultats dans son contexte domicile.',
    description:
        'Le contexte domicile renforce la lecture lorsque les résultats, buts marqués ou xG à domicile sont nettement meilleurs.',
    indicators: [
      'Victoires domicile',
      'Buts à domicile',
      'xG à domicile',
      'Forme domicile',
    ],
    notMeaning:
        'Cela ne transforme pas automatiquement l’équipe en favori. La lecture doit converger avec d’autres signaux.',
    usedIn: ['Domination attendue', 'Favori avec protection'],
    icon: Icons.home_rounded,
  ),
  _ReadingExplanation(
    id: 'level_gap',
    category: 'Hiérarchie',
    title: 'Écart de niveau',
    shortDescription:
        'Différence significative de niveau entre les deux équipes.',
    description:
        'Lector compare la hiérarchie sportive disponible : classement, points, différence de buts et volume de matchs joués.',
    indicators: [
      'Classement',
      'Points',
      'Différence de buts',
      'Échantillon joué',
    ],
    notMeaning:
        'Un écart de niveau ne suffit pas seul. Il doit être confirmé par la forme, le contexte ou le marché.',
    usedIn: ['Domination attendue', 'Favori avec protection'],
    icon: Icons.bar_chart_rounded,
  ),
  _ReadingExplanation(
    id: 'positive_form',
    category: 'Dynamique',
    title: 'Dynamique positive',
    shortDescription: 'La forme récente soutient le scénario analysé.',
    description:
        'Les résultats récents montrent une trajectoire favorable sur une fenêtre courte, généralement les cinq derniers matchs.',
    indicators: ['Forme récente', 'Points récents', 'Série en cours'],
    notMeaning:
        'La dynamique ne prédit pas le prochain résultat. Elle donne seulement un contexte récent.',
    usedIn: ['Domination attendue', 'Équipe meilleure que ses résultats'],
    icon: Icons.show_chart_rounded,
  ),
  _ReadingExplanation(
    id: 'prolific_attack',
    category: 'Attaque',
    title: 'Attaque prolifique',
    shortDescription: 'L’équipe crée ou marque régulièrement.',
    description:
        'L’équipe possède une production offensive élevée par rapport au niveau moyen de la compétition.',
    indicators: ['Buts marqués', 'Tirs', 'xG créés', 'Forme offensive'],
    notMeaning:
        'Une attaque prolifique peut rester muette sur un match isolé. La lecture doit être combinée.',
    usedIn: ['Match ouvert confirmé', 'Signal offensif'],
    icon: Icons.trending_up_rounded,
  ),
  _ReadingExplanation(
    id: 'open_match',
    category: 'Buts',
    title: 'Match ouvert',
    shortDescription: 'Le profil global suggère un match avec des espaces.',
    description:
        'Les profils offensifs et défensifs des deux équipes créent un contexte favorable aux occasions et aux buts.',
    indicators: ['Buts pour', 'Buts contre', 'Over 2.5', 'BTTS'],
    notMeaning:
        'Cela ne signifie pas que le match aura forcément beaucoup de buts. C’est une lecture de rythme.',
    usedIn: ['Match ouvert confirmé', 'Les deux équipes peuvent marquer'],
    icon: Icons.blur_on_rounded,
  ),
  _ReadingExplanation(
    id: 'xg_creation',
    category: 'xG',
    title: 'xG offensifs élevés',
    shortDescription: 'La création d’occasions de qualité est supérieure.',
    description:
        'Lector utilise uniquement des xG historiques capturés avant match. Les xG servent à nuancer les résultats réels.',
    indicators: ['xG pour', 'xG contre', 'Divergence buts/xG'],
    notMeaning:
        'Les xG ne sont pas des xG futurs. Ils décrivent ce qui s’est déjà produit.',
    usedIn: ['Signal offensif', 'Équipe meilleure que ses résultats'],
    icon: Icons.analytics_outlined,
  ),
  _ReadingExplanation(
    id: 'contradiction',
    category: 'Points de vigilance',
    title: 'Contradiction détectée',
    shortDescription: 'Un signal affaiblit ou nuance la lecture principale.',
    description:
        'Une contradiction indique qu’une lecture existe, mais qu’un autre signal invite à ne pas la surinterpréter.',
    indicators: ['Forme opposée', 'Échantillon faible', 'Signal divergent'],
    notMeaning:
        'Une contradiction ne supprime pas automatiquement une lecture. Elle réduit sa netteté.',
    usedIn: ['Résultats à nuancer', 'Match à éviter'],
    icon: Icons.warning_amber_rounded,
  ),
];

const _combinedReadingExplanations = [
  _CombinedReadingExplanation(
    id: 'expected_domination',
    title: 'Domination attendue',
    description:
        'Plusieurs lectures indiquent qu’une équipe possède un avantage sportif net et cohérent.',
    requiredReadings: [
      'Écart de niveau',
      'Domicile solide',
      'Dynamique positive',
    ],
    compatibleMarkets: ['Résultat', 'Double chance', 'Handicap prudent'],
    icon: Icons.home_work_outlined,
  ),
  _CombinedReadingExplanation(
    id: 'open_match_confirmed',
    title: 'Match ouvert confirmé',
    description:
        'Les lectures de rythme, d’attaque et de défense convergent vers un scénario avec occasions.',
    requiredReadings: ['Match ouvert', 'Attaque prolifique', 'Défense fragile'],
    compatibleMarkets: ['Plus/Moins buts', 'BTTS', 'Équipe marque'],
    icon: Icons.blur_on_rounded,
  ),
  _CombinedReadingExplanation(
    id: 'credible_outsider',
    title: 'Outsider crédible',
    description:
        'L’équipe moins attendue possède assez de lectures favorables pour mériter une attention.',
    requiredReadings: [
      'Dynamique positive',
      'Marché prudent',
      'Contradiction favori',
    ],
    compatibleMarkets: ['Double chance', 'Résultat protégé'],
    icon: Icons.shield_outlined,
  ),
  _CombinedReadingExplanation(
    id: 'team_in_difficulty',
    title: 'Équipe en grande difficulté',
    description:
        'Plusieurs lectures négatives convergent contre une équipe : forme, défense ou contexte.',
    requiredReadings: [
      'Défense fragile',
      'Dynamique négative',
      'Faible extérieur',
    ],
    compatibleMarkets: ['Résultat adverse', 'But adverse', 'Double chance'],
    icon: Icons.trending_down_rounded,
  ),
  _CombinedReadingExplanation(
    id: 'probable_goal',
    title: 'Signal offensif',
    description:
        'Une équipe combine création offensive, adversaire fragile et marché compatible.',
    requiredReadings: [
      'Attaque prolifique',
      'xG offensifs élevés',
      'Défense fragile',
    ],
    compatibleMarkets: ['Équipe marque', 'BTTS', 'Plus/Moins buts'],
    icon: Icons.sports_soccer_rounded,
  ),
];

class _TicketsHeader extends StatelessWidget {
  const _TicketsHeader({
    required this.onHistory,
    required this.onRefresh,
    required this.onSettings,
  });

  final VoidCallback onHistory;
  final VoidCallback onRefresh;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            'Mes tickets',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 12),
        _HeaderAction(
          icon: Icons.history_rounded,
          label: 'Historique',
          onTap: onHistory,
        ),
        const SizedBox(width: 8),
        _HeaderAction(
          icon: Icons.refresh_rounded,
          label: 'Recalculer',
          onTap: onRefresh,
        ),
        const SizedBox(width: 8),
        _HeaderAction(
          icon: Icons.settings_rounded,
          label: 'Paramètres',
          onTap: onSettings,
        ),
      ],
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(40),
      onTap: onTap,
      child: Tooltip(
        message: label,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(12),
            minimumSize: const Size.square(46),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          child: Icon(icon, color: colorScheme.onSurface, size: 22),
        ),
      ),
    );
  }
}

class _TicketOriginTabs extends StatelessWidget {
  const _TicketOriginTabs({
    required this.selectedTab,
    required this.copilotCount,
    required this.editedCount,
    required this.manualCount,
    required this.onChanged,
  });

  final _TicketTab selectedTab;
  final int copilotCount;
  final int editedCount;
  final int manualCount;
  final ValueChanged<_TicketTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 520;
        final tabs = [
          _TicketOriginTabData(
            tab: _TicketTab.copilot,
            icon: Icons.auto_awesome_rounded,
            label: 'Proposés par Lector',
            compactLabel: 'Lector',
            count: copilotCount,
          ),
          _TicketOriginTabData(
            tab: _TicketTab.edited,
            icon: Icons.edit_rounded,
            label: 'Modifiés',
            compactLabel: 'Modifiés',
            count: editedCount,
          ),
          _TicketOriginTabData(
            tab: _TicketTab.manual,
            icon: Icons.person_outline_rounded,
            label: 'Manuels',
            compactLabel: 'Manuels',
            count: manualCount,
          ),
        ];

        return Row(
          children: [
            for (final tab in tabs)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: tab == tabs.last ? 0 : 2),
                  child: _TicketOriginTab(
                    data: tab,
                    isSelected: selectedTab == tab.tab,
                    isCompact: isCompact,
                    onTap: () => onChanged(tab.tab),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TicketOriginTabData {
  const _TicketOriginTabData({
    required this.tab,
    required this.icon,
    required this.label,
    required this.compactLabel,
    required this.count,
  });

  final _TicketTab tab;
  final IconData icon;
  final String label;
  final String compactLabel;
  final int count;
}

class _TicketOriginTab extends StatelessWidget {
  const _TicketOriginTab({
    required this.data,
    required this.isSelected,
    required this.isCompact,
    required this.onTap,
  });

  final _TicketOriginTabData data;
  final bool isSelected;
  final bool isCompact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foreground = isSelected ? colorScheme.primary : colorScheme.onSurface;

    return Material(
      color: isSelected
          ? colorScheme.primary.withValues(alpha: 0.14)
          : colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        side: BorderSide(
          color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(data.icon, color: foreground, size: 19),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  isCompact ? data.compactLabel : data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _CountPill(count: data.count, isSelected: isSelected),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count, required this.isSelected});

  final int count;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isSelected
            ? colorScheme.primary
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Text(
          '$count',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _TicketTabContent extends StatelessWidget {
  const _TicketTabContent({
    required this.selectedTab,
    required this.result,
    required this.expandedTicketIds,
    required this.onToggleTicketExpanded,
    required this.onEditProfile,
    required this.onEditStrategies,
    required this.activeStrategyName,
    required this.savedTickets,
    required this.matches,
    required this.opportunities,
    required this.opportunityForMatchId,
    required this.onOpenOpportunity,
    required this.onSaveTicket,
  });

  final _TicketTab selectedTab;
  final TicketGenerationResult result;
  final Set<String> expandedTicketIds;
  final ValueChanged<String> onToggleTicketExpanded;
  final VoidCallback onEditProfile;
  final VoidCallback onEditStrategies;
  final String? activeStrategyName;
  final List<SavedTicket> savedTickets;
  final List<MatchBoardItem> matches;
  final List<Opportunity> opportunities;
  final Opportunity? Function(String matchId) opportunityForMatchId;
  final ValueChanged<Opportunity> onOpenOpportunity;
  final ValueChanged<SavedTicket> onSaveTicket;

  @override
  Widget build(BuildContext context) {
    return switch (selectedTab) {
      _TicketTab.copilot => _CopilotProposalsList(
        result: result,
        expandedTicketIds: expandedTicketIds,
        onToggleTicketExpanded: onToggleTicketExpanded,
        onEditProfile: onEditProfile,
        onEditStrategies: onEditStrategies,
        activeStrategyName: activeStrategyName,
        opportunityForMatchId: opportunityForMatchId,
        matches: matches,
        opportunities: opportunities,
        onOpenOpportunity: onOpenOpportunity,
        onSaveTicket: onSaveTicket,
      ),
      _TicketTab.edited =>
        _modifiedTickets.isEmpty
            ? const _EmptyTicketTab(
                icon: Icons.edit_note_rounded,
                title: 'Aucun ticket modifié',
                message:
                    'Vous n’avez encore modifié aucune proposition Lector.',
              )
            : _SavedTicketsList(
                title: 'Mes tickets modifiés',
                tickets: _modifiedTickets,
                strategies: result.strategies
                    .map((result) => result.strategy)
                    .toList(growable: false),
                matches: matches,
                opportunities: opportunities,
                opportunityForMatchId: opportunityForMatchId,
                onSaveTicket: onSaveTicket,
              ),
      _TicketTab.manual =>
        _manualTickets.isEmpty
            ? const _EmptyTicketTab(
                icon: Icons.add_circle_outline_rounded,
                title: 'Aucun ticket manuel',
                message: 'Vous n’avez encore créé aucun ticket manuellement.',
              )
            : _SavedTicketsList(
                title: 'Mes tickets enregistrés',
                tickets: _manualTickets,
              ),
    };
  }

  List<SavedTicket> get _manualTickets {
    return [
      for (final ticket in savedTickets)
        if (ticket.source == SavedTicketSource.manual) ticket,
    ];
  }

  List<SavedTicket> get _modifiedTickets {
    return [
      for (final ticket in savedTickets)
        if (ticket.source == SavedTicketSource.copilotModified) ticket,
    ];
  }
}

class _CopilotProposalsList extends StatelessWidget {
  const _CopilotProposalsList({
    required this.result,
    required this.expandedTicketIds,
    required this.onToggleTicketExpanded,
    required this.onEditProfile,
    required this.onEditStrategies,
    required this.activeStrategyName,
    required this.opportunityForMatchId,
    required this.matches,
    required this.opportunities,
    required this.onOpenOpportunity,
    required this.onSaveTicket,
  });

  final TicketGenerationResult result;
  final Set<String> expandedTicketIds;
  final ValueChanged<String> onToggleTicketExpanded;
  final VoidCallback onEditProfile;
  final VoidCallback onEditStrategies;
  final String? activeStrategyName;
  final Opportunity? Function(String matchId) opportunityForMatchId;
  final List<MatchBoardItem> matches;
  final List<Opportunity> opportunities;
  final ValueChanged<Opportunity> onOpenOpportunity;
  final ValueChanged<SavedTicket> onSaveTicket;

  @override
  Widget build(BuildContext context) {
    if (result.status == TicketGenerationStatus.profileIncomplete) {
      final activeStrategyMessage = activeStrategyName == null
          ? ''
          : ' Votre stratégie $activeStrategyName est active.';
      return _EmptyState(
        icon: Icons.tune_rounded,
        title: 'Préférences de lecture incomplètes',
        message:
            '$activeStrategyMessage Ajoutez vos compétitions, lectures et marchés pour fournir des sélections à Lector.',
        actionLabel: 'Configurer mes préférences',
        onAction: onEditProfile,
      );
    }

    if (result.status == TicketGenerationStatus.noActiveStrategy) {
      return _EmptyState(
        icon: Icons.rule_rounded,
        title: 'Aucune stratégie active',
        message:
            'Créez ou activez une stratégie pour permettre à Lector de générer des tickets.',
        actionLabel: 'Gérer mes stratégies',
        onAction: onEditStrategies,
      );
    }

    if (!result.hasTickets) {
      return Column(
        children: [
          for (final strategyResult in result.strategies)
            _StrategyEmptyState(result: strategyResult),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final strategyResult in result.strategies)
          for (final ticket in strategyResult.tickets)
            _GeneratedTicketCard(
              ticket: ticket,
              strategy: strategyResult.strategy,
              isExpanded: expandedTicketIds.contains(ticket.id),
              onToggleExpanded: () => onToggleTicketExpanded(ticket.id),
              opportunityForMatchId: opportunityForMatchId,
              matches: matches,
              opportunities: opportunities,
              onOpenOpportunity: onOpenOpportunity,
              onSaveTicket: onSaveTicket,
            ),
      ],
    );
  }
}

class _StrategyEmptyState extends StatelessWidget {
  const _StrategyEmptyState({required this.result});

  final StrategyTicketGenerationResult result;

  @override
  Widget build(BuildContext context) {
    final message = switch (result.status) {
      TicketGenerationStatus.noUsableOpportunity =>
        'Aucune lecture combinée exploitable ne permet actuellement de construire un ticket conforme.',
      TicketGenerationStatus.notEnoughCompatiblePicks =>
        'Des picks sont disponibles, mais pas assez pour respecter le minimum de sélections.',
      TicketGenerationStatus.noCombinationWithinTotalOdds =>
        'Des picks sont disponibles, mais aucune combinaison ne respecte toutes les contraintes.',
      TicketGenerationStatus.invalidStrategyConfiguration =>
        'Cette stratégie possède une configuration invalide.',
      _ => 'Aucun ticket généré pour cette stratégie.',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _EmptyState(
        icon: Icons.info_outline_rounded,
        title: result.strategy.name,
        message: message,
      ),
    );
  }
}

class _GeneratedTicketCard extends StatelessWidget {
  const _GeneratedTicketCard({
    required this.ticket,
    required this.strategy,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.opportunityForMatchId,
    required this.matches,
    required this.opportunities,
    required this.onOpenOpportunity,
    required this.onSaveTicket,
  });

  final GeneratedTicket ticket;
  final TicketStrategy strategy;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final Opportunity? Function(String matchId) opportunityForMatchId;
  final List<MatchBoardItem> matches;
  final List<Opportunity> opportunities;
  final ValueChanged<Opportunity> onOpenOpportunity;
  final ValueChanged<SavedTicket> onSaveTicket;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = _strategyAccent(context, strategy);
    final keyReadings = _keyReadings();
    final convergentReadingCount = _convergentReadingCount();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: ticket.isConform
                ? accent.withValues(alpha: 0.58)
                : colorScheme.error,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TicketSummaryHeader(
                ticket: ticket,
                strategy: strategy,
                accent: accent,
              ),
              const SizedBox(height: 8),
              Column(
                children: [
                  for (final entry in ticket.picks.indexed) ...[
                    _GeneratedPickRow(
                      pick: entry.$2,
                      accent: accent,
                      opportunity: opportunityForMatchId(entry.$2.matchId),
                      onOpenOpportunity: onOpenOpportunity,
                    ),
                    if (entry.$1 != ticket.picks.length - 1)
                      Divider(height: 1, color: colorScheme.outlineVariant),
                  ],
                ],
              ),
              if (convergentReadingCount > 0) ...[
                const SizedBox(height: 10),
                _TicketReadingsFooter(
                  readingCount: convergentReadingCount,
                  hasDetails: keyReadings.isNotEmpty,
                  accent: accent,
                  isExpanded: isExpanded,
                  onToggleExpanded: onToggleExpanded,
                ),
              ],
              const SizedBox(height: 10),
              _GeneratedTicketActions(
                accent: accent,
                onSave: () => _saveCopilotTicket(context),
                onModify: () => _openModifiedTicketSheet(context),
              ),
              if (isExpanded && keyReadings.isNotEmpty) ...[
                const SizedBox(height: 10),
                _KeyReadingsList(readings: keyReadings),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _strategyAccent(BuildContext context, TicketStrategy strategy) {
    if (strategy.pickTypes.contains(PickType.audacious)) {
      return context.opportunities.levelGap;
    }
    if (strategy.pickTypes.contains(PickType.normal)) {
      return context.semantic.warning;
    }
    if (strategy.pickTypes.contains(PickType.prudent)) {
      return context.brand.accent;
    }
    return context.semantic.info;
  }

  List<String> _keyReadings() {
    final labels = <String>{};

    for (final pick in ticket.picks) {
      final opportunity = opportunityForMatchId(pick.matchId);
      if (opportunity == null) {
        continue;
      }

      for (final reading in opportunity.supportingReadings) {
        labels.add(_readingShortLabel(reading));
      }

      if (labels.length >= 4) {
        break;
      }
    }

    if (labels.isEmpty) {
      for (final pick in ticket.picks) {
        labels.addAll(
          pick.opportunityProfileIds
              .map(OpportunityProfileCatalog.byId)
              .whereType<OpportunityProfileDefinition>()
              .map((profile) => profile.label),
        );
        if (labels.length >= 4) {
          break;
        }
      }
    }

    return labels.take(4).toList(growable: false);
  }

  int _convergentReadingCount() {
    final readingKeys = <String>{};

    for (final pick in ticket.picks) {
      final opportunity = opportunityForMatchId(pick.matchId);
      if (opportunity == null) {
        continue;
      }

      for (final reading in opportunity.supportingReadings) {
        readingKeys.add(
          '${pick.matchId}|${reading.id}|${reading.subjectTeamId}',
        );
      }
    }

    return readingKeys.length;
  }

  void _saveCopilotTicket(BuildContext context) {
    final now = DateTime.now().toUtc();
    onSaveTicket(SavedTicket.fromGenerated(ticket: ticket, savedAt: now));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Ticket Lector enregistré.')));
  }

  Future<void> _openModifiedTicketSheet(BuildContext context) async {
    final savedTicket = await showModalBottomSheet<SavedTicket>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ModifyGeneratedTicketSheet(
        ticket: ticket,
        strategy: strategy,
        opportunityForMatchId: opportunityForMatchId,
        matches: matches,
        opportunities: opportunities,
      ),
    );
    if (savedTicket == null || !context.mounted) {
      return;
    }

    onSaveTicket(savedTicket);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Ticket modifié enregistré.')));
  }

  String _readingShortLabel(FootballReading reading) {
    return switch (reading.id) {
      'ranking_superiority' => 'Domination attendue',
      'structural_level_gap' => 'Écart structurel',
      'positive_streak' => 'Série positive',
      'negative_streak' => 'Série négative',
      'improving_form' => 'Forme en hausse',
      'declining_form' => 'Forme en baisse',
      'strong_home_team' => 'Solide à domicile',
      'weak_away_team' => 'Faible à l’extérieur',
      'home_away_mismatch' => 'Avantage domicile/extérieur',
      'prolific_attack' || 'attack_in_form' => 'Création offensive élevée',
      'fragile_defense' || 'high_xg_conceded' => 'Défense fragile',
      'solid_defense' => 'Défense solide',
      'open_match_profile' || 'frequent_over_25' => 'Match ouvert',
      'closed_match_profile' || 'frequent_under_25' => 'Match fermé',
      'frequent_btts' => 'BTTS récurrent',
      'high_xg_creation' => 'xG offensifs élevés',
      'low_xg_creation' => 'xG offensifs faibles',
      _ => reading.evidence.isEmpty ? reading.id : reading.evidence.first.label,
    };
  }
}

class _GeneratedTicketActions extends StatelessWidget {
  const _GeneratedTicketActions({
    required this.accent,
    required this.onSave,
    required this.onModify,
  });

  final Color accent;
  final VoidCallback onSave;
  final VoidCallback onModify;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _CompactTicketActionButton(
          label: 'Enregistrer',
          icon: Icons.bookmark_add_outlined,
          onPressed: onSave,
          isPrimary: true,
        ),
        _CompactTicketActionButton(
          label: 'Modifier',
          icon: Icons.edit_outlined,
          onPressed: onModify,
          foregroundColor: accent,
        ),
      ],
    );
  }
}

class _CompactTicketActionButton extends StatelessWidget {
  const _CompactTicketActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isPrimary = false,
    this.foregroundColor,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isPrimary;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final minimumSize = const Size(0, 42);
    final padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 9);
    final textStyle = Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900);

    if (isPrimary) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label, style: textStyle),
        style: FilledButton.styleFrom(
          minimumSize: minimumSize,
          padding: padding,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: textStyle),
      style: OutlinedButton.styleFrom(
        foregroundColor: foregroundColor,
        minimumSize: minimumSize,
        padding: padding,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _ModifyGeneratedTicketSheet extends StatefulWidget {
  const _ModifyGeneratedTicketSheet({
    required this.ticket,
    required this.strategy,
    required this.opportunityForMatchId,
    required this.matches,
    required this.opportunities,
    this.existingTicket,
  });

  final GeneratedTicket ticket;
  final TicketStrategy strategy;
  final Opportunity? Function(String matchId) opportunityForMatchId;
  final List<MatchBoardItem> matches;
  final List<Opportunity> opportunities;
  final SavedTicket? existingTicket;

  @override
  State<_ModifyGeneratedTicketSheet> createState() =>
      _ModifyGeneratedTicketSheetState();
}

class _ModifyGeneratedTicketSheetState
    extends State<_ModifyGeneratedTicketSheet> {
  late final Set<String> _retainedPickKeys = {
    for (final pick in widget.ticket.picks) _pickKey(pick),
  };
  late final Map<String, GeneratedTicketPick> _editedPicks = {
    for (final pick in widget.ticket.picks) _pickKey(pick): pick,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final retainedPicks = _retainedPicks();
    final totalOdds = _totalOdds(retainedPicks);
    final compliance = _strategyCompliance(retainedPicks, totalOdds);
    final removedCount = widget.ticket.picks.length - retainedPicks.length;
    final opportunityReplacedCount = _replacedOpportunityCount();
    final replacedCount = _replacedMarketCount();
    final hasChanges =
        removedCount > 0 || opportunityReplacedCount > 0 || replacedCount > 0;
    final canSave = retainedPicks.isNotEmpty && hasChanges;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.82,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Modifier le ticket',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fermer',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Ajustez une proposition Lector en retirant une sélection ou en choisissant un autre marché compatible.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              _ModifiedTicketSummary(
                selectionCount: retainedPicks.length,
                totalOdds: totalOdds,
                compliance: compliance,
              ),
              const SizedBox(height: 14),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh.withValues(
                    alpha: 0.28,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Material(
                  color: AppColors.transparent,
                  child: Column(
                    children: [
                      for (final pick in widget.ticket.picks)
                        _EditablePickTile(
                          originalPick: pick,
                          currentPick: _editedPicks[_pickKey(pick)] ?? pick,
                          isRetained: _retainedPickKeys.contains(
                            _pickKey(pick),
                          ),
                          options: _marketOptionsFor(pick),
                          opportunityOptions: _opportunityOptionsFor(pick),
                          onRetainedChanged: (value) =>
                              _setPickRetained(pick, value),
                          onOpportunityChanged: (option) =>
                              _replacePickOpportunity(pick, option),
                          onOptionChanged: (option) =>
                              _replacePickMarket(pick, option),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: canSave ? _saveModifiedTicket : null,
                child: const Text('Enregistrer la version modifiée'),
              ),
              if (!canSave) ...[
                const SizedBox(height: 8),
                Text(
                  retainedPicks.isEmpty
                      ? 'Conservez au moins une sélection.'
                      : 'Modifiez au moins un marché ou retirez une sélection.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _setPickRetained(GeneratedTicketPick pick, bool? value) {
    setState(() {
      if (value == true) {
        _retainedPickKeys.add(_pickKey(pick));
      } else {
        _retainedPickKeys.remove(_pickKey(pick));
      }
    });
  }

  void _replacePickMarket(
    GeneratedTicketPick originalPick,
    _EditableMarketOption option,
  ) {
    final currentPick = _editedPicks[_pickKey(originalPick)] ?? originalPick;
    setState(() {
      _editedPicks[_pickKey(originalPick)] = _pickFromOption(
        currentPick,
        option,
      );
      _retainedPickKeys.add(_pickKey(originalPick));
    });
  }

  void _replacePickOpportunity(
    GeneratedTicketPick originalPick,
    _EditableOpportunityOption option,
  ) {
    setState(() {
      _editedPicks[_pickKey(originalPick)] = option.pick;
      _retainedPickKeys.add(_pickKey(originalPick));
    });
  }

  List<GeneratedTicketPick> _retainedPicks() {
    return [
      for (final pick in widget.ticket.picks)
        if (_retainedPickKeys.contains(_pickKey(pick)))
          _editedPicks[_pickKey(pick)] ?? pick,
    ];
  }

  List<_EditableMarketOption> _marketOptionsFor(GeneratedTicketPick pick) {
    final currentPick = _editedPicks[_pickKey(pick)] ?? pick;
    final optionsByKey = <String, _EditableMarketOption>{};

    void addOption({
      required MatchMarket market,
      required MarketOdds selection,
      required String thesisId,
      required bool isRecommended,
    }) {
      final pickType = pickTypeForOdds(selection.odds);
      if (pickType == null) {
        return;
      }

      final option = _EditableMarketOption(
        market: market,
        selection: selection,
        thesisId: thesisId,
        isRecommended: isRecommended,
        pickType: pickType,
      );
      optionsByKey[_optionKey(option.market.id, option.selection.id)] = option;
    }

    addOption(
      market: MatchMarket(
        id: currentPick.marketId,
        label: currentPick.marketLabel,
        selections: [
          MarketOdds(
            id: currentPick.selectionId,
            label: currentPick.selectionLabel,
            odds: currentPick.odds,
          ),
        ],
      ),
      selection: MarketOdds(
        id: currentPick.selectionId,
        label: currentPick.selectionLabel,
        odds: currentPick.odds,
      ),
      thesisId: currentPick.thesisId,
      isRecommended: _samePick(currentPick, pick),
    );

    final match = widget.matches
        .where((item) => item.id == pick.matchId)
        .firstOrNull;
    if (match != null) {
      for (final candidate in match.betCandidates) {
        final resolved = match.recommendedMarketFor(candidate);
        if (resolved == null) {
          continue;
        }
        addOption(
          market: resolved.market,
          selection: resolved.selection,
          thesisId:
              candidate.supportingThesisIds.firstOrNull ?? 'market_assessment',
          isRecommended: candidate.selectionId == pick.selectionId,
        );
      }
    }

    return optionsByKey.values.toList(growable: false)..sort((a, b) {
      if (a.isRecommended != b.isRecommended) {
        return a.isRecommended ? -1 : 1;
      }
      final marketComparison = a.market.label.compareTo(b.market.label);
      if (marketComparison != 0) {
        return marketComparison;
      }
      return a.selection.odds.compareTo(b.selection.odds);
    });
  }

  List<_EditableOpportunityOption> _opportunityOptionsFor(
    GeneratedTicketPick pick,
  ) {
    final currentPick = _editedPicks[_pickKey(pick)] ?? pick;
    final optionsByMatchId = <String, _EditableOpportunityOption>{
      currentPick.matchId: _EditableOpportunityOption(pick: currentPick),
    };

    for (final match in widget.matches) {
      for (final candidate in match.betCandidates) {
        final candidatePick = GeneratedTicketPick.fromBetCandidate(
          match,
          candidate,
        );
        if (candidatePick == null) {
          continue;
        }
        optionsByMatchId[candidatePick.matchId] = _EditableOpportunityOption(
          pick: candidatePick,
        );
      }
    }

    return optionsByMatchId.values.toList(growable: false)..sort((a, b) {
      if (a.pick.matchId == currentPick.matchId) {
        return -1;
      }
      if (b.pick.matchId == currentPick.matchId) {
        return 1;
      }
      final competitionComparison = a.pick.competitionName.compareTo(
        b.pick.competitionName,
      );
      if (competitionComparison != 0) {
        return competitionComparison;
      }
      return a.pick.homeTeam.compareTo(b.pick.homeTeam);
    });
  }

  GeneratedTicketPick _pickFromOption(
    GeneratedTicketPick originalPick,
    _EditableMarketOption option,
  ) {
    return GeneratedTicketPick(
      opportunityId: originalPick.opportunityId,
      matchId: originalPick.matchId,
      homeTeam: originalPick.homeTeam,
      awayTeam: originalPick.awayTeam,
      competitionName: originalPick.competitionName,
      kickoffLabel: originalPick.kickoffLabel,
      kickoff: originalPick.kickoff,
      marketId: option.market.id,
      marketLabel: option.market.label,
      selectionId: option.selection.id,
      selectionLabel: option.selection.label,
      odds: _normalizeOdds(option.selection.odds),
      pickType: option.pickType,
      thesisId: option.thesisId,
      opportunityProfileIds: originalPick.opportunityProfileIds,
      engineScore: originalPick.engineScore,
    );
  }

  void _saveModifiedTicket() {
    final retainedPicks = _retainedPicks();
    final removedCount = widget.ticket.picks.length - retainedPicks.length;
    final opportunityReplacedCount = _replacedOpportunityCount();
    final replacedCount = _replacedMarketCount();
    final now = DateTime.now().toUtc();
    final parts = [
      if (removedCount > 0)
        '$removedCount sélection${removedCount > 1 ? 's' : ''} supprimée${removedCount > 1 ? 's' : ''}',
      if (opportunityReplacedCount > 0)
        '$opportunityReplacedCount rencontre${opportunityReplacedCount > 1 ? 's' : ''} remplacée${opportunityReplacedCount > 1 ? 's' : ''}',
      if (replacedCount > 0)
        '$replacedCount marché${replacedCount > 1 ? 's' : ''} remplacé${replacedCount > 1 ? 's' : ''}',
    ];

    Navigator.of(context).pop(
      SavedTicket.fromGenerated(
        ticket: widget.ticket,
        picks: retainedPicks,
        savedAt: widget.existingTicket?.createdAt ?? now,
        source: SavedTicketSource.copilotModified,
        name: 'Ticket Lector modifié',
        modificationSummary: parts.join(' · '),
        modificationDetails: _modificationDetails(),
      ),
    );
  }

  List<String> _modificationDetails() {
    final details = <String>[];
    for (final originalPick in widget.ticket.picks) {
      final key = _pickKey(originalPick);
      if (!_retainedPickKeys.contains(key)) {
        details.add(
          'Sélection supprimée : ${originalPick.homeTeam} - ${originalPick.awayTeam}',
        );
        continue;
      }

      final editedPick = _editedPicks[key] ?? originalPick;
      if (originalPick.matchId != editedPick.matchId) {
        details.add(
          'Rencontre remplacée : ${originalPick.homeTeam} - ${originalPick.awayTeam} → ${editedPick.homeTeam} - ${editedPick.awayTeam}',
        );
      } else if (!_samePick(originalPick, editedPick)) {
        details.add(
          'Marché remplacé : ${originalPick.homeTeam} - ${originalPick.awayTeam} · ${originalPick.marketLabel} ${originalPick.selectionLabel} → ${editedPick.marketLabel} ${editedPick.selectionLabel}',
        );
      }
    }

    return details;
  }

  double _totalOdds(List<GeneratedTicketPick> picks) {
    if (picks.isEmpty) {
      return 0;
    }

    var value = 1.0;
    for (final pick in picks) {
      value *= pick.odds;
    }
    return (value * 100).round() / 100;
  }

  int _replacedMarketCount() {
    var count = 0;
    for (final originalPick in widget.ticket.picks) {
      final editedPick = _editedPicks[_pickKey(originalPick)] ?? originalPick;
      if (_retainedPickKeys.contains(_pickKey(originalPick)) &&
          originalPick.matchId == editedPick.matchId &&
          !_samePick(originalPick, editedPick)) {
        count += 1;
      }
    }
    return count;
  }

  int _replacedOpportunityCount() {
    var count = 0;
    for (final originalPick in widget.ticket.picks) {
      final editedPick = _editedPicks[_pickKey(originalPick)] ?? originalPick;
      if (_retainedPickKeys.contains(_pickKey(originalPick)) &&
          originalPick.matchId != editedPick.matchId) {
        count += 1;
      }
    }
    return count;
  }

  _StrategyCompliance _strategyCompliance(
    List<GeneratedTicketPick> picks,
    double totalOdds,
  ) {
    if (picks.isEmpty) {
      return const _StrategyCompliance(
        isConform: false,
        message: 'Aucune sélection conservée',
      );
    }

    final matchIds = <String>{};
    for (final pick in picks) {
      if (!matchIds.add(pick.matchId)) {
        return const _StrategyCompliance(
          isConform: false,
          message: 'Un match est présent plusieurs fois',
        );
      }
    }

    if (!widget.strategy.acceptsSelectionCount(picks.length)) {
      return _StrategyCompliance(
        isConform: false,
        message:
            '${widget.strategy.minimumSelections}-${widget.strategy.maximumSelections} sélections attendues',
      );
    }

    if (!widget.strategy.acceptsTotalOdds(totalOdds)) {
      final maximum = widget.strategy.maximumTotalOdds;
      return _StrategyCompliance(
        isConform: false,
        message: maximum == null
            ? 'Cote totale minimale ${widget.strategy.minimumTotalOdds.toStringAsFixed(2)}'
            : 'Cote totale attendue ${widget.strategy.minimumTotalOdds.toStringAsFixed(2)}-${maximum.toStringAsFixed(2)}',
      );
    }

    for (final pick in picks) {
      if (!widget.strategy.allowsPickType(pick.pickType)) {
        return const _StrategyCompliance(
          isConform: false,
          message: 'Type de cote hors stratégie',
        );
      }
    }

    return _StrategyCompliance(
      isConform: true,
      message: 'Conforme à ${widget.strategy.name}',
    );
  }

  bool _samePick(GeneratedTicketPick a, GeneratedTicketPick b) {
    return a.matchId == b.matchId &&
        a.marketId == b.marketId &&
        a.selectionId == b.selectionId &&
        _normalizeOdds(a.odds) == _normalizeOdds(b.odds);
  }

  String _optionKey(String marketId, String selectionId) {
    return '$marketId|$selectionId';
  }

  String _pickKey(GeneratedTicketPick pick) {
    return '${pick.matchId}|${pick.marketId}|${pick.selectionId}';
  }

  double _normalizeOdds(double odds) => (odds * 100).round() / 100;
}

class _EditableMarketOption {
  const _EditableMarketOption({
    required this.market,
    required this.selection,
    required this.thesisId,
    required this.isRecommended,
    required this.pickType,
  });

  final MatchMarket market;
  final MarketOdds selection;
  final String thesisId;
  final bool isRecommended;
  final PickType pickType;
}

class _EditableOpportunityOption {
  const _EditableOpportunityOption({required this.pick});

  final GeneratedTicketPick pick;
}

class _StrategyCompliance {
  const _StrategyCompliance({required this.isConform, required this.message});

  final bool isConform;
  final String message;
}

class _ModifiedTicketSummary extends StatelessWidget {
  const _ModifiedTicketSummary({
    required this.selectionCount,
    required this.totalOdds,
    required this.compliance,
  });

  final int selectionCount;
  final double totalOdds;
  final _StrategyCompliance compliance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final semantic = context.semantic;
    final complianceColor = compliance.isConform
        ? semantic.success
        : semantic.warning;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _SummaryChip(
              icon: Icons.format_list_numbered_rounded,
              label:
                  '$selectionCount sélection${selectionCount > 1 ? 's' : ''}',
              color: colorScheme.primary,
            ),
            _SummaryChip(
              icon: Icons.stacked_line_chart_rounded,
              label: 'Cote totale ${totalOdds.toStringAsFixed(2)}',
              color: colorScheme.primary,
            ),
            _SummaryChip(
              icon: compliance.isConform
                  ? Icons.verified_outlined
                  : Icons.warning_amber_rounded,
              label: compliance.message,
              color: complianceColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 17),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditablePickTile extends StatelessWidget {
  const _EditablePickTile({
    required this.originalPick,
    required this.currentPick,
    required this.isRetained,
    required this.options,
    required this.opportunityOptions,
    required this.onRetainedChanged,
    required this.onOpportunityChanged,
    required this.onOptionChanged,
  });

  final GeneratedTicketPick originalPick;
  final GeneratedTicketPick currentPick;
  final bool isRetained;
  final List<_EditableMarketOption> options;
  final List<_EditableOpportunityOption> opportunityOptions;
  final ValueChanged<bool?> onRetainedChanged;
  final ValueChanged<_EditableOpportunityOption> onOpportunityChanged;
  final ValueChanged<_EditableMarketOption> onOptionChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selectedKey = _optionKey(
      currentPick.marketId,
      currentPick.selectionId,
    );
    final selectedMatchId = currentPick.matchId;

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isRetained
              ? colorScheme.surfaceContainerHigh.withValues(alpha: 0.20)
              : AppColors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.input),
          border: Border.all(
            color: isRetained
                ? colorScheme.outlineVariant
                : colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Checkbox(value: isRetained, onChanged: onRetainedChanged),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${originalPick.homeTeam} - ${originalPick.awayTeam}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          originalPick.competitionName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    currentPick.odds.toStringAsFixed(2),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue:
                    opportunityOptions.any(
                      (option) => option.pick.matchId == selectedMatchId,
                    )
                    ? selectedMatchId
                    : null,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Opportunité compatible',
                  isDense: true,
                ),
                items: [
                  for (final option in opportunityOptions)
                    DropdownMenuItem<String>(
                      value: option.pick.matchId,
                      child: Text(
                        _opportunityLabel(option),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: isRetained
                    ? (value) {
                        if (value == null) {
                          return;
                        }
                        final option = opportunityOptions.firstWhere(
                          (option) => option.pick.matchId == value,
                        );
                        onOpportunityChanged(option);
                      }
                    : null,
              ),
              const SizedBox(height: 8),
              if (options.length <= 1)
                Text(
                  '${currentPick.marketLabel} · ${currentPick.selectionLabel}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue:
                      options.any(
                        (option) =>
                            _optionKey(option.market.id, option.selection.id) ==
                            selectedKey,
                      )
                      ? selectedKey
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Marché compatible',
                    isDense: true,
                  ),
                  items: [
                    for (final option in options)
                      DropdownMenuItem<String>(
                        value: _optionKey(
                          option.market.id,
                          option.selection.id,
                        ),
                        child: Text(
                          _optionLabel(option),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: isRetained
                      ? (value) {
                          if (value == null) {
                            return;
                          }
                          final option = options.firstWhere(
                            (option) =>
                                _optionKey(
                                  option.market.id,
                                  option.selection.id,
                                ) ==
                                value,
                          );
                          onOptionChanged(option);
                        }
                      : null,
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _optionKey(String marketId, String selectionId) {
    return '$marketId|$selectionId';
  }

  static String _optionLabel(_EditableMarketOption option) {
    final recommended = option.isRecommended ? ' · recommandé' : '';
    return '${option.market.label} · ${option.selection.label} · ${option.selection.odds.toStringAsFixed(2)}$recommended';
  }

  static String _opportunityLabel(_EditableOpportunityOption option) {
    return '${option.pick.competitionName} · ${option.pick.homeTeam} - ${option.pick.awayTeam}';
  }
}

class _TicketSummaryHeader extends StatelessWidget {
  const _TicketSummaryHeader({
    required this.ticket,
    required this.strategy,
    required this.accent,
  });

  final GeneratedTicket ticket;
  final TicketStrategy strategy;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final topLine = Row(
      children: [
        Flexible(
          child: _StrategyNameBadge(name: ticket.strategyName, accent: accent),
        ),
        const SizedBox(width: 8),
        _OriginBadge(origin: ticket.origin),
      ],
    );
    final totalOdds = _TicketMetric(
      label: 'Cote totale',
      value: ticket.totalOdds.toStringAsFixed(2),
      accent: accent,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 430;

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: topLine),
                  const SizedBox(width: 4),
                  totalOdds,
                ],
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [topLine],
              ),
            ),
            const SizedBox(width: 10),
            totalOdds,
          ],
        );
      },
    );
  }
}

class _StrategyNameBadge extends StatelessWidget {
  const _StrategyNameBadge({required this.name, required this.accent});

  final String name;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Text(
          'Stratégie : $name',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: accent,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _OriginBadge extends StatelessWidget {
  const _OriginBadge({required this.origin});

  final TicketOrigin origin;

  @override
  Widget build(BuildContext context) {
    final label = switch (origin) {
      TicketOrigin.copilotGenerated => 'Créé par Lector',
      TicketOrigin.copilotEdited => 'Modifié',
      TicketOrigin.manual => 'Créé manuellement',
    };

    return Flexible(
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TicketMetric extends StatelessWidget {
  const _TicketMetric({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            color: accent,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _TinyMeta extends StatelessWidget {
  const _TinyMeta({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _MarketBadge extends StatelessWidget {
  const _MarketBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _GeneratedPickRow extends StatelessWidget {
  const _GeneratedPickRow({
    required this.pick,
    required this.accent,
    required this.opportunity,
    required this.onOpenOpportunity,
  });

  final GeneratedTicketPick pick;
  final Color accent;
  final Opportunity? opportunity;
  final ValueChanged<Opportunity> onOpenOpportunity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: opportunity == null
            ? null
            : () => onOpenOpportunity(opportunity!),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              SizedBox(width: 44, child: _PickTimeMeta(pick: pick)),
              const SizedBox(width: 6),
              Expanded(
                child: _PickTeams(
                  pick: pick,
                  homeLogoUrl: opportunity?.homeTeam.logoUrl,
                  awayLogoUrl: opportunity?.awayTeam.logoUrl,
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 72,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _MarketBadge(label: _marketLabel(pick)),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 54,
                child: Text(
                  _selectionLabel(pick),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 42,
                child: Text(
                  pick.odds.toStringAsFixed(2),
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _marketLabel(GeneratedTicketPick pick) =>
      _marketLabelFor(pick.marketLabel);

  String _selectionLabel(GeneratedTicketPick pick) =>
      _selectionLabelFor(pick.selectionLabel);
}

class _PickTimeMeta extends StatelessWidget {
  const _PickTimeMeta({required this.pick});

  final GeneratedTicketPick pick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _pickTimeLabel(pick),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          _shortCompetitionLabel(pick.competitionName),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PickTeams extends StatelessWidget {
  const _PickTeams({
    required this.pick,
    required this.homeLogoUrl,
    required this.awayLogoUrl,
  });

  final GeneratedTicketPick pick;
  final String? homeLogoUrl;
  final String? awayLogoUrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PickTeamLine(name: pick.homeTeam, logoUrl: homeLogoUrl),
        const SizedBox(height: 3),
        _PickTeamLine(name: pick.awayTeam, logoUrl: awayLogoUrl),
      ],
    );
  }
}

class _PickTeamLine extends StatelessWidget {
  const _PickTeamLine({required this.name, required this.logoUrl});

  final String name;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SportsAssetBadge(
          size: 19,
          imageUrl: logoUrl,
          fallbackLabel: name,
          borderRadius: AppRadius.chip,
          padding: 1,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

String _pickTimeLabel(GeneratedTicketPick pick) {
  final kickoff = pick.kickoff?.toLocal();
  if (kickoff != null) {
    return '${kickoff.hour.toString().padLeft(2, '0')}:${kickoff.minute.toString().padLeft(2, '0')}';
  }
  return pick.kickoffLabel.trim().isEmpty ? '--:--' : pick.kickoffLabel;
}

String _shortCompetitionLabel(String competitionName) {
  final lower = competitionName.toLowerCase();
  if (lower.contains('premier')) {
    return 'PL';
  }
  if (lower.contains('liga')) {
    return 'LALIGA';
  }
  if (lower.contains('champions')) {
    return 'UCL';
  }
  if (lower.contains('bundes')) {
    return 'BUNDES';
  }
  if (lower.contains('ligue 1')) {
    return 'L1';
  }
  return competitionName.length <= 6
      ? competitionName.toUpperCase()
      : competitionName.substring(0, 3).toUpperCase();
}

String _marketLabelFor(String marketLabel) {
  final market = marketLabel.toLowerCase();
  if (market.contains('double chance')) {
    return 'Double chance';
  }
  if (market.contains('both') || market.contains('deux équipes')) {
    return 'BTTS';
  }
  if (market.contains('result') || market.contains('résultat')) {
    return 'Résultat';
  }
  if (market.contains('plus') ||
      market.contains('moins') ||
      market.contains('over') ||
      market.contains('under')) {
    return 'Total buts';
  }

  return marketLabel;
}

String _selectionLabelFor(String selectionLabel) {
  final selection = selectionLabel.toLowerCase();
  if (selection == 'home' || selection == 'domicile' || selection == '1') {
    return selectionLabel == '1' ? 'Domicile' : selectionLabel;
  }
  if (selection == 'away' || selection == 'extérieur' || selection == '2') {
    return selectionLabel == '2' ? 'Extérieur' : selectionLabel;
  }
  if (selection == 'draw' || selection == 'nul' || selection == 'n') {
    return selectionLabel == 'N' ? 'Nul' : selectionLabel;
  }

  return selectionLabel;
}

class _TicketReadingsFooter extends StatelessWidget {
  const _TicketReadingsFooter({
    required this.readingCount,
    required this.hasDetails,
    required this.accent,
    required this.isExpanded,
    required this.onToggleExpanded,
  });

  final int readingCount;
  final bool hasDetails;
  final Color accent;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final label = readingCount == 1
        ? '1 lecture convergente'
        : '$readingCount lectures convergentes';

    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: hasDetails ? onToggleExpanded : null,
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 22, color: accent),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (hasDetails) ...[
                const SizedBox(width: 4),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 22,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _KeyReadingsList extends StatelessWidget {
  const _KeyReadingsList({required this.readings});

  final List<String> readings;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final reading in readings) _KeyReadingChip(label: reading),
      ],
    );
  }
}

class _KeyReadingChip extends StatelessWidget {
  const _KeyReadingChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final badge = context.opportunities.badgeFor(
      _readingIdForLabel(label),
      variant: AppReadingBadgeVariant.soft,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: badge.background,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: badge.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              color: badge.iconColor,
              size: 15,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: badge.foreground,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _readingIdForLabel(String label) {
    final normalized = label.toLowerCase();
    if (normalized.contains('favori') ||
        normalized.contains('domination') ||
        normalized.contains('domicile')) {
      return 'solid_favorite';
    }
    if (normalized.contains('ouvert') ||
        normalized.contains('but') ||
        normalized.contains('btts')) {
      return 'open_match';
    }
    if (normalized.contains('fermé') || normalized.contains('under')) {
      return 'closed_match';
    }
    if (normalized.contains('écart') || normalized.contains('niveau')) {
      return 'level_gap';
    }
    if (normalized.contains('outsider')) {
      return 'credible_outsider';
    }
    if (normalized.contains('défense') || normalized.contains('fragile')) {
      return 'fragile_defense';
    }
    if (normalized.contains('attaque') || normalized.contains('xg')) {
      return 'prolific_attack';
    }
    if (normalized.contains('positive')) {
      return 'positive_streak';
    }
    if (normalized.contains('négative') ||
        normalized.contains('difficulté') ||
        normalized.contains('insuffisant')) {
      return 'negative_streak';
    }
    return 'prolific_attack';
  }
}

class _CreateManualTicketCta extends StatelessWidget {
  const _CreateManualTicketCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(
                Icons.auto_awesome_outlined,
                color: colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Créer un ticket personnalisé',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Choisissez vos matchs et marchés',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: onTap,
                style: OutlinedButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(12),
                  minimumSize: const Size.square(46),
                ),
                child: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HowItWorksLink extends StatelessWidget {
  const _HowItWorksLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.info_outline_rounded, size: 18),
      label: const Text('Comment Lector construit ces tickets'),
    );
  }
}

class _SavedTicketsList extends StatelessWidget {
  const _SavedTicketsList({
    required this.title,
    required this.tickets,
    this.strategies = const [],
    this.matches = const [],
    this.opportunities = const [],
    this.opportunityForMatchId,
    this.onSaveTicket,
  });

  final String title;
  final List<SavedTicket> tickets;
  final List<TicketStrategy> strategies;
  final List<MatchBoardItem> matches;
  final List<Opportunity> opportunities;
  final Opportunity? Function(String matchId)? opportunityForMatchId;
  final ValueChanged<SavedTicket>? onSaveTicket;

  @override
  Widget build(BuildContext context) {
    final orderedTickets = [...tickets]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        for (final ticket in orderedTickets)
          _SavedManualTicketCard(
            ticket: ticket,
            onEdit: _canEdit(ticket)
                ? () => _openSavedTicketEditor(context, ticket)
                : null,
          ),
      ],
    );
  }

  bool _canEdit(SavedTicket ticket) {
    return ticket.source == SavedTicketSource.copilotModified &&
        strategies.isNotEmpty &&
        opportunities.isNotEmpty &&
        opportunityForMatchId != null &&
        onSaveTicket != null;
  }

  Future<void> _openSavedTicketEditor(
    BuildContext context,
    SavedTicket savedTicket,
  ) async {
    final strategy = _strategyFor(savedTicket);
    final generatedTicket = _generatedTicketFromSaved(savedTicket);
    final updatedTicket = await showModalBottomSheet<SavedTicket>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ModifyGeneratedTicketSheet(
        ticket: generatedTicket,
        strategy: strategy,
        opportunityForMatchId: opportunityForMatchId!,
        matches: matches,
        opportunities: opportunities,
        existingTicket: savedTicket,
      ),
    );
    if (updatedTicket == null || !context.mounted) {
      return;
    }

    onSaveTicket!(
      savedTicket.copyWith(
        updatedAt: DateTime.now().toUtc(),
        totalOdds: updatedTicket.totalOdds,
        selections: updatedTicket.selections,
        opportunityIds: updatedTicket.opportunityIds,
        modificationSummary: updatedTicket.modificationSummary,
        modificationDetails: updatedTicket.modificationDetails,
      ),
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Ticket modifié mis à jour.')));
  }

  TicketStrategy _strategyFor(SavedTicket ticket) {
    for (final strategy in strategies) {
      if (strategy.id == ticket.strategyId) {
        return strategy;
      }
    }
    for (final strategy in strategies) {
      if (strategy.name == ticket.strategyName) {
        return strategy;
      }
    }
    return strategies.first;
  }

  GeneratedTicket _generatedTicketFromSaved(SavedTicket ticket) {
    final picks = [
      for (final selection in ticket.selections)
        _generatedPickFromSavedSelection(selection),
    ];

    return GeneratedTicket(
      id: ticket.id,
      strategyId: ticket.strategyId ?? '',
      strategyName: ticket.strategyName ?? 'Stratégie',
      picks: picks,
      totalOdds: ticket.totalOdds,
      selectionCount: picks.length,
      generatedAt: ticket.createdAt,
      variantIndex: 0,
      origin: TicketOrigin.copilotEdited,
    );
  }

  GeneratedTicketPick _generatedPickFromSavedSelection(
    SavedTicketSelection selection,
  ) {
    final opportunity = opportunityForMatchId?.call(selection.matchId);
    return GeneratedTicketPick(
      opportunityId: selection.opportunityId ?? selection.matchId,
      matchId: selection.matchId,
      homeTeam: selection.homeTeam,
      awayTeam: selection.awayTeam,
      competitionName: selection.competitionName,
      kickoffLabel: opportunity?.fixture.kickoffLabel ?? '',
      kickoff: opportunity?.fixture.kickoff,
      marketId: selection.marketId,
      marketLabel: selection.marketLabel,
      selectionId: selection.selectionId,
      selectionLabel: selection.selectionLabel,
      odds: selection.odds,
      pickType: pickTypeForOdds(selection.odds) ?? PickType.prudent,
      thesisId: opportunity?.primaryThesis.id ?? 'saved_modified_ticket',
      opportunityProfileIds: opportunity?.opportunityProfileIds ?? const [],
      engineScore: opportunity?.engineScore ?? 0,
    );
  }
}

class _SavedManualTicketCard extends StatelessWidget {
  const _SavedManualTicketCard({required this.ticket, this.onEdit});

  final SavedTicket ticket;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final semantic = context.semantic;
    final statusLabel = ticket.status == SavedTicketStatus.played
        ? 'Déclaré joué'
        : 'Enregistré';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.shopping_bag_outlined, color: colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      ticket.name ?? 'Ticket manuel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _SavedStatusPill(
                    label: statusLabel,
                    color: ticket.status == SavedTicketStatus.played
                        ? semantic.success
                        : colorScheme.primary,
                  ),
                  if (onEdit != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Modifier le ticket',
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _TinyMeta(
                    icon: Icons.format_list_numbered_rounded,
                    label:
                        '${ticket.selectionCount} sélection${ticket.selectionCount > 1 ? 's' : ''}',
                    color: colorScheme.primary,
                  ),
                  _TinyMeta(
                    icon: Icons.stacked_line_chart_rounded,
                    label: 'Cote totale ${ticket.totalOdds.toStringAsFixed(2)}',
                    color: colorScheme.primary,
                  ),
                  _TinyMeta(
                    icon: Icons.verified_outlined,
                    label: statusLabel,
                    color: ticket.status == SavedTicketStatus.played
                        ? semantic.success
                        : colorScheme.primary,
                  ),
                  if (ticket.strategyName != null)
                    _TinyMeta(
                      icon: Icons.rule_rounded,
                      label: ticket.strategyName!,
                      color: colorScheme.primary,
                    ),
                ],
              ),
              if (ticket.selections.isNotEmpty) ...[
                const SizedBox(height: 10),
                Column(
                  children: [
                    for (final entry in ticket.selections.indexed) ...[
                      _SavedTicketSelectionRow(selection: entry.$2),
                      if (entry.$1 != ticket.selections.length - 1)
                        Divider(height: 1, color: colorScheme.outlineVariant),
                    ],
                  ],
                ),
              ],
              if (ticket.modificationSummary != null) ...[
                const SizedBox(height: 12),
                _ModificationTrace(
                  summary: ticket.modificationSummary!,
                  details: ticket.modificationDetails,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedTicketSelectionRow extends StatelessWidget {
  const _SavedTicketSelectionRow({required this.selection});

  final SavedTicketSelection selection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              _shortCompetitionLabel(selection.competitionName),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              children: [
                _SavedSelectionTeamLine(
                  name: selection.homeTeam,
                  logoUrl: selection.homeLogoUrl,
                ),
                const SizedBox(height: 3),
                _SavedSelectionTeamLine(
                  name: selection.awayTeam,
                  logoUrl: selection.awayLogoUrl,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 72,
            child: Align(
              alignment: Alignment.centerRight,
              child: _MarketBadge(
                label: _marketLabelFor(selection.marketLabel),
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 54,
            child: Text(
              _selectionLabelFor(selection.selectionLabel),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 42,
            child: Text(
              selection.odds.toStringAsFixed(2),
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedSelectionTeamLine extends StatelessWidget {
  const _SavedSelectionTeamLine({required this.name, required this.logoUrl});

  final String name;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SportsAssetBadge(
          size: 18,
          imageUrl: logoUrl,
          fallbackLabel: name,
          borderRadius: AppRadius.chip,
          padding: 1,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _ModificationTrace extends StatelessWidget {
  const _ModificationTrace({required this.summary, required this.details});

  final String summary;
  final List<String> details;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final semantic = context.semantic;
    final warning = semantic.warning;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: warning.withValues(alpha: 0.32)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.edit_outlined, size: 16, color: warning),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    summary,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: warning,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final detail in details.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    detail,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SavedStatusPill extends StatelessWidget {
  const _SavedStatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: color),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _EmptyTicketTab extends StatelessWidget {
  const _EmptyTicketTab({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return _EmptyState(icon: icon, title: title, message: message);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colorScheme.primary, size: 34),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: onAction,
                      child: Text(actionLabel!),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
