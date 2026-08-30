import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_components.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';

class CopilotCalendar extends StatefulWidget {
  const CopilotCalendar({
    required this.selectedDate,
    required this.onDateSelected,
    this.visibleWindowDays = 15,
    this.onChooseDate,
    super.key,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final int visibleWindowDays;
  final VoidCallback? onChooseDate;

  @override
  State<CopilotCalendar> createState() => _CopilotCalendarState();
}

class _CopilotCalendarState extends State<CopilotCalendar> {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerToday());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = _dayOnly(DateTime.now());
    final selectedDay = _dayOnly(widget.selectedDate);
    final halfWindow = widget.visibleWindowDays ~/ 2;
    final dates = [
      for (var offset = -halfWindow; offset <= halfWindow; offset++)
        DateTime(selectedDay.year, selectedDay.month, selectedDay.day + offset),
    ];

    return SizedBox(
      height: 54,
      child: Row(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const separatorWidth = 1.0;
                final tileWidth =
                    ((constraints.maxWidth - (separatorWidth * 6)) / 7).clamp(
                      30.0,
                      74.0,
                    );

                return ListView.separated(
                  controller: _controller,
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.zero,
                  itemCount: dates.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: separatorWidth),
                  itemBuilder: (context, index) {
                    final date = dates[index];
                    return SizedBox(
                      width: tileWidth,
                      child: _CopilotCalendarDay(
                        date: date,
                        today: today,
                        isSelected: _isSameDay(date, widget.selectedDate),
                        onTap: () => widget.onDateSelected(date),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (widget.onChooseDate != null) ...[
            const SizedBox(width: AppSpacing.xs),
            _CalendarIconButton(onPressed: widget.onChooseDate!),
          ],
        ],
      ),
    );
  }

  void _centerToday() {
    if (!_controller.hasClients) {
      return;
    }

    final maxScroll = _controller.position.maxScrollExtent;
    _controller.jumpTo(maxScroll / 2);
  }

  DateTime _dayOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _CopilotCalendarDay extends StatelessWidget {
  const _CopilotCalendarDay({
    required this.date,
    required this.today,
    required this.isSelected,
    required this.onTap,
  });

  final DateTime date;
  final DateTime today;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isToday = _isSameDay(date, today);
    final textColor = isSelected || isToday
        ? context.brand.accent
        : context.textColors.secondary;

    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        child: Padding(
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isToday ? 'AUJ' : _weekday(date),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: textColor,
                  fontWeight: isSelected || isToday
                      ? FontWeight.w900
                      : FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              FractionallySizedBox(
                widthFactor: isSelected || isToday ? 0.58 : 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 2,
                  decoration: BoxDecoration(
                    color: context.brand.accent,
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _weekday(DateTime date) {
    return switch (date.weekday) {
      DateTime.monday => 'LU',
      DateTime.tuesday => 'MA',
      DateTime.wednesday => 'ME',
      DateTime.thursday => 'JE',
      DateTime.friday => 'VE',
      DateTime.saturday => 'SA',
      DateTime.sunday => 'DI',
      _ => '',
    };
  }
}

class _CalendarIconButton extends StatelessWidget {
  const _CalendarIconButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.outlined(
      tooltip: 'Choisir une date',
      onPressed: onPressed,
      icon: const Icon(Icons.calendar_today_rounded, size: 16),
      color: Theme.of(context).colorScheme.onSurface,
      constraints: const BoxConstraints.tightFor(width: 34, height: 38),
      padding: EdgeInsets.zero,
    );
  }
}
