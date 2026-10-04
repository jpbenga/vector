import 'sport.dart';
import 'sport_fixture.dart';

/// Market identity includes its settlement scope. Two-way final moneyline and
/// three-way regulation results cannot share an ID or substitute their odds.
class SportMarketQuote {
  SportMarketQuote({
    required this.match,
    required this.marketCode,
    required this.selectionCode,
    required this.scope,
    required this.bookmaker,
    required this.decimalOdds,
    required this.capturedAt,
    this.line,
  }) {
    if (match.kind != SportEntityKind.match ||
        marketCode.trim().isEmpty ||
        selectionCode.trim().isEmpty ||
        scope.key.trim().isEmpty ||
        bookmaker.trim().isEmpty ||
        !decimalOdds.isFinite ||
        decimalOdds <= 1 ||
        (line != null && !line!.isFinite)) {
      throw ArgumentError(
        'Market quotes need an explicit identity, scope and valid decimal odds.',
      );
    }
  }
  final SportEntityId match;
  final String marketCode;
  final String selectionCode;
  final SportScoreScope scope;
  final String bookmaker;
  final double decimalOdds;
  final DateTime capturedAt;
  final double? line;

  String get selectionKey => [
    match.key,
    marketCode,
    scope.key,
    line?.toString() ?? '',
    selectionCode,
  ].map(Uri.encodeComponent).join(':');
}
