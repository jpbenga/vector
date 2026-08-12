import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_components.dart';
import '../../../core/theme/app_radius.dart';
import '../../matches/presentation/widgets/sports_asset_badge.dart';
import '../domain/saved_ticket.dart';

enum TicketHistorySource { all, copilot, edited, manual }

enum TicketHistoryPeriod { today, sevenDays, thirtyDays, all }

enum TicketHistoryResult { won, lost, pending, notPlayed, cancelled }

enum TicketHistoryStatusFilter { all, notPlayed, pending, won, lost, cancelled }

class TicketHistoryPage extends StatefulWidget {
  const TicketHistoryPage({
    required this.savedTickets,
    required this.onClose,
    required this.onTicketChanged,
    required this.onTicketDeleted,
    super.key,
  });

  final List<SavedTicket> savedTickets;
  final VoidCallback onClose;
  final ValueChanged<SavedTicket> onTicketChanged;
  final ValueChanged<String> onTicketDeleted;

  @override
  State<TicketHistoryPage> createState() => _TicketHistoryPageState();
}

class _TicketHistoryPageState extends State<TicketHistoryPage> {
  TicketHistoryPeriod _period = TicketHistoryPeriod.sevenDays;
  TicketHistorySource _source = TicketHistorySource.all;
  TicketHistoryStatusFilter _status = TicketHistoryStatusFilter.all;
  late List<SavedTicket> _tickets = [...widget.savedTickets];

