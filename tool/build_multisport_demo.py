"""Build the real multisport app with a public, self-contained hockey compact."""
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PUBLICATION = ROOT / 'var/sports/hockey/published.json'
OUTPUT = ROOT / 'build/multisport-demo'

values = {}
for line in (ROOT / '.env').read_text().splitlines():
    if '=' in line and not line.lstrip().startswith('#'):
        name, value = line.split('=', 1)
        if name.strip() in ('SUPABASE_URL', 'SUPABASE_ANON_KEY'):
            values[name.strip()] = value.strip().strip('\"\'')
if not all(values.get(key) for key in ('SUPABASE_URL', 'SUPABASE_ANON_KEY')):
    raise SystemExit('Missing public Supabase configuration')
payload = json.loads(PUBLICATION.read_text())
if payload.get('sport') != 'hockey' or payload.get('schemaVersion') != 1:
    raise SystemExit('Invalid compact hockey publication')
if not payload.get('competitions') or not isinstance(payload.get('items'), list):
    raise SystemExit('Missing hockey data')

# Only public project configuration is compiled. No provider or server secret.
subprocess.run([
    'flutter', 'build', 'web', '--release', '--no-wasm-dry-run',
    '--target=lib/main.dart', '--output=' + str(OUTPUT),
    '--dart-define=APP_ENV=staging', '--dart-define=SPORT_FEED_DEMO=true',
    '--dart-define=MATCH_FEED_SOURCE=auto',
    '--dart-define=SUPABASE_URL=' + values['SUPABASE_URL'],
    '--dart-define=SUPABASE_ANON_KEY=' + values['SUPABASE_ANON_KEY'],
], cwd=ROOT, check=True)
(OUTPUT / 'data').mkdir(exist_ok=True)
(OUTPUT / 'data/hockey-feed.json').write_text(json.dumps(payload, separators=(',', ':')))
(OUTPUT / 'vercel.json').write_text(json.dumps({
    'buildCommand': None, 'installCommand': None, 'outputDirectory': '.',
    'rewrites': [
        {'source': '/sports/hockey/feed', 'destination': '/data/hockey-feed.json'},
        {'source': '/(.*)', 'destination': '/index.html'},
    ],
    'headers': [{'source': '/(.*)', 'headers': [
        {'key': 'X-Robots-Tag', 'value': 'noindex, nofollow'},
    ]}],
}, indent=2))
print(json.dumps({
    'output': str(OUTPUT), 'hockey_captured_at': payload['capturedAt'],
    'matches': len(payload['items']), 'competitions': len(payload['competitions']),
}))
