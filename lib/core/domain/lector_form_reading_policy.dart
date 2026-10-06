/// Shared football principles, with points supplied by each sport's rules.
/// Windows are newest first. A victory series is a separate assessment.
class LectorFormWindow {
  LectorFormWindow(List<int> newestFirst, {required this.maximumPoints})
    : points = List.unmodifiable(newestFirst.take(5));
  final List<int> points;
  final int maximumPoints;
  bool get available => points.length == 5;
  int get total => points.fold(0, (sum, p) => sum + p);
  int get possible => 5 * maximumPoints;
  int get positiveMinimum => (9 * maximumPoints / 3).ceil();
  int get negativeMaximum => (4 * maximumPoints / 3).floor();
  bool get positive =>
      available && points.every((p) => p > 0) && total >= positiveMinimum;
  bool get negative => available && total <= negativeMaximum;
  double get trend => available
      ? (points[0] + points[1]) / 2 - (points[2] + points[3] + points[4]) / 3
      : 0;
  double get trendThreshold => maximumPoints / 3;
  bool get improving => available && trend + 1e-10 >= trendThreshold;
}
