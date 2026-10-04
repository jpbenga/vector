import 'package:flutter/material.dart';
import '../theme/app_components.dart';
import '../domain/lector_temporal_state.dart';

/// No simulated clock: the label reflects the last factual provider response.
class LectorLiveBadge extends StatelessWidget {
  const LectorLiveBadge({required this.state, super.key});
  final LectorTemporalState state;
  @override
  Widget build(BuildContext context) {
    if (!state.isLive) return const SizedBox.shrink();
    final stale = state.isStale(DateTime.now());
    final color = stale ? context.semantic.warning : context.semantic.live;
    return Semantics(
      label:
          '${stale ? 'Dernier état reçu, actualisation en retard' : 'En direct'}, ${state.compactLabel}',
      child: Tooltip(
        message: stale
            ? 'Actualisation en retard. Dernier état reçu.'
            : 'En direct',
        child: DecoratedBox(
          key: const ValueKey('live-match-status-badge'),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .08),
            border: Border.all(color: color.withValues(alpha: .65)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  stale ? Icons.pause_circle_outline_rounded : Icons.circle,
                  size: 8,
                  color: color,
                ),
                const SizedBox(width: 6),
                Text(
                  state.compactLabel,
                  maxLines: 1,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
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
