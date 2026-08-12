import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

class SupabaseInitializer {
  SupabaseInitializer(this._config);

  final AppConfig _config;
  SupabaseClient? _client;

  SupabaseClient? get client => _client;

  Future<SupabaseClient?> initialize() async {
    if (!_config.isSupabaseConfigured) {
      return null;
    }

    if (_client != null) {
      return _client;
    }

    try {
      await Supabase.initialize(
        url: _config.supabaseUrl.toString(),
        publishableKey: _config.supabaseAnonKey!,
      );
      _client = Supabase.instance.client;
    } on Object catch (error, stackTrace) {
      debugPrint('Supabase initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _client = null;
    }

    return _client;
  }
}
