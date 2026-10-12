import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_components.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import 'lector_horizontal_transition.dart';

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
  late DateTime _windowCenterDate;
  double _dayExtent = 0;

  @override
  void initState() {
    super.initState();
    _windowCenterDate = _dayOnly(widget.selectedDate);
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerWindow());
  }

  @override
  void didUpdateWidget(covariant CopilotCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isSameDay(oldWidget.selectedDate, widget.selectedDate)) {
      return;
    }

    final selectedDay = _dayOnly(widget.selectedDate);
    final halfWindow = widget.visibleWindowDays ~/ 2;
    final firstVisible = DateTime(
      _windowCenterDate.year,
      _windowCenterDate.month,
      _windowCenterDate.day - halfWindow,
    );
    final lastVisible = DateTime(
      _windowCenterDate.year,
      _windowCenterDate.month,
      _windowCenterDate.day + halfWindow,
    );
    if (selectedDay.isBefore(firstVisible) ||
        selectedDay.isAfter(lastVisible)) {
      _windowCenterDate = selectedDay;
      WidgetsBinding.instance.addPostFrameCallback((_) => _centerWindow());
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelectedDay());
    }
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
        DateTime(
          _windowCenterDate.year,
          _windowCenterDate.month,
          _windowCenterDate.day + offset,
        ),
    ];

    return SizedBox(
      key: const ValueKey('home-calendar-navigation'),
      height:
          48 *
          (MediaQuery.textScalerOf(context).scale(12) / 12).clamp(1.0, 1.5),
      child: Row(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const separatorWidth = 1.0;
                final tileWidth =
                    ((constraints.maxWidth - (separatorWidth * 6)) / 7).clamp(
                      36.0 *
                          (MediaQuery.textScalerOf(context).scale(12) / 12)
                              .clamp(1.0, 2.0),
                      74.0 *
                          (MediaQuery.textScalerOf(context).scale(12) / 12)
                              .clamp(1.0, 2.0),
                    );
                _dayExtent = tileWidth + separatorWidth;

                return LectorHorizontalTransition(
                  position: DateTime.utc(
                    _windowCenterDate.year,
                    _windowCenterDate.month,
                    _windowCenterDate.day,
                  ).millisecondsSinceEpoch,
                  child: ListView.separated(
                    key: const ValueKey('home-calendar-day-strip'),
                    controller: _controller,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
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
                  ),
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

  void _centerWindow() {
    if (!mounted || !_controller.hasClients) {
      return;
    }

    final maxScroll = _controller.position.maxScrollExtent;
    _controller.jumpTo(maxScroll / 2);
  }

  void _revealSelectedDay() {
    if (!mounted || !_controller.hasClients || _dayExtent == 0) return;
    final selected = widget.selectedDate;
    final dayOffset = DateTime.utc(selected.year, selected.month, selected.day)
        .difference(
          DateTime.utc(
            _windowCenterDate.year,
            _windowCenterDate.month,
            _windowCenterDate.day,
          ),
        )
        .inDays;
    final leading = (dayOffset + widget.visibleWindowDays ~/ 2) * _dayExtent;
    final position = _controller.position;
    final trailing = leading + _dayExtent - 1;
    if (leading >= position.pixels &&
        trailing <= position.pixels + position.viewportDimension) {
      return;
    }
    final target = (leading - (position.viewportDimension - _dayExtent) / 2)
        .clamp(0.0, position.maxScrollExtent);
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpTo(target);
    } else {
      _controller.animateTo(
        target,
        duration: LectorHorizontalTransition.duration,
        curve: Curves.easeInOutCubic,
      );
    }
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
    final textColor = isSelected
        ? context.semantic.info
        : context.textColors.secondary;

    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: isSelected
                ? context.semantic.info.withValues(alpha: 0.10)
                : AppColors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.control),
            border: Border.all(
              color: isSelected ? context.semantic.info : AppColors.transparent,
              width: 1.2,
            ),
          ),
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
                  color: isSelected ? context.textColors.primary : textColor,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
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
      icon: const Icon(Icons.calendar_today_rounded, size: 20),
      color: Theme.of(context).colorScheme.onSurface,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      padding: EdgeInsets.zero,
    );
  }
}
