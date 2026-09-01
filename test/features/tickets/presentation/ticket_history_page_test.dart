import 'package:copilot/core/theme/app_theme.dart';
import 'package:copilot/features/tickets/domain/saved_ticket.dart';
import 'package:copilot/features/tickets/presentation/ticket_history_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('TicketHistoryPage renders KPIs, timeline and source filters', (
    tester,
  ) async {
    await _pumpHistory(tester);

    expect(find.text('Historique & performances'), findsOneWidget);
    expect(find.byTooltip('Fermer'), findsOneWidget);
    expect(find.text('Exporter'), findsNothing);
    expect(find.text('7 jours'), findsOneWidget);
    expect(find.text('Tickets'), findsOneWidget);
    expect(find.text('Joués'), findsOneWidget);
    expect(find.text('Gagnés'), findsWidgets);
    expect(find.text('Perdus'), findsWidgets);
    expect(find.text('Mise totale'), findsOneWidget);
    expect(find.text('Ticket Lector'), findsOneWidget);
    expect(find.text('Ticket manuel'), findsWidgets);
    expect(find.text('Lecture principale : Favori solide'), findsOneWidget);
    expect(find.text('Créé manuellement'), findsOneWidget);

    await tester.tap(find.text('Manuels'));
    await tester.pumpAndSettle();

    expect(find.text('Ticket manuel'), findsWidgets);
    expect(find.text('Ticket Lector'), findsNothing);

    await tester.tap(find.text('Modifiés'));
    await tester.pumpAndSettle();

    expect(find.text('Aucun ticket modifié'), findsOneWidget);
  });

  testWidgets('TicketHistoryPage updates status, opens details and deletes', (
    tester,
  ) async {
    SavedTicket? changedTicket;
    String? deletedTicketId;

    await _pumpHistory(
      tester,
      onTicketChanged: (ticket) => changedTicket = ticket,
      onTicketDeleted: (ticketId) => deletedTicketId = ticketId,
    );

    await tester.tap(find.byTooltip('Actions du ticket').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marquer gagné'));
    await tester.pumpAndSettle();

    expect(changedTicket?.status, SavedTicketStatus.won);
    expect(find.text('GAGNÉ'), findsOneWidget);

    await tester.tap(find.byTooltip('Actions du ticket').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voir le détail'));
    await tester.pumpAndSettle();

    expect(find.text('Statut : Gagné'), findsOneWidget);
    await tester.tap(find.byTooltip('Fermer').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Actions du ticket').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(changedTicket?.status, SavedTicketStatus.cancelled);
    expect(find.text('ANNULÉ'), findsOneWidget);

    await tester.tap(find.byTooltip('Actions du ticket').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer').last);
    await tester.pumpAndSettle();

    expect(deletedTicketId, 'copilot-1');
    expect(find.text('Ticket Lector'), findsNothing);
  });

  testWidgets(
    'TicketHistoryPage declares played tickets with real tracking data',
    (tester) async {
      SavedTicket? changedTicket;

      await _pumpHistory(
        tester,
        onTicketChanged: (ticket) => changedTicket = ticket,
      );

      await tester.tap(find.byTooltip('Actions du ticket').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Déclarer joué'));
      await tester.pumpAndSettle();

      expect(find.text('Déclarer le ticket joué'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Bookmaker'),
        'Betclic',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Mise réelle'),
        '25,50',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Cote réelle obtenue'),
        '1.40',
      );
      await tester.tap(find.text('Enregistrer comme joué'));
      await tester.pumpAndSettle();

      expect(changedTicket?.status, SavedTicketStatus.played);
      expect(changedTicket?.playedDeclaration?.bookmaker, 'Betclic');
      expect(changedTicket?.playedDeclaration?.stake, 25.5);
      expect(changedTicket?.playedDeclaration?.actualTotalOdds, 1.4);
      expect(find.text('EN ATTENTE'), findsOneWidget);
      expect(find.textContaining('Joué : Betclic'), findsOneWidget);

      await tester.tap(find.byTooltip('Actions du ticket').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Marquer non joué'));
      await tester.pumpAndSettle();

      expect(changedTicket?.status, SavedTicketStatus.saved);
      expect(changedTicket?.playedDeclaration, isNull);
      expect(find.text('NON JOUÉ'), findsWidgets);
    },
  );

  testWidgets(
    'TicketHistoryPage filters by period and status with local KPIs',
    (tester) async {
      final now = DateTime.now();

      await _pumpHistory(
        tester,
        savedTickets: [
          _ticket(
            id: 'saved',
            name: 'Ticket non joué',
            source: SavedTicketSource.copilot,
            status: SavedTicketStatus.saved,
            createdAt: now,
          ),
          _ticket(
            id: 'pending',
            name: 'Ticket en attente',
            source: SavedTicketSource.manual,
            status: SavedTicketStatus.played,
            createdAt: now.subtract(const Duration(hours: 2)),
            stake: 15,
          ),
          _ticket(
            id: 'won',
            name: 'Ticket gagné',
            source: SavedTicketSource.copilot,
            status: SavedTicketStatus.won,
            createdAt: now.subtract(const Duration(days: 1)),
            stake: 10,
          ),
          _ticket(
            id: 'lost',
            name: 'Ticket perdu',
            source: SavedTicketSource.copilotModified,
            status: SavedTicketStatus.lost,
            createdAt: now.subtract(const Duration(days: 2)),
          ),
          _ticket(
            id: 'cancelled',
            name: 'Ticket annulé',
            source: SavedTicketSource.manual,
            status: SavedTicketStatus.cancelled,
            createdAt: now.subtract(const Duration(days: 3)),
          ),
          _ticket(
            id: 'old',
            name: 'Ticket ancien',
            source: SavedTicketSource.copilot,
            status: SavedTicketStatus.won,
            createdAt: now.subtract(const Duration(days: 10)),
          ),
        ],
      );

      expect(find.text('Ticket ancien'), findsNothing);
      expect(find.text('25,00 €'), findsOneWidget);
      expect(find.text('Statut'), findsOneWidget);
      expect(find.text('Tous statuts'), findsOneWidget);

      await tester.ensureVisible(find.text('Tout'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tout'));
      await tester.pumpAndSettle();

      expect(find.text('Ticket ancien'), findsOneWidget);

      await tester.ensureVisible(find.text('Annulés'));
      await tester.tap(find.text('Annulés'));
      await tester.pumpAndSettle();

      expect(find.text('Ticket annulé'), findsOneWidget);
      expect(find.text('Ticket gagné'), findsNothing);

      await tester.ensureVisible(find.text('Gagnés').last);
      await tester.tap(find.text('Gagnés').last);
      await tester.pumpAndSettle();

      expect(find.text('Ticket gagné'), findsOneWidget);
      expect(find.text('Ticket ancien'), findsOneWidget);
      expect(find.text('Ticket annulé'), findsNothing);

      await tester.ensureVisible(find.text('En attente'));
      await tester.tap(find.text('En attente'));
      await tester.pumpAndSettle();

      expect(find.text('Ticket en attente'), findsOneWidget);
      expect(find.text('Ticket gagné'), findsNothing);
    },
  );
}

Future<void> _pumpHistory(
  WidgetTester tester, {
  List<SavedTicket>? savedTickets,
  ValueChanged<SavedTicket>? onTicketChanged,
  ValueChanged<String>? onTicketDeleted,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final now = DateTime.now();

  await tester.pumpWidget(
    MaterialApp(
      theme: CopilotTheme.dark.copyWith(splashFactory: NoSplash.splashFactory),
      home: TicketHistoryPage(
        savedTickets:
            savedTickets ??
            [
              SavedTicket(
                schemaVersion: SavedTicket.currentSchemaVersion,
                id: 'copilot-1',
                source: SavedTicketSource.copilot,
                status: SavedTicketStatus.saved,
                createdAt: now,
                updatedAt: now,
                name: 'Ticket Lector',
                strategyName: 'Prudente',
                mainCombinedReadingLabel: 'Favori solide',
                totalOdds: 1.42,
                selections: const [
                  SavedTicketSelection(
                    id: 'selection-copilot-1',
                    matchId: 'match-1',
                    homeTeam: 'Arsenal',
                    awayTeam: 'Tottenham',
                    homeLogoUrl: null,
                    awayLogoUrl: null,
                    competitionName: 'Premier League',
                    marketId: 'doubleChance',
                    marketLabel: 'Double chance',
                    selectionId: '1x',
                    selectionLabel: '1X',
                    odds: 1.42,
                  ),
                ],
              ),
              SavedTicket(
                schemaVersion: SavedTicket.currentSchemaVersion,
                id: 'manual-1',
                source: SavedTicketSource.manual,
                status: SavedTicketStatus.saved,
                createdAt: now.subtract(const Duration(hours: 1)),
                updatedAt: now.subtract(const Duration(hours: 1)),
                name: 'Ticket manuel',
                totalOdds: 1.58,
                selections: const [
                  SavedTicketSelection(
                    id: 'selection-1',
                    matchId: 'manual-match-1',
                    homeTeam: 'Milan',
                    awayTeam: 'Bologna',
                    homeLogoUrl: null,
                    awayLogoUrl: null,
                    competitionName: 'Serie A',
                    marketId: 'btts',
                    marketLabel: 'But pour les deux équipes',
                    selectionId: 'yes',
                    selectionLabel: 'Yes',
                    odds: 1.58,
                  ),
                ],
              ),
            ],
        onTicketChanged: onTicketChanged ?? (_) {},
        onTicketDeleted: onTicketDeleted ?? (_) {},
        onClose: () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

SavedTicket _ticket({
  required String id,
  required String name,
  required SavedTicketSource source,
  required SavedTicketStatus status,
  required DateTime createdAt,
  double? stake,
}) {
  return SavedTicket(
    schemaVersion: SavedTicket.currentSchemaVersion,
    id: id,
    source: source,
    status: status,
    createdAt: createdAt,
    updatedAt: createdAt,
    name: name,
    strategyName: source == SavedTicketSource.manual ? null : 'Prudente',
    mainCombinedReadingLabel: 'Favori solide',
    plannedStake: stake,
    playedDeclaration: stake == null
        ? null
        : SavedTicketPlayDeclaration(
            bookmaker: 'Betclic',
            stake: stake,
            actualTotalOdds: null,
            playedAt: createdAt,
          ),
    totalOdds: 1.42,
    selections: [
      SavedTicketSelection(
        id: 'selection-$id',
        matchId: 'match-$id',
        homeTeam: 'Arsenal',
        awayTeam: 'Tottenham',
        competitionName: 'Premier League',
        marketId: 'doubleChance',
        marketLabel: 'Double chance',
        selectionId: '1x',
        selectionLabel: '1X',
        odds: 1.42,
      ),
    ],
    modificationSummary: source == SavedTicketSource.copilotModified
        ? '1 marché remplacé'
        : null,
    modificationDetails: source == SavedTicketSource.copilotModified
        ? const ['Marché remplacé : Arsenal - Tottenham']
        : const [],
  );
}
