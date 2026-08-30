// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_components.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/lector_brand_mark.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../opportunities/domain/opportunity.dart';
import '../../tickets/domain/ticket_draft.dart';
import '../../tickets/domain/saved_ticket.dart';
import '../../tickets/domain/ticket_strategy.dart';
import '../domain/match_board_item.dart';
import 'opportunity_decision_presenter.dart';
import 'widgets/sports_asset_badge.dart';

const _matchCardStadiumBackgroundAsset =
    'assets/backgrounds/match-card-stadium-premium.png';

class MatchDetailPage extends StatefulWidget {
  const MatchDetailPage({
    required this.match,
    this.opportunity,
    this.ticketDraftListenable,
    this.ticketStrategies = const [],
    this.onToggleTicket,
    this.onRemoveTicketSelection,
    this.onTicketSaved,
    this.onViewSavedTickets,
    this.onOpenTicketSelection,
    super.key,
  });

  final MatchBoardItem match;
  final Opportunity? opportunity;
  final ValueListenable<TicketDraft>? ticketDraftListenable;
  final List<TicketStrategy> ticketStrategies;
  final ValueChanged<TicketDraftSelection>? onToggleTicket;
  final ValueChanged<String>? onRemoveTicketSelection;
  final ValueChanged<SavedTicket>? onTicketSaved;
  final VoidCallback? onViewSavedTickets;
  final ValueChanged<TicketDraftSelection>? onOpenTicketSelection;

  @override
  State<MatchDetailPage> createState() => _MatchDetailPageState();
}

class _MatchDetailPageState extends State<MatchDetailPage> {
  int _selectedFreeTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surfaces.background,
      body: Stack(
        children: [
          const _LectorMatchBackground(),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
                  sliver: SliverList.list(
                    children: [
                      _LectorMatchTopBar(
                        onBack: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(height: 10),
                      _LectorMatchHero(match: widget.match),
                      const SizedBox(height: 14),
                      _LectorRepereSection(match: widget.match),
                      const SizedBox(height: 14),
                      _LectorMatchTabBar(
                        selectedIndex: _selectedFreeTab,
                        onSelected: (index) {
                          setState(() => _selectedFreeTab = index);
                        },
                      ),
                      const SizedBox(height: 10),
                      _LectorFreeTabContent(
                        match: widget.match,
                        selectedIndex: _selectedFreeTab,
                      ),
                      const SizedBox(height: 10),
                      _LectorRecentMatchesCard(match: widget.match),
                      const SizedBox(height: 10),
                      _LectorFollowCard(match: widget.match),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Positioned(
            left: 14,
            bottom: 14,
            child: _MatchQuickDockButton(),
          ),
        ],
      ),
    );
  }
}

class _LectorMatchBackground extends StatelessWidget {
  const _LectorMatchBackground();

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final brand = context.brand;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF02070A),
            surfaces.background,
            const Color(0xFF050A0E),
          ],
        ),
      ),
      child: CustomPaint(
        painter: _LectorStadiumPainter(
          accent: brand.accent,
          border: surfaces.border,
          shadow: surfaces.shadow,
        ),
      ),
    );
  }
}

class _LectorStadiumPainter extends CustomPainter {
  const _LectorStadiumPainter({
    required this.accent,
    required this.border,
    required this.shadow,
  });

  final Color accent;
  final Color border;
  final Color shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.78),
        radius: 0.86,
        colors: [accent.withValues(alpha: 0.13), Colors.transparent],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, glow);

    final standTop = size.height * 0.18;
    final standBottom = size.height * 0.38;
    final standPaint = Paint()..color = const Color(0xFF0A151B);
    final standPath = Path()
      ..moveTo(0, standTop + 44)
      ..quadraticBezierTo(
        size.width * 0.5,
        standTop - 12,
        size.width,
        standTop + 44,
      )
      ..lineTo(size.width, standBottom)
      ..quadraticBezierTo(size.width * 0.5, standBottom + 24, 0, standBottom)
      ..close();
    canvas.drawPath(standPath, standPaint);

    final linePaint = Paint()
      ..color = border.withValues(alpha: 0.26)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < 6; i++) {
      final y = standTop + 46 + i * 18;
      final path = Path()
        ..moveTo(0, y)
        ..quadraticBezierTo(size.width * 0.5, y - 26, size.width, y);
      canvas.drawPath(path, linePaint);
    }

    final pitchTop = size.height * 0.36;
    final pitchPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF0B2524).withValues(alpha: 0.62),
          shadow.withValues(alpha: 0.18),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, pitchTop, size.width, size.height));
    canvas.drawRect(
      Rect.fromLTWH(0, pitchTop, size.width, size.height - pitchTop),
      pitchPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _LectorStadiumPainter oldDelegate) {
    return accent != oldDelegate.accent ||
        border != oldDelegate.border ||
        shadow != oldDelegate.shadow;
  }
}

class _LectorMatchTopBar extends StatelessWidget {
  const _LectorMatchTopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final textColors = context.textColors;

    return Row(
      children: [
        IconButton(
          tooltip: 'Retour',
          onPressed: onBack,
          icon: Icon(
            Icons.arrow_back_rounded,
            color: textColors.primary,
            size: 27,
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Notifications',
          onPressed: () => _showComingSoon(context, 'Alertes à brancher'),
          icon: Icon(
            Icons.notifications_none_rounded,
            color: textColors.primary,
            size: 24,
          ),
        ),
        IconButton(
          tooltip: 'Favori',
          onPressed: () => _showComingSoon(context, 'Favori à brancher'),
          icon: Icon(Icons.star_rounded, color: brand.accent, size: 28),
        ),
      ],
    );
  }
}

