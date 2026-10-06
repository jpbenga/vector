import 'package:flutter/material.dart';
import '../theme/app_components.dart';
import '../theme/app_radius.dart';

/// Same reading badge surface in every discipline. Style is supplied by theme.
class LectorReadingPill extends StatelessWidget {
  const LectorReadingPill({
    required this.label,
    required this.style,
    required this.icon,
    super.key,
  });
  final String label;
  final AppReadingBadgeStyle style;
  final IconData icon;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: style.background,
      borderRadius: BorderRadius.circular(AppRadius.chip),
      border: Border.all(color: style.border),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: style.iconColor),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: style.foreground,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
