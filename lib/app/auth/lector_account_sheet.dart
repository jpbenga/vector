import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/supabase_auth_controller.dart';
import '../../core/auth/user_presentation.dart';
import '../../core/di/service_locator.dart';
import '../../core/identity/identity_controller.dart';
import '../../core/theme/app_components.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/google_brand_icon.dart';
import '../../core/widgets/lector_brand_mark.dart';
import '../../core/widgets/lector_workspace_header.dart';

/// The account and sign-in journey shared by every sport workspace.
Future<void> showLectorAccountSheet(BuildContext context) {
  final controller = getIt.isRegistered<SupabaseAuthController>()
      ? getIt<SupabaseAuthController>()
      : null;
  final identityController = getIt.isRegistered<IdentityController>()
      ? getIt<IdentityController>()
      : null;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: false,
    isScrollControlled: true,
    backgroundColor: context.surfaces.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
        child: LectorAccountSheet(
          controller: controller,
          identityController: identityController,
        ),
      ),
    ),
  );
}

class LectorAccountSheet extends StatelessWidget {
  const LectorAccountSheet({
    required this.controller,
    required this.identityController,
    super.key,
  });

  final SupabaseAuthController? controller;
  final IdentityController? identityController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller ?? Listenable.merge([]),
      builder: (context, _) {
        if (controller?.isSignedIn ?? false) {
          return _ConnectedAccountSheet(
            controller: controller!,
            identityController: identityController,
          );
        }
        return _DisconnectedAuthSheet(
          controller: controller,
          identityController: identityController,
        );
      },
    );
  }
}

class _DisconnectedAuthSheet extends StatefulWidget {
  const _DisconnectedAuthSheet({
    required this.controller,
    required this.identityController,
  });

  final SupabaseAuthController? controller;
  final IdentityController? identityController;

  @override
  State<_DisconnectedAuthSheet> createState() => _DisconnectedAuthSheetState();
}

