import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/supabase/supabase_initializer.dart';
import '../../application/live_match_controller.dart';
import '../../domain/live_match_state.dart';

class LiveFixtureBuilder extends StatefulWidget {
  const LiveFixtureBuilder({
    required this.fixtureId,
    required this.builder,
    this.controller,
    super.key,
  });
  final int? fixtureId;
  final Widget Function(BuildContext, LiveMatchState?) builder;
  final LiveMatchController? controller;

  @override
  State<LiveFixtureBuilder> createState() => _LiveFixtureBuilderState();
}

class _LiveFixtureBuilderState extends State<LiveFixtureBuilder> {
  LiveMatchController? _controller;
  ValueListenable<LiveMatchState?>? _value;
  int? _id;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  void _attach() {
    _id = widget.fixtureId;
    _controller =
        widget.controller ??
        (getIt.isRegistered<LiveMatchController>() &&
                getIt.isRegistered<SupabaseInitializer>() &&
                getIt<SupabaseInitializer>().client != null
            ? getIt<LiveMatchController>()
            : null);
    if (_id != null && _controller != null) _value = _controller!.watch(_id!);
  }

  void _detach() {
    if (_id != null && _value != null) _controller?.unwatch(_id!);
    _value = null;
  }

  @override
  void didUpdateWidget(covariant LiveFixtureBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fixtureId != widget.fixtureId ||
        oldWidget.controller != widget.controller) {
      _detach();
      _attach();
    }
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _value == null
      ? widget.builder(context, null)
      : ValueListenableBuilder<LiveMatchState?>(
          valueListenable: _value!,
          builder: (context, state, _) => widget.builder(context, state),
        );
}
