import 'package:flutter/material.dart';

/// Fade the outgoing pane away before revealing the incoming pane. Keeping one
/// mounted child avoids duplicate readers and preserves state on data refreshes.
class LectorHorizontalTransition extends StatefulWidget {
  const LectorHorizontalTransition({
    required this.position,
    required this.child,
    super.key,
  });

  final num position;
  final Widget child;
  static const duration = Duration(milliseconds: 440);

  @override
  State<LectorHorizontalTransition> createState() =>
      _LectorHorizontalTransitionState();
}

class _LectorHorizontalTransitionState extends State<LectorHorizontalTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: LectorHorizontalTransition.duration,
    value: 1,
  );
  static const _handoff = .36;
  late Widget _displayedChild = widget.child;
  bool _leaving = false;
  bool _reducedMotion = false;
  double _direction = 1;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_advance);
  }

  void _advance() {
    if (_leaving && _controller.value >= _handoff) {
      setState(() {
        _displayedChild = widget.child;
        _leaving = false;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (_reducedMotion) {
      _leaving = false;
      _displayedChild = widget.child;
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant LectorHorizontalTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.position == widget.position) {
      if (!_leaving) _displayedChild = widget.child;
      return;
    }
    _direction = widget.position > oldWidget.position ? 1 : -1;
    if (_reducedMotion) {
      _displayedChild = widget.child;
      _leaving = false;
      _controller.value = 1;
    } else {
      // Fast successive taps update the destination without flashing the
      // outgoing pane back to full opacity or mounting intermediate screens.
      if (_leaving) return;
      final opacity = _controller.isAnimating
          ? Curves.easeInOutCubic.transform(
              ((_controller.value - _handoff) / (1 - _handoff)).clamp(0, 1),
            )
          : 1.0;
      _leaving = true;
      _controller.forward(from: (1 - opacity) * _handoff);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context) == TextDirection.rtl
        ? -_direction
        : _direction;
    return AnimatedBuilder(
      animation: _controller,
      child: IgnorePointer(ignoring: _leaving, child: _displayedChild),
      builder: (context, child) {
        final value = _controller.value;
        final progress = Curves.easeInOutCubic.transform(
          (_leaving ? value / _handoff : (value - _handoff) / (1 - _handoff))
              .clamp(0, 1),
        );
        return ClipRect(
          child: FractionalTranslation(
            translation: Offset(
              direction * (_leaving ? -.018 * progress : .04 * (1 - progress)),
              0,
            ),
            child: Opacity(
              opacity: _leaving ? 1 - progress : progress,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Flutter supplies the vertical slide and drag gesture; only its timing is
/// shared here, including the user's reduced-motion preference.
AnimationStyle lectorSheetAnimationStyle(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context)
    ? AnimationStyle.noAnimation
    : const AnimationStyle(
        duration: Duration(milliseconds: 420),
        reverseDuration: Duration(milliseconds: 320),
      );
