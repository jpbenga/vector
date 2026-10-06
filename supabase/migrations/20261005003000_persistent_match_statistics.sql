-- Keep post-match facts readable independently of the transient live row.
-- Optional event blocks use the existing bounded fixture ids response.
begin;
alter table public.match_live_states add column if not exists halftime_home_goals integer;
alter table public.match_live_states add column if not exists halftime_away_goals integer;
alter table public.match_live_states add column if not exists events jsonb;
alter table public.match_live_states add column if not exists events_captured_at timestamptz;
create or replace function public.match_live_publish(p_token uuid,p_states jsonb,p_results jsonb,p_checked integer[],p_requests integer,p_deferred boolean default false,p_issue text default null)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare s jsonb; r jsonb; prev match_result_snapshots; result_hash text; count_fixtures integer:=0;
begin
 perform 1 from match_live_configuration where singleton and enabled and stage_token=p_token and lease_until>now() for update;
 if not found then raise exception 'Live lease revoked or expired'; end if;
 if jsonb_array_length(p_states)>2000 or jsonb_array_length(p_results)>20 or cardinality(p_checked)>20 then raise exception 'Live payload exceeds bounded batch'; end if;
 for s in select value from jsonb_array_elements(p_states) loop
   if not exists(select 1 from ops_competitions where league_id=(s->>'league_id')::int and enabled) then continue; end if;
   insert into match_live_states(fixture_id,league_id,fixture_date,kickoff_at,home_team_name,away_team_name,status,elapsed,extra,home_goals,away_goals,captured_at,statistics,statistics_captured_at,events,events_captured_at,halftime_home_goals,halftime_away_goals)
   values((s->>'fixture_id')::int,(s->>'league_id')::int,(s->>'fixture_date')::date,(s->>'kickoff_at')::timestamptz,
    s->>'home_team_name',s->>'away_team_name',s->>'status',(s->>'elapsed')::int,(s->>'extra')::int,
    (s->>'home_goals')::int,(s->>'away_goals')::int,(s->>'captured_at')::timestamptz,
    case when jsonb_typeof(s->'statistics')='array' and jsonb_array_length(s->'statistics')>0 then s->'statistics' end,
    case when jsonb_typeof(s->'statistics')='array' and jsonb_array_length(s->'statistics')>0 then (s->>'statistics_captured_at')::timestamptz end,
    case when jsonb_typeof(s->'events')='array' then s->'events' end,
    case when jsonb_typeof(s->'events')='array' then (s->>'events_captured_at')::timestamptz end,
    (s->>'halftime_home_goals')::int,(s->>'halftime_away_goals')::int)
   on conflict(fixture_id) do update set status=excluded.status,elapsed=excluded.elapsed,extra=excluded.extra,
    home_goals=coalesce(excluded.home_goals,match_live_states.home_goals),away_goals=coalesce(excluded.away_goals,match_live_states.away_goals),captured_at=excluded.captured_at,
    kickoff_at=excluded.kickoff_at,fixture_date=excluded.fixture_date,
    statistics=coalesce(excluded.statistics,match_live_states.statistics),
    statistics_captured_at=coalesce(excluded.statistics_captured_at,match_live_states.statistics_captured_at),
    events=coalesce(excluded.events,match_live_states.events),
    events_captured_at=coalesce(excluded.events_captured_at,match_live_states.events_captured_at),
    halftime_home_goals=coalesce(excluded.halftime_home_goals,match_live_states.halftime_home_goals),
    halftime_away_goals=coalesce(excluded.halftime_away_goals,match_live_states.halftime_away_goals),
    next_check_at=case when excluded.status in ('1H','HT','2H','ET','BT','P','LIVE') then least(match_live_states.next_check_at,now()+interval '1 minute')
      when excluded.status in ('FT','AET','PEN') and match_live_states.result_snapshot_id is null then least(match_live_states.next_check_at,now())
      else match_live_states.next_check_at end
   where (match_live_states.captured_at is null or match_live_states.captured_at<=excluded.captured_at)
     and (match_live_states.status not in ('FT','AET','PEN') or excluded.status in ('FT','AET','PEN'));
   count_fixtures:=count_fixtures+1;
 end loop;
 for r in select value from jsonb_array_elements(p_results) loop
   if not exists(select 1 from ops_competitions where league_id=(r->>'league_id')::int and enabled) then continue; end if;
   select * into prev from match_result_snapshots where fixture_id=(r->>'fixture_id')::int order by captured_at desc,created_at desc,id desc limit 1;
   if prev.captured_at>(r->>'captured_at')::timestamptz then continue; end if;
   if prev.source_payload#>>'{computed,live_semantic_hash}'=r->>'content_hash' then continue; end if;
   result_hash:=encode(sha256(convert_to((r->>'content_hash')||coalesce(prev.id::text,''),'UTF8')),'hex');
   insert into match_result_snapshots(fixture_id,league_id,fixture_date,kickoff_at,status,home_team_id,away_team_id,
    home_team_name,away_team_name,home_goals,away_goals,halftime_home_goals,halftime_away_goals,score,source_payload,content_hash,captured_at)
   values((r->>'fixture_id')::int,(r->>'league_id')::int,(r->>'fixture_date')::date,(r->>'kickoff_at')::timestamptz,r->>'status',
    (r->>'home_team_id')::int,(r->>'away_team_id')::int,r->>'home_team_name',r->>'away_team_name',
    (r->>'home_goals')::int,(r->>'away_goals')::int,(r->>'halftime_home_goals')::int,(r->>'halftime_away_goals')::int,
    r->'score',r->'source_payload',result_hash,(r->>'captured_at')::timestamptz)
   on conflict(fixture_id,content_hash) do nothing;
 end loop;
 -- Rotate even an omitted ID: it cannot monopolize the first 20 slots. Unknown
 -- finals are retried, never classified as success from disappearance alone.
 update match_live_states set checked_at=now(),final_checks=case when status in ('FT','AET','PEN') then final_checks+1 else 0 end,
   next_check_at=now()+case
     when status in ('FT','AET','PEN') and result_snapshot_id is null then interval '1 minute'
     when status in ('FT','AET','PEN','CANC','ABD','AWD','WO') then
       case when final_checks=0 then interval '5 minutes' when final_checks=1 then interval '30 minutes'
         when final_checks=2 then interval '6 hours' else interval '24 hours' end
     when status in ('NS','TBD','PST') then interval '15 minutes'
     else interval '1 minute' end
 where fixture_id=any(p_checked);
 update match_live_configuration set stage_token=null,lease_until=null,last_completed_at=now(),
   last_success_at=case when p_deferred then last_success_at else now() end,
   last_error=case when p_issue is not null then left(p_issue,1600) when p_deferred then 'Collecte différée : budget partagé ou délai atteint ; reprise au prochain passage.' else null end,
   requests_last_run=p_requests,requests_total=requests_total+p_requests where singleton;
 update match_live_runs set finished_at=now(),status=case when p_deferred then 'deferred' else 'succeeded' end,
   provider_requests=p_requests,fixture_count=count_fixtures,error_message=p_issue where id=p_token;
 return jsonb_build_object('fixtures',count_fixtures,'provider_requests',p_requests,'deferred',p_deferred);
