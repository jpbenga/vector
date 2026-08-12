import '../../matches/domain/match_board_item.dart';
import 'saved_ticket.dart';

class TicketSettlementEngine {
  const TicketSettlementEngine();

  List<SavedTicket> settleTickets({
    required List<SavedTicket> tickets,
    required List<MatchBoardItem> matches,
    DateTime? checkedAt,
  }) {
    final matchesById = {
      for (final match in matches) match.id: match,
      for (final match in matches)
        if (match.fixture.apiFootballFixtureId != null)
          match.fixture.apiFootballFixtureId.toString(): match,
    };
    final timestamp = checkedAt?.toUtc() ?? DateTime.now().toUtc();

    var changed = false;
    final settled = [
      for (final ticket in tickets)
        _settleTicket(
          ticket: ticket,
          matchesById: matchesById,
          checkedAt: timestamp,
          onChanged: () => changed = true,
        ),
    ];

    return changed ? settled : tickets;
  }

  SavedTicket _settleTicket({
    required SavedTicket ticket,
    required Map<String, MatchBoardItem> matchesById,
    required DateTime checkedAt,
    required VoidCallback onChanged,
  }) {
    if (ticket.status != SavedTicketStatus.played ||
        ticket.selections.isEmpty) {
      return ticket;
    }

    var hasPendingSelection = false;
    for (final selection in ticket.selections) {
      final match = matchesById[selection.matchId];
      final result = match == null
          ? _SelectionSettlement.pending
          : _settleSelection(selection, match);

      if (result == _SelectionSettlement.lost) {
        onChanged();
        return ticket.copyWith(
          status: SavedTicketStatus.lost,
          updatedAt: checkedAt,
        );
      }

      if (result == _SelectionSettlement.pending) {
        hasPendingSelection = true;
      }
    }

    if (hasPendingSelection) {
      return ticket;
    }

    onChanged();
    return ticket.copyWith(status: SavedTicketStatus.won, updatedAt: checkedAt);
  }

  _SelectionSettlement _settleSelection(
    SavedTicketSelection selection,
    MatchBoardItem match,
  ) {
    final score = match.fixture.score;
    if (match.fixture.status != FixtureStatus.finished || score == null) {
      return _SelectionSettlement.pending;
    }

    final marketId = _normalizedId(selection.marketId);
    final selectionText = [
      selection.selectionId,
      selection.selectionLabel,
    ].join(' ').toLowerCase();

    if (marketId == 'matchresult' || marketId == '1n2') {
      final selectedSide = _threeWaySide(selection, match);
      final actualSide = _matchResultSide(score);
      if (selectedSide == null) {
        return _SelectionSettlement.pending;
      }
      return selectedSide == actualSide
          ? _SelectionSettlement.won
          : _SelectionSettlement.lost;
    }

    if (marketId == 'doublechance') {
      final selectedSides = _doubleChanceSides(selectionText);
      final actualSide = _matchResultSide(score);
      if (selectedSides.isEmpty) {
        return _SelectionSettlement.pending;
      }
      return selectedSides.contains(actualSide)
          ? _SelectionSettlement.won
          : _SelectionSettlement.lost;
    }

    if (marketId == 'bothteamsscore' || marketId == 'btts') {
      final selectedYes = _yesNo(selectionText);
      if (selectedYes == null) {
        return _SelectionSettlement.pending;
      }
      final bothScored = score.home > 0 && score.away > 0;
      return selectedYes == bothScored
          ? _SelectionSettlement.won
          : _SelectionSettlement.lost;
    }

    if (_isGoalsTotalMarket(marketId)) {
      return _settleTotalGoals(selectionText, score.home + score.away);
    }

    if (_isHomeTeamTotalMarket(marketId)) {
      return _settleTotalGoals(selectionText, score.home);
    }

    if (_isAwayTeamTotalMarket(marketId)) {
      return _settleTotalGoals(selectionText, score.away);
    }

    return _SelectionSettlement.pending;
  }

