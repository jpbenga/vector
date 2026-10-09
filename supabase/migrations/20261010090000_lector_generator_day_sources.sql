-- Demo-only read capabilities. No collector, table, cron, user preference or
-- existing football reader is changed. A manifest pins every publication.
create function public.lector_generator_day_manifest(
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
    and captured_at>now()-interval '36 hours'
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
    and (case when p_radar is null then captured_at>now()-interval '36 hours'
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

create function public.lector_generator_day_page(p_date date,p_timezone text,p_sources jsonb,p_matches jsonb)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare result jsonb:='[]'; part jsonb;
begin
 if jsonb_typeof(p_sources) is distinct from 'array' or jsonb_typeof(p_matches) is distinct from 'array'
  or jsonb_array_length(p_sources)>150 or jsonb_array_length(p_matches) not between 1 and 50
  then raise exception 'Invalid source page'; end if;
 if exists(select 1 from jsonb_array_elements(p_matches) r where
  r->>'sport' not in('football','hockey') or r->>'matchId' !~ '^[0-9]{1,12}$'
  or r->>'key' is distinct from (r->>'sport')||':'||(r->>'matchId')
  or not exists(select 1 from jsonb_array_elements(p_sources) s where s->>'id'=r->>'id'
   and s->>'sport'=r->>'sport' and (s->>'capturedAt')::timestamptz=(r->>'capturedAt')::timestamptz))
  or exists(select 1 from jsonb_array_elements(p_matches) r group by r->>'key' having count(*)>1)
  then raise exception 'Inconsistent page identities'; end if;
 -- Missing or changed versions are errors, never a replacement by the head.
 if exists(select 1 from jsonb_array_elements(p_sources) s where
  case s->>'sport' when 'football' then not exists(select 1 from match_feed_analysis_snapshots d
   where d.id=(s->>'id')::uuid and d.captured_at=(s->>'capturedAt')::timestamptz and d.captured_at<=now())
  when 'hockey' then not exists(select 1 from sport_feed_snapshots d where d.id=(s->>'id')::uuid
   and d.sport='hockey' and d.captured_at=(s->>'capturedAt')::timestamptz and d.captured_at<=now())
  else true end) then raise exception 'Pinned publication unavailable'; end if;

 with documents as materialized (
  select d.id,d.captured_at,d.payload||'{}'::jsonb body from match_feed_analysis_snapshots d
  join jsonb_array_elements(p_sources) s on s->>'sport'='football' and d.id=(s->>'id')::uuid
 ), day as materialized (
  select *,coalesce((select jsonb_agg(f) from jsonb_array_elements(coalesce(body#>'{raw,fixtures}','[]')) f
   where f#>>'{fixture,id}' in(select r->>'matchId' from jsonb_array_elements(p_matches) r where r->>'sport'='football')
    and ((f#>>'{fixture,date}')::timestamptz at time zone p_timezone)::date=p_date),'[]') fixtures from documents
 ), teams as materialized (
  select distinct team from day cross join lateral jsonb_array_elements(fixtures) f
  cross join lateral(values(f#>>'{teams,home,id}'),(f#>>'{teams,away,id}')) t(team)
 ) select coalesce(jsonb_agg(jsonb_build_object('id',id::text,'sport','football','capturedAt',captured_at,'payload',
  jsonb_build_object('raw',jsonb_build_object('fixtures',fixtures,
   'odds',coalesce((select jsonb_agg(jsonb_build_object('fixture',x->'fixture','update',x->'update','bookmakers',
    coalesce((select jsonb_agg(jsonb_build_object('id',b->'id','name',b->'name','bets',
     coalesce((select jsonb_agg(bet) from jsonb_array_elements(coalesce(b->'bets','[]')) bet where bet->>'id' in('1','5','8','12')),'[]')))
     from jsonb_array_elements(coalesce(x->'bookmakers','[]')) b),'[]')))
    from jsonb_array_elements(coalesce(body#>'{raw,odds}','[]')) x
    where x#>>'{fixture,id}' in(select f#>>'{fixture,id}' from jsonb_array_elements(fixtures) f)),'[]'),
   'recent_league_matches',coalesce((select jsonb_agg(jsonb_build_object('team',x->'team','league',x->'league','matches',
    coalesce((select jsonb_agg(jsonb_build_object('fixture',m->'fixture','date',m->'date','result',m->'result','venue',m->'venue','opponent',m->'opponent'))
     from jsonb_array_elements(coalesce(x->'matches','[]')) m),'[]')))
    from jsonb_array_elements(coalesce(body#>'{raw,recent_league_matches}','[]')) x where x#>>'{team,id}' in(select team from teams)),'[]'),
   'player_form_radar',coalesce((select jsonb_agg(jsonb_build_object('player',x->'player','team',x->'team','league',x->'league','activity',
    coalesce((select jsonb_agg(jsonb_build_object('fixture_id',a->'fixture_id','played_at',a->'played_at','goals',a->'goals','assists',a->'assists','minutes',a->'minutes'))
     from jsonb_array_elements(coalesce(x->'activity','[]')) a),'[]')))
    from jsonb_array_elements(coalesce(body#>'{raw,player_form_radar}','[]')) x where x#>>'{team,id}' in(select team from teams)),'[]')),
   'computed',jsonb_build_object('fixtures',coalesce((select jsonb_agg(jsonb_build_object('fixture_id',x->'fixture_id','readings',x->'readings','scenarios',x->'scenarios'))
    from jsonb_array_elements(coalesce(body#>'{computed,fixtures}','[]')) x
    where x->>'fixture_id' in(select f#>>'{fixture,id}' from jsonb_array_elements(fixtures) f)),'[]'))))),'[]') into part from day;
 result:=result||part;

 with documents as materialized (
  select d.id,d.captured_at,d.overview||'{}'::jsonb body from sport_feed_snapshots d
  join jsonb_array_elements(p_sources) s on s->>'sport'='hockey' and d.id=(s->>'id')::uuid
 ), day as materialized (
  select *,coalesce((select jsonb_agg(f) from jsonb_array_elements(coalesce(body->'items','[]')) f
   where f->>'id' in(select r->>'matchId' from jsonb_array_elements(p_matches) r where r->>'sport'='hockey')
    and ((f->>'startsAt')::timestamptz at time zone p_timezone)::date=p_date),'[]') items from documents
 ), relevant as materialized (
  select *,array(select distinct team from jsonb_array_elements(items) f
   cross join lateral(values(f#>>'{home,id}'),(f#>>'{away,id}')) t(team)) teams,
   array(select distinct f->>'competitionId' from jsonb_array_elements(items) f) leagues from day
 ) select coalesce(jsonb_agg(jsonb_build_object('id',id::text,'sport','hockey','capturedAt',body->>'capturedAt','payload',
  public.with_hockey_market_quotes(jsonb_build_object('items',items,'readingRulesVersion',body->'readingRulesVersion',
   'playerRadar',jsonb_build_object('profiles',coalesce((select jsonb_agg(x) from jsonb_array_elements(coalesce(body#>'{playerRadar,profiles}','[]')) x
    where x#>>'{team,id}'=any(teams)),'[]')),
   'competitions',coalesce((select jsonb_agg(jsonb_build_object('id',c->'id','formPhaseVerified',c->'formPhaseVerified','tables',
    coalesce((select jsonb_agg(jsonb_build_object('rows',coalesce((select jsonb_agg(jsonb_build_object('team',r->'team','formHistory',r->'formHistory'))
     from jsonb_array_elements(coalesce(t->'rows','[]')) r where r#>>'{team,id}'=any(teams)),'[]')))
     from jsonb_array_elements(coalesce(c->'tables','[]')) t),'[]')))
    from jsonb_array_elements(coalesce(body->'competitions','[]')) c where c->>'id'=any(leagues)),'[]'))))),'[]') into part from relevant;
 return jsonb_build_object('sources',result||part);
end $$;

revoke all on function public.lector_generator_day_manifest(date,text,text[],text[],text[],text[],jsonb),public.lector_generator_day_page(date,text,jsonb,jsonb) from public,anon,authenticated;
grant execute on function public.lector_generator_day_manifest(date,text,text[],text[],text[],text[],jsonb),public.lector_generator_day_page(date,text,jsonb,jsonb) to service_role;
notify pgrst, 'reload schema';
