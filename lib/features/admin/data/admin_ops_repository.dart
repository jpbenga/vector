import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/admin_ops_models.dart';

class AdminOpsRepository {
  const AdminOpsRepository(this._client);

  final SupabaseClient _client;

  Future<AdminOpsOverview> loadOverview() async {
    final response = await _client.functions.invoke(
      'admin-ops',
      method: HttpMethod.get,
      headers: _authHeaders(),
    );
    final data = _objectMap(response.data);
    if (response.status >= 400 || data == null || data['ok'] != true) {
      throw AdminOpsException(_errorMessage(data, response.status));
    }
    return AdminOpsOverview.fromJson(data);
  }

  Future<AdminOperationResult> rerunLeague(int leagueId) async {
    final response = await _client.functions.invoke(
      'admin-ops',
      headers: _authHeaders(),
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

  Map<String, String> _authHeaders() {
    final accessToken = _client.auth.currentSession?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      return const {};
    }
    return {'Authorization': 'Bearer $accessToken'};
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
