import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_components.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../tickets/domain/ticket_strategy.dart';
import 'lector_preferences_sheet.dart';

class LectorStrategiesPage extends StatefulWidget {
  const LectorStrategiesPage({
    required this.strategies,
    required this.onTicketStrategiesChanged,
    super.key,
  });

  final List<TicketStrategy> strategies;
  final TicketStrategyPreferenceSaver onTicketStrategiesChanged;

  @override
  State<LectorStrategiesPage> createState() => _LectorStrategiesPageState();
}

class _LectorStrategiesPageState extends State<LectorStrategiesPage> {
  late List<TicketStrategy> _strategies;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _strategies = _ordered(widget.strategies);
  }

  @override
  void didUpdateWidget(covariant LectorStrategiesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.strategies != widget.strategies) {
      _strategies = _ordered(widget.strategies);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _strategies
        .where((strategy) => strategy.isActive)
        .length;

    return Scaffold(
      backgroundColor: context.surfaces.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
          children: [
            _StrategiesHeader(totalCount: activeCount),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Définissez comment Lector construit vos tickets.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.textColors.secondary,
                height: 1.3,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _SummaryCard(activeCount: activeCount),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Vos stratégies',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Vos différentes configurations de tickets.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.textColors.secondary,
                height: 1.3,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            if (_strategies.isEmpty)
              _EmptyStrategiesCard(onCreate: _createStrategy)
            else ...[
              for (var index = 0; index < _strategies.length; index++) ...[
                _StrategyCard(
                  rank: index + 1,
                  strategy: _strategies[index],
                  style: context.strategies.styleForIndex(index),
                  isSaving: _isSaving,
                  onTap: () => _editStrategy(index),
                  onToggle: (value) => _toggleStrategy(index, value),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              _CreateStrategyButton(onCreate: _createStrategy),
            ],
            const SizedBox(height: AppSpacing.lg),
            const _StrategyInfoCard(),
            const SizedBox(height: AppSpacing.lg),
            _AutosaveNote(isSaving: _isSaving),
          ],
        ),
      ),
    );
  }

  Future<void> _createStrategy() async {
    final draft = createTicketStrategyDraft(index: _strategies.length + 1);
    final result = await showTicketStrategyManagementSheet(
      context: context,
      strategy: draft,
      rank: _strategies.length + 1,
      style: context.strategies.styleForIndex(_strategies.length),
      isNew: true,
      canDelete: false,
    );
    final strategy = result?.strategy;
    if (strategy == null) {
      return;
    }

    final next = _withPriorities([..._strategies, strategy]);
    await _save(next);
  }

  Future<void> _editStrategy(int index) async {
    final result = await showTicketStrategyManagementSheet(
      context: context,
      strategy: _strategies[index],
      rank: index + 1,
      style: context.strategies.styleForIndex(index),
      canDelete: true,
    );
    if (result == null) {
      return;
    }

    final next = [..._strategies];
    if (result.isDeleted) {
      next.removeAt(index);
    } else if (result.strategy != null) {
      next[index] = result.strategy!;
    }
    await _save(_withPriorities(next));
  }

  Future<void> _toggleStrategy(int index, bool isActive) async {
    final next = [..._strategies];
    next[index] = next[index].copyWith(
      isActive: isActive,
      updatedAt: DateTime.now().toUtc(),
    );
    await _save(_withPriorities(next));
  }

  Future<void> _save(List<TicketStrategy> strategies) async {
    setState(() {
      _strategies = _ordered(strategies);
      _isSaving = true;
    });
    await widget.onTicketStrategiesChanged(List.unmodifiable(_strategies));
    if (!mounted) {
      return;
    }
    setState(() {
      _isSaving = false;
    });
  }

  static List<TicketStrategy> _ordered(List<TicketStrategy> strategies) {
    return [...strategies]..sort((a, b) {
      final priority = a.priority.compareTo(b.priority);
      if (priority != 0) {
        return priority;
      }
      return a.id.compareTo(b.id);
    });
  }

  static List<TicketStrategy> _withPriorities(List<TicketStrategy> strategies) {
    return [
      for (var index = 0; index < strategies.length; index++)
        strategies[index].copyWith(priority: index + 1),
    ];
  }
}

