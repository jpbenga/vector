import 'dart:io';

/// Copies the server setup to SQL Editor without printing credentials.
/// Use --copy on macOS, or redirect stdout to a protected file elsewhere.
Future<void> main(List<String> args) async {
  if (args.any((arg) => arg != '--copy')) {
    stderr.writeln('Usage: dart tool/generate_live_setup_sql.dart [--copy]');
    exitCode = 1;
    return;
  }
  final envFile = File('.env');
  if (!envFile.existsSync()) {
    stderr.writeln(
      'Le fichier .env est absent. Lancez depuis le dépôt Lector.',
    );
    exitCode = 1;
    return;
  }
  final env = <String, String>{};
  for (final line in envFile.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final separator = trimmed.indexOf('=');
    if (separator <= 0) continue;
    final key = trimmed.substring(0, separator).trim();
    var value = trimmed.substring(separator + 1).trim();
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      value = value.substring(1, value.length - 1);
    }
    env[key] = value;
  }
  final url = env['SUPABASE_URL']?.trim() ?? '';
  final secret = env['API_FOOTBALL_SYNC_SECRET'] ?? '';
  final uri = Uri.tryParse(url);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      (uri.path.isNotEmpty && uri.path != '/')) {
    stderr.writeln('SUPABASE_URL est absente ou invalide dans .env.');
    exitCode = 1;
    return;
  }
  if (secret.trim().isEmpty) {
    stderr.writeln('API_FOOTBALL_SYNC_SECRET est absent dans .env.');
    exitCode = 1;
    return;
  }
  String quote(String value) => "'${value.replaceAll("'", "''")}'";
  final sql =
      '''-- Execute in the Supabase project used by this .env.
-- Contains a server credential: keep this SQL private.
begin;
insert into public.ops_configuration
  (singleton, base_url, sync_secret, scheduling_enabled)
values (true, ${quote(url.replaceFirst(RegExp(r'/+$'), ''))}, ${quote(secret)}, false)
on conflict (singleton) do update set
  base_url = excluded.base_url,
  sync_secret = excluded.sync_secret;

insert into public.ops_events(actor, kind, message)
values ('sql_editor', 'configuration',
  'Configuration des appels serveur initialisée pour le live ; programmation conservée.');

select public.match_live_set_enabled(true);
select public.match_live_tick();
commit;

select enabled, last_started_at, last_completed_at, last_success_at,
       last_error, requests_last_run
from public.match_live_configuration;
''';
  if (args.contains('--copy')) {
    if (!Platform.isMacOS) {
      stderr.writeln('--copy utilise le presse-papiers macOS.');
      exitCode = 1;
      return;
    }
    try {
      final clipboard = await Process.start('pbcopy', []);
      clipboard.stdin.write(sql);
      await clipboard.stdin.close();
      final result = await clipboard.exitCode;
      if (result != 0) throw const ProcessException('pbcopy', []);
      stdout.writeln('SQL copié. Collez-le dans SQL Editor du projet Supabase');
      stdout.writeln('correspondant au .env, puis cliquez sur Run.');
    } on ProcessException {
      stderr.writeln('Impossible de copier le SQL dans le presse-papiers.');
      exitCode = 1;
    }
  } else {
    stdout.write(sql);
  }
}
