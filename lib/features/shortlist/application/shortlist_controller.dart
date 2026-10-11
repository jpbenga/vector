import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import '../../../core/auth/supabase_auth_controller.dart';
import '../../../core/identity/identity_scope.dart';
import '../../../core/identity/scoped_persistence.dart';
import '../data/shortlist_repository.dart';
import '../domain/shortlist.dart';
import '../../generator/domain/generator_context.dart';

class ShortlistController extends ChangeNotifier with WidgetsBindingObserver {
  ShortlistController({
    required this.repository,
    this.auth,
    this.persistence = const ScopedPersistence(),
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now {
    WidgetsBinding.instance.addObserver(this);
    auth?.addListener(_authChanged);
    if (auth != null) bindAccount(auth!.user?.id);
    _timer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => notifyListeners(),
    );
  }
  final ShortlistRepository repository;
  final SupabaseAuthController? auth;
  final ScopedPersistence persistence;
  final DateTime Function() clock;
  Timer? _timer;
  String? account;
  ShortlistSnapshot? snapshot;
  String? error;
  bool loading = false;
  int _generation = 0, _reads = 0;
  Duration _serverOffset = Duration.zero;
  final Set<String> selected = {};
  final Map<String, ShortlistFixture> hints = {};
  Future<void> _queue = Future.value();
  DateTime get now => clock().add(_serverOffset);
  ShortlistSession? get active => snapshot?.active(now);
  List<ShortlistSession> get recoverable => snapshot?.recoverable(now) ?? [];
  List<ShortlistFixture> get items =>
      active?.items
          .map(
            (f) => f.available
                ? f
                : ShortlistFixture({
                    ...?hints[f.key]?.json,
                    ...f.json,
                    'home': hints[f.key]?.home,
                    'away': hints[f.key]?.away,
                    'available': false,
                  }),
          )
          .toList() ??
      [];
  bool contains(String key) => items.any((f) => f.key == key);
  void _authChanged() => bindAccount(auth?.user?.id);
  Future<void> bindAccount(String? id) async {
    if (account == id) return;
    final token = ++_generation;
    account = id;
    snapshot = null;
    error = null;
    selected.clear();
    hints.clear();
    loading = id != null;
    _serverOffset = Duration.zero;
    notifyListeners();
    if (id == null) return;
    String? cached;
    try {
      cached = await persistence.read(
        IdentityScope.account(id),
        'shortlist.v1',
      );
    } catch (_) {
      // The remote session remains available when browser storage fails.
    }
    if (token != _generation) return;
    if (cached != null) {
      try {
        snapshot = ShortlistSnapshot(generatorMap(jsonDecode(cached)));
        notifyListeners();
      } catch (_) {
        /* Discard obsolete cache. */
      }
    }
    await refresh();
  }

  Future<void> refresh() async {
    if (account == null) return;
    final token = _generation, request = ++_reads;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final value = await repository.request('read');
      if (token != _generation || request != _reads) return;
      await _accept(value, token);
    } catch (e) {
      if (token == _generation && request == _reads) error = _message(e);
    } finally {
      if (token == _generation && request == _reads) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> mutate(
    String action, {
    ShortlistFixture? fixture,
    String? session,
    DateTime? until,
    int? revision,
  }) {
    final token = _generation;
    final completion = Completer<void>();
    _queue = _queue.catchError((_) {}).then((_) async {
      if (token != _generation) {
        completion.complete();
        return;
      }
      if (account == null) {
        completion.completeError(
          StateError('Connectez-vous pour préparer votre Shortlist.'),
        );
        return;
      }
      _reads++;
      loading = true;
      error = null;
      notifyListeners();
      try {
        final value = await repository.request(
          action,
          session: session ?? active?.id,
          fixture: fixture,
          until: until,
          revision: revision,
        );
        if (token == _generation) {
          _reads++;
          if (fixture != null) hints[fixture.key] = fixture;
          await _accept(value, token);
        }
        completion.complete();
      } catch (e) {
        if (token == _generation) error = _message(e);
        completion.completeError(e);
      } finally {
        if (token == _generation) {
          loading = false;
          notifyListeners();
        }
      }
    });
    return completion.future;
  }

  Future<void> _accept(ShortlistSnapshot value, int token) async {
    if (token != _generation) return;
    final before = active?.id;
    snapshot = value;
    _serverOffset = value.serverNow.difference(clock());
    if (before != active?.id) selected.clear();
    selected.removeWhere((key) => !contains(key));
    notifyListeners();
    final owner = account;
    if (owner != null) {
      try {
        await persistence.write(
          IdentityScope.account(owner),
          'shortlist.v1',
          jsonEncode(value.json),
        );
      } catch (_) {
        // A successful server operation must not become a failed UI action.
      }
    }
  }

  void choose(String key, bool value) {
    if (value) {
      selected.add(key);
    } else {
      selected.remove(key);
    }
    notifyListeners();
  }

  void remember(ShortlistFixture fixture) {
    hints[fixture.key] = fixture;
  }

  static String _message(Object e) =>
      e.toString().replaceFirst(RegExp(r'^(Bad state: |StateError: )'), '');
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  @override
  void dispose() {
    _generation++;
    _timer?.cancel();
    auth?.removeListener(_authChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
