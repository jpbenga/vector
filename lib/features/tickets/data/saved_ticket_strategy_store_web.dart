// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/foundation.dart';

import '../../../core/supabase/supabase_user_scope.dart';
import '../domain/ticket_strategy.dart';
import 'local_remote_ticket_sync.dart';
import 'supabase_ticket_strategy_repository.dart';

class SavedTicketStrategyStore {
  const SavedTicketStrategyStore();

  static const _storageKey = 'vector.saved_ticket_strategies.v1';
  static const _cookieKey = 'vector_saved_ticket_strategies_v1';

  Future<List<TicketStrategy>> load() async {
    final localStrategies = _loadLocal();
    final scope = SupabaseUserScope.current();
    if (scope == null) {
      return localStrategies;
    }

    try {
      final remoteRepository = SupabaseTicketStrategyRepository(scope);
      final remoteStrategies = await remoteRepository.load();
      final mergedStrategies = mergeTicketStrategies(
        localStrategies: localStrategies,
        remoteStrategies: remoteStrategies,
      );
      if (!ticketStrategiesEqual(remoteStrategies, mergedStrategies)) {
        await remoteRepository.saveAll(mergedStrategies);
      }
      if (!ticketStrategiesEqual(localStrategies, mergedStrategies)) {
        _saveLocal(mergedStrategies);
      }

      return mergedStrategies;
    } on Object catch (error) {
      debugPrint('Remote ticket strategy sync failed: $error');
      return localStrategies;
    }
  }

  Future<void> save(List<TicketStrategy> strategies) async {
    _saveLocal(strategies);
    final scope = SupabaseUserScope.current();
    if (scope == null) {
      return;
    }

    try {
      await SupabaseTicketStrategyRepository(scope).saveAll(strategies);
    } on Object catch (error) {
      debugPrint('Remote ticket strategy save failed: $error');
      // Local persistence remains the fallback in dev/offline mode.
    }
  }

  List<TicketStrategy> _loadLocal() {
    final raw = html.window.localStorage[_storageKey] ?? _cookieValue();
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

  void _saveLocal(List<TicketStrategy> strategies) {
    final encoded = Uri.encodeComponent(
      jsonEncode([for (final strategy in strategies) strategy.toJson()]),
    );
    html.window.localStorage[_storageKey] = encoded;
    html.document.cookie =
        '$_cookieKey=$encoded; path=/; max-age=31536000; SameSite=Lax';
  }

  String? _cookieValue() {
    final cookies = html.document.cookie?.split(';') ?? const [];
    for (final cookie in cookies) {
      final separator = cookie.indexOf('=');
      if (separator == -1) {
        continue;
      }

      final key = cookie.substring(0, separator).trim();
      if (key == _cookieKey) {
        return cookie.substring(separator + 1).trim();
      }
    }

    return null;
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
