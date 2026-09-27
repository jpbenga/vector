-- A worker which never returns (for example after an Edge Function timeout)
-- must not monopolise the globally serial API-Football queue forever.  Keep
-- the final lease-expiry reason visible and stop after the same three-attempt
-- ceiling used by the queue worker's explicit error path.

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

  -- Recover an interrupted worker.  A third expired lease is terminal: the
  -- job has already consumed its three allowed attempts and must release the
  -- serial worker for the rest of the queue.
  update public.api_football_sync_queue_jobs
  set status = case when attempts >= 3 then 'failed' else 'retrying' end,
      available_at = case
        when attempts >= 3 then available_at
        else v_now + interval '1 minute'
      end,
      lease_expires_at = null,
      finished_at = case when attempts >= 3 then v_now else null end,
      last_error = concat_ws(
        ' ',
        nullif(last_error, ''),
        'Worker lease expired before completion.'
      ),
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
      -- Preserve the last timeout while the replacement worker is running;
      -- completion clears it, so an operator can inspect an active retry.
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
