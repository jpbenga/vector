import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_components.dart';
import '../domain/lector_temporal_state.dart';

/// No simulated clock: the label reflects the last factual provider response.
class LectorLiveBadge extends StatefulWidget {
  const LectorLiveBadge({
    required this.state,
    this.prominent = false,
    super.key,
  });
  final LectorTemporalState state;
  final bool prominent;
  @override
  State<LectorLiveBadge> createState() => _LectorLiveBadgeState();
  Widget _build(BuildContext context) {
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
            padding: EdgeInsets.symmetric(
              horizontal: prominent ? 12 : 9,
              vertical: prominent ? 8 : 5,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  stale ? Icons.pause_circle_outline_rounded : Icons.circle,
                  size: prominent ? 10 : 8,
                  color: color,
                ),
                const SizedBox(width: 6),
                Text(
                  prominent
                      ? (state.clock == null && state.period == null
                            ? (stale ? 'Dernier état reçu' : 'En direct')
                            : '${state.compactLabel} · ${stale ? 'Dernier état' : 'En direct'}')
                      : state.compactLabel,
                  maxLines: 1,
                  style: TextStyle(
                    color: color,
                    fontSize: prominent ? 14 : 12,
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

class _LectorLiveBadgeState extends State<LectorLiveBadge> {
  Timer? _freshness;
  @override
  void initState() {
    super.initState();
    _freshness = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && widget.state.isLive) setState(() {});
    });
  }

  @override
  void dispose() {
    _freshness?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget._build(context);
}
