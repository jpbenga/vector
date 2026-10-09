import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/identity/identity_scope.dart';
import '../../../core/identity/scoped_persistence.dart';
import '../../../core/supabase/supabase_initializer.dart';
import '../../../core/theme/app_components.dart';
import '../../../core/widgets/lector_match_card.dart';
import '../data/generator_repository.dart';
import '../data/generator_voice.dart';
import 'generator_ticket_card.dart';
import 'generator_compositions.dart';
import 'generator_analysis.dart';
import 'generator_selection_sheet.dart';
import 'generator_decisions.dart';
import '../domain/generator_context.dart';

/// One native Lector conversation surface in every sport. No generated markup.
class LectorGeneratorPage extends StatefulWidget {
  const LectorGeneratorPage({
    required this.date,
    required this.scope,
    required this.loadContext,
    required this.onPreferences,
    required this.onOpenMatch,
    this.onUseProfile,
    this.onLegacyTickets,
    this.repository,
    this.configurationKey = '',
    this.voice,
    this.embedded = false,
    this.durableSessions =
        const String.fromEnvironment(
          'LECTOR_GENERATOR_ENDPOINT',
          defaultValue: 'lector-generator',
        ) ==
        'lector-generator-workshop',
    super.key,
  });
  final DateTime date;
  final IdentityScope scope;
  final Future<GeneratorContext> Function() loadContext;
  final VoidCallback onPreferences;
  final VoidCallback? onUseProfile, onLegacyTickets;
  final void Function(Map<String, dynamic> pick) onOpenMatch;
  final GeneratorRepository? repository;
  final GeneratorVoice? voice;
  final bool embedded, durableSessions;
  final String configurationKey;
  @override
  State<LectorGeneratorPage> createState() => _LectorGeneratorPageState();
}

