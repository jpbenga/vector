"""Install the shared public sport reader for the demo; no provider/model calls."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import urllib.error
import urllib.request
from deploy_generator_remote import PROJECT, request, require_ci
from deploy_generator_scope_remote import validate_environment

MIGRATION = Path('supabase/migrations/20261009170000_shared_sport_publications.sql')
FUNCTIONS = ('publish-sport-feed', 'lector-generator-workshop')


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
            raise ValueError('Installed publication migration differs; add a new migration.')
    else:
        if '$lector_publication_sql$' in sql:
            raise ValueError('Unexpected SQL delimiter.')
        query('begin;\n' + sql + f"\ninsert into supabase_migrations.schema_migrations(version,name,statements) values('{version}','{name}',array[$lector_publication_sql${sql}$lector_publication_sql$]);\ncommit;")
    acl = query("""select
        has_function_privilege('anon','public.publish_sport_feed(jsonb,jsonb)','execute') as anonymous_write,
        has_function_privilege('authenticated','public.publish_sport_feed(jsonb,jsonb)','execute') as user_write,
        has_function_privilege('anon','public.read_sport_feed(text,date,text,text,timestamptz)','execute') as public_read,
        has_function_privilege('anon','public.lector_generator_shared_radar_sources(date,text,jsonb)','execute') as anonymous_analysis,
        has_function_privilege('service_role','public.lector_generator_shared_radar_sources(date,text,jsonb)','execute') as server_analysis""", True)[0]
    if acl != {'anonymous_write':False, 'user_write':False, 'public_read':True, 'anonymous_analysis':False, 'server_analysis':True}:
        raise ValueError('Unexpected publication access permissions.')
    for function in FUNCTIONS:
        subprocess.run(['supabase','functions','deploy',function,'--project-ref',PROJECT,'--use-api','--no-verify-jwt'], check=True)
        remote = request(base + '/functions/' + function, token)
        if remote.get('status') != 'ACTIVE' or remote.get('verify_jwt') is not False:
            raise ValueError('Function deployment not confirmed.')
        req = urllib.request.Request(f'https://{PROJECT}.supabase.co/functions/v1/{function}',data=b'{}',headers={'Content-Type':'application/json'},method='POST')
        try:
            urllib.request.urlopen(req, timeout=20)
            raise ValueError('Anonymous write/analysis was not rejected.')
        except urllib.error.HTTPError as error:
            if error.code != 401:
                raise ValueError('Unexpected anonymous endpoint response.') from None
    print(json.dumps({'functions':FUNCTIONS,'acl':acl,'paid_model_calls':0,'provider_calls':0,
                      'revision':env['GITHUB_SHA'],'migration_sha256':hashlib.sha256(sql.encode()).hexdigest()}))


if __name__ == '__main__':
    main()
