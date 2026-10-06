enum LectorMeetingKind { league, cup, unknown, excluded }

/// Classification must be supported by provider metadata or a known league.
/// A different competition id alone never proves that a meeting was a cup.
abstract final class LectorHeadToHeadPolicy {
  static LectorMeetingKind classify({
    required String name,
    String? type,
    String? phase,
    bool knownLeague = false,
  }) {
    final value = '$name ${type ?? ''} ${phase ?? ''}'.toLowerCase();
    if (RegExp(r'friendl|amical|pre.?season|exhibition').hasMatch(value)) {
      return LectorMeetingKind.excluded;
    }
    if (RegExp(
      r'\bcup\b|coupe|champions|play.?off|post.?season|phase[s]? finale',
    ).hasMatch(value)) {
      return LectorMeetingKind.cup;
    }
    if (knownLeague ||
        type?.toLowerCase() == 'league' ||
        value.contains('regular season')) {
      return LectorMeetingKind.league;
    }
    return LectorMeetingKind.unknown;
  }

  /// Hockey league ids often include preseason and playoffs. A league name
  /// alone is not evidence of a regular-season meeting. NHL windows below
  /// follow the official schedules cited in the 2026-10-07 audit. Keep the
  /// simultaneous Global Series/preseason opening in 2024 unclassified.
  static LectorMeetingKind classifyHockey({
    required String name,
    required String competitionId,
    required DateTime? playedAt,
    String? phase,
    LectorMeetingKind declaredKind = LectorMeetingKind.unknown,
  }) {
    final explicit = classify(name: name, phase: phase);
    if (explicit == LectorMeetingKind.excluded ||
        declaredKind == LectorMeetingKind.excluded) {
      return LectorMeetingKind.excluded;
    }
    if (explicit == LectorMeetingKind.cup ||
        declaredKind == LectorMeetingKind.cup) {
      return LectorMeetingKind.cup;
    }
    final label = '$name ${phase ?? ''}'.toLowerCase();
    if (label.contains('regular season') ||
        label.contains('saison régulière')) {
      return LectorMeetingKind.league;
    }
    if (competitionId != '57' || playedAt == null) {
      return LectorMeetingKind.unknown;
    }
    final date = playedAt.toUtc();
    final year = date.month >= 7 ? date.year : date.year - 1;
    final dates = switch (year) {
      2023 => ('2023-10-10', '2023-10-10', '2024-04-19T07:00:00Z'),
      2024 => ('2024-10-04', '2024-10-08', '2025-04-18T07:00:00Z'),
      2025 => ('2025-10-07', '2025-10-07', '2026-04-17T07:00:00Z'),
      2026 => ('2026-09-29', '2026-09-29', '2027-04-11T07:00:00Z'),
      _ => null,
    };
    if (dates == null) return LectorMeetingKind.unknown;
    if (date.isBefore(DateTime.parse('${dates.$1}T00:00:00Z'))) {
      return LectorMeetingKind.excluded;
    }
    if (date.isBefore(DateTime.parse('${dates.$2}T00:00:00Z')) ||
        !date.isBefore(DateTime.parse(dates.$3))) {
      return LectorMeetingKind.unknown;
    }
    return LectorMeetingKind.league;
  }

  static DateTime lowerBound(DateTime reference) {
    final utc = reference.toUtc();
    return DateTime.utc(
      utc.year - 3,
      utc.month,
      utc.day,
      utc.hour,
      utc.minute,
      utc.second,
      utc.millisecond,
      utc.microsecond,
    );
  }
}
