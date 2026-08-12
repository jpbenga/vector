import 'package:flutter/material.dart';

import '../../core/auth/supabase_auth_controller.dart';
import '../../core/theme/app_components.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';

class AuthEntryPage extends StatefulWidget {
  const AuthEntryPage({
    required this.controller,
    required this.onContinueLocal,
    super.key,
  });

  final SupabaseAuthController? controller;
  final VoidCallback onContinueLocal;

  @override
  State<AuthEntryPage> createState() => _AuthEntryPageState();
}

class _AuthEntryPageState extends State<AuthEntryPage> {
  bool _showSignIn = false;
  bool _isStartingGoogle = false;

  bool get _isGoogleAvailable => widget.controller?.isConfigured ?? false;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    return Scaffold(
      backgroundColor: surfaces.background,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _showSignIn
              ? _SignInStep(
                  key: const ValueKey('sign-in-step'),
                  isGoogleAvailable: _isGoogleAvailable,
                  isStartingGoogle: _isStartingGoogle,
                  onBack: () => setState(() => _showSignIn = false),
                  onGoogle: _startGoogleSignIn,
                  onContinueLocal: widget.onContinueLocal,
                )
              : _WelcomeStep(
                  key: const ValueKey('welcome-step'),
                  onStart: () => setState(() => _showSignIn = true),
                ),
        ),
      ),
    );
  }

  Future<void> _startGoogleSignIn() async {
    final controller = widget.controller;
    if (controller == null || !controller.isConfigured || _isStartingGoogle) {
      return;
    }

    setState(() => _isStartingGoogle = true);
    try {
      await controller.signInWithGoogle();
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isStartingGoogle = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connexion Google indisponible : $error')),
      );
    }
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.onStart, super.key});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = context.brand;
    final textColors = context.textColors;
    final surfaces = context.surfaces;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'LECTOR SPORT',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: textColors.primary,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Read the Game.',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: brand.accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: surfaces.surface,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: surfaces.border),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: brand.accent.withValues(alpha: 0.10),
                        border: Border.all(
                          color: brand.accent.withValues(alpha: 0.34),
                        ),
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: brand.accent,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Sports Intelligence',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: textColors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Analysez les lectures, construisez vos stratégies et retrouvez vos tickets sur tous vos appareils.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: textColors.secondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(onPressed: onStart, child: const Text('Commencer')),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignInStep extends StatelessWidget {
  const _SignInStep({
    required this.isGoogleAvailable,
    required this.isStartingGoogle,
    required this.onBack,
    required this.onGoogle,
    required this.onContinueLocal,
    super.key,
  });

  final bool isGoogleAvailable;
  final bool isStartingGoogle;
  final VoidCallback onBack;
  final VoidCallback onGoogle;
  final VoidCallback onContinueLocal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = context.brand;
    final textColors = context.textColors;
    final surfaces = context.surfaces;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: 'Retour',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Bienvenue dans Lector',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: textColors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Connectez-vous pour retrouver votre profil, vos stratégies et vos tickets sur plusieurs appareils.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: textColors.secondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            _ProviderAction(
              icon: Icons.g_mobiledata_rounded,
              label: isStartingGoogle
                  ? 'Connexion en cours...'
                  : 'Continuer avec Google',
              enabled: isGoogleAvailable && !isStartingGoogle,
              onPressed: onGoogle,
            ),
            const SizedBox(height: AppSpacing.sm),
            const _ProviderAction(
              icon: Icons.apple_rounded,
              label: 'Continuer avec Apple',
              enabled: false,
              trailingLabel: 'Bientôt',
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(child: Divider(color: surfaces.border)),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  child: Text(
                    'ou',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: textColors.weak,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: surfaces.border)),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton(
              onPressed: onContinueLocal,
              child: const Text('Continuer sans compte'),
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: surfaces.backgroundSecondary,
                borderRadius: BorderRadius.circular(AppRadius.input),
                border: Border.all(color: surfaces.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    color: isGoogleAvailable ? brand.accent : textColors.weak,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      isGoogleAvailable
                          ? 'L’authentification est gérée par Google et Supabase Auth. Lector ne reçoit jamais votre mot de passe.'
                          : 'Mode local actif. Ajoutez SUPABASE_URL et SUPABASE_ANON_KEY pour activer Google.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: textColors.secondary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderAction extends StatelessWidget {
  const _ProviderAction({
    required this.icon,
    required this.label,
    required this.enabled,
    this.onPressed,
    this.trailingLabel,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback? onPressed;
  final String? trailingLabel;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final textColors = context.textColors;
    final surfaces = context.surfaces;

    return OutlinedButton(
      onPressed: enabled ? onPressed : null,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        alignment: Alignment.centerLeft,
      ),
      child: Row(
        children: [
          Icon(icon, color: enabled ? brand.accent : textColors.disabled),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label)),
          if (trailingLabel != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: surfaces.disabled,
                borderRadius: BorderRadius.circular(AppRadius.chip),
                border: Border.all(color: surfaces.border),
              ),
              child: Text(
                trailingLabel!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: textColors.weak,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