class _DisconnectedAuthSheetState extends State<_DisconnectedAuthSheet> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isCreatingAccount = false;
  String? _errorMessage;

  bool get _isConfigured => widget.controller?.isConfigured ?? false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_handleCredentialInputChanged);
    _passwordController.addListener(_handleCredentialInputChanged);
  }

  @override
  void dispose() {
    _emailController.removeListener(_handleCredentialInputChanged);
    _passwordController.removeListener(_handleCredentialInputChanged);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleCredentialInputChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(0, 0, 0, bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetTopBar(onClose: () => Navigator.of(context).pop()),
            const SizedBox(height: AppSpacing.xs),
            const _LoginVisualIdentity(),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _isCreatingAccount ? 'Créer un compte' : 'Se connecter',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: context.textColors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Accédez à votre compte Lector\net synchronisez vos données.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.textColors.secondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _AuthTextField(
              controller: _emailController,
              icon: Icons.mail_outline_rounded,
              hintText: 'Adresse e-mail',
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              enabled: !_isLoading,
              onChanged: (_) => _clearError(),
            ),
            const SizedBox(height: AppSpacing.sm),
            _AuthTextField(
              controller: _passwordController,
              icon: Icons.lock_outline_rounded,
              hintText: 'Mot de passe',
              obscureText: !_isPasswordVisible,
              autofillHints: const [AutofillHints.password],
              enabled: !_isLoading,
              onChanged: (_) => _clearError(),
              suffix: IconButton(
                tooltip: _isPasswordVisible
                    ? 'Masquer le mot de passe'
                    : 'Afficher le mot de passe',
                onPressed: _isLoading
                    ? null
                    : () => setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      }),
                icon: Icon(
                  _isPasswordVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _AuthInlineMessage(message: _errorMessage!),
            ],
            if (!_isCreatingAccount) ...[
              const SizedBox(height: AppSpacing.xs),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isLoading ? null : _resetPassword,
                  child: const Text('Mot de passe oublié ?'),
                ),
              ),
            ] else
              const SizedBox(height: AppSpacing.sm),
            FilledButton(
              onPressed: _canSubmit ? _submitPasswordAuth : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
              ),
              child: _isLoading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _isCreatingAccount ? 'Créer le compte' : 'Se connecter',
                    ),
            ),
            const SizedBox(height: AppSpacing.md),
            const _AuthDivider(),
            const SizedBox(height: AppSpacing.md),
            _GoogleAuthButton(
              enabled: _isConfigured && !_isLoading,
              onPressed: _signInWithGoogle,
            ),
            const SizedBox(height: AppSpacing.md),
            _AuthModeSwitch(
              isCreatingAccount: _isCreatingAccount,
              onPressed: _isLoading
                  ? null
                  : () => setState(() {
                      _isCreatingAccount = !_isCreatingAccount;
                      _errorMessage = null;
                    }),
            ),
          ],
        ),
      ),
    );
  }

  bool get _canSubmit {
    return _isConfigured &&
        !_isLoading &&
        _emailController.text.trim().isNotEmpty &&
        _passwordController.text.isNotEmpty;
  }

  void _clearError() {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
  }

  Future<void> _submitPasswordAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final validationError = _validateCredentials(email, password);
    if (validationError != null) {
      setState(() => _errorMessage = validationError);
      return;
    }

    await _runAuthAction(
      () {
        final controller = widget.controller!;
        if (_isCreatingAccount) {
          return widget.identityController?.signUpWithPassword(
                email: email,
                password: password,
              ) ??
              controller.signUpWithPassword(email: email, password: password);
        }
        return widget.identityController?.signInWithPassword(
              email: email,
              password: password,
            ) ??
            controller.signInWithPassword(email: email, password: password);
      },
      successMessageWhenStillSignedOut: _isCreatingAccount
          ? 'Compte créé. Vérifiez votre e-mail si une confirmation est demandée.'
          : null,
    );
  }

  Future<void> _signInWithGoogle() async {
    await _runAuthAction(
      () =>
          widget.identityController?.signInWithGoogle() ??
          widget.controller!.signInWithGoogle(),
    );
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (!_isConfigured) {
      setState(() {
        _errorMessage =
            'Connexion indisponible dans cet environnement. Réessayez plus tard.';
      });
      return;
    }
    if (!_looksLikeEmail(email)) {
      setState(() {
        _errorMessage =
            'Saisissez une adresse e-mail valide pour réinitialiser le mot de passe.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await widget.controller!.resetPasswordForEmail(email);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Si ce compte existe, un e-mail de réinitialisation a été envoyé.',
          ),
        ),
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = _friendlyAuthError(error);
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _runAuthAction(
    Future<void> Function() action, {
    String? successMessageWhenStillSignedOut,
  }) async {
    if (!_isConfigured || _isLoading) {
      setState(() {
        _errorMessage =
            'Connexion indisponible dans cet environnement. Réessayez plus tard.';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await action();
      if (mounted) {
        if (successMessageWhenStillSignedOut != null &&
            !(widget.controller?.isSignedIn ?? false)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(successMessageWhenStillSignedOut)),
          );
          return;
        }
        Navigator.of(context).pop();
      }
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = _friendlyAuthError(error);
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

class _ConnectedAccountSheet extends StatelessWidget {
  const _ConnectedAccountSheet({
    required this.controller,
    required this.identityController,
  });

  final SupabaseAuthController controller;
  final IdentityController? identityController;

  @override
  Widget build(BuildContext context) {
    final user = controller.user;
    final name = _displayNameForUser(user);
    final email = user?.email;
    final identityLabel = name ?? email ?? 'Compte Lector';
    final isGoogleAccount = _hasGoogleIdentity(user);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.82,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetTopBar(onClose: () => Navigator.of(context).pop()),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: LectorIdentityButton(
                label: _initialsForName(identityLabel),
                tooltip: 'Compte',
                onPressed: () {},
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              name ?? 'Compte Lector',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            if (email != null) ...[
              const SizedBox(height: 2),
              Text(
                email,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.textColors.secondary,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            DecoratedBox(
              decoration: BoxDecoration(
                color: context.surfaces.backgroundSecondary,
                borderRadius: BorderRadius.circular(AppRadius.input),
                border: Border.all(color: context.surfaces.border),
              ),
              child: Column(
                children: [
                  _HeaderAccountRow(
                    icon: Icons.person_outline_rounded,
                    title: 'Mon profil',
                    subtitle: 'Voir et modifier mes informations',
                    onTap: () => _showUnavailable(
                      context,
                      'Aucun écran de profil détaillé n’est encore relié.',
                    ),
                  ),
                  Divider(height: 1, color: context.surfaces.border),
                  _HeaderAccountRow(
                    icon: Icons.lock_outline_rounded,
                    title: 'Sécurité',
                    subtitle: 'Mot de passe et connexions',
                    onTap: () => _showUnavailable(
                      context,
                      'Aucun écran de sécurité n’est encore relié.',
                    ),
                  ),
                  Divider(height: 1, color: context.surfaces.border),
                  _HeaderAccountRow(
                    icon: Icons.devices_outlined,
                    title: 'Appareils connectés',
                    subtitle: 'Gérer vos sessions actives',
                    onTap: () => _showUnavailable(
                      context,
                      'Aucun écran de sessions actives n’est encore relié.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (isGoogleAccount) ...[
              OutlinedButton.icon(
                onPressed: () async {
                  await (identityController?.signOut() ??
                      controller.signOutFromGoogle());
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  foregroundColor: context.textColors.primary,
                  side: BorderSide(color: context.surfaces.border),
                ),
                icon: const GoogleBrandIcon(size: 19),
                label: const Text('Se déconnecter de Google'),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            OutlinedButton.icon(
              onPressed: () async {
                await (identityController?.signOut() ?? controller.signOut());
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                foregroundColor: context.semantic.error,
                side: BorderSide(color: context.semantic.error),
              ),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Se déconnecter de Lector'),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Vos préférences et informations seront conservées sur cet appareil.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.textColors.secondary,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUnavailable(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SheetTopBar extends StatelessWidget {
  const _SheetTopBar({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: Stack(
        alignment: Alignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: context.textColors.secondary.withValues(alpha: 0.56),
              borderRadius: BorderRadius.circular(AppRadius.chip),
            ),
            child: const SizedBox(width: 34, height: 4),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Fermer',
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded, size: 24),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginVisualIdentity extends StatelessWidget {
  const _LoginVisualIdentity();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 122,
        height: 74,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 8,
              child: Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.brand.accent.withValues(alpha: 0.10),
                  border: Border.all(
                    color: context.brand.accent.withValues(alpha: 0.62),
                  ),
                ),
                child: Icon(
                  Icons.person_outline_rounded,
                  color: context.brand.accent,
                  size: 31,
                ),
              ),
            ),
            Positioned(
              right: 4,
              top: 8,
              child: Container(
                width: 58,
                height: 54,
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: context.surfaces.backgroundSecondary,
                  borderRadius: BorderRadius.circular(AppRadius.odds),
                  border: Border.all(color: context.surfaces.border),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LectorBrandMark(size: 18),
                    const SizedBox(height: 4),
                    _AuthVisualLine(width: 28),
                    const SizedBox(height: 3),
                    _AuthVisualLine(width: 20),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 8,
              child: Container(
                width: 25,
                height: 25,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.brand.accent,
                ),
                child: Icon(
                  Icons.sync_rounded,
                  color: context.brand.onAccent,
                  size: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthVisualLine extends StatelessWidget {
  const _AuthVisualLine({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.textColors.secondary.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: SizedBox(width: width, height: 3),
    );
  }
}

class _AuthTextField extends StatelessWidget {
  const _AuthTextField({
    required this.controller,
    required this.icon,
    required this.hintText,
    required this.enabled,
    this.keyboardType,
    this.autofillHints,
    this.obscureText = false,
    this.suffix,
    this.onChanged,
  });

  final TextEditingController controller;
  final IconData icon;
  final String hintText;
  final bool enabled;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      obscureText: obscureText,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
      ),
    );
  }
}

class _AuthInlineMessage extends StatelessWidget {
  const _AuthInlineMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.semantic.error.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.odds),
        border: Border.all(
          color: context.semantic.error.withValues(alpha: 0.62),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 18,
              color: context.semantic.error,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.semantic.error,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthDivider extends StatelessWidget {
  const _AuthDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: context.surfaces.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text(
            'ou',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.textColors.secondary,
            ),
          ),
        ),
        Expanded(child: Divider(color: context.surfaces.border)),
      ],
    );
  }
}

class _GoogleAuthButton extends StatelessWidget {
  const _GoogleAuthButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: enabled ? onPressed : null,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(46),
        foregroundColor: context.textColors.primary,
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          GoogleBrandIcon(size: 19),
          SizedBox(width: AppSpacing.sm),
          Text('Continuer avec Google'),
        ],
      ),
    );
  }
}

class _AuthModeSwitch extends StatelessWidget {
  const _AuthModeSwitch({
    required this.isCreatingAccount,
    required this.onPressed,
  });

  final bool isCreatingAccount;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          isCreatingAccount ? 'Déjà un compte ? ' : 'Pas encore de compte ? ',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.textColors.secondary),
        ),
        TextButton(
          onPressed: onPressed,
          child: Text(isCreatingAccount ? 'Se connecter' : 'Créer un compte'),
        ),
      ],
    );
  }
}

class _HeaderAccountRow extends StatelessWidget {
  const _HeaderAccountRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.odds),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.surfaces.backgroundSecondary,
                border: Border.all(color: context.surfaces.border),
              ),
              child: Icon(icon, color: context.textColors.primary, size: 19),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.textColors.secondary,
                        height: 1.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: context.textColors.secondary,
            ),
          ],
        ),
      ),
    );
  }
}

