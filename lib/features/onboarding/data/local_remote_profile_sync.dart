import '../domain/decision_profile.dart';

DecisionProfile? resolveSyncedDecisionProfile({
  required DecisionProfile? localProfile,
  required DecisionProfile? remoteProfile,
}) {
  if (_hasUserAnswers(localProfile)) {
    return localProfile;
  }

  if (_hasUserAnswers(remoteProfile)) {
    return remoteProfile;
  }

  return localProfile ?? remoteProfile;
}

bool decisionProfilesEqual(DecisionProfile? first, DecisionProfile? second) {
  if (identical(first, second)) {
    return true;
  }
  if (first == null || second == null) {
    return false;
  }

  return _deepEquals(first.toJson(), second.toJson());
}

bool _hasUserAnswers(DecisionProfile? profile) {
  return profile != null && profile.answers.isNotEmpty;
}

bool _deepEquals(Object? first, Object? second) {
  if (first is Map && second is Map) {
    if (first.length != second.length) {
      return false;
    }
    for (final key in first.keys) {
      if (!second.containsKey(key) || !_deepEquals(first[key], second[key])) {
        return false;
      }
    }
    return true;
  }

  if (first is List && second is List) {
    if (first.length != second.length) {
      return false;
    }
    for (var index = 0; index < first.length; index++) {
      if (!_deepEquals(first[index], second[index])) {
        return false;
      }
    }
    return true;
  }

  return first == second;
}
