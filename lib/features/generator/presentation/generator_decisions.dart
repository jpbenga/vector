import 'package:flutter/material.dart';
import '../../../core/identity/identity_scope.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/supabase/supabase_initializer.dart';
import '../../../core/theme/app_components.dart';
import '../../../core/widgets/lector_match_card.dart';
import '../data/generator_repository.dart';
import '../domain/generator_context.dart';
import 'generator_ticket_card.dart';

/// Feedback, tracking and a declared bet are independent server-owned fields.
class GeneratorDecisionActions extends StatefulWidget {
  const GeneratorDecisionActions({
    required this.onChoice,
    this.initial = const {},
    super.key,
  });
  final Future<Map<String, dynamic>> Function(String) onChoice;
  final Map<String, dynamic> initial;
  @override
  State<GeneratorDecisionActions> createState() =>
      _GeneratorDecisionActionsState();
}

class _GeneratorDecisionActionsState extends State<GeneratorDecisionActions> {
  Map<String, dynamic>? _value;
  bool _busy = false;
  String? _error;
  Future<void> _choose(String choice) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final value = await widget.onChoice(choice);
      if (mounted) setState(() => _value = value);
    } on Object {
      if (mounted) setState(() => _error = 'L’enregistrement n’a pas abouti.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = _value ?? widget.initial;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            OutlinedButton.icon(
              onPressed: _busy || value['relevant'] == true
                  ? null
                  : () => _choose('relevant'),
              icon: Icon(
                value['relevant'] == true
                    ? Icons.thumb_up
                    : Icons.thumb_up_outlined,
                size: 18,
              ),
              label: Text(
                value['relevant'] == true ? 'Jugée pertinente' : 'Pertinente',
              ),
            ),
            OutlinedButton.icon(
              onPressed: _busy || value['followed_at'] != null
                  ? null
                  : () => _choose('follow'),
              icon: Icon(
                value['followed_at'] != null
                    ? Icons.check_circle_outline
                    : Icons.bookmark_add_outlined,
                size: 18,
              ),
              label: Text(
                value['followed_at'] != null
                    ? 'Sélection suivie'
                    : 'Suivre cette sélection',
              ),
            ),
          ],
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          Text(_error!, style: TextStyle(color: context.semantic.warning)),
      ],
    );
  }
}

class GeneratorBilanSection extends StatefulWidget {
  const GeneratorBilanSection({
    required this.scope,
    required this.readings,
    this.repository,
    super.key,
  });
  final IdentityScope scope;
  final Widget readings;
  final GeneratorRepository? repository;
  @override
  State<GeneratorBilanSection> createState() => _GeneratorBilanSectionState();
}

class _GeneratorBilanSectionState extends State<GeneratorBilanSection> {
  bool _followups = false;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(
            value: false,
            label: Text('Lectures'),
            icon: Icon(Icons.menu_book_outlined),
          ),
          ButtonSegment(
            value: true,
            label: Text('Mes suivis'),
            icon: Icon(Icons.bookmarks_outlined),
          ),
        ],
        selected: {_followups},
        onSelectionChanged: (value) => setState(() => _followups = value.first),
      ),
      const SizedBox(height: 16),
      if (_followups)
        GeneratorFollowups(scope: widget.scope, repository: widget.repository)
      else
        widget.readings,
    ],
  );
}

class GeneratorFollowups extends StatefulWidget {
  const GeneratorFollowups({required this.scope, this.repository, super.key});
  final IdentityScope scope;
  final GeneratorRepository? repository;
  @override
  State<GeneratorFollowups> createState() => _GeneratorFollowupsState();
}

