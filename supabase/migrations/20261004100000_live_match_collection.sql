-- Incomplete player event coverage is not a contradicted reading.
create or replace function public.match_reading_verdict(
  p_outcome_rule text,
  p_subject_side text,
  p_status text,
  p_home_goals integer,
  p_away_goals integer,
  p_halftime_home_goals integer default null,
  p_halftime_away_goals integer default null,
  p_player_id integer default null,
  p_source_payload jsonb default '{}'::jsonb
)
returns text
language plpgsql
immutable
set search_path = public
as $$
declare
  second_half_home integer;
  second_half_away integer;
  player_is_decisive boolean;
begin
  if p_outcome_rule is null then return 'context_only'; end if;
  if p_status <> 'FT' or p_home_goals is null or p_away_goals is null then
    return 'not_evaluable';
  end if;
  if p_outcome_rule = 'over_25' then return case when p_home_goals + p_away_goals >= 3 then 'confirmed' else 'contradicted' end; end if;
  if p_outcome_rule = 'under_25' then return case when p_home_goals + p_away_goals <= 2 then 'confirmed' else 'contradicted' end; end if;
  if p_outcome_rule = 'btts' then return case when p_home_goals > 0 and p_away_goals > 0 then 'confirmed' else 'contradicted' end; end if;
  if p_outcome_rule = 'team_win' then return case when (p_subject_side = 'home' and p_home_goals > p_away_goals) or (p_subject_side = 'away' and p_away_goals > p_home_goals) then 'confirmed' else 'contradicted' end; end if;
  if p_outcome_rule = 'team_not_lose' then return case when (p_subject_side = 'home' and p_home_goals >= p_away_goals) or (p_subject_side = 'away' and p_away_goals >= p_home_goals) then 'confirmed' else 'contradicted' end; end if;
  if p_outcome_rule = 'team_loss' then return case when (p_subject_side = 'home' and p_home_goals < p_away_goals) or (p_subject_side = 'away' and p_away_goals < p_home_goals) then 'confirmed' else 'contradicted' end; end if;
  if p_outcome_rule = 'team_scores' then return case when (p_subject_side = 'home' and p_home_goals > 0) or (p_subject_side = 'away' and p_away_goals > 0) then 'confirmed' else 'contradicted' end; end if;
  if p_outcome_rule = 'team_no_score' then return case when (p_subject_side = 'home' and p_home_goals = 0) or (p_subject_side = 'away' and p_away_goals = 0) then 'confirmed' else 'contradicted' end; end if;
  if p_outcome_rule = 'team_clean_sheet' then return case when (p_subject_side = 'home' and p_away_goals = 0) or (p_subject_side = 'away' and p_home_goals = 0) then 'confirmed' else 'contradicted' end; end if;
  if p_outcome_rule = 'team_concedes' then return case when (p_subject_side = 'home' and p_away_goals > 0) or (p_subject_side = 'away' and p_home_goals > 0) then 'confirmed' else 'contradicted' end; end if;
  -- Player results require goals/assists from the final provider payload.
  if p_outcome_rule = 'player_decisive' then
    if p_player_id is null or not coalesce((p_source_payload#>>'{computed,player_events_complete}')::boolean, jsonb_array_length(coalesce(p_source_payload->'final_events','[]'::jsonb))>0) then return 'not_evaluable'; end if;
    player_is_decisive := coalesce(p_source_payload #>> array['computed','player_decisive', coalesce(p_player_id::text, '')], 'false')::boolean;
    return case when player_is_decisive then 'confirmed' else 'contradicted' end;
  end if;
  if p_halftime_home_goals is null or p_halftime_away_goals is null then return 'not_evaluable'; end if;
  if p_outcome_rule = 'first_half_scores' then return case when (p_subject_side = 'home' and p_halftime_home_goals > 0) or (p_subject_side = 'away' and p_halftime_away_goals > 0) then 'confirmed' else 'contradicted' end; end if;
  if p_outcome_rule = 'first_half_concedes' then return case when (p_subject_side = 'home' and p_halftime_away_goals > 0) or (p_subject_side = 'away' and p_halftime_home_goals > 0) then 'confirmed' else 'contradicted' end; end if;
  second_half_home := p_home_goals - p_halftime_home_goals;
  second_half_away := p_away_goals - p_halftime_away_goals;
  if p_outcome_rule = 'second_half_scores' then return case when (p_subject_side = 'home' and second_half_home > 0) or (p_subject_side = 'away' and second_half_away > 0) then 'confirmed' else 'contradicted' end; end if;
  if p_outcome_rule = 'second_half_concedes' then return case when (p_subject_side = 'home' and second_half_away > 0) or (p_subject_side = 'away' and second_half_home > 0) then 'confirmed' else 'contradicted' end; end if;
  return 'not_evaluable';
end;
$$;

-- Lightweight live overlay. Daily raw -> compact -> public snapshots remain intact.
-- Installing this migration does NOT activate external API calls.
create table public.match_live_configuration (
  singleton boolean primary key default true check(singleton),
  enabled boolean not null default false,
  stage_token uuid, lease_until timestamptz,
  last_started_at timestamptz, last_completed_at timestamptz,
  last_success_at timestamptz, last_error text,
  requests_last_run integer not null default 0,
  requests_total bigint not null default 0
);
insert into public.match_live_configuration(singleton) values(true);
create table public.match_live_runs (
  id uuid primary key, started_at timestamptz not null default now(), finished_at timestamptz,
  status text not null default 'running' check(status in ('running','succeeded','deferred','failed','cancelled')),
  provider_requests integer not null default 0, fixture_count integer not null default 0, error_message text
);
create table public.match_live_states (
  fixture_id integer primary key check(fixture_id>0), league_id integer not null,
  fixture_date date not null, kickoff_at timestamptz not null,
  home_team_name text not null, away_team_name text not null,
  status text not null default 'NS', elapsed integer, extra integer,
  home_goals integer check(home_goals>=0), away_goals integer check(away_goals>=0),
  captured_at timestamptz, result_snapshot_id uuid references public.match_result_snapshots(id),
  readings jsonb not null default '[]'::jsonb,
  next_check_at timestamptz not null default now(), checked_at timestamptz,
  final_checks integer not null default 0
);
create index match_live_states_due on public.match_live_states(next_check_at,kickoff_at);
create index match_live_states_date on public.match_live_states(fixture_date);
alter table public.match_live_states enable row level security;
alter table public.match_live_states force row level security;
create policy match_live_public_read on public.match_live_states for select to anon,authenticated using(true);
grant select on public.match_live_states to anon,authenticated;
grant all on public.match_live_states,public.match_live_configuration,public.match_live_runs to service_role;
alter table public.match_live_configuration enable row level security;
alter table public.match_live_configuration force row level security;
alter table public.match_live_runs enable row level security;
alter table public.match_live_runs force row level security;
revoke all on public.match_live_configuration,public.match_live_runs from anon,authenticated;

-- Runs are leased independently from the full daily pipeline, but every API
-- request uses reserve_api_football_request's shared atomic quota reservation.
create function public.match_live_claim() returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare cfg match_live_configuration; tok uuid; ids integer[];
begin
  select * into cfg from match_live_configuration where singleton for update;
  if not cfg.enabled or cfg.lease_until>now() or date_trunc('minute',cfg.last_started_at)=date_trunc('minute',now()) then return '{}'::jsonb; end if;
  if cfg.stage_token is not null then
    update match_live_runs set status='failed',finished_at=now(),error_message='Collecteur interrompu avant confirmation de fin ; reprise automatique.'
    where id=cfg.stage_token and status='running';
  end if;
  tok:=gen_random_uuid();
  update match_live_configuration set stage_token=tok,lease_until=now()+interval '90 seconds',last_started_at=now() where singleton;
  insert into match_live_runs(id) values(tok);
  delete from match_live_runs where started_at<now()-interval '14 days';
  delete from match_live_states where fixture_date<(now() at time zone 'Europe/Paris')::date-30;
  -- Recover fixtures missed during a previous outage. Future NS fixtures never
  -- receive an invented 0-0. The latest calendar controls kickoff postponements.
  insert into match_live_states(fixture_id,league_id,fixture_date,kickoff_at,home_team_name,away_team_name,next_check_at)
  select distinct on(f.api_football_fixture_id) f.api_football_fixture_id,f.api_football_league_id,
    f.fixture_date,f.kickoff_at,f.home_team_name,f.away_team_name,f.kickoff_at
  from match_feed_snapshot_fixtures f join ops_competitions c on c.league_id=f.api_football_league_id and c.enabled
  where f.api_football_fixture_id is not null and f.kickoff_at is not null
    and f.fixture_date between (now() at time zone 'Europe/Paris')::date-7 and (now() at time zone 'Europe/Paris')::date+3
  order by f.api_football_fixture_id,f.created_at desc
  on conflict(fixture_id) do update set kickoff_at=excluded.kickoff_at,fixture_date=excluded.fixture_date
    where match_live_states.status not in ('FT','AET','PEN')
      and (match_live_states.kickoff_at is distinct from excluded.kickoff_at or match_live_states.fixture_date is distinct from excluded.fixture_date);
  select array_agg(league_id order by league_id) into ids from ops_competitions where enabled;
  return jsonb_build_object('token',tok,'league_ids',coalesce(ids,'{}'), 'fixture_ids',coalesce((
    select jsonb_agg(fixture_id) from (
      select l.fixture_id from match_live_states l join ops_competitions c on c.league_id=l.league_id and c.enabled
      where l.next_check_at<=now() and l.kickoff_at<=now()+interval '5 minutes'
        and l.kickoff_at>=now()-interval '7 days'
      order by case when (l.status in ('1H','HT','2H','ET','BT','P','LIVE') and l.captured_at<now()-interval '90 seconds')
        or (l.status in ('FT','AET','PEN') and l.result_snapshot_id is null) then 0 else 1 end,l.next_check_at,l.fixture_id limit 20
    ) due
  ),'[]'::jsonb));
end $$;
create function public.match_live_checkpoint(p_token uuid) returns boolean
language sql security definer set search_path=public,pg_temp as $$
 select exists(select 1 from match_live_configuration where singleton and enabled and stage_token=p_token and lease_until>now());
$$;

-- Deduplicate repeated snapshot publications of the same prematch reading.
create function public.match_live_readings(p_fixture integer) returns jsonb
language sql stable security invoker set search_path=public,pg_temp as $$
 select coalesce(jsonb_agg(to_jsonb(b) order by b.reading_label),'[]'::jsonb) from (
   select distinct on(reading_id,subject_side,coalesce(player_id,-1),announcement_kind) *
   from match_reading_bilan where fixture_id=p_fixture
   order by reading_id,subject_side,coalesce(player_id,-1),announcement_kind,announced_at desc,announcement_id desc
 ) b;
$$;
-- The existing immutable-result evaluator runs first (alphabetical trigger order).
-- Publish the exact evaluation belonging to the latest result, including a
-- corrected result. Keeping the previous result hash in the new hash allows
-- corrections to revert to a score previously seen without losing an audit row.
create function public.match_live_refresh_result() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
begin
  insert into match_live_states(fixture_id,league_id,fixture_date,kickoff_at,home_team_name,away_team_name,status,
    home_goals,away_goals,captured_at,result_snapshot_id,readings,next_check_at)
  values(new.fixture_id,new.league_id,new.fixture_date,new.kickoff_at,new.home_team_name,new.away_team_name,new.status,
    new.home_goals,new.away_goals,new.captured_at,new.id,
    match_live_readings(new.fixture_id),now()+interval '5 minutes')
  on conflict(fixture_id) do update set status=excluded.status,home_goals=excluded.home_goals,away_goals=excluded.away_goals,
    captured_at=excluded.captured_at,result_snapshot_id=excluded.result_snapshot_id,readings=excluded.readings,
    elapsed=null,extra=null,next_check_at=least(match_live_states.next_check_at,excluded.next_check_at)
  where match_live_states.captured_at is null or match_live_states.captured_at<=excluded.captured_at;
  return new;
end $$;
create trigger z_match_live_refresh_after_result after insert on public.match_result_snapshots
for each row execute function public.match_live_refresh_result();
-- A late import of an announcement is still evaluated by the existing trigger.
create function public.match_live_refresh_announcement() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
begin
 update match_live_states l set readings=match_live_readings(new.fixture_id)
 where l.fixture_id=new.fixture_id and l.result_snapshot_id is not null;
 return new;
end $$;
create trigger z_match_live_refresh_after_announcement after insert on public.match_reading_announcements
for each row execute function public.match_live_refresh_announcement();

create function public.match_live_publish(p_token uuid,p_states jsonb,p_results jsonb,p_checked integer[],p_requests integer,p_deferred boolean default false,p_issue text default null)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare s jsonb; r jsonb; prev match_result_snapshots; result_hash text; count_fixtures integer:=0;
begin
 perform 1 from match_live_configuration where singleton and enabled and stage_token=p_token and lease_until>now() for update;
 if not found then raise exception 'Live lease revoked or expired'; end if;
 if jsonb_array_length(p_states)>2000 or jsonb_array_length(p_results)>20 or cardinality(p_checked)>20 then raise exception 'Live payload exceeds bounded batch'; end if;
 for s in select value from jsonb_array_elements(p_states) loop
   if not exists(select 1 from ops_competitions where league_id=(s->>'league_id')::int and enabled) then continue; end if;
   insert into match_live_states(fixture_id,league_id,fixture_date,kickoff_at,home_team_name,away_team_name,status,elapsed,extra,home_goals,away_goals,captured_at)
   values((s->>'fixture_id')::int,(s->>'league_id')::int,(s->>'fixture_date')::date,(s->>'kickoff_at')::timestamptz,
    s->>'home_team_name',s->>'away_team_name',s->>'status',(s->>'elapsed')::int,(s->>'extra')::int,
    (s->>'home_goals')::int,(s->>'away_goals')::int,(s->>'captured_at')::timestamptz)
   on conflict(fixture_id) do update set status=excluded.status,elapsed=excluded.elapsed,extra=excluded.extra,
    home_goals=coalesce(excluded.home_goals,match_live_states.home_goals),away_goals=coalesce(excluded.away_goals,match_live_states.away_goals),captured_at=excluded.captured_at,
    kickoff_at=excluded.kickoff_at,fixture_date=excluded.fixture_date,
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

create function public.match_live_fail(p_token uuid,p_error text,p_requests integer) returns void
language plpgsql security definer set search_path=public,pg_temp as $$
begin
 update match_live_configuration set stage_token=null,lease_until=null,last_completed_at=now(),last_error=left(p_error,1600),
   requests_last_run=p_requests,requests_total=requests_total+p_requests where singleton and stage_token=p_token;
 update match_live_runs set finished_at=now(),status='failed',provider_requests=p_requests,error_message=left(p_error,1600)
 where id=p_token and status='running';
end $$;
create function public.match_live_set_enabled(p_enabled boolean) returns void
language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if p_enabled and not exists(select 1 from ops_configuration where length(base_url)>0 and length(sync_secret)>0) then
   raise exception 'Configure operations before enabling live collection'; end if;
 update match_live_runs set status='cancelled',finished_at=now(),error_message='Collecte interrompue par désactivation.' where status='running' and id=(select stage_token from match_live_configuration where singleton);
 update match_live_configuration set enabled=p_enabled,stage_token=null,lease_until=null where singleton;
end $$;
create function public.match_live_tick() returns void
language plpgsql security definer set search_path=public,pg_temp as $$
declare cfg ops_configuration;
begin
 if not exists(select 1 from match_live_configuration where enabled and (lease_until is null or lease_until<=now())) then return; end if;
 select * into cfg from ops_configuration where singleton;
 if cfg.base_url is null then return; end if;
 perform net.http_post(url:=rtrim(cfg.base_url,'/')||'/functions/v1/sync-live-matches',
   headers:=jsonb_build_object('Content-Type','application/json','Authorization','Bearer '||cfg.sync_secret),body:='{}'::jsonb,timeout_milliseconds:=55000);
end $$;
-- A bounded public read for the currently mounted cards. No API-Football key
-- or server control/diagnostic fields are exposed to browser clients.
create function public.match_live_for_fixtures(p_ids integer[]) returns jsonb
language sql stable security invoker set search_path=public,pg_temp as $$
 select coalesce(jsonb_agg(row),'[]'::jsonb) from (
   select to_jsonb(l) row from match_live_states l where fixture_id=any(p_ids[1:500])
   union all
   select jsonb_build_object('fixture_id',r.fixture_id,'status',r.status,'home_goals',r.home_goals,
     'away_goals',r.away_goals,'captured_at',r.captured_at,'readings',match_live_readings(r.fixture_id))
   from (select distinct on(fixture_id) * from match_result_snapshots
     where fixture_id=any(p_ids[1:500]) order by fixture_id,captured_at desc,created_at desc,id desc) r
   where not exists(select 1 from match_live_states l where l.fixture_id=r.fixture_id)
 ) data;
$$;
revoke all on function public.match_live_for_fixtures(integer[]) from public;
revoke all on function public.match_live_readings(integer) from public;
grant execute on function public.match_live_readings(integer) to anon,authenticated,service_role;
grant execute on function public.match_live_for_fixtures(integer[]) to anon,authenticated,service_role;
do $$ declare f record; begin
 for f in select oid::regprocedure sig from pg_proc where pronamespace='public'::regnamespace
   and proname in ('match_live_claim','match_live_checkpoint','match_live_publish','match_live_fail','match_live_set_enabled','match_live_tick','match_live_refresh_result','match_live_refresh_announcement') loop
  execute format('revoke all on function %s from public,anon,authenticated',f.sig);
  execute format('grant execute on function %s to service_role',f.sig);
 end loop;
 if exists(select 1 from pg_publication where pubname='supabase_realtime') and not exists(
   select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='match_live_states') then
  alter publication supabase_realtime add table public.match_live_states;
 end if;
end $$;
select cron.schedule('lector-live-matches','* * * * *','select public.match_live_tick();');
notify pgrst,'reload schema';
