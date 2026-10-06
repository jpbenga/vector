-- Hockey only: installing never enables collection or changes football tables.
create table if not exists public.sport_live_states (
  sport text not null check(sport='hockey'), provider text not null check(provider='api-hockey'),
  fixture_id text not null, competition_id text not null check(competition_id in ('57','58','35','10','18','16','47')),
  fixture_date date not null, captured_at timestamptz not null, payload jsonb not null,
  primary key(sport,provider,fixture_id)
);
create index if not exists sport_live_states_day on public.sport_live_states(sport,fixture_date);
alter table public.sport_live_states enable row level security;
alter table public.sport_live_states force row level security;
create policy sport_live_public_read on public.sport_live_states for select to anon,authenticated using(true);
revoke all on public.sport_live_states from anon,authenticated;
grant select on public.sport_live_states to anon,authenticated;
grant all on public.sport_live_states to service_role;

create table public.hockey_live_configuration (
  singleton boolean primary key default true check(singleton), enabled boolean not null default false,
  stage_token uuid, lease_until timestamptz, last_started_at timestamptz, last_completed_at timestamptz,
  last_success_at timestamptz, last_error text, requests_last_run integer not null default 0, requests_total bigint not null default 0
);
insert into public.hockey_live_configuration(singleton) values(true);
create table public.hockey_live_runs (
  id uuid primary key, started_at timestamptz not null default now(), finished_at timestamptz,
  status text not null default 'running' check(status in ('running','succeeded','deferred','failed','cancelled')),
  provider_requests integer not null default 0, fixture_count integer not null default 0, error_message text
);
create table public.hockey_api_reservations (
  id bigint generated always as identity primary key, reserved_at timestamptz not null default now(), live boolean not null
);
create index hockey_api_reservations_at on public.hockey_api_reservations(reserved_at);
alter table public.hockey_live_configuration enable row level security;
alter table public.hockey_live_configuration force row level security;
alter table public.hockey_live_runs enable row level security;
alter table public.hockey_live_runs force row level security;
alter table public.hockey_api_reservations enable row level security;
alter table public.hockey_api_reservations force row level security;
revoke all on public.hockey_live_configuration,public.hockey_live_runs,public.hockey_api_reservations from anon,authenticated;
grant all on public.hockey_live_configuration,public.hockey_live_runs,public.hockey_api_reservations to service_role;
grant usage,select on sequence public.hockey_api_reservations_id_seq to service_role;

create function public.hockey_live_set_enabled(p_enabled boolean) returns void
language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if p_enabled and not exists(select 1 from ops_configuration where singleton and base_url is not null and sync_secret is not null) then
  raise exception 'Configure operations before enabling hockey live collection';
 end if;
 update hockey_live_configuration set enabled=p_enabled,stage_token=null,lease_until=null where singleton;
 update hockey_live_runs set status='cancelled',finished_at=now() where status='running';
end $$;
create function public.hockey_live_claim() returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare cfg hockey_live_configuration; tok uuid; today date := (now() at time zone 'Europe/Paris')::date; dates jsonb;
begin
 select * into cfg from hockey_live_configuration where singleton for update;
 if not cfg.enabled or cfg.lease_until>now() or cfg.last_started_at>now()-interval '55 seconds' then return '{}'::jsonb; end if;
 if cfg.stage_token is not null then update hockey_live_runs set status='failed',finished_at=now(),error_message='Lease expired; collector recovered automatically.' where id=cfg.stage_token and status='running'; end if;
 tok:=gen_random_uuid();
 update hockey_live_configuration set stage_token=tok,lease_until=now()+interval '90 seconds',last_started_at=now() where singleton;
 insert into hockey_live_runs(id) values(tok);
 delete from hockey_live_runs where started_at<now()-interval '14 days';
 delete from sport_live_states where sport='hockey' and fixture_date<today-30;
 dates:=jsonb_build_array(today::text,(today-1)::text);
 -- One extra recovery day per hour, rotates across the preceding week.
 if extract(minute from now())=0 then dates:=dates||jsonb_build_array((today-2-(extract(hour from now())::integer % 6))::text); end if;
 return jsonb_build_object('token',tok,'dates',dates);
