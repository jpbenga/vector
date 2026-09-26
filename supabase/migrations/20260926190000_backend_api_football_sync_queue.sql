-- A single durable queue for every API-Football collection request.
-- Cron only enqueues work; one worker claims and processes one league at a
-- time. This prevents a manual run, the rolling refresh, and enrichment jobs
-- from calling the provider concurrently.

create table public.api_football_sync_queue_jobs (
  id uuid primary key default gen_random_uuid(),
  dedupe_key text not null unique,
  payload jsonb not null check (jsonb_typeof(payload) = 'object'),
  status text not null default 'queued'
    check (status in ('queued', 'running', 'retrying', 'succeeded', 'failed', 'cancelled')),
  priority integer not null default 0,
  cancel_requested_at timestamptz,
  attempts integer not null default 0 check (attempts >= 0),
  available_at timestamptz not null default now(),
  lease_expires_at timestamptz,
  started_at timestamptz,
  finished_at timestamptz,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index api_football_sync_queue_jobs_ready_idx
  on public.api_football_sync_queue_jobs (status, available_at, created_at)
  where status in ('queued', 'retrying');

alter table public.api_football_sync_queue_jobs enable row level security;
alter table public.api_football_sync_queue_jobs force row level security;
revoke all on table public.api_football_sync_queue_jobs from anon, authenticated;

create or replace function public.claim_next_api_football_sync_queue_job(
  p_lease_seconds integer default 900
)
returns setof public.api_football_sync_queue_jobs
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_now timestamptz := clock_timestamp();
begin
  if p_lease_seconds < 60 then
    raise exception 'Queue lease must be at least one minute.';
  end if;

  -- Recover a worker killed by an Edge Function or pg_net timeout. The next
  -- worker retries it; a second active job can never start in parallel.
  update public.api_football_sync_queue_jobs
  set status = 'retrying',
      available_at = v_now + interval '1 minute',
      lease_expires_at = null,
      last_error = coalesce(last_error, 'Worker lease expired before completion.'),
      updated_at = v_now
  where status = 'running'
    and lease_expires_at < v_now;

  if exists (
    select 1
    from public.api_football_sync_queue_jobs
    where status = 'running'
      and lease_expires_at >= v_now
  ) then
    return;
  end if;

  return query
  with next_job as (
    select id
    from public.api_football_sync_queue_jobs
    where status in ('queued', 'retrying')
      and cancel_requested_at is null
      and available_at <= v_now
    order by priority desc, available_at, created_at
    limit 1
    for update skip locked
  )
  update public.api_football_sync_queue_jobs jobs
  set status = 'running',
      attempts = attempts + 1,
      started_at = coalesce(started_at, v_now),
      lease_expires_at = v_now + make_interval(secs => p_lease_seconds),
      last_error = null,
      updated_at = v_now
  from next_job
  where jobs.id = next_job.id
  returning jobs.*;
end;
$$;

revoke all on function public.claim_next_api_football_sync_queue_job(integer)
  from public, anon, authenticated;
grant execute on function public.claim_next_api_football_sync_queue_job(integer)
  to service_role;

comment on table public.api_football_sync_queue_jobs is
  'Durable, globally serial API-Football queue for scheduled and manual collection.';

create or replace function public.prepare_manual_api_football_cycle()
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_now timestamptz := clock_timestamp();
begin
  -- Scheduled work that has not contacted the provider is discarded. A
  -- currently running worker receives a cancellation flag and stops before
  -- its next provider request.
  update public.api_football_sync_queue_jobs
  set status = 'cancelled',
      finished_at = v_now,
      last_error = 'Cancelled by a manual cycle.',
      updated_at = v_now
  where status in ('queued', 'retrying');

  update public.api_football_sync_queue_jobs
  set cancel_requested_at = v_now,
      last_error = 'Cancellation requested by a manual cycle.',
      updated_at = v_now
  where status = 'running'
    and cancel_requested_at is null;
end;
$$;

revoke all on function public.prepare_manual_api_football_cycle()
  from public, anon, authenticated;
grant execute on function public.prepare_manual_api_football_cycle()
  to service_role;
