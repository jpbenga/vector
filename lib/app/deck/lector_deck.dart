import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_components.dart';
import '../../core/theme/app_radius.dart';
import '../../core/widgets/lector_brand_mark.dart';

enum LectorDeckScope { forMe, all, generator, matchDetail }

enum LectorDeckActionType { navigation, action }

enum LectorDeckTicketState {
  unavailable,
  canAdd,
  selected,
  blockedByAnotherSelection,
}

@immutable
class LectorDeckContext {
  const LectorDeckContext({
    required this.scope,
    this.selectedDate,
    this.today,
    this.hasGeneratorResults = false,
    this.hasSavedTickets = false,
    this.hasActiveStrategies = false,
    this.ticketState = LectorDeckTicketState.unavailable,
  });

  final LectorDeckScope scope;
  final DateTime? selectedDate;
  final DateTime? today;
  final bool hasGeneratorResults;
  final bool hasSavedTickets;
  final bool hasActiveStrategies;
  final LectorDeckTicketState ticketState;

  bool get isTodaySelected {
    final selected = selectedDate;
    if (selected == null) {
      return true;
    }
    final reference = today ?? DateTime.now();
    return selected.year == reference.year &&
        selected.month == reference.month &&
        selected.day == reference.day;
  }

  Object get signature {
    return Object.hash(
      scope,
      selectedDate == null
          ? null
          : DateTime(
              selectedDate!.year,
              selectedDate!.month,
              selectedDate!.day,
            ),
      hasGeneratorResults,
      hasSavedTickets,
      hasActiveStrategies,
      ticketState,
    );
  }
}

@immutable
class LectorDeckCapabilities {
  const LectorDeckCapabilities({
    this.onOpenForMe,
    this.onOpenAll,
    this.onOpenGenerator,
    this.onGoToday,
    this.onOpenStrategies,
    this.onRecalculate,
    this.onOpenTicketHistory,
    this.onAddToTicket,
    this.onRemoveFromTicket,
    this.onOpenCurrentTicket,
    this.onOpenReadings,
  });

  final VoidCallback? onOpenForMe;
  final VoidCallback? onOpenAll;
  final VoidCallback? onOpenGenerator;
  final VoidCallback? onGoToday;
  final VoidCallback? onOpenStrategies;
  final VoidCallback? onRecalculate;
  final VoidCallback? onOpenTicketHistory;
  final VoidCallback? onAddToTicket;
  final VoidCallback? onRemoveFromTicket;
  final VoidCallback? onOpenCurrentTicket;
  final VoidCallback? onOpenReadings;
}

@immutable
class LectorDeckAction {
  const LectorDeckAction({
    required this.id,
    required this.icon,
    required this.label,
    required this.type,
    required this.onPressed,
    this.isPrimary = false,
  });

  final String id;
  final IconData icon;
  final String label;
  final LectorDeckActionType type;
  final VoidCallback onPressed;
  final bool isPrimary;
}

class LectorDeckActionResolver {
  const LectorDeckActionResolver();

  List<LectorDeckAction> resolve({
    required LectorDeckContext context,
    required LectorDeckCapabilities capabilities,
  }) {
    return switch (context.scope) {
      LectorDeckScope.forMe => _forMe(capabilities),
      LectorDeckScope.all => _all(context, capabilities),
      LectorDeckScope.generator => _generator(context, capabilities),
      LectorDeckScope.matchDetail => _matchDetail(context, capabilities),
    };
  }

  List<LectorDeckAction> _forMe(LectorDeckCapabilities capabilities) {
    return [
      if (capabilities.onOpenAll != null)
        _action(
          id: 'all',
          icon: Icons.format_list_bulleted_rounded,
          label: 'Tous',
          type: LectorDeckActionType.navigation,
          onPressed: capabilities.onOpenAll!,
        ),
      if (capabilities.onOpenGenerator != null)
        _action(
          id: 'generator',
          icon: Icons.auto_awesome_rounded,
          label: 'Générateur',
          type: LectorDeckActionType.navigation,
          onPressed: capabilities.onOpenGenerator!,
        ),
    ];
  }

