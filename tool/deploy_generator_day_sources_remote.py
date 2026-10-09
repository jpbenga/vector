"""Install only the demo's paged public-data reader, without paid model calls."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time
import urllib.error
import urllib.request

from deploy_generator_remote import PROJECT, request, require_ci
from deploy_generator_scope_remote import validate_environment

MIGRATION = Path('supabase/migrations/20261010090000_lector_generator_day_sources.sql')
FUNCTION = 'lector-generator-workshop'


def page_sql(day, timezone, sources, matches):
    def literal(value):
        return "'" + value.replace("'", "''") + "'"
    return ('select public.lector_generator_day_page('
            + literal(day) + '::date,' + literal(timezone) + ','
            + literal(json.dumps(sources)) + '::jsonb,'
            + literal(json.dumps(matches)) + '::jsonb) as page')


def main():
    env = os.environ
    validate_environment(env)
    runs = request(f"https://api.github.com/repos/jpbenga/vector/actions/workflows/ci.yml/runs?head_sha={env['GITHUB_SHA']}&per_page=100", env['GH_TOKEN'])
    require_ci(runs.get('workflow_runs', []), env['GITHUB_SHA'])
    token = env['SUPABASE_ACCESS_TOKEN']
    base = f'https://api.supabase.com/v1/projects/{PROJECT}'

    def query(sql, read_only=False):
        return request(base + '/database/query', token, {'query': sql, 'read_only': read_only})

    sql = MIGRATION.read_text()
    version, name = MIGRATION.stem.split('_', 1)
    prior = query(f"select statements from supabase_migrations.schema_migrations where version='{version}'", True)
    if prior:
        if prior[0].get('statements') != [sql]:
            raise ValueError('Installed day reader differs; add a migration.')
    else:
        if '$lector_day_sql$' in sql:
            raise ValueError('Unexpected migration delimiter.')
        query('begin;\n' + sql + f"\ninsert into supabase_migrations.schema_migrations(version,name,statements) values('{version}','{name}',array[$lector_day_sql${sql}$lector_day_sql$]);\ncommit;")
    acl = query("""select
        has_function_privilege('anon','public.lector_generator_day_manifest(date,text,text[],text[],text[],text[],jsonb)','execute') as anonymous_manifest,
        has_function_privilege('authenticated','public.lector_generator_day_page(date,text,jsonb,jsonb)','execute') as user_page,
        has_function_privilege('service_role','public.lector_generator_day_page(date,text,jsonb,jsonb)','execute') as server_page""", True)[0]
    if acl != {'anonymous_manifest': False, 'user_page': False, 'server_page': True}:
        raise ValueError('Day readers must be service-role only.')

    # Read current public publications through the actual SQL reader. No account,
    # profile, chat, model, collector or betting write participates in this check.
    started = time.monotonic()
    manifest = query("""select public.lector_generator_day_manifest(
        (now() at time zone 'Europe/Paris')::date,'Europe/Paris',
        array['football','hockey'],null,null,null,null) as manifest""")[0]['manifest']
    refs = manifest['matches']
    if manifest['total'] != len(refs) or len({r['key'] for r in refs}) != len(refs):
        raise ValueError('Public day manifest is inconsistent.')
    loaded = 0
    transferred = 0
    pages = 0
    for offset in range(0, len(refs), 50):
        matches = refs[offset:offset + 50]
        sources = [s for s in manifest['sources'] if any(s['sport'] == r['sport'] and s['id'] == r['id'] for r in matches)]
        page = query(page_sql(manifest['date'], manifest['timezone'], sources, matches))[0]['page']
        transferred += len(json.dumps(page).encode())
        seen = set()
        for source in page['sources']:
            items = (source['payload'].get('items', []) if source['sport'] == 'hockey'
                     else source['payload'].get('raw', {}).get('fixtures', []))
            for item in items:
                match_id = str(item['id'] if source['sport'] == 'hockey' else item['fixture']['id'])
                key = source['sport'] + ':' + match_id
                if any(r['key'] == key and r['id'] == source['id'] for r in matches):
                    seen.add(key)
        if seen != {r['key'] for r in matches}:
            raise ValueError('Public day page is incomplete.')
        loaded += len(seen)
        pages += 1
    summary = {'date': manifest['date'], 'expected': len(refs), 'loaded': loaded,
               'pages': pages, 'bytes': transferred,
               'management_roundtrip_ms': round((time.monotonic() - started) * 1000),
               'complete': loaded == len(refs)}
    print(json.dumps({'public_day_check': summary}))
    subprocess.run(['supabase', 'functions', 'deploy', FUNCTION, '--project-ref', PROJECT,
                    '--use-api', '--no-verify-jwt'], check=True)
    remote = request(base + '/functions/' + FUNCTION, token)
    if remote.get('status') != 'ACTIVE' or remote.get('verify_jwt') is not False:
        raise ValueError('Demo day reader deployment was not confirmed.')
    req = urllib.request.Request(f'https://{PROJECT}.supabase.co/functions/v1/{FUNCTION}', data=b'{"action":"chat"}',
                                 headers={'Content-Type': 'application/json'}, method='POST')
    try:
        urllib.request.urlopen(req, timeout=20)
        raise ValueError('Anonymous access was not rejected.')
    except urllib.error.HTTPError as error:
        if error.code != 401:
            raise ValueError('Unexpected anonymous endpoint response.') from None
    print(json.dumps({'function': FUNCTION, 'active': True, 'anonymous_status': 401,
                      'paid_model_calls': 0, 'provider_calls': 0, 'secrets_changed': False,
                      'revision': env['GITHUB_SHA'], 'migration_sha256': hashlib.sha256(sql.encode()).hexdigest()}))


if __name__ == '__main__':
    main()
