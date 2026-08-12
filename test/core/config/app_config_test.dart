import 'package:copilot/core/config/app_config.dart';
import 'package:copilot/core/config/app_environment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig', () {
    test('keeps the optional public app URL for OAuth redirects', () {
      final config = AppConfig(
        environment: AppEnvironment.staging,
        supabaseUrl: Uri.parse('https://project.supabase.co'),
        supabaseAnonKey: 'anon-key',
        appPublicUrl: Uri.parse('https://lector-sports.vercel.app/'),
      );

      expect(config.isSupabaseConfigured, isTrue);
      expect(
        config.appPublicUrl.toString(),
        'https://lector-sports.vercel.app/',
      );
    });
  });
}
