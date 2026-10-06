import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_components.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// Settings presentation shared by every discipline; sport-specific pages
/// supply their own preferences, counters and destinations.
class LectorSpaceHeader extends StatelessWidget {
  const LectorSpaceHeader({required this.onSettings, super.key});

  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: 'Retour',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.chevron_left_rounded, size: 26),
            ),
          ),
          Text(
            'Mon espace',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Préférences',
              onPressed: onSettings,
              icon: const Icon(Icons.settings_outlined, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}

class LectorSpaceSectionHeading extends StatelessWidget {
  const LectorSpaceSectionHeading({
    required this.title,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.textColors.secondary,
              height: 1.3,
            ),
          ),
        ],
      ],
    );
  }
}

class LectorSpaceActionCard extends StatelessWidget {
  const LectorSpaceActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.color,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int count;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LectorSpaceCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.textColors.secondary,
                    height: 1.24,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          _CountBadge(count: count, color: color),
          Icon(
            Icons.chevron_right_rounded,
            color: context.textColors.secondary,
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: SizedBox.square(
        dimension: 26,
        child: Center(
          child: Text(
            '$count',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class LectorSpaceCard extends StatelessWidget {
  const LectorSpaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    final decoration = BoxDecoration(
      color: context.surfaces.surface.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(AppRadius.card),
      border: Border.all(color: context.surfaces.border),
    );

    if (onTap == null) {
      return DecoratedBox(decoration: decoration, child: content);
    }

    return Material(
      color: AppColors.transparent,
      child: Ink(
        decoration: decoration,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: content,
        ),
      ),
    );
  }
}
