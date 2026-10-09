import 'package:flutter/material.dart';
import '../theme/app_components.dart';
import '../theme/app_radius.dart';

enum LectorWorkspaceSection { forMe, radar, all, generator, bilan }

/// Permanent feature shapes are distinct from the unique selected marker.
class LectorWorkspaceNavigation extends StatelessWidget {
  const LectorWorkspaceNavigation({
    super.key,
    required this.selected,
    required this.onChanged,
  });
  final LectorWorkspaceSection selected;
  final ValueChanged<LectorWorkspaceSection> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('home-primary-navigation'),
    height: 48,
    child: Material(
      color: context.surfaces.backgroundSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: context.surfaces.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 600;
          return Row(
            children: [
              for (final section in LectorWorkspaceSection.values)
                Expanded(
                  flex: compact
                      ? switch (section) {
                          LectorWorkspaceSection.forMe => 125,
                          LectorWorkspaceSection.radar => 110,
                          LectorWorkspaceSection.all => 75,
                          LectorWorkspaceSection.generator => 160,
                          LectorWorkspaceSection.bilan => 90,
                        }
                      : 1,
                  child: _WorkspaceTab(
                    section: section,
                    compact: compact,
                    selected: selected == section,
                    onTap: () => onChanged(section),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}

class _WorkspaceTab extends StatelessWidget {
  const _WorkspaceTab({
    required this.section,
    required this.compact,
    required this.selected,
    required this.onTap,
  });
  final LectorWorkspaceSection section;
  final bool compact, selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final feature =
        section == LectorWorkspaceSection.radar ||
        section == LectorWorkspaceSection.generator;
    final radar = section == LectorWorkspaceSection.radar;
    final identity = radar ? const Color(0xff62bd94) : const Color(0xffb69add);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final featureFill = radar
        ? (dark ? const Color(0xff18362d) : const Color(0xffdbeee4))
        : (dark ? const Color(0xff32273f) : const Color(0xffece2f4));
    final featureText = dark
        ? identity
        : radar
        ? const Color(0xff256347)
        : const Color(0xff674485);
    final active = feature ? featureText : context.brand.accent;
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
      LectorWorkspaceSection.generator => Icons.auto_awesome_motion_rounded,
      LectorWorkspaceSection.bilan => Icons.insights_outlined,
    };
    final text = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        label,
        maxLines: 1,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: selected
              ? (feature && dark ? Colors.white : active)
              : context.textColors.secondary,
          fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
          fontSize: compact ? 11.5 : 13,
        ),
      ),
    );
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('workspace-tab-${section.name}'),
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (feature)
                Positioned.fill(
                  left: 1,
                  right: 1,
                  top: 4,
                  bottom: 4,
                  child: CustomPaint(
                    painter: _FeatureShapePainter(
                      fill: featureFill,
                      stroke: featureText.withValues(
                        alpha: selected ? .85 : .32,
                      ),
                      selected: selected,
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: feature ? 8 : 3),
                child: compact && feature
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 15, color: featureText),
                          const SizedBox(height: 2),
                          text,
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!compact) ...[
                            Icon(
                              icon,
                              size: 18,
                              color: feature
                                  ? featureText
                                  : selected
                                  ? active
                                  : context.textColors.secondary,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Flexible(child: text),
                        ],
                      ),
              ),
              if (selected)
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 0,
                  child: Container(
                    key: ValueKey('workspace-selected-${section.name}'),
                    height: 3,
                    decoration: BoxDecoration(
                      color: active,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rounded sloped sides reproduce the reference without bitmap decoration.
class _FeatureShapePainter extends CustomPainter {
  const _FeatureShapePainter({
    required this.fill,
    required this.stroke,
    required this.selected,
  });
  final Color fill, stroke;
  final bool selected;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final slope = w < 100 ? 6.0 : 14.0;
    final path = Path()
      ..moveTo(slope + 6, .8)
      ..lineTo(w - slope - 6, .8)
      ..quadraticBezierTo(w - slope, .8, w - slope + 2, 6)
      ..lineTo(w - 1, h - 7)
      ..quadraticBezierTo(w + 1, h - .8, w - 7, h - .8)
      ..lineTo(7, h - .8)
      ..quadraticBezierTo(-1, h - .8, 1, h - 7)
      ..lineTo(slope - 2, 6)
      ..quadraticBezierTo(slope, .8, slope + 6, .8)
      ..close();
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 1.4 : .7,
    );
  }

  @override
  bool shouldRepaint(_FeatureShapePainter old) =>
      old.fill != fill || old.stroke != stroke || old.selected != selected;
}