  @override
  void didUpdateWidget(TicketHistoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.savedTickets != widget.savedTickets) {
      _tickets = [...widget.savedTickets];
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = _filteredEntries();
    final metrics = _HistoryMetrics.from(entries);

    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return Material(
      type: MaterialType.transparency,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            _HistoryHeader(
              selectedPeriod: _period,
              onPeriodChanged: (period) => setState(() => _period = period),
              onClose: widget.onClose,
            ),
            const SizedBox(height: 14),
            _KpiStrip(metrics: metrics),
            const SizedBox(height: 14),
            _HistoryFilters(
              selectedSource: _source,
              onChanged: (source) => setState(() => _source = source),
            ),
            const SizedBox(height: 10),
            _HistoryStatusFilters(
              selectedStatus: _status,
              onChanged: (status) => setState(() => _status = status),
            ),
            const SizedBox(height: 16),
            if (entries.isEmpty)
              _HistoryEmptyState(source: _source)
            else
              _Timeline(
                entries: entries,
                onTicketChanged: _updateTicket,
                onTicketDeleted: _deleteTicket,
              ),
          ],
        ),
      ),
    );
  }

  List<_HistoryTicketEntry> _filteredEntries() {
    final now = DateTime.now();
    final cutoff = switch (_period) {
      TicketHistoryPeriod.today => DateTime(now.year, now.month, now.day),
      TicketHistoryPeriod.sevenDays => DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 6)),
      TicketHistoryPeriod.thirtyDays => DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 29)),
      TicketHistoryPeriod.all => null,
    };

    final entries = [
      for (final indexed in _tickets.indexed)
        _HistoryTicketEntry.fromSaved(
          ticket: indexed.$2,
          displayNumber: _tickets.length - indexed.$1,
        ),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return [
      for (final entry in entries)
        if (_matchesPeriod(entry, cutoff) && _matchesSource(entry)) entry,
    ].where(_matchesStatus).toList(growable: false);
  }

  bool _matchesStatus(_HistoryTicketEntry entry) {
    return switch (_status) {
      TicketHistoryStatusFilter.all => true,
      TicketHistoryStatusFilter.notPlayed =>
        entry.result == TicketHistoryResult.notPlayed,
      TicketHistoryStatusFilter.pending =>
        entry.result == TicketHistoryResult.pending,
      TicketHistoryStatusFilter.won => entry.result == TicketHistoryResult.won,
      TicketHistoryStatusFilter.lost =>
        entry.result == TicketHistoryResult.lost,
      TicketHistoryStatusFilter.cancelled =>
        entry.result == TicketHistoryResult.cancelled,
    };
  }

  bool _matchesPeriod(_HistoryTicketEntry entry, DateTime? cutoff) {
    if (cutoff == null) {
      return true;
    }
    return !entry.createdAt.isBefore(cutoff);
  }

  bool _matchesSource(_HistoryTicketEntry entry) {
    return switch (_source) {
      TicketHistorySource.all => true,
      TicketHistorySource.copilot =>
        entry.source == TicketHistorySource.copilot,
      TicketHistorySource.edited => entry.source == TicketHistorySource.edited,
      TicketHistorySource.manual => entry.source == TicketHistorySource.manual,
    };
  }

  void _updateTicket(SavedTicket ticket) {
    setState(() {
      _tickets = [
        for (final savedTicket in _tickets)
          if (savedTicket.id == ticket.id) ticket else savedTicket,
      ];
    });
    widget.onTicketChanged(ticket);
  }

  void _deleteTicket(String ticketId) {
    setState(() {
      _tickets = [
        for (final ticket in _tickets)
          if (ticket.id != ticketId) ticket,
      ];
    });
    widget.onTicketDeleted(ticketId);
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({
    required this.selectedPeriod,
    required this.onPeriodChanged,
    required this.onClose,
  });

  final TicketHistoryPeriod selectedPeriod;
  final ValueChanged<TicketHistoryPeriod> onPeriodChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Historique & performances',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Fermer',
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final period in TicketHistoryPeriod.values) ...[
                _PeriodChip(
                  label: _periodLabel(period),
                  isSelected: period == selectedPeriod,
                  onTap: () => onPeriodChanged(period),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _periodLabel(TicketHistoryPeriod period) {
    return switch (period) {
      TicketHistoryPeriod.today => 'Aujourd’hui',
      TicketHistoryPeriod.sevenDays => '7 jours',
      TicketHistoryPeriod.thirtyDays => '30 jours',
      TicketHistoryPeriod.all => 'Tout',
    };
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final surfaces = context.surfaces;
    final textColors = context.textColors;
    final color = isSelected ? brand.accent : surfaces.border;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.chip),
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isSelected
              ? brand.accent.withValues(alpha: 0.13)
              : AppColors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: Border.all(color: color),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: isSelected ? brand.accent : textColors.secondary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _KpiStrip extends StatelessWidget {
  const _KpiStrip({required this.metrics});

  final _HistoryMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final semantic = context.semantic;
    final textColors = context.textColors;
    final cards = [
      _KpiData(
        icon: Icons.confirmation_number_outlined,
        value: metrics.ticketCount.toString(),
        label: 'Tickets',
        sublabel: 'Tous',
        color: brand.accent,
      ),
      _KpiData(
        icon: Icons.check_circle_outline_rounded,
        value: metrics.playedCount.toString(),
        label: 'Joués',
        sublabel: metrics.ticketCount == 0
            ? '0 %'
            : '${((metrics.playedCount / metrics.ticketCount) * 100).round()} %',
        color: semantic.success,
      ),
      _KpiData(
        icon: Icons.emoji_events_outlined,
        value: metrics.wonCount.toString(),
        label: 'Gagnés',
        sublabel: metrics.playedCount == 0
            ? '0 %'
            : '${((metrics.wonCount / metrics.playedCount) * 100).round()} %',
        color: semantic.warning,
      ),
      _KpiData(
        icon: Icons.trending_up_rounded,
        value: metrics.lostCount.toString(),
        label: 'Perdus',
        sublabel: metrics.playedCount == 0
            ? '0 %'
            : '${((metrics.lostCount / metrics.playedCount) * 100).round()} %',
        color: semantic.error,
      ),
      _KpiData(
        icon: Icons.storage_rounded,
        value: metrics.totalStakeLabel,
        label: 'Mise totale',
        sublabel: '',
        color: textColors.secondary,
      ),
    ];

    return SizedBox(
      height: 86,
      child: Row(
        children: [
          for (final indexed in cards.indexed) ...[
            Expanded(child: _KpiCard(data: indexed.$2)),
            if (indexed.$1 != cards.length - 1) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _KpiData {
  const _KpiData({
    required this.icon,
    required this.value,
    required this.label,
    required this.sublabel,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final String sublabel;
  final Color color;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.data});

  final _KpiData data;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(data.icon, color: data.color, size: 19),
            const SizedBox(height: 4),
            Text(
              data.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              data.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.05,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryFilters extends StatelessWidget {
  const _HistoryFilters({
    required this.selectedSource,
    required this.onChanged,
  });

  final TicketHistorySource selectedSource;
  final ValueChanged<TicketHistorySource> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          for (final source in TicketHistorySource.values)
            Expanded(
              child: _SourceChip(
                label: _sourceLabel(source),
                isSelected: selectedSource == source,
                onTap: () => onChanged(source),
              ),
            ),
        ],
      ),
    );
  }

  String _sourceLabel(TicketHistorySource source) {
    return switch (source) {
      TicketHistorySource.all => 'Tous',
      TicketHistorySource.copilot => 'Copilot',
      TicketHistorySource.edited => 'Modifiés',
      TicketHistorySource.manual => 'Manuels',
    };
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({
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

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.input),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.surfaceContainerHigh
              : AppColors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.input),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _HistoryStatusFilters extends StatelessWidget {
  const _HistoryStatusFilters({
    required this.selectedStatus,
    required this.onChanged,
  });

  final TicketHistoryStatusFilter selectedStatus;
  final ValueChanged<TicketHistoryStatusFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Statut',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final status in TicketHistoryStatusFilter.values) ...[
                _StatusChip(
                  label: _statusLabel(status),
                  isSelected: selectedStatus == status,
                  onTap: () => onChanged(status),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _statusLabel(TicketHistoryStatusFilter status) {
    return switch (status) {
      TicketHistoryStatusFilter.all => 'Tous statuts',
      TicketHistoryStatusFilter.notPlayed => 'Non joués',
      TicketHistoryStatusFilter.pending => 'En attente',
      TicketHistoryStatusFilter.won => 'Gagnés',
      TicketHistoryStatusFilter.lost => 'Perdus',
      TicketHistoryStatusFilter.cancelled => 'Annulés',
    };
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
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

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.chip),
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.13)
              : colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outlineVariant,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.entries,
    required this.onTicketChanged,
    required this.onTicketDeleted,
  });

  final List<_HistoryTicketEntry> entries;
  final ValueChanged<SavedTicket> onTicketChanged;
  final ValueChanged<String> onTicketDeleted;

  @override
  Widget build(BuildContext context) {
    final grouped = <DateTime, List<_HistoryTicketEntry>>{};
    for (final entry in entries) {
      final day = DateTime(
        entry.createdAt.year,
        entry.createdAt.month,
        entry.createdAt.day,
      );
      grouped.putIfAbsent(day, () => []).add(entry);
    }

    final days = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final day in days)
          _TimelineDay(
            day: day,
            entries: grouped[day]!,
            isLast: day == days.last,
            onTicketChanged: onTicketChanged,
            onTicketDeleted: onTicketDeleted,
          ),
      ],
    );
  }
}

class _TimelineDay extends StatelessWidget {
  const _TimelineDay({
    required this.day,
    required this.entries,
    required this.isLast,
    required this.onTicketChanged,
    required this.onTicketDeleted,
  });

  final DateTime day;
  final List<_HistoryTicketEntry> entries;
  final bool isLast;
  final ValueChanged<SavedTicket> onTicketChanged;
  final ValueChanged<String> onTicketDeleted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 18,
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Container(
                  width: 1,
                  height: 260,
                  color: colorScheme.outlineVariant,
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Text(
                      _dayTitle(day),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _dateLabel(day),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              for (final entry in entries)
                _HistoryTicketCard(
                  entry: entry,
                  onTicketChanged: onTicketChanged,
                  onTicketDeleted: onTicketDeleted,
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _dayTitle(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (day == today) {
      return 'Aujourd’hui';
    }
    if (day == yesterday) {
      return 'Hier';
    }
    return switch (day.weekday) {
      DateTime.monday => 'Lundi',
      DateTime.tuesday => 'Mardi',
      DateTime.wednesday => 'Mercredi',
      DateTime.thursday => 'Jeudi',
      DateTime.friday => 'Vendredi',
      DateTime.saturday => 'Samedi',
      _ => 'Dimanche',
    };
  }

  String _dateLabel(DateTime day) {
    const months = [
      'janvier',
      'février',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'août',
      'septembre',
      'octobre',
      'novembre',
      'décembre',
    ];
    return '${day.day} ${months[day.month - 1]}';
  }
}

class _HistoryTicketCard extends StatelessWidget {
  const _HistoryTicketCard({
    required this.entry,
    required this.onTicketChanged,
    required this.onTicketDeleted,
  });

  final _HistoryTicketEntry entry;
  final ValueChanged<SavedTicket> onTicketChanged;
  final ValueChanged<String> onTicketDeleted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final components = context.components;
    final accent = _sourceAccent(context, entry.source);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SourceIcon(source: entry.source, color: accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                entry.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: colorScheme.onSurface,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '#${entry.displayNumber}',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          entry.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _ResultBadge(result: entry.result),
                      const SizedBox(height: 7),
                      Text(
                        entry.totalOdds.toStringAsFixed(2),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: components.oddsText,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      PopupMenuButton<_HistoryTicketAction>(
                        tooltip: 'Actions du ticket',
                        icon: const Icon(Icons.more_horiz_rounded),
                        onSelected: (action) => _handleAction(context, action),
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: _HistoryTicketAction.details,
                            child: Text('Voir le détail'),
                          ),
                          PopupMenuItem(
                            value: _HistoryTicketAction.markPlayed,
                            child: Text('Déclarer joué'),
                          ),
                          PopupMenuItem(
                            value: _HistoryTicketAction.markNotPlayed,
                            child: Text('Marquer non joué'),
                          ),
                          PopupMenuItem(
                            value: _HistoryTicketAction.markWon,
                            child: Text('Marquer gagné'),
                          ),
                          PopupMenuItem(
                            value: _HistoryTicketAction.markLost,
                            child: Text('Marquer perdu'),
                          ),
                          PopupMenuItem(
                            value: _HistoryTicketAction.markCancelled,
                            child: Text('Annuler'),
                          ),
                          PopupMenuItem(
                            value: _HistoryTicketAction.delete,
                            child: Text('Supprimer'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Column(
                  children: [
                    for (final selection in entry.selections)
                      _HistorySelectionRow(selection: selection),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _HistoryTicketFooter(entry: entry, accent: accent),
            ],
          ),
        ),
      ),
    );
  }

  Color _sourceAccent(BuildContext context, TicketHistorySource source) {
    return switch (source) {
      TicketHistorySource.copilot => context.brand.accent,
      TicketHistorySource.edited => context.semantic.warning,
      TicketHistorySource.manual => context.opportunities.levelGap,
      TicketHistorySource.all => context.brand.accent,
    };
  }

  void _handleAction(BuildContext context, _HistoryTicketAction action) {
    switch (action) {
      case _HistoryTicketAction.details:
        _showDetails(context);
      case _HistoryTicketAction.markPlayed:
        _showPlayedDeclaration(context);
      case _HistoryTicketAction.markNotPlayed:
        _changeStatus(SavedTicketStatus.saved, clearsPlayedDeclaration: true);
      case _HistoryTicketAction.markWon:
        _changeStatus(SavedTicketStatus.won);
      case _HistoryTicketAction.markLost:
        _changeStatus(SavedTicketStatus.lost);
      case _HistoryTicketAction.markCancelled:
        _changeStatus(SavedTicketStatus.cancelled);
      case _HistoryTicketAction.delete:
        _confirmDelete(context);
    }
  }

  void _changeStatus(
    SavedTicketStatus status, {
    bool clearsPlayedDeclaration = false,
  }) {
    onTicketChanged(
      entry.ticket.copyWith(
        status: status,
        updatedAt: DateTime.now().toUtc(),
        clearsPlayedDeclaration: clearsPlayedDeclaration,
      ),
    );
  }

  Future<void> _showPlayedDeclaration(BuildContext context) async {
    final updatedTicket = await showModalBottomSheet<SavedTicket>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _PlayedDeclarationSheet(ticket: entry.ticket),
    );
    if (updatedTicket != null) {
      onTicketChanged(updatedTicket);
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le ticket ?'),
        content: const Text(
          'Cette action retire le ticket de votre historique local.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      onTicketDeleted(entry.ticket.id);
    }
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _SavedTicketDetailsSheet(ticket: entry.ticket),
    );
  }
}

enum _HistoryTicketAction {
  details,
  markPlayed,
  markNotPlayed,
  markWon,
  markLost,
  markCancelled,
  delete,
}

class _PlayedDeclarationSheet extends StatefulWidget {
  const _PlayedDeclarationSheet({required this.ticket});

  final SavedTicket ticket;

  @override
  State<_PlayedDeclarationSheet> createState() =>
      _PlayedDeclarationSheetState();
}

class _PlayedDeclarationSheetState extends State<_PlayedDeclarationSheet> {
  late final TextEditingController _bookmakerController = TextEditingController(
    text: widget.ticket.playedDeclaration?.bookmaker ?? '',
  );
  late final TextEditingController _stakeController = TextEditingController(
    text: _initialNumber(widget.ticket.playedDeclaration?.stake),
  );
  late final TextEditingController _actualOddsController =
      TextEditingController(
        text: _initialNumber(widget.ticket.playedDeclaration?.actualTotalOdds),
      );

  @override
  void dispose() {
    _bookmakerController.dispose();
    _stakeController.dispose();
    _actualOddsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.78;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Déclarer le ticket joué',
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
            const SizedBox(height: 8),
            Text(
              'Ces informations servent uniquement à suivre vos tickets enregistrés.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bookmakerController,
              decoration: const InputDecoration(
                labelText: 'Bookmaker',
                hintText: 'Ex : Betclic, Unibet...',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _stakeController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Mise réelle',
                suffixText: 'EUR',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _actualOddsController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Cote réelle obtenue',
                hintText: 'Optionnel',
              ),
            ),
            const SizedBox(height: 16),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.input),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.24),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Le statut passera à “En attente”. Vous pourrez ensuite marquer le ticket gagné, perdu, annulé ou non joué.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _save,
              child: const Text('Enregistrer comme joué'),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    Navigator.of(context).pop(
      widget.ticket.copyWith(
        status: SavedTicketStatus.played,
        updatedAt: DateTime.now().toUtc(),
        playedDeclaration: SavedTicketPlayDeclaration(
          bookmaker: _bookmakerController.text.trim(),
          stake: _doubleFromText(_stakeController.text),
          actualTotalOdds: _doubleFromText(_actualOddsController.text),
          playedAt: DateTime.now().toUtc(),
        ),
      ),
    );
  }

  String _initialNumber(double? value) {
    if (value == null) {
      return '';
    }
    return value.toStringAsFixed(2);
  }

  double? _doubleFromText(String value) {
    final normalized = value.trim().replaceAll(',', '.');
    if (normalized.isEmpty) {
      return null;
    }
    return double.tryParse(normalized);
  }
}

class _SavedTicketDetailsSheet extends StatelessWidget {
  const _SavedTicketDetailsSheet({required this.ticket});

  final SavedTicket ticket;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
                      ticket.name ?? 'Ticket',
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FooterPill(
                    label:
                        '${ticket.selectionCount} sélection${ticket.selectionCount > 1 ? 's' : ''}',
                  ),
                  _FooterPill(
                    label: 'Cote totale ${ticket.totalOdds.toStringAsFixed(2)}',
                  ),
                  _FooterPill(label: 'Statut : ${_statusLabel(ticket.status)}'),
                  if (ticket.strategyName != null)
                    _FooterPill(label: 'Stratégie : ${ticket.strategyName}'),
                  if (ticket.playedDeclaration != null)
                    _FooterPill(
                      label:
                          'Joué : ${_playedDeclarationLabel(ticket.playedDeclaration!)}',
                    ),
                ],
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
                child: Column(
                  children: [
                    for (final selection in ticket.selections)
                      _HistorySelectionRow(
                        selection: _HistorySelection.fromSavedSelection(
                          selection,
                        ),
                      ),
                  ],
                ),
              ),
              if (ticket.modificationSummary != null) ...[
                const SizedBox(height: 14),
                _HistoryModificationTrace(
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

  String _statusLabel(SavedTicketStatus status) {
    return switch (status) {
      SavedTicketStatus.saved => 'Non joué',
      SavedTicketStatus.played => 'En attente',
      SavedTicketStatus.won => 'Gagné',
      SavedTicketStatus.lost => 'Perdu',
      SavedTicketStatus.cancelled => 'Annulé',
    };
  }

  String _playedDeclarationLabel(SavedTicketPlayDeclaration declaration) {
    final parts = <String>[];
    if (declaration.bookmaker.trim().isNotEmpty) {
      parts.add(declaration.bookmaker.trim());
    }
    if (declaration.stake != null) {
      parts.add(
        '${declaration.stake!.toStringAsFixed(2).replaceAll('.', ',')} EUR',
      );
    }
    if (declaration.actualTotalOdds != null) {
      parts.add('cote ${declaration.actualTotalOdds!.toStringAsFixed(2)}');
    }
    return parts.isEmpty ? 'déclaré' : parts.join(' · ');
  }
}

class _SourceIcon extends StatelessWidget {
  const _SourceIcon({required this.source, required this.color});

  final TicketHistorySource source;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final icon = switch (source) {
      TicketHistorySource.copilot => Icons.auto_awesome_rounded,
      TicketHistorySource.edited => Icons.edit_rounded,
      TicketHistorySource.manual => Icons.person_outline_rounded,
      TicketHistorySource.all => Icons.confirmation_number_outlined,
    };

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.75)),
      ),
      child: Icon(icon, color: color, size: 23),
    );
  }
}