String? _displayNameForUser(User? user) => lectorDisplayNameForUser(user);
String _initialsForName(String value) => lectorInitialsForName(value);

bool _hasGoogleIdentity(User? user) {
  if (user == null) {
    return false;
  }
  final provider = user.appMetadata['provider']?.toString().toLowerCase();
  if (provider == 'google') {
    return true;
  }
  return user.identities?.any(
        (identity) => identity.provider.toLowerCase() == 'google',
      ) ??
      false;
}

String? _validateCredentials(String email, String password) {
  if (!_looksLikeEmail(email)) {
    return 'Saisissez une adresse e-mail valide.';
  }
  if (password.length < 6) {
    return 'Le mot de passe doit contenir au moins 6 caractères.';
  }
  return null;
}

bool _looksLikeEmail(String value) {
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
}

String _friendlyAuthError(Object error) {
  if (error is AuthException) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login') ||
        message.contains('invalid credentials') ||
        message.contains('email not confirmed') ||
        message.contains('password')) {
      return 'Adresse e-mail ou mot de passe incorrect.';
    }
    if (message.contains('user not found') || message.contains('not found')) {
      return 'Aucun compte ne correspond à cette adresse e-mail.';
    }
    if (message.contains('email')) {
      return 'Vérifiez votre adresse e-mail puis réessayez.';
    }
    if (message.contains('network') || message.contains('timeout')) {
      return 'La connexion réseau semble indisponible. Réessayez dans un instant.';
    }
  }
  if (error is StateError) {
    return 'Connexion indisponible dans cet environnement. Réessayez plus tard.';
  }
  return 'Connexion impossible pour le moment. Réessayez dans un instant.';
}
