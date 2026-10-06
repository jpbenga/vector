import '../theme/app_components.dart';
import '../theme/app_radius.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme_controller.dart';
import '../theme/app_spacing.dart';
import 'lector_brand_mark.dart';

class LectorWorkspaceHeader extends StatelessWidget {
  const LectorWorkspaceHeader({
    required this.identity,
    required this.onOpenSettings,
    super.key,
  });
  final Widget identity;
  final VoidCallback onOpenSettings;
  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: SizedBox(
      height: 56,
      child: Row(
        children: [
          const LectorBrandMark(size: 34),
          const Spacer(),
          const LectorThemeToggleButton(),
          const SizedBox(width: AppSpacing.xs),
          identity,
          const SizedBox(width: AppSpacing.xs),
          IconButton(
            tooltip: 'Paramètres',
            onPressed: onOpenSettings,
            icon: const Icon(Icons.settings_outlined, size: 25),
          ),
        ],
      ),
    ),
  );
}

class LectorThemeToggleButton extends StatelessWidget {
  const LectorThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemeVariant>(
      valueListenable: appThemeController,
      builder: (context, variant, _) {
        final isLight = variant.isLight;
        return IconButton(
          tooltip: isLight ? 'Passer en thème sombre' : 'Passer en thème clair',
          onPressed: appThemeController.toggleBrightness,
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              );
            },
            child: Icon(
              isLight ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
              key: ValueKey(isLight),
              size: 24,
            ),
          ),
        );
      },
    );
  }
}

class LectorIdentityButton extends StatelessWidget {
  const LectorIdentityButton({
    super.key,
    this.label,
    this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final String? label;
  final IconData? icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        child: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.surfaces.backgroundSecondary.withValues(alpha: 0.64),
            border: Border.all(
              color: context.brand.accent.withValues(alpha: 0.72),
            ),
          ),
          child: label == null
              ? Icon(
                  icon ?? Icons.person_outline_rounded,
                  color: context.brand.accent,
                  size: 22,
                )
              : Text(
                  label!,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: context.textColors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
        ),
      ),
    );
  }
}
