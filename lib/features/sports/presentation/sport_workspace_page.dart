import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/view/copilot_flow_page.dart';
import '../../../core/sports/domain/sport.dart';
import '../../../core/sports/domain/sport_module.dart';
import '../../../core/theme/app_components.dart';
import '../../../core/widgets/lector_responsive_layout.dart';
import '../../hockey/presentation/hockey_workspace.dart';
import '../domain/sport_module_registry.dart';

/// One account and design system, independent discipline workspaces.
class SportWorkspacePage extends StatelessWidget {
  const SportWorkspacePage({required this.sport, super.key});
  final SportId sport;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        SafeArea(
          bottom: false,
          child: LectorContent(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: PopupMenuButton<SportId>(
                  key: const ValueKey('sport-selector'),
                  tooltip: 'Choisir un sport',
                  initialValue: sport,
                  onSelected: (selected) => context.go(
                    selected == SportId.football
                        ? '/'
                        : '/sports/${selected.key}',
                  ),
                  itemBuilder: (_) => [
                    for (final module in SportModuleRegistry.modules)
                      PopupMenuItem(
                        value: module.sport,
                        enabled: module.stage != SportModuleStage.planned,
                        child: Text(
                          '${module.sport.label}'
                          '${switch (module.stage) {
                            SportModuleStage.active => '',
                            SportModuleStage.preparation => ' · En préparation',
                            SportModuleStage.planned => ' · À venir',
                          }}',
                        ),
                      ),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          sport == SportId.football
                              ? Icons.sports_soccer_rounded
                              : Icons.sports_hockey_rounded,
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
          child: sport == SportId.football
              ? const CopilotFlowPage()
              : HockeyWorkspace(sport: sport),
        ),
      ],
    ),
  );
}
