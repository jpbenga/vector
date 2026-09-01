import 'identity_scope.dart';

class ScopedOperationToken {
  const ScopedOperationToken({required this.scope, required this.revision});

  final IdentityScope scope;
  final int revision;
}
