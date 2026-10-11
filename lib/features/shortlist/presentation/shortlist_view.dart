import '../domain/shortlist.dart';
import '../../generator/domain/generator_context.dart';

enum ShortlistSort { dateAscending, dateDescending, competition, readings }

extension ShortlistSortLabel on ShortlistSort {
  String get label => switch (this) {
    ShortlistSort.dateAscending => 'Date (croissante)',
    ShortlistSort.dateDescending => 'Date (décroissante)',
    ShortlistSort.competition => 'Compétition',
    ShortlistSort.readings => 'Nombre de lectures',
  };
}

/// Published observations only. These labels never score betting quality.
class ShortlistReadingTag {
  const ShortlistReadingTag(this.label, this.kind);
  final String label;
  final String kind;
}

extension ShortlistFixturePresentation on ShortlistFixture {
  String get competition =>
      json['competition']?.toString() ?? 'Compétition à confirmer';
  List<Map<String, dynamic>> get publishedReadings =>
      generatorRows(json['readings'])
          .where(
            (r) =>
                r['id'] != 'head_to_head_dominance' &&
                (r['status'] == null || r['status'] == 'detected'),
          )
          .toList();
  bool get readingsAvailable => json['readings'] is List;
  int get readingCount => publishedReadings.length;
  List<ShortlistReadingTag> get readingTags {
    final ids = publishedReadings.map((r) => r['id'].toString()).toSet();
    final tags = <ShortlistReadingTag>[];
    if (ids.contains('positive_streak') || ids.contains('improving_form')) {
      tags.add(const ShortlistReadingTag('Forme +', 'form'));
    }
    if (ids.any(
      {
        'standing_advantage',
        'ranking_advantage',
        'structural_level_gap',
        'home_away_advantage',
        'away_home_advantage',
        'recent_form_advantage',
        'form_gap',
      }.contains,
    )) {
      tags.add(const ShortlistReadingTag('Avantage', 'advantage'));
    }
    if (publishedReadings.any(
      (r) =>
          r['isContradiction'] == true ||
          r['is_contradiction'] == true ||
          {
            'negative_streak',
            'weak_home_team',
            'weak_away_team',
            'fragile_defense',
            'declining_form',
          }.contains(r['id']),
    )) {
      tags.insert(0, const ShortlistReadingTag('Vigilance', 'warning'));
    }
    return tags;
  }
}

/// Filters affect the visible list, never the persisted preparation.
class ShortlistViewFilter {
  const ShortlistViewFilter({
    this.sport,
    this.competition,
    this.withReadings = false,
  });
  final String? sport, competition;
  final bool withReadings;
  int get count =>
      (sport == null ? 0 : 1) +
      (competition == null ? 0 : 1) +
      (withReadings ? 1 : 0);
  bool accepts(ShortlistFixture fixture) =>
      (sport == null || fixture.sport == sport) &&
      (competition == null || fixture.competition == competition) &&
      (!withReadings || fixture.readingCount > 0);
}

List<ShortlistFixture> shortlistVisibleFixtures(
  Iterable<ShortlistFixture> items, {
  required DateTime now,
  required String group,
  required ShortlistSort sort,
  required ShortlistViewFilter filter,
}) {
  final visible = items
      .where(
        (f) =>
            filter.accepts(f) &&
            (f.phase(now) == group ||
                (group == 'other' && f.phase(now) == 'unavailable')),
      )
      .toList();
  int date(ShortlistFixture a, ShortlistFixture b) {
    if (a.kickoff == null) return b.kickoff == null ? 0 : 1;
    if (b.kickoff == null) return -1;
    return a.kickoff!.compareTo(b.kickoff!);
  }

  visible.sort((a, b) {
    final order = switch (sort) {
      ShortlistSort.dateAscending => date(a, b),
      ShortlistSort.dateDescending =>
        a.kickoff == null || b.kickoff == null ? date(a, b) : date(b, a),
      ShortlistSort.competition => a.competition.compareTo(b.competition),
      ShortlistSort.readings => b.readingCount.compareTo(a.readingCount),
    };
    return order != 0 ? order : a.key.compareTo(b.key);
  });
  return visible;
}
