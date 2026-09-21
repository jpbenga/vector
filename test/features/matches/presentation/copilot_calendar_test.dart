import 'package:copilot/core/theme/app_theme.dart';
import 'package:copilot/features/matches/presentation/widgets/copilot_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('highlights only the selected day when leaving today', (
    tester,
  ) async {
    final today = _dayOnly(DateTime.now());
    final tomorrow = today.add(const Duration(days: 1));
    var selectedDate = today;

    await tester.pumpWidget(
      MaterialApp(
        theme: CopilotTheme.dark,
        home: StatefulBuilder(
          builder: (context, setState) {
            return Center(
              child: SizedBox(
                width: 390,
                child: CopilotCalendar(
                  selectedDate: selectedDate,
                  visibleWindowDays: 7,
                  onDateSelected: (date) {
                    setState(() => selectedDate = _dayOnly(date));
                  },
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text(_weekday(tomorrow)));
    await tester.pump(const Duration(milliseconds: 200));

    expect(selectedDate, tomorrow);
    final todayText = tester.widget<Text>(find.text('AUJ'));
    final selectedText = tester.widget<Text>(find.text(_weekday(tomorrow)));
    expect(todayText.style?.color, isNot(selectedText.style?.color));
  });

  testWidgets('scrolls horizontally to days outside the initial viewport', (
    tester,
  ) async {
    final today = _dayOnly(DateTime.now());
    final laterDay = today.add(const Duration(days: 12));

    await tester.pumpWidget(
      MaterialApp(
        theme: CopilotTheme.dark,
        home: Center(
          child: SizedBox(
            width: 390,
            child: CopilotCalendar(
              selectedDate: today,
              visibleWindowDays: 31,
              onDateSelected: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.text(_calendarLabel(laterDay)),
      180,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('home-calendar-day-strip')),
        matching: find.byType(Scrollable),
      ),
    );

    expect(find.text(_calendarLabel(laterDay)), findsOneWidget);
  });
}

DateTime _dayOnly(DateTime date) => DateTime(date.year, date.month, date.day);

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

String _calendarLabel(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}';
