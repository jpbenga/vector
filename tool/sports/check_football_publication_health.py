"""Read-only football batch and publication alarm; no provider or model calls."""
import argparse
from datetime import datetime, timezone
import json
import os
import re
from pathlib import Path
import urllib.request

PROJECT = 'ednvvxxvlawaagjyshkj'
SQL = """with configured as (
 select replace(jobname,'api-football-league-','') league_id from cron.job
 where active and jobname ~ '^api-football-league-[0-9]+$'
), latest as (
 select distinct on(scope_key) scope_key,captured_at,window_start,window_end
 from match_feed_analysis_snapshots order by scope_key,as_of desc
), attempts as (
 select distinct on(payload->'league_ids') id,status,payload->'league_ids' leagues,created_at
 from api_football_sync_queue_jobs where created_at>now()-interval '24 hours'
 order by payload->'league_ids',created_at desc
) select jsonb_build_object('checkedAt',now(),
 'parisDay',(now() at time zone 'Europe/Paris')::date,
 'leagues',(select coalesce(jsonb_agg(jsonb_build_object('id',c.league_id,'capturedAt',l.captured_at,
 'windowStart',l.window_start,'windowEnd',l.window_end)),'[]') from configured c left join latest l on l.scope_key='league:'||c.league_id),
 'failedBatches',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'leagues',leagues,'status',status)),'[]')from attempts where status='failed'),
 'stalledBatches',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'status',status)),'[]')from api_football_sync_queue_jobs
 where (status='running' and lease_expires_at<now()-interval '15 minutes')
 or (status in('queued','retrying') and available_at<now()-interval '2 hours'))
) as document"""


def assess(document, now=None):
    now = now or datetime.now(timezone.utc)
    day = document.get('parisDay', '')
    missing, stale, uncovered = [], [], []
    for league in document.get('leagues', []):
        identity = str(league['id'])
        try:
            text = str(league['capturedAt']).replace('Z', '+00:00')
            text = re.sub(r'\.(\d+)(?=[+-])',lambda m:'.'+m.group(1).ljust(6,'0')[:6],text)
            at = datetime.fromisoformat(text)
            if at.tzinfo is None or at > now:
                raise ValueError()
        except (ValueError, TypeError, KeyError):
            missing.append(identity)
            continue
        if (now-at).total_seconds() >= 36*3600:
            stale.append(identity)
        if not league.get('windowStart', '') <= day <= league.get('windowEnd', ''):
            uncovered.append(identity)
    failed = document.get('failedBatches', [])
    stalled = document.get('stalledBatches', [])
    healthy = bool(document.get('leagues')) and not any((missing, stale, uncovered, failed, stalled))
    return {'status': 'healthy' if healthy else 'attention', 'checkedAt': now.isoformat(),
            'parisDay': day, 'configuredLeagues': len(document.get('leagues', [])),
            'missingLeagues': missing, 'staleLeagues': stale, 'uncoveredLeagues': uncovered,
            'failedBatches': failed, 'stalledBatches': stalled,
            'providerRequests': 0, 'paidModelCalls': 0}


def remote_read():
    token = os.environ.get('SUPABASE_ACCESS_TOKEN')
    if not token:
        raise ValueError('Missing operator token for read-only monitoring')
    req = urllib.request.Request(f'https://api.supabase.com/v1/projects/{PROJECT}/database/query',
        data=json.dumps({'query': SQL, 'read_only': True}).encode(),
        headers={'Authorization': 'Bearer '+token, 'Content-Type': 'application/json'})
    with urllib.request.urlopen(req, timeout=30) as response:
        rows = json.load(response)
    if len(rows) != 1:
        raise ValueError('Missing football publication health document')
    return rows[0]['document']


def main():
    parser = argparse.ArgumentParser()
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument('--file', type=Path)
    source.add_argument('--remote-readonly', action='store_true')
    args = parser.parse_args()
    result = assess(json.loads(args.file.read_text()) if args.file else remote_read())
    print(json.dumps(result))
    if os.environ.get('GITHUB_STEP_SUMMARY'):
        with open(os.environ['GITHUB_STEP_SUMMARY'], 'a') as summary:
            summary.write('## Football — collecte et publications\n\n```json\n'+json.dumps(result, indent=2)+'\n```\n')
    # GitHub's existing workflow failure notifications deliver the email.
    # No new recipient, messaging provider or sensitive data is introduced.
    return 0 if result['status'] == 'healthy' else 1


if __name__ == '__main__':
    raise SystemExit(main())
