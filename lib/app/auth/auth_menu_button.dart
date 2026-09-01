import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/supabase_auth_controller.dart';
import '../../core/di/service_locator.dart';
import '../../core/identity/identity_controller.dart';
import '../../core/theme/app_components.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/google_brand_icon.dart';

class AuthMenuButton extends StatelessWidget {
  const AuthMenuButton({this.showGuestLabel = false, super.key});

  final bool showGuestLabel;

  @override
  Widget build(BuildContext context) {
    if (!getIt.isRegistered<SupabaseAuthController>()) {
      return const SizedBox.shrink();
    }

    final controller = getIt<SupabaseAuthController>();
    final identityController = getIt.isRegistered<IdentityController>()
        ? getIt<IdentityController>()
        : null;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.isSignedIn && showGuestLabel) {
          return Tooltip(
            message: 'Invité - se connecter',
            child: TextButton.icon(
              onPressed: () =>
                  _showAuthSheet(context, controller, identityController),
              icon: const Icon(Icons.person_outline_rounded),
              label: const Text('Se connecter'),
            ),
          );
        }

        final icon = controller.isSignedIn
            ? Icons.cloud_done_rounded
            : Icons.person_outline_rounded;
        return IconButton(
          tooltip: controller.isSignedIn
              ? 'Compte synchronisé'
              : 'Connexion et synchronisation',
          onPressed: () =>
              _showAuthSheet(context, controller, identityController),
          icon: Icon(icon),
        );
      },
    );
  }

  void _showAuthSheet(
    BuildContext context,
    SupabaseAuthController controller,
    IdentityController? identityController,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: context.surfaces.surface,
      builder: (context) => _AuthSheet(
        controller: controller,
        identityController: identityController,
      ),
    );
  }
}

class _AuthSheet extends StatelessWidget {
  const _AuthSheet({
    required this.controller,
    required this.identityController,
  });

  final SupabaseAuthController controller;
  final IdentityController? identityController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = context.brand;
    final textColors = context.textColors;
    final surfaces = context.surfaces;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xs,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final signedInUser = controller.user;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            signedInUser == null
                                ? 'Se connecter'
                                : 'Compte Lector',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: textColors.primary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            signedInUser == null
                                ? 'Invité'
                                : 'Synchronisation active',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: brand.accent,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fermer',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _BrandMessage(signedInUser: signedInUser),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: surfaces.backgroundSecondary,
                    borderRadius: BorderRadius.circular(AppRadius.input),
                    border: Border.all(color: surfaces.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        controller.isConfigured
                            ? Icons.verified_user_outlined
                            : Icons.offline_bolt_rounded,
                        color: controller.isConfigured
                            ? brand.accent
                            : textColors.weak,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          _statusMessage(controller, signedInUser),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: textColors.secondary,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (signedInUser == null) ...[
                  _AuthProviderButton(
                    leading: const GoogleBrandIcon(size: 19),
                    label: 'Continuer avec Google',
                    enabled: controller.isConfigured,
                    onPressed: () => _signIn(
                      context,
                      identityController?.signInWithGoogle ??
                          controller.signInWithGoogle,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _AuthProviderButton(
                    icon: Icons.apple_rounded,
                    label: 'Continuer avec Apple',
                    enabled: false,
                    trailingLabel: 'Bientôt',
                    onPressed: () {},
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Continuer plus tard'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Vous gardez le contrôle : fermer cette fenêtre ne modifie pas vos données locales.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: textColors.weak,
                      height: 1.35,
                    ),
                  ),
                ] else ...[
                  FilledButton.icon(
                    onPressed: () async {
                      await (identityController?.signOut() ??
                          controller.signOut());
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Se déconnecter'),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _signIn(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } on Object catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connexion indisponible : $error')),
      );
    }
  }

  String _statusMessage(SupabaseAuthController controller, User? user) {
    if (!controller.isConfigured) {
      return 'Mode local actif. Ajoutez SUPABASE_URL et SUPABASE_ANON_KEY pour activer Google et Apple.';
    }

    if (user == null) {
      return 'Connectez-vous pour sauvegarder et synchroniser votre profil, vos stratégies, vos favoris et vos tickets.';
    }

    return 'Session synchronisée : profil, stratégies, favoris et tickets sont rattachés à votre compte.';
  }
}

class _AuthProviderButton extends StatelessWidget {
  const _AuthProviderButton({
    required this.label,
    required this.enabled,
    required this.onPressed,
    this.leading,
    this.icon,
    this.trailingLabel,
  });

  final Widget? leading;
  final IconData? icon;
  final String label;
  final bool enabled;
  final VoidCallback onPressed;
  final String? trailingLabel;

  @override
  Widget build(BuildContext context) {
    final textColors = context.textColors;
    final surfaces = context.surfaces;
    return OutlinedButton(
      onPressed: enabled ? onPressed : null,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        alignment: Alignment.centerLeft,
      ),
      child: Row(
        children: [
          if (leading != null)
            Opacity(opacity: enabled ? 1 : 0.42, child: leading!)
          else if (icon != null)
            Icon(icon),
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

class _BrandMessage extends StatelessWidget {
  const _BrandMessage({required this.signedInUser});

  final User? signedInUser;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = context.brand;
    final textColors = context.textColors;
    final surfaces = context.surfaces;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: brand.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: brand.accent.withValues(alpha: 0.26)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: surfaces.surface,
              border: Border.all(color: brand.accent.withValues(alpha: 0.36)),
            ),
            child: Icon(
              signedInUser == null
                  ? Icons.auto_awesome_rounded
                  : Icons.cloud_done_rounded,
              color: brand.accent,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  signedInUser == null
                      ? 'Mode invité'
                      : 'Synchronisation active',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: textColors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  signedInUser == null
                      ? 'Votre utilisation locale reste disponible. La connexion permet de retrouver vos données sur plusieurs appareils.'
                      : _signedInText(signedInUser!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: textColors.secondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _signedInText(User user) {
    final email = user.email;
    if (email != null && email.isNotEmpty) {
      return email;
    }

    return 'Votre compte Lector Sport est connecté.';
  }
}