class _StrategiesHeader extends StatelessWidget {
  const _StrategiesHeader({required this.totalCount});

  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Retour',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.chevron_left_rounded, size: 26),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'Mes stratégies',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          _CountPill(count: totalCount),
        ],
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.brand.accent.withValues(alpha: 0.08),
        border: Border.all(color: context.brand.accent.withValues(alpha: 0.7)),
      ),
      child: Text(
        '$count',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: context.brand.accent,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.activeCount});

  final int activeCount;

  @override
  Widget build(BuildContext context) {
    return _StrategyShell(
      borderColor: context.brand.accent,
      backgroundColor: context.brand.accent.withValues(alpha: 0.10),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          _IconSquare(
            icon: Icons.confirmation_number_outlined,
            color: context.brand.accent,
            size: 44,
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
                        text: '$activeCount',
                        style: TextStyle(color: context.brand.accent),
                      ),
                      TextSpan(
                        text:
                            ' stratégie${activeCount > 1 ? 's' : ''} active${activeCount > 1 ? 's' : ''}',
                      ),
                    ],
                  ),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: context.textColors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Lector peut générer plusieurs propositions selon vos différentes configurations.',
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

class _StrategyCard extends StatelessWidget {
  const _StrategyCard({
    required this.rank,
    required this.strategy,
    required this.style,
    required this.isSaving,
    required this.onTap,
    required this.onToggle,
  });

  final int rank;
  final TicketStrategy strategy;
  final AppStrategyVisualStyle style;
  final bool isSaving;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final borderColor = style.color.withValues(
      alpha: strategy.isActive ? 0.76 : 0.36,
    );

    return _StrategyShell(
      key: ValueKey('lector-strategy-card-${strategy.id}'),
      borderColor: borderColor,
      accentColor: style.color,
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 9),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _IconSquare(icon: style.icon, color: style.color, size: 34),
                    const SizedBox(width: AppSpacing.xs),
                    _RankBadge(rank: rank, color: style.color),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        _strategyName(strategy),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      strategy.isActive ? 'Activé' : 'Inactif',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: strategy.isActive
                            ? context.brand.accent
                            : context.textColors.secondary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Transform.scale(
                      scale: 0.72,
                      child: Switch(
                        value: strategy.isActive,
                        onChanged: isSaving ? null : onToggle,
                        activeThumbColor: context.brand.accent,
                        activeTrackColor: context.brand.accent.withValues(
                          alpha: 0.48,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: context.textColors.secondary,
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Divider(height: 1, color: context.surfaces.border),
                const SizedBox(height: AppSpacing.xs),
                _StrategyMetricsRow(
                  metrics: [
                    _StrategyMetricData(
                      label: 'Sélections',
                      value: _selectionRange(strategy),
                    ),
                    _StrategyMetricData(
                      label: 'Cote par sélection',
                      value: _oddsRange(
                        strategy.minimumIndividualOdds,
                        strategy.maximumIndividualOdds,
                      ),
                    ),
                    _StrategyMetricData(
                      label: 'Cote totale',
                      value: _oddsRange(
                        strategy.minimumTotalOdds,
                        strategy.maximumTotalOdds,
                      ),
                    ),
                  ],
                  color: style.color,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StrategyMetricsRow extends StatelessWidget {
  const _StrategyMetricsRow({required this.metrics, required this.color});

  final List<_StrategyMetricData> metrics;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < metrics.length; index++) ...[
          Expanded(
            child: _StrategyMetric(metric: metrics[index], color: color),
          ),
          if (index != metrics.length - 1)
            Container(
              width: 1,
              height: 34,
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              color: context.surfaces.border,
            ),
        ],
      ],
    );
  }
}

class _StrategyMetricData {
  const _StrategyMetricData({required this.label, required this.value});

