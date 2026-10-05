import 'package:flutter/material.dart';
import '../theme/app_components.dart';
import 'lector_signal_panel.dart';
import 'sports_asset_badge.dart';

/// Shared embedded Form Radar list. Sports supply factual rows and their
/// history window; no football detection rules enter the common presentation.
class LectorFormRadarSignalPanel extends StatefulWidget {
  const LectorFormRadarSignalPanel({
    required this.rows,
    required this.periodLabel,
    this.isLocalPreview = false,
    super.key,
  });
  final List<Widget> rows;
  final Widget periodLabel;
  final bool isLocalPreview;
  @override
  State<LectorFormRadarSignalPanel> createState() =>
      _LectorFormRadarSignalPanelState();
}

class _LectorFormRadarSignalPanelState
    extends State<LectorFormRadarSignalPanel> {
  static const previewLimit = 4;
  bool _expanded = false;

  @override
  void didUpdateWidget(LectorFormRadarSignalPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rows.length != widget.rows.length) _expanded = false;
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.rows.length;
    final visibleRows = _expanded
        ? widget.rows
        : widget.rows.take(previewLimit).toList(growable: false);
    if (count == 0) return const SizedBox.shrink();
    return LectorSignalPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bar_chart_rounded,
                color: context.brand.accent,
                size: 19,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Signaux Form Radar',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.textColors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  count == 1 ? '1 signal de forme' : '$count signaux de forme',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.textColors.secondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (widget.isLocalPreview) ...[
                const SizedBox(width: 6),
                Text(
                  'aperçu local',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.brand.accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 7),
          Align(alignment: Alignment.centerRight, child: widget.periodLabel),
          const SizedBox(height: 4),
          for (final indexed in visibleRows.indexed) ...[
            if (indexed.$1 > 0)
              Divider(height: 12, color: context.surfaces.border),
            indexed.$2,
          ],
          if (count > previewLimit) ...[
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(
                _expanded ? 'Réduire la liste' : 'Voir les $count joueurs',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class LectorFormRadarSignalRow extends StatelessWidget {
  const LectorFormRadarSignalRow({
    required this.name,
    required this.description,
    required this.activity,
    this.logoUrl,
    super.key,
  });
  final String name;
  final String? logoUrl;
  final Widget description, activity;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      SportsAssetBadge(
        size: 34,
        imageUrl: logoUrl,
        fallbackLabel: name,
        borderRadius: 17,
        contrastPlate: true,
      ),
      const SizedBox(width: 7),
      Expanded(child: description),
      const SizedBox(width: 7),
      activity,
    ],
  );
}
