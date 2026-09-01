import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/identity/identity_scope.dart';
import '../../../core/identity/scoped_data_keys.dart';
import '../../../core/identity/scoped_persistence.dart';
import '../../../core/supabase/supabase_initializer.dart';
import '../domain/saved_ticket.dart';
import 'supabase_saved_ticket_repository.dart';

class SavedTicketStore {
  const SavedTicketStore({ScopedPersistence? persistence})
    : _persistence = persistence;

  static const legacyStorageKey = 'vector.saved_tickets.v1';
  static const legacyCookieKey = 'vector_saved_tickets_v1';

  final ScopedPersistence? _persistence;

  Future<List<SavedTicket>> load({required IdentityScope scope}) async {
    _ensureUserOwned(scope);
    if (scope.isGuest) {
      return _loadLocal(scope);
    }

    try {
      final remoteRepository = SupabaseSavedTicketRepository(
        client: _accountClient(),
        scope: scope,
      );
      final remoteTickets = await remoteRepository.load();
      await _saveAllLocal(scope, remoteTickets);
      return remoteTickets;
    } on Object catch (error) {
      debugPrint('Remote saved ticket load failed: $error');
      return _loadLocal(scope);
    }
  }

  Future<void> saveAll({
    required IdentityScope scope,
    required List<SavedTicket> tickets,
  }) async {
    _ensureUserOwned(scope);
    if (scope.isGuest) {
      await _saveAllLocal(scope, tickets);
      return;
    }

    try {
      await SupabaseSavedTicketRepository(
        client: _accountClient(),
        scope: scope,
      ).saveAll(tickets);
      await _saveAllLocal(scope, tickets);
    } on Object catch (error) {
      debugPrint('Remote saved ticket saveAll failed: $error');
      rethrow;
    }
  }

  Future<void> upsert({
    required IdentityScope scope,
    required SavedTicket ticket,
  }) async {
    _ensureUserOwned(scope);
    final tickets = await load(scope: scope);
    final updated = [
      for (final savedTicket in tickets)
        if (savedTicket.id != ticket.id) savedTicket,
      ticket,
    ];
    if (scope.isGuest) {
      await _saveAllLocal(scope, updated);
      return;
    }

    try {
      await SupabaseSavedTicketRepository(
        client: _accountClient(),
        scope: scope,
      ).upsert(ticket);
      await _saveAllLocal(scope, updated);
    } on Object catch (error) {
      debugPrint('Remote saved ticket upsert failed: $error');
      rethrow;
    }
  }

  Future<void> delete({
    required IdentityScope scope,
    required String ticketId,
  }) async {
    _ensureUserOwned(scope);
    final tickets = await load(scope: scope);
    final updated = [
      for (final ticket in tickets)
        if (ticket.id != ticketId) ticket,
    ];
    if (scope.isGuest) {
      await _saveAllLocal(scope, updated);
      return;
    }

    try {
      await SupabaseSavedTicketRepository(
        client: _accountClient(),
        scope: scope,
      ).delete(ticketId);
      await _saveAllLocal(scope, updated);
    } on Object catch (error) {
      debugPrint('Remote saved ticket delete failed: $error');
      rethrow;
    }
  }

  ScopedPersistence get _scopedPersistence =>
      _persistence ?? const ScopedPersistence();

  Future<List<SavedTicket>> _loadLocal(IdentityScope scope) async {
    final raw = await _scopedPersistence.read(
      scope,
      ScopedDataKeys.savedTickets,
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
        for (final ticket in decoded) SavedTicket.fromJson(_mapValue(ticket)),
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } on FormatException {
      return const [];
    }
  }

  Future<void> _saveAllLocal(
    IdentityScope scope,
    List<SavedTicket> tickets,
  ) async {
    final normalized = [...tickets]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final encoded = Uri.encodeComponent(
      jsonEncode([for (final ticket in normalized) ticket.toJson()]),
    );
    await _scopedPersistence.write(scope, ScopedDataKeys.savedTickets, encoded);
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
