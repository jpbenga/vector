-- First multisport collection boundary. No cron or API call is activated here.
-- Existing football tables, RPCs and quotas remain unchanged.
create table public.sport_collection_configuration (
  sport text not null, provider text not null, competition_id text not null,
  enabled boolean not null default false,
  active_run uuid, lease_until timestamptz,
  primary key(sport, competition_id)
);
create table public.sport_provider_budgets (
  provider text primary key, daily_limit integer not null check(daily_limit>0),
  minute_limit integer not null check(minute_limit>0)
);
insert into public.sport_provider_budgets values ('api-hockey',7500,280);
insert into public.sport_collection_configuration(sport,provider,competition_id)
values('hockey','api-hockey','57');
create table public.sport_collection_runs (
  id uuid primary key default gen_random_uuid(), sport text not null,
  provider text not null, competition_id text not null,
  started_at timestamptz not null default now(), finished_at timestamptz,
  status text not null default 'running' check(status in('running','succeeded','failed')),
  provider_requests integer not null default 0, error_message text
);
create table public.sport_raw_responses (
  run_id uuid not null references public.sport_collection_runs(id),
  kind text not null, payload jsonb not null, captured_at timestamptz not null default now(),
  primary key(run_id,kind)
);
create table public.sport_provider_reservations (
  id bigint generated always as identity primary key,
  provider text not null references public.sport_provider_budgets(provider),
  run_id uuid not null references public.sport_collection_runs(id),
  reserved_at timestamptz not null default now()
);
create index sport_provider_reservations_window on public.sport_provider_reservations(provider,reserved_at);
create table public.sport_feed_publications (
  sport text not null, provider text not null, competition_id text not null,
  run_id uuid not null references public.sport_collection_runs(id),
  captured_at timestamptz not null, window_start date not null, window_end date not null,
  payload jsonb not null, primary key(sport,provider,competition_id),
  check(window_end>=window_start)
);
alter table public.sport_collection_configuration enable row level security;
alter table public.sport_provider_budgets enable row level security;
alter table public.sport_collection_runs enable row level security;
alter table public.sport_raw_responses enable row level security;
alter table public.sport_provider_reservations enable row level security;
alter table public.sport_feed_publications enable row level security;
revoke all on public.sport_collection_configuration,public.sport_provider_budgets,
  public.sport_collection_runs,public.sport_raw_responses,public.sport_provider_reservations,
  public.sport_feed_publications from public,anon,authenticated;
grant all on public.sport_collection_configuration,public.sport_provider_budgets,
  public.sport_collection_runs,public.sport_raw_responses,public.sport_provider_reservations,
  public.sport_feed_publications to service_role;
grant usage,select on sequence public.sport_provider_reservations_id_seq to service_role;
grant select on public.sport_feed_publications to anon,authenticated;
create policy sport_public_compact_read on public.sport_feed_publications
  for select to anon,authenticated using(true);

create function public.sport_collection_claim(p_sport text,p_competition text) returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare cfg sport_collection_configuration; run sport_collection_runs;
begin
  select * into cfg from sport_collection_configuration
  where sport=p_sport and competition_id=p_competition for update;
  if not found or not cfg.enabled or cfg.lease_until>now() then return '{}'::jsonb; end if;
  if cfg.active_run is not null then
    update sport_collection_runs set status='failed',finished_at=now(),error_message='Collection lease expired'
    where id=cfg.active_run and status='running';
  end if;
  insert into sport_collection_runs(sport,provider,competition_id,started_at)
  values(cfg.sport,cfg.provider,cfg.competition_id,date_trunc('milliseconds',now())) returning * into run;
  update sport_collection_configuration set active_run=run.id,lease_until=now()+interval '3 minutes'
  where sport=cfg.sport and competition_id=cfg.competition_id;
  return jsonb_build_object('run_id',run.id,'started_at',run.started_at,'provider',cfg.provider);
end $$;

create function public.reserve_sport_request(p_run uuid) returns boolean
language plpgsql security definer set search_path=public,pg_temp as $$
declare run sport_collection_runs; cfg sport_collection_configuration; budget sport_provider_budgets;
  daily_count bigint; minute_count bigint;
