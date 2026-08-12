import '../../../core/supabase/supabase_user_scope.dart';
import '../domain/saved_ticket.dart';

class SupabaseSavedTicketRepository {
  const SupabaseSavedTicketRepository(this._scope);

  final SupabaseUserScope _scope;

  Future<List<SavedTicket>> load() async {
    final ticketRows = await _scope.client
        .from('saved_tickets')
        .select()
        .eq('user_id', _scope.userId)
        .order('created_at', ascending: false);
    final selectionRows = await _scope.client
        .from('saved_ticket_selections')
        .select()
        .eq('user_id', _scope.userId)
        .order('position');
    final selectionsByTicket = <String, List<Map<String, Object?>>>{};
    for (final row in selectionRows) {
      final map = _mapValue(row);
      final ticketId = map['ticket_id']?.toString();
      if (ticketId == null) {
        continue;
      }
      selectionsByTicket.putIfAbsent(ticketId, () => []).add(map);
    }

    return [
      for (final row in ticketRows)
        savedTicketFromSupabaseRows(
          ticketRow: _mapValue(row),
          selectionRows:
              selectionsByTicket[_mapValue(row)['id']?.toString()] ?? const [],
        ),
    ];
  }

  Future<void> saveAll(List<SavedTicket> tickets) async {
    await _scope.client
        .from('saved_ticket_selections')
        .delete()
        .eq('user_id', _scope.userId);
    await _scope.client
        .from('saved_tickets')
        .delete()
        .eq('user_id', _scope.userId);

    if (tickets.isEmpty) {
      return;
    }

    await _scope.client.from('saved_tickets').insert([
      for (final ticket in tickets)
        savedTicketToSupabaseRow(ticket, userId: _scope.userId),
    ]);
    final selectionRows = [
      for (final ticket in tickets)
        ...savedTicketSelectionRows(ticket, userId: _scope.userId),
    ];
    if (selectionRows.isEmpty) {
      return;
    }

    await _scope.client.from('saved_ticket_selections').insert(selectionRows);
  }

  Future<void> upsert(SavedTicket ticket) async {
    await _scope.client
        .from('saved_tickets')
        .upsert(
          savedTicketToSupabaseRow(ticket, userId: _scope.userId),
          onConflict: 'user_id,id',
        );
    await _scope.client
        .from('saved_ticket_selections')
        .delete()
        .eq('user_id', _scope.userId)
        .eq('ticket_id', ticket.id);

    if (ticket.selections.isEmpty) {
      return;
    }

    await _scope.client
        .from('saved_ticket_selections')
        .insert(savedTicketSelectionRows(ticket, userId: _scope.userId));
  }

  Future<void> delete(String ticketId) async {
    await _scope.client
        .from('saved_tickets')
        .delete()
        .eq('user_id', _scope.userId)
        .eq('id', ticketId);
  }
}

Map<String, Object?> savedTicketToSupabaseRow(
  SavedTicket ticket, {
  required String userId,
}) {
  final played = ticket.playedDeclaration;
  return {
    'user_id': userId,
    'id': ticket.id,
    'schema_version': ticket.schemaVersion,
    'source': ticket.source.name,
    'status': ticket.status.name,
    'name': ticket.name,
    'strategy_id': ticket.strategyId,
    'strategy_name': ticket.strategyName,
    'total_odds': ticket.totalOdds,
    'planned_stake': ticket.plannedStake,
    'played_bookmaker': played?.bookmaker,
    'played_stake': played?.stake,
    'played_actual_total_odds': played?.actualTotalOdds,
    'played_at': played?.playedAt.toUtc().toIso8601String(),
    'main_combined_reading_id': ticket.mainCombinedReadingId,
    'main_combined_reading_label': ticket.mainCombinedReadingLabel,
    'opportunity_ids': ticket.opportunityIds,
    'modification_summary': ticket.modificationSummary,
    'modification_details': ticket.modificationDetails,
    'created_at': ticket.createdAt.toUtc().toIso8601String(),
    'updated_at': ticket.updatedAt.toUtc().toIso8601String(),
  };
}

List<Map<String, Object?>> savedTicketSelectionRows(
  SavedTicket ticket, {
  required String userId,
}) {
  return [
    for (final indexed in ticket.selections.indexed)
      {
        'user_id': userId,
        'ticket_id': ticket.id,
        'id': indexed.$2.id,
        'position': indexed.$1,
        'match_id': indexed.$2.matchId,
        'home_team': indexed.$2.homeTeam,
        'away_team': indexed.$2.awayTeam,
        'competition_name': indexed.$2.competitionName,
        'market_id': indexed.$2.marketId,
        'market_label': indexed.$2.marketLabel,
        'selection_id': indexed.$2.selectionId,
        'selection_label': indexed.$2.selectionLabel,
        'odds': indexed.$2.odds,
        'home_logo_url': indexed.$2.homeLogoUrl,
        'away_logo_url': indexed.$2.awayLogoUrl,
        'bookmaker_name': indexed.$2.bookmakerName,
        'opportunity_id': indexed.$2.opportunityId,
      },
  ];
}

