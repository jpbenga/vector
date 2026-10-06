import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/sports/sport_workspace_registry.dart';
import '../../../core/sports/domain/sport.dart';
import '../../../core/sports/domain/sport_module.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_components.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/lector_responsive_layout.dart';

/// One account and design system, independent discipline workspaces.
class SportWorkspacePage extends StatelessWidget {
  const SportWorkspacePage({required this.sport, this.registry, super.key});
  final SportId sport;
  final SportWorkspaceRegistry? registry;

  @override
  Widget build(BuildContext context) {
    final workspaces = registry ?? SportWorkspaceRegistry.defaults;
    final entry = workspaces.find(sport.key)!;
    final availableSports = workspaces.entries.where(
      (entry) => entry.definition.stage != SportModuleStage.planned,
    );
    return Scaffold(
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: LectorContent(
              maxWidth: 544,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: PopupMenuButton<SportId>(
                    key: const ValueKey('sport-selector'),
                    tooltip: 'Choisir un sport',
                    position: PopupMenuPosition.under,
                    offset: const Offset(0, 4),
                    menuPadding: const EdgeInsets.symmetric(vertical: 4),
                    constraints: const BoxConstraints(
                      minWidth: 236,
                      maxWidth: 236,
                      maxHeight: 372,
                    ),
                    color: context.surfaces.surface,
                    surfaceTintColor: AppColors.transparent,
                    elevation: 8,
                    shadowColor: context.surfaces.shadow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.input),
                      side: BorderSide(
                        color: context.surfaces.border.withValues(alpha: .6),
                      ),
                    ),
                    onSelected: (selected) {
                      if (selected == sport) {
                        return;
                      }
                      context.go(
                        selected == SportId.football
                            ? '/'
                            : '/sports/${selected.key}',
                      );
                    },
                    itemBuilder: (_) => [
                      for (final (index, available)
                          in availableSports.indexed) ...[
                        if (index > 0)
                          PopupMenuDivider(
                            height: 1,
                            thickness: 1,
                            indent: 16,
                            endIndent: 16,
                            color: context.surfaces.border.withValues(
                              alpha: .3,
                            ),
                          ),
                        PopupMenuItem(
                          key: ValueKey(
                            'sport-option:${available.definition.sport.key}',
                          ),
                          value: available.definition.sport,
                          height: 52,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Semantics(
                            selected: available.definition.sport == sport,
                            child: Row(
                              children: [
                                Icon(
                                  available.icon,
                                  size: 21,
                                  color: available.definition.sport == sport
                                      ? context.brand.accent
                                      : context.textColors.primary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    available.definition.sport.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          color: context.textColors.primary,
                                        ),
                                  ),
                                ),
                                if (available.definition.sport == sport) ...[
                                  const SizedBox(width: 12),
                                  Icon(
                                    Icons.check_rounded,
                                    size: 19,
                                    color: context.brand.accent,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            entry.icon,
                            size: 20,
                            color: context.brand.accent,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            sport.label,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const Icon(Icons.expand_more_rounded, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: KeyedSubtree(
              key: ValueKey('sport-body:${sport.key}'),
              child: entry.builder(context),
            ),
          ),
        ],
      ),
    );
  }
}
