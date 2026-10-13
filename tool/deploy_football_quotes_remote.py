"""Publish cached price revisions inside PostgreSQL; never transfer raw archives."""
import json
import os
import subprocess
import uuid
from pathlib import Path
from deploy_generator_remote import PROJECT, request, require_ci
from deploy_generator_scope_remote import validate_environment

def main():
    validate_environment(os.environ)
    sha=os.environ['GITHUB_SHA'];token=os.environ['SUPABASE_ACCESS_TOKEN']
    runs=request(f'https://api.github.com/repos/jpbenga/vector/actions/workflows/ci.yml/runs?head_sha={sha}&per_page=100',os.environ['GH_TOKEN'])
    require_ci(runs.get('workflow_runs',[]),sha)
    def query(sql,read_only=True):
        return request(f'https://api.supabase.com/v1/projects/{PROJECT}/database/query',token,{'query':sql,'read_only':read_only})
    subprocess.run(['supabase','functions','deploy','lector-generator-workshop','--project-ref',PROJECT,'--use-api','--no-verify-jwt'],check=True)
    info=request(f'https://api.supabase.com/v1/projects/{PROJECT}/functions/lector-generator-workshop',token)
    if info.get('status')!='ACTIVE' or info.get('verify_jwt') is not False:raise ValueError('Function deployment not confirmed')
    results=[]
    for league in (2,3,848):
        raw_id=str(uuid.uuid4());analysis_id=str(uuid.uuid4())
        # All archive copying stays in the database. Only the resulting identity,
        # provider quote time and dimensions are returned through the gateway.
        sql=f"""with base as materialized (
          select a.*,r.id as raw_id from match_feed_analysis_snapshots a
          join match_feed_snapshots r on r.id=a.source_snapshot_id
          where a.league_ids=array[{league}] order by a.as_of desc,a.id desc limit 1
        ), fixtures as materialized (
          select f#>>'{{fixture,id}}' id,f#>>'{{league,id}}' league,f#>>'{{league,season}}' season
          from base cross join lateral jsonb_array_elements(payload#>'{{raw,fixtures}}') f
        ), cached as materialized (
          select c.*,q from api_football_cached_responses c
          cross join lateral jsonb_array_elements(coalesce(c.response_body->'response','[]')) q
          join fixtures f on f.id=q#>>'{{fixture,id}}'
          where c.source='api-football' and c.endpoint='/odds' and c.response_status between 200 and 299
          and c.query_params->>'league'=f.league and c.query_params->>'season'=f.season
          and c.fetched_at>now()-interval '4 days' and coalesce(c.response_body->'errors','[]') in ('[]','{{}}')
          and q->>'update' is not null
        ), price_pool as (
          select o as quote,'epoch'::timestamptz collected from base
          cross join lateral jsonb_array_elements(coalesce(payload#>'{{raw,odds}}','[]')) o
          union all select q,fetched_at from cached
        ), newest as materialized (
          select distinct on(quote#>>'{{fixture,id}}') quote from price_pool
          where quote#>>'{{fixture,id}}' in(select id from fixtures)
          order by quote#>>'{{fixture,id}}',nullif(quote->>'update','')::timestamptz desc nulls last,collected desc
        ), prices as materialized (
          select coalesce(jsonb_agg(quote order by quote#>>'{{fixture,id}}'),'[]') odds from newest
        ), raw_revision as (
          insert into match_feed_snapshots(id,schema_version,source,kind,season,timezone,window_start,window_end,date_window,
            bookmaker_priority,payload,coverage_summary,provenance,source_sync_run_ids,captured_at,as_of,snapshot_created_at,scope,scope_key,league_ids)
          select '{raw_id}'::uuid,r.schema_version,r.source,r.kind,r.season,r.timezone,r.window_start,r.window_end,r.date_window,
            r.bookmaker_priority,jsonb_set(r.payload,'{{raw,odds}}',p.odds)||jsonb_build_object('captured_at',now(),'as_of',now()),
            r.coverage_summary,r.provenance||jsonb_build_object('quoteRevisionOf',b.id),r.source_sync_run_ids,now(),now(),now(),r.scope,r.scope_key,r.league_ids
          from base b join match_feed_snapshots r on r.id=b.raw_id cross join prices p returning id
        ), fixture_index as (
          insert into match_feed_snapshot_fixtures(snapshot_id,fixture_id,api_football_fixture_id,api_football_league_id,season,
            fixture_date,kickoff_at,status,competition_id,competition_name,country_code,country_name,home_team_id,home_team_name,
            away_team_id,away_team_name,has_odds,has_standings,has_team_statistics,has_recent_form,has_expected_goals,contains_predictions,payload)
          select distinct on(i.fixture_id) r.id,i.fixture_id,i.api_football_fixture_id,i.api_football_league_id,i.season,
            i.fixture_date,i.kickoff_at,i.status,i.competition_id,i.competition_name,i.country_code,i.country_name,i.home_team_id,i.home_team_name,
            i.away_team_id,i.away_team_name,exists(select 1 from newest n where n.quote#>>'{{fixture,id}}'=f.id),
            i.has_standings,i.has_team_statistics,i.has_recent_form,i.has_expected_goals,i.contains_predictions,i.payload
          from raw_revision r cross join fixtures f join match_feed_snapshot_fixtures i on i.api_football_fixture_id::text=f.id
          where i.api_football_league_id={league} and i.season=f.season::integer
            and i.fixture_date between (select window_start from base) and (select window_end from base)
          order by i.fixture_id,i.created_at desc returning fixture_id
        ), inherited_sources as (
          insert into match_feed_snapshot_sources(snapshot_id,source,endpoint,query_hash,sync_run_id,response_status,fetched_at,as_of)
          select '{raw_id}'::uuid,s.source,s.endpoint,s.query_hash,s.sync_run_id,s.response_status,s.fetched_at,s.as_of
          from match_feed_snapshot_sources s,raw_revision where s.snapshot_id=(select raw_id from base)
          and s.endpoint<>'/odds' returning snapshot_id
        ), quote_sources as (
          insert into match_feed_snapshot_sources(snapshot_id,source,endpoint,query_hash,sync_run_id,response_status,fetched_at,as_of)
          select distinct '{raw_id}'::uuid,c.source,c.endpoint,c.query_hash,c.sync_run_id,c.response_status,c.fetched_at,c.as_of
          from cached c,raw_revision returning snapshot_id
        ), analysis_revision as (
          insert into match_feed_analysis_snapshots(id,source_snapshot_id,schema_version,source,scope,scope_key,league_ids,timezone,
            window_start,window_end,captured_at,as_of,payload,coverage_summary)
          select '{analysis_id}'::uuid,r.id,b.schema_version,b.source,b.scope,b.scope_key,b.league_ids,b.timezone,
            b.window_start,b.window_end,now(),now(),
            jsonb_set(b.payload,'{{raw,odds}}',p.odds)||jsonb_build_object('captured_at',now(),'as_of',now(),
              'quoteRevision',jsonb_build_object('originalAnalysisId',b.id,'analysisAsOf',b.as_of)),b.coverage_summary
          from base b cross join prices p cross join raw_revision r returning id,captured_at
        ) select id as source_id,captured_at,{league} as league,
          (select count(*) from fixtures) as fixtures,(select count(*) from fixture_index) as indexed_fixtures,(select count(*) from newest) as priced_fixtures,
          (select count(*) from newest where nullif(quote->>'update','')::timestamptz>=now()-interval '48 hours') as recent_priced_fixtures,
          (select max(quote->>'update') from newest) as newest_quote_at from analysis_revision"""
        result=query(sql,False)
        if len(result)!=1 or result[0]['indexed_fixtures']!=result[0]['fixtures']:raise ValueError('Price revision or fixture index not confirmed')
        results.extend(result);print(json.dumps(result),flush=True)
    receipt={'revision':sha,'priceRevisions':results,'providerCalls':0,'modelCalls':0,'analysisRecomputed':False,'personalDataWrites':0}
    out=Path('output/european-comparison');out.mkdir(parents=True,exist_ok=True)
    (out/'quote-receipt.json').write_text(json.dumps(receipt,indent=2));print(json.dumps(receipt))

if __name__=='__main__':main()
