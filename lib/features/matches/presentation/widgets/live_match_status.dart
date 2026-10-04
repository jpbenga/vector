import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_components.dart';
import '../../data/match_reading_bilan_repository.dart';
import '../../domain/live_match_state.dart';
import '../reading_bilan_section.dart';

class LiveMatchStatus extends StatefulWidget {
  const LiveMatchStatus({required this.state, super.key});
  final LiveMatchState state;
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
    final color = stale
        ? context.semantic.warning
        : state.isLive
        ? context.semantic.success
        : context.textColors.secondary;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 10,
        runSpacing: 4,
        children: [
          Text(
            state.statusLabel,
            style: TextStyle(
              color: color,
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
    super.key,
  });
  final LiveMatchState state;
  final List<MatchReadingBilanEntry> entries;
  final bool hasReadings;
  @override
  Widget build(BuildContext context) {
    if (!hasReadings && entries.isEmpty) return const SizedBox.shrink();
    if (!state.isFinal) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'Lectures annoncées avant match · bilan au résultat final',
          style: TextStyle(color: context.textColors.secondary, fontSize: 12),
        ),
      );
    }
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
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (context) => FractionallySizedBox(
                heightFactor: 0.85,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Bilan des lectures annoncées',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Fermer',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: entries.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, index) =>
                            ReadingVerdictCard(entry: entries[index]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            icon: const Icon(Icons.fact_check_outlined, size: 17),
            label: const Text('Voir les lectures'),
          ),
        ],
      ),
    );
  }
}
