import 'package:copilot/features/form_radar/domain/radar_audience_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const defaults = RadarAudienceFilter();

  test('uses explicit competition categories even with neutral labels', () {
    for (final id in [8, 64, 525, 1191]) {
      expect(defaults.includes(leagueId: id, teamName: 'Sélection A'), isFalse);
    }
    expect(defaults.includes(leagueId: 38, teamName: 'Sélection A'), isFalse);
    expect(defaults.includes(leagueId: 5, teamName: 'Sélection A'), isTrue);
    expect(defaults.includes(leagueId: 61, teamName: 'Club A'), isTrue);
  });

  test('recognizes explicit youth labels inside mixed friendlies', () {
    for (final name in [
      'Nation U17',
      'Nation U19',
      'Nation U20',
      'Nation U21',
      'Nation U23',
      'Nation U-21',
      'Nation U 20',
      'Nation Under-20',
      'Nation Under 21',
    ]) {
      expect(
        defaults.includes(leagueId: 10, teamName: name),
        isFalse,
        reason: name,
      );
    }
    expect(
      defaults.includes(
        leagueId: null,
        teamName: 'Sélection',
        competitionName: 'Championship U21',
      ),
      isFalse,
    );
  });

  test('recognizes women labels without guessing from player names', () {
    for (final competition in [
      'Women',
      "Women's Cup",
      'Feminine Division 1',
      'Première Ligue féminine',
      'Liga Femenina',
      'Liga Feminina',
      'Frauen Bundesliga',
    ]) {
      expect(
        defaults.includes(
          leagueId: 9999,
          teamName: 'Club A',
          competitionName: competition,
        ),
        isFalse,
        reason: competition,
      );
    }
    for (final name in [
      'Club W',
      'Nation Women',
      'Nation W U20',
      'Nation U20 W',
    ]) {
      expect(
        defaults.includes(leagueId: 10, teamName: name),
        isFalse,
        reason: name,
      );
    }
    for (final name in [
      'W Connection',
      'Wolves',
      'Utrecht',
      'United',
      'Club 21',
    ]) {
      expect(
        defaults.includes(leagueId: 61, teamName: name),
        isTrue,
        reason: name,
      );
    }
  });

  test(
    'women and youth inclusions are independent and both required when combined',
    () {
      const women = RadarAudienceFilter(includeWomen: true);
      const youth = RadarAudienceFilter(includeYouth: true);
      const all = RadarAudienceFilter(includeWomen: true, includeYouth: true);
      expect(women.includes(leagueId: 64, teamName: 'Club A'), isTrue);
      expect(women.includes(leagueId: 10, teamName: 'Nation U20'), isFalse);
      expect(youth.includes(leagueId: 10, teamName: 'Nation U20'), isTrue);
      expect(youth.includes(leagueId: 64, teamName: 'Club A'), isFalse);
      expect(women.includes(leagueId: 8, teamName: 'Nation U20'), isFalse);
      expect(youth.includes(leagueId: 8, teamName: 'Nation U20'), isFalse);
      expect(all.includes(leagueId: 8, teamName: 'Nation U20'), isTrue);
      expect(defaults.exclusionCount, 2);
      expect(all.exclusionCount, 0);
    },
  );

  test('invalid persisted values retain defaults', () {
    final filter = RadarAudienceFilter.fromJson({
      'includeWomen': 'true',
      'includeYouth': 1,
    });
    expect(filter.includeWomen, isFalse);
    expect(filter.includeYouth, isFalse);
    final restored = RadarAudienceFilter.fromJson(
      const RadarAudienceFilter(includeYouth: true).toJson(),
    );
    expect(restored.includeWomen, isFalse);
    expect(restored.includeYouth, isTrue);
  });
}
