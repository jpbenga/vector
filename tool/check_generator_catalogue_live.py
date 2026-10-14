"""Read-only production parity capture; trusted existing runner only, no model/provider call."""
import datetime
import json
import os
from pathlib import Path
import subprocess
import urllib.request
from zoneinfo import ZoneInfo
from deploy_controlled_generator_release import api, BASE, REPOSITORY
from generator_catalogue_rpc import ServerCatalogueReader


def main():
    revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
    if (os.environ.get('GITHUB_ACTIONS') != 'true'
        or os.environ.get('GITHUB_REPOSITORY') != REPOSITORY
        or os.environ.get('GITHUB_REF') != 'refs/heads/main'
        or os.environ.get('LECTOR_APPROVED_RELEASE') != revision
        or os.environ.get('GITHUB_SHA') != revision):
        raise ValueError('Exact approved main revision required.')
    token = os.environ['SUPABASE_ACCESS_TOKEN']
    server_catalogue = ServerCatalogueReader(token)
    def query(sql):
        return api(BASE + '/database/query', token, {'query': sql, 'read_only': True})
    now = datetime.datetime.now(datetime.timezone.utc)
    day = now.astimezone(ZoneInfo('Europe/Paris')).date().isoformat()
    # Flutter's current fallback orders date-covered rows, then latest rows;
    # selectMatchFeedSnapshotRowIds keeps the newest uncovered league IDs.
    metadata = query("select id::text,scope,league_ids,captured_at,as_of from match_feed_analysis_snapshots where captured_at<=now() and window_start<='" + day + "' and window_end>='" + day + "' order by as_of desc limit 500")
    if not metadata or max(datetime.datetime.fromisoformat(r['captured_at'].replace('Z','+00:00')) for r in metadata) < now - datetime.timedelta(hours=36):
        raise ValueError('Football app publication obsolete or unavailable; cannot certify visible-catalogue parity.')
    covered, selected, global_selected = set(), [], False
    for row in metadata:
        leagues = set(row['league_ids'] or [])
        if row['scope'] == 'global':
            if not global_selected: selected.append(row['id']); global_selected = True
            continue
        if not leagues or leagues - covered:
            selected.append(row['id']); covered.update(leagues)
    # UUIDs are server-generated; never interpolate arbitrary request strings.
    import re
    if not all(re.fullmatch(r'[a-f0-9-]{36}', value) for value in selected):
        raise ValueError('Invalid publication identity')
    ids = ','.join("'" + value + "'::uuid" for value in selected) or 'null::uuid'
    fixtures = query("select id::text as source_id,captured_at,f as fixture from match_feed_analysis_snapshots cross join lateral jsonb_array_elements(payload#>'{raw,fixtures}') f where id in (" + ids + ") and ((f#>>'{fixture,date}')::timestamptz at time zone 'Europe/Paris')::date='" + day + "'")
    order = {value: i for i, value in enumerate(selected)}
    unique = {}
    for fixture in sorted(fixtures, key=lambda value: order[value['source_id']]):
        unique.setdefault(str(fixture['fixture']['fixture']['id']), fixture)
    fixtures = list(unique.values())
    document = {'day': day, 'asOf': now.isoformat(), 'revision': revision, 'sports': {}}
    heads = query("select sport,manifest from sport_feed_delivery_heads where day='" + day + "'")
    if any(r['sport'] == 'football' for r in heads):
        raise ValueError('Football fast delivery now active: capture its authoritative app reader before claiming parity.')
    for sport in ('football', 'hockey'):
        manifest = server_catalogue.read('lector_generator_day_manifest', {
            'p_date':day, 'p_timezone':'Europe/Paris', 'p_sports':[sport],
            'p_competitions':None, 'p_readings':None, 'p_scenarios':None, 'p_radar':None})
        parts = []
        for start in range(0, manifest['total'], 50):
            matches = manifest['matches'][start:start + 50]
            source_ids = {r['id'] for r in matches}
            sources = [r for r in manifest['sources'] if r['id'] in source_ids]
            parts += server_catalogue.read('lector_generator_day_page', {
                'p_date':day, 'p_timezone':'Europe/Paris', 'p_sources':sources,
                'p_matches':matches})['sources']
        def merge(a, b):
            if isinstance(a, dict) and isinstance(b, dict):
                return {k: merge(a[k], b[k]) if k in a and k in b else (a if k in a else b)[k] for k in a.keys() | b.keys()}
            if isinstance(a, list) and isinstance(b, list):
                return list({json.dumps(v, sort_keys=True): v for v in a + b}.values())
            return b
        combined = {}
        for part in parts:
            key = part['id']; combined[key] = merge(combined[key], part) if key in combined else part
        if sport == 'football':
            visible = [{'key': 'football:' + str(f['fixture']['fixture']['id']), 'competitionId': str(f['fixture']['league']['id']),
                        'season': str(f['fixture']['league'].get('season', '')), 'home': f['fixture']['teams']['home']['name'],
                        'away': f['fixture']['teams']['away']['name'], 'kickoff': f['fixture']['fixture']['date'],
                        'sourceId': f['source_id'], 'capturedAt': f['captured_at']} for f in fixtures]
        else:
            head = next((r['manifest'] for r in heads if r['sport'] == sport), None)
            if not head or not re.fullmatch(r'delivery/hockey/[a-zA-Z0-9_-]+/[a-zA-Z0-9_.-]+\.json', head.get('path', '')):
                raise ValueError('Authoritative hockey fast publication unavailable; do not claim parity.')
            with urllib.request.urlopen('https://ednvvxxvlawaagjyshkj.supabase.co/storage/v1/object/public/lector-feed-delivery/' + head['path'], timeout=30) as response:
                body = json.load(response)
            if datetime.datetime.fromisoformat(body['capturedAt'].replace('Z','+00:00')) < now - datetime.timedelta(hours=36):
                raise ValueError('Hockey fast publication expired; cannot certify app display parity.')
            source = next((s for s in manifest['sources'] if datetime.datetime.fromisoformat(s['capturedAt'].replace('Z', '+00:00')) == datetime.datetime.fromisoformat(body['capturedAt'].replace('Z', '+00:00'))), None)
            if not source: raise ValueError('Hockey application/Generator publication version mismatch')
            visible = [{'key': 'hockey:' + str(f['id']), 'competitionId': str(f['competitionId']), 'season': str(f.get('season', '')),
                        'home': f['home']['name'], 'away': f['away']['name'], 'kickoff': f['startsAt'],
                        'sourceId': source['id'], 'capturedAt': body['capturedAt']} for f in body['items']]
        document['sports'][sport] = {'visible': visible, 'manifest': manifest, 'page': {'sources': list(combined.values())}}
    output = Path('catalogue-parity-capture.json')
    output.write_text(json.dumps(document)); output.chmod(0o600)
    subprocess.run(['deno','run','--allow-read=' + str(output),'--allow-write=catalogue-parity-results.json',
                    'tool/check_generator_catalogue_parity.ts',str(output),'catalogue-parity-results.json'], check=True)


if __name__ == '__main__': main()