SavedTicket savedTicketFromSupabaseRows({
  required Map<String, Object?> ticketRow,
  required List<Map<String, Object?>> selectionRows,
}) {
  return SavedTicket(
    schemaVersion: _intValue(ticketRow['schema_version']) ?? 1,
    id: ticketRow['id']?.toString() ?? '',
    source: _sourceValue(ticketRow['source']),
    status: _statusValue(ticketRow['status']),
    createdAt: _dateValue(ticketRow['created_at']) ?? DateTime.now().toUtc(),
    updatedAt:
        _dateValue(ticketRow['updated_at']) ??
        _dateValue(ticketRow['created_at']) ??
        DateTime.now().toUtc(),
    totalOdds: _doubleValue(ticketRow['total_odds']) ?? 0,
    selections: [
      for (final row in selectionRows) savedTicketSelectionFromSupabaseRow(row),
    ],
    name: _stringValue(ticketRow['name']),
    strategyId: _stringValue(ticketRow['strategy_id']),
    strategyName: _stringValue(ticketRow['strategy_name']),
    plannedStake: _doubleValue(ticketRow['planned_stake']),
    playedDeclaration: _playedDeclaration(ticketRow),
    mainCombinedReadingId: _stringValue(ticketRow['main_combined_reading_id']),
    mainCombinedReadingLabel: _stringValue(
      ticketRow['main_combined_reading_label'],
    ),
    opportunityIds: [
      for (final id in _listValue(ticketRow['opportunity_ids']))
        if (_stringValue(id) != null) _stringValue(id)!,
    ],
    modificationSummary: _stringValue(ticketRow['modification_summary']),
    modificationDetails: [
      for (final detail in _listValue(ticketRow['modification_details']))
        if (_stringValue(detail) != null) _stringValue(detail)!,
    ],
  );
}

SavedTicketSelection savedTicketSelectionFromSupabaseRow(
  Map<String, Object?> row,
) {
  return SavedTicketSelection(
    id: row['id']?.toString() ?? '',
    matchId: row['match_id']?.toString() ?? '',
    homeTeam: row['home_team']?.toString() ?? '',
    awayTeam: row['away_team']?.toString() ?? '',
    competitionName: row['competition_name']?.toString() ?? '',
    marketId: row['market_id']?.toString() ?? '',
    marketLabel: row['market_label']?.toString() ?? '',
    selectionId: row['selection_id']?.toString() ?? '',
    selectionLabel: row['selection_label']?.toString() ?? '',
    odds: _doubleValue(row['odds']) ?? 0,
    homeLogoUrl: _stringValue(row['home_logo_url']),
    awayLogoUrl: _stringValue(row['away_logo_url']),
    bookmakerName: _stringValue(row['bookmaker_name']),
    opportunityId: _stringValue(row['opportunity_id']),
  );
}

SavedTicketPlayDeclaration? _playedDeclaration(Map<String, Object?> row) {
  final playedAt = _dateValue(row['played_at']);
  if (playedAt == null) {
    return null;
  }

  return SavedTicketPlayDeclaration(
    bookmaker: row['played_bookmaker']?.toString() ?? '',
    stake: _doubleValue(row['played_stake']),
    actualTotalOdds: _doubleValue(row['played_actual_total_odds']),
    playedAt: playedAt,
  );
}

Map<String, Object?> _mapValue(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return {
      for (final entry in value.entries)
        if (entry.key != null) entry.key.toString(): entry.value,
    };
  }
  return const {};
}

String? _stringValue(Object? value) => value?.toString();

double? _doubleValue(Object? value) {
  return switch (value) {
    final double number => number,
    final num number => number.toDouble(),
    final String text => double.tryParse(text),
    _ => null,
  };
}

int? _intValue(Object? value) {
  return switch (value) {
    final int number => number,
    final num number => number.toInt(),
    final String text => int.tryParse(text),
    _ => null,
  };
}

DateTime? _dateValue(Object? value) {
  if (value is DateTime) {
    return value.toUtc();
  }
  return DateTime.tryParse(value?.toString() ?? '')?.toUtc();
}

List<Object?> _listValue(Object? value) {
  if (value is List<Object?>) {
    return value;
  }
  if (value is List) {
    return value;
  }
  return const [];
}

SavedTicketSource _sourceValue(Object? value) {
  final name = value?.toString();
  return SavedTicketSource.values.firstWhere(
    (source) => source.name == name,
    orElse: () => SavedTicketSource.manual,
  );
}

SavedTicketStatus _statusValue(Object? value) {
  final name = value?.toString();
  return SavedTicketStatus.values.firstWhere(
    (status) => status.name == name,
    orElse: () => SavedTicketStatus.saved,
  );
}
