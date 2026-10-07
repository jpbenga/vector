import 'package:flutter/material.dart';

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
  @override
  void initState() {
    super.initState();
    _result = widget.load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: _result,
    builder: (context, snapshot) {
      if (snapshot.hasData) return widget.builder(context, snapshot.data as T);
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!snapshot.hasError) const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                snapshot.hasError
                    ? 'Les détails sont momentanément indisponibles.'
                    : 'Chargement des détails du match…',
              ),
              if (snapshot.hasError)
                TextButton(
                  onPressed: () => setState(() => _result = widget.load()),
                  child: const Text('Réessayer'),
                ),
            ],
          ),
        ),
      );
    },
  );
}
