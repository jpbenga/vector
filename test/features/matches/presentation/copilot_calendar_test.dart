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
