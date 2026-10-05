import 'package:flutter/material.dart';
import '../theme/app_components.dart';
import '../theme/app_radius.dart';

class LectorSignalPanel extends StatelessWidget {
  const LectorSignalPanel({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.surfaces.background.withValues(alpha: .45),
      border: Border.all(color: context.surfaces.border),
      borderRadius: BorderRadius.circular(AppRadius.control),
    ),
    child: Padding(padding: const EdgeInsets.all(9), child: child),
  );
}
