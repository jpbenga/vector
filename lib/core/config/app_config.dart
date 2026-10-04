import 'package:flutter/foundation.dart';

import 'app_environment.dart';

class AppConfig {
  const AppConfig({
    required this.environment,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    this.appPublicUrl,
    this.matchFeedSource = 'auto',
    this.sportFeedBaseUrl,
  });

  final AppEnvironment environment;
  final Uri? supabaseUrl;
  final String? supabaseAnonKey;
  final Uri? appPublicUrl;
  final String matchFeedSource;
  final Uri? sportFeedBaseUrl;

  bool get isSupabaseConfigured {
    return supabaseUrl != null &&
        supabaseAnonKey != null &&
        supabaseAnonKey!.isNotEmpty;
  }

  factory AppConfig.fromEnvironment() {
    const environmentValue = String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'development',
    );
    const supabaseUrlValue = String.fromEnvironment('SUPABASE_URL');
    const supabaseAnonKeyValue = String.fromEnvironment('SUPABASE_ANON_KEY');
    const appPublicUrlValue = String.fromEnvironment('APP_PUBLIC_URL');
    const matchFeedSourceValue = String.fromEnvironment(
      'MATCH_FEED_SOURCE',
      defaultValue: 'auto',
    );

    const sportFeedBaseUrlValue = String.fromEnvironment('SPORT_FEED_BASE_URL');
    final environment = AppEnvironment.parse(environmentValue);
    final sportFeedBaseUrl = _parseOptionalUri(
      'SPORT_FEED_BASE_URL',
      sportFeedBaseUrlValue,
    );
    if (sportFeedBaseUrl != null &&
        (environment == AppEnvironment.production ||
            sportFeedBaseUrl.scheme != 'http' ||
            !['localhost', '127.0.0.1'].contains(sportFeedBaseUrl.host))) {
      throw StateError(
        'The sport preview server is restricted to local development.',
      );
    }
    final supabaseUrl = _parseSupabaseUrl(supabaseUrlValue);
    final appPublicUrl = _parseOptionalUri('APP_PUBLIC_URL', appPublicUrlValue);
    final supabaseAnonKey = supabaseAnonKeyValue.isEmpty
        ? null
        : supabaseAnonKeyValue;

    final config = AppConfig(
      environment: environment,
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
      appPublicUrl: appPublicUrl,
      matchFeedSource: matchFeedSourceValue,
      sportFeedBaseUrl: sportFeedBaseUrl,
    );

    if (environment == AppEnvironment.production &&
        !config.isSupabaseConfigured) {
      throw StateError(
        'SUPABASE_URL and SUPABASE_ANON_KEY are required in production.',
      );
    }

    return config;
  }

  static Uri? _parseOptionalUri(String name, String value) {
    if (value.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw ArgumentError.value(value, name, 'Must be an absolute URL.');
    }

    return uri;
  }

  static Uri? _parseSupabaseUrl(String value) {
    final uri = _parseOptionalUri('SUPABASE_URL', value);
    if (uri == null) {
      return null;
    }

    final origin = Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
    );

    if (uri.pathSegments.isNotEmpty || uri.hasQuery || uri.hasFragment) {
      debugPrint(
        'SUPABASE_URL must be the project origin only. '
        'Using $origin instead of the provided URL.',
      );
    }

    return origin;
  }
}
