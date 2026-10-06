/// Common temporal contract for player form. Sports supply their contributions
/// and whether each match is decisive; missing evidence interrupts a series.
abstract final class LectorPlayerFormPolicy {
  static const recentWindow = 3;
  static const minimumContributions = 2;

  static List<T> recent<T>(List<T> activity) => activity
      .skip((activity.length - recentWindow).clamp(0, activity.length))
      .toList(growable: false);

  static int streak<T>(List<T> activity, bool? Function(T) isDecisive) {
    var count = 0;
    for (final match in activity.reversed) {
      if (isDecisive(match) != true) break;
      count++;
    }
    return count;
  }
}