class _ResultBadge extends StatelessWidget {
  const _ResultBadge({required this.result});

  final TicketHistoryResult result;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    final textColors = context.textColors;
    final spec = switch (result) {
      TicketHistoryResult.won => (
        label: 'Gagné',
        icon: Icons.check_rounded,
        color: semantic.success,
      ),
      TicketHistoryResult.lost => (
        label: 'Perdu',
        icon: Icons.close_rounded,
        color: semantic.error,
      ),
      TicketHistoryResult.pending => (
        label: 'En attente',
        icon: Icons.schedule_rounded,
        color: semantic.warning,
      ),
      TicketHistoryResult.notPlayed => (
        label: 'Non joué',
        icon: Icons.bookmark_border_rounded,
        color: textColors.weak,
      ),
      TicketHistoryResult.cancelled => (
        label: 'Annulé',
        icon: Icons.block_rounded,
        color: textColors.weak,
      ),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: spec.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(spec.icon, color: spec.color, size: 15),
            const SizedBox(width: 5),
            Text(
              spec.label.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: spec.color,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistorySelectionRow extends StatelessWidget {
  const _HistorySelectionRow({required this.selection});

  final _HistorySelection selection;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final components = context.components;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: Row(
        children: [
          SportsAssetBadge(
            size: 30,
            imageUrl: selection.homeLogoUrl,
            fallbackLabel: selection.matchLabel,
            borderRadius: 8,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selection.matchLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  selection.competitionName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _MarketMiniChip(label: selection.marketLabel),
          const SizedBox(width: 8),
          SizedBox(
            width: 66,
            child: Text(
              selection.selectionLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            selection.odds.toStringAsFixed(2),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: components.oddsText,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketMiniChip extends StatelessWidget {
  const _MarketMiniChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(maxWidth: 96),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Text(
        _shortMarketLabel(label),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  String _shortMarketLabel(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('double')) {
      return '1X2';
    }
    if (lower.contains('btts') || lower.contains('deux équipes')) {
      return 'BTTS';
    }
    if (lower.contains('plus') || lower.contains('moins')) {
      return '+/- buts';
    }
    if (lower.contains('résultat') || lower.contains('result')) {
      return '1 N 2';
    }
    return label;
  }
}

class _HistoryModificationTrace extends StatelessWidget {
  const _HistoryModificationTrace({
    required this.summary,
    required this.details,
  });

  final String summary;
  final List<String> details;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final warning = context.semantic.warning;

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
              for (final detail in details)
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

class _HistoryTicketFooter extends StatelessWidget {
  const _HistoryTicketFooter({required this.entry, required this.accent});

  final _HistoryTicketEntry entry;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final meta = switch (entry.source) {
      TicketHistorySource.edited =>
        entry.modificationSummary ?? 'Modifications enregistrées',
      TicketHistorySource.manual => 'Créé manuellement',
      _ => 'Lecture principale : ${entry.mainCombinedReading}',
    };
    final playedDeclaration = entry.ticket.playedDeclaration;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _FooterPill(label: 'Stratégie : ${entry.strategyName ?? '—'}'),
        _FooterPill(icon: _footerIcon(entry.source), label: meta),
        if (playedDeclaration != null)
          _FooterPill(
            icon: Icons.sports_score_outlined,
            label: 'Joué : ${_playedDeclarationLabel(playedDeclaration)}',
          ),
        Text(
          '${entry.selectionCount} match${entry.selectionCount > 1 ? 's' : ''}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  IconData _footerIcon(TicketHistorySource source) {
    return switch (source) {
      TicketHistorySource.edited => Icons.edit_outlined,
      TicketHistorySource.manual => Icons.person_outline_rounded,
      _ => Icons.auto_awesome_rounded,
    };
  }

  String _playedDeclarationLabel(SavedTicketPlayDeclaration declaration) {
    final parts = <String>[];
    if (declaration.bookmaker.trim().isNotEmpty) {
      parts.add(declaration.bookmaker.trim());
    }
    if (declaration.stake != null) {
      parts.add(
        '${declaration.stake!.toStringAsFixed(2).replaceAll('.', ',')} EUR',
      );
    }
    if (declaration.actualTotalOdds != null) {
      parts.add('cote ${declaration.actualTotalOdds!.toStringAsFixed(2)}');
    }
    return parts.isEmpty ? 'déclaré' : parts.join(' · ');
  }
}

class _FooterPill extends StatelessWidget {
  const _FooterPill({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: colorScheme.onSurfaceVariant, size: 15),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryEmptyState extends StatelessWidget {
  const _HistoryEmptyState({required this.source});

  final TicketHistorySource source;

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
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(Icons.history_rounded, color: colorScheme.primary, size: 32),
            const SizedBox(height: 10),
            Text(
              _title(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Les tickets apparaîtront ici dès qu’ils seront générés, modifiés ou créés manuellement.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _title() {
    return switch (source) {
      TicketHistorySource.edited => 'Aucun ticket modifié',
      TicketHistorySource.manual => 'Aucun ticket manuel',
      TicketHistorySource.copilot => 'Aucun ticket Copilot',
      TicketHistorySource.all => 'Aucun ticket dans l’historique',
    };
  }
}

class _HistoryTicketEntry {
  const _HistoryTicketEntry({
    required this.ticket,
    required this.displayNumber,
    required this.source,
    required this.title,
    required this.subtitle,
    required this.createdAt,
    required this.result,
    required this.totalOdds,
    required this.selections,
    this.strategyName,
    this.mainCombinedReading = 'Lecture combinée',
    this.modificationSummary,
    this.modificationDetails = const [],
    this.totalStake,
  });

  final SavedTicket ticket;
  final int displayNumber;
  final TicketHistorySource source;
  final String title;
  final String subtitle;
  final DateTime createdAt;
  final TicketHistoryResult result;
  final double totalOdds;
  final List<_HistorySelection> selections;
  final String? strategyName;
  final String mainCombinedReading;
  final String? modificationSummary;
  final List<String> modificationDetails;
  final double? totalStake;

  int get selectionCount => selections.length;

  static _HistoryTicketEntry fromSaved({
    required SavedTicket ticket,
    required int displayNumber,
  }) {
    final createdAt = ticket.createdAt.toLocal();
    final source = _sourceFromSaved(ticket.source);

    return _HistoryTicketEntry(
      ticket: ticket,
      displayNumber: displayNumber,
      source: source,
      title: _titleFromSaved(ticket),
      subtitle: 'Créé à ${_timeLabel(createdAt)}',
      createdAt: createdAt,
      result: _resultFromStatus(ticket.status),
      totalOdds: ticket.totalOdds,
      strategyName: ticket.strategyName,
      selections: [
        for (final selection in ticket.selections)
          _HistorySelection.fromSavedSelection(selection),
      ],
      totalStake: ticket.playedDeclaration?.stake ?? ticket.plannedStake,
      mainCombinedReading:
          ticket.mainCombinedReadingLabel ?? 'Lecture combinée principale',
      modificationSummary: ticket.modificationSummary,
      modificationDetails: ticket.modificationDetails,
    );
  }

  static TicketHistorySource _sourceFromSaved(SavedTicketSource source) {
    return switch (source) {
      SavedTicketSource.copilot => TicketHistorySource.copilot,
      SavedTicketSource.copilotModified => TicketHistorySource.edited,
      SavedTicketSource.manual => TicketHistorySource.manual,
    };
  }

  static String _titleFromSaved(SavedTicket ticket) {
    final name = ticket.name?.trim();
    if (name != null && name.isNotEmpty && name != 'Mon ticket') {
      return name;
    }
    return switch (ticket.source) {
      SavedTicketSource.copilot => 'Ticket Copilot',
      SavedTicketSource.copilotModified => 'Ticket Copilot modifié',
      SavedTicketSource.manual => 'Ticket manuel',
    };
  }

  static TicketHistoryResult _resultFromStatus(SavedTicketStatus status) {
    return switch (status) {
      SavedTicketStatus.won => TicketHistoryResult.won,
      SavedTicketStatus.lost => TicketHistoryResult.lost,
      SavedTicketStatus.played => TicketHistoryResult.pending,
      SavedTicketStatus.saved => TicketHistoryResult.notPlayed,
      SavedTicketStatus.cancelled => TicketHistoryResult.cancelled,
    };
  }

  static String _timeLabel(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _HistorySelection {
  const _HistorySelection({
    required this.matchLabel,
    required this.competitionName,
    required this.marketLabel,
    required this.selectionLabel,
    required this.odds,
    this.homeLogoUrl,
  });

  final String matchLabel;
  final String competitionName;
  final String marketLabel;
  final String selectionLabel;
  final double odds;
  final String? homeLogoUrl;

  static _HistorySelection fromSavedSelection(SavedTicketSelection selection) {
    return _HistorySelection(
      matchLabel: selection.matchLabel,
      competitionName: selection.competitionName,
      marketLabel: selection.marketLabel,
      selectionLabel: selection.selectionLabel,
      odds: selection.odds,
      homeLogoUrl: selection.homeLogoUrl,
    );
  }
}

class _HistoryMetrics {
  const _HistoryMetrics({
    required this.ticketCount,
    required this.playedCount,
    required this.wonCount,
    required this.lostCount,
    required this.totalStake,
  });

  final int ticketCount;
  final int playedCount;
  final int wonCount;
  final int lostCount;
  final double totalStake;

  String get totalStakeLabel {
    if (totalStake == 0) {
      return '—';
    }
    return '${totalStake.toStringAsFixed(2).replaceAll('.', ',')} €';
  }

  static _HistoryMetrics from(List<_HistoryTicketEntry> entries) {
    return _HistoryMetrics(
      ticketCount: entries.length,
      playedCount: entries
          .where(
            (entry) =>
                entry.result == TicketHistoryResult.pending ||
                entry.result == TicketHistoryResult.won ||
                entry.result == TicketHistoryResult.lost,
          )
          .length,
      wonCount: entries
          .where((entry) => entry.result == TicketHistoryResult.won)
          .length,
      lostCount: entries
          .where((entry) => entry.result == TicketHistoryResult.lost)
          .length,
      totalStake: entries.fold<double>(
        0,
        (total, entry) => total + (entry.totalStake ?? 0),
      ),
    );
  }
}
