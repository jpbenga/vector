import 'package:flutter/foundation.dart';

enum IdentityScopeKind { device, guest, account, legacyUnowned }

@immutable
class IdentityScope {
  const IdentityScope._(this.kind, this.id);

  const IdentityScope.device() : this._(IdentityScopeKind.device, 'device');

  const IdentityScope.guest(String guestId)
    : this._(IdentityScopeKind.guest, guestId);

  const IdentityScope.account(String userId)
    : this._(IdentityScopeKind.account, userId);

  const IdentityScope.legacyUnowned()
    : this._(IdentityScopeKind.legacyUnowned, 'legacy-unowned');

  final IdentityScopeKind kind;
  final String id;

  bool get isDevice => kind == IdentityScopeKind.device;
  bool get isGuest => kind == IdentityScopeKind.guest;
  bool get isAccount => kind == IdentityScopeKind.account;
  bool get isLegacyUnowned => kind == IdentityScopeKind.legacyUnowned;
  bool get isUserOwned => isGuest || isAccount;

  String get stableKey => '${kind.name}:$id';

  @override
  bool operator ==(Object other) {
    return other is IdentityScope && other.kind == kind && other.id == id;
  }

  @override
  int get hashCode => Object.hash(kind, id);

  @override
  String toString() => 'IdentityScope($stableKey)';
}
