#!/usr/bin/env python3
"""Operator-approved supplementary collector release; no client, AI or legacy generator deployment."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time
from deploy_controlled_generator_release import api, BASE, PROJECT, REPOSITORY, ROOT

FUNCTIONS=('api-football-sync','daily-football-sync','build-match-feed-snapshot')
MIGRATION='20261014220000_european_publication_freshness.sql'

def verify_served(function):
    with tempfile.TemporaryDirectory(prefix='lector-collector-check-') as directory:
        subprocess.run(['supabase','functions','download',function,'--project-ref',PROJECT,'--use-api','--workdir',directory],check=True)
        source=Path(directory)/'supabase/functions'
        files=[p for p in source.rglob('*') if p.is_file()]
        if not any(p.relative_to(source).as_posix()==function+'/index.ts' for p in files):raise ValueError('Downloaded function entry point missing')
        hashes={}
        for path in files:
            rel=path.relative_to(source).as_posix();local=ROOT/'supabase/functions'/rel
            if path.suffix not in ('.ts','.json'):continue
            if not local.is_file() or path.read_bytes()!=local.read_bytes():raise ValueError('Served collector source differs: '+rel)
            hashes[rel]=hashlib.sha256(path.read_bytes()).hexdigest()
        return {'sourceSha256':hashes}

def main():
    revision=os.environ.get('LECTOR_APPROVED_RELEASE','')
    operation=os.environ.get('LECTOR_RELEASE_OPERATION','')
    if (os.environ.get('GITHUB_ACTIONS')!='true' or os.environ.get('GITHUB_REF')!='refs/heads/main'
        or os.environ.get('GITHUB_REPOSITORY')!=REPOSITORY or not re.fullmatch('[a-f0-9]{40}',revision)
        or os.environ.get('GITHUB_SHA')!=revision
        or subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()!=revision):
        raise ValueError('Trusted workflow and exact reviewed main revision required')
    if operation not in ('install-freshness','activate-freshness','disable-freshness'):
        raise ValueError('Invalid supplementary release operation')
    token=os.environ['SUPABASE_ACCESS_TOKEN']
    runs=api('https://api.github.com/repos/'+REPOSITORY+'/actions/workflows/ci.yml/runs?head_sha='+revision+'&per_page=100',os.environ['GH_TOKEN'])
    if not any(r.get('head_sha')==revision and r.get('head_branch')=='main' and r.get('event')=='push' and r.get('conclusion')=='success' for r in runs.get('workflow_runs',[])):
        raise ValueError('Successful CI for the exact revision is required')
    def query(sql,readonly=True):return api(BASE+'/database/query',token,{'query':sql,'read_only':readonly})
    before={r['slug']:r for r in api(BASE+'/functions',token)}
    if any(before.get(f,{}).get('status')!='ACTIVE' or before[f].get('verify_jwt') is not False for f in FUNCTIONS):
        raise ValueError('Installed function configuration differs')
    # Prove the accepted discovery migration is already installed; do not silently
    # ship a new workshop/client version when publishing the collector supplement.
    discovery=(ROOT/'supabase/migrations/20261014190000_generator_discovery_publication_parity.sql').read_text()
    prior=query("select statements from supabase_migrations.schema_migrations where version='20261014190000'")
    if prior!=[{'statements':[discovery]}]:raise ValueError('Publish the accepted discovery lot first')
    body=(ROOT/'supabase/migrations'/MIGRATION).read_text()
    installed=query("select statements from supabase_migrations.schema_migrations where version='20261014220000'")
    if installed and installed!=[{'statements':[body]}]:raise ValueError('Installed freshness migration differs')
    receipt={'revision':revision,'operation':operation,'modelCalls':0,'legacyGeneratorReplaced':False,'clientChanged':False,'functions':{},'providerCallsTriggered':False}
    if operation=='install-freshness':
        paused=query("select jobid,jobname,active from cron.job where jobname in('api-football-queue-worker','api-football-league-2','api-football-league-3','api-football-league-848') order by jobid")
        if len(paused)!=4:raise ValueError('Expected scheduler inventory differs')
        query("select cron.alter_job(job_id:=jobid,active:=false) from cron.job where jobname in('api-football-queue-worker','api-football-league-2','api-football-league-3','api-football-league-848')",False)
        # Stop new claims while replacing the three stages. In-flight jobs must
        # finish before deployment; do not cancel a user/manual collection.
        time.sleep(5)
        busy=query("select count(*)::int n from api_football_sync_queue_jobs where status='running' and lease_expires_at>now()")
        if busy!=[{'n':0}]:
            for job in paused:query('select cron.alter_job(job_id:='+str(job['jobid'])+',active:='+('true' if job['active'] else 'false')+')',False)
            raise ValueError('A collector is running; prior cron states restored, nothing deployed')
        receipt['pausedSchedulers']=paused
        (ROOT/'european-freshness-release-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
        if installed:query('update european_refresh_control set enabled=false',False)
        else:
            if '$collector_migration$' in body:raise ValueError('Unexpected SQL delimiter')
            query("begin;select pg_advisory_xact_lock(hashtext('lector-controlled-generator-release'));\n"+body+"\ninsert into supabase_migrations.schema_migrations(version,name,statements) values('20261014220000','european_publication_freshness',array[$collector_migration$"+body+"$collector_migration$]);commit;",False)
        for function in FUNCTIONS:
            subprocess.run(['supabase','functions','deploy',function,'--project-ref',PROJECT,'--use-api','--no-verify-jwt'],check=True)
            receipt['functions'][function]=verify_served(function)
        after={r['slug']:r for r in api(BASE+'/functions',token)}
        if any(after.get(f,{}).get('version')!=before.get(f,{}).get('version') for f in ('lector-generator','lector-generator-workshop')):raise ValueError('Generator unexpectedly changed during collector deployment')
        if any(after.get(f,{}).get('status')!='ACTIVE' or after[f].get('verify_jwt') is not False for f in FUNCTIONS):raise ValueError('Deployment not verified')
        for job in paused:query('select cron.alter_job(job_id:='+str(job['jobid'])+',active:='+('true' if job['active'] else 'false')+')',False)
        receipt['previousSchedulersRestored']=True
        receipt['refreshEnabled']=False
    elif operation=='activate-freshness':
        if not installed:raise ValueError('Install and verify the collector supplement first')
        for function in FUNCTIONS:receipt['functions'][function]=verify_served(function)
        query("begin;update european_refresh_control set enabled=true;select cron.alter_job(job_id:=jobid,active:=true) from cron.job where jobname='lector-european-prematch-freshness';commit;",False)
        receipt['refreshEnabled']=True
        receipt['providerCallsTriggered']='scheduled queue only; existing quota reservations remain enforced'
    else:
        if not installed:raise ValueError('No installed freshness control')
        query("begin;update european_refresh_control set enabled=false;select cron.alter_job(job_id:=jobid,active:=false) from cron.job where jobname='lector-european-prematch-freshness';commit;",False)
        receipt['refreshEnabled']=False
    receipt['health']=query('select * from european_publication_health()')
    (ROOT/'european-freshness-release-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps(receipt))

if __name__=='__main__':
    try:main()
    except (ValueError,RuntimeError,KeyError,subprocess.CalledProcessError) as error:raise SystemExit(str(error)) from None
