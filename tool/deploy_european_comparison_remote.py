"""Deploy/rebuild only European dossiers from existing caches. No provider/model calls."""
import datetime
import json
import os
from pathlib import Path
import subprocess
import urllib.request
import urllib.error
from deploy_generator_remote import PROJECT, request, require_ci
from deploy_generator_scope_remote import validate_environment

FUNCTIONS = ('build-match-feed-snapshot', 'analyze-match-feed-snapshot', 'build-feed-delivery', 'lector-generator-workshop')

def main():
    validate_environment(os.environ)
    sha = os.environ['GITHUB_SHA']
    token = os.environ['SUPABASE_ACCESS_TOKEN']
    runs = request(f'https://api.github.com/repos/jpbenga/vector/actions/workflows/ci.yml/runs?head_sha={sha}&per_page=100', os.environ['GH_TOKEN'])
    require_ci(runs.get('workflow_runs', []), sha)
    base = f'https://api.supabase.com/v1/projects/{PROJECT}'
    def query(sql, read_only=True):
        return request(base + '/database/query', token, {'query':sql,'read_only':read_only})
    for fn in FUNCTIONS:
        subprocess.run(['supabase','functions','deploy',fn,'--project-ref',PROJECT,'--use-api','--no-verify-jwt'],check=True)
        remote = request(base+'/functions/'+fn,token)
        if remote.get('status') != 'ACTIVE' or remote.get('verify_jwt') is not False:
            raise ValueError('Deployment configuration not confirmed for '+fn)
    secret = query('select sync_secret from ops_configuration where singleton')[0]['sync_secret']
    def invoke(fn,body):
        req=urllib.request.Request(f'https://{PROJECT}.supabase.co/functions/v1/{fn}',data=json.dumps(body).encode(),headers={'Content-Type':'application/json','Authorization':'Bearer '+secret},method='POST')
        try:
            with urllib.request.urlopen(req,timeout=150) as response:
                value=json.load(response)
        except urllib.error.HTTPError as error:
            raise RuntimeError(f'{fn} HTTP {error.code}; response withheld') from None
        if not value.get('ok'):
            raise RuntimeError(fn+' did not confirm success')
        return value
    import tempfile
    import uuid
    # Download only public sporting cache fields; never user or conversation tables.
    cache=query("select source,endpoint,query_hash,query_params,response_status,response_body,fetched_at,as_of from api_football_cached_responses where source='api-football' and (endpoint in ('/standings','/leagues') or (endpoint='/odds' and query_params->>'league' in ('2','3','848') and fetched_at>now()-interval '4 days')) and response_status between 200 and 299 order by fetched_at desc")
    keys=request(base+'/api-keys',token)
    service=next(k['api_key'] for k in keys if k['name']=='service_role')
    def storage(table,body):
        req=urllib.request.Request(f'https://{PROJECT}.supabase.co/rest/v1/'+table,data=json.dumps(body).encode(),headers={'Content-Type':'application/json','apikey':service,'Authorization':'Bearer '+service,'Prefer':'return=representation'},method='POST')
        try:
            with urllib.request.urlopen(req,timeout=60) as response:return json.load(response)
        except urllib.error.HTTPError as error:raise RuntimeError(f'Snapshot storage HTTP {error.code}; response withheld') from None
    built=[]
    for league in (2,3,848):
        print('Preparing European league '+str(league)+' from archived sources',flush=True)
        seed=query("select * from match_feed_snapshots where league_ids=array["+str(league)+"] order by captured_at desc limit 1")[0]
        source_id=seed['id']
        sources=query("select s.source,s.endpoint,s.query_hash,s.sync_run_id,s.response_status,c.query_params,s.fetched_at,s.as_of from match_feed_snapshot_sources s join api_football_cached_responses c on c.source=s.source and c.endpoint=s.endpoint and c.query_hash=s.query_hash where s.snapshot_id='"+source_id+"'")
        now=datetime.datetime.now(datetime.timezone.utc).isoformat()
        with tempfile.TemporaryDirectory() as folder:
            inp=Path(folder)/'input.json';out=Path(folder)/'prepared.json'
            def prepare(cache_rows):
                inp.write_text(json.dumps({'payload':seed['payload'],'sources':sources,'cached':cache_rows,'builtAt':now}))
                subprocess.run(['deno','run','--allow-read='+folder,'--allow-write='+folder,'tool/prepare_european_publication.ts',str(inp),str(out)],check=True)
                return json.loads(out.read_text())
            initial=prepare(cache)
            pairs=initial['wantedSchedules']
            if any(not isinstance(p['league'],int) or not isinstance(p['season'],int) for p in pairs):raise ValueError('Invalid schedule scope')
            clauses=' or '.join("(query_params->>'league'='"+str(p['league'])+"' and query_params->>'season'='"+str(p['season'])+"')" for p in pairs)
            wanted=query("select source,endpoint,query_hash,query_params,response_status,response_body,fetched_at,as_of from api_football_cached_responses where source='api-football' and endpoint='/fixtures' and response_status between 200 and 299 and ("+clauses+") and not (query_params ?| array['team','date','from','to','round','last','status','ids','live','next']) order by fetched_at desc")
            prepared=prepare(cache+wanted)
        clone={**seed,'id':str(uuid.uuid4()),'captured_at':now,'as_of':now,'payload':prepared['payload'],'snapshot_created_at':now}
        for field in ('created_at','updated_at'):clone.pop(field,None)
        storage('match_feed_snapshots',clone)
        records={r['source']+':'+r['endpoint']+':'+r['query_hash']:{**r,'snapshot_id':clone['id']} for r in prepared['sourceRecords']}
        if records:storage('match_feed_snapshot_sources',list(records.values()))
        analysis=invoke('analyze-match-feed-snapshot',{'snapshot_id':clone['id']})
        built.append({'leagueId':league,'snapshotId':clone['id'],'analysis':{k:analysis.get(k) for k in ('analysisSnapshotId','reused','snapshotId')},'coverage':prepared['coverage']})
    # Only public sporting payloads enter artifacts. Never persist secrets/cache envelopes.
    import re
    identities=[b['snapshotId'] for b in built]
    if any(not re.fullmatch(r'[a-f0-9-]{36}', i) for i in identities):
        raise ValueError('Invalid snapshot identity')
    literals=','.join("'"+i+"'" for i in identities)
    sources=query('select id,scope_key,captured_at,as_of,window_start,window_end,payload from match_feed_analysis_snapshots where source_snapshot_id in ('+literals+') order by captured_at desc')
    if len(sources)!=3 or any(not s['payload'].get('raw',{}).get('european_comparisons') for s in sources):
        raise ValueError('European dossiers not confirmed in all three publications')
    output=Path('output/european-comparison');output.mkdir(parents=True,exist_ok=True)
    (output/'public-sources.json').write_text(json.dumps(sources))
    counts=[]
    for s in sources:
        dossiers=s['payload']['raw']['european_comparisons']
        counts.append({'sourceId':s['id'],'fixtures':len(dossiers),'domesticContexts':sum(1 for d in dossiers for side in ('home','away') if d[side]['domesticCompetition'] is not None),'europeanHistories':sum(1 for d in dossiers for side in ('home','away') if d[side]['europeanRecentMatches']), 'newestQuoteAt':max((q.get('update','') for q in s['payload']['raw'].get('odds',[])),default=None)})
    receipt={'revision':sha,'functions':list(FUNCTIONS),'sources':counts,'builds':built,'providerCalls':0,'modelCalls':0,'personalDataWrites':0}
    (output/'receipt.json').write_text(json.dumps(receipt,indent=2))
    print(json.dumps(receipt),flush=True)
    capabilities=query("select to_regprocedure('public.feed_delivery_claim(text)') is not null and to_regprocedure('public.feed_delivery_finish(text,uuid,bigint,jsonb,text)') is not null as cloud_delivery")[0]
    if capabilities['cloud_delivery']:
        runtime={**os.environ,'SUPABASE_URL':'https://'+PROJECT+'.supabase.co','SUPABASE_SERVICE_ROLE_KEY':service}
        subprocess.run(['deno','run','--allow-env=GITHUB_ACTIONS,SUPABASE_URL,SUPABASE_SERVICE_ROLE_KEY','--allow-net='+PROJECT+'.supabase.co','tool/build_football_delivery_remote.ts'],env=runtime,check=True)
    else:
        print(json.dumps({'cloudDelivery':'not_installed','demoDelivery':'static_files','europeanPublication':'confirmed'}))


if __name__=='__main__':main()
