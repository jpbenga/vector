import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/theme/app_components.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_theme_controller.dart';
import '../../../core/widgets/lector_brand_mark.dart';
import '../../../core/widgets/lector_responsive_layout.dart';
import 'appearance_preview.dart';
import 'appearance_theme_catalog.dart';

class AppearancePage extends StatefulWidget {
  const AppearancePage({this.controller, super.key});
  final AppThemeController? controller;

  @override
  State<AppearancePage> createState() => _AppearancePageState();
}

class _AppearancePageState extends State<AppearancePage> {
  final _scrollController = ScrollController();
  AppearanceThemeFamily _family = AppearanceThemeFamily.all;
  AppearancePreviewKind _preview = AppearancePreviewKind.overview;
  AppThemeController get _controller => widget.controller ?? appThemeController;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _select(AppThemeVariant variant) {
    _controller.select(variant);
    // On mobile the palette sits below the preview. Bring the result into view.
    if (_scrollController.hasClients && _scrollController.offset > 120) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _scrollController.jumpTo(0);
      } else {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<AppThemeVariant>(
    valueListenable: _controller,
    builder: (context, active, _) => Theme(
      data: AppTheme.forVariant(active),
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: context.surfaces.background,
          appBar: AppBar(
            title: const Text('Apparence'),
            leading: IconButton(
              tooltip: 'Retour',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          body: SafeArea(
            top: false,
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: LectorLayout.workspaceWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Votre Lector, à votre image.',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Comparez les thèmes sur des cartes, des lectures et des données comme dans l’application.',
                        style: TextStyle(color: context.textColors.secondary),
                      ),
                      const SizedBox(height: 20),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final preview = _buildPreview(context, active);
                          final choices = _buildChoices(context, active);
                          if (constraints.maxWidth >= 840) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 6, child: preview),
                                const SizedBox(width: 24),
                                Expanded(flex: 5, child: choices),
                              ],
                            );
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              preview,
                              const SizedBox(height: 24),
                              choices,
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      AppearancePreviewPanel(
                        child: Wrap(
                          spacing: 16,
                          runSpacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Le thème s’applique immédiatement et reste mémorisé.',
                              style: TextStyle(
                                color: context.textColors.secondary,
                              ),
                            ),
                            OutlinedButton.icon(
                              key: const ValueKey('appearance-reset'),
                              onPressed: () {
                                setState(
                                  () => _family = AppearanceThemeFamily.all,
                                );
                                _select(AppThemeVariant.vectorDark);
                              },
                              icon: const Icon(
                                Icons.restart_alt_rounded,
                                size: 18,
                              ),
                              label: const Text('Réinitialiser'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildPreview(BuildContext context, AppThemeVariant active) {
    final variants = AppThemeVariant.values.where(_family.includes).toList();
    void cycle(int delta) {
      final current = variants.indexOf(active);
      final next = current < 0
          ? (delta > 0 ? 0 : variants.length - 1)
          : (current + delta) % variants.length;
      _select(variants[next]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(active.icon, color: context.brand.accent, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                active.appearanceLabel,
                key: const ValueKey('appearance-active-theme'),
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              tooltip: 'Thème précédent',
              onPressed: () => cycle(-1),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            IconButton(
              tooltip: 'Thème suivant',
              onPressed: () => cycle(1),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Données d’exemple · Aperçu visuel',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: context.textColors.secondary),
        ),
        const SizedBox(height: 10),
        AppearancePreviewPanel(
          key: const ValueKey('appearance-live-preview'),
          child: MediaQuery.disableAnimationsOf(context)
              ? AppearancePreview(kind: _preview)
              : AnimatedSize(
                  alignment: Alignment.topCenter,
                  duration: const Duration(milliseconds: 180),
                  child: AppearancePreview(kind: _preview),
                ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final kind in AppearancePreviewKind.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    key: ValueKey('appearance-preview-${kind.name}'),
                    label: Text(kind.label),
                    selected: _preview == kind,
                    onSelected: (_) => setState(() => _preview = kind),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChoices(BuildContext context, AppThemeVariant active) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Choisir un thème',
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 6),
      Text(
        'Une ambiance, les mêmes informations.',
        style: TextStyle(color: context.textColors.secondary),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final family in AppearanceThemeFamily.values)
            ChoiceChip(
              key: ValueKey('appearance-family-${family.name}'),
              label: Text(family.label),
              selected: _family == family,
              onSelected: (_) => setState(() => _family = family),
            ),
        ],
      ),
      const SizedBox(height: 14),
      LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 620
              ? 3
              : constraints.maxWidth < 270
              ? 1
              : 2;
          final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
          return Wrap(
            spacing: 12,
            runSpacing: 14,
            children: [
              for (final variant in AppThemeVariant.values.where(
                _family.includes,
              ))
                SizedBox(
                  width: width,
                  child: _ThemeChoice(
                    key: ValueKey('appearance-theme-${variant.name}'),
                    variant: variant,
                    selected: variant == active,
                    onTap: () => _select(variant),
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );
}

class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice({
    required this.variant,
    required this.selected,
    required this.onTap,
    super.key,
  });
  final AppThemeVariant variant;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: '${variant.appearanceLabel}, ${variant.appearanceDescription}',
    child: Material(
      color: context.surfaces.background,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Theme(
                data: AppTheme.forVariant(variant),
                child: _ThemeThumbnail(
                  selected: selected,
                  key: ValueKey('appearance-theme-preview-${variant.name}'),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selected) ...[
                    Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: context.brand.accent,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      variant.appearanceLabel,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                variant.appearanceDescription,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.textColors.secondary,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// A compact, legible sample of the actual palette, not a loading skeleton.
class _ThemeThumbnail extends StatelessWidget {
  const _ThemeThumbnail({required this.selected, super.key});
  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
    height: 92,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: context.surfaces.background,
      border: Border.all(
        color: selected ? context.brand.accent : context.surfaces.border,
        width: selected ? 2 : 1,
      ),
      borderRadius: BorderRadius.circular(AppRadius.card),
      boxShadow: [
        BoxShadow(
          color: context.surfaces.shadow.withValues(alpha: .12),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const LectorBrandMark(size: 22),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Lector',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: context.textColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: context.surfaces.surface,
              borderRadius: BorderRadius.circular(AppRadius.odds),
              border: Border.all(color: context.surfaces.border),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.bar_chart_rounded,
                  color: context.brand.accent,
                  size: 16,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Radar',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: context.textColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                for (final color in [
                  context.semantic.success,
                  context.textColors.secondary,
                  context.semantic.error,
                ])
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.only(left: 3),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
