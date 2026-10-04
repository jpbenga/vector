import '../../identity/identity_scope.dart';
import '../../identity/scoped_persistence.dart';
import '../domain/sport.dart';

/// Football retains exactly its existing keys. All new sports use a separate
/// namespace under the existing account/guest identity boundary.
class ScopedSportPersistence {
  const ScopedSportPersistence({
    required this.persistence,
    required this.sport,
  });
  final ScopedPersistence persistence;
  final SportId sport;

  String _resource(String resource) {
    sport.validate();
    if (resource.trim().isEmpty) {
      throw ArgumentError('An explicit resource is required.');
    }
    return sport == SportId.football
        ? resource
        : 'sports:${sport.key}:v1:$resource';
  }

  String keyFor(IdentityScope scope, String resource) =>
      persistence.keyFor(scope, _resource(resource));
  Future<String?> read(IdentityScope scope, String resource) =>
      persistence.read(scope, _resource(resource));
  Future<void> write(IdentityScope scope, String resource, String value) =>
      persistence.write(scope, _resource(resource), value);
  Future<void> delete(IdentityScope scope, String resource) =>
      persistence.delete(scope, _resource(resource));
}
