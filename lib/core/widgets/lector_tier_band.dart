import 'package:flutter/material.dart';
import '../theme/app_components.dart';

class LectorTierBand extends StatelessWidget {
  const LectorTierBand({super.key, required this.color, required this.label});

  final Color? color;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final borderColor = context.surfaces.border;
    return Container(
      width: 24.0,
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: color ?? borderColor, width: 5),
          bottom: BorderSide(color: borderColor.withValues(alpha: 0.7)),
        ),
      ),
      alignment: Alignment.center,
      child: label == null
          ? const SizedBox.shrink()
          : Text(
              label!,
              maxLines: 1,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
    );
  }
}
