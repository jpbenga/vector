"""Install only recorded Radar evidence and bounded hockey events for the demo."""
import json
import os
from pathlib import Path
import subprocess
from deploy_generator_remote import PROJECT, request, require_ci
from deploy_generator_scope_remote import validate_environment

MIGRATION = Path('supabase/migrations/20261009230000_form_radar_match_snapshots.sql')
FUNCTION = 'sync-hockey-live'

def main():
    env = os.environ
    validate_environment(env)
    runs = request(f"https://api.github.com/repos/jpbenga/vector/actions/workflows/ci.yml/runs?head_sha={env['GITHUB_SHA']}&per_page=100", env['GH_TOKEN'])
    require_ci(runs.get('workflow_runs', []), env['GITHUB_SHA'])
    base = f'https://api.supabase.com/v1/projects/{PROJECT}'
    token = env['SUPABASE_ACCESS_TOKEN']
    def query(sql, read_only=False):
        return request(base + '/database/query', token, {'query': sql, 'read_only': read_only})
    sql = MIGRATION.read_text()
    version, name = MIGRATION.stem.split('_', 1)
    prior = query(f"select statements from supabase_migrations.schema_migrations where version='{version}'", True)
    if prior:
        if prior[0].get('statements') != [sql]:
            raise ValueError('Installed Radar migration differs; add a new migration.')
    else:
        if '$lector_radar_sql$' in sql:
            raise ValueError('Unexpected SQL delimiter.')
        query('begin;\n' + sql + f"\ninsert into supabase_migrations.schema_migrations(version,name,statements) values('{version}','{name}',array[$lector_radar_sql${sql}$lector_radar_sql$]);\ncommit;")
    subprocess.run(['supabase', 'functions', 'deploy', FUNCTION, '--project-ref', PROJECT, '--use-api', '--no-verify-jwt'], check=True)
    remote = request(base + '/functions/' + FUNCTION, token)
    if remote.get('status') != 'ACTIVE' or remote.get('verify_jwt') is not False:
        raise ValueError('Hockey event collector deployment was not confirmed.')
    acl = query("""select
      has_function_privilege('anon','public.form_radar_for_fixtures(text,text[])','execute') as public_evidence_read,
      has_table_privilege('anon','public.form_radar_match_snapshots','insert') as public_write,
      has_function_privilege('anon','public.form_radar_record_publication(text,uuid,timestamptz,jsonb)','execute') as public_record,
      has_function_privilege('anon','public.hockey_radar_event_due(text[])','execute') as public_collector""", True)[0]
    if acl != {'public_evidence_read': True, 'public_write': False, 'public_record': False, 'public_collector': False}:
        raise ValueError('Radar access controls do not match the read-only contract.')
    coverage = query("""select sport,count(*) as matches,count(*) filter(where jsonb_array_length(profiles)>0) as with_players,
      count(*) filter(where recorded_at>=kickoff_at or captured_at>=kickoff_at) as late
      from public.form_radar_match_snapshots group by sport""", True)
    print(json.dumps({'revision':env['GITHUB_SHA'],'function':FUNCTION,'active':True,
       'migration':version,'access':acl,'coverage':coverage,'manual_collection':False,'secrets_changed':False,'quota_changed':False}))

if __name__ == '__main__':
    main()
