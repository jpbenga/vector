import 'package:flutter/material.dart';

import '../../core/auth/supabase_auth_controller.dart';
import '../../core/identity/identity_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_components.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/google_brand_icon.dart';
import '../../core/widgets/lector_brand_mark.dart';
import '../../features/matches/presentation/widgets/sports_asset_badge.dart';

const _authTunnelBackgroundAsset =
    'assets/backgrounds/auth-stadium-stands-background.png';

class AuthEntryPage extends StatefulWidget {
  const AuthEntryPage({
    required this.controller,
    required this.onContinueLocal,
    this.identityController,
    super.key,
  });

  final SupabaseAuthController? controller;
  final IdentityController? identityController;
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _StadiumArrivalBackground(),
          SafeArea(
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
                      onSignIn: () => setState(() => _showSignIn = true),
                      onContinueLocal: widget.onContinueLocal,
                    ),
            ),
          ),
        ],
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
      await (widget.identityController?.signInWithGoogle() ??
          controller.signInWithGoogle());
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
  const _WelcomeStep({
    required this.onSignIn,
    required this.onContinueLocal,
    super.key,
  });

  final VoidCallback onSignIn;
  final VoidCallback onContinueLocal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = context.brand;
    final textColors = context.textColors;
    final surfaces = context.surfaces;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 26),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 50,
                maxWidth: 460,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: LectorBrandLockup(width: 250)),
                  const SizedBox(height: 18),
                  Text(
                    'Read the Game.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: textColors.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 34),
                  Text(
                    'Les matchs du jour,\navec une lecture plus claire.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: textColors.primary,
                      fontWeight: FontWeight.w900,
                      height: 1.08,
                    ),
                  ),
                  const SizedBox(height: 36),
                  _ArrivalPrimaryButton(
                    label: 'Continuer sans compte',
                    onPressed: onContinueLocal,
                  ),
                  const SizedBox(height: 14),
                  _ArrivalSecondaryButton(
                    label: 'Se connecter',
                    onPressed: onSignIn,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        color: brand.accent,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          'Aucun compte requis pour voir les scores.',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: textColors.secondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: surfaces.surface.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(AppRadius.control),
                      border: Border.all(
                        color: surfaces.border.withValues(alpha: 0.9),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: surfaces.shadow.withValues(alpha: 0.28),
                          blurRadius: 28,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(14),
                      child: _TodayMatchesPreview(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ArrivalPrimaryButton extends StatelessWidget {
  const _ArrivalPrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(58),
        backgroundColor: brand.accent,
        foregroundColor: brand.onAccent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 18),
          const Icon(Icons.arrow_forward_rounded),
        ],
      ),
    );
  }
}

class _ArrivalSecondaryButton extends StatelessWidget {
  const _ArrivalSecondaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = context.surfaces;
    final violet = context.opportunities.levelGap;

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(58),
        foregroundColor: violet,
        side: BorderSide(color: violet, width: 1.4),
        backgroundColor: surfaces.surface.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                color: violet,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 18),
          const Icon(Icons.arrow_forward_rounded),
        ],
      ),
    );
  }
}

class _TodayMatchesPreview extends StatelessWidget {
  const _TodayMatchesPreview();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = context.brand;
    final textColors = context.textColors;
    final surfaces = context.surfaces;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Aperçu des matchs du jour',
          style: theme.textTheme.titleMedium?.copyWith(
            color: brand.accent,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        _PreviewMatchRow(
          homeLogoUrl: 'https://media.api-sports.io/football/teams/49.png',
          awayLogoUrl: 'https://media.api-sports.io/football/teams/47.png',
          label: 'Chelsea - Tottenham',
          badge: 'Match ouvert',
          badgeColor: brand.accent,
        ),
        Divider(height: 12, color: surfaces.border),
        _PreviewMatchRow(
          homeLogoUrl: 'https://media.api-sports.io/football/teams/541.png',
          awayLogoUrl: 'https://media.api-sports.io/football/teams/157.png',
          label: 'Real Madrid - Bayern',
          badge: 'Domination attendue',
          badgeColor: context.opportunities.levelGap,
        ),
        Divider(height: 12, color: surfaces.border),
        _PreviewMatchRow(
          homeLogoUrl: 'https://media.api-sports.io/football/teams/85.png',
          awayLogoUrl: 'https://media.api-sports.io/football/teams/165.png',
          label: 'PSG - Dortmund',
          badge: 'Match ouvert',
          badgeColor: brand.accent,
        ),
        const SizedBox(height: 2),
        Text(
          'Accès immédiat aux scores et aux repères essentiels.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: textColors.weak,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _PreviewMatchRow extends StatelessWidget {
  const _PreviewMatchRow({
    required this.homeLogoUrl,
    required this.awayLogoUrl,
    required this.label,
    required this.badge,
    required this.badgeColor,
  });

  final String homeLogoUrl;
  final String awayLogoUrl;
  final String label;
  final String badge;
  final Color badgeColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColors = context.textColors;
    final surfaces = context.surfaces;

    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: surfaces.backgroundSecondary.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: surfaces.border.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 74,
            child: Stack(
              children: [
                SportsAssetBadge(
                  size: 34,
                  imageUrl: homeLogoUrl,
                  fallbackLabel: label,
                  backgroundColor: AppColors.transparent,
                ),
                Positioned(
                  left: 30,
                  child: SportsAssetBadge(
                    size: 34,
                    imageUrl: awayLogoUrl,
                    fallbackLabel: label,
                    backgroundColor: AppColors.transparent,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: textColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.chip),
              border: Border.all(color: badgeColor.withValues(alpha: 0.52)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: badgeColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    badge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: badgeColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 42,
                maxWidth: 460,
              ),
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
                  const Center(child: LectorBrandLockup(width: 170)),
                  const SizedBox(height: 26),
                  Text(
                    'Connexion',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: textColors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Retrouvez vos favoris et vos préférences sur vos appareils.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: textColors.secondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: surfaces.surface.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(color: surfaces.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _ProviderAction(
                            leading: const GoogleBrandIcon(size: 19),
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
                          const SizedBox(height: AppSpacing.md),
                          Divider(color: surfaces.border),
                          const SizedBox(height: AppSpacing.md),
                          TextButton(
                            onPressed: onContinueLocal,
                            child: Text(
                              'Continuer en invité',
                              style: TextStyle(color: brand.accent),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!isGoogleAvailable) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Connexion externe indisponible dans cet environnement.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: textColors.weak,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StadiumArrivalBackground extends StatelessWidget {
  const _StadiumArrivalBackground();

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return ColoredBox(
      color: surfaces.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            _authTunnelBackgroundAsset,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  surfaces.shadow.withValues(alpha: 0.28),
                  surfaces.shadow.withValues(alpha: 0.42),
                  surfaces.background.withValues(alpha: 0.78),
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.16),
                radius: 0.84,
                colors: [
                  AppColors.transparent,
                  surfaces.shadow.withValues(alpha: 0.46),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderAction extends StatelessWidget {
  const _ProviderAction({
    required this.label,
    required this.enabled,
    this.leading,
    this.icon,
    this.onPressed,
    this.trailingLabel,
  });

  final Widget? leading;
  final IconData? icon;
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
          if (leading != null)
            Opacity(opacity: enabled ? 1 : 0.42, child: leading!)
          else if (icon != null)
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
