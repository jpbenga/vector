"""Export public sources, including seven frozen historical days.

No provider request, private profile, management token or server secret is used.
The index references cached files: the builder reads one payload at a time.
"""
import concurrent.futures
import datetime
import json
import os
import re
from pathlib import Path
import time
import urllib.error
import urllib.parse
import urllib.request
from zoneinfo import ZoneInfo

ROOT = Path(__file__).resolve().parent.parent
CACHE = Path('/private/tmp/lector-public-delivery-cache')
OUTPUT = Path('/private/tmp/lector-public-delivery-sources.json')
PARIS = ZoneInfo('Europe/Paris')


def timestamp(value):
    value = re.sub(r'\.(\d+)(?=[+-])',
                   lambda match: '.' + match.group(1).ljust(6, '0')[:6],
                   value.replace('Z', '+00:00'))
    return datetime.datetime.fromisoformat(value)


def selected_sources(metadata, today):
    chosen = {}
    for offset in range(-7, 14):
        day = today + datetime.timedelta(days=offset)
        end = datetime.datetime.combine(
            day + datetime.timedelta(days=1), datetime.time(), PARIS)
        covered = [row for row in metadata
                   if row['window_start'] <= day.isoformat() <= row['window_end']
                   and (day >= today or timestamp(row['as_of']) < end)]
        scopes = set()
        for row in covered + (metadata if day >= today else []):
            scope = row['scope_key']
            if scope in scopes:
                continue
            scopes.add(scope)
            chosen[row['id']] = row
    return list(chosen.values())


def main():
    values = {}
    for line in (ROOT / '.env').read_text().splitlines():
        if '=' in line and not line.lstrip().startswith('#'):
            name, value = line.split('=', 1)
            if name.strip() in ('SUPABASE_URL', 'SUPABASE_ANON_KEY'):
                values[name.strip()] = value.strip().strip('\"\'')

    def read(parameters):
        request = urllib.request.Request(
            values['SUPABASE_URL'] + '/rest/v1/match_feed_analysis_snapshots?' +
            urllib.parse.urlencode(parameters),
            headers={'apikey': values['SUPABASE_ANON_KEY']})
        with urllib.request.urlopen(request, timeout=45) as response:
            return json.load(response)

    today = datetime.datetime.now(PARIS).date()
    metadata = []
    offset = 0
    while True:
        page = read({
            'select': 'id,scope,scope_key,league_ids,captured_at,as_of,window_start,window_end',
            'order': 'as_of.desc,id.desc', 'limit': '1000', 'offset': str(offset),
            'window_end': 'gte.' + (today - datetime.timedelta(days=7)).isoformat(),
        })
        metadata.extend(page)
        if len(page) < 1000:
            break
        offset += len(page)
    chosen = selected_sources(metadata, today)
    CACHE.mkdir(exist_ok=True)
    missing = [row['id'] for row in chosen
               if not (CACHE / (row['id'] + '.json')).exists()]

    def fetch_chunk(ids):
        for attempt in range(3):
            try:
                rows = read({
                    'select': 'id,scope,scope_key,league_ids,captured_at,as_of,window_start,window_end,payload',
                    'id': 'in.(' + ','.join(ids) + ')',
                })
                if {row['id'] for row in rows} != set(ids):
                    raise RuntimeError('Incomplete public snapshot response')
                for row in rows:
                    temporary = CACHE / (row['id'] + '.tmp')
                    temporary.write_text(json.dumps(row, separators=(',', ':')))
                    os.replace(temporary, CACHE / (row['id'] + '.json'))
                return len(rows)
            except urllib.error.HTTPError as error:
                if error.code == 500 and len(ids) > 1:
                    return sum(fetch_chunk([identity]) for identity in ids)
                if attempt == 2:
                    raise RuntimeError('Public snapshot export failed') from None
            except Exception:
                if attempt == 2:
                    raise RuntimeError('Public snapshot export failed') from None
            time.sleep(1 + attempt)
        raise RuntimeError('Public snapshot export failed')

    chunks = [missing[i:i + 5] for i in range(0, len(missing), 5)]
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        completed = 0
        for count in pool.map(fetch_chunk, chunks):
            completed += count
            print(json.dumps({'public_snapshots_downloaded': completed,
                              'required': len(missing)}), flush=True)
    rows = [{**row, 'sourceFile': str(CACHE / (row['id'] + '.json'))}
            for row in chosen]
    temporary = OUTPUT.with_suffix('.tmp')
    temporary.write_text(json.dumps({
        'schemaVersion': 2, 'today': today.isoformat(), 'rows': rows,
    }, separators=(',', ':')))
    os.replace(temporary, OUTPUT)
    print(json.dumps({'output': str(OUTPUT), 'snapshot_count': len(rows),
                      'index_bytes': OUTPUT.stat().st_size}), flush=True)


if __name__ == '__main__':
    main()
