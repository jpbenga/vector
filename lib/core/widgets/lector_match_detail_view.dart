import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_components.dart';
import '../theme/app_radius.dart';
import 'lector_responsive_layout.dart';

/// Both sports use this page, tab state and scroll/navigation structure.
/// Modules provide factual content, never an alternative page layout.
class LectorMatchDetailView extends StatefulWidget {
  const LectorMatchDetailView({
    required this.hero,
    required this.synthesis,
    required this.tabBuilder,
    this.bottomNavigationBar,
    this.overlay,
    this.stats,
    this.openStats = false,
    super.key,
  });
  final Widget hero, synthesis;
  final Widget Function(BuildContext, int) tabBuilder;
  final Widget? bottomNavigationBar, overlay, stats;
  final bool openStats;
  @override
  State<LectorMatchDetailView> createState() => _LectorMatchDetailViewState();
}

class _LectorMatchDetailViewState extends State<LectorMatchDetailView> {
  int _selected = 0;
  bool _userSelected = false;
  @override
  void initState() {
    super.initState();
    if (widget.openStats && widget.stats != null) _selected = -1;
  }

  @override
  void didUpdateWidget(covariant LectorMatchDetailView old) {
    super.didUpdateWidget(old);
    if (!_userSelected &&
        widget.openStats &&
        !old.openStats &&
        widget.stats != null) {
      _selected = -1;
    }
    if (_selected == -1 && widget.stats == null) _selected = 0;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.surfaces.background,
    bottomNavigationBar: widget.bottomNavigationBar,
    body: Stack(
      children: [
        const Positioned.fill(child: LectorMatchBackground()),
        SafeArea(
          child: LectorContent(
            maxWidth: LectorLayout.workspaceWidth,
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
                  sliver: SliverList.list(
                    children: [
                      LectorMatchTopBar(
                        onBack: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(height: 10),
                      widget.hero,
                      const SizedBox(height: 12),
                      widget.synthesis,
                      const SizedBox(height: 12),
                      LectorMatchTabBar(
                        selectedIndex: _selected,
                        hasStats: widget.stats != null,
                        onSelected: (index) => setState(() {
                          _selected = index;
                          _userSelected = true;
                        }),
                      ),
                      const SizedBox(height: 10),
                      if (_selected == -1)
                        widget.stats!
                      else
                        widget.tabBuilder(context, _selected),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.overlay != null)
          Positioned(
            left: 14,
            bottom: 16 + MediaQuery.paddingOf(context).bottom,
            child: widget.overlay!,
          ),
      ],
    ),
  );
}

class LectorMatchBackground extends StatelessWidget {
  const LectorMatchBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final brand = context.brand;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            surfaces.shadow.withValues(alpha: 0.94),
            surfaces.background,
            surfaces.backgroundSecondary,
          ],
        ),
      ),
      child: CustomPaint(
        painter: _LectorStadiumPainter(
          accent: brand.accent,
          border: surfaces.border,
          shadow: surfaces.shadow,
        ),
      ),
    );
  }
}

class _LectorStadiumPainter extends CustomPainter {
  const _LectorStadiumPainter({
    required this.accent,
    required this.border,
    required this.shadow,
  });

  final Color accent;
  final Color border;
  final Color shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.78),
        radius: 0.86,
        colors: [accent.withValues(alpha: 0.13), AppColors.transparent],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, glow);

    final standTop = size.height * 0.18;
    final standBottom = size.height * 0.38;
    final standPaint = Paint()..color = border.withValues(alpha: 0.22);
    final standPath = Path()
      ..moveTo(0, standTop + 44)
      ..quadraticBezierTo(
        size.width * 0.5,
        standTop - 12,
        size.width,
        standTop + 44,
      )
      ..lineTo(size.width, standBottom)
      ..quadraticBezierTo(size.width * 0.5, standBottom + 24, 0, standBottom)
      ..close();
    canvas.drawPath(standPath, standPaint);

    final linePaint = Paint()
      ..color = border.withValues(alpha: 0.26)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < 6; i++) {
      final y = standTop + 46 + i * 18;
      final path = Path()
        ..moveTo(0, y)
        ..quadraticBezierTo(size.width * 0.5, y - 26, size.width, y);
      canvas.drawPath(path, linePaint);
    }

    final pitchTop = size.height * 0.36;
    final pitchPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accent.withValues(alpha: 0.12),
          shadow.withValues(alpha: 0.18),
          AppColors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, pitchTop, size.width, size.height));
    canvas.drawRect(
      Rect.fromLTWH(0, pitchTop, size.width, size.height - pitchTop),
      pitchPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _LectorStadiumPainter oldDelegate) {
    return accent != oldDelegate.accent ||
        border != oldDelegate.border ||
        shadow != oldDelegate.shadow;
  }
}

class LectorMatchTopBar extends StatelessWidget {
  const LectorMatchTopBar({required this.onBack, super.key});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final textColors = context.textColors;
    final brand = context.brand;

    return Row(
      children: [
        IconButton(
          tooltip: 'Retour',
          onPressed: onBack,
          icon: Icon(
            Icons.arrow_back_rounded,
            color: textColors.primary,
            size: 27,
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Notifications',
          onPressed: () => ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Alertes à brancher'))),
          icon: Icon(
            Icons.notifications_none_rounded,
            color: textColors.primary,
            size: 24,
          ),
        ),
        IconButton(
          tooltip: 'Favori',
          onPressed: () => ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Favori à brancher'))),
          icon: Icon(Icons.star_rounded, color: brand.accent, size: 28),
        ),
      ],
    );
  }
}

class LectorMatchTabBar extends StatelessWidget {
  const LectorMatchTabBar({
    required this.selectedIndex,
    required this.onSelected,
    this.hasStats = false,
    super.key,
  });

  final int selectedIndex;
  final bool hasStats;
  final ValueChanged<int> onSelected;

  Map<int, String> get _tabs => {
    0: 'Contexte',
    if (hasStats) -1: 'Stats',
    1: 'Classement',
    2: 'Forme',
    3: 'TAT',
  };

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaces.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: SizedBox(
        height: 52,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final minimumWidth =
                100 * MediaQuery.textScalerOf(context).scale(1);
            final width = constraints.maxWidth / _tabs.length;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final index in _tabs.keys)
                    SizedBox(
                      width: width < minimumWidth ? minimumWidth : width,
                      child: _LectorMatchTab(
                        label: _tabs[index]!,
                        isSelected: selectedIndex == index,
                        onPressed: () => onSelected(index),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LectorMatchTab extends StatelessWidget {
  const _LectorMatchTab({
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = context.brand;
    final textColors = context.textColors;

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: Center(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: isSelected ? brand.accent : textColors.primary,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 3,
            width: isSelected ? 58 : 0,
            decoration: BoxDecoration(
              color: brand.accent,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ),
    );
  }
}
