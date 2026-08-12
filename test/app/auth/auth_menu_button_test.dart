import 'package:copilot/app/auth/auth_menu_button.dart';
import 'package:copilot/core/config/app_config.dart';
import 'package:copilot/core/config/app_environment.dart';
import 'package:copilot/core/di/service_locator.dart';
import 'package:copilot/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows local mode when Supabase is not configured', (
    tester,
  ) async {
    await configureDependencies(
      const AppConfig(
        environment: AppEnvironment.development,
        supabaseUrl: null,
        supabaseAnonKey: null,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: CopilotTheme.dark.copyWith(
          splashFactory: NoSplash.splashFactory,
        ),
        home: const Scaffold(body: AuthMenuButton()),
      ),
    );

    await tester.tap(find.byIcon(Icons.person_outline_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.text('Invité'), findsOneWidget);
    expect(find.text('Mode invité'), findsOneWidget);
    expect(find.textContaining('Mode local actif'), findsOneWidget);
    expect(find.text('Continuer avec Google'), findsOneWidget);
    expect(find.text('Continuer avec Apple'), findsOneWidget);
    expect(find.text('Bientôt'), findsOneWidget);
    expect(find.text('Continuer plus tard'), findsOneWidget);

    final googleButton = tester.widget<OutlinedButton>(
      find
          .ancestor(
            of: find.text('Continuer avec Google'),
            matching: find.byType(OutlinedButton),
          )
          .first,
    );
    final appleButton = tester.widget<OutlinedButton>(
      find
          .ancestor(
            of: find.text('Continuer avec Apple'),
            matching: find.byType(OutlinedButton),
          )
          .first,
    );

    expect(googleButton.onPressed, isNull);
    expect(appleButton.onPressed, isNull);
  });

  testWidgets('can expose an in-app guest sign-in entry point', (tester) async {
    await configureDependencies(
      const AppConfig(
        environment: AppEnvironment.development,
        supabaseUrl: null,
        supabaseAnonKey: null,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: CopilotTheme.dark.copyWith(
          splashFactory: NoSplash.splashFactory,
        ),
        home: const Scaffold(
          body: Center(child: AuthMenuButton(showGuestLabel: true)),
        ),
      ),
    );

    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
  });
}
