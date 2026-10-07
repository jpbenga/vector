"""Read-only export of public snapshots for a remotely testable delivery demo.
No provider request, private profile, management token or server secret is used.
"""
import concurrent.futures
import datetime
import json
import os
import re
from pathlib import Path
import time
import urllib.parse
import urllib.request
from zoneinfo import ZoneInfo
ROOT=Path(__file__).resolve().parent.parent
CACHE=Path('/private/tmp/lector-public-delivery-cache')
OUTPUT=Path('/private/tmp/lector-public-delivery-sources.json')
values={}
for line in (ROOT/'.env').read_text().splitlines():
    if '=' in line and not line.lstrip().startswith('#'):
        name,value=line.split('=',1)
        if name.strip() in ('SUPABASE_URL','SUPABASE_ANON_KEY'):
            values[name.strip()]=value.strip().strip('\"\'')
base=values['SUPABASE_URL'];key=values['SUPABASE_ANON_KEY']
def timestamp(value):
    value=re.sub(r'\.(\d+)(?=[+-])',lambda m:'.'+m.group(1).ljust(6,'0')[:6],value.replace('Z','+00:00'))
    return datetime.datetime.fromisoformat(value)
def read(parameters):
    request=urllib.request.Request(base+'/rest/v1/match_feed_analysis_snapshots?'+urllib.parse.urlencode(parameters),headers={'apikey':key})
    with urllib.request.urlopen(request,timeout=45) as response:return json.load(response)
metadata=read({'select':'id,scope,scope_key,league_ids,captured_at,as_of,window_start,window_end','order':'as_of.desc','limit':'1000'})
today=datetime.datetime.now(ZoneInfo('Europe/Paris')).date();chosen=set()
for offset in range(0,14):
    day=today+datetime.timedelta(days=offset);text=day.isoformat()
    end=datetime.datetime.combine(day+datetime.timedelta(days=1),datetime.time(),ZoneInfo('Europe/Paris'))
    covered=[r for r in metadata if r['window_start']<=text<=r['window_end'] and (day>=today or timestamp(r['as_of'])<end)]
    leagues=set();global_seen=False
    for row in covered+(metadata if day>=today else []):
        if row['scope']=='global':
            if global_seen:continue
            global_seen=True
        elif row['league_ids'] and set(row['league_ids'])<=leagues:continue
        chosen.add(row['id']);leagues.update(row['league_ids'])
CACHE.mkdir(exist_ok=True)
missing=[identity for identity in chosen if not (CACHE/(identity+'.json')).exists()]
def fetch_chunk(ids):
    for attempt in range(3):
        try:
            rows=read({'select':'id,scope,scope_key,league_ids,captured_at,as_of,window_start,window_end,payload','id':'in.('+','.join(ids)+')'})
            if {r['id'] for r in rows}!=set(ids):raise RuntimeError('Incomplete public snapshot response')
            for row in rows:
                temporary=CACHE/(row['id']+'.tmp')
                temporary.write_text(json.dumps(row,separators=(',',':')))
                os.replace(temporary,CACHE/(row['id']+'.json'))
            return len(rows)
        except Exception:
            if attempt==2:raise RuntimeError('Public snapshot export failed; no partial demo is published') from None
            time.sleep(1+attempt)
chunks=[missing[i:i+5] for i in range(0,len(missing),5)]
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
    completed=0
    for count in pool.map(fetch_chunk,chunks):
        completed+=count
        print(json.dumps({'public_snapshots_downloaded':completed,'required':len(missing)}),flush=True)
rows=[json.loads((CACHE/(identity+'.json')).read_text()) for identity in chosen]
rows.sort(key=lambda r:r['as_of'],reverse=True)
OUTPUT.write_text(json.dumps(rows,separators=(',',':')))
print(json.dumps({'output':str(OUTPUT),'snapshot_count':len(rows),'bytes':OUTPUT.stat().st_size}),flush=True)
