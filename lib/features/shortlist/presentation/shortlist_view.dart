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
  required ShortlistSort sort,
  required ShortlistViewFilter filter,
}) {
  final visible = items.where(filter.accepts).toList();
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