end $$;
create function public.hockey_live_reserve(p_token uuid,p_live boolean default true) returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare cfg hockey_live_configuration; n_day integer; n_live integer; n_minute integer;
begin
 -- Serializes reservations for both grouped live and full local collection.
 select * into cfg from hockey_live_configuration where singleton for update;
 if p_live and (not cfg.enabled or cfg.stage_token is distinct from p_token or cfg.lease_until is null or cfg.lease_until<=now()) then return jsonb_build_object('allowed',false,'reason','revoked'); end if;
 delete from hockey_api_reservations where reserved_at<now()-interval '2 days';
 select count(*),count(*) filter(where live) into n_day,n_live
 from hockey_api_reservations where reserved_at>=date_trunc('day',now() at time zone 'UTC') at time zone 'UTC';
 select count(*) into n_minute from hockey_api_reservations where reserved_at>now()-interval '60 seconds';
 -- 3000 requests/day for live, 7500 total, below provider minute threshold.
 if n_day>=7500 or (p_live and n_live>=3000) or n_minute>=200 then return jsonb_build_object('allowed',false,'reason','quota'); end if;
 insert into hockey_api_reservations(live) values(p_live);
 return jsonb_build_object('allowed',true);
end $$;
create function public.hockey_live_publish(p_token uuid,p_states jsonb,p_requests integer,p_deferred boolean default false) returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare cfg hockey_live_configuration; item jsonb; f jsonb; at timestamptz; n integer:=0;
begin
 select * into cfg from hockey_live_configuration where singleton for update;
 if not cfg.enabled or cfg.stage_token is distinct from p_token or cfg.lease_until is null or cfg.lease_until<=now() then raise exception 'Collector lease revoked'; end if;
 if jsonb_typeof(p_states)<>'array' or jsonb_array_length(p_states)>2000 or p_requests not between 0 and 3 then raise exception 'Invalid live publication'; end if;
 for item in select value from jsonb_array_elements(p_states) loop
  f:=item->'fixture'; at:=(item->>'capturedAt')::timestamptz;
  if at is null or jsonb_typeof(f) is distinct from 'object' or f->>'season' is distinct from '2026' or f->>'id' is null or f#>>'{home,id}' is null or f#>>'{away,id}' is null or f->>'status' is null or at>now()+interval '30 seconds' or at<now()-interval '2 minutes' or f->>'season'<>'2026' or f->>'id' !~ '^[0-9]+$' or f#>>'{home,id}'=f#>>'{away,id}'
     or f->>'status' not in ('scheduled','live','finished','postponed','cancelled') then raise exception 'Invalid live fixture'; end if;
  insert into sport_live_states(sport,provider,fixture_id,competition_id,fixture_date,captured_at,payload)
  values('hockey','api-hockey',f->>'id',f->>'competitionId',(f->>'calendarDate')::date,at,f)
  on conflict(sport,provider,fixture_id) do update set captured_at=excluded.captured_at,payload=excluded.payload,fixture_date=excluded.fixture_date
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
create function public.hockey_live_fail(p_token uuid,p_error text,p_requests integer) returns void
language plpgsql security definer set search_path=public,pg_temp as $$
begin
 perform 1 from hockey_live_configuration where singleton and stage_token=p_token for update;
 if not found then return; end if;
 update hockey_live_runs set status='failed',finished_at=now(),error_message=left(p_error,500),provider_requests=p_requests where id=p_token;
 update hockey_live_configuration set stage_token=null,lease_until=null,last_completed_at=now(),last_error=left(p_error,500),requests_last_run=p_requests,requests_total=requests_total+p_requests where singleton;
end $$;
create function public.hockey_live_tick() returns void
language plpgsql security definer set search_path=public,pg_temp as $$
declare cfg ops_configuration;
begin
 if not exists(select 1 from hockey_live_configuration where enabled and (lease_until is null or lease_until<=now())) then return; end if;
 select * into cfg from ops_configuration where singleton;
 if cfg.base_url is null or cfg.sync_secret is null then return; end if;
 perform net.http_post(url:=rtrim(cfg.base_url,'/')||'/functions/v1/sync-hockey-live',headers:=jsonb_build_object('Content-Type','application/json','Authorization','Bearer '||cfg.sync_secret),body:='{}'::jsonb,timeout_milliseconds:=55000);
end $$;
do $$ declare f record; begin
 for f in select oid::regprocedure sig from pg_proc where pronamespace='public'::regnamespace and proname in ('hockey_live_claim','hockey_live_reserve','hockey_live_publish','hockey_live_fail','hockey_live_set_enabled','hockey_live_tick') loop
  execute format('revoke all on function %s from public,anon,authenticated',f.sig);
  execute format('grant execute on function %s to service_role',f.sig);
 end loop;
end $$;
select cron.schedule('lector-hockey-live','* * * * *','select public.hockey_live_tick();');
notify pgrst,'reload schema';
