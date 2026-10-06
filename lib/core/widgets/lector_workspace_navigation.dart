import 'package:flutter/material.dart';
import '../theme/app_components.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

enum LectorWorkspaceSection { forMe, radar, all, generator, bilan }

class LectorWorkspaceNavigation extends StatelessWidget {
  const LectorWorkspaceNavigation({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final LectorWorkspaceSection selected;
  final ValueChanged<LectorWorkspaceSection> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('home-primary-navigation'),
      height: 48.0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.surfaces.backgroundSecondary,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: context.surfaces.border),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 470;
            return Row(
              children: [
                _ScoresModeTab(
                  icon: Icons.person_outline_rounded,
                  label: 'Pour moi',
                  compact: compact,
                  isSelected: selected == LectorWorkspaceSection.forMe,
                  onTap: () => onChanged(LectorWorkspaceSection.forMe),
                ),
                _ModeDivider(),
                _ScoresModeTab(
                  icon: Icons.bar_chart_rounded,
                  label: 'Radar',
                  compact: compact,
                  isSelected: selected == LectorWorkspaceSection.radar,
                  onTap: () => onChanged(LectorWorkspaceSection.radar),
                ),
                _ModeDivider(),
                _ScoresModeTab(
                  icon: Icons.format_list_bulleted_rounded,
                  label: 'Tous',
                  compact: compact,
                  isSelected: selected == LectorWorkspaceSection.all,
                  onTap: () => onChanged(LectorWorkspaceSection.all),
                ),
                _ModeDivider(),
                _ScoresModeTab(
                  icon: Icons.auto_awesome_rounded,
                  label: 'Générateur',
                  compact: compact,
                  isSelected: selected == LectorWorkspaceSection.generator,
                  onTap: () => onChanged(LectorWorkspaceSection.generator),
                ),
                _ModeDivider(),
                _ScoresModeTab(
                  icon: Icons.insights_outlined,
                  label: 'Bilan',
                  compact: compact,
                  isSelected: selected == LectorWorkspaceSection.bilan,
                  onTap: () => onChanged(LectorWorkspaceSection.bilan),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ModeDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: VerticalDivider(color: context.surfaces.border),
    );
  }
}

class _ScoresModeTab extends StatelessWidget {
  const _ScoresModeTab({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? context.brand.accent
        : context.textColors.secondary;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: SizedBox(
          height: 48.0,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!compact) ...[
                    Icon(icon, size: 17, color: color),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: compact ? 12 : null,
                      ),
                    ),
                  ),
                ],
              ),
              if (isSelected)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: context.brand.accent,
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                    ),
                    child: const SizedBox(height: 3),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
