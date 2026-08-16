-- Admin operations cockpit foundation.
--
-- Scope:
-- - expose curated cron/job health to service-role Edge Functions only;
-- - log manual admin operations;
-- - never expose cron command text because it contains bearer secrets.

create or replace view public.admin_cron_jobs
as
select
  job.jobid,
  job.jobname,
  job.schedule,
  job.active,
  case
    when job.jobname like 'api-football-%-snapshot' then 'snapshot'
    when job.jobname like 'api-football-%' then 'sync'
    else 'other'
  end as task_kind,
  nullif(substring(job.jobname from 'league-([0-9]+)'), '')::integer
    as api_football_league_id,
  job.database,
  job.username
from cron.job job
where job.jobname like 'api-football-%'
order by job.jobname;

comment on view public.admin_cron_jobs is
  'Curated pg_cron jobs for the admin cockpit. Intentionally excludes command text because it contains bearer secrets.';

create or replace view public.admin_cron_job_runs
as
select
  details.runid,
  details.jobid,
  job.jobname,
  case
    when job.jobname like 'api-football-%-snapshot' then 'snapshot'
    when job.jobname like 'api-football-%' then 'sync'
    else 'other'
  end as task_kind,
  nullif(substring(job.jobname from 'league-([0-9]+)'), '')::integer
    as api_football_league_id,
  details.status,
  details.return_message,
  details.start_time,
  details.end_time
from cron.job_run_details details
left join cron.job job
  on job.jobid = details.jobid
where job.jobname like 'api-football-%'
order by details.start_time desc;

comment on view public.admin_cron_job_runs is
  'Curated pg_cron run history for the admin cockpit. Intentionally excludes command text because it contains bearer secrets.';

create table public.admin_operation_runs (
  id uuid primary key default gen_random_uuid(),
  action text not null
    check (action in ('rerun_league')),
  status text not null default 'running'
    check (status in ('running', 'succeeded', 'failed', 'partial')),
  environment text not null default 'unknown',
  actor_user_id uuid,
  actor_email text,
  league_ids integer[] not null default '{}',
  request_payload jsonb not null default '{}'::jsonb,
  response_summary jsonb not null default '{}'::jsonb,
  error_message text,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  created_at timestamptz not null default now(),
  check (cardinality(league_ids) > 0)
);

comment on table public.admin_operation_runs is
  'Service-role audit log for privileged admin cockpit operations.';

create index admin_operation_runs_started_at_idx
  on public.admin_operation_runs (started_at desc);

create index admin_operation_runs_status_idx
  on public.admin_operation_runs (status, started_at desc);

alter table public.admin_operation_runs enable row level security;
alter table public.admin_operation_runs force row level security;

revoke all on table public.admin_operation_runs
  from anon, authenticated;

revoke all on table public.admin_cron_jobs
  from anon, authenticated;

revoke all on table public.admin_cron_job_runs
  from anon, authenticated;

grant select on public.admin_cron_jobs
  to service_role;

grant select on public.admin_cron_job_runs
  to service_role;

grant select, insert, update on public.admin_operation_runs
  to service_role;
