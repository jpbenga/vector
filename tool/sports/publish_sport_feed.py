"""Publish a collector's public compact using the existing server secret.

No keychain, user JWT, provider key in a browser, or paid model call.
"""
import json
from pathlib import Path
import subprocess
import tempfile
import urllib.request
import urllib.error

ROOT = Path(__file__).resolve().parents[2]
PROJECT_URL = 'https://ednvvxxvlawaagjyshkj.supabase.co'


def configuration():
    values = {}
    for line in (ROOT / '.env').read_text().splitlines():
        if '=' in line and not line.lstrip().startswith('#'):
            name, value = line.split('=', 1)
            if name.strip() in ('SUPABASE_URL', 'SUPABASE_ANON_KEY', 'API_FOOTBALL_SYNC_SECRET'):
                values[name.strip()] = value.strip().strip('\"\'')
    if values.get('SUPABASE_URL', '').rstrip('/') != PROJECT_URL:
        raise ValueError('Unexpected publication destination')
    return values


def without_prices(payload):
    if payload is None:
        return None
    return {**payload, 'items': [{k:v for k,v in f.items() if k not in ('quotes','quotesCollectedAt')} for f in payload['items']]}


def verify_publication(payload, values):
    def read(section):
        req = urllib.request.Request(PROJECT_URL + '/rest/v1/rpc/read_sport_feed',
            data=json.dumps({'p_sport': payload['sport'], 'p_section': section,
                             'p_captured_at': payload['capturedAt']}).encode(),
            headers={'apikey': values['SUPABASE_ANON_KEY'], 'Content-Type': 'application/json'}, method='POST')
        with urllib.request.urlopen(req, timeout=60) as response:
            return json.load(response)
    stored = read('full')
    if without_prices(stored) != without_prices(payload):
        raise ValueError('Shared server publication differs from the displayed compact')
    if payload['sport'] != 'hockey':
        return stored
    # Quote observations do not require rebuilding the large analytical export
    # in PostgreSQL. Read them from its lightweight, exact-version projection.
    quoted = read('radar')
    if quoted is None or any(quoted.get(k) != stored.get(k) for k in ('sport', 'capturedAt', 'collectionId')):
        raise ValueError('Quote projection differs from the verified publication')
    prices = {f['id']: f for f in quoted['items']}
    if len(prices) != len(quoted['items']) or set(prices) != {f['id'] for f in stored['items']}:
        raise ValueError('Quote projection has different fixture identities')
    hydrated = []
    for f in stored['items']:
        q = prices[f['id']]
        if any(q.get(k) != f.get(k) for k in ('competitionId', 'season', 'startsAt')) or any(q.get(side, {}).get('id') != f.get(side, {}).get('id') for side in ('home', 'away')):
            raise ValueError('Quote identity differs from the verified fixture')
        base = {k: v for k, v in f.items() if k not in ('quotes', 'quotesCollectedAt')}
        hydrated.append({**base, **{k: q[k] for k in ('quotes', 'quotesCollectedAt') if k in q}})
    return {**stored, 'items': hydrated}


def main():
    values = configuration()
    if not values.get('API_FOOTBALL_SYNC_SECRET'):
        raise ValueError('Existing server sync secret is required. No keychain fallback.')
    path = ROOT / 'var/sports/hockey/published.json'
    with tempfile.TemporaryDirectory(prefix='lector-publication-') as staging:
        source = Path(staging) / 'calendar.json'
        source.write_text(json.dumps(without_prices(json.loads(path.read_text()))))
        prepared = Path(staging) / 'hockey.json'
        subprocess.run(['dart', 'run', 'tool/sports/prepare_hockey_publication.dart', str(source), str(prepared)], cwd=ROOT, check=True)
        text = prepared.read_text()
        payload = json.loads(text)
        req = urllib.request.Request(PROJECT_URL + '/functions/v1/publish-sport-feed',
            data=text.encode(), headers={'Authorization': 'Bearer ' + values['API_FOOTBALL_SYNC_SECRET'],
            'Content-Type': 'application/json'}, method='POST')
        try:
            with urllib.request.urlopen(req, timeout=90) as response:
                receipt = json.load(response)
        except urllib.error.HTTPError as error:
            # Server errors never expose credentials or submitted provider data.
            try:
                detail = json.load(error)
                status = detail.get('storageStatus')
                code = detail.get('storageCode')
                reason = detail.get('reason')
                diagnostic = f"; storage {status}/{code}: {reason}" if status and code and reason else ''
            except (ValueError, AttributeError):
                diagnostic = ''
            raise RuntimeError(f'Publication rejected (HTTP {error.code}){diagnostic}') from None
        if not receipt.get('ok'):
            raise ValueError('Server publication was not confirmed')
        hydrated = verify_publication(payload, values)
        # Local collector/browser and server now retain exactly the same object.
        temporary = path.with_suffix('.bridge.tmp')
        temporary.write_text(json.dumps(hydrated, separators=(',',':')))
        temporary.replace(path)
        print(json.dumps({'shared_publication': receipt['publication'], 'verified': True}))


if __name__ == '__main__':
    main()
