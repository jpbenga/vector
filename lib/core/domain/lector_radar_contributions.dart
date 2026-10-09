import '../sports/domain/sport_match_history.dart';
import 'lector_recorded_radar.dart';

List<LectorRadarContribution> footballRadarContributions(
  LectorRecordedRadar snapshot,
  List<Map<String, dynamic>> events,
  DateTime? capturedAt,
) {
  if (capturedAt == null || capturedAt.isBefore(snapshot.kickoffAt)) return [];
  final result = <String, LectorRadarContribution>{};
  for (final e in events) {
    if (e['type'] != 'Goal' ||
        e['detail'] == 'Own Goal' ||
        e['detail'] == 'Missed Penalty' ||
        e['comments'] == 'Penalty Shootout') {
      continue;
    }
    final team = e['team'] is Map ? e['team'] as Map : null;
    final time = e['time'] is Map ? e['time'] as Map : null;
    final minute = time?['elapsed'] is num ? time!['elapsed'] as num : null;
    final extra = time?['extra'] is num ? time!['extra'] as num : null;
    final clock = minute == null
        ? ''
        : " ${minute.toInt()}${extra != null && extra > 0 ? '+${extra.toInt()}' : ''}′";
    for (final (field, label) in [
      ('player', 'But'),
      ('assist', 'Passe décisive'),
    ]) {
      final participant = e[field] is Map ? e[field] as Map : null;
      final id = participant?['id'];
      if (id == null || team?['id'] == null) continue;
      final p = snapshot.players
          .where((p) => p.id == '$id' && p.teamId == '${team!['id']}')
          .singleOrNull;
      if (p == null) continue;
      final text = '$label$clock';
      result['${p.id}:$text'] = LectorRadarContribution(
        playerId: p.id,
        label: text,
      );
    }
  }
  return result.values.toList();
}

List<LectorRadarContribution> hockeyRadarContributions(
  LectorRecordedRadar snapshot,
  List<SportMatchEvent> events,
  DateTime? capturedAt,
) {
  if (capturedAt == null || capturedAt.isBefore(snapshot.kickoffAt)) return [];
  final result = <String, LectorRadarContribution>{};
  for (final e in events) {
    if (e.type != 'goal' ||
        !const {'P1', 'P2', 'P3', 'OT'}.contains(e.period) ||
        e.players.length != 1 ||
        e.assists.length > 2 ||
        e.assists.contains(e.players.single)) {
      continue;
    }
    final clock = e.minute == null ? '' : ' ${e.period} · ${e.minute}′';
    for (final (names, label) in [
      (e.players, 'But'),
      (e.assists, 'Passe décisive'),
    ]) {
      for (final name in names) {
        // API-Hockey identities are event names. Exact team/name matching only;
        // an ambiguous name is never attributed to a tracked player.
        final p = snapshot.players
            .where((p) => p.teamId == e.teamId && p.name.trim() == name.trim())
            .singleOrNull;
        if (p == null) continue;
        final text = '$label$clock';
        result['${p.id}:$text'] = LectorRadarContribution(
          playerId: p.id,
          label: text,
        );
      }
    }
  }
  return result.values.toList();
}
