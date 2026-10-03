import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/admin_ops_models.dart';

class AdminOpsRepository {
  const AdminOpsRepository(this._client);

  final SupabaseClient _client;

  Future<Map<String, dynamic>> operations(
    String action, [
    Map<String, Object?> payload = const {},
  ]) async {
    final response = await _invoke(body: {'action': action, ...payload});
    final data = _objectMap(response.data);
    if (response.status >= 400 || data == null || data['ok'] != true) {
      throw AdminOpsException(_errorMessage(data, response.status));
    }
    return Map<String, dynamic>.from(data);
  }

  Future<AdminOpsOverview> loadOverview() async {
    final response = await _invoke(method: HttpMethod.get);
    final data = _objectMap(response.data);
    if (response.status >= 400 || data == null || data['ok'] != true) {
      throw AdminOpsException(_errorMessage(data, response.status));
    }
    return AdminOpsOverview.fromJson(data);
  }

  Future<AdminOperationResult> rerunLeague(int leagueId) async {
    final response = await _invoke(
      body: {
        'action': 'rerun_league',
        'league_id': leagueId,
        'include_snapshot': true,
      },
    );
    final data = _objectMap(response.data);
    if (response.status >= 400 || data == null || data['ok'] != true) {
      throw AdminOpsException(_errorMessage(data, response.status));
    }
    return AdminOperationResult.fromJson(data);
  }

  Future<AdminTestLinkResult> createTestLink({
    required Uri baseUrl,
    int durationMinutes = 60,
    String? label,
  }) async {
    final response = await _invoke(
      body: {
        'action': 'create_test_link',
        'base_url': baseUrl.toString(),
        'duration_minutes': durationMinutes,
        if (label != null && label.trim().isNotEmpty) 'label': label.trim(),
      },
    );
    final data = _objectMap(response.data);
    if (response.status >= 400 || data == null || data['ok'] != true) {
      throw AdminOpsException(_errorMessage(data, response.status));
    }
    return AdminTestLinkResult.fromJson(data);
  }

  Future<FunctionResponse> _invoke({
    HttpMethod method = HttpMethod.post,
    Map<String, Object?>? body,
  }) async {
    Future<FunctionResponse> send() => _client.functions.invoke(
      'admin-ops',
      method: method,
      body: method == HttpMethod.get ? null : body,
    );

    try {
      return await send();
    } on FunctionException catch (error) {
      if (error.status != 401 || _client.auth.currentSession == null) {
        rethrow;
      }
    }

    // Let Supabase's authenticated HTTP client provide Authorization so it can
    // refresh an expired session. If the function still rejects a valid-looking
    // session, refresh once explicitly and retry with the newly issued token.
    try {
      await _client.auth.refreshSession();
    } on Object {
      await _client.auth.signOut();
      rethrow;
    }

    if (_client.auth.currentSession == null) {
      await _client.auth.signOut();
      throw const AdminOpsException(
        'La session a expiré. Reconnectez-vous pour ouvrir le pilotage.',
      );
    }

    try {
      return await send();
    } on FunctionException catch (error) {
      if (error.status == 401) {
        await _client.auth.signOut();
      }
      rethrow;
    }
  }
}

class AdminOpsException implements Exception {
  const AdminOpsException(this.message);

  final String message;

  @override
  String toString() => message;
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

String _errorMessage(Map<String, Object?>? data, int status) {
  final error = data?['error'];
  if (error is String && error.isNotEmpty) {
    return error;
  }
  return 'Admin operation failed with status $status.';
}
