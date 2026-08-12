import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_components.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme_controller.dart';

class ThemeVariantMenuButton extends StatefulWidget {
  const ThemeVariantMenuButton({super.key});

  @override
  State<ThemeVariantMenuButton> createState() => _ThemeVariantMenuButtonState();
}

class _ThemeVariantMenuButtonState extends State<ThemeVariantMenuButton> {
  OverlayEntry? _entry;

  @override
  void dispose() {
    _entry?.remove();
    _entry = null;
    super.dispose();
  }

  void _toggleMenu() {
    if (_entry != null) {
      _closeMenu();
      return;
    }

    final buttonBox = context.findRenderObject() as RenderBox?;
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (buttonBox == null || overlayBox == null) {
      return;
    }
    final buttonTopLeft = buttonBox.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    final anchor = buttonTopLeft & buttonBox.size;
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) {
        return _ThemeVariantOverlay(anchor: anchor, onClosed: _closeMenu);
      },
    );
    _entry = entry;
    overlay.insert(entry);
  }

  void _closeMenu() {
    _entry?.remove();
    _entry = null;
  }

  @override
  Widget build(BuildContext context) {
    final activeVariant = appThemeController.variant;

    return IconButton(
      tooltip: 'Changer de thème',
      onPressed: _toggleMenu,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: animation, child: child),
          );
        },
        child: Icon(activeVariant.icon, key: ValueKey(activeVariant)),
      ),
    );
  }
}

class _ThemeVariantOverlay extends StatefulWidget {
  const _ThemeVariantOverlay({required this.anchor, required this.onClosed});

  final Rect anchor;
  final VoidCallback onClosed;

  @override
  State<_ThemeVariantOverlay> createState() => _ThemeVariantOverlayState();
}

class _ThemeVariantOverlayState extends State<_ThemeVariantOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _spread;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 150),
    );
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _fade = curve;
    _spread = curve;
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss({AppThemeVariant? selectedVariant}) async {
    if (_controller.status != AnimationStatus.dismissed) {
      await _controller.reverse();
    }
    widget.onClosed();
    if (selectedVariant != null) {
      appThemeController.select(selectedVariant);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => _dismiss(),
          ),
        ),
        Positioned(
          top: widget.anchor.bottom + AppSpacing.xs,
          right: _panelRightOffset(context, widget.anchor),
          child: FadeTransition(
            opacity: _fade,
            child: AnimatedBuilder(
              animation: _spread,
              builder: (context, _) {
                return _ThemeVariantPanel(
                  spread: _spread.value,
                  onSelected: (variant) => _dismiss(selectedVariant: variant),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  double _panelRightOffset(BuildContext context, Rect anchor) {
    final width = MediaQuery.sizeOf(context).width;
    final right = width - anchor.right;
    return math.max(AppSpacing.sm, right);
  }
}

class _ThemeVariantPanel extends StatelessWidget {
  const _ThemeVariantPanel({required this.spread, required this.onSelected});

  final double spread;
  final ValueChanged<AppThemeVariant> onSelected;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final textColors = context.textColors;
    final activeVariant = appThemeController.variant;
    const size = 144.0;

    return Material(
      color: AppColors.transparent,
      child: Semantics(
        label: 'Sélecteur de thème',
        container: true,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: surfaces.surface.withValues(alpha: 0.74),
            border: Border.all(color: surfaces.border.withValues(alpha: 0.36)),
            boxShadow: [
              BoxShadow(
                color: surfaces.shadow.withValues(alpha: 0.16),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              _ThemeCenterBadge(variant: activeVariant),
              for (final entry in _radialItems.indexed)
                _RadialThemeButton(
                  variant: entry.$2,
                  angle: (-math.pi / 2) + (entry.$1 * math.pi / 2),
                  spread: spread,
                  isActive: entry.$2 == activeVariant,
                  onPressed: () => onSelected(entry.$2),
                ),
              Positioned(
                bottom: AppSpacing.xs,
                child: Text(
                  activeVariant.shortLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: textColors.secondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeCenterBadge extends StatelessWidget {
  const _ThemeCenterBadge({required this.variant});

  final AppThemeVariant variant;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: brand.accent.withValues(alpha: 0.10),
        border: Border.all(color: brand.accent.withValues(alpha: 0.54)),
        boxShadow: [
          BoxShadow(
            color: brand.accent.withValues(alpha: 0.08),
            blurRadius: 10,
          ),
        ],
      ),
      child: Icon(variant.icon, color: brand.accent, size: 20),
    );
  }
}

class _RadialThemeButton extends StatelessWidget {
  const _RadialThemeButton({
    required this.variant,
    required this.angle,
    required this.spread,
    required this.isActive,
    required this.onPressed,
  });

  final AppThemeVariant variant;
  final double angle;
  final double spread;
  final bool isActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final surfaces = context.surfaces;
    final textColors = context.textColors;
    const radius = 48.0;
    const buttonSize = 34.0;
    final x = math.cos(angle) * radius * spread;
    final y = math.sin(angle) * radius * spread;

    return Transform.translate(
      offset: Offset(x, y),
      child: Semantics(
        button: true,
        label: variant.label,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.chip),
          onTap: onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? brand.accent.withValues(alpha: 0.14)
                  : surfaces.backgroundSecondary.withValues(alpha: 0.82),
              border: Border.all(
                color: isActive
                    ? brand.accent.withValues(alpha: 0.9)
                    : surfaces.border.withValues(alpha: 0.62),
              ),
            ),
            child: Icon(
              variant.icon,
              size: 17,
              color: isActive ? brand.accent : textColors.secondary,
            ),
          ),
        ),
      ),
    );
  }
}

const _radialItems = [
  AppThemeVariant.vectorDark,
  AppThemeVariant.gold,
  AppThemeVariant.aurora,
  AppThemeVariant.vectorLight,
];
