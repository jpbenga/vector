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
    final halfWindow = widget.visibleWindowDays ~/ 2;
    final dates = [
      for (var offset = -halfWindow; offset <= halfWindow; offset++)
        DateTime(today.year, today.month, today.day + offset),
    ];

    return SizedBox(
      height: 94,
      child: Row(
        children: [
          _CalendarArrowButton(
            icon: Icons.chevron_left_rounded,
            onPressed: () => _scrollByVisibleDays(-3),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const separatorWidth = 2.0;
                final tileWidth =
                    ((constraints.maxWidth - (separatorWidth * 6)) / 7).clamp(
                      34.0,
                      104.0,
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
          _CalendarArrowButton(
            icon: Icons.chevron_right_rounded,
            onPressed: () => _scrollByVisibleDays(3),
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

  void _scrollByVisibleDays(int days) {
    if (!_controller.hasClients) {
      return;
    }

    final tileExtent = _controller.position.viewportDimension / 7;
    final delta = tileExtent * days;
    final target = (_controller.offset + delta).clamp(
      _controller.position.minScrollExtent,
      _controller.position.maxScrollExtent,
    );
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
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
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isToday ? 'AUJ' : _weekday(date),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: textColor,
                  fontWeight: isSelected || isToday
                      ? FontWeight.w900
                      : FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              FractionallySizedBox(
                widthFactor: isSelected || isToday ? 0.72 : 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 3,
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

class _CalendarArrowButton extends StatelessWidget {
  const _CalendarArrowButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Naviguer dans les dates',
      onPressed: onPressed,
      icon: Icon(icon),
      color: Theme.of(context).colorScheme.onSurface,
      constraints: const BoxConstraints.tightFor(width: 30, height: 48),
      padding: EdgeInsets.zero,
    );
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
      icon: const Icon(Icons.calendar_today_rounded),
      color: Theme.of(context).colorScheme.onSurface,
    );
  }
}
