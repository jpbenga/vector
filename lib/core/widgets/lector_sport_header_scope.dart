import 'package:flutter/material.dart';

/// Sport routing stays in the shell; account/settings stay in each workspace.
class LectorSportHeaderScope extends InheritedWidget {
  const LectorSportHeaderScope({
    required this.sportSelector,
    required this.shortlistAction,
    required super.child,
    super.key,
  });
  final Widget sportSelector, shortlistAction;
  static LectorSportHeaderScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LectorSportHeaderScope>();
  @override
  bool updateShouldNotify(LectorSportHeaderScope oldWidget) =>
      oldWidget.sportSelector != sportSelector ||
      oldWidget.shortlistAction != shortlistAction;
}