begin
  select * into run from sport_collection_runs where id=p_run;
  if not found or run.status<>'running' then return false; end if;
  select * into cfg from sport_collection_configuration
  where sport=run.sport and competition_id=run.competition_id for update;
  if not cfg.enabled or cfg.active_run is distinct from p_run or cfg.lease_until<=now() then return false; end if;
  -- One lock per provider subscription, across all leagues/collectors.
  select * into budget from sport_provider_budgets where provider=run.provider for update;
  if not found then return false; end if;
  select count(*) filter(where reserved_at>=date_trunc('day',now() at time zone 'UTC') at time zone 'UTC'),
         count(*) filter(where reserved_at>now()-interval '1 minute')
  into daily_count,minute_count from sport_provider_reservations
  where provider=run.provider and reserved_at>now()-interval '1 day';
  if daily_count>=budget.daily_limit or minute_count>=budget.minute_limit then return false; end if;
  insert into sport_provider_reservations(provider,run_id) values(run.provider,p_run);
  update sport_collection_runs set provider_requests=provider_requests+1 where id=p_run;
  return true;
end $$;

create function public.sport_collection_finish(p_run uuid,p_payload jsonb default null,p_error text default null)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare run sport_collection_runs; cfg sport_collection_configuration; row_item jsonb;
begin
  select * into run from sport_collection_runs where id=p_run;
  if not found or run.status<>'running' then return false; end if;
  select * into cfg from sport_collection_configuration
  where sport=run.sport and competition_id=run.competition_id for update;
  if cfg.active_run is distinct from p_run or cfg.lease_until<=now() then return false; end if;
  if p_error is null then
    if not cfg.enabled then return false; end if;
    if p_payload is null or p_payload->>'sport' is distinct from run.sport
      or p_payload->>'provider' is distinct from run.provider
      or p_payload->>'competitionId' is distinct from run.competition_id
      or p_payload->>'collectionId' is distinct from p_run::text
      or p_payload->>'schemaVersion' is distinct from '1'
      or (p_payload->>'capturedAt')::timestamptz is distinct from run.started_at
      or jsonb_typeof(p_payload->'items') is distinct from 'array'
      or not exists(select 1 from sport_raw_responses where run_id=p_run and kind='leagues')
      or not exists(select 1 from sport_raw_responses where run_id=p_run and kind='games') then
      raise exception 'Invalid or untraceable compact publication';
    end if;
    if (p_payload->>'windowStart')::date is distinct from (run.started_at at time zone 'Europe/Paris')::date-7
      or (p_payload->>'windowEnd')::date is distinct from (run.started_at at time zone 'Europe/Paris')::date+13 then
      raise exception 'Invalid publication calendar window';
    end if;
    for row_item in select * from jsonb_array_elements(p_payload->'items') loop
      if row_item->>'competitionId' is distinct from run.competition_id
        or row_item->>'season' is distinct from p_payload->>'season'
        or (row_item->>'calendarDate')::date not between (p_payload->>'windowStart')::date and (p_payload->>'windowEnd')::date then
        raise exception 'Fixture crossed publication boundary';
      end if;
    end loop;
    insert into sport_feed_publications(sport,provider,competition_id,run_id,captured_at,window_start,window_end,payload)
    values(run.sport,run.provider,run.competition_id,p_run,run.started_at,(p_payload->>'windowStart')::date,(p_payload->>'windowEnd')::date,p_payload)
    on conflict(sport,provider,competition_id) do update set run_id=excluded.run_id,
      captured_at=excluded.captured_at,window_start=excluded.window_start,window_end=excluded.window_end,payload=excluded.payload;
  end if;
  update sport_collection_runs set status=case when p_error is null then 'succeeded' else 'failed' end,
    finished_at=now(),error_message=p_error where id=p_run;
  update sport_collection_configuration set active_run=null,lease_until=null
  where sport=run.sport and competition_id=run.competition_id;
  return true;
end $$;
revoke all on function public.sport_collection_claim(text,text),public.reserve_sport_request(uuid),
  public.sport_collection_finish(uuid,jsonb,text) from public,anon,authenticated;
grant execute on function public.sport_collection_claim(text,text),public.reserve_sport_request(uuid),
  public.sport_collection_finish(uuid,jsonb,text) to service_role;
notify pgrst,'reload schema';
