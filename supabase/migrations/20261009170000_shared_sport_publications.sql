-- Immutable public compacts shared by native screens and the demo Generator.
-- Generic storage; sport adapters compute their own readings on the collector.
-- No football tables, existing RPCs, cron or provider budgets are changed.
create table public.sport_feed_snapshots (
 id uuid primary key default gen_random_uuid(),
 sport text not null check(sport ~ '^[a-z]+$' and sport <> 'football'),
 provider text not null, collection_id text not null,
 captured_at timestamptz not null, window_start date not null, window_end date not null,
 payload jsonb not null, overview jsonb not null,
 unique(sport,captured_at), check(window_end >= window_start)
);
create index sport_feed_snapshots_latest on public.sport_feed_snapshots(sport,captured_at desc);
alter table public.sport_feed_snapshots enable row level security;
revoke all on public.sport_feed_snapshots from public,anon,authenticated,service_role;
grant select on public.sport_feed_snapshots to service_role;

create function public.publish_sport_feed(p_payload jsonb,p_overview jsonb) returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare doc sport_feed_snapshots; item jsonb; at timestamptz; lower_day date; upper_day date;
begin
 at := (p_payload->>'capturedAt')::timestamptz;
 lower_day := (p_payload->>'windowStart')::date; upper_day := (p_payload->>'windowEnd')::date;
 if p_payload->>'schemaVersion' is distinct from '1'
  or p_payload->>'sport' is null or p_payload->>'sport' !~ '^[a-z]+$' or p_payload->>'sport'='football'
  or coalesce(p_payload->>'provider','')='' or coalesce(p_payload->>'collectionId','')=''
  or at is null or at>now() or lower_day is null or upper_day is null or upper_day<lower_day
  or jsonb_typeof(p_payload->'items') is distinct from 'array'
  or jsonb_typeof(p_payload->'competitions') is distinct from 'array'
  or p_overview->>'sport' is distinct from p_payload->>'sport'
  or p_overview->>'capturedAt' is distinct from p_payload->>'capturedAt'
  or p_overview->>'collectionId' is distinct from p_payload->>'collectionId'
  or jsonb_typeof(p_overview->'items') is distinct from 'array'
  or jsonb_array_length(p_overview->'items')<>jsonb_array_length(p_payload->'items')
  or (p_payload ? 'baseCapturedAt' and (p_payload->>'baseCapturedAt')::timestamptz>at)
 then raise exception 'Invalid shared publication'; end if;
 if exists(select 1 from jsonb_array_elements(p_payload->'items') x group by x->>'id' having count(*)>1) then
  raise exception 'Duplicate match identity'; end if;
 for item in select * from jsonb_array_elements(p_payload->'items') loop
  if coalesce(item->>'id','')='' or (item#>>'{home,id}') is null or (item#>>'{away,id}') is null
   or item#>>'{home,id}'=item#>>'{away,id}'
   or item->>'status' not in ('scheduled','live','finished','postponed','cancelled','unknown')
   or (item->>'calendarDate')::date not between lower_day and upper_day
   or (item->>'startsAt')::timestamptz is null
   or not exists(select 1 from jsonb_array_elements(p_payload->'competitions') c
     where c->>'id'=item->>'competitionId' and c->>'season'=item->>'season')
  then raise exception 'Invalid match boundary'; end if;
 end loop;
 insert into sport_feed_snapshots(sport,provider,collection_id,captured_at,window_start,window_end,payload,overview)
 values(p_payload->>'sport',p_payload->>'provider',p_payload->>'collectionId',at,lower_day,upper_day,p_payload,p_overview)
 on conflict(sport,captured_at) do nothing;
 select * into doc from sport_feed_snapshots where sport=p_payload->>'sport' and captured_at=at;
 if doc.payload<>p_payload or doc.overview<>p_overview then raise exception 'Publication version is immutable'; end if;
 return jsonb_build_object('id',doc.id,'sport',doc.sport,'capturedAt',doc.payload->>'capturedAt','matches',jsonb_array_length(doc.payload->'items'));
end $$;

-- Public compact only. A detail request pins the day's version so refreshing a
-- collection cannot silently change its histories while the user navigates.
create function public.read_sport_feed(p_sport text,p_day date default null,p_section text default 'radar',p_match text default null,p_captured_at timestamptz default null)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare doc sport_feed_snapshots; body jsonb; items jsonb; teams text[]; leagues text[];
begin
 if p_section not in ('full','radar','day','match') then raise exception 'Invalid section'; end if;
 select * into doc from sport_feed_snapshots where sport=p_sport and captured_at<=now()
  and (p_captured_at is null or captured_at=p_captured_at)
  and (p_day is null or p_day between window_start and window_end)
 order by captured_at desc limit 1;
 if not found then return null; end if;
 if p_section='full' then return doc.payload; end if;
 if p_section='radar' then return doc.overview; end if;
 body := case when p_section='match' then doc.payload else doc.overview end;
 select coalesce(jsonb_agg(f),'[]') into items from jsonb_array_elements(body->'items') f
 where (p_section='match' and f->>'id'=p_match) or (p_section='day' and (f->>'calendarDate')::date=p_day);
 if p_section='match' and jsonb_array_length(items)=0 then return null; end if;
 teams := array(select distinct team from jsonb_array_elements(items) f
  cross join lateral(values(f#>>'{home,id}'),(f#>>'{away,id}')) t(team));
 leagues := array(select distinct f->>'competitionId' from jsonb_array_elements(items) f);
 return body||jsonb_build_object('items',items,'playerRadar',coalesce(body->'playerRadar','{}')||jsonb_build_object(
  'profiles',coalesce((select jsonb_agg(x) from jsonb_array_elements(coalesce(body#>'{playerRadar,profiles}','[]')) x where x#>>'{team,id}'=any(teams)),'[]'),
  'coverage',coalesce((select jsonb_agg(x) from jsonb_array_elements(coalesce(body#>'{playerRadar,coverage}','[]')) x where x->>'teamId'=any(teams)),'[]')),
  'competitions',case when p_section='match' then coalesce((select jsonb_agg(c) from jsonb_array_elements(body->'competitions') c where c->>'id'=any(leagues)),'[]') else body->'competitions' end);
end $$;

-- One projection for all compact sport adapters. Radar pins an immutable
-- version and retains exact history IDs; ordinary views read the fresh head.
create function public.lector_generator_published_sources(p_date date,p_timezone text,p_sports text[],p_competitions text[] default null,p_readings text[] default null,p_radar jsonb default null)
returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
 with chosen as materialized (
  select distinct on(sport) id,sport,captured_at,overview||'{}'::jsonb body
  from sport_feed_snapshots where sport=any(p_sports) and window_start<=p_date and window_end>=p_date and captured_at<=now()
   and (case when p_radar is null then captured_at>now()-interval '36 hours'
    else captured_at=(p_radar->sport->>'capturedAt')::timestamptz end)
  order by sport,captured_at desc
 ), day as materialized (
  select *,coalesce((select jsonb_agg(f) from jsonb_array_elements(body->'items') f
   where ((f->>'startsAt')::timestamptz at time zone p_timezone)::date=p_date
   and (p_competitions is null or f->>'competitionId'=any(p_competitions)
    or (sport||':'||(body->>'provider')||':competition:'||(f->>'competitionId'))=any(p_competitions))
   and (p_radar is null or exists(select 1 from jsonb_array_elements(coalesce(p_radar->sport->'teams','[]')||coalesce(p_radar->sport->'players','[]')) m
    where m->>'teamId' in (f#>>'{home,id}',f#>>'{away,id}')))
   and (p_readings is null or exists(select 1 from jsonb_array_elements(coalesce(f->'readings','[]')) r where r->>'id'=any(p_readings)))),'[]') items
  from chosen
 ) select coalesce(jsonb_agg(jsonb_build_object('id',id::text,'sport',sport,'capturedAt',body->>'capturedAt','payload',jsonb_build_object(
  'items',items,'readingRulesVersion',body->'readingRulesVersion',
  'playerRadar',jsonb_build_object('profiles',coalesce((select jsonb_agg(x) from jsonb_array_elements(coalesce(body#>'{playerRadar,profiles}','[]')) x
   where p_radar is null or exists(select 1 from jsonb_array_elements(coalesce(p_radar->sport->'teams','[]')||coalesce(p_radar->sport->'players','[]')) m where m->>'teamId'=x#>>'{team,id}')),'[]')),
  'competitions',coalesce((select jsonb_agg(jsonb_build_object('id',c->'id','formPhaseVerified',c->'formPhaseVerified','tables',
   coalesce((select jsonb_agg(jsonb_build_object('rows',coalesce((select jsonb_agg(jsonb_build_object('team',r->'team','formHistory',r->'formHistory'))
    from jsonb_array_elements(coalesce(t->'rows','[]')) r where p_radar is null or exists(select 1 from jsonb_array_elements(coalesce(p_radar->sport->'teams','[]')||coalesce(p_radar->sport->'players','[]')) m where m->>'teamId'=r#>>'{team,id}')),'[]')))
    from jsonb_array_elements(coalesce(c->'tables','[]')) t),'[]')))
    from jsonb_array_elements(coalesce(body->'competitions','[]')) c),'[]')))),'[]') from day;
$$;

-- Keep the football reader unchanged. These new entry points are selected by
-- the workshop backend only; the production Generator is not redeployed.
create function public.lector_generator_shared_sources(p_date date,p_timezone text,p_sports text[],p_competitions text[] default null,p_readings text[] default null,p_scenarios text[] default null)
returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
 select (case when 'football'=any(p_sports) then public.lector_generator_sources_filtered(p_date,p_timezone,array['football'],p_competitions,p_readings,p_scenarios) else '[]'::jsonb end)
 ||public.lector_generator_published_sources(p_date,p_timezone,p_sports,p_competitions,p_readings,null);
$$;
create function public.lector_generator_shared_radar_sources(p_date date,p_timezone text,p_radar jsonb)
returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
 select public.lector_generator_radar_sources(p_date,p_timezone,case when p_radar ? 'football' then jsonb_build_object('football',p_radar->'football') else '{}'::jsonb end)
 ||public.lector_generator_published_sources(p_date,p_timezone,array(select jsonb_object_keys(p_radar)),null,null,p_radar);
$$;
revoke all on function public.publish_sport_feed(jsonb,jsonb),public.read_sport_feed(text,date,text,text,timestamptz),public.lector_generator_published_sources(date,text,text[],text[],text[],jsonb),public.lector_generator_shared_sources(date,text,text[],text[],text[],text[]),public.lector_generator_shared_radar_sources(date,text,jsonb) from public,anon,authenticated;
grant execute on function public.publish_sport_feed(jsonb,jsonb),public.read_sport_feed(text,date,text,text,timestamptz),public.lector_generator_published_sources(date,text,text[],text[],text[],jsonb),public.lector_generator_shared_sources(date,text,text[],text[],text[],text[]),public.lector_generator_shared_radar_sources(date,text,jsonb) to service_role;
grant execute on function public.read_sport_feed(text,date,text,text,timestamptz) to anon,authenticated;
notify pgrst, 'reload schema';
