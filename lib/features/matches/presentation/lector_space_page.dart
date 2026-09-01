import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/auth/supabase_auth_controller.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/identity/identity_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_components.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme_controller.dart';
import '../../../core/widgets/lector_brand_mark.dart';
import '../../onboarding/domain/decision_profile.dart';
import '../../onboarding/domain/decision_profile_catalogs.dart';
import '../../tickets/domain/ticket_strategy.dart';
import 'lector_competitions_page.dart';
import 'lector_preferences_sheet.dart';
import 'lector_scenarios_page.dart';
import 'lector_strategies_page.dart';

class LectorSpacePage extends StatefulWidget {
  const LectorSpacePage({
    required this.profile,
    required this.ticketStrategies,
    required this.onProfileChanged,
    required this.onTicketStrategiesChanged,
    super.key,
  });

  final DecisionProfile profile;
  final List<TicketStrategy> ticketStrategies;
  final ProfilePreferenceSaver onProfileChanged;
  final TicketStrategyPreferenceSaver onTicketStrategiesChanged;

  @override
  State<LectorSpacePage> createState() => _LectorSpacePageState();
}

class _LectorSpacePageState extends State<LectorSpacePage> {
  late DecisionProfile _profile;
  late List<TicketStrategy> _ticketStrategies;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    _ticketStrategies = widget.ticketStrategies;
  }

  @override
  void didUpdateWidget(covariant LectorSpacePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile != widget.profile) {
      _profile = widget.profile;
    }
    if (oldWidget.ticketStrategies != widget.ticketStrategies) {
      _ticketStrategies = widget.ticketStrategies;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = getIt.isRegistered<SupabaseAuthController>()
        ? getIt<SupabaseAuthController>()
        : null;
    final identityController = getIt.isRegistered<IdentityController>()
        ? getIt<IdentityController>()
        : null;

    return Scaffold(
      backgroundColor: context.surfaces.background,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: authController ?? Listenable.merge([]),
          builder: (context, _) {
            final user = authController?.user;
            return ListView(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
              children: [
                _LectorSpaceHeader(
                  onSettings: () => _openAppPreferences(context),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Gérez votre compte et personnalisez votre expérience Lector.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.textColors.secondary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _ProfileCard(
                  user: user,
                  isSignedIn: authController?.isSignedIn ?? false,
                  competitionCount: _selectedCompetitionCount(_profile),
                  scenarioCount: _selectedScenarioCount(_profile),
                  activeStrategyCount: _activeStrategyCount(_ticketStrategies),
                  onAccount: () => _showUnavailable(
                    context,
                    'Les informations personnelles seront reliées au prochain écran compte.',
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _SectionHeading(
                  title: 'Personnaliser Lector',
                  subtitle:
                      'Définissez ce que Lector doit suivre et comment il construit vos opportunités.',
                ),
                const SizedBox(height: AppSpacing.xs),
                _SpaceActionCard(
                  icon: Icons.emoji_events_outlined,
                  title: 'Mes compétitions',
                  subtitle:
                      'Choisissez les championnats que vous souhaitez suivre.',
                  count: _selectedCompetitionCount(_profile),
                  color: context.brand.accent,
                  onTap: () => _openCompetitions(context),
                ),
                const SizedBox(height: AppSpacing.sm),
                _SpaceActionCard(
                  icon: Icons.my_location_rounded,
                  title: 'Mes scénarios',
                  subtitle:
                      'Choisissez les situations de match que Lector doit rechercher pour vous.',
                  count: _selectedScenarioCount(_profile),
                  color: context.opportunities.levelGap,
                  onTap: () => _openScenarios(context),
                ),
                const SizedBox(height: AppSpacing.sm),
                _SpaceActionCard(
                  icon: Icons.confirmation_number_outlined,
                  title: 'Mes stratégies',
                  subtitle: 'Définissez comment Lector construit vos tickets.',
                  count: _activeStrategyCount(_ticketStrategies),
                  color: context.semantic.warning,
                  onTap: () => _openStrategies(context),
                ),
                const SizedBox(height: AppSpacing.lg),
                const _SectionHeading(title: 'Mon compte'),
                const SizedBox(height: AppSpacing.xs),
                _GroupedActionList(
                  children: [
                    _CompactSpaceRow(
                      icon: Icons.person_outline_rounded,
                      label: 'Compte et informations personnelles',
                      onTap: () => _showUnavailable(
                        context,
                        'Aucun écran de gestion du compte n’est encore disponible.',
                      ),
                    ),
                    _CompactSpaceRow(
                      icon: Icons.credit_card_rounded,
                      label: 'Abonnement et facturation',
                      onTap: () => _showUnavailable(
                        context,
                        'Aucun système d’abonnement ou de facturation n’est encore relié.',
                      ),
                    ),
                    _CompactSpaceRow(
                      icon: Icons.notifications_none_rounded,
                      label: 'Notifications',
                      onTap: () => _showUnavailable(
                        context,
                        'Aucune préférence de notifications n’est encore disponible.',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                const _SectionHeading(title: 'Application'),
                const SizedBox(height: AppSpacing.xs),
                _GroupedActionList(
                  children: [
                    _CompactSpaceRow(
                      icon: Icons.palette_outlined,
                      label: 'Apparence',
                      color: context.brand.accent,
                      onTap: () => _openAppPreferences(context),
                    ),
                    if (authController?.isSignedIn ?? false)
                      _CompactSpaceRow(
                        icon: Icons.logout_rounded,
                        label: 'Se déconnecter',
                        color: context.semantic.error,
                        onTap: () async {
                          await (identityController?.signOut() ??
                              authController?.signOut());
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _openAppPreferences(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const _SpaceAppearancePage(),
      ),
    );
  }

  void _showUnavailable(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openCompetitions(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => LectorCompetitionsPage(
          profile: _profile,
          onProfileChanged: _handleProfileChanged,
        ),
      ),
    );
  }

  void _openScenarios(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => LectorScenariosPage(
          profile: _profile,
          onProfileChanged: _handleProfileChanged,
        ),
      ),
    );
  }

  void _openStrategies(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => LectorStrategiesPage(
          strategies: _ticketStrategies,
          onTicketStrategiesChanged: _handleTicketStrategiesChanged,
        ),
      ),
    );
  }

  Future<void> _handleProfileChanged(DecisionProfile profile) async {
    await widget.onProfileChanged(profile);
    if (!mounted) {
      return;
    }
    setState(() {
      _profile = profile;
    });
  }

  Future<void> _handleTicketStrategiesChanged(
    List<TicketStrategy> strategies,
  ) async {
    await widget.onTicketStrategiesChanged(strategies);
    if (!mounted) {
      return;
    }
    setState(() {
      _ticketStrategies = strategies;
    });
  }
}

class _LectorSpaceHeader extends StatelessWidget {
  const _LectorSpaceHeader({required this.onSettings});

  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: 'Retour',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.chevron_left_rounded, size: 26),
            ),
          ),
          Text(
            'Mon espace',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Préférences',
              onPressed: onSettings,
              icon: const Icon(Icons.settings_outlined, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpaceAppearancePage extends StatelessWidget {
  const _SpaceAppearancePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surfaces.background,
      body: SafeArea(
        child: ValueListenableBuilder<AppThemeVariant>(
          valueListenable: appThemeController,
          builder: (context, activeVariant, _) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
              children: [
                const _SpaceSubmenuHeader(title: 'Apparence'),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Choisir un thème',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Sélectionnez le thème qui vous convient.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.textColors.secondary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                for (final variant in AppThemeVariant.values) ...[
                  _SpaceThemeChoiceCard(
                    key: ValueKey('appearance-theme-${variant.name}'),
                    variant: variant,
                    isSelected: variant == activeVariant,
                    onTap: () => appThemeController.select(variant),
                  ),
                  if (variant != AppThemeVariant.values.last)
                    const SizedBox(height: AppSpacing.sm),
                ],
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Le thème est appliqué immédiatement.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.textColors.secondary,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SpaceSubmenuHeader extends StatelessWidget {
  const _SpaceSubmenuHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: 'Retour',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.chevron_left_rounded, size: 26),
            ),
          ),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _SpaceThemeChoiceCard extends StatelessWidget {
  const _SpaceThemeChoiceCard({
    super.key,
    required this.variant,
    required this.isSelected,
    required this.onTap,
  });

  final AppThemeVariant variant;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final previewTheme = AppTheme.forVariant(variant);
    final previewBrand =
        previewTheme.extension<AppBrandPalette>() ?? context.brand;
    final borderColor = isSelected
        ? previewBrand.accent
        : context.surfaces.border.withValues(alpha: 0.82);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected
              ? previewBrand.accent.withValues(alpha: 0.07)
              : context.surfaces.backgroundSecondary,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: borderColor, width: isSelected ? 1.4 : 1),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: previewBrand.accent.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(variant.icon, size: 28, color: previewBrand.accent),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    variant.shortLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: Icon(
                    isSelected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    key: ValueKey(isSelected),
                    size: 24,
                    color: isSelected
                        ? previewBrand.accent
                        : context.textColors.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Theme(
              data: previewTheme,
              child: _ThemePreview(
                key: ValueKey('appearance-theme-preview-${variant.name}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemePreview extends StatelessWidget {
  const _ThemePreview({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 86,
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: context.surfaces.background,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: context.surfaces.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 54,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.surfaces.surface,
                    borderRadius: BorderRadius.circular(AppRadius.odds),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(7),
                    child: LectorBrandMark(size: 28),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                _ThemePreviewLine(width: 34, color: context.brand.accent),
                const SizedBox(height: 4),
                _ThemePreviewLine(width: 28, color: context.brand.accentHover),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(child: _ThemePreviewPill()),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: _ThemePreviewPill(
                        color: context.surfaces.surfaceHover,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _ThemePreviewLine(
                    width: 70,
                    color: context.textColors.secondary.withValues(alpha: 0.34),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                _ThemePreviewContentBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemePreviewPill extends StatelessWidget {
  const _ThemePreviewPill({this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? context.surfaces.backgroundSecondary,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: const SizedBox(height: 14),
    );
  }
}

class _ThemePreviewContentBar extends StatelessWidget {
  const _ThemePreviewContentBar();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.surfaces.surface,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(
          color: context.surfaces.border.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: 5,
        ),
        child: Row(
          children: [
            _ThemePreviewLine(width: 38, color: context.brand.accent),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: _ThemePreviewLine(
                width: double.infinity,
                color: context.textColors.primary.withValues(alpha: 0.18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemePreviewLine extends StatelessWidget {
  const _ThemePreviewLine({required this.width, required this.color});

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: SizedBox(width: width, height: 5),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.user,
    required this.isSignedIn,
    required this.competitionCount,
    required this.scenarioCount,
    required this.activeStrategyCount,
    required this.onAccount,
  });

  final User? user;
  final bool isSignedIn;
  final int competitionCount;
  final int scenarioCount;
  final int activeStrategyCount;
  final VoidCallback onAccount;

  @override
  Widget build(BuildContext context) {
    final name = _displayName(user);
    final email = user?.email;

    return _LectorCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        children: [
          InkWell(
            onTap: onAccount,
            borderRadius: BorderRadius.circular(AppRadius.input),
            child: Row(
              children: [
                _ProfileAvatar(user: user, label: name ?? email ?? 'Lector'),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name ?? (isSignedIn ? 'Compte Lector' : 'Mode local'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        email ?? 'Aucun compte synchronisé',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.textColors.secondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      _SubscriptionBadge(isSignedIn: isSignedIn),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.textColors.secondary,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Divider(height: 1, color: context.surfaces.border),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const LectorBrandMark(size: 28),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Votre Lector',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$competitionCount compétition${competitionCount > 1 ? 's' : ''} · '
                      '$scenarioCount scénario${scenarioCount > 1 ? 's' : ''} · '
                      '$activeStrategyCount stratégie${activeStrategyCount > 1 ? 's' : ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.textColors.secondary,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.user, required this.label});

  final User? user;
  final String label;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = _avatarUrl(user);
    final initials = _initials(label);

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: context.brand.accent, width: 2),
      ),
      child: ClipOval(
        child: avatarUrl == null
            ? ColoredBox(
                color: context.surfaces.backgroundSecondary,
                child: Center(
                  child: Text(
                    initials,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              )
            : Image.network(avatarUrl, fit: BoxFit.cover),
      ),
    );
  }
}

class _SubscriptionBadge extends StatelessWidget {
  const _SubscriptionBadge({required this.isSignedIn});

  final bool isSignedIn;

  @override
  Widget build(BuildContext context) {
    final label = isSignedIn ? 'Offre non reliée' : 'Mode local';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.brand.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: context.brand.accent),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: 4,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.verified_outlined,
              color: context.brand.accent,
              size: 14,
            ),
            const SizedBox(width: AppSpacing.xxs),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: context.brand.accent,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.textColors.secondary,
              height: 1.3,
            ),
          ),
        ],
      ],
    );
  }
}

class _SpaceActionCard extends StatelessWidget {
  const _SpaceActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int count;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _LectorCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.textColors.secondary,
                    height: 1.24,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          _CountBadge(count: count, color: color),
          Icon(
            Icons.chevron_right_rounded,
            color: context.textColors.secondary,
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: SizedBox.square(
        dimension: 26,
        child: Center(
          child: Text(
            '$count',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupedActionList extends StatelessWidget {
  const _GroupedActionList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return _LectorCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final entry in children.indexed) ...[
            entry.$2,
            if (entry.$1 != children.length - 1)
              Divider(
                height: 1,
                indent: AppSpacing.md,
                color: context.surfaces.border,
              ),
          ],
        ],
      ),
    );
  }
}

class _CompactSpaceRow extends StatelessWidget {
  const _CompactSpaceRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? context.textColors.secondary;
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(icon, color: foreground, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: foreground),
            ],
          ),
        ),
      ),
    );
  }
}

class _LectorCard extends StatelessWidget {
  const _LectorCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    final decoration = BoxDecoration(
      color: context.surfaces.surface.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(AppRadius.card),
      border: Border.all(color: context.surfaces.border),
    );

    if (onTap == null) {
      return DecoratedBox(decoration: decoration, child: content);
    }

    return Material(
      color: AppColors.transparent,
      child: Ink(
        decoration: decoration,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: content,
        ),
      ),
    );
  }
}

int _selectedCompetitionCount(DecisionProfile profile) {
  return {
    for (final id in profile.optionIdsFor('competitions'))
      if (RuntimeCompetitionCatalog.resolveId(id) != null)
        RuntimeCompetitionCatalog.resolveId(id)!,
  }.length;
}

int _selectedScenarioCount(DecisionProfile profile) {
  return profile.optionIdsFor('opportunity_profiles').toSet().length;
}

int _activeStrategyCount(List<TicketStrategy> strategies) {
  return strategies.where((strategy) => strategy.isActive).length;
}

String? _displayName(User? user) {
  final metadata = user?.userMetadata;
  for (final key in ['full_name', 'name', 'display_name']) {
    final value = metadata?[key]?.toString().trim();
    if (value != null && value.isNotEmpty) {
      return value;
    }
  }
  return null;
}

String? _avatarUrl(User? user) {
  final metadata = user?.userMetadata;
  for (final key in ['avatar_url', 'picture']) {
    final value = metadata?[key]?.toString().trim();
    if (value != null && value.isNotEmpty) {
      return value;
    }
  }
  return null;
}

String _initials(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.length >= 2) {
    return '${parts.first.characters.first}${parts.last.characters.first}'
        .toUpperCase();
  }
  if (parts.isNotEmpty) {
    return parts.first.characters.take(2).toString().toUpperCase();
  }
  return 'LS';
}
