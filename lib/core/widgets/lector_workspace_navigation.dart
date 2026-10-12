import 'package:flutter/material.dart';
import 'lector_geometric_navigation.dart';

enum LectorWorkspaceSection { forMe, radar, all, generator, bilan }

/// Stable navigation contract; presentation shared across all sports.
class LectorWorkspaceNavigation extends StatelessWidget {
  const LectorWorkspaceNavigation({
    super.key,
    required this.selected,
    required this.onChanged,
  });
  final LectorWorkspaceSection selected;
  final ValueChanged<LectorWorkspaceSection> onChanged;
  @override
  Widget build(BuildContext context) => LectorGeometricNavigation(
    key: const ValueKey('home-primary-navigation'),
    selected: selected,
    onChanged: onChanged,
  );
}
