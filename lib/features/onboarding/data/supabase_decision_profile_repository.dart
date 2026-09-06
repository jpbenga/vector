import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/debug/runtime_personalization_diagnostic.dart';
import '../../../core/identity/identity_scope.dart';
import '../domain/compiled_decision_profile.dart';
import '../domain/decision_profile.dart';
import '../domain/profile_compiler.dart';

class SupabaseDecisionProfileRepository {
  SupabaseDecisionProfileRepository({
    required this.client,
    required IdentityScope scope,
  }) : assert(scope.isAccount),
       _userId = scope.id;

  final SupabaseClient client;
  final String _userId;

  Future<DecisionProfile?> load() async {
    await _traceProfileRows();
    final row = await client
        .from('profiles')
        .select('decision_profile')
        .eq('user_id', _userId)
        .eq('is_active', true)
        .maybeSingle();

    final payload = row?['decision_profile'];
    if (payload is Map<String, Object?>) {
      return DecisionProfile.fromJson(payload);
    }
    if (payload is Map) {
      return DecisionProfile.fromJson(_mapValue(payload));
    }

    return null;
  }

  Future<void> _traceProfileRows() async {
    if (!RuntimePersonalizationDiagnostic.instance.isEnabled) return;
    try {
      final List<Map<String, dynamic>> rows = await client
          .from('profiles')
          .select(
            'id,user_id,is_active,created_at,updated_at,profile_schema_version,decision_profile',
          )
          .eq('user_id', _userId);
      final normalizedRows = rows.map(_traceRow).toList(growable: false);
      RuntimePersonalizationDiagnostic.instance.recordProfileRows(
        normalizedRows,
      );
      RuntimePersonalizationDiagnostic.instance.recordLifecycle(
        'profile rows fetched',
        fields: {
          'userId': _userId,
          'rowCount': normalizedRows.length,
          'activeRowCount': normalizedRows
              .where((row) => row['is_active'] == true)
              .length,
          'rows': normalizedRows,
        },
      );
    } on Object catch (error) {
      RuntimePersonalizationDiagnostic.instance.recordLifecycle(
        'profile rows fetch failed',
        fields: {'userId': _userId, 'error': error.toString()},
      );
    }
  }

  Map<String, Object?> _traceRow(Map<String, dynamic> row) {
    return {
      'id': row['id']?.toString(),
      'user_id': row['user_id']?.toString(),
      'is_active': row['is_active'],
      'created_at': row['created_at']?.toString(),
      'updated_at': row['updated_at']?.toString(),
      'decision_profile_version': row['profile_schema_version'],
    };
  }

  Future<void> save(DecisionProfile profile) async {
    final compiledProfile = const ProfileCompiler().compile(profile);
    final existing = await client
        .from('profiles')
        .select('id')
        .eq('user_id', _userId)
        .eq('is_active', true)
        .maybeSingle();
    final row = {
      'user_id': _userId,
      'is_active': true,
      'profile_schema_version': compiledProfile.profileSchemaVersion,
      'onboarding_version': profile.onboardingVersion,
      'configuration_state': compiledProfile.configurationState.name,
      'decision_profile': profile.toJson(),
      'compiled_profile': _compiledProfileJson(compiledProfile),
      'compatibility': _compatibilityJson(compiledProfile),
    };

    final profileId = existing?['id']?.toString();
    if (profileId == null || profileId.isEmpty) {
      await client.from('profiles').insert(row);
      return;
    }

    await client
        .from('profiles')
        .update(row)
        .eq('user_id', _userId)
        .eq('id', profileId);
  }
}

Map<String, Object?> _compiledProfileJson(
  CompiledDecisionProfile compiledProfile,
) {
  return {
    'profileSchemaVersion': compiledProfile.profileSchemaVersion,
    'onboardingVersion': compiledProfile.onboardingVersion,
    'userId': compiledProfile.userId,
    'configurationState': compiledProfile.configurationState.name,
    'competitions': {
      for (final entry in compiledProfile.competitions.entries)
        entry.key: {
          'id': entry.value.id,
          'apiFootballLeagueId': entry.value.apiFootballLeagueId,
          'name': entry.value.name,
          'enabled': entry.value.enabled,
          'legacyIds': entry.value.legacyIds,
        },
    },
    'markets': {
      for (final entry in compiledProfile.markets.entries)
        entry.key: {
          'id': entry.value.id,
          'enabled': entry.value.enabled,
          'sourceOptionId': entry.value.sourceOptionId,
        },
    },
    'readings': {
      for (final entry in compiledProfile.readings.entries)
        entry.key: {'id': entry.value.id, 'enabled': entry.value.enabled},
    },
    'matchTypes': {
      for (final entry in compiledProfile.matchTypes.entries)
        entry.key: {'id': entry.value.id, 'enabled': entry.value.enabled},
    },
    'compatibility': _compatibilityJson(compiledProfile),
  };
}

Map<String, Object?> _compatibilityJson(
  CompiledDecisionProfile compiledProfile,
) {
  return {
    'migratedFromSchemaVersion':
        compiledProfile.compatibility.migratedFromSchemaVersion,
    'ignoredLegacyQuestionIds':
        compiledProfile.compatibility.ignoredLegacyQuestionIds,
  };
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
