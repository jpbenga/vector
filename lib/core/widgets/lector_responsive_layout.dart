import 'package:flutter/material.dart';

/// Shared content widths, independent of the platform or device model.
abstract final class LectorLayout {
  static const readingWidth = 760.0;
  static const workspaceWidth = 1120.0;
  static const twoColumnBreakpoint = 820.0;
}

/// Keeps the page background full width and the content readable.
/// Pass a scrollable child to keep its height bounded by the viewport.
class LectorContent extends StatelessWidget {
  const LectorContent({
    required this.child,
    this.maxWidth = LectorLayout.readingWidth,
    super.key,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    heightFactor: 1,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: SizedBox(width: double.infinity, child: child),
    ),
  );
}

/// Cards keep their natural height; labels can wrap at larger text sizes.
class LectorAdaptiveCards extends StatelessWidget {
  const LectorAdaptiveCards({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final largeText = MediaQuery.textScalerOf(context).scale(16) > 22;
      final columns =
          constraints.maxWidth >= LectorLayout.twoColumnBreakpoint && !largeText
          ? 2
          : 1;
      const gap = 12.0;
      final width = (constraints.maxWidth - (columns - 1) * gap) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}
