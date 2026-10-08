import '../../../../core/widgets/lector_live_badge.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_components.dart';
import '../../data/match_reading_bilan_repository.dart';
import '../../domain/live_match_state.dart';
import '../../domain/match_board_item.dart';
import 'match_reading_bilan_sheet.dart';

class LiveMatchStatus extends StatefulWidget {
  const LiveMatchStatus({
    required this.state,
    this.showBadge = true,
    super.key,
  });
  final LiveMatchState state;
  final bool showBadge;
  @override
  State<LiveMatchStatus> createState() => _LiveMatchStatusState();
}

class _LiveMatchStatusState extends State<LiveMatchStatus> {
  Timer? _clock;
  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    if (state.capturedAt == null) return const SizedBox.shrink();
    final stale = state.isStale(DateTime.now());
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 10,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (state.isLive && widget.showBadge)
            LectorLiveBadge(state: state.temporal)
          else if (!state.isLive)
            Text(
              state.statusLabel,
              style: TextStyle(
                color: stale
                    ? context.semantic.warning
                    : context.textColors.secondary,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          Text(
            '${stale ? 'Actualisation en retard · dernière réception' : 'Reçu à'} ${DateFormat('HH:mm').format(state.capturedAt!.toLocal())}',
            style: TextStyle(color: context.textColors.secondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class LiveReadingSummary extends StatelessWidget {
  const LiveReadingSummary({
    required this.state,
    required this.entries,
    this.hasReadings = false,
    this.match,
    this.onOpenMatch,
    super.key,
  });
  final LiveMatchState state;
  final List<MatchReadingBilanEntry> entries;
  final bool hasReadings;
  final MatchBoardItem? match;
  final VoidCallback? onOpenMatch;
  @override
  Widget build(BuildContext context) {
    if (!hasReadings && entries.isEmpty) return const SizedBox.shrink();
    if (!state.isFinal) return const SizedBox.shrink();
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'Résultat reçu · bilan des lectures en attente',
          style: TextStyle(color: context.textColors.secondary, fontSize: 12),
        ),
      );
    }
    final confirmed = entries.where((e) => e.verdict == 'confirmed').length;
    final contradicted = entries
        .where((e) => e.verdict == 'contradicted')
        .length;
    int count(String verdict) =>
        entries.where((e) => e.verdict == verdict).length;
    final pending = entries.where((e) => e.verdict == null).length;
    final notEvaluable = count('not_evaluable');
    final contextual = count('context_only');
    final pertinent = count('caution_confirmed');
    final nuance = count('caution_not_confirmed');
    final parts = <String>[
      if (confirmed > 0) '$confirmed confirmée${confirmed > 1 ? 's' : ''}',
      if (contradicted > 0)
        '$contradicted contredite${contradicted > 1 ? 's' : ''}',
      if (notEvaluable > 0)
        '$notEvaluable non évaluable${notEvaluable > 1 ? 's' : ''}',
      if (contextual > 0) '$contextual descriptive${contextual > 1 ? 's' : ''}',
      if (pending > 0) '$pending en attente',
      if (pertinent > 0)
        '$pertinent nuance${pertinent > 1 ? 's' : ''} pertinente${pertinent > 1 ? 's' : ''}',
      if (nuance > 0)
        '$nuance nuance${nuance > 1 ? 's' : ''} non confirmée${nuance > 1 ? 's' : ''}',
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            parts.join(' · '),
            style: TextStyle(
              color: context.textColors.primary,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          TextButton.icon(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
            ),
            onPressed: () => showMatchReadingBilan(
              context,
              entries: entries,
              match: match,
              onOpenMatch: onOpenMatch,
            ),
            icon: const Icon(Icons.fact_check_outlined, size: 17),
            label: const Text('Voir les lectures'),
          ),
        ],
      ),
    );
  }
}