  List<LectorDeckAction> _all(
    LectorDeckContext context,
    LectorDeckCapabilities capabilities,
  ) {
    return [
      if (capabilities.onOpenForMe != null)
        _action(
          id: 'for-me',
          icon: Icons.person_outline_rounded,
          label: 'Pour moi',
          type: LectorDeckActionType.navigation,
          onPressed: capabilities.onOpenForMe!,
          isPrimary: true,
        ),
      if (!context.isTodaySelected && capabilities.onGoToday != null)
        _action(
          id: 'today',
          icon: Icons.today_rounded,
          label: 'Aujourd’hui',
          type: LectorDeckActionType.action,
          onPressed: capabilities.onGoToday!,
        ),
      if (capabilities.onOpenGenerator != null)
        _action(
          id: 'generator',
          icon: Icons.auto_awesome_rounded,
          label: 'Générateur',
          type: LectorDeckActionType.navigation,
          onPressed: capabilities.onOpenGenerator!,
        ),
    ];
  }

  List<LectorDeckAction> _generator(
    LectorDeckContext context,
    LectorDeckCapabilities capabilities,
  ) {
    if (context.hasGeneratorResults) {
      return [
        if (context.hasSavedTickets && capabilities.onOpenTicketHistory != null)
          _action(
            id: 'ticket-history',
            icon: Icons.history_rounded,
            label: 'Historique',
            type: LectorDeckActionType.navigation,
            onPressed: capabilities.onOpenTicketHistory!,
            isPrimary: true,
          ),
        if (capabilities.onRecalculate != null)
          _action(
            id: 'recalculate',
            icon: Icons.refresh_rounded,
            label: 'Recalculer',
            type: LectorDeckActionType.action,
            onPressed: capabilities.onRecalculate!,
            isPrimary: !context.hasSavedTickets,
          ),
        if (capabilities.onOpenStrategies != null)
          _action(
            id: 'strategies',
            icon: Icons.tune_rounded,
            label: 'Stratégies',
            type: LectorDeckActionType.navigation,
            onPressed: capabilities.onOpenStrategies!,
          ),
      ];
    }

    return [
      if (!context.hasActiveStrategies && capabilities.onOpenStrategies != null)
        _action(
          id: 'strategies',
          icon: Icons.tune_rounded,
          label: 'Stratégies',
          type: LectorDeckActionType.navigation,
          onPressed: capabilities.onOpenStrategies!,
          isPrimary: true,
        ),
      if (capabilities.onRecalculate != null)
        _action(
          id: 'recalculate',
          icon: Icons.refresh_rounded,
          label: 'Recalculer',
          type: LectorDeckActionType.action,
          onPressed: capabilities.onRecalculate!,
          isPrimary: context.hasActiveStrategies,
        ),
      if (context.hasActiveStrategies && capabilities.onOpenStrategies != null)
        _action(
          id: 'strategies',
          icon: Icons.tune_rounded,
          label: 'Stratégies',
          type: LectorDeckActionType.navigation,
          onPressed: capabilities.onOpenStrategies!,
        ),
      if (capabilities.onOpenAll != null)
        _action(
          id: 'all',
          icon: Icons.format_list_bulleted_rounded,
          label: 'Tous',
          type: LectorDeckActionType.navigation,
          onPressed: capabilities.onOpenAll!,
        ),
    ];
  }

  List<LectorDeckAction> _matchDetail(
    LectorDeckContext context,
    LectorDeckCapabilities capabilities,
  ) {
    return switch (context.ticketState) {
      LectorDeckTicketState.canAdd => [
        if (capabilities.onAddToTicket != null)
          _action(
            id: 'add-to-ticket',
            icon: Icons.add_rounded,
            label: 'Ajouter au ticket',
            type: LectorDeckActionType.action,
            onPressed: capabilities.onAddToTicket!,
            isPrimary: true,
          ),
        ..._matchDetailSecondary(capabilities, includeGenerator: true),
      ],
      LectorDeckTicketState.selected => [
        if (capabilities.onOpenCurrentTicket != null)
          _action(
            id: 'current-ticket',
            icon: Icons.confirmation_number_outlined,
            label: 'Voir mon ticket',
            type: LectorDeckActionType.action,
            onPressed: capabilities.onOpenCurrentTicket!,
            isPrimary: true,
          ),
        if (capabilities.onOpenReadings != null) _readings(capabilities),
        if (capabilities.onRemoveFromTicket != null)
          _action(
            id: 'remove-from-ticket',
            icon: Icons.close_rounded,
            label: 'Retirer',
            type: LectorDeckActionType.action,
            onPressed: capabilities.onRemoveFromTicket!,
          ),
      ],
      LectorDeckTicketState.blockedByAnotherSelection => [
        if (capabilities.onOpenCurrentTicket != null)
          _action(
            id: 'current-ticket',
            icon: Icons.confirmation_number_outlined,
            label: 'Voir mon ticket',
            type: LectorDeckActionType.action,
            onPressed: capabilities.onOpenCurrentTicket!,
            isPrimary: true,
          ),
        ..._matchDetailSecondary(capabilities, includeGenerator: true),
      ],
      LectorDeckTicketState.unavailable => [
        ..._matchDetailSecondary(capabilities, includeGenerator: true),
      ],
    };
  }

