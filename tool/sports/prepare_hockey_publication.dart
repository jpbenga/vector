import 'dart:convert';
import 'dart:io';
import 'package:copilot/features/hockey/domain/hockey_publication_readings.dart';

void main(List<String> args) {
  if (args.length != 2) {
    throw ArgumentError('Source and destination publication paths required');
  }
  final value = withHockeyPublicationReadings(
    jsonDecode(File(args[0]).readAsStringSync()) as Map<String, dynamic>,
  );
  File(args[1]).writeAsStringSync(jsonEncode(value));
  stdout.writeln(
    jsonEncode({
      'sport': value['sport'],
      'capturedAt': value['capturedAt'],
      'readingRulesVersion': value['readingRulesVersion'],
      'matches': (value['items'] as List).length,
    }),
  );
}
