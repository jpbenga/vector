"""Build the real multisport app with a public, self-contained hockey compact."""
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PUBLICATION = ROOT / 'var/sports/hockey/published.json'
OUTPUT = ROOT / 'build/multisport-demo'
REUSE_DELIVERY = '--reuse-delivery' in sys.argv
if REUSE_DELIVERY and not (OUTPUT / 'delivery/metrics.json').exists():
    raise SystemExit('Aucun flux de démo existant à réutiliser')

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
    '--dart-define=MATCH_FEED_SOURCE=auto', '--dart-define=FEED_DELIVERY_DEMO=true',
    '--dart-define=LECTOR_GENERATOR_UI=true',
    '--dart-define=LECTOR_GENERATOR_ENDPOINT=lector-generator-workshop',
    '--dart-define=SUPABASE_URL=' + values['SUPABASE_URL'],
    '--dart-define=SUPABASE_ANON_KEY=' + values['SUPABASE_ANON_KEY'],
], cwd=ROOT, check=True)
if not REUSE_DELIVERY:
    sources = Path('/private/tmp/lector-public-delivery-sources.json')
    if not sources.exists():
        raise SystemExit('Export public manquant : exécuter tool/fetch_public_delivery_sources.py')
    # Replace generated delivery only after a complete build. Repeated builds
    # must not upload abandoned archives or keep obsolete full JSON files.
    with tempfile.TemporaryDirectory(prefix='lector-delivery-', dir=OUTPUT.parent) as staging:
        subprocess.run(['deno', 'run', '--allow-read', '--allow-write',
            str(ROOT / 'tool/build_feed_delivery_demo.ts'), str(sources), str(PUBLICATION), staging],
            cwd=ROOT, check=True)
        target = OUTPUT / 'delivery'
        if target.exists():
            shutil.rmtree(target)
        shutil.move(str(Path(staging) / 'delivery'), target)
elif not (OUTPUT / 'delivery/metrics.json').exists():
    raise SystemExit('Les fichiers de livraison de la démo ont disparu')
(OUTPUT / 'data').mkdir(exist_ok=True)
(OUTPUT / 'data/hockey-feed.json').write_text(json.dumps(payload, separators=(',', ':')))
(OUTPUT / 'vercel.json').write_text(json.dumps({
    'buildCommand': None, 'installCommand': None, 'outputDirectory': '.',
    'rewrites': [
        {'source': '/delivery/:path*', 'destination': '/delivery/:path*'},
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