  List<LectorDeckAction> _matchDetailSecondary(
    LectorDeckCapabilities capabilities, {
    required bool includeGenerator,
  }) {
    return [
      if (capabilities.onOpenReadings != null) _readings(capabilities),
      if (includeGenerator && capabilities.onOpenGenerator != null)
        _action(
          id: 'generator',
          icon: Icons.auto_awesome_rounded,
          label: 'Générateur',
          type: LectorDeckActionType.navigation,
          onPressed: capabilities.onOpenGenerator!,
        ),
    ];
  }

  LectorDeckAction _readings(LectorDeckCapabilities capabilities) {
    return _action(
      id: 'readings',
      icon: Icons.article_outlined,
      label: 'Lectures',
      type: LectorDeckActionType.navigation,
      onPressed: capabilities.onOpenReadings!,
    );
  }

  LectorDeckAction _action({
    required String id,
    required IconData icon,
    required String label,
    required LectorDeckActionType type,
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    return LectorDeckAction(
      id: id,
      icon: icon,
      label: label,
      type: type,
      onPressed: onPressed,
      isPrimary: isPrimary,
    );
  }
}

class LectorDeck extends StatefulWidget {
  const LectorDeck({
    required this.deckContext,
    required this.capabilities,
    this.maxWidth = double.infinity,
    this.resolver = const LectorDeckActionResolver(),
    super.key,
  });

  final LectorDeckContext deckContext;
  final LectorDeckCapabilities capabilities;
  final double maxWidth;
  final LectorDeckActionResolver resolver;

  @override
  State<LectorDeck> createState() => _LectorDeckState();
}

class _LectorDeckState extends State<LectorDeck> {
  static const _height = 48.0;
  static const _closedWidth = 52.0;
  static const _logoSlotWidth = 49.0;
  static const _dividerWidth = 1.0;
  static const _actionTargetWidth = 42.0;
  static const _primaryActionTargetWidth = 46.0;
  static const _actionsRightPadding = 4.0;

  bool _isOpen = false;