class _GeneratorFollowupsState extends State<GeneratorFollowups> {
  List<Map<String, dynamic>>? _rows;
  String? _error;
  int _page = 0, _generation = 0;
  bool _hasMore = false, _loadingMore = false;
  Map<String, dynamic> _counts = {};
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
    _load();
  }

  @override
  void didUpdateWidget(covariant GeneratorFollowups oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scope != widget.scope) {
      _rows = null;
      _page = 0;
      _load();
    }
  }

  Future<void> _load({bool more = false}) async {
    final generation = ++_generation;
    if (!widget.scope.isAccount || _repository == null) return;
    try {
      if (more) setState(() => _loadingMore = true);
      final result = await _repository!.request({
        'action': 'decisions',
        'offset': more ? _rows?.length ?? 0 : 0,
      });
      if (mounted && generation == _generation) {
        setState(() {
          _rows = [
            ...(more
                ? _rows ?? <Map<String, dynamic>>[]
                : <Map<String, dynamic>>[]),
            ...generatorRows(result['decisions']),
          ];
          _hasMore = result['hasMore'] == true;
          _counts = generatorMap(result['counts']);
          _loadingMore = false;
          _page = more ? _page : 0;
          _error = null;
        });
      }
    } on Object {
      if (mounted && generation == _generation) {
        setState(() => _error = 'Vos suivis sont momentanément indisponibles.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.scope.isAccount) {
      return const Text(
        'Connectez-vous pour retrouver vos tickets et sélections suivies.',
      );
    }
    if (_rows == null && _error == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Column(
        children: [
          Text(_error!),
          TextButton(onPressed: _load, child: const Text('Actualiser')),
        ],
      );
    }
    final rows = _rows!;
    final tickets =
        (_counts['tickets'] as num?)?.toInt() ??
        rows
            .where((r) => r['saved_at'] != null && r['kind'] == 'ticket')
            .length;
    final followed =
        (_counts['followed'] as num?)?.toInt() ??
        rows
            .where((r) => r['followed_at'] != null && r['kind'] == 'selection')
            .length;
    final feedback =
        (_counts['feedback'] as num?)?.toInt() ??
        rows
            .where(
              (r) =>
                  r['relevant'] == true &&
                  r['followed_at'] == null &&
                  r['saved_at'] == null,
            )
            .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Mes suivis',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            IconButton(
              tooltip: 'Actualiser les résultats',
              onPressed: _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        Text('$followed sélections suivies · $tickets tickets enregistrés'),
        if (feedback > 0)
          Text('$feedback propositions jugées pertinentes, sans suivi.'),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          const LectorMatchCardFrame(
            child: Text(
              'Enregistrez un ticket ou suivez une sélection depuis le Générateur. Ils resteront ici après l’expiration de la conversation.',
            ),
          ),
        for (final row in rows.skip(_page * 10).take(10))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _DecisionCard(
              row: row,
              onOpen: () async {
                await showGeneratorSavedDecision(
                  context,
                  row: row,
                  repository: _repository!,
                );
                if (mounted) _load();
              },
            ),
          ),
        if (rows.length > 10)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('${_page + 1}/${(rows.length / 10).ceil()}'),
              IconButton(
                onPressed: _page > 0 ? () => setState(() => _page--) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                onPressed: (_page + 1) * 10 < rows.length
                    ? () => setState(() => _page++)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        if (_hasMore)
          TextButton(
            onPressed: _loadingMore ? null : () => _load(more: true),
            child: Text(
              _loadingMore
                  ? 'Chargement…'
                  : 'Afficher les éléments plus anciens',
            ),
          ),
        const SizedBox(height: 10),
        Text(
          'Les résultats des sélections sont distincts de la confirmation des lectures. Les cotes affichées sont celles de la sauvegarde ; aucun gain réellement encaissé n’est déduit.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

String generatorVerdict(Object? value) => switch (value) {
  'won' => 'Gagnante',
  'lost' => 'Perdante',
  'void' => 'Annulée',
  'push' => 'Remboursée',
  'unverifiable' => 'Non vérifiable',
  _ => 'En attente',
};

class _DecisionCard extends StatelessWidget {
  const _DecisionCard({required this.row, required this.onOpen});
  final Map<String, dynamic> row;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    final snapshot = generatorMap(row['snapshot']),
        picks = generatorRows(snapshot['picks']);
    final result = generatorMap(row['result']);
    final tracked =
        row['saved_at'] != null ||
        row['followed_at'] != null ||
        row['played_at'] != null;
    final verified = generatorRows(
      result['picks'],
    ).where((p) => p['status'] != 'pending').length;
    return LectorMatchCardFrame(
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    row['kind'] == 'ticket'
                        ? Icons.receipt_long_outlined
                        : Icons.bookmark_outline,
                    color: context.brand.accent,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      row['kind'] == 'ticket'
                          ? 'Ticket ${snapshot['number']} · ${picks.length} sélections'
                          : '${picks.firstOrNull?['home']} — ${picks.firstOrNull?['away']}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 8),
              if (row['kind'] == 'selection')
                Text(
                  '${picks.firstOrNull?['selection']} · ${generatorOdds(picks.firstOrNull?['odds'])}',
                ),
              Text(
                tracked
                    ? '${generatorVerdict(result['status'])} · $verified/${picks.length} vérifiées'
                    : 'Jugée pertinente · sans suivi',
              ),
              if (row['played_at'] != null)
                const Text('Pari déclaré placé par vous'),
              if (row['supersedes'] != null)
                const Text('Nouvelle version · état antérieur conservé'),
              Text(
                'Conservé le ${_date(row['created_at'])}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _date(Object? date) {
  final value = DateTime.tryParse(date?.toString() ?? '')?.toLocal();
  return value == null
      ? '—'
      : '${value.day}/${value.month}/${value.year} à ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

Future<void> showGeneratorSavedDecision(
  BuildContext context, {
  required Map<String, dynamic> row,
  required GeneratorRepository repository,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: context.surfaces.backgroundSecondary,
  builder: (_) => _SavedDecisionDetail(row: row, repository: repository),
);

class _SavedDecisionDetail extends StatefulWidget {
  const _SavedDecisionDetail({required this.row, required this.repository});
  final Map<String, dynamic> row;
  final GeneratorRepository repository;
  @override
  State<_SavedDecisionDetail> createState() => _SavedDecisionDetailState();
}

class _SavedDecisionDetailState extends State<_SavedDecisionDetail> {
  late Map<String, dynamic> _row = widget.row;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    if (_row['summaryOnly'] == true) _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _busy = true);
    try {
      final result = await widget.repository.request({
        'action': 'decision',
        'decisionId': _row['id'],
      });
      if (mounted) setState(() => _row = generatorMap(result['decision']));
    } on Object {
      if (mounted) setState(() => _error = 'Le détail n’a pas pu être chargé.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _action(String action) async {
    if (action == 'played' || action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(
            action == 'played'
                ? 'Déclarer un pari placé ?'
                : 'Supprimer cet élément ?',
          ),
          content: Text(
            action == 'played'
                ? 'Vous confirmez avoir placé ce pari auprès d’un bookmaker. Lector n’effectue aucune mise et ne déduit aucun gain réel.'
                : 'Le snapshot et son historique de suivi seront supprimés de votre compte.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Confirmer'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await widget.repository.request({
        'action': 'decision_action',
        'decisionId': _row['id'],
        'choice': action,
      });
      if (!mounted) return;
      if (action == 'delete') {
        Navigator.pop(context);
        return;
      }
      setState(() => _row = generatorMap(response['decision']));
    } on Object {
      if (mounted) setState(() => _error = 'La modification n’a pas abouti.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_row['summaryOnly'] == true) {
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * .5,
        child: Center(
          child: _busy
              ? const CircularProgressIndicator()
              : Text(_error ?? 'Détail indisponible'),
        ),
      );
    }
    final snapshot = generatorMap(_row['snapshot']),
        picks = generatorRows(snapshot['picks']);
    final result = generatorMap(_row['result']);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .88,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _row['kind'] == 'ticket'
                      ? 'Ticket enregistré'
                      : 'Sélection conservée',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Fermer',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Text('Snapshot original · ${_date(_row['created_at'])}'),
          if (_row['kind'] == 'ticket') ...[
            const SizedBox(height: 12),
            LectorTicketSummary(ticket: snapshot),
          ],
          const SizedBox(height: 12),
          for (final pick in picks)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LectorMatchCardFrame(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${pick['competition']} · ${_date(pick['kickoff'])}'),
                    const SizedBox(height: 8),
                    Text(
                      '${pick['home']} — ${pick['away']}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${pick['selection']} · cote initiale ${generatorOdds(pick['odds'])}',
                    ),
                    Text(
                      '${pick['bookmaker']} · relevée le ${_date(pick['oddsAt'])}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const Divider(),
                    for (final verdict in generatorRows(
                      result['picks'],
                    ).where((r) => r['selectionId'] == pick['id'])) ...[
                      Text(
                        generatorVerdict(verdict['status']),
                        style: TextStyle(
                          color: verdict['status'] == 'won'
                              ? context.brand.accent
                              : null,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text('${verdict['reason']}'),
                      if (verdict['homeGoals'] != null)
                        Text(
                          'Score réglementaire : ${verdict['homeGoals']} — ${verdict['awayGoals']}',
                        ),
                    ],
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Arguments conservés'),
                      children: [GeneratorSelectionEvidence(pick: pick)],
                    ),
                  ],
                ),
              ),
            ),
          if (generatorMap(snapshot['analysis'])['text'] != null)
            Text('${generatorMap(snapshot['analysis'])['text']}'),
          Text(
            'Contexte initial : ${generatorMap(snapshot['context'])['origin'] == 'explorer' ? 'Explorateur' : 'Profil'}',
          ),
          const SizedBox(height: 12),
          Text(
            _row['played_at'] == null
                ? 'Cet élément est conservé ou suivi. Aucun pari placé n’est supposé.'
                : 'Vous avez déclaré ce pari placé le ${_date(_row['played_at'])}. Son règlement réel n’est pas confirmé.',
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _action(
                        _row['played_at'] == null ? 'played' : 'unplayed',
                      ),
                icon: const Icon(Icons.edit_note),
                label: Text(
                  _row['played_at'] == null
                      ? 'J’ai placé ce pari'
                      : 'Retirer ma déclaration',
                ),
              ),
              if (_row['followed_at'] != null)
                TextButton(
                  onPressed: _busy ? null : () => _action('unfollow'),
                  child: const Text('Ne plus suivre'),
                ),
              if (_row['relevant'] == true)
                TextButton(
                  onPressed: _busy ? null : () => _action('irrelevant'),
                  child: const Text('Retirer la pertinence'),
                ),
              TextButton.icon(
                onPressed: _busy ? null : () => _action('delete'),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Supprimer'),
              ),
            ],
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null) Text(_error!),
        ],
      ),
    );
  }
}
