/// A match's temporal state is independent of its sport and exploration mode.
enum LectorMatchPhase { live, upcoming, finished, other }

class LectorTemporalState {
  const LectorTemporalState({
    required this.phase,
    this.period,
    this.clock,
    this.capturedAt,
    this.label,
  });
  final LectorMatchPhase phase;
  final String? period, clock, label;
  final DateTime? capturedAt;
  bool get isLive => phase == LectorMatchPhase.live;
  bool isStale(DateTime now) =>
      isLive &&
      capturedAt != null &&
      now.difference(capturedAt!) > const Duration(minutes: 3);
  String get compactLabel =>
      [
        period,
        clock,
      ].whereType<String>().where((s) => s.isNotEmpty).join(' · ').isNotEmpty
      ? [
          period,
          clock,
        ].whereType<String>().where((s) => s.isNotEmpty).join(' · ')
      : label ??
            (isLive
                ? 'Live'
                : phase == LectorMatchPhase.finished
                ? 'Terminé'
                : 'À venir');
}
