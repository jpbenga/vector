import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_components.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../matches/presentation/widgets/sports_asset_badge.dart';
import '../domain/saved_ticket.dart';
import '../domain/ticket_draft.dart';
import '../domain/ticket_strategy.dart';

class TicketBuilderPanel extends StatefulWidget {
  const TicketBuilderPanel({
    required this.ticket,
    required this.strategies,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.onRemoveSelection,
    required this.onTicketSaved,
    required this.onViewSavedTickets,
    this.onOpenSelection,
    super.key,
  });

  final TicketDraft ticket;
  final List<TicketStrategy> strategies;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final ValueChanged<String> onRemoveSelection;
  final ValueChanged<SavedTicket> onTicketSaved;
  final VoidCallback onViewSavedTickets;
  final ValueChanged<TicketDraftSelection>? onOpenSelection;

  @override
  State<TicketBuilderPanel> createState() => _TicketBuilderPanelState();
}

class _TicketBuilderPanelState extends State<TicketBuilderPanel>
    with TickerProviderStateMixin {
  bool _showAllSelections = false;

  @override
  void didUpdateWidget(TicketBuilderPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isExpanded || widget.ticket.selectionCount <= 3) {
      _showAllSelections = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ticket.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final maxPanelHeight = MediaQuery.sizeOf(context).height * 0.50;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomCenter,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer.withValues(alpha: 0.98),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.card),
          ),
          border: Border(
            top: BorderSide(color: colorScheme.outlineVariant),
            left: BorderSide(color: colorScheme.outlineVariant),
            right: BorderSide(color: colorScheme.outlineVariant),
          ),
          boxShadow: AppShadows.bottomPanel,
        ),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxPanelHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TicketPanelHeader(
                  ticket: widget.ticket,
                  isExpanded: widget.isExpanded,
                  onToggleExpanded: widget.onToggleExpanded,
                  onPrimaryAction: widget.isExpanded
                      ? _openValidationSheet
                      : widget.onToggleExpanded,
                ),
                if (widget.isExpanded) ...[
                  Divider(height: 1, color: colorScheme.outlineVariant),
                  Flexible(child: _selectionList(context)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openValidationSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _TicketValidationSheet(
          ticket: widget.ticket,
          strategies: widget.strategies,
          onTicketSaved: widget.onTicketSaved,
          onViewSavedTickets: widget.onViewSavedTickets,
        );
      },
    );
  }

  Widget _selectionList(BuildContext context) {
    final ticket = widget.ticket;
    final visibleSelections = _showAllSelections
        ? ticket.selections
        : ticket.selections.take(3).toList();
    final remainingCount = ticket.selectionCount - visibleSelections.length;

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      children: [
        for (final selection in visibleSelections)
          _TicketSelectionRow(
            selection: selection,
            onRemove: () => widget.onRemoveSelection(selection.id),
            onOpen: widget.onOpenSelection == null
                ? null
                : () => widget.onOpenSelection!(selection),
          ),
        if (remainingCount > 0) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _showAllSelections = true;
                });
              },
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              label: Text(
                'Voir $remainingCount sélection${remainingCount > 1 ? 's' : ''} supplémentaire${remainingCount > 1 ? 's' : ''}',
              ),
            ),
          ),
        ] else if (_showAllSelections && ticket.selectionCount > 3) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _showAllSelections = false;
                });
              },
              icon: const Icon(Icons.keyboard_arrow_up_rounded),
              label: const Text('Réduire'),
            ),
          ),
        ],
      ],
    );
  }
}

class _TicketPanelHeader extends StatelessWidget {
  const _TicketPanelHeader({
    required this.ticket,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.onPrimaryAction,
  });

