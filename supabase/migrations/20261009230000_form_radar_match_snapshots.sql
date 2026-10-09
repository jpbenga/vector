-- Record the published Radar BEFORE kickoff. No user writes or provider calls.
create table public.form_radar_match_snapshots (
 sport text not null check (sport in ('football','hockey')),
 provider text not null, fixture_id text not null,
 kickoff_at timestamptz not null, captured_at timestamptz not null,
 recorded_at timestamptz not null default now(), source_id uuid not null,
 profiles jsonb not null check (jsonb_typeof(profiles)='array'),
 primary key(sport,provider,fixture_id),
 check(captured_at < kickoff_at), check(recorded_at < kickoff_at)
);
alter table public.form_radar_match_snapshots enable row level security;
revoke all on public.form_radar_match_snapshots from public,anon,authenticated;
grant select,insert,update on public.form_radar_match_snapshots to service_role;

-- Rank eligibility is shared: the three latest team games, at least two
-- confirmed goals/assists. Older history remains unchanged in the snapshot.
create function public.form_radar_record_publication(p_sport text,p_source uuid,p_at timestamptz,p_body jsonb)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare f jsonb; players jsonb; profiles jsonb; kickoff timestamptz; fid text; home_id text; away_id text; v_provider text;
begin
 if p_sport not in ('football','hockey') or p_at is null or p_at>now() then return; end if;
 v_provider:=case when p_sport='football' then 'api-football' else 'api-hockey' end;
 players:=coalesce(case when p_sport='football' then p_body#>'{raw,player_form_radar}' else p_body#>'{playerRadar,profiles}' end,'[]');
 for f in select value from jsonb_array_elements(coalesce(case when p_sport='football' then p_body#>'{raw,fixtures}' else p_body->'items' end,'[]')) loop
  kickoff:=(case when p_sport='football' then f#>>'{fixture,date}' else f->>'startsAt' end)::timestamptz;
  fid:=case when p_sport='football' then f#>>'{fixture,id}' else f->>'id' end;
  home_id:=case when p_sport='football' then f#>>'{teams,home,id}' else f#>>'{home,id}' end;
  away_id:=case when p_sport='football' then f#>>'{teams,away,id}' else f#>>'{away,id}' end;
  if kickoff is null or fid is null or kickoff<=now() or p_at>=kickoff
   or (case when p_sport='football' then f#>>'{fixture,status,short}' not in ('NS','TBD') else f->>'status'<>'scheduled' end)
  then continue; end if;
  with candidates as (
   select p,(select max(coalesce(a->>'played_at',a->>'startsAt')::timestamptz)
    from jsonb_array_elements(coalesce(p->'activity','[]')) a) latest
   from jsonb_array_elements(players) p where p#>>'{team,id}' in(home_id,away_id)
    and (p_sport='football' or (p->>'competitionId'=f->>'competitionId' and p->>'season'=f->>'season'))
  ), current_profiles as (
   select distinct on(p#>>'{team,id}',coalesce(p#>>'{player,id}',p->>'id')) p,latest
   from candidates c where latest=(select max(c2.latest) from candidates c2 where c2.p#>>'{team,id}'=c.p#>>'{team,id}')
   order by p#>>'{team,id}',coalesce(p#>>'{player,id}',p->>'id'),latest desc,jsonb_array_length(p->'activity') desc
  ) select coalesce(jsonb_agg(p),'[]') into profiles from current_profiles
  where jsonb_array_length(p->'activity')>=3 and latest<p_at
   and not exists(select 1 from jsonb_array_elements(p->'activity') a where coalesce(a->>'played_at',a->>'startsAt')::timestamptz>=p_at or coalesce(a->>'fixture_id',a->>'id')=fid)
   and (select count(*)=3 and sum((a->>'goals')::int+(a->>'assists')::int)>=2
    from (select value a from jsonb_array_elements(p->'activity') with ordinality x(value,n) order by n desc limit 3) recent
    where a->>'goals' is not null and a->>'assists' is not null);
  insert into form_radar_match_snapshots(sport,provider,fixture_id,kickoff_at,captured_at,source_id,profiles)
  values(p_sport,v_provider,fid,kickoff,p_at,p_source,profiles)
  on conflict(sport,provider,fixture_id) do update set kickoff_at=excluded.kickoff_at,captured_at=excluded.captured_at,
   recorded_at=excluded.recorded_at,source_id=excluded.source_id,profiles=excluded.profiles
   where form_radar_match_snapshots.kickoff_at>now() and form_radar_match_snapshots.captured_at<=excluded.captured_at;
 end loop;
end $$;
revoke all on function public.form_radar_record_publication(text,uuid,timestamptz,jsonb) from public,anon,authenticated;
grant execute on function public.form_radar_record_publication(text,uuid,timestamptz,jsonb) to service_role;

create function public.form_radar_record_source() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if tg_table_name='match_feed_analysis_snapshots' then
  perform form_radar_record_publication('football',new.id,new.captured_at,new.payload);
 else
  perform form_radar_record_publication(new.sport,new.id,new.captured_at,new.payload);
 end if;
 return new;
end $$;
revoke all on function public.form_radar_record_source() from public,anon,authenticated;
create trigger form_radar_record_football after insert on public.match_feed_analysis_snapshots for each row execute function public.form_radar_record_source();
create trigger form_radar_record_hockey after insert on public.sport_feed_snapshots for each row execute function public.form_radar_record_source();

-- Compact public evidence only; no arbitrary SQL or access to private sources.
create function public.form_radar_for_fixtures(p_sport text,p_ids text[]) returns jsonb
language sql stable security definer set search_path=public,pg_temp as $$
 select coalesce(jsonb_agg(jsonb_build_object('sport',sport,'provider',provider,'fixtureId',fixture_id,
  'kickoffAt',kickoff_at,'capturedAt',captured_at,'recordedAt',recorded_at,'sourceId',source_id,'profiles',profiles)),'[]')
 from form_radar_match_snapshots where sport=p_sport and fixture_id=any(p_ids[1:500]);
$$;
revoke all on function public.form_radar_for_fixtures(text,text[]) from public;
grant execute on function public.form_radar_for_fixtures(text,text[]) to anon,authenticated,service_role;

-- Seed forthcoming matches only. Never create a retrospective prematch claim.
do $$ declare s record; begin
 for s in select distinct on(scope_key) id,captured_at,payload from match_feed_analysis_snapshots order by scope_key,captured_at desc loop
  perform form_radar_record_publication('football',s.id,s.captured_at,s.payload);
 end loop;
 for s in select distinct on(sport) id,sport,captured_at,payload from sport_feed_snapshots order by sport,captured_at desc loop
  perform form_radar_record_publication(s.sport,s.id,s.captured_at,s.payload);
 end loop;
end $$;

-- Event polling shares the existing 3,000 live / 7,500 total reservations.
create function public.hockey_radar_event_due(p_ids text[]) returns jsonb
language sql stable security definer set search_path=public,pg_temp as $$
 select coalesce(jsonb_agg(fixture_id),'[]') from (
  select l.fixture_id from sport_live_states l join form_radar_match_snapshots r
   on r.sport=l.sport and r.provider=l.provider and r.fixture_id=l.fixture_id
  where l.sport='hockey' and l.fixture_id=any(p_ids[1:500]) and jsonb_array_length(r.profiles)>0
   and (l.payload#>>'{matchEvents,collectedAt}' is null
    or (l.payload#>>'{matchEvents,collectedAt}')::timestamptz<now()-case when l.payload->>'status'='finished' and l.payload#>>'{matchEvents,isFinal}'='true' then interval '1 hour' else interval '5 minutes' end)
   and r.kickoff_at>now()-interval '24 hours'
  order by l.payload#>>'{matchEvents,collectedAt}' nulls first,l.fixture_id limit 4
 ) due;
$$;
revoke all on function public.hockey_radar_event_due(text[]) from public,anon,authenticated;
grant execute on function public.hockey_radar_event_due(text[]) to service_role;

create or replace function public.hockey_live_publish(p_token uuid,p_states jsonb,p_requests integer,p_deferred boolean default false) returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare cfg hockey_live_configuration; item jsonb; f jsonb; at timestamptz; n integer:=0;
begin
 select * into cfg from hockey_live_configuration where singleton for update;
 if not cfg.enabled or cfg.stage_token is distinct from p_token or cfg.lease_until is null or cfg.lease_until<=now() then raise exception 'Collector lease revoked'; end if;
 if jsonb_typeof(p_states)<>'array' or jsonb_array_length(p_states)>2000 or p_requests not between 0 and 7 then raise exception 'Invalid live publication'; end if;
 for item in select value from jsonb_array_elements(p_states) loop
  f:=item->'fixture'; at:=(item->>'capturedAt')::timestamptz;
  if at is null or jsonb_typeof(f) is distinct from 'object' or f->>'season' is distinct from '2026' or f->>'id' is null or f#>>'{home,id}' is null or f#>>'{away,id}' is null or f->>'status' is null or at>now()+interval '30 seconds' or at<now()-interval '2 minutes' or f->>'season'<>'2026' or f->>'id' !~ '^[0-9]+$' or f#>>'{home,id}'=f#>>'{away,id}'
     or f->>'status' not in ('scheduled','live','finished','postponed','cancelled') then raise exception 'Invalid live fixture'; end if;
  insert into sport_live_states(sport,provider,fixture_id,competition_id,fixture_date,captured_at,payload)
  values('hockey','api-hockey',f->>'id',f->>'competitionId',(f->>'calendarDate')::date,at,f)
  on conflict(sport,provider,fixture_id) do update set captured_at=excluded.captured_at,payload=excluded.payload||case when excluded.payload ? 'matchEvents' then '{}'::jsonb else jsonb_build_object('matchEvents',sport_live_states.payload->'matchEvents') end,fixture_date=excluded.fixture_date
  where sport_live_states.captured_at<=excluded.captured_at
   and sport_live_states.competition_id=excluded.competition_id
   and sport_live_states.payload->>'season'=excluded.payload->>'season'
   and sport_live_states.payload#>>'{home,id}'=excluded.payload#>>'{home,id}'
   and sport_live_states.payload#>>'{away,id}'=excluded.payload#>>'{away,id}'
   -- Scheduled status cannot undo a known final result.
   and not(sport_live_states.payload->>'status'='finished' and excluded.payload->>'status' in ('scheduled','live'));
  n:=n+1;
 end loop;
 update hockey_live_runs set finished_at=now(),status=case when p_deferred then 'deferred' else 'succeeded' end,provider_requests=p_requests,fixture_count=n where id=p_token;
 update hockey_live_configuration set stage_token=null,lease_until=null,last_completed_at=now(),last_success_at=case when p_deferred then last_success_at else now() end,last_error=case when p_deferred then 'Quota reached; latest scores retained.' else null end,requests_last_run=p_requests,requests_total=requests_total+p_requests where singleton;
 return jsonb_build_object('fixtures',n,'deferred',p_deferred);
end $$;
