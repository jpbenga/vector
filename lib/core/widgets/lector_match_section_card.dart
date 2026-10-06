import 'package:flutter/material.dart';
import '../theme/app_components.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import 'lector_glass_card.dart';

/// Shared section header/surface for factual match panels and missing data.
class LectorMatchSectionCard extends StatelessWidget {
  const LectorMatchSectionCard({
    required this.title,
    required this.child,
    this.subtitle,
    this.icon = Icons.info_outline_rounded,
    super.key,
  });
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget child;
  @override
  Widget build(BuildContext context) => LectorGlassCard(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: context.brand.accent),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.textColors.secondary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

class LectorMatchSynthesisHeader extends StatelessWidget {
  const LectorMatchSynthesisHeader({required this.subtitle, super.key});
  final String subtitle;
  @override
  Widget build(BuildContext context) {
    final accent = context.opportunities.levelGap;
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .16),
            borderRadius: BorderRadius.circular(AppRadius.odds),
          ),
          child: Icon(Icons.track_changes_rounded, color: accent, size: 25),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MATCH À SUIVRE',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: context.textColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class LectorMatchScopeChip extends StatelessWidget {
  const LectorMatchScopeChip({
    required this.label,
    required this.selected,
    required this.onPressed,
    this.color,
    this.personalized = false,
    this.semanticsLabel,
    super.key,
  });
  final String label;
  final String? semanticsLabel;
  final bool selected, personalized;
  final VoidCallback onPressed;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final accent = color ?? context.brand.accent;
    return Semantics(
      label: semanticsLabel ?? label,
      button: true,
      selected: selected,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: selected ? accent : context.textColors.secondary,
          backgroundColor: selected
              ? accent.withValues(alpha: .13)
              : AppColors.transparent,
          side: BorderSide(
            color: personalized || selected
                ? accent.withValues(alpha: .78)
                : context.surfaces.border,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          visualDensity: VisualDensity.compact,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (personalized) ...[
              Icon(Icons.auto_awesome_rounded, size: 13, color: accent),
              const SizedBox(width: 5),
            ],
            Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}
