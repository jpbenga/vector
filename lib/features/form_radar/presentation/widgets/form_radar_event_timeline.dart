import 'package:flutter/material.dart';

import '../../../../core/theme/app_components.dart';

enum FormRadarTimelineEventKind { goal, assist }

class FormRadarTimelineEvent {
  const FormRadarTimelineEvent({
    required this.minute,
    required this.kind,
    required this.label,
  });

  final int minute;
  final FormRadarTimelineEventKind kind;
  final String label;
}

/// Shared match-event timeline for Player and Team Form Radar details.
class FormRadarEventTimeline extends StatelessWidget {
  const FormRadarEventTimeline({
    required this.events,
    this.endMinute = 90,
    super.key,
  });

  final List<FormRadarTimelineEvent> events;
  final int endMinute;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const side = 12.0;
      final lineWidth = constraints.maxWidth - side * 2;
      return SizedBox(
        height: 98,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: side,
              right: side,
              top: 38,
              child: Container(height: 2, color: context.surfaces.border),
            ),
            _endpoint(context, left: side - 4, label: '0′'),
            _endpoint(
              context,
              left: side + lineWidth - 8,
              label: '$endMinute′',
            ),
            if (endMinute >= 45)
              Positioned(
                left: side + lineWidth * .5 - 14,
                top: 27,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.surfaces.background,
                    border: Border.all(color: context.surfaces.border),
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox(
                    width: 28,
                    height: 28,
                    child: Center(child: Text('MT')),
                  ),
                ),
              ),
            for (final event in events)
              _event(
                context,
                event,
                side +
                    lineWidth * (event.minute.clamp(0, endMinute) / endMinute),
              ),
          ],
        ),
      );
    },
  );

  Widget _endpoint(
    BuildContext context, {
    required double left,
    required String label,
  }) => Positioned(
    left: left,
    top: 15,
    child: Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: context.textColors.secondary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 11),
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: context.surfaces.background,
            border: Border.all(color: context.textColors.secondary, width: 2),
            shape: BoxShape.circle,
          ),
        ),
      ],
    ),
  );

  Widget _event(
    BuildContext context,
    FormRadarTimelineEvent event,
    double position,
  ) => Positioned(
    left: position - 40,
    top: 0,
    width: 80,
    child: Column(
      children: [
        Icon(
          event.kind == FormRadarTimelineEventKind.goal
              ? Icons.sports_soccer_rounded
              : Icons.assistant_rounded,
          size: 19,
          color: context.semantic.success,
        ),
        const SizedBox(height: 8),
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: context.surfaces.background,
            border: Border.all(color: context.semantic.success, width: 2),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '${event.minute}′',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: context.textColors.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          event.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: context.textColors.secondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}
