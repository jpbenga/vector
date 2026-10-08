-- Fetch only the requested day/sports. Keep the immutable published evidence.
create function public.lector_generator_sources_filtered(p_date date,p_timezone text,p_sports text[],p_competitions text[] default null,p_readings text[] default null,p_scenarios text[] default null)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare result jsonb:='[]'; hockey jsonb;
begin
 if 'football'=any(p_sports) then
  with latest as materialized (
   select distinct on(scope_key) id,source_snapshot_id,captured_at,league_ids
   from match_feed_analysis_snapshots
   where window_start<=p_date and window_end>=p_date
    and captured_at<=now() and captured_at>now()-interval '36 hours'
   order by scope_key,as_of desc,id desc
  ), documents as materialized (
   -- The indexed fixture list avoids opening large snapshots without a match
   -- that day. Concatenation detoasts once, before repeated JSON projections.
   select s.id,s.captured_at,s.payload||'{}'::jsonb payload
   from latest l join match_feed_analysis_snapshots s on s.id=l.id
   where (p_competitions is null or exists(select 1 from unnest(l.league_ids) league where league::text=any(p_competitions)))
    and exists(select 1 from match_feed_snapshot_fixtures f where f.snapshot_id=l.source_snapshot_id
     and f.kickoff_at>=(p_date::timestamp at time zone p_timezone)
     and f.kickoff_at<((p_date+1)::timestamp at time zone p_timezone))
  ), day as materialized (
   select id,captured_at,payload,coalesce((select jsonb_agg(x) from jsonb_array_elements(coalesce(payload#>'{raw,fixtures}','[]')) x
    where ((x#>>'{fixture,date}')::timestamptz at time zone p_timezone)::date=p_date
     and (p_competitions is null or x#>>'{league,id}'=any(p_competitions))
     and (p_readings is null or exists(select 1 from jsonb_array_elements(coalesce(payload#>'{computed,fixtures}','[]')) a
      where a->>'fixture_id'=x#>>'{fixture,id}' and (
       exists(select 1 from jsonb_array_elements(coalesce(a->'readings','[]')) r where r->>'id'=any(p_readings))
       or exists(select 1 from jsonb_array_elements(coalesce(a->'scenarios','[]')) r where r->>'id'=any(coalesce(p_scenarios,array[]::text[])))
      )))),'[]') fixtures
   from documents
  ), relevant as materialized (
   select *,array(select x#>>'{fixture,id}' from jsonb_array_elements(fixtures) x) fixture_ids,
    array(select distinct team from jsonb_array_elements(fixtures) x cross join lateral (values(x#>>'{teams,home,id}'),(x#>>'{teams,away,id}')) t(team)) team_ids
   from day where jsonb_array_length(fixtures)>0
  )
  select coalesce(jsonb_agg(jsonb_build_object('id',id::text,'sport','football','capturedAt',captured_at,'payload',
   jsonb_build_object('raw',jsonb_build_object('fixtures',fixtures,
    'odds',coalesce((select jsonb_agg(jsonb_build_object('fixture',x->'fixture','update',x->'update','bookmakers',
     coalesce((select jsonb_agg(jsonb_build_object('id',b->'id','name',b->'name','bets',
      coalesce((select jsonb_agg(bet) from jsonb_array_elements(coalesce(b->'bets','[]')) bet where bet->>'id' in ('1','5','8','12')),'[]')))
      from jsonb_array_elements(coalesce(x->'bookmakers','[]')) b),'[]')))
     from jsonb_array_elements(coalesce(payload#>'{raw,odds}','[]')) x where x#>>'{fixture,id}'=any(fixture_ids)),'[]'),
    'player_form_radar',coalesce((select jsonb_agg(jsonb_build_object('player',x->'player','team',x->'team','activity',
     coalesce((select jsonb_agg(jsonb_build_object('played_at',a->'played_at','goals',a->'goals','assists',a->'assists'))
      from jsonb_array_elements(coalesce(x->'activity','[]')) a),'[]')))
     from jsonb_array_elements(coalesce(payload#>'{raw,player_form_radar}','[]')) x where x#>>'{team,id}'=any(team_ids)),'[]')),
    'computed',jsonb_build_object('fixtures',coalesce((select jsonb_agg(jsonb_build_object('fixture_id',x->'fixture_id','readings',x->'readings','scenarios',x->'scenarios'))
     from jsonb_array_elements(coalesce(payload#>'{computed,fixtures}','[]')) x where x->>'fixture_id'=any(fixture_ids)),'[]'))))),'[]')
   into result from relevant;
 end if;
 if 'hockey'=any(p_sports) and to_regclass('public.sport_feed_publications') is not null then
  execute $hockey$
   with latest as materialized(select run_id,captured_at,payload from public.sport_feed_publications
    where sport='hockey' and window_start<=$1 and window_end>=$1 and captured_at<=now() and captured_at>now()-interval '36 hours'),
   day as materialized(select *,coalesce((select jsonb_agg(x) from jsonb_array_elements(coalesce(payload->'items','[]')) x
    where ((x->>'startsAt')::timestamptz at time zone $2)::date=$1 and ($3 is null or x->>'competitionId'=any($3))),'[]') items from latest)
   select coalesce(jsonb_agg(jsonb_build_object('id',run_id::text,'sport','hockey','capturedAt',captured_at,'payload',
    jsonb_build_object('items',items,'playerRadar',jsonb_build_object('profiles',coalesce((select jsonb_agg(x)
     from jsonb_array_elements(coalesce(payload#>'{playerRadar,profiles}','[]')) x where x#>>'{team,id}' in
     (select i#>>'{home,id}' from jsonb_array_elements(items) i union select i#>>'{away,id}' from jsonb_array_elements(items) i)),'[]')),
     'competitions',coalesce((select jsonb_agg(jsonb_build_object('id',x->'id','formPhaseVerified',x->'formPhaseVerified'))
      from jsonb_array_elements(coalesce(payload->'competitions','[]')) x),'[]')))),'[]') from day where jsonb_array_length(items)>0
  $hockey$ into hockey using p_date,p_timezone,p_competitions;
  result:=result||hockey;
 end if;
 return result;
end $$;
-- Compatibility for the already deployed backend and read-only diagnostics.
create or replace function public.lector_generator_sources(p_date date,p_timezone text default 'Europe/Paris') returns jsonb
language sql stable security definer set search_path=public,pg_temp as $$
 select public.lector_generator_sources_filtered(p_date,p_timezone,array['football','hockey'],null);
$$;
revoke all on function public.lector_generator_sources_filtered(date,text,text[],text[],text[],text[]) from public,anon,authenticated;
grant execute on function public.lector_generator_sources_filtered(date,text,text[],text[],text[],text[]) to service_role;
notify pgrst, 'reload schema';
