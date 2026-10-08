import 'package:intl/intl.dart';
import '../domain/generator_context.dart';

String generatorMoney(Object? amount) =>
    NumberFormat.currency(locale: 'fr_FR', symbol: '€').format(amount ?? 0);
String generatorOdds(Object? amount) =>
    NumberFormat('0.00', 'fr').format(amount ?? 0);
String generatorKickoff(Map<String, dynamic> pick) {
  final date = DateTime.tryParse(pick['kickoff']?.toString() ?? '')?.toLocal();
  return date == null ? '' : DateFormat('EEE d · HH:mm', 'fr').format(date);
}

List<Map<String, dynamic>> generatorEvidence(
  Map<String, dynamic> pick,
  String source,
) => generatorRows(
  pick['evidence'],
).where((e) => e['source'] == source && e['reusesReading'] != true).toList();
