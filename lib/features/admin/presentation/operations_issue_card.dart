import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_components.dart';
import '../../../core/theme/app_radius.dart';
import '../domain/operations_issue.dart';

class OperationsIssueCard extends StatelessWidget {
  const OperationsIssueCard({
    super.key,
    required this.message,
    this.adminRequest = false,
    this.onReconnect,
    this.heading,
  });
  final String message;
  final bool adminRequest;
  final VoidCallback? onReconnect;
  final String? heading;
  @override
  Widget build(BuildContext context) {
    final issue = explainOperationsIssue(message, adminRequest: adminRequest);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: context.semantic.error.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.odds),
      ),
      child: Material(
        color: AppColors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${heading == null ? '' : '$heading · '}${issue.title}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: context.semantic.error,
              ),
            ),
            const SizedBox(height: 6),
            Text(issue.reason),
            const SizedBox(height: 8),
            Text('Que faire ? ${issue.action}'),
            if (issue.reconnect && onReconnect != null)
              TextButton.icon(
                onPressed: onReconnect,
                icon: const Icon(Icons.login),
                label: const Text('Se reconnecter'),
              ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              title: const Text(
                'Détail technique',
                style: TextStyle(fontSize: 12),
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(
                    message.isEmpty ? 'Aucun détail transmis.' : message,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
