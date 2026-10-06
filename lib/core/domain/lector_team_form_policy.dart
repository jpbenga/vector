/// Shared five-match ranking. Each sport supplies its result values and the
/// definition of a series. Results must be ordered oldest to newest.
abstract final class LectorTeamFormPolicy {
  static const window = 5;
  static const recentWindow = 3;

  static List<LectorTeamFormEntry<T>> rank<T>(
    Iterable<T> profiles, {
    required List<int> Function(T) resultValues,
    required bool Function(int) continuesSeries,
    required String Function(T) name,
  }) {
    final entries = <LectorTeamFormEntry<T>>[];
    for (final profile in profiles) {
      final values = List<int>.unmodifiable(resultValues(profile));
      if (values.length < window) continue;
      var series = 0;
      for (final value in values.reversed) {
        if (!continuesSeries(value)) break;
        series++;
      }
      entries.add(
        LectorTeamFormEntry(
          profile: profile,
          values: values,
          score: values.skip(values.length - window).fold(0, (a, b) => a + b),
          recentScore: values
              .skip(values.length - recentWindow)
              .fold(0, (a, b) => a + b),
          series: series,
        ),
      );
    }
    entries.sort((a, b) {
      final score = b.score.compareTo(a.score);
      if (score != 0) return score;
      // Compare the sixth result, then the seventh, etc. Unknown older
      // results are never interpreted as losses.
      final available = a.values.length < b.values.length
          ? a.values.length
          : b.values.length;
      for (var offset = window + 1; offset <= available; offset++) {
        final result = b.values[b.values.length - offset].compareTo(
          a.values[a.values.length - offset],
        );
        if (result != 0) return result;
      }
      final series = b.series.compareTo(a.series);
      return series != 0 ? series : name(a.profile).compareTo(name(b.profile));
    });
    return List.unmodifiable(entries);
  }
}

class LectorTeamFormEntry<T> {
  const LectorTeamFormEntry({
    required this.profile,
    required this.values,
    required this.score,
    required this.recentScore,
    required this.series,
  });
  final T profile;
  final List<int> values;
  final int score, recentScore, series;
}
