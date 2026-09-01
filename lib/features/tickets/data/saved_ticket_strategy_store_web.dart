import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/identity/identity_scope.dart';
import '../../../core/identity/scoped_data_keys.dart';
import '../../../core/identity/scoped_persistence.dart';
import '../../../core/supabase/supabase_initializer.dart';
import '../domain/ticket_strategy.dart';
import 'supabase_ticket_strategy_repository.dart';

class SavedTicketStrategyStore {
  const SavedTicketStrategyStore({this.persistence});

  static const legacyStorageKey = 'vector.saved_ticket_strategies.v1';
  static const legacyCookieKey = 'vector_saved_ticket_strategies_v1';

  final ScopedPersistence? persistence;

  Future<List<TicketStrategy>> load({required IdentityScope scope}) async {
    _ensureUserOwned(scope);
    if (scope.isGuest) {
      return _loadLocal(scope);
    }

    try {
      final remoteRepository = SupabaseTicketStrategyRepository(
        client: _accountClient(),
        scope: scope,
      );
      final remoteStrategies = await remoteRepository.load();
      await _saveLocal(scope, remoteStrategies);
      return remoteStrategies;
    } on Object catch (error) {
      debugPrint('Remote ticket strategy load failed: $error');
      return _loadLocal(scope);
    }
  }

  Future<void> save({
    required IdentityScope scope,
    required List<TicketStrategy> strategies,
  }) async {
    _ensureUserOwned(scope);
    if (scope.isGuest) {
      await _saveLocal(scope, strategies);
      return;
    }

    try {
      await SupabaseTicketStrategyRepository(
        client: _accountClient(),
        scope: scope,
      ).saveAll(strategies);
      await _saveLocal(scope, strategies);
    } on Object catch (error) {
      debugPrint('Remote ticket strategy save failed: $error');
      rethrow;
    }
  }

  ScopedPersistence get _scopedPersistence =>
      persistence ?? const ScopedPersistence();

  Future<List<TicketStrategy>> _loadLocal(IdentityScope scope) async {
    final raw = await _scopedPersistence.read(
      scope,
      ScopedDataKeys.ticketStrategies,
    );
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(Uri.decodeComponent(raw));
      if (decoded is! List) {
        return const [];
      }

      return [
        for (final strategy in decoded)
          TicketStrategy.fromJson(_mapValue(strategy)),
      ];
    } on FormatException {
      return const [];
    }
  }

  Future<void> _saveLocal(
    IdentityScope scope,
    List<TicketStrategy> strategies,
  ) async {
    final encoded = Uri.encodeComponent(
      jsonEncode([for (final strategy in strategies) strategy.toJson()]),
    );
    await _scopedPersistence.write(
      scope,
      ScopedDataKeys.ticketStrategies,
      encoded,
    );
  }

  SupabaseClient _accountClient() {
    final client = getIt<SupabaseInitializer>().client;
    if (client == null) {
      throw StateError('Supabase is not configured.');
    }
    return client;
  }

  void _ensureUserOwned(IdentityScope scope) {
    if (!scope.isUserOwned) {
      throw ArgumentError.value(scope, 'scope', 'Must be guest or account.');
    }
  }
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
