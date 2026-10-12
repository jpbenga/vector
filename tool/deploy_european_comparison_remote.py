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
    today=datetime.datetime.now(datetime.timezone.utc).date()
    built=[]
    for league in (2,3,848):
        result=invoke('build-match-feed-snapshot',{'league_ids':[league],'season':today.year,'window_start':today.isoformat(),'window_end':(today+datetime.timedelta(days=13)).isoformat(),'timezone':'Europe/Paris','force_rebuild':True})
        source_id=result['snapshotId']
        analysis=invoke('analyze-match-feed-snapshot',{'snapshot_id':source_id})
        built.append({'leagueId':league,'snapshotId':source_id,'analysis':{k:analysis.get(k) for k in ('analysisSnapshotId','reused','snapshotId')}})
    invoke('build-feed-delivery',{'sport':'football'})
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
        counts.append({'sourceId':s['id'],'fixtures':len(dossiers),'domesticContexts':sum(1 for d in dossiers for side in ('home','away') if d[side]['domesticCompetition'] is not None),'europeanHistories':sum(1 for d in dossiers for side in ('home','away') if d[side]['europeanRecentMatches'])})
    receipt={'revision':sha,'functions':list(FUNCTIONS),'sources':counts,'builds':built,'providerCalls':0,'modelCalls':0,'personalDataWrites':0}
    (output/'receipt.json').write_text(json.dumps(receipt,indent=2))
    print(json.dumps(receipt))

if __name__=='__main__':main()
