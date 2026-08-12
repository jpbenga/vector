// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

import '../../../core/supabase/supabase_user_scope.dart';
import '../domain/saved_ticket.dart';
import 'local_remote_ticket_sync.dart';
import 'supabase_saved_ticket_repository.dart';

class SavedTicketStore {
  const SavedTicketStore();

  static const _storageKey = 'vector.saved_tickets.v1';
  static const _cookieKey = 'vector_saved_tickets_v1';

  Future<List<SavedTicket>> load() async {
    final localTickets = _loadLocal();
    final scope = SupabaseUserScope.current();
    if (scope == null) {
      return localTickets;
    }

    try {
      final remoteRepository = SupabaseSavedTicketRepository(scope);
      final remoteTickets = await remoteRepository.load();
      final mergedTickets = mergeSavedTickets(
        localTickets: localTickets,
        remoteTickets: remoteTickets,
      );
      if (!savedTicketsEqual(remoteTickets, mergedTickets)) {
        await remoteRepository.saveAll(mergedTickets);
      }
      if (!savedTicketsEqual(localTickets, mergedTickets)) {
        _saveAllLocal(mergedTickets);
      }

      return mergedTickets;
    } on Object {
      return localTickets;
    }
  }

  Future<void> saveAll(List<SavedTicket> tickets) async {
    _saveAllLocal(tickets);
    final scope = SupabaseUserScope.current();
    if (scope == null) {
      return;
    }

    try {
      await SupabaseSavedTicketRepository(scope).saveAll(tickets);
    } on Object {
      // Local persistence remains the fallback in dev/offline mode.
    }
  }

  Future<void> upsert(SavedTicket ticket) async {
    final tickets = await load();
    final updated = [
      for (final savedTicket in tickets)
        if (savedTicket.id != ticket.id) savedTicket,
      ticket,
    ];
    _saveAllLocal(updated);

    final scope = SupabaseUserScope.current();
    if (scope == null) {
      return;
    }

    try {
      await SupabaseSavedTicketRepository(scope).upsert(ticket);
    } on Object {
      // Local persistence remains the fallback in dev/offline mode.
    }
  }

  Future<void> delete(String ticketId) async {
    final tickets = await load();
    _saveAllLocal([
      for (final ticket in tickets)
        if (ticket.id != ticketId) ticket,
    ]);

    final scope = SupabaseUserScope.current();
    if (scope == null) {
      return;
    }

    try {
      await SupabaseSavedTicketRepository(scope).delete(ticketId);
    } on Object {
      // Local persistence remains the fallback in dev/offline mode.
    }
  }

  List<SavedTicket> _loadLocal() {
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
        for (final ticket in decoded) SavedTicket.fromJson(_mapValue(ticket)),
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } on FormatException {
      return const [];
    }
  }

  void _saveAllLocal(List<SavedTicket> tickets) {
    final normalized = [...tickets]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final encoded = Uri.encodeComponent(
      jsonEncode([for (final ticket in normalized) ticket.toJson()]),
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
