import 'package:supabase_flutter/supabase_flutter.dart';

import '../../onboarding/domain/decision_profile_catalogs.dart';
import '../../../core/identity/identity_scope.dart';
import '../domain/ticket_strategy.dart';

class SupabaseTicketStrategyRepository {
  SupabaseTicketStrategyRepository({
    required SupabaseClient client,
    required IdentityScope scope,
  }) : assert(scope.isAccount),
       _client = client,
       _userId = scope.id;

  final SupabaseClient _client;
  final String _userId;

  Future<List<TicketStrategy>> load() async {
    final rows = await _client
        .from('ticket_strategies')
        .select()
        .eq('user_id', _userId)
        .order('priority');

    return [
      for (final row in rows) ticketStrategyFromSupabaseRow(_mapValue(row)),
    ];
  }

  Future<void> saveAll(List<TicketStrategy> strategies) async {
    await _client
        .from('ticket_strategies')
        .delete()
        .eq('user_id', _userId);

    if (strategies.isEmpty) {
      return;
    }

    await _client.from('ticket_strategies').insert([
      for (final strategy in strategies)
        ticketStrategyToSupabaseRow(strategy, userId: _userId),
    ]);
  }
}

Map<String, Object?> ticketStrategyToSupabaseRow(
  TicketStrategy strategy, {
  required String userId,
}) {
  return {
    'user_id': userId,
    'id': strategy.id,
    'schema_version': strategy.schemaVersion,
    'name': strategy.name,
    'is_active': strategy.isActive,
    'pick_types': [for (final pickType in strategy.pickTypes) pickType.name],
    'minimum_individual_odds': strategy.minimumIndividualOdds,
    'maximum_individual_odds': strategy.maximumIndividualOdds,
    'minimum_selections': strategy.minimumSelections,
    'maximum_selections': strategy.maximumSelections,
    'minimum_total_odds': strategy.minimumTotalOdds,
    'maximum_total_odds': strategy.maximumTotalOdds,
    'priority': strategy.priority,
    'created_at': strategy.createdAt.toUtc().toIso8601String(),
    'updated_at': strategy.updatedAt.toUtc().toIso8601String(),
  };
}

TicketStrategy ticketStrategyFromSupabaseRow(Map<String, Object?> row) {
  return TicketStrategy(
    schemaVersion: _intValue(row['schema_version']) ?? 2,
    id: row['id']?.toString() ?? '',
    userId: row['user_id']?.toString() ?? '',
    name: row['name']?.toString() ?? '',
    isActive: _boolValue(row['is_active']) ?? true,
    pickTypes: [
      for (final pickType in _listValue(row['pick_types']))
        if (_pickTypeValue(pickType) != null) _pickTypeValue(pickType)!,
    ],
    minimumIndividualOdds: _doubleValue(row['minimum_individual_odds']) ?? 1.01,
    maximumIndividualOdds: _doubleValue(row['maximum_individual_odds']),
    minimumSelections: _intValue(row['minimum_selections']) ?? 1,
    maximumSelections: _intValue(row['maximum_selections']) ?? 1,
    minimumTotalOdds: _doubleValue(row['minimum_total_odds']) ?? 1,
    maximumTotalOdds: _doubleValue(row['maximum_total_odds']),
    priority: _intValue(row['priority']) ?? 1,
    createdAt:
        DateTime.tryParse(row['created_at']?.toString() ?? '') ??
        DateTime.now().toUtc(),
    updatedAt:
        DateTime.tryParse(row['updated_at']?.toString() ?? '') ??
        DateTime.now().toUtc(),
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

List<Object?> _listValue(Object? value) {
  if (value is List<Object?>) {
    return value;
  }
  if (value is List) {
    return value;
  }
  return const [];
}

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

bool? _boolValue(Object? value) {
  return switch (value) {
    final bool boolean => boolean,
    final String text => bool.tryParse(text),
    _ => null,
  };
}

PickType? _pickTypeValue(Object? value) {
  return PickTypeCatalog.byId(value?.toString() ?? '')?.id;
}
