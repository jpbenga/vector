import 'package:flutter/material.dart';
import '../theme/app_components.dart';
import '../domain/lector_temporal_state.dart';

/// Receives an already eligible selection. It never adds matches or reanalyses
/// readings, and keeps sport/league grouping in the supplied section builder.
class LectorTemporalFeed<T> extends StatefulWidget {
  const LectorTemporalFeed({
    required this.items,
    required this.phaseOf,
    required this.sectionBuilder,
    super.key,
  });
  final List<T> items;
  final LectorMatchPhase Function(T) phaseOf;
  final Widget Function(BuildContext, List<T>, LectorMatchPhase?)
  sectionBuilder;
  @override
  State<LectorTemporalFeed<T>> createState() => _LectorTemporalFeedState<T>();
}

class _LectorTemporalFeedState<T> extends State<LectorTemporalFeed<T>> {
  LectorMatchPhase? _selected;
  @override
  void didUpdateWidget(covariant LectorTemporalFeed<T> old) {
    super.didUpdateWidget(old);
    if (_selected != null &&
        !widget.items.any((item) => widget.phaseOf(item) == _selected)) {
      _selected = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = {
      for (final p in LectorMatchPhase.values)
        p: widget.items.where((m) => widget.phaseOf(m) == p).toList(),
    };
    // A finished match must not remain hidden when the Live chip disappears.
    final selected = _selected != null && groups[_selected]!.isEmpty
        ? null
        : _selected;
    final phases = selected == null ? LectorMatchPhase.values : [selected];
    String label(LectorMatchPhase? p) => switch (p) {
      null => 'Tous',
      LectorMatchPhase.live => 'Live',
      LectorMatchPhase.upcoming => 'À venir',
      LectorMatchPhase.finished => 'Terminés',
      LectorMatchPhase.other => 'Autres',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.items.isNotEmpty) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final p in <LectorMatchPhase?>[
                  null,
                  ...LectorMatchPhase.values,
                ])
                  if (p == null || groups[p]!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        key: ValueKey('temporal-filter-${p?.name ?? 'all'}'),
                        selected: selected == p,
                        selectedColor:
                            (p == LectorMatchPhase.live
                                    ? context.semantic.live
                                    : context.brand.accent)
                                .withValues(alpha: .12),
                        side: BorderSide(
                          color: p == LectorMatchPhase.live
                              ? context.semantic.live
                              : context.surfaces.border,
                        ),
                        showCheckmark: false,
                        label: Text(
                          '${p == LectorMatchPhase.live ? '● ' : ''}${label(p)} ${p == null ? widget.items.length : groups[p]!.length}',
                          style: TextStyle(
                            color: p == LectorMatchPhase.live
                                ? context.semantic.live
                                : context.textColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        onSelected: (_) => setState(() => _selected = p),
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (widget.items.isEmpty)
          widget.sectionBuilder(context, const [], null),
        for (final p in phases)
          if (groups[p]!.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  switch (p) {
                    LectorMatchPhase.live => Icons.circle,
                    LectorMatchPhase.upcoming => Icons.schedule_rounded,
                    _ => Icons.flag_outlined,
                  },
                  size: p == LectorMatchPhase.live ? 10 : 19,
                  color: p == LectorMatchPhase.live
                      ? context.semantic.live
                      : context.textColors.secondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    p == LectorMatchPhase.live
                        ? 'EN DIRECT'
                        : label(p).toUpperCase(),
                    style: TextStyle(
                      color: p == LectorMatchPhase.live
                          ? context.semantic.live
                          : context.textColors.secondary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '${groups[p]!.length} match${groups[p]!.length > 1 ? 's' : ''}',
                  style: TextStyle(color: context.textColors.secondary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            widget.sectionBuilder(context, groups[p]!, p),
            const SizedBox(height: 18),
          ],
      ],
    );
  }
}
