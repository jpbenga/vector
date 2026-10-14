"""Read-only owner preferences and public quote coverage. No model/provider calls."""
import json
import os
from deploy_generator_remote import PROJECT, request

def main():
    if os.environ.get('GITHUB_ACTIONS') != 'true' or os.environ.get('GITHUB_REF') != 'refs/heads/main':
        raise ValueError('Demo workflow only')
    def query(sql):
        return request(f'https://api.supabase.com/v1/projects/{PROJECT}/database/query', os.environ['SUPABASE_ACCESS_TOKEN'], {'query':sql,'read_only':True})
    preferences=query("""select p.updated_at,p.compiled_profile->'readings' as readings,
        p.compiled_profile->'opportunityProfiles' as scenarios
        from profiles p join auth.users u on u.id=p.user_id
        where lower(u.email) in ('jpaulbengiar@gmail.com','jpaulbenga@gmail.com') and p.is_active""")
    coverage=query("""with latest as (select distinct on(scope_key) captured_at,payload from match_feed_analysis_snapshots
        where window_end >= current_date and captured_at>now()-interval '36 hours' order by scope_key,as_of desc,id desc)
        select f#>>'{league,id}' as league,f#>>'{fixture,id}' as fixture,f#>>'{teams,home,name}' as home,
        f#>>'{teams,away,name}' as away,min(o->>'update') as oldest_quote,max(o->>'update') as newest_quote,
        count(o) as quote_rows from latest cross join lateral jsonb_array_elements(payload#>'{raw,fixtures}') f
        left join lateral jsonb_array_elements(coalesce(payload#>'{raw,odds}','[]')) o on o#>>'{fixture,id}'=f#>>'{fixture,id}'
        where f#>>'{league,id}' in ('2','3','848','40') and (f#>>'{fixture,date}')::timestamptz>=now()
        and (f#>>'{fixture,date}')::timestamptz<now()+interval '4 days'
        group by 1,2,3,4 order by 1,2""")
    cached=query("""select query_params,fetched_at,as_of,jsonb_array_length(coalesce(response_body->'response','[]')) as fixtures
        from api_football_cached_responses where endpoint='/odds' and query_params->>'league' in ('2','3','848','40')
        and fetched_at>now()-interval '4 days' order by fetched_at desc limit 20""")
    schedules=query("select league_id,enabled,daily_time,last_scheduled_date from ops_competitions where league_id in (2,3,848,40)")
    tasks=query("select league_id,status,stage,created_at,finished_at,error_message from ops_tasks where league_id in (2,3,848,40) order by created_at desc limit 12")
    print(json.dumps({'owner_profile':preferences,'football_quotes':coverage,'cached_odds':cached,'schedules':schedules,'tasks':tasks},ensure_ascii=False))

if __name__=='__main__':main()
