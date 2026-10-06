import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/supabase/supabase_initializer.dart';
import '../../application/live_match_controller.dart';
import '../../domain/live_match_state.dart';

/// Watch the whole selected day, including cards hidden by a temporal filter.
/// All listeners still share the controller's batched read and single channel.
class LiveMatchListBuilder extends StatefulWidget {
  const LiveMatchListBuilder({
    required this.fixtureIds,
    required this.builder,
    this.controller,
    super.key,
  });
  final Set<int> fixtureIds;
  final Widget Function(BuildContext, Map<int, LiveMatchState>) builder;
  final LiveMatchController? controller;
  @override
  State<LiveMatchListBuilder> createState() => _LiveMatchListBuilderState();
}

class _LiveMatchListBuilderState extends State<LiveMatchListBuilder> {
  LiveMatchController? _controller;
  final Map<int, ValueListenable<LiveMatchState?>> _values = {};
  @override
  void initState() {
    super.initState();
    _attach();
  }

  void _attach() {
    _controller =
        widget.controller ??
        (getIt.isRegistered<LiveMatchController>() &&
                getIt.isRegistered<SupabaseInitializer>() &&
                getIt<SupabaseInitializer>().client != null
            ? getIt<LiveMatchController>()
            : null);
    for (final id in widget.fixtureIds) {
      final value = _controller?.watch(id);
      if (value != null) {
        _values[id] = value;
        value.addListener(_changed);
      }
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _detach() {
    for (final entry in _values.entries) {
      entry.value.removeListener(_changed);
      _controller?.unwatch(entry.key);
    }
    _values.clear();
  }

  @override
  void didUpdateWidget(covariant LiveMatchListBuilder old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller ||
        old.fixtureIds.length != widget.fixtureIds.length ||
        !old.fixtureIds.containsAll(widget.fixtureIds)) {
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
  Widget build(BuildContext context) => widget.builder(context, {
    for (final entry in _values.entries)
      if (entry.value.value != null) entry.key: entry.value.value!,
  });
}
