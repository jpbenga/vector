import 'package:flutter/material.dart';
import '../../../app/sports/generator_match_navigation.dart';
import '../../../core/identity/identity_scope.dart';
import '../../generator/domain/generator_context.dart';
import '../../generator/presentation/lector_generator_page.dart';
import '../application/shortlist_controller.dart';

class ShortlistConversationPage extends StatefulWidget {
  const ShortlistConversationPage({
    required this.controller,
    required this.keys,
    this.prompt,
    super.key,
  });
  final ShortlistController controller;
  final List<String> keys;
  final String? prompt;
  @override
  State<ShortlistConversationPage> createState() =>
      _ShortlistConversationPageState();
}

class _ShortlistConversationPageState extends State<ShortlistConversationPage> {
  late final String? _account = widget.controller.account;
  late final String? _session = widget.controller.active?.id;
  late final DateTime _date =
      widget.controller.items
          .where(
            (f) =>
                widget.keys.contains(f.key) &&
                f.phase(widget.controller.now) == 'upcoming',
          )
          .map((f) => f.kickoff?.toLocal())
          .whereType<DateTime>()
          .firstOrNull ??
      widget.controller.now.toLocal();
  bool get _available =>
      _account != null &&
      _account == widget.controller.account &&
      _session != null &&
      _session == widget.controller.active?.id;

  Future<GeneratorContext> _context() async {
    if (!_available) throw StateError('Cette préparation n’est plus active.');
    await widget.controller.refresh();
    if (!_available) throw StateError('Cette préparation n’est plus active.');
    final session = widget.controller.active!;
    final chosen = widget.keys.where(widget.controller.contains).toList();
    if (chosen.isEmpty) {
      throw StateError('Les rencontres sélectionnées ont été retirées.');
    }
    return GeneratorContext(
      origin: 'profile',
      shortlist: session.reference(chosen),
      preferences: {
        for (final sport
            in widget.controller.items
                .where((f) => chosen.contains(f.key))
                .map((f) => f.sport)
                .toSet())
          sport: {'competitions': [], 'readings': [], 'markets': []},
      },
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Préparer avec Lector')),
    body: ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => !_available
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Cette préparation n’est plus active. Retrouvez ou restaurez votre Shortlist pour continuer.',
                ),
              ),
            )
          : LectorGeneratorPage(
              date: _date,
              scope: IdentityScope.account(_account!),
              workspaceKey: 'shortlist:$_session',
              initialPrompt: widget.prompt,
              configurationKey: widget.controller.active!.revision.toString(),
              loadContext: _context,
              onOpenMatch: (pick) => openGeneratorMatch(context, pick),
            ),
    ),
  );
}