  _MatchResultSide _matchResultSide(FixtureScore score) {
    if (score.home > score.away) {
      return _MatchResultSide.home;
    }
    if (score.home < score.away) {
      return _MatchResultSide.away;
    }
    return _MatchResultSide.draw;
  }

  _MatchResultSide? _threeWaySide(
    SavedTicketSelection selection,
    MatchBoardItem match,
  ) {
    final id = selection.selectionId.toLowerCase();
    final label = selection.selectionLabel.trim().toLowerCase();
    final homeName = match.homeTeam.name.toLowerCase();
    final awayName = match.awayTeam.name.toLowerCase();

    if (_containsToken(id, 'home') ||
        label == '1' ||
        label == 'domicile' ||
        label == homeName) {
      return _MatchResultSide.home;
    }
    if (_containsToken(id, 'draw') ||
        label == 'n' ||
        label == 'x' ||
        label == 'nul') {
      return _MatchResultSide.draw;
    }
    if (_containsToken(id, 'away') ||
        label == '2' ||
        label == 'extérieur' ||
        label == 'exterieur' ||
        label == awayName) {
      return _MatchResultSide.away;
    }

    return null;
  }

  Set<_MatchResultSide> _doubleChanceSides(String text) {
    final normalized = text
        .replaceAll('/', '')
        .replaceAll('-', '')
        .replaceAll(' ', '')
        .replaceAll(':', '');

    if (normalized.contains('1x') ||
        (text.contains('home') && text.contains('draw'))) {
      return {_MatchResultSide.home, _MatchResultSide.draw};
    }
    if (normalized.contains('12') ||
        (text.contains('home') && text.contains('away'))) {
      return {_MatchResultSide.home, _MatchResultSide.away};
    }
    if (normalized.contains('x2') ||
        (text.contains('draw') && text.contains('away'))) {
      return {_MatchResultSide.draw, _MatchResultSide.away};
    }

    return const {};
  }

  bool? _yesNo(String text) {
    if (text.contains('yes') || text.contains('oui')) {
      return true;
    }
    if (text.contains('no') || text.contains('non')) {
      return false;
    }
    return null;
  }

  _SelectionSettlement _settleTotalGoals(String text, int goals) {
    final line = _lineValue(text);
    final side = _overUnderSide(text);
    if (line == null || side == null) {
      return _SelectionSettlement.pending;
    }
    if (goals == line) {
      return _SelectionSettlement.pending;
    }

    final isWon = side == _OverUnderSide.over ? goals > line : goals < line;
    return isWon ? _SelectionSettlement.won : _SelectionSettlement.lost;
  }

  double? _lineValue(String text) {
    final match = RegExp(
      r'([0-9]+(?:[\.,][0-9]+)?)',
    ).firstMatch(text.replaceAll(':', ' '));
    if (match == null) {
      return null;
    }
    return double.tryParse(match.group(1)!.replaceAll(',', '.'));
  }

  _OverUnderSide? _overUnderSide(String text) {
    if (text.contains('over') || text.contains('plus') || text.contains('+')) {
      return _OverUnderSide.over;
    }
    if (text.contains('under') ||
        text.contains('moins') ||
        text.contains('-')) {
      return _OverUnderSide.under;
    }
    return null;
  }

  bool _isGoalsTotalMarket(String marketId) {
    return marketId == 'goalstotal' ||
        marketId == 'goaltotal' ||
        marketId == 'overundergoals' ||
        marketId == 'overunder';
  }

  bool _isHomeTeamTotalMarket(String marketId) {
    return marketId == 'teamtotalhome' || marketId == 'hometeamtotal';
  }

  bool _isAwayTeamTotalMarket(String marketId) {
    return marketId == 'teamtotalaway' || marketId == 'awayteamtotal';
  }

  bool _containsToken(String value, String token) {
    return value == token ||
        value.startsWith('$token:') ||
        value.contains(':$token') ||
        value.contains('_$token') ||
        value.contains('${token}_');
  }

  String _normalizedId(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }
}

typedef VoidCallback = void Function();

enum _SelectionSettlement { won, lost, pending }

enum _MatchResultSide { home, draw, away }

enum _OverUnderSide { over, under }
