"""Scheduled full hockey refresh; credentials and provider keys never enter artifacts."""
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import urllib.request
import urllib.error
from deploy_generator_remote import PROJECT, request, require_ci

ROOT = Path(__file__).resolve().parent.parent
URL = f'https://{PROJECT}.supabase.co'
MIGRATION = ROOT / 'supabase/migrations/20261011050000_hockey_automatic_delivery.sql'


def validate_environment(env):
    if env.get('GITHUB_ACTIONS') != 'true' or env.get('GITHUB_REPOSITORY') != 'jpbenga/vector' or env.get('GITHUB_REF') not in ('refs/heads/main', 'refs/heads/codex/multisport-hockey'):
        raise ValueError('Refresh runs in the trusted repository workflow only')
    if not all(env.get(k) for k in ('SUPABASE_ACCESS_TOKEN', 'GH_TOKEN')):
        raise ValueError('Missing existing workflow credentials')


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


def public_read(key, path):
    req = urllib.request.Request(URL + path, headers={'apikey': key})
    with urllib.request.build_opener(NoRedirect).open(req, timeout=30) as r:
        return json.load(r)


def main():
    validate_environment(os.environ)
    at = time.monotonic()
    sha = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
    runs = request(f'https://api.github.com/repos/jpbenga/vector/actions/workflows/ci.yml/runs?head_sha={sha}&per_page=100', os.environ['GH_TOKEN'])
    require_ci(runs.get('workflow_runs', []), sha)
    token = os.environ['SUPABASE_ACCESS_TOKEN']
    base = f'https://api.supabase.com/v1/projects/{PROJECT}'
    def query(sql, read_only=False):
        return request(base + '/database/query', token, {'query': sql, 'read_only': read_only})
    if '--install' in sys.argv:
        sql = MIGRATION.read_text()
        version, name = MIGRATION.stem.split('_', 1)
        prior = query(f"select statements from supabase_migrations.schema_migrations where version='{version}'", True)
        if prior:
            if prior[0]['statements'] != [sql]:
                raise ValueError('Installed migration differs')
        else:
            if '$hockey_refresh$' in sql:
                raise ValueError('Unexpected SQL delimiter')
            query('begin;\n' + sql + f"\ninsert into supabase_migrations.schema_migrations(version,name,statements) values('{version}','{name}',array[$hockey_refresh${sql}$hockey_refresh$]);\ncommit;")
        subprocess.run(['supabase','functions','deploy','hockey-collection-provider','--project-ref',PROJECT,'--use-api','--no-verify-jwt'], check=True)
        info = request(base + '/functions/hockey-collection-provider', token)
        if info.get('status') != 'ACTIVE' or info.get('verify_jwt') is not False:
            raise ValueError('Private collector deployment not confirmed')
        req = urllib.request.Request(URL + '/functions/v1/hockey-collection-provider', data=b'{}', method='POST')
        try:
            urllib.request.urlopen(req, timeout=20)
            raise ValueError('Anonymous collection unexpectedly accepted')
        except urllib.error.HTTPError as error:
            if error.code != 401:
                raise ValueError('Anonymous collection check failed') from None
        acl = query("select has_function_privilege('anon','public.hockey_delivery_publish(uuid,timestamptz,jsonb)','execute') as anon_write, has_function_privilege('authenticated','public.hockey_delivery_publish(uuid,timestamptz,jsonb)','execute') as user_write, has_function_privilege('service_role','public.hockey_delivery_publish(uuid,timestamptz,jsonb)','execute') as server_write", True)[0]
        if acl != {'anon_write': False, 'user_write': False, 'server_write': True}:
            raise ValueError('Unexpected delivery permissions')
        print(json.dumps({'installed': True, 'acl': acl, 'revision': sha}))
        return
    keys = request(base + '/api-keys', token)
    service = next(k['api_key'] for k in keys if k['name'] == 'service_role')
    anon = next(k['api_key'] for k in keys if k['name'] == 'anon')
    secret = query('select sync_secret from ops_configuration where singleton', True)[0]['sync_secret']
    publication = ROOT / 'var/sports/hockey/published.json'
    publication.parent.mkdir(parents=True, exist_ok=True)
    envfile = ROOT / '.env'
    if envfile.exists():
        raise ValueError('Refuse to overwrite an existing environment file')
    envfile.write_text(f'SUPABASE_URL={URL}\nSUPABASE_ANON_KEY={anon}\nAPI_FOOTBALL_SYNC_SECRET={secret}\nHOCKEY_COLLECTION_PROXY=true\n')
    envfile.chmod(0o600)
    try:
        if '--delivery-only' in sys.argv:
            req = urllib.request.Request(URL + '/rest/v1/rpc/read_sport_feed', data=json.dumps({'p_sport':'hockey','p_section':'full'}).encode(), headers={'apikey':anon,'Content-Type':'application/json'})
            with urllib.request.urlopen(req, timeout=30) as r:
                publication.write_text(json.dumps(json.load(r), separators=(',', ':')))
        else:
            subprocess.run(['deno','run','--allow-read','--allow-write=var/sports/hockey','--allow-net='+PROJECT+'.supabase.co','tool/sports/nhl_local.ts','--collect-only','--refresh'], cwd=ROOT, check=True)
        sys.path.insert(0, str(ROOT / 'tool/sports'))
        from publication_health import require_current_hockey_publication
        from publish_sport_feed import configuration, verify_publication, main as publish
        payload = json.loads(publication.read_text())
        require_current_hockey_publication(payload)
        if {str(c['id']) for c in payload['competitions']} != {'57','58','35','10','18','16','47'} or not payload['items']:
            raise ValueError('Incomplete seven-league hockey collection')
        if '--delivery-only' in sys.argv:
            publication.write_text(json.dumps(verify_publication(payload, configuration()), separators=(',', ':')))
        else:
            publish()
        payload = json.loads(publication.read_text())
        runtime = {**os.environ, 'SUPABASE_URL':URL, 'SUPABASE_SERVICE_ROLE_KEY':service}
        subprocess.run(['deno','run','--allow-env=SUPABASE_URL,SUPABASE_SERVICE_ROLE_KEY','--allow-read','--allow-write','--allow-net='+PROJECT+'.supabase.co','tool/sports/publish_hockey_delivery.ts',str(publication)], cwd=ROOT, env=runtime, check=True)
        day = __import__('datetime').datetime.now(__import__('zoneinfo').ZoneInfo('Europe/Paris')).date().isoformat()
        rows = public_read(anon, f'/rest/v1/sport_feed_delivery_heads?sport=eq.hockey&day=eq.{day}&select=manifest')
        manifest = rows[0]['manifest'] if rows else {}
        if manifest.get('collectionId') != payload['collectionId'] or manifest.get('capturedAt') != payload['capturedAt']:
            raise ValueError('Public delivery pointer differs from verified collection')
        doc = public_read(anon, '/storage/v1/object/public/lector-feed-delivery/' + manifest['path'])
        if doc.get('capturedAt') != payload['capturedAt'] or doc.get('collectionId') != payload['collectionId']:
            raise ValueError('Public delivery object differs from verified collection')
        expected = {f['id'] for f in payload['items'] if f['calendarDate'] == day}
        if {f['id'] for f in doc['items']} != expected:
            raise ValueError('Incomplete public day coverage')
        run = ROOT / 'var/sports/hockey/enrichment-run.json'
        receipt = {'ok':True,'revision':sha,'capturedAt':payload['capturedAt'],'collectionId':payload['collectionId'],'competitions':len(payload['competitions']),'matches':len(payload['items']),'today':day,'today_matches':len(expected),'duration_seconds':round(time.monotonic()-at,2),'provider_requests':json.loads(run.read_text()).get('providerRequests') if run.exists() else 0,'paid_model_calls':0}
        (ROOT / 'hockey-refresh-receipt.json').write_text(json.dumps(receipt, indent=2))
        print(json.dumps(receipt))
    finally:
        envfile.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
