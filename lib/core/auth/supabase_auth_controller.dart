import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_initializer.dart';

class SupabaseAuthController extends ChangeNotifier {
  SupabaseAuthController(this._initializer);

  final SupabaseInitializer _initializer;
  StreamSubscription<AuthState>? _subscription;
  User? _user;

  SupabaseClient? get _client => _initializer.client;

  bool get isConfigured => _client != null;

  User? get user => _user ?? _client?.auth.currentUser;

  bool get isSignedIn => user != null;

  Future<void> start() async {
    final client = _client;
    if (client == null || _subscription != null) {
      return;
    }

    _user = client.auth.currentUser;
    _subscription = client.auth.onAuthStateChange.listen((event) {
      _user = event.session?.user ?? client.auth.currentUser;
      notifyListeners();
    });
  }

  Future<void> signInWithGoogle() {
    return _signInWithProvider(OAuthProvider.google);
  }

  Future<void> signInWithApple() {
    return _signInWithProvider(OAuthProvider.apple);
  }

  Future<void> signOut() async {
    final client = _client;
    if (client == null) {
      return;
    }

    await client.auth.signOut();
    _user = null;
    notifyListeners();
  }

  Future<void> _signInWithProvider(OAuthProvider provider) async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is not configured.');
    }

    await client.auth.signInWithOAuth(provider, redirectTo: _redirectTo);
  }

  String? get _redirectTo {
    if (!kIsWeb) {
      return null;
    }

    final uri = Uri.base.removeFragment();
    return uri.toString();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
