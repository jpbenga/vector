import 'package:flutter/material.dart';
import '../data/read_recovery.dart';
import 'lector_loading.dart';
import 'lector_responsive_layout.dart';

/// Shared route shell: detail data is fetched only after opening the match.
class LectorDeferredContent<T> extends StatefulWidget {
  const LectorDeferredContent({
    required this.load,
    required this.builder,
    required this.title,
    super.key,
  });
  final Future<T> Function() load;
  final Widget Function(BuildContext, T) builder;
  final String title;
  @override
  State<LectorDeferredContent<T>> createState() =>
      _LectorDeferredContentState<T>();
}

class _LectorDeferredContentState<T> extends State<LectorDeferredContent<T>> {
  late Future<T> _result;
  late final ReadRecovery _recovery;
  @override
  void initState() {
    super.initState();
    _recovery = ReadRecovery(onConnectionReturn: _restart);
    _result = _recovery.read(widget.load);
  }

  void _restart() {
    if (mounted) setState(() => _result = _recovery.read(widget.load));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _recovery.setActive(TickerMode.valuesOf(context).enabled);
  }

  @override
  void dispose() {
    _recovery.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: _result,
    builder: (context, snapshot) {
      if (snapshot.hasData) return widget.builder(context, snapshot.data as T);
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: LectorContent(
            child: ListenableBuilder(
              listenable: _recovery,
              builder: (context, _) => snapshot.hasError
                  ? LectorReadUnavailable(
                      label: 'Les détails sont momentanément indisponibles.',
                      exhausted: _recovery.exhausted,
                    )
                  : LectorLoading(
                      kind: LectorSkeletonKind.detail,
                      label: 'Chargement des détails du match…',
                      recovering: _recovery.recovering,
                    ),
            ),
          ),
        ),
      );
    },
  );
}
