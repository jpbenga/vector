import '../../../core/supabase/supabase_user_scope.dart';
import '../domain/compiled_decision_profile.dart';
import '../domain/decision_profile.dart';
import '../domain/profile_compiler.dart';

class SupabaseDecisionProfileRepository {
  const SupabaseDecisionProfileRepository(this._scope);

  final SupabaseUserScope _scope;

  Future<DecisionProfile?> load() async {
    final row = await _scope.client
        .from('profiles')
        .select('decision_profile')
        .eq('user_id', _scope.userId)
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

  Future<void> save(DecisionProfile profile) async {
    final compiledProfile = const ProfileCompiler().compile(profile);
    final existing = await _scope.client
        .from('profiles')
        .select('id')
        .eq('user_id', _scope.userId)
        .eq('is_active', true)
        .maybeSingle();
    final row = {
      'user_id': _scope.userId,
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
      await _scope.client.from('profiles').insert(row);
      return;
    }

    await _scope.client
        .from('profiles')
        .update(row)
        .eq('user_id', _scope.userId)
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
