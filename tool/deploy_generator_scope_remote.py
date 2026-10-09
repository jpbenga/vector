"""Update the demo's Radar read scope without model calls or credential prompts."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import urllib.error
import urllib.request

from deploy_generator_remote import PROJECT, request, require_ci

MIGRATION = Path('supabase/migrations/20261009143000_lector_generator_radar_scope.sql')
FUNCTION = 'lector-generator-workshop'


def validate_environment(env):
    if (env.get('GITHUB_ACTIONS') != 'true'
            or env.get('GITHUB_REF') != 'refs/heads/codex/multisport-hockey'
            or env.get('GITHUB_REPOSITORY') != 'jpbenga/vector'):
        raise ValueError('This update runs on the multisport GitHub branch only.')
    for name in ('SUPABASE_ACCESS_TOKEN', 'GH_TOKEN', 'GITHUB_SHA'):
        if not env.get(name):
            raise ValueError(f'Missing repository secret {name}. No keychain fallback.')


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
            raise ValueError('Installed scope migration differs; create a new migration.')
    else:
        if '$lector_scope_sql$' in sql:
            raise ValueError('Unexpected SQL delimiter.')
        query('begin;\n' + sql + f"\ninsert into supabase_migrations.schema_migrations(version,name,statements) values('{version}','{name}',array[$lector_scope_sql${sql}$lector_scope_sql$]);\ncommit;")
    check = query("""select
       has_function_privilege('anon','public.lector_generator_radar_sources(date,text,jsonb)','execute') as anonymous,
       has_function_privilege('authenticated','public.lector_generator_radar_sources(date,text,jsonb)','execute') as user_access,
       has_function_privilege('service_role','public.lector_generator_radar_sources(date,text,jsonb)','execute') as server_access""", True)[0]
    if check != {'anonymous': False, 'user_access': False, 'server_access': True}:
        raise ValueError('Scope RPC must be service-role only.')
    # Validate SQL execution with a public current publication, not user data.
    smoke = query("""with s as (select id,captured_at from match_feed_analysis_snapshots order by captured_at desc limit 1)
      select jsonb_array_length(public.lector_generator_radar_sources(current_date,'Europe/Paris',
        jsonb_build_object('football',jsonb_build_object('sourceIds',jsonb_build_array(s.id::text),'teams','[]'::jsonb,'players','[]'::jsonb)))) as sources from s""")
    if not smoke or smoke[0]['sources'] != 1:
        raise ValueError('Pinned publication read failed.')
    subprocess.run(['supabase', 'functions', 'deploy', FUNCTION, '--project-ref', PROJECT,
                    '--use-api', '--no-verify-jwt'], check=True)
    remote = request(base + '/functions/' + FUNCTION, token)
    if remote.get('status') != 'ACTIVE' or remote.get('verify_jwt') is not False:
        raise ValueError('Demo function deployment was not confirmed.')
    req = urllib.request.Request(f'https://{PROJECT}.supabase.co/functions/v1/{FUNCTION}', data=b'{"action":"prepare"}',
                                 headers={'Content-Type': 'application/json'}, method='POST')
    try:
        urllib.request.urlopen(req, timeout=20)
        raise ValueError('Anonymous access was not rejected.')
    except urllib.error.HTTPError as error:
        if error.code != 401:
            raise ValueError('Unexpected anonymous endpoint response.') from None
    print(json.dumps({'function': FUNCTION, 'active': True, 'scope_rpc_service_only': True,
                      'paid_model_calls': 0, 'revision': env['GITHUB_SHA'],
                      'migration_sha256': hashlib.sha256(sql.encode()).hexdigest()}))


if __name__ == '__main__':
    main()
