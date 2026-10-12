import 'package:flutter/material.dart';
import '../theme/app_components.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import 'lector_workspace_navigation.dart';

/// Exactly five equal-width destinations. Geometry never implies selection.
class LectorGeometricNavigation extends StatelessWidget {
  const LectorGeometricNavigation({
    required this.selected,
    required this.onChanged,
    super.key,
  });
  final LectorWorkspaceSection selected;
  final ValueChanged<LectorWorkspaceSection> onChanged;
  @override
  Widget build(BuildContext context) => Material(
    color: context.surfaces.backgroundSecondary,
    borderRadius: BorderRadius.circular(AppRadius.control),
    clipBehavior: Clip.antiAlias,
    child: SizedBox(
      height: 54,
      child: Row(
        children: [
          for (final section in LectorWorkspaceSection.values)
            Expanded(
              child: _Tab(
                section: section,
                selected: section == selected,
                onPressed: () => onChanged(section),
              ),
            ),
        ],
      ),
    ),
  );
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.section,
    required this.selected,
    required this.onPressed,
  });
  final LectorWorkspaceSection section;
  final bool selected;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final label = switch (section) {
      LectorWorkspaceSection.forMe => 'Pour moi',
      LectorWorkspaceSection.radar => 'Radar',
      LectorWorkspaceSection.all => 'Tous',
      LectorWorkspaceSection.generator => 'Générateur',
      LectorWorkspaceSection.bilan => 'Bilan',
    };
    final icon = switch (section) {
      LectorWorkspaceSection.forMe => Icons.person_outline_rounded,
      LectorWorkspaceSection.radar => Icons.radar_rounded,
      LectorWorkspaceSection.all => Icons.format_list_bulleted_rounded,
      LectorWorkspaceSection.generator => Icons.auto_awesome_rounded,
      LectorWorkspaceSection.bilan => Icons.bar_chart_rounded,
    };
    final accent = section == LectorWorkspaceSection.radar
        ? context.features.radarAccent
        : section == LectorWorkspaceSection.generator
        ? context.features.generatorAccent
        : context.semantic.info;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fill = selected
        ? (dark
              ? (section == LectorWorkspaceSection.generator
                    ? context.features.generatorFill
                    : section == LectorWorkspaceSection.radar
                    ? context.features.radarFill
                    : AppCompetitionColors.activeNavigation)
              : accent.withValues(alpha: .12))
        : context.surfaces.backgroundSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('geometric-tab-${section.name}'),
        onTap: onPressed,
        child: CustomPaint(
          painter: _AnglePainter(
            fill,
            selected ? accent : context.surfaces.border,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 17,
                  color:
                      selected ||
                          section == LectorWorkspaceSection.radar ||
                          section == LectorWorkspaceSection.generator
                      ? accent
                      : context.textColors.secondary,
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected
                          ? context.textColors.primary
                          : context.textColors.secondary,
                    ),
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

class _AnglePainter extends CustomPainter {
  const _AnglePainter(this.fill, this.border);
  final Color fill, border;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(6, .5)
      ..lineTo(size.width - 6, .5)
      ..lineTo(size.width - .5, size.height - .5)
      ..lineTo(.5, size.height - .5)
      ..close();
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8,
    );
  }

  @override
  bool shouldRepaint(_AnglePainter old) =>
      old.fill != fill || old.border != border;
}
