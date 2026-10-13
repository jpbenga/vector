"""Read-only freshness alarm. No provider call, publishing or clock rewriting."""
import argparse
from datetime import datetime, timedelta, timezone
import json
import os
from pathlib import Path
import urllib.request
from zoneinfo import ZoneInfo

PROJECT = 'ednvvxxvlawaagjyshkj'
LEAGUES = {'57', '58', '35', '10', '18', '16', '47'}


def assess(document, now=None):
    now = now or datetime.now(timezone.utc)
    if now.tzinfo is None:
        raise ValueError('An explicit audit timezone is required')
    issues = []
    ages = []
    for key in ('capturedAt', 'baseCapturedAt'):
        try:
            at = datetime.fromisoformat(str(document.get(key, document.get('capturedAt'))).replace('Z', '+00:00'))
            if at.tzinfo is None:
                raise ValueError()
            age = (now-at).total_seconds()/3600
            if age < -30/3600:
                raise ValueError()
            ages.append(age)
        except (ValueError, TypeError):
            issues.append('invalid_' + key)
    league_ids = {str(x) for x in document.get('competitionIds', [])}
    if league_ids != LEAGUES:
        issues.append('incomplete_leagues')
    today = now.astimezone(ZoneInfo('Europe/Paris')).date()
    expected = {(today+timedelta(days=i)).isoformat() for i in range(14)}
    if not document.get('windowStart', '') <= today.isoformat() or document.get('windowEnd', '') < max(expected):
        issues.append('incomplete_14_day_window')
    heads = {h['day']: h for h in document.get('heads', [])}
    missing = sorted(day for day in expected if day not in heads
                     or heads[day].get('collectionId') != document.get('collectionId')
                     or heads[day].get('capturedAt') != document.get('capturedAt'))
    if missing:
        issues.append('delivery_heads_not_current')
    age = max(ages) if len(ages) == 2 else None
    status = ('invalid' if issues else 'stale' if age > 36
              else 'critical' if age >= 30 else 'warning' if age >= 24 else 'healthy')
    return {'status': status, 'capturedAt': document.get('capturedAt'),
            'collectionId': document.get('collectionId'),
            'ageHours': None if age is None else round(age, 3),
            'parisDay': today.isoformat(), 'leagueCount': len(league_ids),
            'missingHeadDays': missing, 'issues': issues,
            'providerRequests': 0, 'paidModelCalls': 0}


def remote_read():
    token = os.environ.get('SUPABASE_ACCESS_TOKEN')
    if not token:
        raise ValueError('Missing operator token for the read-only health check')
    # Select metadata only; never select ops secrets or provider response bodies.
    sql = """select jsonb_build_object(
      'capturedAt',payload->>'capturedAt',
      'baseCapturedAt',coalesce(payload->>'baseCapturedAt',payload->>'capturedAt'),
      'collectionId',collection_id,'windowStart',window_start,'windowEnd',window_end,
      'competitionIds',(select jsonb_agg(c->>'id') from jsonb_array_elements(payload->'competitions') c),
      'heads',(select coalesce(jsonb_agg(jsonb_build_object('day',day,
        'capturedAt',manifest->>'capturedAt','collectionId',manifest->>'collectionId')),'[]')
        from sport_feed_delivery_heads where sport='hockey')
      ) as document from sport_feed_snapshots where sport='hockey'
      order by captured_at desc limit 1"""
    req = urllib.request.Request(
        f'https://api.supabase.com/v1/projects/{PROJECT}/database/query',
        data=json.dumps({'query': sql, 'read_only': True}).encode(),
        headers={'Authorization': 'Bearer '+token, 'Content-Type': 'application/json'})
    with urllib.request.urlopen(req, timeout=20) as response:
        rows = json.load(response)
    if len(rows) != 1:
        return {}
    return rows[0]['document']


def main():
    parser = argparse.ArgumentParser()
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument('--file', type=Path)
    source.add_argument('--remote-readonly', action='store_true')
    args = parser.parse_args()
    document = json.loads(args.file.read_text()) if args.file else remote_read()
    result = assess(document)
    print(json.dumps(result))
    summary = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary:
        with open(summary, 'a') as report:
            report.write('## Hockey publication health\n\n```json\n'+json.dumps(result, indent=2)+'\n```\n')
    # A failing scheduled workflow is the alert; no email, webhook or issue is sent.
    return 0 if result['status'] == 'healthy' else 1


if __name__ == '__main__':
    raise SystemExit(main())