  final TicketDraft ticket;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onToggleExpanded,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
          child: Row(
            children: [
              Icon(
                isExpanded
                    ? Icons.keyboard_arrow_down_rounded
                    : Icons.keyboard_arrow_up_rounded,
                color: colorScheme.onSurface,
              ),
              const SizedBox(width: 8),
              const Icon(Icons.shopping_bag_outlined, size: 20),
              const SizedBox(width: 8),
              Text(
                'Mon ticket',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              _SelectionCountPill(count: ticket.selectionCount),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Cote totale',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ticket.totalOdds.toStringAsFixed(2),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              FilledButton(
                onPressed: onPrimaryAction,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(isExpanded ? 'Valider le ticket' : 'Voir le ticket'),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right_rounded, size: 18),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TicketValidationSheet extends StatefulWidget {
  const _TicketValidationSheet({
    required this.ticket,
    required this.strategies,
    required this.onTicketSaved,
    required this.onViewSavedTickets,
  });

  final TicketDraft ticket;
  final List<TicketStrategy> strategies;
  final ValueChanged<SavedTicket> onTicketSaved;
  final VoidCallback onViewSavedTickets;

  @override
  State<_TicketValidationSheet> createState() => _TicketValidationSheetState();
}

class _TicketValidationSheetState extends State<_TicketValidationSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _plannedStakeController = TextEditingController();
  final TextEditingController _bookmakerController = TextEditingController();
  final TextEditingController _realStakeController = TextEditingController();
  final TextEditingController _actualOddsController = TextEditingController();
  String? _strategyId;
  SavedTicket? _savedTicket;
  bool _showPlayedForm = false;

  @override
  void dispose() {
    _nameController.dispose();
    _plannedStakeController.dispose();
    _bookmakerController.dispose();
    _realStakeController.dispose();
    _actualOddsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final savedTicket = _savedTicket;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomInset),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 720),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: savedTicket == null
                ? _buildValidationForm(context)
                : _showPlayedForm
                ? _buildPlayedForm(context, savedTicket)
                : _buildSavedState(context, savedTicket),
          ),
        ),
      ),
    );
  }

  Widget _buildValidationForm(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final activeStrategies = widget.strategies
        .where((strategy) => strategy.isActive)
        .toList();
    final selectedStrategy = _selectedStrategy(activeStrategies);

    return ListView(
      shrinkWrap: true,
      children: [
        _SheetHeader(
          title: 'Valider le ticket',
          onClose: () => Navigator.of(context).pop(),
        ),
        const SizedBox(height: 18),
        _TicketSummaryBox(ticket: widget.ticket),
        const SizedBox(height: 18),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Nom du ticket (optionnel)',
            hintText: 'Ex : Mon combiné du soir',
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _strategyId,
          decoration: const InputDecoration(
            labelText: 'Stratégie utilisée (optionnel)',
          ),
          items: [
            const DropdownMenuItem(value: '', child: Text('Aucune stratégie')),
            for (final strategy in activeStrategies)
              DropdownMenuItem(value: strategy.id, child: Text(strategy.name)),
          ],
          onChanged: (value) {
            setState(() {
              _strategyId = value == null || value.isEmpty ? null : value;
            });
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _plannedStakeController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Mise envisagée (optionnel)',
            suffixText: 'EUR',
          ),
        ),
        if (selectedStrategy != null) ...[
          const SizedBox(height: 12),
          Text(
            'Associé à ${selectedStrategy.name}.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _saveTicket,
          child: const Text('Enregistrer le ticket'),
        ),
      ],
    );
  }

  Widget _buildSavedState(BuildContext context, SavedTicket ticket) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final semantic = context.semantic;

    return ListView(
      shrinkWrap: true,
      children: [
        const SizedBox(height: 12),
        Icon(
          Icons.check_circle_outline_rounded,
          color: semantic.success,
          size: 72,
        ),
        const SizedBox(height: 14),
        Text(
          'Ticket enregistré !',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Votre ticket a été enregistré dans votre liste.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () {
            widget.onViewSavedTickets();
            Navigator.of(context).pop();
          },
          child: const Text('Voir mes tickets'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Continuer à parier'),
        ),
        const SizedBox(height: 18),
        _ReadyToPlayCard(
          ticket: ticket,
          onDeclarePlayed: () {
            setState(() {
              _showPlayedForm = true;
            });
          },
          onLater: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildPlayedForm(BuildContext context, SavedTicket ticket) {
    return ListView(
      shrinkWrap: true,
      children: [
        _SheetHeader(
          title: 'J’ai joué ce ticket',
          onClose: () => Navigator.of(context).pop(),
        ),
        const SizedBox(height: 10),
        const _ImportantRulesCard(
          lines: [
            'Déclarez uniquement un ticket réellement placé.',
            'La cote réelle peut différer de la cote repérée dans Vector.',
            'Aucun résultat financier n’est calculé ici.',
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _bookmakerController,
          decoration: const InputDecoration(
            labelText: 'Bookmaker',
            hintText: 'Sélectionnez votre bookmaker',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _realStakeController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Mise réelle',
            suffixText: 'EUR',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _actualOddsController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Cote réelle obtenue (optionnel)',
          ),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: () => _markPlayed(ticket),
          child: const Text('Enregistrer comme joué'),
        ),
      ],
    );
  }

  TicketStrategy? _selectedStrategy(List<TicketStrategy> strategies) {
    final strategyId = _strategyId;
    if (strategyId == null) {
      return null;
    }

    for (final strategy in strategies) {
      if (strategy.id == strategyId) {
        return strategy;
      }
    }

    return null;
  }

  void _saveTicket() {
    final activeStrategies = widget.strategies
        .where((strategy) => strategy.isActive)
        .toList();
    final selectedStrategy = _selectedStrategy(activeStrategies);
    final savedTicket = SavedTicket.fromDraft(
      draft: widget.ticket,
      name: _nameController.text,
      createdAt: DateTime.now().toUtc(),
      strategyId: selectedStrategy?.id,
      strategyName: selectedStrategy?.name,
      plannedStake: _doubleFromText(_plannedStakeController.text),
    );

    widget.onTicketSaved(savedTicket);
    setState(() {
      _savedTicket = savedTicket;
    });
  }

  void _markPlayed(SavedTicket ticket) {
    final updated = ticket.copyWith(
      status: SavedTicketStatus.played,
      updatedAt: DateTime.now().toUtc(),
      playedDeclaration: SavedTicketPlayDeclaration(
        bookmaker: _bookmakerController.text.trim(),
        stake: _doubleFromText(_realStakeController.text),
        actualTotalOdds: _doubleFromText(_actualOddsController.text),
        playedAt: DateTime.now().toUtc(),
      ),
    );

    widget.onTicketSaved(updated);
    setState(() {
      _savedTicket = updated;
      _showPlayedForm = false;
    });
  }

  double? _doubleFromText(String value) {
    final normalized = value.trim().replaceAll(',', '.');
    if (normalized.isEmpty) {
      return null;
    }

    return double.tryParse(normalized);
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
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

class _TicketSummaryBox extends StatelessWidget {
  const _TicketSummaryBox({required this.ticket});

  final TicketDraft ticket;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Récapitulatif',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${ticket.selectionCount} sélection${ticket.selectionCount > 1 ? 's' : ''}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Cote totale',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ticket.totalOdds.toStringAsFixed(2),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedTicketSummaryBox extends StatelessWidget {
  const _SavedTicketSummaryBox({required this.ticket});

  final SavedTicket ticket;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Récapitulatif',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${ticket.selectionCount} sélection${ticket.selectionCount > 1 ? 's' : ''}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Cote totale',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ticket.totalOdds.toStringAsFixed(2),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadyToPlayCard extends StatelessWidget {
  const _ReadyToPlayCard({
    required this.ticket,
    required this.onDeclarePlayed,
    required this.onLater,
  });

  final SavedTicket ticket;
  final VoidCallback onDeclarePlayed;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colorScheme.primary),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              Icons.event_available_rounded,
              color: colorScheme.primary,
              size: 34,
            ),
            const SizedBox(height: 10),
            Text(
              ticket.status == SavedTicketStatus.played
                  ? 'Ticket déclaré joué'
                  : 'Prêt à être joué !',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              ticket.status == SavedTicketStatus.played
                  ? 'Votre déclaration a été enregistrée.'
                  : 'N’oubliez pas de le déclarer comme joué lorsque vous l’aurez placé.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            _SavedTicketSummaryBox(ticket: ticket),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: ticket.status == SavedTicketStatus.played
                  ? null
                  : onDeclarePlayed,
              child: const Text('J’ai joué ce ticket'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: onLater, child: const Text('Plus tard')),
          ],
        ),
      ),
    );
  }
}

class _ImportantRulesCard extends StatelessWidget {
  const _ImportantRulesCard({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '• $line',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SelectionCountPill extends StatelessWidget {
  const _SelectionCountPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          '$count',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _TicketSelectionRow extends StatelessWidget {
  const _TicketSelectionRow({
    required this.selection,
    required this.onRemove,
    this.onOpen,
  });

  final TicketDraftSelection selection;
  final VoidCallback onRemove;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final semantic = context.semantic;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Retirer la sélection',
                  onPressed: onRemove,
                  icon: const Icon(Icons.close_rounded),
                  color: semantic.error,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 4),
                _TeamLogoPair(selection: selection),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selection.matchLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        selection.marketSelectionLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  selection.odds.toStringAsFixed(2),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: context.components.oddsText,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (onOpen != null) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TeamLogoPair extends StatelessWidget {
  const _TeamLogoPair({required this.selection});

  final TicketDraftSelection selection;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      child: Stack(
        children: [
          SportsAssetBadge(
            size: 30,
            imageUrl: selection.homeLogoUrl,
            fallbackLabel: selection.homeTeam,
            borderRadius: 6,
          ),
          Positioned(
            left: 24,
            child: SportsAssetBadge(
              size: 30,
              imageUrl: selection.awayLogoUrl,
              fallbackLabel: selection.awayTeam,
              borderRadius: 6,
            ),
          ),
        ],
      ),
    );
  }
}
