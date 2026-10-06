import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../appearance/presentation/appearance_page.dart';
import '../../../core/auth/supabase_auth_controller.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/identity/identity_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_components.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme_controller.dart';
import '../../../core/widgets/lector_brand_mark.dart';
import '../../../core/widgets/lector_space_widgets.dart';
import '../../../core/widgets/lector_responsive_layout.dart';
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
            return LectorContent(
              maxWidth: LectorLayout.workspaceWidth,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
                children: [
                  LectorSpaceHeader(
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
                    readingCount: _selectedReadingCount(_profile),
                    scenarioCount: _selectedScenarioCount(_profile),
                    activeStrategyCount: _activeStrategyCount(
                      _ticketStrategies,
                    ),
                    onAccount: () => _showUnavailable(
                      context,
                      'Les informations personnelles seront reliées au prochain écran compte.',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  LectorSpaceSectionHeading(
                    title: 'Personnaliser Lector',
                    subtitle:
                        'Choisissez votre apparence et les informations que vous souhaitez suivre.',
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  LectorAdaptiveCards(
                    children: [
                      LectorSpaceActionCard(
                        icon: Icons.palette_outlined,
                        title: 'Apparence',
                        subtitle:
                            'Comparez les thèmes sur un aperçu de Lector.',
                        count: AppThemeVariant.values.length,
                        color: context.brand.accent,
                        onTap: () => _openAppPreferences(context),
                      ),
                      LectorSpaceActionCard(
                        icon: Icons.emoji_events_outlined,
                        title: 'Mes compétitions',
                        subtitle:
                            'Choisissez les championnats que vous souhaitez suivre.',
                        count: _selectedCompetitionCount(_profile),
                        color: context.brand.accent,
                        onTap: () => _openCompetitions(context),
                      ),
                      LectorSpaceActionCard(
                        icon: Icons.auto_graph_rounded,
                        title: 'Mes lectures',
                        subtitle:
                            'Choisissez les faits sportifs qui doivent retenir votre attention.',
                        count: _selectedReadingCount(_profile),
                        color: context.semantic.info,
                        onTap: () => _openReadings(context),
                      ),
                      LectorSpaceActionCard(
                        icon: Icons.my_location_rounded,
                        title: 'Mes scénarios',
                        subtitle:
                            'Choisissez les situations de match que Lector doit rechercher pour vous.',
                        count: _selectedScenarioCount(_profile),
                        color: context.opportunities.levelGap,
                        onTap: () => _openScenarios(context),
                      ),
                      LectorSpaceActionCard(
                        icon: Icons.sports_score_outlined,
                        title: 'Mes marchés',
                        subtitle:
                            'Choisissez les marchés que Lector peut recommander.',
                        count: _selectedMarketCount(_profile),
                        color: context.semantic.success,
                        onTap: () => _openMarkets(context),
                      ),
                      LectorSpaceActionCard(
                        icon: Icons.confirmation_number_outlined,
                        title: 'Mes stratégies',
                        subtitle:
                            'Définissez comment Lector construit vos tickets.',
                        count: _activeStrategyCount(_ticketStrategies),
                        color: context.semantic.warning,
                        onTap: () => _openStrategies(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const LectorSpaceSectionHeading(title: 'Mon compte'),
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
                  if (authController?.isSignedIn ?? false)
                    const SizedBox(height: AppSpacing.lg),
                  if (authController?.isSignedIn ?? false)
                    _GroupedActionList(
                      children: [
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
              ),
            );
          },
        ),
      ),
    );
  }

  void _openAppPreferences(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => const AppearancePage()),
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

  void _openReadings(BuildContext context) {
    showReadingPreferencesSheet(
      context: context,
      profile: _profile,
      onProfileChanged: _handleProfileChanged,
    );
  }

  void _openMarkets(BuildContext context) {
    showMarketPreferencesSheet(
      context: context,
      profile: _profile,
      onProfileChanged: _handleProfileChanged,
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
    setState(() {
      _profile = profile;
    });
    await widget.onProfileChanged(profile);
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

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.user,
    required this.isSignedIn,
    required this.competitionCount,
    required this.readingCount,
    required this.scenarioCount,
    required this.activeStrategyCount,
    required this.onAccount,
  });

  final User? user;
  final bool isSignedIn;
  final int competitionCount;
  final int readingCount;
  final int scenarioCount;
  final int activeStrategyCount;
  final VoidCallback onAccount;

  @override
  Widget build(BuildContext context) {
    final name = _displayName(user);
    final email = user?.email;

    return LectorSpaceCard(
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
                      '$readingCount lecture${readingCount > 1 ? 's' : ''} · '
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

class _GroupedActionList extends StatelessWidget {
  const _GroupedActionList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LectorSpaceCard(
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

int _selectedReadingCount(DecisionProfile profile) {
  return ReadingPreferenceCatalog.normalizeSelectionIds(
    profile.optionIdsFor('readings'),
  ).length;
}

int _selectedMarketCount(DecisionProfile profile) {
  return MarketCatalog.enabledMarketIdsFor(
    profile.optionIdsFor('markets'),
  ).length;
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
