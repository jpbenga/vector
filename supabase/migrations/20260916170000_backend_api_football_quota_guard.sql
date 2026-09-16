-- Hard, project-wide API-Football quota guard.
--
-- The provider plan allows 7,500 requests per Europe/Paris day and 300
-- requests in any rolling 60-second window. Every provider request must first
-- reserve one slot through the RPC below. Reservations are deliberately
-- conservative: a failed HTTP request still consumes a provider slot.

create table public.api_football_request_budget_days (
  budget_date date primary key,
  request_count integer not null default 0 check (request_count >= 0),
  updated_at timestamptz not null default now()
);

create table public.api_football_request_reservations (
  id bigint generated always as identity primary key,
  sync_run_id uuid references public.api_football_sync_runs(id)
    on delete set null,
  reserved_at timestamptz not null default now()
);

create index api_football_request_reservations_reserved_at_idx
  on public.api_football_request_reservations (reserved_at desc);

alter table public.api_football_request_budget_days enable row level security;
alter table public.api_football_request_reservations enable row level security;
alter table public.api_football_request_budget_days force row level security;
alter table public.api_football_request_reservations force row level security;

revoke all on table public.api_football_request_budget_days
  from anon, authenticated;
revoke all on table public.api_football_request_reservations
  from anon, authenticated;

-- Seed the current Paris day from existing run summaries. Installing the
-- guard during an active quota day therefore cannot reset the count to zero.
insert into public.api_football_request_budget_days (
  budget_date,
  request_count,
  updated_at
)
select
  (now() at time zone 'Europe/Paris')::date,
  coalesce(sum((response_summary ->> 'cachedResponses')::integer), 0),
  now()
from public.api_football_sync_runs
where started_at >= (
  date_trunc('day', now() at time zone 'Europe/Paris')
  at time zone 'Europe/Paris'
)
on conflict (budget_date) do update
set request_count = greatest(
      public.api_football_request_budget_days.request_count,
      excluded.request_count
    ),
    updated_at = now();

create or replace function public.reserve_api_football_request(
  p_sync_run_id uuid,
  p_daily_limit integer default 7500,
  p_minute_limit integer default 300
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_now timestamptz := clock_timestamp();
  v_budget_date date := (clock_timestamp() at time zone 'Europe/Paris')::date;
  v_daily_count integer;
  v_minute_count integer;
begin
  if p_daily_limit < 1 or p_minute_limit < 1 then
    raise exception 'API-Football quota limits must be positive.';
  end if;

  -- Serialize reservations across cron and manual Edge Function runs.
  perform pg_advisory_xact_lock(hashtext('api-football-request-budget'));

  insert into public.api_football_request_budget_days (
    budget_date,
    request_count,
    updated_at
  ) values (v_budget_date, 0, v_now)
  on conflict (budget_date) do nothing;

  select request_count
  into v_daily_count
  from public.api_football_request_budget_days
  where budget_date = v_budget_date
  for update;

  select count(*)::integer
  into v_minute_count
  from public.api_football_request_reservations
  where reserved_at > v_now - interval '60 seconds';

  if v_daily_count >= p_daily_limit then
    return jsonb_build_object(
      'allowed', false,
      'reason', 'daily_limit',
      'daily_used', v_daily_count,
      'daily_remaining', 0,
      'minute_used', v_minute_count,
      'minute_remaining', greatest(p_minute_limit - v_minute_count, 0)
    );
  end if;

  if v_minute_count >= p_minute_limit then
    return jsonb_build_object(
      'allowed', false,
      'reason', 'minute_limit',
      'daily_used', v_daily_count,
      'daily_remaining', greatest(p_daily_limit - v_daily_count, 0),
      'minute_used', v_minute_count,
      'minute_remaining', 0
    );
  end if;

  update public.api_football_request_budget_days
  set request_count = request_count + 1,
      updated_at = v_now
  where budget_date = v_budget_date;

  insert into public.api_football_request_reservations (
    sync_run_id,
    reserved_at
  ) values (p_sync_run_id, v_now);

  if (v_daily_count + 1) % 100 = 0 then
    delete from public.api_football_request_reservations
    where reserved_at < v_now - interval '2 days';
  end if;

  return jsonb_build_object(
    'allowed', true,
    'reason', null,
    'daily_used', v_daily_count + 1,
    'daily_remaining', p_daily_limit - v_daily_count - 1,
    'minute_used', v_minute_count + 1,
    'minute_remaining', p_minute_limit - v_minute_count - 1
  );
end;
$$;

revoke all on function public.reserve_api_football_request(uuid, integer, integer)
  from public, anon, authenticated;
grant execute on function public.reserve_api_football_request(uuid, integer, integer)
  to service_role;

comment on function public.reserve_api_football_request(uuid, integer, integer)
  is 'Atomically reserves one API-Football request under the 7,500/day and 300/rolling-minute plan limits.';
