import 'package:copilot/features/form_radar/data/player_form_radar_fixture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the selected past day and retains the last state for future days', () {
    final past = playerFormRadarFixtureForDate(DateTime(2026, 9, 24));
    final future = playerFormRadarFixtureForDate(DateTime(2026, 9, 27));

    expect(past.asOf, DateTime(2026, 9, 24, 22, 30));
    expect(future.asOf, DateTime(2026, 9, 25, 22, 30));
    expect(future.profiles, isNotEmpty);
  });
}
