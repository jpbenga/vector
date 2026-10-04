import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/identity/identity_scope.dart';
import '../domain/radar_audience_filter.dart';

abstract interface class RadarAudienceFilterStore {
  Future<RadarAudienceFilter> load(IdentityScope scope);
  Future<void> save(IdentityScope scope, RadarAudienceFilter filter);
}

class SharedPreferencesRadarAudienceFilterStore
    implements RadarAudienceFilterStore {
  const SharedPreferencesRadarAudienceFilterStore();

  String _key(IdentityScope scope) =>
      'lector.radar.audience.v1:${scope.stableKey}';

  @override
  Future<RadarAudienceFilter> load(IdentityScope scope) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key(scope));
    if (raw == null) return const RadarAudienceFilter();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return RadarAudienceFilter.fromJson(decoded);
      }
    } on FormatException {
      // Corrupt local preferences must not expose excluded categories.
    }
    return const RadarAudienceFilter();
  }

  @override
  Future<void> save(IdentityScope scope, RadarAudienceFilter filter) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key(scope), jsonEncode(filter.toJson()));
  }
}
