import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final file = File('.env');
  final env = <String, String>{};
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#') || !trimmed.contains('=')) {
      continue;
    }
    final separator = trimmed.indexOf('=');
    env[trimmed.substring(0, separator).trim()] = trimmed
        .substring(separator + 1)
        .trim()
        .replaceAll('"', '')
        .replaceAll("'", '');
  }

  final key = env['API_FOOTBALL_KEY']!;
  const baseUrl = 'https://v3.football.api-sports.io';

  final searches = ['China'];

  for (final search in searches) {
    final uri = Uri.parse(
      '$baseUrl/leagues',
    ).replace(queryParameters: {'country': search});
    final request = await HttpClient().getUrl(uri);
    request.headers.set('x-apisports-key', key);
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    final json = jsonDecode(body) as Map;
    final leagues = json['response'] as List?;

    if (leagues != null && leagues.isNotEmpty) {
      stdout.writeln('--- $search ---');
      for (final l in leagues) {
        final league = l['league'];
        if (league['type'] == 'League') {
          stdout.writeln('${league['id']}: ${league['name']}');
        }
      }
    }
  }
}
