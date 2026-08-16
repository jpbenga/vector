import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../supabase/supabase_initializer.dart';
import 'oauth_redirect_cleaner.dart';

class SupabaseAuthController extends ChangeNotifier {
  SupabaseAuthController(this._initializer, this._config);

  final SupabaseInitializer _initializer;
  final AppConfig _config;
  StreamSubscription<AuthState>? _subscription;
  User? _user;

  SupabaseClient? get _client => _initializer.client;

  bool get isConfigured => _client != null;

  User? get user => _user ?? _client?.auth.currentUser;

  bool get isSignedIn => user != null;

  bool get isResolvingOAuthRedirect => _isResolvingOAuthRedirect;

  bool _isResolvingOAuthRedirect = false;

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

    await _resolveOAuthRedirectIfNeeded(client);
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

  Future<void> _resolveOAuthRedirectIfNeeded(SupabaseClient client) async {
    if (!kIsWeb || !Uri.base.queryParameters.containsKey('code')) {
      return;
    }

    _isResolvingOAuthRedirect = true;
    notifyListeners();

    try {
      final existingSession = client.auth.currentSession;
      if (existingSession != null) {
        _user = existingSession.user;
      } else {
        final response = await client.auth.exchangeCodeForSession(
          Uri.base.queryParameters['code']!,
        );
        _user = response.session.user;
      }
      cleanOAuthRedirectUrl();
    } on Object catch (error, stackTrace) {
      debugPrint('OAuth redirect resolution failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _isResolvingOAuthRedirect = false;
      _user = client.auth.currentUser ?? _user;
      notifyListeners();
    }
  }

  String? get _redirectTo {
    if (!kIsWeb) {
      return null;
    }

    return buildOAuthRedirectUrl(
      configuredUrl: _config.appPublicUrl,
      currentUrl: Uri.base,
    ).toString();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

@visibleForTesting
Uri buildOAuthRedirectUrl({
  required Uri? configuredUrl,
  required Uri currentUrl,
}) {
  final currentPath = currentUrl.path.isEmpty ? '/' : currentUrl.path;
  final currentQuery = currentUrl.query.isEmpty ? null : currentUrl.query;
  final base = configuredUrl ?? currentUrl;

  return base.replace(path: currentPath, query: currentQuery).removeFragment();
}
