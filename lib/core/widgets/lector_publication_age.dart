import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Publication time is distinct from the live score and quote observation time.
class LectorPublicationAge extends StatelessWidget {
  const LectorPublicationAge({required this.capturedAt, super.key});
  final DateTime capturedAt;

  @override
  Widget build(BuildContext context) {
    final age = DateTime.now().toUtc().difference(capturedAt.toUtc());
    final elapsed = age.isNegative
        ? 'horodatage à vérifier'
        : age.inHours > 0
        ? 'il y a ${age.inHours} h'
        : 'il y a ${age.inMinutes} min';
    return Tooltip(
      message:
          'Publication sportive $elapsed. Les scores live et les cotes ont leur propre horodatage.',
      child: Text(
        'Publication · ${DateFormat('dd/MM · HH:mm').format(capturedAt.toLocal())}',
        key: const ValueKey('publication-age'),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
