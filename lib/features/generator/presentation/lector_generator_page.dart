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
  final bool embedded;
  final String configurationKey;
  @override
  State<LectorGeneratorPage> createState() => _LectorGeneratorPageState();
}

class _LectorGeneratorPageState extends State<LectorGeneratorPage> {
  final _message = TextEditingController();
  final _scroll = ScrollController();
  final _defaultVoice = GeneratorVoice();
  GeneratorVoice get _voice => widget.voice ?? _defaultVoice;
  Timer? _progressTimer, _voiceTimer;
  String? _requestId, _retryMessage, _retryRequestId, _retryReferenceTicketId;
  String _phase = 'Analyse de votre demande…';
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
  static const _key = 'generator.conversation.v1';
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
    _initialize();
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
    _generation++;
    _progressTimer?.cancel();
    _voiceTimer?.cancel();
    _voice.cancel();
    _scroll.dispose();
    _message.dispose();
    super.dispose();
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
    if (!widget.scope.isAccount) {
      setState(
        () => _error =
            'Connectez-vous à votre compte pour utiliser l’assistant et conserver vos brouillons.',
      );
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

  Future<void> _operation(String action) async {
    if (_busy || _conversation == null) return;
    final generation = _generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await _repository!.request(_body(action));
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
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(title: Text('Vos brouillons')),
              if (generatorRows(result['history']).isEmpty)
                const ListTile(title: Text('Aucun brouillon enregistré.')),
              for (final row in generatorRows(result['history']))
                ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: Text(
                    '${generatorRows(row['tickets']).length} composition(s)',
                  ),
                  subtitle: Text(
                    generatorMap(row['intent'])['date']?.toString() ?? '',
                  ),
                  onTap: () => Navigator.pop(context, row),
                ),
            ],
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
        final phase = generatorMap(result['turn'])['phase'];
        setState(
          () => _phase = switch (phase) {
            'sources' => 'Analyse des rencontres…',
            'compose' => 'Construction des tickets…',
            'commit' => 'Enregistrement du brouillon…',
            _ => 'Analyse de votre demande…',
          },
        );
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
    onOpenMatch: widget.onOpenMatch,
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
                      'Votre assistant de composition',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.textColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Vos brouillons',
                onPressed: _busy ? null : _history,
                icon: const Icon(Icons.history_rounded),
              ),
              PopupMenuButton<String>(
                tooltip: 'Options du générateur',
                onSelected: (value) {
                  switch (value) {
                    case 'new':
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
                    case 'settings':
                      _settings();
                    case 'preferences':
                      widget.onPreferences();
                    case 'profile':
                      _useProfile();
                    case 'save':
                      _operation('save');
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
                        conversation!.saved
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
                      ? 'Votre configuration Explorateur est active. Décrivez le ticket que vous souhaitez préparer : date, mise et objectif.'
                      : 'Je m’appuie sur vos lectures et vos marchés autorisés. Quelle composition souhaitez-vous préparer ?',
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
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Semantics(
                    liveRegion: true,
                    child: Row(
                      children: [
                        const GeneratorAvatar(),
                        const SizedBox(width: 10),
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _transcribing ? 'Transcription en cours…' : _phase,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: context.brand.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
