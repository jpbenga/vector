-- Read the exact publications displayed by the native Radar, never the latest
-- replacement. This RPC accepts identifiers only and is service-role only.
create function public.lector_generator_radar_sources(p_date date,p_timezone text,p_radar jsonb)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare result jsonb:='[]'; hockey jsonb;
begin
 if p_radar ? 'football' then
  with requested as materialized (
   select id::uuid,ordinality n from jsonb_array_elements_text(p_radar#>'{football,sourceIds}') with ordinality r(id,ordinality)
  ), teams as materialized (
   select distinct x->>'teamId' id from jsonb_array_elements(
    coalesce(p_radar#>'{football,teams}','[]')||coalesce(p_radar#>'{football,players}','[]')) x
  ), documents as materialized (
   select s.id,s.captured_at,s.payload||'{}'::jsonb payload,r.n
   from requested r join match_feed_analysis_snapshots s on s.id=r.id where s.captured_at<=now()
  ), day as materialized (
   select *,coalesce((select jsonb_agg(f) from jsonb_array_elements(coalesce(payload#>'{raw,fixtures}','[]')) f
    where ((f#>>'{fixture,date}')::timestamptz at time zone p_timezone)::date=p_date
     and (f#>>'{teams,home,id}' in(select id from teams) or f#>>'{teams,away,id}' in(select id from teams))),'[]') fixtures
   from documents
  )
  select coalesce(jsonb_agg(jsonb_build_object('id',id::text,'sport','football','capturedAt',captured_at,'payload',
   jsonb_build_object('raw',jsonb_build_object('fixtures',fixtures,
    'odds',coalesce((select jsonb_agg(x) from jsonb_array_elements(coalesce(payload#>'{raw,odds}','[]')) x
     where x#>>'{fixture,id}' in(select f#>>'{fixture,id}' from jsonb_array_elements(fixtures) f)),'[]'),
    'recent_league_matches',coalesce((select jsonb_agg(jsonb_build_object('team',x->'team','league',x->'league','matches',
     coalesce((select jsonb_agg(jsonb_build_object('fixture',m->'fixture','date',m->'date','result',m->'result',
      'venue',m->'venue','opponent',m->'opponent')) from jsonb_array_elements(coalesce(x->'matches','[]')) m),'[]')))
     from jsonb_array_elements(coalesce(payload#>'{raw,recent_league_matches}','[]')) x where x#>>'{team,id}' in(select id from teams)),'[]'),
    'player_form_radar',coalesce((select jsonb_agg(jsonb_build_object('player',x->'player','team',x->'team','league',x->'league','activity',
     coalesce((select jsonb_agg(jsonb_build_object('fixture_id',a->'fixture_id','played_at',a->'played_at','goals',a->'goals',
      'assists',a->'assists','minutes',a->'minutes')) from jsonb_array_elements(coalesce(x->'activity','[]')) a),'[]')))
     from jsonb_array_elements(coalesce(payload#>'{raw,player_form_radar}','[]')) x where x#>>'{team,id}' in(select id from teams)),'[]')),
    'computed',jsonb_build_object('fixtures',coalesce((select jsonb_agg(jsonb_build_object('fixture_id',x->'fixture_id','readings',x->'readings','scenarios',x->'scenarios'))
     from jsonb_array_elements(coalesce(payload#>'{computed,fixtures}','[]')) x
     where x->>'fixture_id' in(select f#>>'{fixture,id}' from jsonb_array_elements(fixtures) f)),'[]')))) order by n),'[]')
   into result from day;
 end if;
 if p_radar ? 'hockey' and to_regclass('public.sport_feed_publications') is not null then
  with members as materialized (
   select distinct x->>'teamId' id from jsonb_array_elements(
    coalesce(p_radar#>'{hockey,teams}','[]')||coalesce(p_radar#>'{hockey,players}','[]')) x
  ), document as materialized (
   select run_id,captured_at,payload||'{}'::jsonb payload from sport_feed_publications
   where sport='hockey' and (payload->>'capturedAt')::timestamptz=(p_radar#>>'{hockey,capturedAt}')::timestamptz
    and captured_at<=now()
  )
  select coalesce(jsonb_agg(jsonb_build_object('id',run_id::text,'sport','hockey','capturedAt',payload->>'capturedAt','payload',
   jsonb_build_object('items',coalesce((select jsonb_agg(f) from jsonb_array_elements(coalesce(payload->'items','[]')) f
    where ((f->>'startsAt')::timestamptz at time zone p_timezone)::date=p_date
     and (f#>>'{home,id}' in(select id from members) or f#>>'{away,id}' in(select id from members))),'[]'),
    'playerRadar',jsonb_build_object('profiles',coalesce((select jsonb_agg(x) from jsonb_array_elements(coalesce(payload#>'{playerRadar,profiles}','[]')) x
     where x#>>'{team,id}' in(select id from members)),'[]')),
    'competitions',coalesce((select jsonb_agg(jsonb_build_object('id',c->'id','formPhaseVerified',c->'formPhaseVerified','tables',
     coalesce((select jsonb_agg(jsonb_build_object('rows',coalesce((select jsonb_agg(jsonb_build_object('team',r->'team','formHistory',r->'formHistory'))
      from jsonb_array_elements(coalesce(t->'rows','[]')) r where r#>>'{team,id}' in(select id from members)),'[]')))
      from jsonb_array_elements(coalesce(c->'tables','[]')) t),'[]')))
      from jsonb_array_elements(coalesce(payload->'competitions','[]')) c),'[]')))),'[]') into hockey from document;
  result:=result||hockey;
 end if;
 return result;
end $$;
revoke all on function public.lector_generator_radar_sources(date,text,jsonb) from public,anon,authenticated;
grant execute on function public.lector_generator_radar_sources(date,text,jsonb) to service_role;
notify pgrst, 'reload schema';
