"""Install account-owned Shortlist sessions and update only the demo Generator."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import urllib.error
import urllib.request

from deploy_generator_remote import PROJECT, request, require_ci
from deploy_generator_scope_remote import validate_environment

MIGRATION = Path('supabase/migrations/20261011160000_lector_shortlist.sql')
DISPLAY_MIGRATION = Path('supabase/migrations/20261011220000_lector_shortlist_display.sql')
FUNCTION = 'lector-generator-workshop'


def main():
    env = os.environ
    validate_environment(env)
    runs = request(f"https://api.github.com/repos/jpbenga/vector/actions/workflows/ci.yml/runs?head_sha={env['GITHUB_SHA']}&per_page=100", env['GH_TOKEN'])
    require_ci(runs.get('workflow_runs', []), env['GITHUB_SHA'])
    token = env['SUPABASE_ACCESS_TOKEN']
    base = f'https://api.supabase.com/v1/projects/{PROJECT}'

    def query(sql, read_only=False):
        return request(base + '/database/query', token, {'query': sql, 'read_only': read_only})

    for migration in (MIGRATION, DISPLAY_MIGRATION):
        sql = migration.read_text()
        version, name = migration.stem.split('_', 1)
        prior = query(f"select statements from supabase_migrations.schema_migrations where version='{version}'", True)
        if prior:
            if prior[0].get('statements') != [sql]:
                raise ValueError('Installed Shortlist migration differs; add a migration.')
        else:
            if '$lector_shortlist_sql$' in sql:
                raise ValueError('Unexpected migration delimiter.')
            query('begin;\n' + sql + f"\ninsert into supabase_migrations.schema_migrations(version,name,statements) values('{version}','{name}',array[$lector_shortlist_sql${sql}$lector_shortlist_sql$]);\ncommit;")
    acl = query("""select
        has_function_privilege('anon','public.lector_shortlist(text,uuid,text,text,date,timestamptz,text,bigint)','execute') as anonymous_mutation,
        has_function_privilege('authenticated','public.lector_shortlist(text,uuid,text,text,date,timestamptz,text,bigint)','execute') as user_action,
        has_function_privilege('authenticated','public.lector_shortlist_read(uuid)','execute') as foreign_owner_read,
        has_function_privilege('service_role','public.lector_shortlist_read(uuid)','execute') as server_read,
        has_table_privilege('authenticated','public.lector_shortlist_items','insert') as direct_user_write""", True)[0]
    if acl != {'anonymous_mutation': False, 'user_action': True, 'foreign_owner_read': False, 'server_read': True, 'direct_user_write': False}:
        raise ValueError('Shortlist ownership permissions differ from the tested contract.')
    cron = query("select schedule,active from cron.job where jobname='lector-shortlist-cleanup'", True)
    if len(cron) != 1 or cron[0] != {'schedule': '17 * * * *', 'active': True}:
        raise ValueError('Shortlist cleanup schedule was not confirmed.')
    subprocess.run(['supabase', 'functions', 'deploy', FUNCTION, '--project-ref', PROJECT,
                    '--use-api', '--no-verify-jwt'], check=True)
    remote = request(base + '/functions/' + FUNCTION, token)
    if remote.get('status') != 'ACTIVE' or remote.get('verify_jwt') is not False:
        raise ValueError('Demo Generator deployment was not confirmed.')
    req = urllib.request.Request(f'https://{PROJECT}.supabase.co/functions/v1/{FUNCTION}', data=b'{"action":"shortlist_inspect"}',
                                 headers={'Content-Type': 'application/json'}, method='POST')
    try:
        urllib.request.urlopen(req, timeout=20)
        raise ValueError('Anonymous access was not rejected.')
    except urllib.error.HTTPError as error:
        if error.code != 401:
            raise ValueError('Unexpected anonymous endpoint response.') from None
    print(json.dumps({'function': FUNCTION, 'active': True, 'anonymous_status': 401,
                      'shortlist_permissions': acl, 'cleanup': cron[0],
                      'paid_model_calls': 0, 'provider_calls': 0, 'secrets_changed': False,
                      'revision': env['GITHUB_SHA'], 'migration_sha256': hashlib.sha256(sql.encode()).hexdigest()}))


if __name__ == '__main__':
    main()
