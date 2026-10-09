import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_components.dart';
import '../theme/app_radius.dart';
import 'lector_glass_card.dart';

enum LectorSkeletonKind {
  matches,
  radar,
  detail,
  standings,
  statistics,
  bilan,
  conversation,
}

/// A single animation for the whole placeholder, with theme and accessibility
/// tokens shared by every sport. No invented names, scores or match counts.
class LectorLoading extends StatefulWidget {
  const LectorLoading({
    this.kind = LectorSkeletonKind.matches,
    this.label = 'Chargement des rencontres…',
    this.recovering = false,
    super.key,
  });
  final LectorSkeletonKind kind;
  final String label;
  final bool recovering;
  @override
  State<LectorLoading> createState() => _LectorLoadingState();
}

class _LectorLoadingState extends State<LectorLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  Timer? _delay;
  bool _visible = false;
  @override
  void initState() {
    super.initState();
    _delay = Timer(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _pulse.stop();
    } else {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.recovering
        ? 'Connexion interrompue. Récupération automatique en cours.'
        : widget.label,
    liveRegion: true,
    child: AnimatedOpacity(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 160),
      opacity: _visible ? 1 : 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.recovering
                ? 'Récupération des données en cours…'
                : widget.label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.textColors.secondary,
            ),
          ),
          const SizedBox(height: 12),
          ExcludeSemantics(
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) => Opacity(
                opacity: MediaQuery.disableAnimationsOf(context)
                    ? .8
                    : .56 + _pulse.value * .34,
                child: Column(
                  children: [
                    if (widget.kind == LectorSkeletonKind.conversation)
                      for (var exchange = 0; exchange < 3; exchange++) ...[
                        Align(
                          alignment: Alignment.centerRight,
                          child: FractionallySizedBox(
                            widthFactor: .72,
                            child: _card(context, [
                              _line(context, double.infinity),
                              const SizedBox(height: 9),
                              _line(context, 110, height: 10),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _line(context, double.infinity),
                        const SizedBox(height: 10),
                        _line(context, double.infinity),
                        const SizedBox(height: 10),
                        FractionallySizedBox(
                          widthFactor: .65,
                          alignment: Alignment.centerLeft,
                          child: _line(context, double.infinity),
                        ),
                        const SizedBox(height: 30),
                      ],
                    if (widget.kind == LectorSkeletonKind.detail) ...[
                      _card(context, [
                        _line(context, 130),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            _block(context, 48, 48, circle: true),
                            const Spacer(),
                            _block(context, 64, 32),
                            const Spacer(),
                            _block(context, 48, 48, circle: true),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _line(context, double.infinity),
                      ]),
                      const SizedBox(height: 12),
                      _block(context, double.infinity, 48),
                      const SizedBox(height: 12),
                    ],
                    for (
                      var i = 0;
                      i <
                          (widget.kind == LectorSkeletonKind.conversation
                              ? 0
                              : widget.kind == LectorSkeletonKind.detail
                              ? 2
                              : 3);
                      i++
                    ) ...[
                      _card(
                        context,
                        widget.kind == LectorSkeletonKind.standings
                            ? [
                                for (var row = 0; row < 5; row++)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      children: [
                                        _block(context, 24, 16),
                                        const SizedBox(width: 10),
                                        _block(context, 26, 26, circle: true),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: _line(
                                            context,
                                            double.infinity,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        _block(context, 32, 16),
                                      ],
                                    ),
                                  ),
                              ]
                            : [
                                Row(
                                  children: [
                                    _block(
                                      context,
                                      widget.kind == LectorSkeletonKind.radar
                                          ? 42
                                          : 28,
                                      widget.kind == LectorSkeletonKind.radar
                                          ? 42
                                          : 28,
                                      circle: true,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _line(context, 140),
                                          const SizedBox(height: 8),
                                          _line(context, 100, height: 10),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _block(context, 42, 14),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                if (widget.kind ==
                                    LectorSkeletonKind.matches) ...[
                                  _line(context, double.infinity),
                                  const SizedBox(height: 10),
                                  _line(context, double.infinity),
                                  const SizedBox(height: 16),
                                ],
                                Row(
                                  children: [
                                    Expanded(
                                      child: _block(
                                        context,
                                        double.infinity,
                                        22,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _block(
                                        context,
                                        double.infinity,
                                        22,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    _block(context, 50, 22),
                                  ],
                                ),
                                if (widget.kind == LectorSkeletonKind.detail ||
                                    widget.kind == LectorSkeletonKind.bilan ||
                                    widget.kind ==
                                        LectorSkeletonKind.statistics) ...[
                                  const SizedBox(height: 14),
                                  _line(context, double.infinity),
                                  const SizedBox(height: 10),
                                  _line(context, double.infinity),
                                ],
                              ],
                      ),
                      if (i < 2) const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
  Widget _card(BuildContext context, List<Widget> children) => LectorGlassCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
  Widget _line(BuildContext context, double width, {double height = 14}) =>
      Align(
        alignment: Alignment.centerLeft,
        child: _block(context, width, height),
      );
  Widget _block(
    BuildContext context,
    double width,
    double height, {
    bool circle = false,
  }) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: context.textColors.secondary.withValues(alpha: .23),
      borderRadius: BorderRadius.circular(
        circle ? AppRadius.chip : AppRadius.input,
      ),
    ),
  );
}

class LectorReadUnavailable extends StatelessWidget {
  const LectorReadUnavailable({
    this.exhausted = false,
    this.label = 'Les données sont momentanément indisponibles.',
    super.key,
  });
  final bool exhausted;
  final String label;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: LectorGlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_off_outlined, color: context.textColors.secondary),
          const SizedBox(height: 10),
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(
            exhausted
                ? 'La récupération automatique n’a pas abouti. Elle reprendra au retour de la connexion ou lorsque vous reviendrez dans l’application. Vous pouvez continuer à naviguer.'
                : 'Vous pouvez consulter une autre journée ou revenir plus tard.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.textColors.secondary,
            ),
          ),
        ],
      ),
    ),
  );
}

class LectorRefreshStatus extends StatelessWidget {
  const LectorRefreshStatus({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Semantics(
      liveRegion: true,
      child: Row(
        children: [
          Icon(Icons.sync_rounded, size: 16, color: context.brand.accent),
          const SizedBox(width: 8),
          Text(
            'Actualisation…',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.textColors.secondary,
            ),
          ),
        ],
      ),
    ),
  );
}
