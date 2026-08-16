import 'package:supabase_flutter/supabase_flutter.dart';

class TemporaryAccessLinkRepository {
  const TemporaryAccessLinkRepository(this._client);

  final SupabaseClient _client;

  Future<TemporaryAccessResult> redeem(String token) async {
    final response = await _client.functions.invoke(
      'admin-ops',
      body: {'action': 'redeem_test_link', 'token': token},
    );
    final data = _objectMap(response.data);
    if (response.status >= 400 || data == null || data['ok'] != true) {
      return TemporaryAccessResult.denied(_errorMessage(data, response.status));
    }
    return TemporaryAccessResult.allowed(
      expiresAt: _dateTime(data['expires_at']),
      environment: _string(data['environment']) ?? 'unknown',
    );
  }
}

class TemporaryAccessResult {
  const TemporaryAccessResult._({
    required this.isAllowed,
    required this.environment,
    required this.expiresAt,
    required this.errorMessage,
  });

  final bool isAllowed;
  final String? environment;
  final DateTime? expiresAt;
  final String? errorMessage;

  factory TemporaryAccessResult.allowed({
    required String environment,
    required DateTime? expiresAt,
  }) {
    return TemporaryAccessResult._(
      isAllowed: true,
      environment: environment,
      expiresAt: expiresAt,
      errorMessage: null,
    );
  }

  factory TemporaryAccessResult.denied(String message) {
    return TemporaryAccessResult._(
      isAllowed: false,
      environment: null,
      expiresAt: null,
      errorMessage: message,
    );
  }
}

Map<String, Object?>? _objectMap(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return {
      for (final entry in value.entries)
        if (entry.key != null) entry.key.toString(): entry.value,
    };
  }
  return null;
}

String? _string(Object? value) => value is String ? value : null;

DateTime? _dateTime(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}

String _errorMessage(Map<String, Object?>? data, int status) {
  final error = data?['error'];
  if (error is String && error.isNotEmpty) {
    return error;
  }
  return 'Temporary access failed with status $status.';
}
