/// A public-data cache. Null is an authoritative result, failures are not.
/// Consumers must still validate coverage and publication freshness.
class RetainedAsyncValue<T> {
  RetainedAsyncValue({
    this.ttl = const Duration(minutes: 2),
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;
  final Duration ttl;
  final DateTime Function() clock;
  T? _value;
  bool _loaded = false;
  DateTime? _checkedAt;
  Future<T>? _pending;

  void invalidate() {
    _checkedAt = null;
  }

  Future<T> read(Future<T> Function() fetch) {
    final pending = _pending;
    if (pending != null) return pending;
    if (_loaded &&
        _checkedAt != null &&
        clock().difference(_checkedAt!) < ttl) {
      return Future.value(_value as T);
    }
    final request = _refresh(fetch);
    _pending = request;
    return request;
  }

  Future<T> _refresh(Future<T> Function() fetch) async {
    try {
      final value = await Future<T>.sync(fetch);
      _value = value;
      _loaded = true;
      _checkedAt = clock();
      return value;
    } catch (_) {
      if (!_loaded) rethrow;
      // Retry on the next visit; a failed request never becomes an empty feed.
      return _value as T;
    } finally {
      _pending = null;
    }
  }
}
