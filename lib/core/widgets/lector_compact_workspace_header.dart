import 'package:flutter/material.dart';
import '../theme/app_components.dart';
import 'lector_brand_mark.dart';
import 'lector_shortlist_icon.dart';

/// Compact header slots retain the existing sport, account and settings actions.
class LectorCompactWorkspaceHeader extends StatelessWidget {
  const LectorCompactWorkspaceHeader({
    required this.sportSelector,
    required this.identity,
    required this.onOpenShortlist,
    required this.onOpenSettings,
    this.shortlistCount = 0,
    this.shortlistAction,
    this.settingsAction,
    super.key,
  });
  final Widget sportSelector, identity;
  final Widget? shortlistAction, settingsAction;
  final int shortlistCount;
  final VoidCallback onOpenShortlist, onOpenSettings;
  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        height: 48,
        child: Row(
          children: [
            const LectorBrandMark(size: 30),
            const SizedBox(width: 6),
            SizedBox(
              width: 112,
              child: FittedBox(fit: BoxFit.scaleDown, child: sportSelector),
            ),
            const Spacer(),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: (constraints.maxWidth - 239).clamp(44.0, 240.0),
              ),
              child:
                  shortlistAction ??
                  Tooltip(
                    message: shortlistCount == 0
                        ? 'Ma Shortlist'
                        : 'Ma Shortlist : $shortlistCount rencontres',
                    child: TextButton(
                      onPressed: onOpenShortlist,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(44, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          LectorShortlistIcon(color: context.semantic.info),
                          if (shortlistCount > 0) ...[
                            const SizedBox(width: 3),
                            Text(
                              '$shortlistCount',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: context.semantic.info,
                              ),
                            ),
                          ],
                          if (constraints.maxWidth >= 350) ...[
                            const SizedBox(width: 5),
                            Text(
                              'Shortlist',
                              style: TextStyle(
                                fontSize: 11,
                                color: context.semantic.info,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
            ),
            const SizedBox(width: 3),
            SizedBox.square(dimension: 44, child: FittedBox(child: identity)),
            SizedBox.square(
              dimension: 44,
              child:
                  settingsAction ??
                  IconButton(
                    tooltip: 'Paramètres',
                    onPressed: onOpenSettings,
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    icon: const Icon(Icons.settings_outlined, size: 22),
                  ),
            ),
          ],
        ),
      ),
    ),
  );
}