  final String label;
  final String value;
}

class _StrategyMetric extends StatelessWidget {
  const _StrategyMetric({required this.metric, required this.color});

  final _StrategyMetricData metric;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metric.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: context.textColors.secondary,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            metric.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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

class _EmptyStrategiesCard extends StatelessWidget {
  const _EmptyStrategiesCard({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return _StrategyShell(
      borderColor: context.brand.accent.withValues(alpha: 0.7),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconSquare(
            icon: Icons.confirmation_number_outlined,
            color: context.brand.accent,
            size: 44,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Aucune stratégie active',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Créez une première configuration pour permettre à Lector de composer vos tickets.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.textColors.secondary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('create-ticket-strategy-button'),
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Créer une stratégie'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateStrategyButton extends StatelessWidget {
  const _CreateStrategyButton({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      key: const ValueKey('create-ticket-strategy-button'),
      onPressed: onCreate,
      style: OutlinedButton.styleFrom(
        foregroundColor: context.brand.accent,
        side: BorderSide(
          color: context.brand.accent.withValues(alpha: 0.9),
          style: BorderStyle.solid,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: context.brand.accent, width: 2),
            ),
            child: const Icon(Icons.add_rounded, size: 22),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '+ Créer une stratégie',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: context.brand.accent,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Ajoutez une nouvelle configuration de ticket.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.textColors.secondary,
                    height: 1.25,
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

class _StrategyInfoCard extends StatelessWidget {
  const _StrategyInfoCard();

  @override
  Widget build(BuildContext context) {
    final color = context.opportunities.levelGap;
    return _StrategyShell(
      borderColor: color.withValues(alpha: 0.45),
      backgroundColor: color.withValues(alpha: 0.08),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          _IconSquare(
            icon: Icons.lightbulb_outline_rounded,
            color: color,
            size: 44,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Comment Lector utilise vos stratégies ?',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Lector applique vos stratégies actives pour générer des tickets adaptés à vos styles de jeu. Vous pourrez en sélectionner une au moment de générer vos tickets.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.textColors.secondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: color, size: 20),
        ],
      ),
    );
  }
}

class _AutosaveNote extends StatelessWidget {
  const _AutosaveNote({required this.isSaving});

  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          isSaving ? Icons.sync_rounded : Icons.lock_rounded,
          size: 18,
          color: context.opportunities.levelGap,
        ),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            isSaving
                ? 'Enregistrement des stratégies...'
                : 'Vos stratégies sont enregistrées automatiquement.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.textColors.secondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _IconSquare extends StatelessWidget {
  const _IconSquare({required this.icon, required this.color, this.size = 40});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.control),
        color: color.withValues(alpha: 0.16),
      ),
      child: Icon(icon, color: color, size: size * 0.48),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank, required this.color});

  final int rank;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color, width: 1.4),
      ),
      child: Text(
        '$rank',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _StrategyShell extends StatelessWidget {
  const _StrategyShell({
    super.key,
    required this.child,
    this.borderColor,
    this.backgroundColor,
    this.accentColor,
    this.padding,
  });

  final Widget child;
  final Color? borderColor;
  final Color? backgroundColor;
  final Color? accentColor;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.card);
    final content = padding == null
        ? child
        : Padding(padding: padding!, child: child);

    return ClipRRect(
      borderRadius: radius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color:
              backgroundColor ??
              context.surfaces.surface.withValues(alpha: 0.74),
          borderRadius: radius,
          border: Border.all(color: borderColor ?? context.surfaces.border),
        ),
        child: accentColor == null
            ? content
            : Stack(
                children: [
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(width: 4, color: accentColor),
                    ),
                  ),
                  content,
                ],
              ),
      ),
    );
  }
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