end $$;

create or replace function public.match_live_for_fixtures(p_ids integer[]) returns jsonb
language sql stable security invoker set search_path=public,pg_temp as $$
 with ids as (select distinct unnest(p_ids[1:500]) fixture_id),
 facts as (
   select i.fixture_id,l,r,
     r.id is not null and (l.fixture_id is null or l.status not in ('FT','AET','PEN') or r.captured_at>=l.captured_at) use_result
   from ids i
   left join match_live_states l using(fixture_id)
   left join lateral (select * from match_result_snapshots rs where rs.fixture_id=i.fixture_id
     order by captured_at desc,created_at desc,id desc limit 1) r on true
   where l.fixture_id is not null or r.id is not null
 ), selected as (
   select f.*,
     case when use_result then (r).status else (l).status end selected_status,
     case when use_result then (r).home_goals else (l).home_goals end selected_home,
     case when use_result then (r).away_goals else (l).away_goals end selected_away,
     case when use_result then (r).captured_at else (l).captured_at end selected_capture
   from facts f
 )
 select coalesce(jsonb_agg(
   coalesce(to_jsonb(l),'{}'::jsonb) || jsonb_build_object(
     'fixture_id',s.fixture_id,'status',selected_status,
     'home_goals',selected_home,'away_goals',selected_away,
     'halftime_home_goals',case when use_result then fh.halftime_home_goals else (l).halftime_home_goals end,
     'halftime_away_goals',case when use_result then fh.halftime_away_goals else (l).halftime_away_goals end,
     'captured_at',greatest(selected_capture,(l).captured_at),
     'elapsed',case when selected_status in ('FT','AET','PEN') then null else (l).elapsed end,
     'readings',case when selected_status in ('FT','AET','PEN') then match_live_readings(s.fixture_id) else coalesce((l).readings,'[]'::jsonb) end,
     'statistics',coalesce(fs.source_payload->'final_statistics',(l).statistics),
     'statistics_captured_at',case when fs.id is not null then fs.captured_at else (l).statistics_captured_at end,
     'statistics_is_final',fs.id is not null or (selected_status in ('FT','AET','PEN') and (l).status=selected_status and (l).statistics_captured_at>=(l).captured_at),
     'events',coalesce(fe.source_payload->'final_events',(l).events),
     'events_captured_at',case when fe.id is not null then fe.captured_at else (l).events_captured_at end
   ) order by s.fixture_id),'[]'::jsonb)
 from selected s
 left join lateral (
   select rs.halftime_home_goals,rs.halftime_away_goals from match_result_snapshots rs
   where selected_status in ('FT','AET','PEN') and rs.fixture_id=s.fixture_id
     and rs.status=selected_status and rs.home_goals=selected_home and rs.away_goals=selected_away
     and rs.halftime_home_goals is not null and rs.halftime_away_goals is not null
   order by captured_at desc,created_at desc,id desc limit 1
 ) fh on true
 left join lateral (
   select rs.* from match_result_snapshots rs
   where selected_status in ('FT','AET','PEN') and rs.fixture_id=s.fixture_id
     and rs.status=selected_status and rs.home_goals=selected_home and rs.away_goals=selected_away
     and jsonb_typeof(rs.source_payload->'final_statistics')='array'
     and jsonb_array_length(rs.source_payload->'final_statistics')>0
   order by captured_at desc,created_at desc,id desc limit 1
 ) fs on true
 left join lateral (
   select rs.* from match_result_snapshots rs
   where selected_status in ('FT','AET','PEN') and rs.fixture_id=s.fixture_id
     and rs.status=selected_status and rs.home_goals=selected_home and rs.away_goals=selected_away
     and jsonb_typeof(rs.source_payload->'final_events')='array'
     and jsonb_array_length(rs.source_payload->'final_events')>0
   order by captured_at desc,created_at desc,id desc limit 1
 ) fe on true;
$$;
commit;