class _LectorGeneratorPageState extends State<LectorGeneratorPage>
    with WidgetsBindingObserver {
  final _message = TextEditingController();
  final _scroll = ScrollController();
  final _defaultVoice = GeneratorVoice();
  GeneratorVoice get _voice => widget.voice ?? _defaultVoice;
  Timer? _progressTimer, _voiceTimer, _sessionTimer;
  final Map<String, Map<String, dynamic>> _decisions = {};
  String? _requestId, _retryMessage, _retryRequestId, _retryReferenceTicketId;
  String _phase = 'Analyse de votre demande…';
  Map<String, dynamic> _progress = {};
  bool _recording = false, _transcribing = false;
  int _recordSeconds = 0;
  GeneratorContext? _context;
  GeneratorConversation? _conversation;
  Map<String, dynamic>? _preparation;
  String _id = generatorUuid();
  String? _error;
  String? _submittedMessage;
  bool _busy = false;
  int _generation = 0;
  static const _key =
      String.fromEnvironment(
            'LECTOR_GENERATOR_ENDPOINT',
            defaultValue: 'lector-generator',
          ) ==
          'lector-generator-workshop'
      ? 'generator.conversation.workshop.v1'
      : 'generator.conversation.v1';
  GeneratorRepository? get _repository {
    if (widget.repository != null) return widget.repository;
    final client = getIt.isRegistered<SupabaseInitializer>()
        ? getIt<SupabaseInitializer>().client
        : null;
    return client == null ? null : SupabaseGeneratorRepository(client);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
    if (widget.durableSessions) {
      _sessionTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        _expireSessionIfNeeded();
        if (mounted && _conversation != null) setState(() {});
      });
    }
  }

  @override
  void didUpdateWidget(covariant LectorGeneratorPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scope != widget.scope || oldWidget.date != widget.date) {
      _generation++;
      _progressTimer?.cancel();
      _voiceTimer?.cancel();
      _voice.cancel();
      _recording = false;
      _transcribing = false;
      _requestId = null;
      _retryMessage = null;
      _retryRequestId = null;
      _retryReferenceTicketId = null;
      _conversation = null;
      _decisions.clear();
      _preparation = null;
      _context = null;
      _busy = false;
      _error = null;
      _submittedMessage = null;
      _id = generatorUuid();
      _message.clear();
      _initialize();
    } else if (oldWidget.configurationKey != widget.configurationKey) {
      final generation = _generation;
      widget
          .loadContext()
          .then((value) {
            if (!mounted || generation != _generation) return;
            setState(() => _context = value);
            _prepare(generation);
          })
          .catchError((Object error) {
            if (mounted && generation == _generation) {
              setState(
                () => _error =
                    'Votre contexte n’a pas pu être chargé. Réessayez.',
              );
            }
          });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
    _progressTimer?.cancel();
    _voiceTimer?.cancel();
    _voice.cancel();
    _sessionTimer?.cancel();
    _scroll.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _expireSessionIfNeeded();
  }

  void _expireSessionIfNeeded() {
    if (!mounted || !widget.durableSessions || _conversation == null) return;
    final deadline = DateTime.tryParse(
      _conversation!.json['expiresAt']?.toString() ?? '',
    );
    if (deadline == null || deadline.isAfter(DateTime.now())) return;
    _generation++;
    _progressTimer?.cancel();
    setState(() {
      _conversation = null;
      _id = generatorUuid();
      _busy = false;
      _submittedMessage = null;
      _error =
          'Votre session a expiré. Vos éléments conservés restent dans Mes suivis.';
    });
  }

  Future<void> _initialize() async {
    final generation = ++_generation;
    try {
      final context = await widget.loadContext();
      final saved = widget.scope.isUserOwned
          ? await const ScopedPersistence().read(widget.scope, _key)
          : null;
      if (!mounted || generation != _generation) return;
      // Local value is only a conversation reference. Private content remains
      // server-owned and is not restored under a different account.
      setState(() {
        _context = context;
      });
      if (saved != null) {
        final value = generatorMap(jsonDecode(saved));
        // Saved drafts are deliberately opened from history, not injected as
        // the active context when the user arrives on a different date.
        if (value['date'] == generatorDay(widget.date) &&
            widget.scope.isAccount &&
            _repository != null) {
          try {
            final result = await _repository!.request({
              'action': 'read',
              'conversationId': value['id'],
              'revision': 0,
            });
            if (!mounted || generation != _generation) return;
            if (result['state'] != null) {
              setState(
                () => _conversation = GeneratorConversation(
                  generatorMap(result['state']),
                ),
              );
            }
          } on Object {
            // A stale reference never prevents starting a new conversation.
          }
        }
      }
      await _prepare(generation);
      if (widget.durableSessions &&
          widget.scope.isAccount &&
          _repository != null) {
        try {
          final result = await _repository!.request({'action': 'decisions'});
          if (mounted && generation == _generation) {
            setState(() {
              for (final row in generatorRows(result['decisions'])) {
                _decisions['${row['kind']}:${row['source_id']}'] = row;
              }
            });
          }
        } on Object {
          /* Calendar and conversation remain usable. */
        }
      }
    } on Object {
      if (mounted && generation == _generation) {
        setState(
          () => _error = 'Votre contexte n’a pas pu être chargé. Réessayez.',
        );
      }
    }
  }

  Map<String, Object?> _body(String action) => {
    'action': action,
    'conversationId': _conversation?.id ?? _id,
    'revision': _conversation?.revision ?? 0,
    'date': generatorDay(widget.date),
    'context': _context!.toJson(),
  };
  Future<void> _prepare(int generation) async {
    if (!widget.scope.isAccount || _repository == null) return;
    try {
      final result = await _repository!.request(_body('prepare'));
      if (mounted && generation == _generation) {
        setState(() => _preparation = generatorMap(result['preparation']));
      }
    } on Object {
      // An unopened/uninstalled AI service never blocks the existing calendar.
    }
  }

  Future<void> _send([String? preset, String? referenceTicketId]) async {
    final message = preset ?? _message.text.trim();
    if (_busy || _context == null || message.isEmpty) return;
    final expires = DateTime.tryParse(
      _conversation?.json['expiresAt']?.toString() ?? '',
    );
    if (widget.durableSessions &&
        expires != null &&
        !expires.isAfter(DateTime.now())) {
      _conversation = null;
      _id = generatorUuid();
    }
    if (!widget.scope.isAccount) {
      setState(
        () => _error =
            'Connectez-vous à votre compte pour utiliser l’assistant et conserver vos brouillons.',
      );
      _scrollToEnd();
      return;
    }
    final repository = _repository;
    if (repository == null) {
      setState(() => _error = 'L’assistant IA n’est pas encore configuré.');
      return;
    }
    final generation = _generation;
    final requestId = generatorUuid();
    _requestId = requestId;
    _phase = 'Analyse de votre demande…';
    _progress = {};
    _retryMessage = message;
    _retryRequestId = requestId;
    _retryReferenceTicketId = referenceTicketId;
    setState(() {
      _busy = true;
      _error = null;
      _submittedMessage = message;
      _message.clear();
    });
    _scrollToEnd();
    _startProgress(requestId);
    try {
      final result = await repository.request({
        ..._body('chat'),
        'message': message,
        'requestId': requestId,
        'referenceTicketId': ?referenceTicketId,
      });
      if (!mounted || generation != _generation || _requestId != requestId) {
        return;
      }
      final conversation = GeneratorConversation(generatorMap(result['state']));
      setState(() {
        _conversation = conversation;
        _submittedMessage = null;
        _retryMessage = null;
        _retryRequestId = null;
        _retryReferenceTicketId = null;
      });
      _scrollToEnd();
      await const ScopedPersistence().write(
        widget.scope,
        _key,
        jsonEncode({'id': conversation.id, 'date': generatorDay(widget.date)}),
      );
    } on Object catch (error) {
      if (mounted && generation == _generation && _requestId == requestId) {
        setState(
          () => _error = error.toString().replaceFirst('Bad state: ', ''),
        );
      }
    } finally {
      if (mounted && generation == _generation && _requestId == requestId) {
        _progressTimer?.cancel();
        setState(() {
          _busy = false;
          _requestId = null;
        });
      }
    }
  }

  Future<void> _operation(String action, {String? ticketId}) async {
    if (_busy || _conversation == null) return;
    final generation = _generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await _repository!.request({
        ..._body(action),
        'ticketId': ?ticketId,
      });
      if (!mounted || generation != _generation) return;
      setState(
        () => _conversation = GeneratorConversation(
          generatorMap(result['state']),
        ),
      );
    } on Object catch (error) {
      if (mounted && generation == _generation) {
        setState(
          () => _error = error.toString().replaceFirst('Bad state: ', ''),
        );
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _history() async {
    if (!widget.scope.isAccount || _repository == null) {
      setState(() => _error = 'Connectez-vous pour retrouver vos brouillons.');
      return;
    }
    final generation = _generation;
    try {
      final result = await _repository!.request({'action': 'history'});
      if (!mounted || generation != _generation) return;
      final selected = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => SizedBox(
          height: MediaQuery.sizeOf(context).height * .8,
          child: DefaultTabController(
            length: widget.durableSessions ? 2 : 1,
            child: Column(
              children: [
                TabBar(
                  tabs: [
                    Tab(
                      text: widget.durableSessions
                          ? 'Sessions actives'
                          : 'Vos brouillons',
                    ),
                    if (widget.durableSessions)
                      const Tab(text: 'Mes éléments sauvegardés'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      ListView(
                        children: [
                          if (generatorRows(result['history']).isEmpty)
                            const ListTile(
                              title: Text('Aucune session à reprendre.'),
                            ),
                          for (final row in generatorRows(result['history']))
                            ListTile(
                              leading: const Icon(Icons.chat_bubble_outline),
                              title: Text(
                                '${generatorRows(row['tickets']).length} composition(s)',
                              ),
                              subtitle: Text(
                                widget.durableSessions
                                    ? _expiration(row)
                                    : generatorMap(
                                            row['intent'],
                                          )['date']?.toString() ??
                                          '',
                              ),
                              onTap: () => Navigator.pop(context, row),
                            ),
                        ],
                      ),
                      if (widget.durableSessions)
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: GeneratorFollowups(
                            scope: widget.scope,
                            repository: _repository,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (selected != null && mounted && generation == _generation) {
        setState(() => _conversation = GeneratorConversation(selected));
      }
    } on Object {
      if (mounted && generation == _generation) {
        setState(
          () =>
              _error = 'Les brouillons ne sont pas accessibles pour le moment.',
        );
      }
    }
  }

  String _expiration(Map<String, dynamic> value) {
    final deadline = DateTime.tryParse(value['expiresAt']?.toString() ?? '');
    if (deadline == null) {
      return 'Session temporaire · 24 h après la dernière activité';
    }
    final remaining = deadline.difference(DateTime.now());
    if (remaining.isNegative) {
      return 'Session expirée · vos suivis sont conservés';
    }
    return 'Expire dans ${remaining.inHours} h ${(remaining.inMinutes % 60)} min';
  }

  Map<String, dynamic> _decisionFor(Map<String, dynamic> pick) =>
      _decisions['selection:${pick['id']}'] ?? {};
  Future<Map<String, dynamic>> _keep(
    String kind,
    String sourceId,
    String choice,
  ) async {
    if (_repository == null ||
        !widget.scope.isAccount ||
        _conversation == null) {
      throw StateError('Connectez-vous pour conserver cette proposition.');
    }
    final generation = _generation;
    final result = await _repository!.request({
      ..._body('keep'),
      'kind': kind,
      'sourceId': sourceId,
      'choice': choice,
    });
    final decision = generatorMap(result['decision']);
    if (mounted && generation == _generation) {
      setState(() {
        _decisions['$kind:$sourceId'] = decision;
        if (decision['sessionExpiresAt'] != null && _conversation != null) {
          _conversation = GeneratorConversation({
            ..._conversation!.json,
            'expiresAt': decision['sessionExpiresAt'],
          });
        }
      });
    }
    return decision;
  }

  Future<void> _saveTicket(Map<String, dynamic> ticket) async {
    try {
      await _keep('ticket', ticket['id'].toString(), 'save');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket conservé dans Mes suivis.')),
        );
      }
    } on Object {
      if (mounted) {
        setState(() => _error = 'Le ticket n’a pas pu être enregistré.');
      }
    }
  }

  Future<void> _deleteSession() async {
    if (_conversation == null || _repository == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Supprimer cette session ?'),
        content: const Text(
          'Les messages et brouillons seront supprimés. Vos tickets enregistrés et sélections suivies resteront dans le Bilan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _repository!.request(_body('delete_session'));
      if (mounted) {
        setState(() {
          _conversation = null;
          _id = generatorUuid();
        });
      }
    } on Object {
      if (mounted) {
        setState(() => _error = 'La session n’a pas pu être supprimée.');
      }
    }
  }

  Future<void> _newSession() async {
    final tickets = _conversation?.tickets ?? [];
    final unsaved = tickets
        .where((t) => _decisions['ticket:${t['id']}']?['saved_at'] == null)
        .toList();
    if (widget.durableSessions && unsaved.isNotEmpty) {
      final choice = await showDialog<String>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Conserver une composition ?'),
          content: const Text(
            'Les compositions non enregistrées disparaîtront à l’expiration de la session. Vous pouvez conserver le ticket actuel pour vérifier ses résultats.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, 'stay'),
              child: const Text('Revenir aux tickets'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, 'skip'),
              child: const Text('Pas maintenant'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, 'save'),
              child: const Text('Enregistrer le ticket actuel'),
            ),
          ],
        ),
      );
      if (choice == null || choice == 'stay' || !mounted) return;
      if (choice == 'save') {
        try {
          await _keep('ticket', unsaved.first['id'].toString(), 'save');
        } on Object {
          if (mounted) {
            setState(() => _error = 'Le ticket n’a pas pu être conservé.');
          }
          return;
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _conversation = null;
      _id = generatorUuid();
      _error = null;
      _submittedMessage = null;
      _retryMessage = null;
      _retryRequestId = null;
      _retryReferenceTicketId = null;
      _voice.cancel();
      _voiceTimer?.cancel();
      _recording = false;
    });
    if (widget.scope.isUserOwned) {
      await const ScopedPersistence().write(
        widget.scope,
        _key,
        jsonEncode({'id': _id, 'date': generatorDay(widget.date)}),
      );
    }
  }

  Future<void> _useProfile() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Utiliser votre profil ?'),
        content: const Text(
          'Les prochaines préparations utiliseront votre profil enregistré. Les compositions existantes conservent leur configuration initiale.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Utiliser mon profil'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) widget.onUseProfile?.call();
  }

  Future<void> _settings() async {
    if (_context == null) return;
    final budget = TextEditingController(
      text: _context!.budget.toStringAsFixed(0),
    );
    bool discovery = _context!.discovery;
    final next = await showDialog<GeneratorContext>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Contexte de préparation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: budget,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Plafond total des mises (€)',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Découverte'),
                subtitle: const Text(
                  'Inclure les pistes du Radar hors de mes compétitions.',
                ),
                value: discovery,
                onChanged: (v) => update(() => discovery = v),
              ),
              const Text(
                'Les marchés interdits restent exclus. Chaque composition conserve le contexte utilisé.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                final value = double.tryParse(budget.text.replaceAll(',', '.'));
                if (value != null && value >= 0 && value <= 1000) {
                  Navigator.pop(
                    context,
                    _context!.copyWith(budget: value, discovery: discovery),
                  );
                }
              },
              child: const Text('Appliquer'),
            ),
          ],
        ),
      ),
    );
    budget.dispose();
    if (next != null && mounted) {
      setState(() => _context = next);
      _prepare(_generation);
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _startProgress(String requestId) {
    _progressTimer?.cancel();
    bool polling = false;
    _progressTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (polling || !mounted || _requestId != requestId) return;
      polling = true;
      try {
        final result = await _repository!.request({
          ..._body('status'),
          'requestId': requestId,
        });
        if (!mounted || _requestId != requestId) return;
        final turn = generatorMap(result['turn']);
        final phase = turn['phase'];
        setState(() {
          _progress = turn;
          _phase = switch (phase) {
            'analyze' => 'Réflexion en cours…',
            'details' => 'Examen des lectures et des marchés…',
            'sources' => 'Analyse des rencontres…',
            'compose' => 'Comparaison des compositions…',
            'review' => 'Analyse des arguments et des compromis…',
            'commit' => 'Enregistrement du brouillon…',
            _ => 'Analyse de votre demande…',
          };
        });
      } on Object {
        /* Progress is optional; the actual result remains authoritative. */
      } finally {
        polling = false;
      }
    });
  }

  Future<void> _interrupt() async {
    final requestId = _requestId;
    if (requestId == null || _repository == null) return;
    final generation = _generation;
    try {
      final result = await _repository!.request({
        ..._body('cancel'),
        'requestId': requestId,
      });
      if (!mounted || generation != _generation || _requestId != requestId) {
        return;
      }
      _progressTimer?.cancel();
      setState(() {
        _requestId = null;
        _busy = false;
        _transcribing = false;
        _submittedMessage = null;
        _error = null;
      });
      if (generatorMap(result['turn'])['status'] == 'complete') {
        final read = await _repository!.request(_body('read'));
        if (mounted && generation == _generation && read['state'] != null) {
          setState(
            () => _conversation = GeneratorConversation(
              generatorMap(read['state']),
            ),
          );
        }
      } else if (_retryMessage != null) {
        _message.text = _retryMessage!;
      }
    } on Object {
      if (mounted && generation == _generation) {
        setState(() => _error = 'L’interruption n’a pas pu être confirmée.');
      }
    }
  }

  Future<void> _retry() async {
    final message = _retryMessage;
    final referenceTicketId = _retryReferenceTicketId;
    if (message == null || _busy) return;
    final generation = _generation;
    try {
      final status = _retryRequestId == null
          ? <String, dynamic>{}
          : await _repository!.request({
              ..._body('status'),
              'requestId': _retryRequestId,
            });
      if (!mounted || generation != _generation) return;
      if (generatorMap(status['turn'])['status'] == 'pending') {
        setState(
          () => _error =
              'Cette recherche est encore en cours. Patientez, puis réessayez pour retrouver son résultat.',
        );
        return;
      }
      final result = await _repository!.request(_body('read'));
      if (!mounted || generation != _generation) return;
      if (result['state'] != null) {
        final latest = GeneratorConversation(generatorMap(result['state']));
        final completed = generatorMap(status['turn'])['status'] == 'complete';
        setState(() {
          _conversation = latest;
          _error = null;
          if (completed) {
            _submittedMessage = null;
            _retryMessage = null;
            _retryRequestId = null;
            _retryReferenceTicketId = null;
          }
        });
        if (completed) return;
      }
      await _send(message, referenceTicketId);
    } on Object {
      if (mounted && generation == _generation) {
        setState(
          () =>
              _error = 'La conversation n’a pas pu être actualisée. Réessayez.',
        );
      }
    }
  }

  Future<void> _dictate() async {
    if (_busy || _recording || !widget.scope.isAccount) return;
    if (!_voice.supported) {
      setState(
        () => _error =
            'La dictée nécessite un navigateur compatible et une connexion HTTPS. Vous pouvez utiliser le microphone de votre clavier.',
      );
      return;
    }
    final generation = _generation;
    final consent = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dicter votre demande'),
        content: const Text(
          'Autorisez le microphone de votre navigateur. Après « Terminer », jusqu’à une minute d’audio sera transcrite par OpenAI, puis supprimée de l’application. Vous pourrez relire et modifier le texte avant de l’envoyer. La dictée utilise l’enveloppe de tests IA.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Commencer'),
          ),
        ],
      ),
    );
    if (consent != true || !mounted || generation != _generation) return;
    try {
      await _voice.start();
      if (!mounted || generation != _generation) {
        _voice.cancel();
        return;
      }
      setState(() {
        _recording = true;
        _recordSeconds = 0;
        _error = null;
      });
      _voiceTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _recordSeconds++);
        if (_recordSeconds >= 60) _finishDictation();
      });
    } on Object {
      if (mounted && generation == _generation) {
        setState(
          () => _error =
              'Le microphone n’est pas accessible. Vérifiez son autorisation dans le navigateur, ou utilisez la dictée du clavier.',
        );
      }
    }
  }

  void _cancelDictation() {
    _voiceTimer?.cancel();
    _voice.cancel();
    setState(() => _recording = false);
  }

  Future<void> _finishDictation() async {
    if (!_recording) return;
    final generation = _generation;
    _voiceTimer?.cancel();
    final requestId = generatorUuid();
    setState(() {
      _recording = false;
      _transcribing = true;
      _busy = true;
      _requestId = requestId;
    });
    try {
      final audio = await _voice.finish();
      if (!mounted || generation != _generation || _requestId != requestId) {
        return;
      }
      final result = await _repository!.request({
        ..._body('transcribe'),
        'audio': audio,
        'requestId': requestId,
      });
      if (!mounted || generation != _generation || _requestId != requestId) {
        return;
      }
      final text = result['transcript']?.toString() ?? '';
      _message.text = [
        _message.text.trim(),
        text.trim(),
      ].where((s) => s.isNotEmpty).join(' ');
      _message.selection = TextSelection.collapsed(
        offset: _message.text.length,
      );
    } on Object catch (error) {
      if (mounted && generation == _generation && _requestId == requestId) {
        setState(
          () => _error = error.toString().replaceFirst('Bad state: ', ''),
        );
      }
    } finally {
      if (mounted && generation == _generation && _requestId == requestId) {
        setState(() {
          _busy = false;
          _transcribing = false;
          _requestId = null;
        });
      }
    }
  }

  Future<void> _archivedTicket(String id) async {
    final generation = _generation;
    try {
      final result = await _repository!.request({
        ..._body('ticket'),
        'ticketId': id,
      });
      if (mounted && generation == _generation && result['ticket'] != null) {
        _examine(generatorMap(result['ticket']));
      }
    } on Object {
      if (mounted && generation == _generation) {
        setState(() => _error = 'Ce brouillon n’a pas pu être ouvert.');
      }
    }
  }

  void _prompt(String text) {
    _message.text = text;
    _message.selection = TextSelection.collapsed(offset: text.length);
  }

  Widget _ticket(Map<String, dynamic> ticket) => LectorTicketCard(
    ticket: ticket,
    enabled: !_busy,
    onSave: widget.durableSessions ? () => _saveTicket(ticket) : null,
    saved: _decisions['ticket:${ticket['id']}']?['saved_at'] != null,
    pending: _conversation?.pending.any((t) => t['id'] == ticket['id']) == true,
    onDetail: () => _examine(ticket),
    onSelection: (index) => _examine(ticket, selection: index),
    onModify: () => _examine(ticket),
    onAlternative: () => _send(
      'Propose-moi un autre ticket avec les mêmes contraintes que le ticket ${ticket['number']}.',
      ticket['id']?.toString(),
    ),
  );
  void _examine(
    Map<String, dynamic> ticket, {
    int? selection,
  }) => showGeneratorTicketDetail(
    context,
    ticket,
    selection: selection,
    inTicket:
        _conversation?.tickets.any((t) => t['id'] == ticket['id']) == true,
    onOpenMatch: widget.onOpenMatch,
    onChoice: widget.durableSessions
        ? (pick, choice) => _keep('selection', pick['id'].toString(), choice)
        : null,
    decisionFor: _decisionFor,
    onReplace: (index) => _prompt(
      'Remplace uniquement la sélection ${index + 1} du ticket ${ticket['number']}. Conserve les autres sélections, la mise et les contraintes.',
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), current = _context;
    final conversation = _conversation;
    final tickets = <String, Map<String, dynamic>>{
      for (final t in [
        ...generatorRows(conversation?.json['drafts']),
        ...generatorRows(conversation?.json['proposals']),
        ...?conversation?.tickets,
        ...?conversation?.pending,
      ])
        t['id'].toString(): t,
    };
    final hasAttachments =
        conversation?.messages.any((m) => m.containsKey('ticketIds')) == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 6, 10),
          child: Row(
            children: [
              Icon(
                Icons.smart_toy_outlined,
                size: 30,
                color: context.brand.accent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Générateur',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      widget.durableSessions && conversation != null
                          ? _expiration(conversation.json)
                          : 'Votre assistant de composition',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.textColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: widget.durableSessions
                    ? 'Sessions et éléments sauvegardés'
                    : 'Vos brouillons',
                onPressed: _busy ? null : _history,
                icon: const Icon(Icons.history_rounded),
              ),
              PopupMenuButton<String>(
                tooltip: 'Options du générateur',
                onSelected: (value) {
                  switch (value) {
                    case 'new':
                      _newSession();
                    case 'retention':
                      showDialog<void>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('Données et conservation'),
                          content: const SingleChildScrollView(
                            child: Text(
                              'Par défaut, votre conversation temporaire expire 24 h après la dernière activité, avec une durée maximale de 7 jours. Les délais sont configurables côté serveur.\n\nLes tickets enregistrés et sélections conservées restent dans Mes suivis jusqu’à leur suppression par vous. Leurs cotes et arguments d’origine sont conservés.\n\nLes propositions générées et les reçus techniques sont conservés séparément pendant 30 jours pour l’audit, sans les messages du chat. La pertinence est un avis ; le suivi n’est pas un pari placé. Aucun apprentissage prédictif automatique n’est activé.\n\nVous pouvez supprimer une session depuis ce menu et chaque élément conservé depuis son détail.',
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c),
                              child: const Text('Fermer'),
                            ),
                          ],
                        ),
                      );
                    case 'delete_session':
                      _deleteSession();
                    case 'settings':
                      _settings();
                    case 'preferences':
                      widget.onPreferences();
                    case 'profile':
                      _useProfile();
                    case 'save':
                      if (widget.durableSessions) {
                        final ticket = conversation?.tickets.firstOrNull;
                        if (ticket != null) _saveTicket(ticket);
                      } else {
                        _operation('save');
                      }
                    case 'legacy':
                      widget.onLegacyTickets?.call();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'new',
                    enabled: !_busy,
                    child: const Text('Nouvelle conversation'),
                  ),
                  if (widget.durableSessions)
                    const PopupMenuItem(
                      value: 'retention',
                      child: Text('Données et conservation'),
                    ),
                  if (widget.durableSessions && conversation != null)
                    PopupMenuItem(
                      value: 'delete_session',
                      enabled: !_busy,
                      child: const Text('Supprimer cette session'),
                    ),
                  PopupMenuItem(
                    value: 'settings',
                    enabled: !_busy,
                    child: const Text('Ajuster le contexte'),
                  ),
                  const PopupMenuItem(
                    value: 'preferences',
                    child: Text('Mes préférences'),
                  ),
                  if (current?.origin == 'explorer' &&
                      widget.onUseProfile != null)
                    const PopupMenuItem(
                      value: 'profile',
                      child: Text('Utiliser mon profil'),
                    ),
                  if (conversation?.tickets.isNotEmpty == true)
                    PopupMenuItem(
                      value: 'save',
                      enabled: !_busy,
                      child: Text(
                        widget.durableSessions
                            ? 'Enregistrer le ticket actuel'
                            : conversation!.saved
                            ? 'Brouillon enregistré'
                            : 'Enregistrer le brouillon',
                      ),
                    ),
                  if (widget.onLegacyTickets != null)
                    const PopupMenuItem(
                      value: 'legacy',
                      child: Text('Mes tickets et stratégies'),
                    ),
                ],
              ),
            ],
          ),
        ),
        Divider(height: 1, color: context.surfaces.border),
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
            children: [
              if (conversation == null && _submittedMessage == null) ...[
                GeneratorMessageBubble(
                  text: current?.origin == 'explorer'
                      ? 'Votre configuration Explorateur est active. Posez une question sur les rencontres ou décrivez le ticket que vous souhaitez préparer.'
                      : 'Je m’appuie sur vos lectures, le Radar et vos marchés autorisés. Quelle journée souhaitez-vous analyser ou quelle composition voulez-vous préparer ?',
                ),
                LectorMatchCardFrame(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        current?.origin == 'explorer'
                            ? 'Explorateur · configuration temporaire'
                            : 'Profil enregistré',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${DateFormat('EEEE d MMMM', 'fr').format(widget.date)} · ${current?.count('readings') ?? 0} lectures',
                        style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        current?.discovery == true
                            ? 'Pour moi + pistes du Radar'
                            : 'Mes compétitions uniquement',
                        style: theme.textTheme.bodySmall,
                      ),
                      if (_preparation != null)
                        Text(
                          '${_preparation!['matchCount']} rencontres analysables',
                          style: theme.textTheme.bodySmall,
                        ),
                      if (_preparation != null)
                        for (final missing
                            in (generatorMap(_preparation)['missing']
                                    as List? ??
                                []))
                          Text(
                            missing.toString(),
                            style: theme.textTheme.bodySmall,
                          ),
                      TextButton(
                        onPressed: _settings,
                        child: const Text('Ajuster le contexte'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final suggestion in [
                      'Top 5 dans Pour moi',
                      'Préparer un ticket',
                      'Créer plusieurs tickets',
                      'Explorer les joueurs chauds',
                    ])
                      ActionChip(
                        label: Text(suggestion),
                        onPressed: () => _prompt(
                          '$suggestion pour ${generatorDay(widget.date)}.',
                        ),
                      ),
                  ],
                ),
              ],
              for (final message
                  in conversation?.messages ?? <Map<String, dynamic>>[]) ...[
                GeneratorMessageBubble(
                  text: message['text']?.toString() ?? '',
                  user: message['role'] == 'user',
                  at: message['at']?.toString(),
                ),
                if (message['analysis'] is Map)
                  GeneratorAnalysisResult(
                    analysis: generatorMap(message['analysis']),
                    onInspect: (pick) => showGeneratorSelectionDetail(
                      context,
                      pick: pick,
                      inTicket: false,
                      analysisOnly: true,
                      onChoice: widget.durableSessions
                          ? (choice) => _keep(
                              'selection',
                              pick['id'].toString(),
                              choice,
                            )
                          : null,
                      decision: _decisionFor(pick),
                      onOpenMatch: () => widget.onOpenMatch(pick),
                      onReplace: () => _send(
                        'Compare les autres marchés autorisés pour ${pick['home']} contre ${pick['away']}, dans le même périmètre et la même journée.',
                      ),
                    ),
                  ),
                if ((message['proposalIds'] as List? ?? []).length > 1)
                  GeneratorCompositionOptions(
                    tickets: [
                      for (final id in message['proposalIds'] as List)
                        if (tickets[id.toString()] != null)
                          tickets[id.toString()]!,
                    ],
                    selectedId: conversation?.tickets.firstOrNull?['id']
                        ?.toString(),
                    onInspect: (ticket) => _examine(ticket),
                    onChoose:
                        !_busy &&
                            (message['proposalIds'] as List).every(
                              (id) => generatorRows(
                                conversation?.json['proposals'],
                              ).any((t) => t['id'] == id),
                            )
                        ? (ticket) => _operation(
                            'apply',
                            ticketId: ticket['id'].toString(),
                          )
                        : null,
                  ),
                for (final id in (message['ticketIds'] as List? ?? []))
                  if (tickets[id.toString()] != null)
                    _ticket(tickets[id.toString()]!)
                  else
                    TextButton.icon(
                      onPressed: () => _archivedTicket(id.toString()),
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: const Text('Revoir ce ticket'),
                    ),
              ],
              if (!hasAttachments)
                for (final ticket
                    in conversation?.tickets ?? <Map<String, dynamic>>[])
                  _ticket(ticket),
              if (conversation?.pending.isNotEmpty == true) ...[
                if (!hasAttachments)
                  for (final ticket in conversation!.pending) _ticket(ticket),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: FilledButton.icon(
                    onPressed: _busy ? null : () => _operation('apply'),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Appliquer le changement proposé'),
                  ),
                ),
                Text(
                  'Le ticket initial reste conservé dans la conversation.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
              if (_submittedMessage != null)
                GeneratorMessageBubble(text: _submittedMessage!, user: true),
              if (_busy)
                GeneratorAnalysisProgress(
                  phase: _transcribing ? 'Transcription en cours…' : _phase,
                  progress: _progress,
                ),
              if (_error != null)
                LectorMatchCardFrame(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _error!,
                        style: TextStyle(color: context.semantic.warning),
                      ),
                      if (_retryMessage != null && !_busy)
                        TextButton.icon(
                          onPressed: _retry,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Réessayer'),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(
              color: context.surfaces.background,
              border: Border(top: BorderSide(color: context.surfaces.border)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_recording)
                  Row(
                    children: [
                      Icon(Icons.mic_rounded, color: context.semantic.live),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('À l’écoute… ${_recordSeconds}s / 60s'),
                      ),
                      TextButton(
                        onPressed: _cancelDictation,
                        child: const Text('Annuler'),
                      ),
                      TextButton(
                        onPressed: _finishDictation,
                        child: const Text('Terminer'),
                      ),
                    ],
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _message,
                          enabled: !_busy,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: 2000,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: const InputDecoration(
                            hintText: 'Écrivez votre demande…',
                            counterText: '',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton.filled(
                        tooltip: 'Dicter une demande',
                        onPressed: _busy || !widget.scope.isAccount
                            ? null
                            : _dictate,
                        icon: const Icon(Icons.mic_none_rounded),
                      ),
                      const SizedBox(width: 4),
                      if (_busy && _requestId != null)
                        IconButton(
                          tooltip: 'Interrompre la génération',
                          onPressed: _interrupt,
                          icon: const Icon(Icons.stop_circle_outlined),
                        )
                      else
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _message,
                          builder: (_, value, _) => IconButton(
                            tooltip: 'Envoyer la demande',
                            onPressed:
                                _busy ||
                                    current == null ||
                                    value.text.trim().isEmpty
                                ? null
                                : _send,
                            icon: Icon(
                              Icons.send_rounded,
                              color: value.text.trim().isEmpty
                                  ? context.textColors.secondary
                                  : context.brand.accent,
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
