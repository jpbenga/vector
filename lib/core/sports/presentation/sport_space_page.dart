import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../theme/app_components.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme_controller.dart';
import '../../widgets/lector_responsive_layout.dart';
import '../../widgets/lector_space_widgets.dart';
import '../../../features/appearance/presentation/appearance_page.dart';
import '../domain/sport_reading_preferences.dart';

/// The sport workspace opens this menu each time, never its last subpage.
/// Preferences stay owned by the workspace's identity and discipline.
class SportSpacePage extends StatelessWidget {
  const SportSpacePage({
    required this.preferences,
    required this.onOpenCompetitions,
    required this.onOpenReadings,
    required this.onOpenAccount,
    super.key,
  });
  final ValueListenable<SportReadingPreferences> preferences;
  final VoidCallback onOpenCompetitions, onOpenReadings, onOpenAccount;

  void _appearance(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const AppearancePage()));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.surfaces.background,
    body: SafeArea(
      child: ValueListenableBuilder<SportReadingPreferences>(
        valueListenable: preferences,
        builder: (context, selected, _) => LectorContent(
          maxWidth: LectorLayout.workspaceWidth,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
            children: [
              LectorSpaceHeader(onSettings: () => _appearance(context)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Gérez votre compte et personnalisez votre expérience Lector.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.textColors.secondary,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              LectorSpaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Votre Lector · ${selected.sport.label}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '${selected.competitionKeys.length} compétition(s) · '
                      '${selected.readingIds.length} lecture(s)',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Text('Chaque sport possède ses propres préférences.'),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Préférences enregistrées sur cet appareil',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.textColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const LectorSpaceSectionHeading(
                title: 'Personnaliser Lector',
                subtitle:
                    'Choisissez votre apparence et les informations que vous souhaitez suivre.',
              ),
              const SizedBox(height: AppSpacing.xs),
              LectorAdaptiveCards(
                children: [
                  LectorSpaceActionCard(
                    icon: Icons.palette_outlined,
                    title: 'Apparence',
                    subtitle: 'Comparez les thèmes sur un aperçu de Lector.',
                    count: AppThemeVariant.values.length,
                    color: context.brand.accent,
                    onTap: () => _appearance(context),
                  ),
                  LectorSpaceActionCard(
                    key: const ValueKey('sport-space-competitions'),
                    icon: Icons.emoji_events_outlined,
                    title: 'Mes compétitions',
                    subtitle:
                        'Choisissez les championnats ${selected.sport.label.toLowerCase()} que vous souhaitez suivre.',
                    count: selected.competitionKeys.length,
                    color: context.brand.accent,
                    onTap: onOpenCompetitions,
                  ),
                  LectorSpaceActionCard(
                    key: const ValueKey('sport-space-readings'),
                    icon: Icons.auto_graph_rounded,
                    title: 'Mes lectures',
                    subtitle:
                        'Choisissez les faits sportifs qui doivent retenir votre attention.',
                    count: selected.readingIds.length,
                    color: context.semantic.info,
                    onTap: onOpenReadings,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const LectorSpaceSectionHeading(title: 'Mon compte'),
              const SizedBox(height: AppSpacing.xs),
              LectorSpaceActionCard(
                icon: Icons.person_outline_rounded,
                title: 'Compte et connexion',
                subtitle: 'Accédez à votre compte Lector.',
                count: 0,
                color: context.brand.accent,
                onTap: onOpenAccount,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
