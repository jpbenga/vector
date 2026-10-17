-- Keep exactly the API markets understood by the existing Flutter adapter.
-- Fixture identity, bookmaker ordering, prices and observation times are intact.
-- Full provider markets remain in the immutable source and lazy match detail.
create function public.compact_football_calendar_odds(p_rows jsonb,p_fixture_ids text[])
returns jsonb language sql immutable set search_path=public,pg_temp as $$
 select coalesce(jsonb_agg(case when o ? 'bookmakers' then
  (o-'bookmakers')||jsonb_build_object('bookmakers',
   (select coalesce(jsonb_agg((b-'bets')||jsonb_build_object('bets',
     (select coalesce(jsonb_agg(bet),'[]')from jsonb_array_elements(coalesce(b->'bets','[]'))bet
      where bet->>'id'=any(array['1','5','8','12','16','17','45','80','92'])))),'[]')
    from jsonb_array_elements(coalesce(o->'bookmakers','[]'))b)) else o end),'[]')
 from jsonb_array_elements(coalesce(p_rows,'[]'))o where o#>>'{fixture,id}'=any(p_fixture_ids);
$$;
revoke all on function public.compact_football_calendar_odds(jsonb,text[]) from public,anon,authenticated;
grant execute on function public.compact_football_calendar_odds(jsonb,text[]) to service_role;
create or replace function public.read_football_calendar_rows(p_day date, p_section text)
returns setof jsonb language plpgsql stable security definer
set search_path=public,pg_temp set plan_cache_mode='force_generic_plan'
set statement_timeout='15s' as $$
declare source record; body jsonb; raw_body jsonb; fixtures jsonb; fixture_ids text[];
 team_ids text[]; projected jsonb;
 today date:=(now() at time zone 'Europe/Paris')::date;
begin
 if p_day is null or p_section is null or p_section not in ('calendar','radar') then
  raise exception 'Invalid football projection';
 end if;
 for source in
  with selected as materialized (
   select distinct on(scope_key) id,scope,league_ids,captured_at,as_of,window_start,window_end
   from match_feed_analysis_snapshots
   where captured_at<=now() and as_of<=now()
    and (p_day>=today or as_of<((p_day+1)::timestamp at time zone 'Europe/Paris'))
    and (p_day>=today or window_start<=p_day and window_end>=p_day)
   order by scope_key,case when window_start<=p_day and window_end>=p_day then 0 else 1 end,as_of desc,id desc
  ) select s.*,d.payload from selected s join match_feed_analysis_snapshots d on d.id=s.id
   order by s.as_of desc,s.id desc
 loop
  -- A calendar with no covering publication is unavailable, never an invented
  -- empty date. Radar may still inspect the latest known form independently.
  if p_section='calendar' and (source.window_start>p_day or source.window_end<p_day) then continue; end if;
  -- Detoast once per selected source, never once per fixture or JSON field.
  body:=source.payload||'{}'::jsonb; raw_body:=coalesce(body->'raw','{}');
  select coalesce(jsonb_agg(f),'[]'),coalesce(array_agg(f#>>'{fixture,id}'),'{}')
   into fixtures,fixture_ids from jsonb_array_elements(coalesce(raw_body->'fixtures','[]')) f
   where (f#>>'{fixture,date}')::timestamptz at time zone 'Europe/Paris'>=p_day::timestamp
    and (f#>>'{fixture,date}')::timestamptz at time zone 'Europe/Paris'<(p_day+1)::timestamp;
  select coalesce(array_agg(distinct id),'{}') into team_ids from (
   select f#>>'{teams,home,id}' id from jsonb_array_elements(fixtures) f union all
   select f#>>'{teams,away,id}' from jsonb_array_elements(fixtures) f
  ) teams;
  projected:=jsonb_build_object(
   'fixtures',fixtures,
   'odds',public.compact_football_calendar_odds(raw_body->'odds',fixture_ids),
   'recent_league_matches',(select coalesce(jsonb_agg(r),'[]')from jsonb_array_elements(coalesce(raw_body->'recent_league_matches','[]'))r where p_section='radar' or r#>>'{team,id}'=any(team_ids)),
   'player_form_radar',(select coalesce(jsonb_agg(r),'[]')from jsonb_array_elements(coalesce(raw_body->'player_form_radar','[]'))r where p_section='radar' or r#>>'{team,id}'=any(team_ids)),
   'standings',coalesce(raw_body->'standings','[]'),
   'european_comparisons',(select coalesce(jsonb_agg(r),'[]')from jsonb_array_elements(coalesce(raw_body->'european_comparisons','[]'))r where r->>'fixtureId'=any(fixture_ids)),
   'european_card_forms',(select coalesce(jsonb_agg(r),'[]')from jsonb_array_elements(coalesce(raw_body->'european_card_forms','[]'))r where r->>'fixtureId'=any(fixture_ids))
  );
  return next jsonb_build_object(
   'id',source.id,'scope',source.scope,'league_ids',source.league_ids,
   'payload',jsonb_build_object(
    'schema_version',body->'schema_version','source',body->'source',
    'timezone',body->'timezone','captured_at',body->'captured_at',
    'window_start',p_day,'window_end',p_day,'raw',projected,
    'computed',jsonb_build_object('fixtures',
     (select coalesce(jsonb_agg(f),'[]')from jsonb_array_elements(coalesce(body#>'{computed,fixtures}','[]'))f where f->>'fixture_id'=any(fixture_ids)))
   )
  );
 end loop;
 return;
end $$;
-- PostgreSQL JSON aggregation serializes once. A JSONB aggregate rebuilds a
-- very large binary tree before PostgREST serializes it again. Wire shape stays
-- the same array; this changes no publication or client/business contract.
drop function public.read_football_calendar(date,text);
create function public.read_football_calendar(p_day date,p_section text default 'calendar')
returns json language sql stable security definer
set search_path=public,pg_temp set plan_cache_mode='force_generic_plan'
set statement_timeout='15s' as $$
 select coalesce(json_agg(projected),'[]'::json)
 from public.read_football_calendar_rows(p_day,p_section) projected;
$$;
revoke all on function public.read_football_calendar(date,text) from public;
grant execute on function public.read_football_calendar(date,text) to anon,authenticated,service_role;
notify pgrst,'reload schema';
-- Rollback: restore the row reader and JSONB wrapper from 20261017190000,
-- then drop function public.compact_football_calendar_odds(jsonb,text[]).
-- Existing immutable publications, Generator markets and conversations are unchanged.
