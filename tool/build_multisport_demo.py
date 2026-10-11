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
REFRESH_HOCKEY = '--refresh-hockey-delivery' in sys.argv
if REFRESH_HOCKEY and REUSE_DELIVERY:
    raise SystemExit('Choisir soit la réutilisation, soit la nouvelle livraison hockey')
if REFRESH_HOCKEY and not (OUTPUT / 'main.dart.js').exists():
    raise SystemExit('Compiler la démo avant de renouveler uniquement sa livraison hockey')
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

# A demo must never ship a hockey version that its Generator cannot read.
sys.path.insert(0, str(ROOT / 'tool/sports'))
from publish_sport_feed import verify_publication, without_prices
from publication_health import require_current_hockey_publication
require_current_hockey_publication(payload)
if REUSE_DELIVERY:
    delivered = json.loads((OUTPUT / 'data/hockey-feed.json').read_text())
    if without_prices(delivered) != without_prices(payload):
        raise SystemExit('La publication a changé : reconstruire la livraison de la démo')
    payload = delivered
# A visual-only rebuild reuses its quote observations and delivery files. The
# canonical publication must still match the server, but it does not need a
# fresh quote projection. Collectors retain the complete quote verification.
verified = verify_publication(payload, values, include_quotes=not REUSE_DELIVERY)
if not REUSE_DELIVERY:
    payload = verified
require_current_hockey_publication(payload)

# Only public project configuration is compiled. No provider or server secret.
if not REFRESH_HOCKEY:
    # Flutter can reuse bundle stamps from a different web output directory,
    # then omit unchanged runtime assets in this custom demo output. Re-run
    # packaging only; preserve the expensive Dart compilation cache.
    for target in ('web_static_assets', 'web_release_bundle', 'web_templated_files', 'web_service_worker'):
        for stamp in (ROOT / '.dart_tool/flutter_build').glob('*/' + target + '.stamp'):
            stamp.unlink()
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
# An incremental build left an incomplete output despite a successful exit.
# Never publish a shell that falls back to index.html
# when the runtime requests its asset manifest or voice transcription script.
required_web_files = [
    'index.html', 'main.dart.js', 'flutter_bootstrap.js',
    'generator_voice.js', 'manifest.json',
    'assets/AssetManifest.bin.json', 'assets/FontManifest.json',
]
missing_web_files = [name for name in required_web_files if not (OUTPUT / name).is_file()]
if missing_web_files:
    raise SystemExit('Paquet web incomplet : ' + ', '.join(missing_web_files))
for family in json.loads((OUTPUT / 'assets/FontManifest.json').read_text()):
    for font in family['fonts']:
        if not (OUTPUT / 'assets' / font['asset']).is_file():
            raise SystemExit('Police manquante dans le paquet web : ' + font['asset'])
if not REUSE_DELIVERY and not REFRESH_HOCKEY:
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
# Rebuild hockey delivery from the verified payload including quote observations.
# Older demo files predate quote hydration. Their paths must not be reused for
# different bytes; the delivery builder derives a new source ID from this JSON.
with tempfile.TemporaryDirectory(prefix='lector-hockey-delivery-', dir=OUTPUT.parent) as staging:
    stage = Path(staging)
    (stage / 'football.json').write_text('[]')
    (stage / 'hockey.json').write_text(json.dumps(payload, separators=(',', ':')))
    subprocess.run(['deno', 'run', '--allow-read', '--allow-write',
        str(ROOT / 'tool/build_feed_delivery_demo.ts'), str(stage / 'football.json'),
        str(stage / 'hockey.json'), str(stage / 'output'), '--hockey-only'], cwd=ROOT, check=True)
    target = OUTPUT / 'delivery/hockey'
    if target.exists():
        shutil.rmtree(target)
    shutil.move(str(stage / 'output/delivery/hockey'), target)
    metrics_path = OUTPUT / 'delivery/metrics.json'
    metrics = json.loads(metrics_path.read_text())
    fresh_metrics = json.loads((stage / 'output/delivery/metrics.json').read_text())
    metrics.update({key: fresh_metrics[key] for key in ('hockey', 'builtAt', 'today')})
    metrics_path.write_text(json.dumps(metrics, separators=(',', ':')))
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
