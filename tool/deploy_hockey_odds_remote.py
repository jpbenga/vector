"""Install hockey prices + demo conversation continuity, without local keychain."""
import json
import os
from pathlib import Path
import subprocess
import urllib.request
from deploy_generator_remote import PROJECT, request, require_ci
from deploy_generator_scope_remote import validate_environment

MIGRATIONS = (
    Path('supabase/migrations/20261009210000_hockey_market_quotes.sql'),
    Path('supabase/migrations/20261009213000_hockey_quotes_compact_reader.sql'),
)
FUNCTIONS = ('sync-hockey-odds', 'lector-generator-workshop')


def generator_price_coverage(access_token, day):
    # The Management read-only SQL role cannot execute service-only RPCs. Verify
    # the same endpoint and role as the Edge backend, without broadening grants.
    keys = request(f'https://api.supabase.com/v1/projects/{PROJECT}/api-keys', access_token)
    key = next((k.get('api_key') for k in keys if k.get('name') == 'service_role'), None)
    if not key:
        raise ValueError('Existing server API credential unavailable.')
    class NoRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, *args, **kwargs):
            return None
    req = urllib.request.Request(f'https://{PROJECT}.supabase.co/rest/v1/rpc/lector_generator_shared_sources',
        data=json.dumps({'p_date':day,'p_timezone':'Europe/Paris','p_sports':['hockey']}).encode(),
        headers={'apikey':key,'Authorization':'Bearer '+key,'Content-Type':'application/json'},method='POST')
    with urllib.request.build_opener(NoRedirect).open(req,timeout=30) as response:
        sources = json.load(response)
    fixtures = [f for source in sources if source.get('sport') == 'hockey' for f in source.get('payload',{}).get('items',[])]
    return {'day':day,'matches':sum(bool(f.get('quotes')) for f in fixtures),'prices':sum(len(f.get('quotes',[])) for f in fixtures)}


def main():
    env = os.environ
    validate_environment(env)
    runs = request(f"https://api.github.com/repos/jpbenga/vector/actions/workflows/ci.yml/runs?head_sha={env['GITHUB_SHA']}&per_page=100", env['GH_TOKEN'])
    require_ci(runs.get('workflow_runs', []), env['GITHUB_SHA'])
    token = env['SUPABASE_ACCESS_TOKEN']
    base = f'https://api.supabase.com/v1/projects/{PROJECT}'
    def query(sql, read_only=False):
        return request(base + '/database/query', token, {'query': sql, 'read_only': read_only})
    for migration in MIGRATIONS:
        sql = migration.read_text()
        version, name = migration.stem.split('_', 1)
        prior = query(f"select statements from supabase_migrations.schema_migrations where version='{version}'", True)
        if prior:
            if prior[0].get('statements') != [sql]:
                raise ValueError('Installed odds migration differs; add a new migration.')
        else:
            if '$lector_quotes_sql$' in sql:
                raise ValueError('Unexpected SQL delimiter.')
            query('begin;\n' + sql + f"\ninsert into supabase_migrations.schema_migrations(version,name,statements) values('{version}','{name}',array[$lector_quotes_sql${sql}$lector_quotes_sql$]);\ncommit;")
    for function in FUNCTIONS:
        subprocess.run(['supabase','functions','deploy',function,'--project-ref',PROJECT,'--use-api','--no-verify-jwt'], check=True)
        remote = request(base + '/functions/' + function, token)
        if remote.get('status') != 'ACTIVE' or remote.get('verify_jwt') is not False:
            raise ValueError('Function deployment not confirmed.')
    acl = query("""select
        has_function_privilege('anon','public.hockey_odds_publish(uuid,jsonb)','execute') as public_write,
        has_table_privilege('anon','public.hockey_market_quotes','select') as raw_table_read,
        has_function_privilege('anon','public.read_sport_feed(text,date,text,text,timestamptz)','execute') as public_read""", True)[0]
    if acl != {'public_write':False, 'raw_table_read':False, 'public_read':True}:
        raise ValueError('Unexpected quote access permissions.')
    # This server secret is sent only to this project's authenticated collector.
    fresh = query("select last_success_at>now()-interval '6 hours' as fresh from hockey_odds_configuration where singleton", True)[0]['fresh']
    if fresh:
        collection = {'ok':True, 'reused_recent_collection':True, 'requests':0}
    else:
        secret = query('select sync_secret from ops_configuration where singleton', True)[0]['sync_secret']
        collection = request(f'https://{PROJECT}.supabase.co/functions/v1/sync-hockey-odds', secret, {})
    coverage = query("""select competition_id,count(*) filter(where jsonb_array_length(quotes)>0) as matches,
        sum(jsonb_array_length(quotes)) as prices,max(collected_at) as collected_at
        from hockey_market_quotes group by competition_id order by competition_id""", True)
    schedule = query("select jobname,schedule,active from cron.job where jobname='lector-hockey-odds'", True)
    if schedule != [{'jobname':'lector-hockey-odds','schedule':'17 */6 * * *','active':True}]:
        raise ValueError('Hockey price schedule is not active.')
    days = query("""with head as (
        select overview from sport_feed_snapshots where sport='hockey' order by captured_at desc limit 1
        ) select ((f->>'startsAt')::timestamptz at time zone 'Europe/Paris')::date::text as day
        from head cross join lateral jsonb_array_elements(overview->'items') f
        join hockey_market_quotes q on q.fixture_id=f->>'id'
        where jsonb_array_length(q.quotes)>0 and (f->>'startsAt')::timestamptz>now()
        group by day order by day limit 1""", True)
    generator = generator_price_coverage(token, days[0]['day']) if days else {'matches':0,'prices':0}
    if days and not generator['prices']:
        raise ValueError('Collected prices are missing from the Generator projection.')
    print(json.dumps({'schedule':schedule,'generator_quote_coverage':generator,'functions':FUNCTIONS,'acl':acl,'collection':collection,'coverage':coverage,'paid_model_calls':0,'revision':env['GITHUB_SHA']}))
    if not collection.get('ok'):
        raise ValueError('Some hockey leagues were deferred; inspect collector status before claiming completion.')


if __name__ == '__main__':
    main()
