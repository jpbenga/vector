import 'package:copilot/app/auth/lector_account_sheet.dart';
import 'package:copilot/app/theme/app_theme.dart';
import 'package:copilot/core/auth/supabase_auth_controller.dart';
import 'package:copilot/core/config/app_config.dart';
import 'package:copilot/core/config/app_environment.dart';
import 'package:copilot/core/di/service_locator.dart';
import 'package:copilot/core/supabase/supabase_initializer.dart';
import 'package:copilot/features/hockey/presentation/hockey_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _config = AppConfig(
  environment: AppEnvironment.development,
  supabaseUrl: null,
  supabaseAnonKey: null,
);

class _Auth extends SupabaseAuthController {
  _Auth() : super(SupabaseInitializer(_config), _config);

  bool googleStarted = false;
  String? passwordEmail;
  @override
  bool get isConfigured => true;
  @override
  bool get isSignedIn => false;
  @override
  User? get user => null;
  @override
  Future<void> signInWithGoogle() async => googleStarted = true;
  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async => passwordEmail = email;
}

void main() {
  setUpAll(() => initializeDateFormatting('fr'));
  tearDown(() => getIt.reset());

  Future<void> openAccount(WidgetTester tester, _Auth auth) async {
    getIt.registerSingleton<SupabaseAuthController>(auth);
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: HockeyWorkspace(initialDate: DateTime(2026, 10, 4)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Connexion'));
    await tester.pumpAndSettle();
    expect(find.byType(LectorAccountSheet), findsOneWidget);
    expect(find.text('Continuer avec Google'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Adresse e-mail'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Mot de passe'), findsOneWidget);
  }

  testWidgets('hockey uses the shared account sheet and starts Google auth', (
    tester,
  ) async {
    final auth = _Auth();
    await openAccount(tester, auth);
    await tester.ensureVisible(find.text('Continuer avec Google'));
    await tester.tap(find.text('Continuer avec Google'));
    await tester.pumpAndSettle();
    expect(auth.googleStarted, isTrue);
    expect(find.byType(LectorAccountSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hockey can sign in with the same email form as football', (
    tester,
  ) async {
    final auth = _Auth();
    await openAccount(tester, auth);
    await tester.enterText(
      find.widgetWithText(TextField, 'Adresse e-mail'),
      'test@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Mot de passe'),
      'test-password',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.descendant(
        of: find.byType(LectorAccountSheet),
        matching: find.widgetWithText(FilledButton, 'Se connecter'),
      ),
    );
    await tester.tap(
      find.descendant(
        of: find.byType(LectorAccountSheet),
        matching: find.widgetWithText(FilledButton, 'Se connecter'),
      ),
    );
    await tester.pumpAndSettle();
    expect(auth.passwordEmail, 'test@example.com');
    expect(tester.takeException(), isNull);
  });
}
