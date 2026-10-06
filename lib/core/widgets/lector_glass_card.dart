import 'package:flutter/material.dart';

import '../theme/app_components.dart';
import '../theme/app_radius.dart';

class LectorGlassCard extends StatelessWidget {
  const LectorGlassCard({
    required this.child,
    required this.padding,
    this.backgroundAsset,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final String? backgroundAsset;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final radius = BorderRadius.circular(AppRadius.control);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: surfaces.shadow.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: surfaces.border.withValues(alpha: 0.92)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(color: surfaces.surface.withValues(alpha: 0.72)),
          ),
          if (backgroundAsset != null) ...[
            Positioned.fill(
              child: Image.asset(
                backgroundAsset!,
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      surfaces.shadow.withValues(alpha: 0.64),
                      surfaces.shadow.withValues(alpha: 0.76),
                    ],
                  ),
                ),
              ),
            ),
          ],
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}
