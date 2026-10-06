import 'package:flutter/material.dart';
import '../theme/app_components.dart';

/// Result colors and foreground contrast shared by all disciplines.
class LectorResultBadge extends StatelessWidget {
  const LectorResultBadge({required this.result, this.size = 21, super.key});
  final String result;
  final double size;
  @override
  Widget build(BuildContext context) {
    final value = result.toUpperCase();
    final win = value == 'W' || value == 'V',
        loss = value == 'L' || value == 'P';
    final draw = value == 'D' || value == 'N';
    final color = win
        ? context.semantic.success
        : loss
        ? context.semantic.error
        : draw
        ? context.textColors.secondary
        : context.surfaces.border;
    final foreground = win
        ? context.semantic.onSuccess
        : loss
        ? context.semantic.onError
        : draw
        ? context.semantic.onNeutral
        : context.textColors.primary;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: Text(
        win
            ? 'V'
            : loss
            ? 'D'
            : draw
            ? 'N'
            : '-',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foreground,
          fontSize: size < 23 ? 9 : 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
