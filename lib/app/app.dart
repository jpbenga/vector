import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/config/app_config.dart';
import '../core/di/service_locator.dart';
import '../core/theme/app_theme_controller.dart';
import '../l10n/generated/app_localizations.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class CopilotApp extends StatefulWidget {
  const CopilotApp({super.key});

  @override
  State<CopilotApp> createState() => _CopilotAppState();
}

class _CopilotAppState extends State<CopilotApp> {
  late final _router = createAppRouter(getIt<AppConfig>());

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemeVariant>(
      valueListenable: appThemeController,
      builder: (context, themeVariant, _) {
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: 'Lector Sport',
          theme: AppTheme.forVariant(themeVariant),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: _router,
        );
      },
    );
  }
}
