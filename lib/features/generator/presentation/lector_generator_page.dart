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
  final bool embedded;
  final String configurationKey;
  @override
  State<LectorGeneratorPage> createState() => _LectorGeneratorPageState();
}

class _LectorGeneratorPageState extends State<LectorGeneratorPage> {
  final _message = TextEditingController();
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

  Future<void> _send([String? preset]) async {
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
    setState(() {
      _busy = true;
      _error = null;
      _submittedMessage = message;
      _message.clear();
    });
    try {
      final result = await repository.request({
        ..._body('chat'),
        'message': message,
        'requestId': generatorUuid(),
      });
      if (!mounted || generation != _generation) return;
      final conversation = GeneratorConversation(generatorMap(result['state']));
      setState(() {
        _conversation = conversation;
        _submittedMessage = null;
      });
      await const ScopedPersistence().write(
        widget.scope,
        _key,
        jsonEncode({'id': conversation.id, 'date': generatorDay(widget.date)}),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), current = _context;
    final children = <Widget>[
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Générateur',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text('Assistant Lector', style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Vos brouillons',
            onPressed: _history,
            icon: const Icon(Icons.history_rounded),
          ),
          IconButton(
            tooltip: 'Nouvelle conversation',
            onPressed: _busy
                ? null
                : () => setState(() {
                    _conversation = null;
                    _id = generatorUuid();
                    _error = null;
                    _submittedMessage = null;
                  }),
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
      ),
      const SizedBox(height: 16),
      LectorMatchCardFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CONTEXTE ACTIF', style: theme.textTheme.labelSmall),
            const SizedBox(height: 6),
            Text(
              current?.origin == 'explorer'
                  ? 'Explorateur · configuration temporaire'
                  : 'Profil enregistré',
              style: theme.textTheme.titleSmall,
            ),
            Text(
              current == null
                  ? 'Chargement des préférences…'
                  : '${current.count('readings')} lectures · ${current.count('markets')} marchés · plafond ${current.budget.toStringAsFixed(0)} €',
            ),
            Text(
              current?.discovery == true
                  ? 'Pour moi + pistes du Radar'
                  : 'Strict · mes compétitions uniquement',
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: widget.onPreferences,
                  child: const Text('Voir les préférences'),
                ),
                TextButton(
                  onPressed: _settings,
                  child: const Text('Ajuster le contexte'),
                ),
                if (current?.origin == 'explorer' &&
                    widget.onUseProfile != null)
                  TextButton(
                    onPressed: _useProfile,
                    child: const Text('Utiliser mon profil'),
                  ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      if (_conversation == null) ...[
        LectorMatchCardFrame(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text('Votre préparation', style: theme.textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                DateFormat('EEEE d MMMM', 'fr').format(widget.date),
                style: theme.textTheme.titleSmall,
              ),
              Text(
                current?.sports
                        .map((s) => s == 'hockey' ? 'Hockey' : 'Football')
                        .join(' · ') ??
                    '',
              ),
              const SizedBox(height: 8),
              Text(
                _preparation == null
                    ? 'Préparation à partir des données Lector disponibles.'
                    : '${_preparation!['matchCount']} rencontres analysables · ${_preparation!['radarCount']} profils Radar disponibles',
              ),
              if (_preparation?['status'] == 'anticipated')
                const Text(
                  'Préparation anticipée · certaines lectures ou cotes restent indisponibles.',
                ),
              if (_preparation?['status'] == 'verifiable')
                const Text(
                  'Sélections vérifiables · à examiner avant utilisation.',
                ),
              TextButton.icon(
                onPressed: () {
                  _message.text =
                      'Prépare des tickets pour ${generatorDay(widget.date)}.';
                },
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Préparer mes tickets'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('QUE SOUHAITEZ-VOUS FAIRE ?', style: theme.textTheme.labelMedium),
        Wrap(
          spacing: 8,
          children: [
            for (final suggestion in [
              'Créer plusieurs tickets',
              'Un ticket multisport',
              'Explorer les joueurs chauds',
            ])
              ActionChip(
                label: Text(suggestion),
                onPressed: () => _message.text =
                    '$suggestion pour ${generatorDay(widget.date)}.',
              ),
          ],
        ),
      ],
      if (_conversation != null) ...[
        for (final message in _conversation!.messages)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message['role'] == 'user' ? 'VOUS' : 'LECTOR',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(message['text']?.toString() ?? ''),
              ],
            ),
          ),
        if (_conversation!.pending.isNotEmpty) ...[
          Text('MODIFICATION PROPOSÉE', style: theme.textTheme.titleSmall),
          for (final ticket in _conversation!.pending)
            _ticket(ticket, pending: true),
          FilledButton.icon(
            onPressed: _busy ? null : () => _operation('apply'),
            icon: const Icon(Icons.check_rounded),
            label: const Text('Appliquer le changement'),
          ),
          const SizedBox(height: 16),
        ],
        for (final ticket in _conversation!.tickets) _ticket(ticket),
        if (_conversation!.tickets.isNotEmpty)
          TextButton.icon(
            onPressed: _busy || _conversation!.saved
                ? null
                : () => _operation('save'),
            icon: const Icon(Icons.bookmark_outline_rounded),
            label: Text(
              _conversation!.saved
                  ? 'Brouillon enregistré'
                  : 'Enregistrer le brouillon',
            ),
          ),
        if (generatorMap(_conversation!.json['context'])['origin'] ==
            'explorer')
          const Text(
            'Ces compositions conservent la configuration Explorateur de leur création.',
          ),
        for (final missing
            in (generatorMap(_conversation!.json['catalog'])['missing']
                    as List? ??
                []))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(missing.toString(), style: theme.textTheme.bodySmall),
          ),
      ],
      const SizedBox(height: 16),
      if (_submittedMessage != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'VOUS',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(_submittedMessage!),
            ],
          ),
        ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            _error!,
            style: TextStyle(color: context.semantic.warning),
          ),
        ),
      if (_busy && _submittedMessage != null)
        Semantics(
          liveRegion: true,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text(
                  'Recherche en cours…',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        )
      else if (_busy)
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: LinearProgressIndicator(),
        ),
      TextField(
        controller: _message,
        enabled: !_busy,
        minLines: 1,
        maxLines: 4,
        maxLength: 2000,
        textInputAction: TextInputAction.newline,
        decoration: InputDecoration(
          hintText: 'Votre demande…',
          suffixIcon: IconButton(
            tooltip: 'Envoyer la demande',
            onPressed: _busy || current == null ? null : _send,
            icon: const Icon(Icons.arrow_upward_rounded),
          ),
        ),
      ),
      const Text(
        'Des compositions à examiner. Aucun pari n’est placé. Le retour potentiel inclut la mise et n’est pas garanti.',
      ),
      if (widget.onLegacyTickets != null)
        TextButton(
          onPressed: widget.onLegacyTickets,
          child: const Text('Mes tickets et stratégies'),
        ),
    ];
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    return widget.embedded
        ? column
        : ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
            children: [column],
          );
  }

  Widget _ticket(Map<String, dynamic> ticket, {bool pending = false}) {
    final picks = generatorRows(ticket['picks']);
    final needsUpdate = picks.any((p) {
      final kickoff = DateTime.tryParse(p['kickoff']?.toString() ?? '');
      final oddsAt = DateTime.tryParse(p['oddsAt']?.toString() ?? '');
      final now = DateTime.now();
      return kickoff == null ||
          !kickoff.isAfter(now) ||
          oddsAt == null ||
          now.difference(oddsAt) > const Duration(hours: 48);
    });
    String money(String key) => NumberFormat.currency(
      locale: 'fr_FR',
      symbol: '€',
    ).format(ticket[key] ?? 0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: LectorMatchCardFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'TICKET ${ticket['number']}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text('${picks.length} sélection(s)'),
              ],
            ),
            const SizedBox(height: 8),
            if (needsUpdate)
              Text(
                'À actualiser · statut et cotes à revérifier',
                style: TextStyle(color: context.semantic.warning),
              ),
            Text(
              'Mise ${money('stake')} · Cote ${NumberFormat('0.00', 'fr').format(ticket['totalOdds'] ?? 0)}',
            ),
            Text('Retour potentiel ${money('returnTotal')}'),
            Text('Bénéfice net si gagnant ${money('netProfit')}'),
            const Divider(),
            for (final pick in picks.take(2))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${pick['home']} — ${pick['away']}'),
                    Text('${pick['selection']} · ${pick['odds']}'),
                  ],
                ),
              ),
            if (picks.length > 2)
              Text('+ ${picks.length - 2} autre(s) sélection(s)'),
            TextButton.icon(
              onPressed: () => _examine(ticket),
              icon: const Icon(Icons.chevron_right_rounded),
              label: const Text('Examiner ce ticket'),
            ),
          ],
        ),
      ),
    );
  }

  void _examine(Map<String, dynamic> ticket) {
    final picks = generatorRows(ticket['picks']);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .8,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Ticket ${ticket['number']} · détail',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              for (final entry in picks.indexed) ...[
                const SizedBox(height: 16),
                Text(
                  entry.$2['competition']?.toString() ?? '',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                LectorTeamLine(
                  name: entry.$2['home']?.toString() ?? '',
                  logoUrl: entry.$2['homeLogo']?.toString(),
                ),
                LectorTeamLine(
                  name: entry.$2['away']?.toString() ?? '',
                  logoUrl: entry.$2['awayLogo']?.toString(),
                ),
                const SizedBox(height: 8),
                Text('${entry.$2['selection']} · cote ${entry.$2['odds']}'),
                Text(
                  '${entry.$2['bookmaker']} · cote relevée ${entry.$2['oddsAt']}',
                ),
                const SizedBox(height: 8),
                const Text('POURQUOI CETTE SÉLECTION ?'),
                for (final evidence in generatorRows(entry.$2['evidence']))
                  Text('• ${evidence['text']}'),
                for (final warning in (entry.$2['warnings'] as List? ?? []))
                  Text(
                    warning.toString(),
                    style: TextStyle(color: context.semantic.warning),
                  ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    widget.onOpenMatch(entry.$2);
                  },
                  child: const Text('Voir les données du match'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _message.text =
                        'Remplace uniquement la sélection ${entry.$1 + 1} du ticket ${ticket['number']}. Conserve le reste.';
                  },
                  child: const Text('Remplacer cette sélection'),
                ),
                const Divider(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
