-- Exploration A/B: additive publication projection, no tables or archive lifecycle changes.
-- Preserves pinned sources, service-role ACLs, all odds and existing reading/Radar filters.
-- This migration is prepared for review only; it has not been applied remotely.
create or replace function public.lector_generator_day_page(p_date date,p_timezone text,p_sources jsonb,p_matches jsonb)
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
   -- Keep only the already-published domestic dossier for fixtures in this pinned page.
   -- Do not forward complete match details, current tables or later provider data.
   'european_comparisons',coalesce((select jsonb_agg(jsonb_build_object(
    'schemaVersion',e->'schemaVersion','fixtureId',e->'fixtureId','kickoffAt',e->'kickoffAt',
    'home',jsonb_build_object('teamId',e#>'{home,teamId}',
     'domesticCompetition',e#>'{home,domesticCompetition}','domesticObservedAt',e#>'{home,domesticObservedAt}',
     'domesticRecentMatches',e#>'{home,domesticRecentMatches}'),
    'away',jsonb_build_object('teamId',e#>'{away,teamId}',
     'domesticCompetition',e#>'{away,domesticCompetition}','domesticObservedAt',e#>'{away,domesticObservedAt}',
     'domesticRecentMatches',e#>'{away,domesticRecentMatches}')))
    from jsonb_array_elements(coalesce(body#>'{raw,european_comparisons}','[]')) e
    where e->>'fixtureId' in(select f#>>'{fixture,id}' from jsonb_array_elements(fixtures) f)),'[]'),
   'recent_league_matches',coalesce((select jsonb_agg(jsonb_build_object('team',x->'team','league',x->'league','matches',
    coalesce((select jsonb_agg(jsonb_build_object('fixture',m->'fixture','date',m->'date','result',m->'result','venue',m->'venue','opponent',m->'opponent','league',m->'league','goals',m->'goals'))
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

revoke all on function public.lector_generator_day_page(date,text,jsonb,jsonb) from public,anon,authenticated;
grant execute on function public.lector_generator_day_page(date,text,jsonb,jsonb) to service_role;
notify pgrst, 'reload schema';
