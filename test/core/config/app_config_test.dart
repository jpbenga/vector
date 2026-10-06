import 'package:copilot/core/config/app_config.dart';
import 'package:copilot/core/config/app_environment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig', () {
    test('hosted sport demo stays on its own origin from any app route', () {
      final origin = AppConfig.hostedSportDemoBaseUrl(
        environment: AppEnvironment.staging,
        currentUrl: Uri.parse(
          'https://demo.vercel.app/sports/hockey?code=demo#tab',
        ),
      );
      expect(origin.toString(), 'https://demo.vercel.app/');
      expect(
        origin.resolve('sports/hockey/feed').toString(),
        'https://demo.vercel.app/sports/hockey/feed',
      );
    });

    test(
      'hosted sport demo cannot replace production or use insecure remote data',
      () {
        for (final environment in [
          AppEnvironment.production,
          AppEnvironment.development,
        ]) {
          expect(
            () => AppConfig.hostedSportDemoBaseUrl(
              environment: environment,
              currentUrl: Uri.parse('https://demo.vercel.app/'),
            ),
            throwsStateError,
          );
        }
        for (final url in [
          'http://remote.example/',
          'file:///app/',
          'https://user:password@demo.vercel.app/',
        ]) {
          expect(
            () => AppConfig.hostedSportDemoBaseUrl(
              environment: AppEnvironment.staging,
              currentUrl: Uri.parse(url),
            ),
            throwsStateError,
          );
        }
      },
    );

    test('hosted demo can be checked locally with the same transport', () {
      expect(
        AppConfig.hostedSportDemoBaseUrl(
          environment: AppEnvironment.staging,
          currentUrl: Uri.parse('http://localhost:8194/sports/hockey'),
        ).toString(),
        'http://localhost:8194/',
      );
    });

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
