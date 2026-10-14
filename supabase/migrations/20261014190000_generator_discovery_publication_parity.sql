-- Incident 14 October: catalogue discovery must not exclude stale publications.
-- Composition freshness remains enforced by buildCatalog/marketAvailability.
-- Pin latest date-covered sources; past days stop at the Paris/local day boundary.
-- No collection, odds, user data or existing legacy generator RPC is changed.
create or replace function public.lector_generator_day_manifest(
 p_date date,p_timezone text,p_sports text[],p_competitions text[] default null,
 p_readings text[] default null,p_scenarios text[] default null,p_radar jsonb default null
) returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare refs jsonb:='[]'; publications jsonb:='[]'; part jsonb; docs jsonb;
begin
 if p_date is null or p_timezone is null or coalesce(cardinality(p_sports),0)=0
  or not p_sports <@ array['football','hockey'] then raise exception 'Invalid day scope'; end if;
 -- Resolve time zones on PostgreSQL, including DST. Never use the host day.
 perform p_date::timestamp at time zone p_timezone;
 if 'football'=any(p_sports) then
  with latest as materialized (
   select distinct on(scope_key) id from match_feed_analysis_snapshots
   where window_start<=p_date and window_end>=p_date and captured_at<=now()
    and (p_date >= (now() at time zone p_timezone)::date
     or as_of < (p_date+1)::timestamp at time zone p_timezone)
   order by scope_key,as_of desc,id desc
  ), chosen as materialized (
   select id,captured_at,payload||'{}'::jsonb body from match_feed_analysis_snapshots s
   where captured_at<=now() and (
    (p_radar is null and id in(select id from latest))
    or (p_radar is not null and id::text in(select jsonb_array_elements_text(coalesce(p_radar#>'{football,sourceIds}','[]')))))
  ), matches as (
   select jsonb_build_object('key','football:'||(f#>>'{fixture,id}'),'matchId',f#>>'{fixture,id}',
    'id',id::text,'sport','football','capturedAt',captured_at) ref
   from chosen cross join lateral jsonb_array_elements(coalesce(body#>'{raw,fixtures}','[]')) f
   where ((f#>>'{fixture,date}')::timestamptz at time zone p_timezone)::date=p_date
    and (p_competitions is null or f#>>'{league,id}'=any(p_competitions))
    and (p_radar is null or exists(select 1 from jsonb_array_elements(
     coalesce(p_radar#>'{football,teams}','[]')||coalesce(p_radar#>'{football,players}','[]')) m
     where m->>'teamId' in(f#>>'{teams,home,id}',f#>>'{teams,away,id}')))
    and (p_readings is null or exists(select 1 from jsonb_array_elements(coalesce(body#>'{computed,fixtures}','[]')) a
     where a->>'fixture_id'=f#>>'{fixture,id}' and (
      exists(select 1 from jsonb_array_elements(coalesce(a->'readings','[]')) r where r->>'id'=any(p_readings))
      or exists(select 1 from jsonb_array_elements(coalesce(a->'scenarios','[]')) r where r->>'id'=any(coalesce(p_scenarios,array[]::text[]))))))
  ) select coalesce((select jsonb_agg(ref) from matches),'[]'),
   coalesce((select jsonb_agg(jsonb_build_object('id',id::text,'sport','football','capturedAt',captured_at)) from chosen),'[]')
   into part,docs;
  refs:=refs||part; publications:=publications||docs;
 end if;
 if 'hockey'=any(p_sports) then
  with chosen as materialized (
   select id,captured_at,overview||'{}'::jsonb body from sport_feed_snapshots
   where sport='hockey' and window_start<=p_date and window_end>=p_date and captured_at<=now()
    and (case when p_radar is null then
     (p_date >= (now() at time zone p_timezone)::date
      or captured_at < (p_date+1)::timestamp at time zone p_timezone)
     else captured_at=(p_radar#>>'{hockey,capturedAt}')::timestamptz end)
   order by captured_at desc,id desc limit 1
  ), matches as (
   select jsonb_build_object('key','hockey:'||(f->>'id'),'matchId',f->>'id',
    'id',id::text,'sport','hockey','capturedAt',body->>'capturedAt') ref
   from chosen cross join lateral jsonb_array_elements(coalesce(body->'items','[]')) f
   where ((f->>'startsAt')::timestamptz at time zone p_timezone)::date=p_date
    and (p_competitions is null or f->>'competitionId'=any(p_competitions)
     or ('hockey:'||(body->>'provider')||':competition:'||(f->>'competitionId'))=any(p_competitions))
    and (p_radar is null or exists(select 1 from jsonb_array_elements(
     coalesce(p_radar#>'{hockey,teams}','[]')||coalesce(p_radar#>'{hockey,players}','[]')) m
     where m->>'teamId' in(f#>>'{home,id}',f#>>'{away,id}')))
    and (p_readings is null or exists(select 1 from jsonb_array_elements(coalesce(f->'readings','[]')) r where r->>'id'=any(p_readings)))
  ) select coalesce((select jsonb_agg(ref) from matches),'[]'),
   coalesce((select jsonb_agg(jsonb_build_object('id',id::text,'sport','hockey','capturedAt',body->>'capturedAt')) from chosen),'[]')
   into part,docs;
  refs:=refs||part; publications:=publications||docs;
 end if;
 -- Overlapping football scopes can contain the same match. Pin its freshest
 -- source once; Radar still keeps all pinned publications for its histories.
 select coalesce(jsonb_agg(ref order by ref->>'key'),'[]') into refs from (
  select distinct on(r->>'key') r ref from jsonb_array_elements(refs) r
  order by r->>'key',(r->>'capturedAt')::timestamptz desc,r->>'id' desc
 ) unique_matches;
 if jsonb_array_length(refs)>3000 then raise exception 'Day scope exceeds transport capacity'; end if;
 return jsonb_build_object('version',1,'date',p_date,'timezone',p_timezone,
  'total',jsonb_array_length(refs),'sources',publications,'matches',refs);
end $$;


revoke all on function public.lector_generator_day_manifest(date,text,text[],text[],text[],text[],jsonb) from public,anon,authenticated;
grant execute on function public.lector_generator_day_manifest(date,text,text[],text[],text[],text[],jsonb) to service_role;
notify pgrst,'reload schema';

create or replace function public.lector_generator_audit_summary(p_usage jsonb)
returns jsonb language sql immutable set search_path=public,pg_temp as $$
 select jsonb_strip_nulls(jsonb_build_object(
  'release',p_usage->'release','request',p_usage->'request','responseText',p_usage->'responseText',
  'tools',p_usage->'tools','toolsTruncated',p_usage->'toolsTruncated',
  'toolsOmittedCount',p_usage->'toolsOmittedCount','consultations',p_usage->'consultations',
  'auditReports',p_usage->'auditReports','ticketRefs',p_usage->'ticketRefs',
  'interpretedIntent',p_usage->'interpretedIntent',
  'catalogSummary',p_usage->'catalogSummary',
  'ai',p_usage->'ai','timings_ms',p_usage->'timings_ms',
  'elapsed_ms',p_usage->'elapsed_ms','failure_stage',p_usage->'failure_stage',
  'failure_name',p_usage->'failure_name','failure_message',p_usage->'failure_message'
 ));
$$;

revoke all on function public.lector_generator_audit_summary(jsonb) from public,anon,authenticated;
grant execute on function public.lector_generator_audit_summary(jsonb) to service_role;
