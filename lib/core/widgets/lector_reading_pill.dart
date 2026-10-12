import 'package:flutter/material.dart';
import '../theme/app_components.dart';
import '../theme/app_radius.dart';

/// Same reading badge surface in every discipline. Style is supplied by theme.
class LectorReadingPill extends StatelessWidget {
  const LectorReadingPill({
    required this.label,
    required this.style,
    required this.icon,
    this.compact = false,
    super.key,
  });
  final String label;
  final AppReadingBadgeStyle style;
  final IconData icon;
  final bool compact;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: style.background,
      borderRadius: BorderRadius.circular(AppRadius.chip),
      border: Border.all(color: style.border),
    ),
    child: Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 5 : 4,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 12 : 15, color: style.iconColor),
          SizedBox(width: compact ? 3 : 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: style.foreground,
                fontWeight: compact ? FontWeight.w600 : FontWeight.w900,
                fontSize: compact ? 9 : null,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
