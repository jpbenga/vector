import '../domain/lector_head_to_head_policy.dart';
import 'package:flutter/material.dart';

/// Presentation inputs. Each discipline supplies its history policy and clock.
class LectorHeadToHeadData {
  const LectorHeadToHeadData({
    required this.competitionId,
    required this.firstTeamId,
    required this.secondTeamId,
    required this.firstTeamName,
    required this.secondTeamName,
    this.firstTeamLogoUrl,
    this.secondTeamLogoUrl,
    required this.meetings,
    required this.emptyDescription,
    this.coverageNote,
    this.allowUnknownCompetitionFallback = true,
  });
  final String? competitionId, firstTeamId, secondTeamId;
  final String firstTeamName, secondTeamName, emptyDescription;
  final String? firstTeamLogoUrl, secondTeamLogoUrl, coverageNote;
  final bool allowUnknownCompetitionFallback;
  final List<LectorHeadToHeadMeeting> meetings;
}

class LectorHeadToHeadMeeting {
  const LectorHeadToHeadMeeting({
    required this.competitionId,
    required this.competitionName,
    required this.playedAt,
    required this.homeTeamId,
    required this.homeTeamName,
    required this.awayTeamId,
    required this.awayTeamName,
    required this.homeGoals,
    required this.awayGoals,
    this.fixtureId,
    this.homeTeamLogoUrl,
    this.awayTeamLogoUrl,
    this.events = const [],
    this.statistics = const [],
    this.regulationMinutes = 90,
    this.tickMinutes = 15,
    this.eventsUnavailableLabel =
        'Événements indisponibles pour cette confrontation.',
    this.showVenue = false,
    this.orderByVenue = false,
    this.resultLabel,
    this.competitionKind = LectorMeetingKind.unknown,
  });
  final String competitionId,
      competitionName,
      homeTeamId,
      homeTeamName,
      awayTeamId,
      awayTeamName;
  final String? fixtureId, homeTeamLogoUrl, awayTeamLogoUrl, resultLabel;
  final LectorMeetingKind competitionKind;
  final DateTime playedAt;
  final int homeGoals, awayGoals, regulationMinutes, tickMinutes;
  final bool showVenue, orderByVenue;
  final String eventsUnavailableLabel;
  final List<LectorHeadToHeadEvent> events;
  final List<LectorHeadToHeadStatistic> statistics;
}

class LectorHeadToHeadEvent {
  const LectorHeadToHeadEvent({
    required this.minute,
    this.teamId,
    required this.label,
    required this.clockLabel,
    required this.icon,
    this.playerName,
    this.danger = false,
  });
  final int? minute;
  final String? teamId, playerName;
  final String label, clockLabel;
  final IconData icon;
  final bool danger;
}

class LectorHeadToHeadStatistic {
  const LectorHeadToHeadStatistic(this.label, this.home, this.away);
  final String label;
  final double? home, away;
}