  @override
  void didUpdateWidget(covariant LectorDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deckContext.signature != widget.deckContext.signature &&
        _isOpen) {
      _isOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final actions = widget.resolver.resolve(
      context: widget.deckContext,
      capabilities: widget.capabilities,
    );
    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    final openedWidth =
        (_logoSlotWidth +
                _dividerWidth +
                _actionsRightPadding +
                actions.fold<double>(
                  0,
                  (sum, action) =>
                      sum +
                      (action.isPrimary
                          ? _primaryActionTargetWidth
                          : _actionTargetWidth),
                ))
            .clamp(_closedWidth, widget.maxWidth)
            .toDouble();
    final width = _isOpen ? openedWidth : _closedWidth;
    final borderColor = _isOpen
        ? context.brand.accent.withValues(alpha: 0.62)
        : context.surfaces.border;

    return TapRegion(
      onTapOutside: (_) {
        if (_isOpen && mounted) {
          setState(() {
            _isOpen = false;
          });
        }
      },
      child: AnimatedContainer(
        key: const ValueKey('lector-floating-dock'),
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        width: width,
        height: _height,
        decoration: BoxDecoration(
          color: context.surfaces.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: context.surfaces.shadow.withValues(alpha: 0.34),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
            if (_isOpen)
              BoxShadow(
                color: context.brand.accent.withValues(alpha: 0.18),
                blurRadius: 22,
              ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: AppColors.transparent,
          child: Row(
            children: [
              _DeckLogoButton(
                isOpen: _isOpen,
                onPressed: () {
                  setState(() {
                    _isOpen = !_isOpen;
                  });
                },
              ),
              if (_isOpen) ...[
                SizedBox(
                  width: _dividerWidth,
                  height: 26,
                  child: ColoredBox(color: context.surfaces.border),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final leadingPadding =
                          constraints.maxWidth < _actionsRightPadding
                          ? constraints.maxWidth
                          : _actionsRightPadding;
                      final availableWidth =
                          constraints.maxWidth - leadingPadding;
                      final totalTargetWidth = actions.fold<double>(
                        0,
                        (sum, action) =>
                            sum +
                            (action.isPrimary
                                ? _primaryActionTargetWidth
                                : _actionTargetWidth),
                      );
                      final ratio = totalTargetWidth <= 0
                          ? 0.0
                          : (availableWidth / totalTargetWidth)
                                .clamp(0.0, 1.0)
                                .toDouble();

                      return TweenAnimationBuilder<double>(
                        tween: Tween<double>(end: 1),
                        duration: const Duration(milliseconds: 210),
                        curve: Curves.easeOutCubic,
                        builder: (context, progress, _) {
                          return Row(
                            children: [
                              SizedBox(width: leadingPadding),
                              for (
                                var index = 0;
                                index < actions.length;
                                index++
                              )
                                _DeckActionButton(
                                  action: actions[index],
                                  width:
                                      (actions[index].isPrimary
                                          ? _primaryActionTargetWidth
                                          : _actionTargetWidth) *
                                      ratio,
                                  progress: _staggeredProgress(
                                    progress,
                                    index,
                                    actions.length,
                                  ),
                                  onPressed: () {
                                    actions[index].onPressed();
                                    if (mounted) {
                                      setState(() {
                                        _isOpen = false;
                                      });
                                    }
                                  },
                                ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  double _staggeredProgress(double progress, int index, int count) {
    final delay = index * 0.08;
    final available = 1 - (count - 1) * 0.08;
    return ((progress - delay) / available).clamp(0.0, 1.0).toDouble();
  }
}

class _DeckLogoButton extends StatelessWidget {
  const _DeckLogoButton({required this.isOpen, required this.onPressed});

  final bool isOpen;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final borderColor = isOpen
        ? context.brand.accent.withValues(alpha: 0.50)
        : context.surfaces.border;
    return Tooltip(
      message: isOpen ? 'Replier le Deck' : 'Ouvrir le Deck',
      child: InkWell(
        key: const ValueKey('lector-floating-dock-logo'),
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        child: SizedBox(
          width: _LectorDeckState._logoSlotWidth,
          height: _LectorDeckState._height,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: context.surfaces.backgroundSecondary.withValues(
                  alpha: 0.78,
                ),
                shape: BoxShape.circle,
                border: Border.all(color: borderColor),
                boxShadow: [
                  if (isOpen)
                    BoxShadow(
                      color: context.brand.accent.withValues(alpha: 0.18),
                      blurRadius: 14,
                    ),
                ],
              ),
              child: const Center(child: LectorBrandMark(size: 24)),
            ),
          ),
        ),
      ),
    );
  }
}

class _DeckActionButton extends StatelessWidget {
  const _DeckActionButton({
    required this.action,
    required this.width,
    required this.progress,
    required this.onPressed,
  });

  final LectorDeckAction action;
  final double width;
  final double progress;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = action.isPrimary
        ? context.brand.accent
        : context.textColors.secondary;
    return Opacity(
      opacity: progress,
      child: Transform.translate(
        offset: Offset((1 - progress) * -3, 0),
        child: Transform.scale(
          scale: 0.92 + progress * 0.08,
          child: Tooltip(
            message: action.label,
            child: InkWell(
              key: ValueKey('lector-floating-dock-${action.label}'),
              onTap: onPressed,
              borderRadius: BorderRadius.circular(AppRadius.chip),
              child: SizedBox(
                width: width,
                height: _LectorDeckState._height,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: action.isPrimary ? 32 : 30,
                    height: action.isPrimary ? 32 : 30,
                    decoration: BoxDecoration(
                      color: action.isPrimary
                          ? context.brand.accent.withValues(alpha: 0.12)
                          : AppColors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(action.icon, size: 20, color: color),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
