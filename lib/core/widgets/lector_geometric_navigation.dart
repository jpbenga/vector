import 'package:flutter/material.dart';
import '../theme/app_components.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import 'lector_workspace_navigation.dart';

/// Five equal destinations in a compact, rounded top navigation.
/// The public name is retained for consumers of the validated workspace shell.
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
    borderRadius: BorderRadius.circular(AppRadius.chip),
    clipBehavior: Clip.antiAlias,
    child: SizedBox(
      height: MediaQuery.textScalerOf(context).scale(10.5) > 13 ? 54 : 44,
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
      LectorWorkspaceSection.forMe => Icons.bolt_outlined,
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
        key: ValueKey('workspace-tab-${section.name}'),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        onTap: onPressed,
        child: DecoratedBox(
          key: selected ? ValueKey('workspace-selected-${section.name}') : null,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(AppRadius.chip),
            border: Border.all(
              color: selected ? accent : context.surfaces.border,
              width: selected ? 1.3 : .6,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final inline =
                  constraints.maxWidth >= 66 &&
                  MediaQuery.textScalerOf(context).scale(10.5) <= 13;
              final symbol = Icon(
                icon,
                size: constraints.maxWidth >= 100 ? 19 : 16,
                color:
                    selected ||
                        section == LectorWorkspaceSection.radar ||
                        section == LectorWorkspaceSection.generator
                    ? accent
                    : context.textColors.secondary,
              );
              final text = Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: constraints.maxWidth >= 100 ? 12 : 10.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? context.textColors.primary
                      : context.textColors.secondary,
                ),
              );
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: inline
                    ? Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [symbol, const SizedBox(width: 4), text],
                          ),
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          symbol,
                          const SizedBox(height: 2),
                          FittedBox(fit: BoxFit.scaleDown, child: text),
                        ],
                      ),
              );
            },
          ),
        ),
      ),
    );
  }
}
