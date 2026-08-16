import 'package:copilot/core/auth/supabase_auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SupabaseAuthController OAuth redirect', () {
    test('keeps the current web path when APP_PUBLIC_URL is configured', () {
      final redirect = buildOAuthRedirectUrl(
        configuredUrl: Uri.parse('https://lector-sports.vercel.app/'),
        currentUrl: Uri.parse('http://localhost:8099/admin'),
      );

      expect(redirect.toString(), 'https://lector-sports.vercel.app/admin');
    });

    test('keeps the current query and strips fragments', () {
      final redirect = buildOAuthRedirectUrl(
        configuredUrl: Uri.parse('https://preview.vercel.app/'),
        currentUrl: Uri.parse('http://localhost:8099/admin?tab=runs#section'),
      );

      expect(redirect.toString(), 'https://preview.vercel.app/admin?tab=runs');
    });

    test('falls back to the current URL when APP_PUBLIC_URL is missing', () {
      final redirect = buildOAuthRedirectUrl(
        configuredUrl: null,
        currentUrl: Uri.parse('http://192.168.0.46:8099/admin#ignored'),
      );

      expect(redirect.toString(), 'http://192.168.0.46:8099/admin');
    });
  });
}