class _LectorDetailWordmark extends StatelessWidget {
  const _LectorDetailWordmark();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColors = context.textColors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _LectorDetailMark(size: 38),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'LECTOR SPORT',
              style: theme.textTheme.titleSmall?.copyWith(
                color: textColors.primary,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
            Text(
              'Read the Game.',
              style: theme.textTheme.labelMedium?.copyWith(
                color: textColors.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
                height: 1,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LectorDetailMark extends StatelessWidget {
  const _LectorDetailMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return LectorBrandMark(size: size);
  }
}

class _LectorMatchHero extends StatelessWidget {
  const _LectorMatchHero({required this.match});

  final MatchBoardItem match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = context.brand;
    final textColors = context.textColors;
    final venueLabel = _venueValue(match.fixture.venue);

    return _LectorGlassCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 13),
      backgroundAsset: _matchCardStadiumBackgroundAsset,
      child: Column(
        children: [
          Row(
            children: [
              SportsAssetBadge(
                size: 34,
                imageUrl: match.competition.logoUrl,
                fallbackLabel: match.competition.name,
                icon: Icons.emoji_events_outlined,
                backgroundColor: Colors.transparent,
                padding: 1,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      match.competition.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: textColors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Journée 34',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: brand.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _matchDateTimeLabel(match),
                textAlign: TextAlign.right,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: brand.accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _HeroTeamBlock(team: match.homeTeam, alignRight: false),
              ),
              const SizedBox(width: 8),
              _HeroStatusBlock(match: match),
              const SizedBox(width: 8),
              Expanded(
                child: _HeroTeamBlock(team: match.awayTeam, alignRight: true),
              ),
            ],
          ),
          if (venueLabel.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.stadium_outlined,
                  color: textColors.secondary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    venueLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: textColors.secondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroTeamBlock extends StatelessWidget {
  const _HeroTeamBlock({required this.team, required this.alignRight});

  final TeamInfo team;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColors = context.textColors;

    return Column(
      crossAxisAlignment: alignRight
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        SportsAssetBadge(
          size: 56,
          imageUrl: team.logoUrl,
          fallbackLabel: team.name,
          backgroundColor: Colors.transparent,
          padding: 1,
        ),
        const SizedBox(height: 7),
        Text(
          team.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
          style: theme.textTheme.titleMedium?.copyWith(
            color: textColors.primary,
            fontWeight: FontWeight.w900,
            height: 1.05,
          ),
        ),
      ],
    );
  }
}

class _HeroStatusBlock extends StatelessWidget {
  const _HeroStatusBlock({required this.match});

  final MatchBoardItem match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = context.brand;
    final textColors = context.textColors;
    final score = match.fixture.score;
    final isLive = match.fixture.status == FixtureStatus.live;
    final isFinished = match.fixture.status == FixtureStatus.finished;

    return SizedBox(
      width: 94,
      child: Column(
        children: [
          Text(
            isLive
                ? 'EN COURS'
                : isFinished
                ? 'TERMINÉ'
                : 'Avant-match',
            style: theme.textTheme.labelMedium?.copyWith(
              color: brand.accent,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          if (score != null)
            Text(
              '${score.home} - ${score.away}',
              style: theme.textTheme.displaySmall?.copyWith(
                color: textColors.primary,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            )
          else
            Text(
              '-',
              style: theme.textTheme.headlineLarge?.copyWith(
                color: textColors.primary,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          if (!isLive && !isFinished) ...[
            const SizedBox(height: 6),
            DecoratedBox(
              decoration: BoxDecoration(
                color: brand.accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                child: Text(
                  'Avant-match',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: brand.accent,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LectorRepereSection extends StatelessWidget {
  const _LectorRepereSection({required this.match});

  final MatchBoardItem match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = context.brand;
    final textColors = context.textColors;
    final primaryTitle = match.thesis?.title ?? _firstSignalTitle(match);
    final primarySubtitle = match.thesis == null
        ? 'Lecture disponible'
        : '${match.thesis!.supportingEvidence.length.clamp(1, 3)} lectures';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Repères Lector',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: textColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () =>
                  _showComingSoon(context, 'Explication premium à brancher'),
              icon: const Icon(Icons.lock_outline_rounded, size: 15),
              label: const Text('Pourquoi ?'),
              style: TextButton.styleFrom(foregroundColor: brand.accent),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _LectorRepereCard(
                icon: Icons.track_changes_rounded,
                title: primaryTitle,
                subtitle: primarySubtitle,
                color: brand.accent,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _LectorRepereCard(
                icon: Icons.compare_arrows_rounded,
                title: 'Match à suivre',
                subtitle: _secondaryRepereSubtitle(match),
                color: const Color(0xFF7A3CFF),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LectorRepereCard extends StatelessWidget {
  const _LectorRepereCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = context.surfaces;
    final textColors = context.textColors;

    return _LectorGlassCard(
      padding: const EdgeInsets.all(10),
      child: SizedBox(
        height: 68,
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 25),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: textColors.primary,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: surfaces.border.withValues(alpha: 0.95),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _LectorMatchTabBar extends StatelessWidget {
  const _LectorMatchTabBar({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _tabs = ['Contexte', 'Classement', 'Forme', 'Infos'];

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaces.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            for (var index = 0; index < _tabs.length; index++)
              Expanded(
                child: _LectorMatchTab(
                  label: _tabs[index],
                  isSelected: selectedIndex == index,
                  onPressed: () => onSelected(index),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LectorMatchTab extends StatelessWidget {
  const _LectorMatchTab({
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = context.brand;
    final textColors = context.textColors;

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: Center(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: isSelected ? brand.accent : textColors.primary,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 3,
            width: isSelected ? 58 : 0,
            decoration: BoxDecoration(
              color: brand.accent,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ),
    );
  }
}

class _LectorFreeTabContent extends StatelessWidget {
  const _LectorFreeTabContent({
    required this.match,
    required this.selectedIndex,
  });

  final MatchBoardItem match;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    return switch (selectedIndex) {
      0 => _LectorQuickContextCard(match: match),
      1 => _LectorStandingContextCard(match: match),
      2 => _LectorFormContextCard(match: match),
      _ => _LectorInfoContextCard(match: match),
    };
  }
}

class _LectorQuickContextCard extends StatelessWidget {
  const _LectorQuickContextCard({required this.match});

  final MatchBoardItem match;

  @override
  Widget build(BuildContext context) {
    final homeRank = _rankLabel(match.analysis.homeStanding);
    final awayRank = _rankLabel(match.analysis.awayStanding);
    final form = _bestFormResults(match);
    final awayWins = _awayWinsLabel(match);

    return _LectorInfoCard(
      title: 'Contexte rapide',
      rows: [
        _LectorInfoRow(
          icon: Icons.bar_chart_rounded,
          label: 'Classement',
          trailing: [
            TextSpan(text: '${match.homeTeam.name} $homeRank'),
            const TextSpan(text: ' · '),
            TextSpan(text: '${match.awayTeam.name} $awayRank'),
          ],
        ),
        _LectorInfoRow(
          icon: Icons.monitor_heart_outlined,
          label: 'Forme',
          customTrailing: _FormDots(results: form),
        ),
        _LectorInfoRow(
          icon: Icons.flight_takeoff_rounded,
          label: 'Extérieur',
          trailing: [TextSpan(text: awayWins)],
        ),
      ],
    );
  }
}

class _LectorStandingContextCard extends StatelessWidget {
  const _LectorStandingContextCard({required this.match});

  final MatchBoardItem match;

  @override
  Widget build(BuildContext context) {
    return _LectorInfoCard(
      title: 'Classement',
      rows: [
        _LectorInfoRow(
          icon: Icons.shield_outlined,
          label: match.homeTeam.name,
          trailing: [
            TextSpan(text: _standingSummary(match.analysis.homeStanding)),
          ],
        ),
        _LectorInfoRow(
          icon: Icons.shield_outlined,
          label: match.awayTeam.name,
          trailing: [
            TextSpan(text: _standingSummary(match.analysis.awayStanding)),
          ],
        ),
      ],
    );
  }
}

class _LectorFormContextCard extends StatelessWidget {
  const _LectorFormContextCard({required this.match});

  final MatchBoardItem match;

  @override
  Widget build(BuildContext context) {
    return _LectorInfoCard(
      title: 'Forme',
      rows: [
        _LectorInfoRow(
          icon: Icons.home_rounded,
          label: match.homeTeam.name,
          customTrailing: _FormDots(
            results: _matchDetailLastFiveResults(
              match.analysis.homeStatistics?.form ??
                  match.analysis.homeStanding?.form,
            ),
          ),
        ),
        _LectorInfoRow(
          icon: Icons.flight_takeoff_rounded,
          label: match.awayTeam.name,
          customTrailing: _FormDots(
            results: _matchDetailLastFiveResults(
              match.analysis.awayStatistics?.form ??
                  match.analysis.awayStanding?.form,
            ),
          ),
        ),
      ],
    );
  }
}

class _LectorInfoContextCard extends StatelessWidget {
  const _LectorInfoContextCard({required this.match});

  final MatchBoardItem match;

  @override
  Widget build(BuildContext context) {
    return _LectorInfoCard(
      title: 'Infos',
      rows: [
        _LectorInfoRow(
          icon: Icons.stadium_outlined,
          label: 'Stade',
          trailing: [TextSpan(text: _venueValue(match.fixture.venue))],
        ),
        _LectorInfoRow(
          icon: Icons.schedule_rounded,
          label: 'Horaire',
          trailing: [TextSpan(text: _matchDateTimeLabel(match))],
        ),
      ],
    );
  }
}

class _LectorInfoCard extends StatelessWidget {
  const _LectorInfoCard({required this.title, required this.rows});

  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColors = context.textColors;
    final surfaces = context.surfaces;

    return _LectorGlassCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: textColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < rows.length; index++) ...[
            rows[index],
            if (index < rows.length - 1)
              Divider(height: 16, color: surfaces.border),
          ],
        ],
      ),
    );
  }
}

class _LectorInfoRow extends StatelessWidget {
  const _LectorInfoRow({
    required this.icon,
    required this.label,
    this.trailing,
    this.customTrailing,
  });

  final IconData icon;
  final String label;
  final List<TextSpan>? trailing;
  final Widget? customTrailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = context.brand;
    final textColors = context.textColors;

    return Row(
      children: [
        Icon(icon, color: brand.accent, size: 23),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              color: textColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child:
              customTrailing ??
              Text.rich(
                TextSpan(
                  children: trailing,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: brand.accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              ),
        ),
      ],
    );
  }
}

class _FormDots extends StatelessWidget {
  const _FormDots({required this.results});

  final List<String> results;

  @override
  Widget build(BuildContext context) {
    final values = results.isEmpty ? const ['-', '-', '-', '-', '-'] : results;

    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 5,
      runSpacing: 4,
      children: [
        for (final result in values.take(5))
          Container(
            width: 23,
            height: 23,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _formDotColor(context, result),
            ),
            child: Text(
              _formDotLabel(result),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
      ],
    );
  }
}

class _LectorRecentMatchesCard extends StatelessWidget {
  const _LectorRecentMatchesCard({required this.match});

  final MatchBoardItem match;

  @override
  Widget build(BuildContext context) {
    final rows = _recentRows(match).take(3).toList();
    final theme = Theme.of(context);
    final textColors = context.textColors;
    final surfaces = context.surfaces;

    return _LectorGlassCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Derniers matchs',
            style: theme.textTheme.titleMedium?.copyWith(
              color: textColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            Text(
              'Les derniers matchs seront affichés dès que les données sont disponibles.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: textColors.secondary,
              ),
            )
          else
            for (var index = 0; index < rows.length; index++) ...[
              _RecentMatchLine(row: rows[index]),
              if (index < rows.length - 1)
                Divider(height: 14, color: surfaces.border),
            ],
        ],
      ),
    );
  }
}

class _RecentMatchLine extends StatelessWidget {
  const _RecentMatchLine({required this.row});

  final _RecentMatchUiRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColors = context.textColors;

    return Row(
      children: [
        SizedBox(
          width: 48,
          child: Text(
            row.meta,
            style: theme.textTheme.bodySmall?.copyWith(
              color: textColors.secondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SportsAssetBadge(
          size: 23,
          imageUrl: row.teamLogoUrl,
          fallbackLabel: row.teamName,
          backgroundColor: Colors.transparent,
          padding: 1,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            row.teamName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              color: textColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          row.score,
          style: theme.textTheme.titleSmall?.copyWith(
            color: textColors.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            row.opponentName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: theme.textTheme.titleSmall?.copyWith(
              color: textColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SportsAssetBadge(
          size: 23,
          imageUrl: row.opponentLogoUrl,
          fallbackLabel: row.opponentName,
          backgroundColor: Colors.transparent,
          padding: 1,
        ),
      ],
    );
  }
}

class _LectorFollowCard extends StatelessWidget {
  const _LectorFollowCard({required this.match});

  final MatchBoardItem match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColors = context.textColors;
    final surfaces = context.surfaces;
    final brand = context.brand;

    return _LectorGlassCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Suivre',
            style: theme.textTheme.titleMedium?.copyWith(
              color: textColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          _FollowActionRow(
            icon: Icons.notifications_none_rounded,
            label: 'Alerte coup d’envoi',
            onTap: () => _showComingSoon(context, 'Alerte à brancher'),
          ),
          Divider(height: 12, color: surfaces.border),
          _FollowActionRow(
            icon: Icons.star_border_rounded,
            label: 'Favori',
            trailing: Icon(Icons.star_rounded, color: brand.accent, size: 25),
            onTap: () => _showComingSoon(context, 'Favori à brancher'),
          ),
          Divider(height: 12, color: surfaces.border),
          _FollowActionRow(
            icon: Icons.groups_2_outlined,
            label: 'Composition disponible',
            onTap: () => _showComingSoon(context, 'Compositions à brancher'),
          ),
        ],
      ),
    );
  }
}

class _FollowActionRow extends StatelessWidget {
  const _FollowActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = context.brand;
    final textColors = context.textColors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.input),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Icon(icon, color: brand.accent, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: textColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  color: textColors.primary,
                  size: 23,
                ),
          ],
        ),
      ),
    );
  }
}

class _MatchQuickDockButton extends StatelessWidget {
  const _MatchQuickDockButton();

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final surfaces = context.surfaces;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showMatchDockSheet(context),
        borderRadius: BorderRadius.circular(22),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: surfaces.surface.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: brand.accent.withValues(alpha: 0.45)),
            boxShadow: [
              BoxShadow(
                color: brand.accent.withValues(alpha: 0.18),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _LectorDetailMark(size: 26),
              const SizedBox(width: 7),
              Text(
                'Match',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: brand.accent,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LectorGlassCard extends StatelessWidget {
  const _LectorGlassCard({
    required this.child,
    required this.padding,
    this.backgroundAsset,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final String? backgroundAsset;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final radius = BorderRadius.circular(AppRadius.control);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: surfaces.shadow.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: surfaces.border.withValues(alpha: 0.92)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(color: surfaces.surface.withValues(alpha: 0.72)),
          ),
          if (backgroundAsset != null) ...[
            Positioned.fill(
              child: Image.asset(
                backgroundAsset!,
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      surfaces.shadow.withValues(alpha: 0.18),
                      surfaces.shadow.withValues(alpha: 0.52),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: ColoredBox(
                color: surfaces.surface.withValues(alpha: 0.34),
              ),
            ),
          ],
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

class _RecentMatchUiRow {
  const _RecentMatchUiRow({
    required this.meta,
    required this.teamName,
    required this.opponentName,
    required this.score,
    this.teamLogoUrl,
    this.opponentLogoUrl,
  });

  final String meta;
  final String teamName;
  final String opponentName;
  final String score;
  final String? teamLogoUrl;
  final String? opponentLogoUrl;
}

void _showComingSoon(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

void _showMatchDockSheet(BuildContext context) {
  final brand = context.brand;
  final textColors = context.textColors;

  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _DockSheetAction(
                icon: Icons.article_outlined,
                label: 'Lectures',
                color: brand.accent,
              ),
              _DockSheetAction(
                icon: Icons.bar_chart_rounded,
                label: 'Stats',
                color: textColors.primary,
              ),
              _DockSheetAction(
                icon: Icons.star_border_rounded,
                label: 'Favori',
                color: textColors.primary,
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _DockSheetAction extends StatelessWidget {
  const _DockSheetAction({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => Navigator.of(context).pop(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: color)),
        ],
      ),
    );
  }
}

String _matchDateTimeLabel(MatchBoardItem match) {
  final label = match.fixture.kickoffLabel.trim();
  return label.isEmpty ? 'Aujourd’hui' : 'Aujourd’hui · $label';
}

String _venueValue(FixtureVenue? venue) {
  if (venue == null) {
    return 'Stade à confirmer';
  }
  final name = venue.name?.trim();
  final city = venue.city?.trim();
  return [
    if (name != null && name.isNotEmpty) name,
    if (city != null && city.isNotEmpty) city,
  ].join(' · ');
}

String _rankLabel(TeamStandingSnapshot? standing) {
  final rank = standing?.rank;
  if (rank == null) {
    return '-';
  }
  return '${rank}e';
}

String _standingSummary(TeamStandingSnapshot? standing) {
  if (standing == null) {
    return 'Donnée indisponible';
  }
  final rank = standing.rank == null ? '-' : '${standing.rank}e';
  final points = standing.points == null ? '-' : '${standing.points} pts';
  return '$rank · $points';
}

String _firstSignalTitle(MatchBoardItem match) {
  if (match.signals.isNotEmpty) {
    return match.signals.first.title;
  }
  return 'Lecture disponible';
}

String _secondaryRepereSubtitle(MatchBoardItem match) {
  if (match.signals.length > 1) {
    return match.signals[1].summary;
  }
  final homeRank = match.analysis.homeStanding?.rank;
  final awayRank = match.analysis.awayStanding?.rank;
  if (homeRank != null && awayRank != null) {
    return 'Écart de classement visible';
  }
  return 'Contexte à surveiller';
}

List<String> _bestFormResults(MatchBoardItem match) {
  final home = _matchDetailLastFiveResults(
    match.analysis.homeStatistics?.form ?? match.analysis.homeStanding?.form,
  );
  if (home.isNotEmpty) {
    return home;
  }
  return _matchDetailLastFiveResults(
    match.analysis.awayStatistics?.form ?? match.analysis.awayStanding?.form,
  );
}

String _awayWinsLabel(MatchBoardItem match) {
  final stats = match.analysis.awayStatistics;
  final wins = stats?.winsAway;
  final played = stats?.playedAway;
  if (wins != null && played != null && played > 0) {
    return '$wins victoire${wins > 1 ? 's' : ''} sur $played';
  }
  return 'Donnée à confirmer';
}

Color _formDotColor(BuildContext context, String result) {
  final value = result.toUpperCase();
  if (value == 'W' || value == 'V') {
    return context.brand.accent;
  }
  if (value == 'D' || value == 'N') {
    return Theme.of(context).colorScheme.outline;
  }
  if (value == 'L' || value == 'P') {
    return context.semantic.error;
  }
  return context.surfaces.border;
}

String _formDotLabel(String result) {
  final value = result.toUpperCase();
  return switch (value) {
    'W' => 'V',
    'D' => 'N',
    'L' => 'P',
    '-' => '-',
    _ => value.characters.take(1).toString(),
  };
}

List<_RecentMatchUiRow> _recentRows(MatchBoardItem match) {
  final homeRows = match.analysis.homeRecentLeagueMatches.map((recent) {
    final score = recent.goalsFor == null || recent.goalsAgainst == null
        ? recent.result
        : '${recent.goalsFor} - ${recent.goalsAgainst}';
    return _RecentMatchUiRow(
      meta: recent.venue == RecentMatchVenue.home ? 'Dom.' : 'Ext.',
      teamName: match.homeTeam.name,
      teamLogoUrl: match.homeTeam.logoUrl,
      opponentName: recent.opponentName,
      opponentLogoUrl: recent.opponentLogoUrl,
      score: score,
    );
  });

  final awayRows = match.analysis.awayRecentLeagueMatches.map((recent) {
    final score = recent.goalsFor == null || recent.goalsAgainst == null
        ? recent.result
        : '${recent.goalsFor} - ${recent.goalsAgainst}';
    return _RecentMatchUiRow(
      meta: recent.venue == RecentMatchVenue.home ? 'Dom.' : 'Ext.',
      teamName: match.awayTeam.name,
      teamLogoUrl: match.awayTeam.logoUrl,
      opponentName: recent.opponentName,
      opponentLogoUrl: recent.opponentLogoUrl,
      score: score,
    );
  });

  return [...homeRows, ...awayRows];
}

class _MatchDetailCloseAction extends StatelessWidget {
  const _MatchDetailCloseAction({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 430) {
      return Padding(
        padding: const EdgeInsets.only(right: AppSpacing.xs),
        child: IconButton(
          tooltip: 'Toutes les rencontres',
          onPressed: onPressed,
          icon: const Icon(Icons.list_rounded),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.md),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.list_rounded, size: 18),
        label: const Text('Toutes les rencontres'),
      ),
    );
  }
}

class _ProfileStatusBand extends StatelessWidget {
  const _ProfileStatusBand({required this.match});

  final MatchBoardItem match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: colorScheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cette compétition n’est pas activée dans votre profil.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Vous consultez ici toutes les rencontres disponibles.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Ajout de ${match.competition.name} au profil à brancher.',
                    ),
                  ),
                );
              },
              child: Text('Ajouter ${match.competition.name} à mon profil'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchDetailHeader extends StatelessWidget {
  const _MatchDetailHeader({required this.match});

  final MatchBoardItem match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final homeStanding = match.analysis.homeStanding;
    final awayStanding = match.analysis.awayStanding;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  match.fixture.kickoffLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    match.competition.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (match.profileStatus == MatchProfileStatus.outOfProfile)
                  _HeaderStatusPill(label: 'Hors profil'),
              ],
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 640;
                return Row(
                  children: [
                    Expanded(
                      child: _MatchHeaderTeam(
                        team: match.homeTeam,
                        standing: homeStanding,
                        alignment: CrossAxisAlignment.center,
                        isCompact: true,
                      ),
                    ),
                    SizedBox(width: isCompact ? 8 : 18),
                    _ScoreSeparator(isCompact: isCompact),
                    SizedBox(width: isCompact ? 8 : 18),
                    Expanded(
                      child: _MatchHeaderTeam(
                        team: match.awayTeam,
                        standing: awayStanding,
                        alignment: CrossAxisAlignment.center,
                        isCompact: true,
                      ),
                    ),
                  ],
                );
              },
            ),
            if (match.fixture.venue != null) ...[
              const SizedBox(height: 16),
              _VenueLine(venue: match.fixture.venue!),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeaderStatusPill extends StatelessWidget {
  const _HeaderStatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 5),
            Icon(
              Icons.info_outline_rounded,
              size: 14,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchHeaderTeam extends StatelessWidget {
  const _MatchHeaderTeam({
    required this.team,
    required this.standing,
    required this.alignment,
    this.isCompact = false,
  });

  final TeamInfo team;
  final TeamStandingSnapshot? standing;
  final CrossAxisAlignment alignment;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rank = standing?.rank;
    final points = standing?.points;
    final meta = [
      if (rank != null) '${rank}e',
      if (points != null) '$points pts',
    ].join(' · ');

    return Column(
      crossAxisAlignment: alignment,
      children: [
        SportsAssetBadge(
          size: isCompact ? 54 : 74,
          imageUrl: team.logoUrl,
          fallbackLabel: team.name,
          borderRadius: 8,
        ),
        const SizedBox(height: 12),
        Text(
          team.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: alignment == CrossAxisAlignment.end
              ? TextAlign.right
              : alignment == CrossAxisAlignment.center
              ? TextAlign.center
              : TextAlign.left,
          style:
              (isCompact
                      ? theme.textTheme.titleMedium
                      : theme.textTheme.headlineSmall)
                  ?.copyWith(fontWeight: FontWeight.w900),
        ),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            meta,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ],
    );
  }
}

class _ScoreSeparator extends StatelessWidget {
  const _ScoreSeparator({this.isCompact = false});

  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final style = isCompact
        ? Theme.of(context).textTheme.headlineSmall
        : Theme.of(context).textTheme.headlineMedium;

    return Text(
      '–',
      style: style?.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _VenueLine extends StatelessWidget {
  const _VenueLine({required this.venue});

  final FixtureVenue venue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final city = venue.city;
    final name = venue.name;
    final value = [
      if (name != null && name.isNotEmpty) name,
      if (city != null && city.isNotEmpty) city,
    ].join(' · ');

    if (value.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        Icon(Icons.location_on_rounded, size: 16, color: colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          l10n.venueLabel,
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer.withValues(alpha: 0.80),
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(padding: const EdgeInsets.all(14), child: child),
    );
  }
}

class _CopilotReadingSection extends StatefulWidget {
  const _CopilotReadingSection({
    required this.match,
    required this.opportunity,
  });

  final MatchBoardItem match;
  final Opportunity? opportunity;

  @override
  State<_CopilotReadingSection> createState() => _CopilotReadingSectionState();
}

class _CopilotReadingSectionState extends State<_CopilotReadingSection> {
  bool _isOpen = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final theses =
        widget.opportunity?.retainedTheses ??
        [if (widget.match.thesis != null) widget.match.thesis!];
    final title = OpportunityDecisionPresenter.opportunityTitleFromTheses(
      theses,
    );
    final argumentCount = widget.opportunity?.argumentCount ?? 0;
    final vigilanceCount = widget.opportunity?.contradictionCount ?? 0;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CollapsibleHeader(
            icon: Icons.auto_awesome_rounded,
            title: l10n.copilotReadingTitle,
            summary: theses.isEmpty
                ? 'Aucune lecture combinée'
                : '$title · $argumentCount argument${argumentCount > 1 ? 's' : ''} · $vigilanceCount vigilance${vigilanceCount > 1 ? 's' : ''}',
            isOpen: _isOpen,
            onPressed: () {
              setState(() {
                _isOpen = !_isOpen;
              });
            },
          ),
          if (_isOpen) ...[
            const SizedBox(height: 12),
            if (theses.isNotEmpty) ...[
              _ReadingTitlePill(label: title, thesisId: theses.first.id),
              const SizedBox(height: 10),
            ],
            theses.isEmpty
                ? widget.match.signals.isEmpty
                      ? Text(
                          l10n.noCopilotSignalsMessage,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        )
                      : Column(
                          children: [
                            for (final signal in widget.match.signals)
                              _CopilotSignalTile(signal: signal),
                          ],
                        )
                : Text(
                    _compactReadingText(theses),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
            if (widget.opportunity != null) ...[
              const SizedBox(height: 10),
              _ReadingValidationSummary(opportunity: widget.opportunity!),
            ],
          ],
        ],
      ),
    );
  }

  String _compactReadingText(List<MatchThesis> theses) {
    final primary = theses.first;
    final title = primary.title.toLowerCase();
    if (title.contains('ouvert')) {
      return 'Plusieurs indicateurs offensifs et défensifs convergent vers un scénario avec des espaces et des buts.';
    }
    if (title.contains('fermé')) {
      return 'Plusieurs indicateurs convergent vers un scénario plus contrôlé et moins ouvert.';
    }
    if (title.contains('favori')) {
      return 'Les signaux disponibles convergent vers une équipe mieux placée pour maîtriser la rencontre.';
    }
    if (title.contains('outsider')) {
      return 'La lecture signale un outsider plus crédible que sa cote ou son statut ne le suggère.';
    }

    return primary.summary;
  }
}

class _CollapsibleHeader extends StatelessWidget {
  const _CollapsibleHeader({
    required this.icon,
    required this.title,
    required this.summary,
    required this.isOpen,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String summary;
  final bool isOpen;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.input),
      onTap: onPressed,
      child: Row(
        children: [
          Icon(icon, color: colorScheme.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            isOpen
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            color: colorScheme.onSurface,
          ),
        ],
      ),
    );
  }
}

class _ReadingTitlePill extends StatelessWidget {
  const _ReadingTitlePill({required this.label, required this.thesisId});

  final String label;
  final String thesisId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badge = context.opportunities.badgeFor(
      thesisId,
      variant: AppReadingBadgeVariant.combined,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: badge.background,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: badge.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Text(
          label.toUpperCase(),
          style: theme.textTheme.labelMedium?.copyWith(
            color: badge.foreground,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _ReadingValidationSummary extends StatelessWidget {
  const _ReadingValidationSummary({required this.opportunity});

  final Opportunity opportunity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final arguments = opportunity.argumentCount;
    final contradictions = opportunity.contradictionCount;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.hub_rounded, color: colorScheme.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Lecture combinée validée par $arguments argument${arguments > 1 ? 's' : ''} convergent${arguments > 1 ? 's' : ''}'
                ' et $contradictions point${contradictions > 1 ? 's' : ''} de vigilance.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CopilotArgumentsSection extends StatefulWidget {
  const _CopilotArgumentsSection({
    required this.match,
    required this.opportunity,
  });

  final MatchBoardItem match;
  final Opportunity? opportunity;

  @override
  State<_CopilotArgumentsSection> createState() =>
      _CopilotArgumentsSectionState();
}

class _CopilotArgumentsSectionState extends State<_CopilotArgumentsSection> {
  bool _isOpen = false;

  @override
  Widget build(BuildContext context) {
    final allArguments =
        widget.opportunity?.copilotArguments ??
        widget.match.thesis?.arguments ??
        const [];
    final positiveArguments =
        widget.opportunity?.positiveArguments ??
        allArguments
            .where(
              (argument) =>
                  argument.family != CopilotArgumentFamily.contradiction,
            )
            .toList();
    final contradictions =
        widget.opportunity?.contradictions ??
        allArguments
            .where(
              (argument) =>
                  argument.family == CopilotArgumentFamily.contradiction,
            )
            .toList();
    final evidence =
        widget.opportunity?.statisticalEvidence ??
        widget.match.thesis?.supportingEvidence ??
        const [];
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final argumentCount = positiveArguments.length;
    final vigilanceCount = contradictions.length;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CollapsibleHeader(
            icon: Icons.fact_check_outlined,
            title: 'Lectures simples retenues',
            summary:
                '$argumentCount lecture${argumentCount > 1 ? 's' : ''} · $vigilanceCount vigilance${vigilanceCount > 1 ? 's' : ''}',
            isOpen: _isOpen,
            onPressed: () {
              setState(() {
                _isOpen = !_isOpen;
              });
            },
          ),
          if (_isOpen) ...[
            const SizedBox(height: 12),
            if (positiveArguments.isNotEmpty || contradictions.isNotEmpty) ...[
              _CopilotArgumentGroup(
                title: 'Lectures retenues',
                emptyMessage:
                    'Aucune lecture simple détaillée n’est disponible pour cette lecture combinée.',
                arguments: positiveArguments,
                match: widget.match,
              ),
              const SizedBox(height: 14),
              _CopilotArgumentGroup(
                title: 'Points de vigilance',
                emptyMessage: 'Aucun point de vigilance détecté.',
                arguments: contradictions,
                match: widget.match,
                isVigilance: true,
              ),
            ] else if (evidence.isNotEmpty)
              _EvidenceGroup(title: 'Preuves disponibles', evidence: evidence)
            else
              Text(
                'Aucune lecture simple détaillée n’est disponible pour cette lecture combinée.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _CopilotArgumentGroup extends StatelessWidget {
  const _CopilotArgumentGroup({
    required this.title,
    required this.emptyMessage,
    required this.arguments,
    required this.match,
    this.isVigilance = false,
  });

  final String title;
  final String emptyMessage;
  final List<CopilotArgument> arguments;
  final MatchBoardItem match;
  final bool isVigilance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final groupedArguments = _groupArguments(arguments);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        if (arguments.isEmpty)
          DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                emptyMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          )
        else
          Column(
            children: [
              for (final group in groupedArguments.indexed) ...[
                _GroupedCopilotArgumentCard(
                  group: group.$2,
                  match: match,
                  isVigilance: isVigilance,
                ),
                if (group.$1 < groupedArguments.length - 1)
                  const SizedBox(height: 10),
              ],
            ],
          ),
      ],
    );
  }

  List<_ArgumentPresentationGroup> _groupArguments(
    List<CopilotArgument> arguments,
  ) {
    final groupsByKey = <String, List<CopilotArgument>>{};
    for (final argument in arguments) {
      final key =
          '${FootballReadingCopyCatalog.readingIdFor(argument)}_${argument.subjectName}';
      groupsByKey.putIfAbsent(key, () => []).add(argument);
    }

    return [
      for (final entry in groupsByKey.entries)
        _ArgumentPresentationGroup(arguments: entry.value),
    ];
  }
}

class _ArgumentPresentationGroup {
  const _ArgumentPresentationGroup({required this.arguments});

  final List<CopilotArgument> arguments;

  CopilotArgument get primary => arguments.first;
}

class _GroupedCopilotArgumentCard extends StatelessWidget {
  const _GroupedCopilotArgumentCard({
    required this.group,
    required this.match,
    required this.isVigilance,
  });

  final _ArgumentPresentationGroup group;
  final MatchBoardItem match;
  final bool isVigilance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = group.primary;
    final presenter = CopilotArgumentPresenter(primary);
    final readingId = FootballReadingCopyCatalog.readingIdFor(primary);
    final badge = context.opportunities.badgeFor(
      isVigilance ? 'contradiction' : readingId,
      variant: isVigilance
          ? AppReadingBadgeVariant.soft
          : AppReadingBadgeVariant.simple,
    );
    final color = badge.foreground;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: badge.background,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: badge.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _argumentGroupIcon(primary),
                  color: badge.iconColor,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    presenter.headline,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final argument in group.arguments.indexed) ...[
              _ArgumentEvidenceLine(
                argument: argument.$2,
                match: match,
                color: color,
              ),
              if (argument.$1 < group.arguments.length - 1)
                const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  IconData _argumentGroupIcon(CopilotArgument argument) {
    return switch (argument.family) {
      CopilotArgumentFamily.hierarchy => Icons.bar_chart_rounded,
      CopilotArgumentFamily.performance => Icons.home_work_outlined,
      CopilotArgumentFamily.defense => Icons.shield_outlined,
      CopilotArgumentFamily.attack => Icons.trending_up_rounded,
      CopilotArgumentFamily.form => Icons.show_chart_rounded,
      CopilotArgumentFamily.rhythm => Icons.auto_graph_rounded,
      CopilotArgumentFamily.market => Icons.track_changes_rounded,
      CopilotArgumentFamily.contradiction => Icons.warning_amber_rounded,
    };
  }
}

class _ArgumentEvidenceLine extends StatelessWidget {
  const _ArgumentEvidenceLine({
    required this.argument,
    required this.match,
    required this.color,
  });

  final CopilotArgument argument;
  final MatchBoardItem match;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final presenter = CopilotArgumentPresenter(argument);
    final showSummary =
        argument.evidence.isEmpty ||
        !FootballReadingCopyCatalog.hasStructuredEvidence(argument);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle_outline_rounded, color: color, size: 17),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _displaySubjectName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              if (showSummary)
                Text(
                  _displaySummary(presenter.summary),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              for (final evidence in argument.evidence)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _displayText(
                      FootballReadingCopyCatalog.evidenceLineFor(
                        argument,
                        evidence,
                      ),
                    ),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String get _displaySubjectName {
    final subject = argument.subjectName;
    if (subject == match.homeTeam.id ||
        subject == match.homeTeam.apiFootballTeamId?.toString() ||
        subject == 'api-team-${match.homeTeam.apiFootballTeamId}') {
      return match.homeTeam.name;
    }
    if (subject == match.awayTeam.id ||
        subject == match.awayTeam.apiFootballTeamId?.toString() ||
        subject == 'api-team-${match.awayTeam.apiFootballTeamId}') {
      return match.awayTeam.name;
    }
    if (subject == match.id) {
      return 'La rencontre';
    }
    return subject;
  }

  String _displaySummary(String summary) {
    return _displayText(summary);
  }

  String _displayText(String text) {
    return text
        .replaceAll(match.homeTeam.id, match.homeTeam.name)
        .replaceAll(
          'api-team-${match.homeTeam.apiFootballTeamId}',
          match.homeTeam.name,
        )
        .replaceAll(match.awayTeam.id, match.awayTeam.name)
        .replaceAll(
          'api-team-${match.awayTeam.apiFootballTeamId}',
          match.awayTeam.name,
        )
        .replaceAll(match.id, 'la rencontre');
  }
}

class _ThesisReading extends StatelessWidget {
  const _ThesisReading({required this.thesis});

  final MatchThesis thesis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final arguments = thesis.arguments;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (arguments.isNotEmpty)
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 760;
              final spacing = isWide ? 14.0 : 10.0;
              final width = isWide
                  ? (constraints.maxWidth - spacing) / 2
                  : constraints.maxWidth;

              return Wrap(
                spacing: spacing,
                runSpacing: 14,
                children: [
                  for (final argument in arguments)
                    SizedBox(
                      width: width,
                      child: _CopilotArgumentCard(argument: argument),
                    ),
                ],
              );
            },
          )
        else ...[
          Text(
            thesis.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            thesis.summary,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (thesis.supportingEvidence.isNotEmpty) ...[
            const SizedBox(height: 12),
            _EvidenceGroup(
              title: 'Preuves disponibles',
              evidence: thesis.supportingEvidence,
            ),
          ],
        ],
        if (thesis.limits.isNotEmpty) ...[
          const SizedBox(height: 14),
          _CompactEvidenceLine(evidence: thesis.limits.first),
        ] else if (thesis.profileReasons.isNotEmpty) ...[
          const SizedBox(height: 14),
          _ProfileFitNotice(reasonCount: thesis.profileReasons.length),
        ],
      ],
    );
  }
}

class _CompactEvidenceLine extends StatelessWidget {
  const _CompactEvidenceLine({required this.evidence});

  final ThesisEvidence evidence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline_rounded,
          size: 16,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            evidence.label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileFitNotice extends StatelessWidget {
  const _ProfileFitNotice({required this.reasonCount});

  final int reasonCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Icon(Icons.tune_rounded, color: colorScheme.primary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                reasonCount > 1
                    ? 'Cette lecture recoupe plusieurs priorités de votre profil.'
                    : 'Cette lecture recoupe une priorité de votre profil.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CopilotArgumentCard extends StatefulWidget {
  const _CopilotArgumentCard({required this.argument});

  final CopilotArgument argument;

  @override
  State<_CopilotArgumentCard> createState() => _CopilotArgumentCardState();
}

class _CopilotArgumentCardState extends State<_CopilotArgumentCard> {
  bool _isOpen = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final argument = widget.argument;
    final presenter = CopilotArgumentPresenter(argument);
    final readingId = FootballReadingCopyCatalog.readingIdFor(argument);
    final badge = context.opportunities.badgeFor(
      argument.family == CopilotArgumentFamily.contradiction
          ? 'contradiction'
          : readingId,
      variant: AppReadingBadgeVariant.simple,
    );

    return Material(
      color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.56),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          setState(() {
            _isOpen = !_isOpen;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: badge.background,
                      borderRadius: BorderRadius.circular(AppRadius.control),
                      border: Border.all(color: badge.border),
                    ),
                    child: SizedBox.square(
                      dimension: 42,
                      child: Icon(
                        _argumentIcon(argument),
                        color: badge.iconColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          presenter.headline,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          presenter.summary,
                          maxLines: _isOpen ? null : 3,
                          overflow: _isOpen ? null : TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      presenter.actionLabel,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Icon(
                    _isOpen
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.arrow_forward_rounded,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                ],
              ),
              if (_isOpen && argument.evidence.isNotEmpty) ...[
                const SizedBox(height: 14),
                Divider(height: 1, color: colorScheme.outlineVariant),
                const SizedBox(height: 12),
                for (final evidence in argument.evidence)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: _EvidenceRow(evidence: evidence),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _argumentIcon(CopilotArgument argument) {
    return switch (argument.family) {
      CopilotArgumentFamily.hierarchy => Icons.emoji_events_outlined,
      CopilotArgumentFamily.performance => Icons.trending_down_rounded,
      CopilotArgumentFamily.defense => Icons.shield_outlined,
      CopilotArgumentFamily.attack => Icons.trending_up_rounded,
      CopilotArgumentFamily.form => Icons.show_chart_rounded,
      CopilotArgumentFamily.rhythm => Icons.speed_rounded,
      CopilotArgumentFamily.market => Icons.stacked_line_chart_rounded,
      CopilotArgumentFamily.contradiction => Icons.warning_amber_rounded,
    };
  }
}

class _RecommendedMarketPanel extends StatelessWidget {
  const _RecommendedMarketPanel({
    required this.match,
    required this.recommendedMarket,
    required this.rationale,
    required this.ticketDraftListenable,
    required this.onToggleTicket,
  });

  final MatchBoardItem match;
  final RecommendedMarket recommendedMarket;
  final String rationale;
  final ValueListenable<TicketDraft>? ticketDraftListenable;
  final ValueChanged<TicketDraftSelection>? onToggleTicket;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final components = context.components;
    final bookmaker = recommendedMarket.market.bookmakerName;
    final ticketSelection = TicketDraftSelection.fromMatchSelection(
      match,
      recommendedMarket.market,
      recommendedMarket.selection,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: components.oddsBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle_rounded, color: components.oddsText),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Marché proposé',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: components.oddsText,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${recommendedMarket.market.label} · ${recommendedMarket.selection.label}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (bookmaker != null && bookmaker.isNotEmpty)
                        Text(
                          bookmaker,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  recommendedMarket.selection.odds.toStringAsFixed(2),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: components.oddsText,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (ticketSelection != null &&
                    ticketDraftListenable != null &&
                    onToggleTicket != null) ...[
                  const SizedBox(width: 10),
                  ValueListenableBuilder<TicketDraft>(
                    valueListenable: ticketDraftListenable!,
                    builder: (context, ticket, _) {
                      final isSelected = ticket.contains(ticketSelection.id);
                      final isBlockedByMatch = ticket
                          .containsAnotherSelectionForMatch(ticketSelection);
                      final canToggle = isSelected || !isBlockedByMatch;
                      return IconButton.filled(
                        tooltip: isSelected
                            ? 'Retirer du ticket'
                            : isBlockedByMatch
                            ? 'Ce match est déjà dans Mon ticket'
                            : 'Ajouter au ticket',
                        onPressed: canToggle
                            ? () => onToggleTicket!(ticketSelection)
                            : null,
                        icon: Icon(
                          isSelected
                              ? Icons.check_rounded
                              : isBlockedByMatch
                              ? Icons.block_rounded
                              : Icons.add_rounded,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: isSelected
                              ? colorScheme.primary.withValues(alpha: 0.18)
                              : isBlockedByMatch
                              ? colorScheme.surfaceContainerHighest
                              : colorScheme.primary,
                          foregroundColor: isSelected
                              ? colorScheme.primary
                              : isBlockedByMatch
                              ? colorScheme.onSurfaceVariant
                              : colorScheme.onPrimary,
                          side: BorderSide(
                            color: isBlockedByMatch
                                ? colorScheme.outlineVariant
                                : colorScheme.primary,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
            Divider(height: 22, color: colorScheme.outlineVariant),
            Text(
              'Pourquoi ce marché ?',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              rationale,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EvidenceGroup extends StatelessWidget {
  const _EvidenceGroup({required this.title, required this.evidence});

  final String title;
  final List<ThesisEvidence> evidence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelLarge?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        for (final item in evidence)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: _EvidenceRow(evidence: item),
          ),
      ],
    );
  }
}

class _EvidenceRow extends StatelessWidget {
  const _EvidenceRow({required this.evidence});

  final ThesisEvidence evidence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _colorFor(context, evidence.tone);
    final icon = switch (evidence.tone) {
      ThesisEvidenceTone.positive => Icons.check_rounded,
      ThesisEvidenceTone.warning => Icons.priority_high_rounded,
      ThesisEvidenceTone.negative => Icons.close_rounded,
      ThesisEvidenceTone.neutral => Icons.info_outline_rounded,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AppRadius.tight),
          ),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Icon(icon, size: 15, color: color),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            evidence.label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Color _colorFor(BuildContext context, ThesisEvidenceTone tone) {
    final colorScheme = Theme.of(context).colorScheme;

    return switch (tone) {
      ThesisEvidenceTone.positive => colorScheme.primary,
      ThesisEvidenceTone.warning => context.semantic.warning,
      ThesisEvidenceTone.negative => colorScheme.error,
      ThesisEvidenceTone.neutral => colorScheme.onSurfaceVariant,
    };
  }
}

class _CopilotSignalTile extends StatelessWidget {
  const _CopilotSignalTile({required this.signal});

  final MatchSignal signal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
      childrenPadding: const EdgeInsets.fromLTRB(44, 0, 12, 12),
      leading: Icon(Icons.insights_rounded, color: colorScheme.primary),
      title: Text(
        signal.title,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w900,
        ),
      ),
      subtitle: Text(signal.summary),
      shape: const Border(),
      collapsedShape: const Border(),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final proof in signal.proofs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• $proof',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnalysisSection extends StatefulWidget {
  const _AnalysisSection({required this.match, required this.opportunity});

  final MatchBoardItem match;
  final Opportunity? opportunity;

  @override
  State<_AnalysisSection> createState() => _AnalysisSectionState();
}

class _AnalysisSectionState extends State<_AnalysisSection> {
  _AnalysisTab _selectedTab = _AnalysisTab.standings;
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final match = widget.match;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CollapsibleHeader(
            icon: Icons.bar_chart_rounded,
            title: 'Vérifier les données',
            summary: match.analysis.hasAnalysisData
                ? 'Données snapshot disponibles'
                : 'Snapshot incomplet',
            isOpen: _isExpanded,
            onPressed: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
          ),
          if (_isExpanded) ...[
            const SizedBox(height: 12),
            Text(
              'Championnat uniquement · Amicaux et coupes exclus',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final tab in _AnalysisTab.values) ...[
                    _AnalysisTabButton(
                      label: tab.label,
                      isSelected: _selectedTab == tab,
                      onPressed: () {
                        setState(() {
                          _selectedTab = tab;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (!match.analysis.hasAnalysisData)
              Text(
                'Aucune donnée de classement, forme ou statistiques d’équipe disponible pour ce match.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            else
              switch (_selectedTab) {
                _AnalysisTab.standings => _StandingsPanel(match: match),
                _AnalysisTab.form => _FormComparisonPanel(match: match),
                _AnalysisTab.homeAway => _HomeAwayPanel(match: match),
                _AnalysisTab.attackDefense => _AttackDefensePanel(
                  match: match,
                  opportunity: widget.opportunity,
                ),
                _AnalysisTab.series => _SeriesPanel(match: match),
              },
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Source des données : API-Football',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

enum _AnalysisTab {
  standings('Classement'),
  form('Forme (5 matchs)'),
  homeAway('Domicile / Extérieur'),
  attackDefense('Attaque / Défense'),
  series('Séries');

  const _AnalysisTab(this.label);

  final String label;
}

class _AnalysisTabButton extends StatelessWidget {
  const _AnalysisTabButton({
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected
            ? colorScheme.primary.withValues(alpha: 0.13)
            : colorScheme.surfaceContainerHigh,
        foregroundColor: isSelected
            ? colorScheme.primary
            : colorScheme.onSurface,
        side: BorderSide(
          color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _AnalysisPlaceholder extends StatelessWidget {
  const _AnalysisPlaceholder({required this.tab});

  final _AnalysisTab tab;

  String get _message {
    return switch (tab) {
      _AnalysisTab.form =>
        'La forme récente sera affichée dès que le snapshot contient les derniers matchs de championnat.',
      _AnalysisTab.standings =>
        'Le classement sera affiché dès que le snapshot contient la table de cette ligue.',
      _AnalysisTab.homeAway =>
        'Les splits domicile/extérieur seront affichés dès que les statistiques d’équipe sont disponibles.',
      _AnalysisTab.attackDefense =>
        'Les indicateurs attaque/défense seront affichés dès que les statistiques d’équipe sont disponibles.',
      _ =>
        '${tab.label} sera alimenté dès que ces données sont présentes dans le snapshot.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Text(
            _message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _FormComparisonPanel extends StatelessWidget {
  const _FormComparisonPanel({required this.match});

  final MatchBoardItem match;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final homeResults = _lastFiveResults(
      match.analysis.homeStatistics,
      match.analysis.homeStanding,
    );
    final awayResults = _lastFiveResults(
      match.analysis.awayStatistics,
      match.analysis.awayStanding,
    );
    final homeWindow = _FormWindowStats.from(
      recentMatches: match.analysis.homeRecentLeagueMatches,
      fallbackResults: homeResults,
    );
    final awayWindow = _FormWindowStats.from(
      recentMatches: match.analysis.awayRecentLeagueMatches,
      fallbackResults: awayResults,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _VerificationInsightLine(
              text: 'Championnat uniquement · Amicaux et coupes exclus',
            ),
            const SizedBox(height: 16),
            _TeamFormTableBlock(
              team: match.homeTeam,
              statistics: match.analysis.homeStatistics,
              standing: match.analysis.homeStanding,
              recentMatches: match.analysis.homeRecentLeagueMatches,
            ),
            Divider(height: 24, color: colorScheme.outlineVariant),
            _TeamFormTableBlock(
              team: match.awayTeam,
              statistics: match.analysis.awayStatistics,
              standing: match.analysis.awayStanding,
              recentMatches: match.analysis.awayRecentLeagueMatches,
            ),
            const SizedBox(height: 12),
            _FormSynthesisCard(
              text: _formComparisonText(
                match.homeTeam.name,
                match.awayTeam.name,
                homeWindow,
                awayWindow,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _lastFiveResults(
    TeamStatisticsSnapshot? statistics,
    TeamStandingSnapshot? standing,
  ) {
    return _matchDetailLastFiveResults(statistics?.form ?? standing?.form);
  }

  String _formComparisonText(
    String homeName,
    String awayName,
    _FormWindowStats home,
    _FormWindowStats away,
  ) {
    if (!home.hasResults || !away.hasResults) {
      return 'Donnée insuffisante pour produire une comparaison de forme fiable.';
    }

    if (home.points == away.points) {
      return 'Sur les 5 derniers matchs de championnat, les deux équipes présentent une dynamique récente comparable.';
    }

    final strongerName = home.points > away.points ? homeName : awayName;
    final weakerName = home.points > away.points ? awayName : homeName;
    final stronger = home.points > away.points ? home : away;
    final weaker = home.points > away.points ? away : home;
    final defensiveNote =
        stronger.goalsAgainstTotal != null &&
            weaker.goalsAgainstTotal != null &&
            stronger.goalsAgainstTotal! < weaker.goalsAgainstTotal!
        ? ' et encaisse moins de buts'
        : '';

    return 'Sur les 5 derniers matchs de championnat, $strongerName est plus régulier$defensiveNote, tandis que $weakerName présente une dynamique plus instable.';
  }
}

class _TeamFormTableBlock extends StatelessWidget {
  const _TeamFormTableBlock({
    required this.team,
    required this.statistics,
    required this.standing,
    required this.recentMatches,
  });

  final TeamInfo team;
  final TeamStatisticsSnapshot? statistics;
  final TeamStandingSnapshot? standing;
  final List<TeamRecentMatchSnapshot> recentMatches;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final fallbackResults = _matchDetailLastFiveResults(
      statistics?.form ?? standing?.form,
    );
    final stats = _FormWindowStats.from(
      recentMatches: recentMatches,
      fallbackResults: fallbackResults,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SportsAssetBadge(
              size: 30,
              imageUrl: team.logoUrl,
              fallbackLabel: team.name,
              borderRadius: AppRadius.tight,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                team.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          '5 derniers matchs de championnat',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        if (!stats.hasResults)
          Text(
            'Forme récente indisponible dans le snapshot actuel.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          )
        else ...[
          _RecentFormTable(matches: recentMatches),
          const SizedBox(height: 10),
          _FormSummaryBar(stats: stats),
          if (recentMatches.isEmpty) ...[
            const SizedBox(height: 8),
            const _VerificationInsightLine(
              text:
                  'Le snapshot fournit seulement la série brute pour cette équipe ; le détail match par match n’est pas disponible.',
            ),
          ],
        ],
      ],
    );
  }
}

class _RecentFormTable extends StatelessWidget {
  const _RecentFormTable({required this.matches});

  final List<TeamRecentMatchSnapshot> matches;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: Column(
          children: [
            const _RecentFormHeader(),
            if (matches.isEmpty)
              const _RecentFormUnavailableRow()
            else
              for (var index = 0; index < matches.length; index++)
                _RecentFormRow(
                  match: matches[index],
                  showDivider: index < matches.length - 1,
                ),
          ],
        ),
      ),
    );
  }
}

class _RecentFormHeader extends StatelessWidget {
  const _RecentFormHeader();

  @override
  Widget build(BuildContext context) {
    return _RecentFormTableLine(
      opponent: const Text('Adversaire'),
      venue: const Text('Lieu'),
      score: const Text('Score'),
      result: const Text('Résultat'),
      textColor: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w800,
    );
  }
}

class _RecentFormUnavailableRow extends StatelessWidget {
  const _RecentFormUnavailableRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _RecentFormTableLine(
      opponent: Text(
        'Détail match par match indisponible.',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
      venue: const Text('—'),
      score: const Text('—'),
      result: const Text('—'),
    );
  }
}

class _RecentFormRow extends StatelessWidget {
  const _RecentFormRow({required this.match, required this.showDivider});

  final TeamRecentMatchSnapshot match;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.62),
                ),
              )
            : null,
      ),
      child: _RecentFormTableLine(
        opponent: Row(
          children: [
            SportsAssetBadge(
              size: 26,
              imageUrl: match.opponentLogoUrl,
              fallbackLabel: match.opponentName,
              borderRadius: AppRadius.tight,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                match.opponentName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        venue: _VenueBadge(venue: match.venue),
        score: Text(
          _scoreLabel(match),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        result: Align(
          alignment: Alignment.centerRight,
          child: _FormResultBadge(result: match.result),
        ),
      ),
    );
  }

  String _scoreLabel(TeamRecentMatchSnapshot match) {
    if (match.goalsFor == null || match.goalsAgainst == null) {
      return '—';
    }
    return '${match.goalsFor}-${match.goalsAgainst}';
  }
}

class _RecentFormTableLine extends StatelessWidget {
  const _RecentFormTableLine({
    required this.opponent,
    required this.venue,
    required this.score,
    required this.result,
    this.textColor,
    this.fontWeight,
  });

  final Widget opponent;
  final Widget venue;
  final Widget score;
  final Widget result;
  final Color? textColor;
  final FontWeight? fontWeight;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: textColor, fontWeight: fontWeight);

    Widget styled(Widget child) {
      return DefaultTextStyle.merge(
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        child: child,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(flex: 7, child: styled(opponent)),
          SizedBox(width: 44, child: Center(child: styled(venue))),
          SizedBox(width: 68, child: Center(child: styled(score))),
          SizedBox(width: 58, child: styled(result)),
        ],
      ),
    );
  }
}

class _VenueBadge extends StatelessWidget {
  const _VenueBadge({required this.venue});

  final RecentMatchVenue venue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = venue == RecentMatchVenue.home
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;
    final label = venue == RecentMatchVenue.home ? 'D' : 'E';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.62)),
      ),
      child: SizedBox.square(
        dimension: 26,
        child: Center(
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _FormSummaryBar extends StatelessWidget {
  const _FormSummaryBar({required this.stats});

  final _FormWindowStats stats;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              _InlineFormBalance(stats: stats),
              if (stats.goalsForTotal != null) ...[
                _SummarySeparator(),
                _InlineSummaryText(
                  label: 'Buts marqués',
                  value:
                      '${stats.goalsForTotal} (${stats.goalsForAverage!.toStringAsFixed(2)}/m)',
                ),
              ],
              if (stats.goalsAgainstTotal != null) ...[
                _SummarySeparator(),
                _InlineSummaryText(
                  label: 'Buts encaissés',
                  value:
                      '${stats.goalsAgainstTotal} (${stats.goalsAgainstAverage!.toStringAsFixed(2)}/m)',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineFormBalance extends StatelessWidget {
  const _InlineFormBalance({required this.stats});

  final _FormWindowStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semantic;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Bilan : ',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w900,
          ),
        ),
        _ColoredText('${stats.wins}V', color: semantic.success),
        _MutedDot(),
        _ColoredText('${stats.draws}N', color: semantic.warning),
        _MutedDot(),
        _ColoredText('${stats.losses}D', color: theme.colorScheme.error),
      ],
    );
  }
}

class _InlineSummaryText extends StatelessWidget {
  const _InlineSummaryText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text.rich(
      TextSpan(
        text: '$label : ',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
        ),
        children: [
          TextSpan(
            text: value,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ColoredText extends StatelessWidget {
  const _ColoredText(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: color,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _MutedDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        '·',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SummarySeparator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

class _FormSynthesisCard extends StatelessWidget {
  const _FormSynthesisCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.auto_awesome_rounded, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormWindowStats {
  const _FormWindowStats({
    required this.wins,
    required this.draws,
    required this.losses,
    required this.matchCount,
    this.goalsForTotal,
    this.goalsAgainstTotal,
  });

  factory _FormWindowStats.from({
    required List<TeamRecentMatchSnapshot> recentMatches,
    required List<String> fallbackResults,
  }) {
    final normalizedResults = recentMatches.isNotEmpty
        ? recentMatches
              .map((match) => _normalizeResult(match.result))
              .whereType<String>()
              .toList(growable: false)
        : fallbackResults;
    final scoredMatches = recentMatches.where(
      (match) => match.goalsFor != null && match.goalsAgainst != null,
    );
    final goalsFor = scoredMatches.isEmpty
        ? null
        : scoredMatches.fold<int>(0, (sum, match) => sum + match.goalsFor!);
    final goalsAgainst = scoredMatches.isEmpty
        ? null
        : scoredMatches.fold<int>(0, (sum, match) => sum + match.goalsAgainst!);

    return _FormWindowStats(
      wins: normalizedResults.where((result) => result == 'W').length,
      draws: normalizedResults.where((result) => result == 'D').length,
      losses: normalizedResults.where((result) => result == 'L').length,
      matchCount: normalizedResults.length,
      goalsForTotal: goalsFor,
      goalsAgainstTotal: goalsAgainst,
    );
  }

  final int wins;
  final int draws;
  final int losses;
  final int matchCount;
  final int? goalsForTotal;
  final int? goalsAgainstTotal;

  bool get hasResults => matchCount > 0;
  int get points => (wins * 3) + draws;
  double? get goalsForAverage => goalsForTotal == null || matchCount == 0
      ? null
      : goalsForTotal! / matchCount;
  double? get goalsAgainstAverage =>
      goalsAgainstTotal == null || matchCount == 0
      ? null
      : goalsAgainstTotal! / matchCount;
}

String? _normalizeResult(String result) {
  return switch (result.trim().toUpperCase()) {
    'W' || 'V' => 'W',
    'D' || 'N' => 'D',
    'L' || 'P' => 'L',
    _ => null,
  };
}

String _formResultLabel(String result) {
  return switch (_normalizeResult(result)) {
    'W' => 'V',
    'D' => 'N',
    'L' => 'D',
    _ => '—',
  };
}

Color _formResultColor(BuildContext context, String result) {
  final semantic = context.semantic;
  return switch (_normalizeResult(result)) {
    'W' => semantic.success,
    'D' => semantic.warning,
    'L' => Theme.of(context).colorScheme.error,
    _ => Theme.of(context).colorScheme.onSurfaceVariant,
  };
}

class _FormResultBadge extends StatelessWidget {
  const _FormResultBadge({required this.result});

  final String result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _formResultColor(context, result);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.tight),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: SizedBox.square(
        dimension: 30,
        child: Center(
          child: Text(
            _formResultLabel(result),
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _StandingsPanel extends StatelessWidget {
  const _StandingsPanel({required this.match});

  final MatchBoardItem match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final standings = _standingsRows();

    if (standings.isEmpty) {
      return const _AnalysisPlaceholder(tab: _AnalysisTab.standings);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${match.competition.name} · Saison en cours',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              const _VerificationInsightLine(
                text: 'Championnat uniquement · Amicaux et coupes exclus',
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 560),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.surface.withValues(alpha: 0.34),
                      borderRadius: BorderRadius.circular(AppRadius.input),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Column(
                      children: [
                        const _StandingCompactRow.header(),
                        for (final standing in standings)
                          _StandingCompactRow(
                            standing: standing,
                            team: _teamForStanding(standing),
                            highlight: _highlightForStanding(standing),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _StandingGapCard(match: match),
            ],
          ),
        ),
      ),
    );
  }

  List<TeamStandingSnapshot> _standingsRows() {
    final fullTable = match.analysis.leagueStandings;
    if (fullTable.isNotEmpty) {
      return fullTable;
    }

    final fallback = [
      if (match.analysis.homeStanding != null) match.analysis.homeStanding!,
      if (match.analysis.awayStanding != null) match.analysis.awayStanding!,
    ];
    fallback.sort((a, b) => (a.rank ?? 999).compareTo(b.rank ?? 999));
    return fallback;
  }

  TeamInfo? _teamForStanding(TeamStandingSnapshot standing) {
    if (_isHomeStanding(standing)) {
      return match.homeTeam;
    }
    if (_isAwayStanding(standing)) {
      return match.awayTeam;
    }
    return null;
  }

  _StandingHighlight _highlightForStanding(TeamStandingSnapshot standing) {
    if (_isHomeStanding(standing)) {
      return _StandingHighlight.home;
    }
    if (_isAwayStanding(standing)) {
      return _StandingHighlight.away;
    }
    return _StandingHighlight.none;
  }

  bool _isHomeStanding(TeamStandingSnapshot standing) {
    return standing.teamId == match.homeTeam.apiFootballTeamId ||
        standing.teamName == match.homeTeam.name;
  }

  bool _isAwayStanding(TeamStandingSnapshot standing) {
    return standing.teamId == match.awayTeam.apiFootballTeamId ||
        standing.teamName == match.awayTeam.name;
  }
}

enum _StandingHighlight { none, home, away }

class _StandingGapCard extends StatelessWidget {
  const _StandingGapCard({required this.match});

  final MatchBoardItem match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final home = match.analysis.homeStanding;
    final away = match.analysis.awayStanding;

    if (home == null || away == null) {
      return const _VerificationInsightLine(
        text: 'Donnée de classement indisponible pour une des deux équipes.',
      );
    }

    final rankGap = _gap(home.rank, away.rank);
    final pointsGap = _gap(home.points, away.points);
    final goalDiffGap = _gap(home.goalDiff, away.goalDiff);
    final leader = _leaderName(match, home.points, away.points);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Écart entre les deux équipes',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _GapMetric(label: 'Places d’écart', value: rankGap),
                _GapMetric(label: 'Points d’écart', value: pointsGap),
                _GapMetric(label: 'Différence de buts', value: goalDiffGap),
              ],
            ),
            const SizedBox(height: 10),
            _VerificationInsightLine(
              text: leader == null
                  ? 'Les deux équipes sont proches au classement disponible.'
                  : '$leader possède actuellement ${pointsGap ?? 0} point(s) d’avance sur l’autre équipe.',
            ),
          ],
        ),
      ),
    );
  }

  int? _gap(int? a, int? b) {
    if (a == null || b == null) {
      return null;
    }
    return (a - b).abs();
  }

  String? _leaderName(MatchBoardItem match, int? homePoints, int? awayPoints) {
    if (homePoints == null || awayPoints == null || homePoints == awayPoints) {
      return null;
    }
    return homePoints > awayPoints ? match.homeTeam.name : match.awayTeam.name;
  }
}

class _GapMetric extends StatelessWidget {
  const _GapMetric({required this.label, required this.value});

  final String label;
  final int? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 128,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value?.toString() ?? '—',
            style: theme.textTheme.titleLarge?.copyWith(
              color: context.semantic.warning,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _VerificationInsightLine extends StatelessWidget {
  const _VerificationInsightLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, size: 16, color: colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _StandingCompactRow extends StatelessWidget {
  const _StandingCompactRow({
    required this.standing,
    required this.team,
    required this.highlight,
  }) : isHeader = false;

  const _StandingCompactRow.header()
    : standing = null,
      team = null,
      highlight = _StandingHighlight.none,
      isHeader = true;

  final TeamStandingSnapshot? standing;
  final TeamInfo? team;
  final _StandingHighlight highlight;
  final bool isHeader;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final semantic = context.semantic;
    final accent = switch (highlight) {
      _StandingHighlight.home => colorScheme.primary,
      _StandingHighlight.away => semantic.warning,
      _StandingHighlight.none => colorScheme.outlineVariant,
    };
    final textColor = isHeader
        ? colorScheme.onSurfaceVariant
        : highlight == _StandingHighlight.none
        ? colorScheme.onSurface
        : accent;
    final rowBackground = isHeader
        ? AppColors.transparent
        : highlight == _StandingHighlight.none
        ? AppColors.transparent
        : accent.withValues(alpha: 0.10);
    final borderColor = isHeader
        ? colorScheme.outlineVariant
        : highlight == _StandingHighlight.none
        ? colorScheme.outlineVariant.withValues(alpha: 0.55)
        : accent.withValues(alpha: 0.75);

    if (isHeader) {
      return _StandingRowShell(
        borderColor: borderColor,
        backgroundColor: rowBackground,
        child: Row(
          children: [
            _StandingCell('#', width: 34, color: textColor, isHeader: true),
            _StandingCell(
              'Équipe',
              width: 190,
              color: textColor,
              isHeader: true,
              alignment: Alignment.centerLeft,
            ),
            _StandingCell('MJ', width: 48, color: textColor, isHeader: true),
            _StandingCell('Pts', width: 52, color: textColor, isHeader: true),
            _StandingCell('Diff', width: 56, color: textColor, isHeader: true),
            _StandingCell(
              'Buts pour',
              width: 74,
              color: textColor,
              isHeader: true,
            ),
            _StandingCell(
              'Buts contre',
              width: 86,
              color: textColor,
              isHeader: true,
            ),
          ],
        ),
      );
    }

    final standing = this.standing!;

    return _StandingRowShell(
      borderColor: borderColor,
      backgroundColor: rowBackground,
      child: Row(
        children: [
          _StandingCell(
            _value(standing.rank),
            width: 34,
            color: textColor,
            isHeader: false,
          ),
          SizedBox(
            width: 190,
            child: Row(
              children: [
                if (team != null) ...[
                  SportsAssetBadge(
                    size: 24,
                    imageUrl: team!.logoUrl,
                    fallbackLabel: team!.name,
                    borderRadius: 5,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    standing.teamName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: textColor,
                      fontWeight: highlight == _StandingHighlight.none
                          ? FontWeight.w700
                          : FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _StandingCell(_value(standing.played), width: 48, color: textColor),
          _StandingCell(_value(standing.points), width: 52, color: textColor),
          _StandingCell(
            _signed(standing.goalDiff),
            width: 56,
            color: textColor,
          ),
          _StandingCell(_value(standing.goalsFor), width: 74, color: textColor),
          _StandingCell(
            _value(standing.goalsAgainst),
            width: 86,
            color: textColor,
          ),
        ],
      ),
    );
  }

  static String _value(int? value) => value?.toString() ?? '–';

  static String _signed(int? value) {
    if (value == null) {
      return '–';
    }
    return value > 0 ? '+$value' : '$value';
  }
}

class _StandingRowShell extends StatelessWidget {
  const _StandingRowShell({
    required this.child,
    required this.borderColor,
    required this.backgroundColor,
  });

  final Widget child;
  final Color borderColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: child,
      ),
    );
  }
}

class _StandingCell extends StatelessWidget {
  const _StandingCell(
    this.value, {
    required this.width,
    required this.color,
    this.isHeader = false,
    this.alignment = Alignment.center,
  });

  final String value;
  final double width;
  final Color color;
  final bool isHeader;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: width,
      child: Align(
        alignment: alignment,
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style:
              (isHeader
                      ? theme.textTheme.labelSmall
                      : theme.textTheme.bodySmall)
                  ?.copyWith(color: color, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _HomeAwayPanel extends StatelessWidget {
  const _HomeAwayPanel({required this.match});

  final MatchBoardItem match;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final homeStats = match.analysis.homeStatistics;
    final awayStats = match.analysis.awayStatistics;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SplitTeamBlock(
              team: match.homeTeam,
              emphasizedColumn: _SplitColumn.home,
              values: _SplitTableValues.from(homeStats),
            ),
            Divider(height: 24, color: colorScheme.outlineVariant),
            _SplitTeamBlock(
              team: match.awayTeam,
              emphasizedColumn: _SplitColumn.away,
              values: _SplitTableValues.from(awayStats),
            ),
            const SizedBox(height: 12),
            _VerificationInsightLine(
              text: _homeAwayText(match, homeStats, awayStats),
            ),
          ],
        ),
      ),
    );
  }

  String _homeAwayText(
    MatchBoardItem match,
    TeamStatisticsSnapshot? homeStats,
    TeamStatisticsSnapshot? awayStats,
  ) {
    final homePoints = _pointsPerMatch(
      homeStats?.winsHome,
      homeStats?.drawsHome,
      homeStats?.playedHome,
    );
    final awayPoints = _pointsPerMatch(
      awayStats?.winsAway,
      awayStats?.drawsAway,
      awayStats?.playedAway,
    );

    if (homePoints == null || awayPoints == null) {
      return 'Stats domicile/extérieur indisponibles pour produire une comparaison fiable.';
    }

    if (homePoints == awayPoints) {
      return 'Les splits disponibles montrent un rendement domicile/extérieur comparable.';
    }

    return homePoints > awayPoints
        ? '${match.homeTeam.name} présente un meilleur rendement à domicile que ${match.awayTeam.name} à l’extérieur.'
        : '${match.awayTeam.name} voyage mieux que le rendement domicile de ${match.homeTeam.name}.';
  }
}

enum _SplitColumn { home, away }

class _SplitTableValues {
  const _SplitTableValues({
    required this.home,
    required this.away,
    required this.homePointsPerMatch,
    required this.awayPointsPerMatch,
  });

  factory _SplitTableValues.from(TeamStatisticsSnapshot? stats) {
    return _SplitTableValues(
      home: _SplitSideValues(
        played: stats?.playedHome,
        wins: stats?.winsHome,
        draws: stats?.drawsHome,
        losses: stats?.lossesHome,
        goalsFor: stats?.goalsForHome,
        goalsAgainst: stats?.goalsAgainstHome,
        goalsForAverage: stats?.goalsForAverageHome,
        goalsAgainstAverage: stats?.goalsAgainstAverageHome,
        cleanSheets: stats?.cleanSheetsHome,
        failedToScore: stats?.failedToScoreHome,
      ),
      away: _SplitSideValues(
        played: stats?.playedAway,
        wins: stats?.winsAway,
        draws: stats?.drawsAway,
        losses: stats?.lossesAway,
        goalsFor: stats?.goalsForAway,
        goalsAgainst: stats?.goalsAgainstAway,
        goalsForAverage: stats?.goalsForAverageAway,
        goalsAgainstAverage: stats?.goalsAgainstAverageAway,
        cleanSheets: stats?.cleanSheetsAway,
        failedToScore: stats?.failedToScoreAway,
      ),
      homePointsPerMatch: _pointsPerMatch(
        stats?.winsHome,
        stats?.drawsHome,
        stats?.playedHome,
      ),
      awayPointsPerMatch: _pointsPerMatch(
        stats?.winsAway,
        stats?.drawsAway,
        stats?.playedAway,
      ),
    );
  }

  final _SplitSideValues home;
  final _SplitSideValues away;
  final double? homePointsPerMatch;
  final double? awayPointsPerMatch;

  bool get isEmpty => home.isEmpty && away.isEmpty;
}

class _SplitSideValues {
  const _SplitSideValues({
    this.played,
    this.wins,
    this.draws,
    this.losses,
    this.goalsFor,
    this.goalsAgainst,
    this.goalsForAverage,
    this.goalsAgainstAverage,
    this.cleanSheets,
    this.failedToScore,
  });

  final int? played;
  final int? wins;
  final int? draws;
  final int? losses;
  final int? goalsFor;
  final int? goalsAgainst;
  final double? goalsForAverage;
  final double? goalsAgainstAverage;
  final int? cleanSheets;
  final int? failedToScore;

  bool get isEmpty =>
      played == null &&
      wins == null &&
      draws == null &&
      losses == null &&
      goalsFor == null &&
      goalsAgainst == null &&
      goalsForAverage == null &&
      goalsAgainstAverage == null &&
      cleanSheets == null &&
      failedToScore == null;
}

class _SplitTeamBlock extends StatelessWidget {
  const _SplitTeamBlock({
    required this.team,
    required this.emphasizedColumn,
    required this.values,
  });

  final TeamInfo team;
  final _SplitColumn emphasizedColumn;
  final _SplitTableValues values;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SportsAssetBadge(
              size: 26,
              imageUrl: team.logoUrl,
              fallbackLabel: team.name,
              borderRadius: AppRadius.tight,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                team.name,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (values.isEmpty)
          Text(
            'Stats domicile/extérieur indisponibles dans le snapshot actuel.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          )
        else
          _SplitTable(values: values, emphasizedColumn: emphasizedColumn),
      ],
    );
  }
}

class _SplitTable extends StatelessWidget {
  const _SplitTable({required this.values, required this.emphasizedColumn});

  final _SplitTableValues values;
  final _SplitColumn emphasizedColumn;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            _SplitTableRow.header(emphasizedColumn: emphasizedColumn),
            _SplitTableRow(
              label: 'MJ',
              home: _value(values.home.played),
              away: _value(values.away.played),
              emphasizedColumn: emphasizedColumn,
            ),
            _SplitTableRow(
              label: 'V / N / D',
              home: _record(values.home),
              away: _record(values.away),
              emphasizedColumn: emphasizedColumn,
            ),
            _SplitTableRow(
              label: 'Points / match',
              home: _decimal(values.homePointsPerMatch),
              away: _decimal(values.awayPointsPerMatch),
              emphasizedColumn: emphasizedColumn,
            ),
            _SplitTableRow(
              label: 'Buts pour',
              home: _value(values.home.goalsFor),
              away: _value(values.away.goalsFor),
              emphasizedColumn: emphasizedColumn,
            ),
            _SplitTableRow(
              label: 'Buts contre',
              home: _value(values.home.goalsAgainst),
              away: _value(values.away.goalsAgainst),
              emphasizedColumn: emphasizedColumn,
            ),
            _SplitTableRow(
              label: 'Buts / match',
              home: _decimal(values.home.goalsForAverage),
              away: _decimal(values.away.goalsForAverage),
              emphasizedColumn: emphasizedColumn,
            ),
            _SplitTableRow(
              label: 'Buts c. / match',
              home: _decimal(values.home.goalsAgainstAverage),
              away: _decimal(values.away.goalsAgainstAverage),
              emphasizedColumn: emphasizedColumn,
            ),
            _SplitTableRow(
              label: 'Clean sheets',
              home: _value(values.home.cleanSheets),
              away: _value(values.away.cleanSheets),
              emphasizedColumn: emphasizedColumn,
            ),
            _SplitTableRow(
              label: 'Sans marquer',
              home: _value(values.home.failedToScore),
              away: _value(values.away.failedToScore),
              emphasizedColumn: emphasizedColumn,
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }

  static String _value(int? value) => value?.toString() ?? '—';

  static String _decimal(double? value) => value?.toStringAsFixed(2) ?? '—';

  static String _record(_SplitSideValues values) {
    if (values.wins == null || values.draws == null || values.losses == null) {
      return '—';
    }
    return '${values.wins} / ${values.draws} / ${values.losses}';
  }
}

class _SplitTableRow extends StatelessWidget {
  const _SplitTableRow({
    required this.label,
    required this.home,
    required this.away,
    required this.emphasizedColumn,
    this.isLast = false,
  }) : isHeader = false;

  const _SplitTableRow.header({required this.emphasizedColumn})
    : label = '',
      home = 'À domicile',
      away = 'À l’extérieur',
      isLast = false,
      isHeader = true;

  final String label;
  final String home;
  final String away;
  final _SplitColumn emphasizedColumn;
  final bool isLast;
  final bool isHeader;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: isLast
              ? BorderSide.none
              : BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.7),
                ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: isHeader ? 4 : 7),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _SplitValueCell(
              value: home,
              isHeader: isHeader,
              isEmphasized: emphasizedColumn == _SplitColumn.home,
            ),
            _SplitValueCell(
              value: away,
              isHeader: isHeader,
              isEmphasized: emphasizedColumn == _SplitColumn.away,
            ),
          ],
        ),
      ),
    );
  }
}

class _SplitValueCell extends StatelessWidget {
  const _SplitValueCell({
    required this.value,
    required this.isHeader,
    required this.isEmphasized,
  });

  final String value;
  final bool isHeader;
  final bool isEmphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Expanded(
      flex: 3,
      child: Text(
        value,
        textAlign: TextAlign.center,
        style:
            (isHeader ? theme.textTheme.labelSmall : theme.textTheme.bodySmall)
                ?.copyWith(
                  color: isEmphasized
                      ? colorScheme.primary
                      : colorScheme.onSurface,
                  fontWeight: isEmphasized || isHeader
                      ? FontWeight.w900
                      : FontWeight.w700,
                ),
      ),
    );
  }
}

class _AttackDefensePanel extends StatelessWidget {
  const _AttackDefensePanel({required this.match, required this.opportunity});

  final MatchBoardItem match;
  final Opportunity? opportunity;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final rows = _rows();

    if (rows.isEmpty) {
      return const _AnalysisPlaceholder(tab: _AnalysisTab.attackDefense);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 34,
                dataRowMinHeight: 42,
                dataRowMaxHeight: 48,
                horizontalMargin: 8,
                columnSpacing: 24,
                columns: [
                  const DataColumn(label: Text('Statistique')),
                  DataColumn(label: Text(match.homeTeam.name)),
                  DataColumn(label: Text(match.awayTeam.name)),
                  const DataColumn(label: Text('Avantage')),
                ],
                rows: [
                  for (final row in rows)
                    DataRow(
                      color: WidgetStatePropertyAll(
                        row.highlight
                            ? colorScheme.primary.withValues(alpha: 0.08)
                            : AppColors.transparent,
                      ),
                      cells: [
                        DataCell(Text(row.label)),
                        DataCell(Text(row.home)),
                        DataCell(Text(row.away)),
                        DataCell(Text(row.advantage)),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _VerificationInsightLine(text: _attackDefenseText(rows)),
          ],
        ),
      ),
    );
  }

  List<_ComparisonRow> _rows() {
    final homeStats = match.analysis.homeStatistics;
    final awayStats = match.analysis.awayStatistics;
    final homeXg = match.analysis.homeExpectedGoals;
    final awayXg = match.analysis.awayExpectedGoals;
    final highlightedKinds = _highlightedKinds();

    return [
      ?_comparison(
        label: 'Buts marqués / match',
        home: homeStats?.goalsForAverageTotal,
        away: awayStats?.goalsForAverageTotal,
        highIsBetter: true,
        highlight: highlightedKinds.contains(_VerificationKind.attack),
      ),
      ?_comparison(
        label: 'Buts encaissés / match',
        home: homeStats?.goalsAgainstAverageTotal,
        away: awayStats?.goalsAgainstAverageTotal,
        highIsBetter: false,
        highlight: highlightedKinds.contains(_VerificationKind.defense),
      ),
      ?_comparison(
        label: 'xG',
        home: homeXg?.seasonXgForAverage ?? homeXg?.rollingXgFor5,
        away: awayXg?.seasonXgForAverage ?? awayXg?.rollingXgFor5,
        highIsBetter: true,
        highlight: highlightedKinds.contains(_VerificationKind.xg),
      ),
      ?_comparison(
        label: 'xGA',
        home: homeXg?.seasonXgAgainstAverage ?? homeXg?.rollingXgAgainst5,
        away: awayXg?.seasonXgAgainstAverage ?? awayXg?.rollingXgAgainst5,
        highIsBetter: false,
        highlight: highlightedKinds.contains(_VerificationKind.xg),
      ),
      ?_comparisonInt(
        label: 'Clean sheets',
        home: homeStats?.cleanSheetsTotal,
        away: awayStats?.cleanSheetsTotal,
        highIsBetter: true,
        highlight: highlightedKinds.contains(_VerificationKind.defense),
      ),
      ?_comparisonInt(
        label: 'Sans marquer',
        home: homeStats?.failedToScoreTotal,
        away: awayStats?.failedToScoreTotal,
        highIsBetter: false,
        highlight: highlightedKinds.contains(_VerificationKind.attack),
      ),
    ];
  }

  Set<_VerificationKind> _highlightedKinds() {
    final arguments =
        opportunity?.positiveArguments ?? match.thesis?.arguments ?? const [];
    return {
      for (final argument in arguments)
        switch (argument.family) {
          CopilotArgumentFamily.attack => _VerificationKind.attack,
          CopilotArgumentFamily.defense => _VerificationKind.defense,
          CopilotArgumentFamily.rhythm => _VerificationKind.attack,
          _ => _VerificationKind.other,
        },
    };
  }

  _ComparisonRow? _comparison({
    required String label,
    required double? home,
    required double? away,
    required bool highIsBetter,
    required bool highlight,
  }) {
    if (home == null || away == null) {
      return null;
    }
    final advantage = _advantage(home, away, highIsBetter);
    return _ComparisonRow(
      label: label,
      home: home.toStringAsFixed(2),
      away: away.toStringAsFixed(2),
      advantage: advantage,
      highlight: highlight,
    );
  }

  _ComparisonRow? _comparisonInt({
    required String label,
    required int? home,
    required int? away,
    required bool highIsBetter,
    required bool highlight,
  }) {
    if (home == null || away == null) {
      return null;
    }
    final advantage = _advantage(
      home.toDouble(),
      away.toDouble(),
      highIsBetter,
    );
    return _ComparisonRow(
      label: label,
      home: '$home',
      away: '$away',
      advantage: advantage,
      highlight: highlight,
    );
  }

  String _advantage(double home, double away, bool highIsBetter) {
    if (home == away) {
      return 'Égal';
    }
    final homeBetter = highIsBetter ? home > away : home < away;
    return homeBetter ? match.homeTeam.name : match.awayTeam.name;
  }

  String _attackDefenseText(List<_ComparisonRow> rows) {
    final highlighted = rows.where((row) => row.highlight).length;
    if (highlighted > 0) {
      return '$highlighted donnée(s) de ce tableau ont contribué à la lecture affichée plus haut.';
    }
    return 'Ces métriques permettent de contrôler le lien entre volume offensif, solidité défensive et lecture combinée.';
  }
}

enum _VerificationKind { attack, defense, xg, other }

class _ComparisonRow {
  const _ComparisonRow({
    required this.label,
    required this.home,
    required this.away,
    required this.advantage,
    required this.highlight,
  });

  final String label;
  final String home;
  final String away;
  final String advantage;
  final bool highlight;
}

class _SeriesPanel extends StatelessWidget {
  const _SeriesPanel({required this.match});

  final MatchBoardItem match;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TeamSeriesBlock(
              team: match.homeTeam,
              statistics: match.analysis.homeStatistics,
              standing: match.analysis.homeStanding,
            ),
            Divider(height: 24, color: colorScheme.outlineVariant),
            _TeamSeriesBlock(
              team: match.awayTeam,
              statistics: match.analysis.awayStatistics,
              standing: match.analysis.awayStanding,
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamSeriesBlock extends StatelessWidget {
  const _TeamSeriesBlock({
    required this.team,
    required this.statistics,
    required this.standing,
  });

  final TeamInfo team;
  final TeamStatisticsSnapshot? statistics;
  final TeamStandingSnapshot? standing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final results = _matchDetailLastFiveResults(
      statistics?.form ?? standing?.form,
    );
    final series = _seriesFrom(results);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SportsAssetBadge(
              size: 26,
              imageUrl: team.logoUrl,
              fallbackLabel: team.name,
              borderRadius: AppRadius.tight,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                team.name,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (series.isEmpty)
          Text(
            'Séries indisponibles dans le snapshot actuel.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          )
        else
          Column(
            children: [
              for (final item in series)
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: _SeriesLine(text: item),
                ),
            ],
          ),
      ],
    );
  }

  List<String> _seriesFrom(List<String> results) {
    if (results.isEmpty) {
      return const [];
    }

    final wins = results.where((result) => result == 'W').length;
    final draws = results.where((result) => result == 'D').length;
    final losses = results.where((result) => result == 'L').length;
    final series = <String>[
      '$wins victoire(s) sur ${results.length} derniers résultats disponibles',
      '$draws nul(s) sur ${results.length}',
      '$losses défaite(s) sur ${results.length}',
    ];

    final first = results.first;
    final currentRun = results.takeWhile((result) => result == first).length;
    if (currentRun >= 2) {
      final label = switch (first) {
        'W' => 'victoires consécutives',
        'D' => 'nuls consécutifs',
        _ => 'défaites consécutives',
      };
      series.add('$currentRun $label');
    }

    return series;
  }
}

class _SeriesLine extends StatelessWidget {
  const _SeriesLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.check_circle_outline_rounded,
          color: theme.colorScheme.primary,
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

double? _pointsPerMatch(int? wins, int? draws, int? played) {
  if (wins == null || draws == null || played == null || played == 0) {
    return null;
  }

  return ((wins * 3) + draws) / played;
}

List<String> _matchDetailLastFiveResults(String? form) {
  if (form == null) {
    return const [];
  }

  return form
      .trim()
      .toUpperCase()
      .split('')
      .where((result) => result == 'W' || result == 'D' || result == 'L')
      .take(5)
      .toList(growable: false);
}

class _MarketsSection extends StatefulWidget {
  const _MarketsSection({
    required this.match,
    required this.opportunity,
    required this.markets,
    required this.ticketDraftListenable,
    required this.onToggleTicket,
  });

  final MatchBoardItem match;
  final Opportunity? opportunity;
  final List<MatchMarket> markets;
  final ValueListenable<TicketDraft>? ticketDraftListenable;
  final ValueChanged<TicketDraftSelection>? onToggleTicket;

  @override
  State<_MarketsSection> createState() => _MarketsSectionState();
}

class _MarketsSectionState extends State<_MarketsSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final recommendedMarket =
        widget.opportunity?.recommendedMarket ??
        widget.match.thesis?.recommendedMarket;
    final theses =
        widget.opportunity?.retainedTheses ??
        [if (widget.match.thesis != null) widget.match.thesis!];
    final compatibleMarkets = widget.opportunity?.compatibleMarkets ?? const [];
    final isOutOfProfile =
        widget.match.profileStatus == MatchProfileStatus.outOfProfile;
    final summary = recommendedMarket == null || isOutOfProfile
        ? 'Aucun marché'
        : '${recommendedMarket.market.label} · ${recommendedMarket.selection.label}';

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CollapsibleHeader(
            icon: Icons.track_changes_rounded,
            title: 'Marchés et cotes',
            summary: summary,
            isOpen: _isExpanded,
            onPressed: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
          ),
          if (_isExpanded) ...[
            const SizedBox(height: 14),
            if (isOutOfProfile || recommendedMarket == null)
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  border: Border.all(
                    color: colorScheme.outlineVariant,
                    style: BorderStyle.solid,
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      children: [
                        Text(
                          'Aucun marché recommandé actuellement.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isOutOfProfile
                              ? 'Cette compétition n’est pas dans votre profil.\nActivez-la pour recevoir des marchés adaptés.'
                              : 'Copilot n’a pas trouvé de marché assez aligné avec cette lecture.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (isOutOfProfile) ...[
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Ajout de ${widget.match.competition.name} au profil à brancher.',
                                  ),
                                ),
                              );
                            },
                            child: Text(
                              'Ajouter ${widget.match.competition.name} à mon profil',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            if (!isOutOfProfile && recommendedMarket != null)
              _RecommendedMarketPanel(
                match: widget.match,
                recommendedMarket: recommendedMarket,
                rationale: OpportunityDecisionPresenter.marketRationale(
                  recommendedMarket: recommendedMarket,
                  theses: theses,
                ),
                ticketDraftListenable: widget.ticketDraftListenable,
                onToggleTicket: widget.onToggleTicket,
              ),
            if (compatibleMarkets.isNotEmpty) ...[
              const SizedBox(height: 16),
              _CompatibleMarketsWrap(markets: compatibleMarkets),
            ],
            if (widget.markets.isNotEmpty) ...[
              const SizedBox(height: 16),
              Divider(height: 1, color: colorScheme.outlineVariant),
              const SizedBox(height: 14),
              Text(
                'Cotes disponibles',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tous les marchés normalisés présents dans le snapshot.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              _RawApiMarketsDisclosure(markets: widget.markets),
            ],
          ],
        ],
      ),
    );
  }
}

class _CompatibleMarketsWrap extends StatelessWidget {
  const _CompatibleMarketsWrap({required this.markets});

  final List<OpportunityMarketCompatibility> markets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final otherMarkets = markets.where((item) => !item.isRecommended).toList();

    if (otherMarkets.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Autres marchés compatibles',
          style: theme.textTheme.labelLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final item in otherMarkets.take(6))
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh.withValues(
                    alpha: 0.45,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${item.market.label} · ${item.selection.label}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        item.selection.odds.toStringAsFixed(2),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _RawApiMarketsDisclosure extends StatefulWidget {
  const _RawApiMarketsDisclosure({required this.markets});

  final List<MatchMarket> markets;

  @override
  State<_RawApiMarketsDisclosure> createState() =>
      _RawApiMarketsDisclosureState();
}

class _RawApiMarketsDisclosureState extends State<_RawApiMarketsDisclosure> {
  bool _isOpen = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selectionCount = widget.markets.fold<int>(
      0,
      (total, market) => total + market.selections.length,
    );

    return Material(
      color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          setState(() {
            _isOpen = !_isOpen;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.dataset_outlined, color: colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cotes API disponibles',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.markets.length} marché(s) · $selectionCount cote(s) · API-Football',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isOpen
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              if (_isOpen) ...[
                const SizedBox(height: 14),
                for (final market in widget.markets)
                  _MarketPanel(market: market),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MarketPanel extends StatefulWidget {
  const _MarketPanel({required this.market});

  final MatchMarket market;

  @override
  State<_MarketPanel> createState() => _MarketPanelState();
}

class _MarketPanelState extends State<_MarketPanel> {
  static const _visibleSelectionLimit = 6;

  bool _isOpen = false;
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final market = widget.market;
    final visibleSelections = _isExpanded
        ? market.selections
        : market.selections.take(_visibleSelectionLimit).toList();
    final hiddenCount = market.selections.length - visibleSelections.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.control),
          onTap: () {
            setState(() {
              _isOpen = !_isOpen;
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        market.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (market.bookmakerName != null)
                      Text(
                        market.bookmakerName!,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    const SizedBox(width: 8),
                    Icon(
                      _isOpen
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.chevron_right_rounded,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                if (!_isOpen) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${market.selections.length} cote(s) disponible(s)',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (_isOpen) ...[
                  const SizedBox(height: 10),
                  Column(
                    children: [
                      for (final row in _selectionRows(visibleSelections))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: _SelectionOddPill(selection: row.first),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: row.length > 1
                                    ? _SelectionOddPill(selection: row[1])
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  if (market.selections.length > _visibleSelectionLimit)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _isExpanded = !_isExpanded;
                          });
                        },
                        icon: Icon(
                          _isExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 18,
                        ),
                        label: Text(
                          _isExpanded
                              ? l10n.showLessMarketsButton
                              : l10n.showMoreMarketsButton(hiddenCount),
                        ),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<List<MarketOdds>> _selectionRows(List<MarketOdds> selections) {
    final rows = <List<MarketOdds>>[];

    for (var index = 0; index < selections.length; index += 2) {
      rows.add(
        selections.sublist(
          index,
          index + 2 > selections.length ? selections.length : index + 2,
        ),
      );
    }

    return rows;
  }
}

class _SelectionOddPill extends StatelessWidget {
  const _SelectionOddPill({required this.selection});

  final MarketOdds selection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.tight),
      ),
      child: SizedBox(
        height: 44,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  selection.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                selection.odds.toStringAsFixed(2),
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
