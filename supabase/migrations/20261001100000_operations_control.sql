-- Persistent operations control. All mutations are service-role only.
create table public.ops_competitions (
  league_id integer primary key check (league_id > 0),
  name text not null check (length(trim(name)) between 1 and 160),
  enabled boolean not null default true,
  daily_time time not null default '02:00',
  timezone text not null default 'Europe/Paris',
  last_scheduled_date date,
  enrichment_enabled boolean not null default false,
  enrichment_day integer not null default 0 check (enrichment_day between 0 and 6),
  enrichment_time time not null default '04:15',
  enrichment_timezone text not null default 'Europe/Paris',
  last_enrichment_date date,
  created_at timestamptz not null default now()
);
insert into public.ops_competitions (league_id, name)
select api_football_league_id, league_name from public.api_football_mvp_leagues;
-- Preserve existing weekly enrichment schedules (the old generator uses UTC).
update public.ops_competitions c set enrichment_enabled=j.active,
  enrichment_day=split_part(j.schedule,' ',5)::integer,
  enrichment_time=make_time(split_part(j.schedule,' ',2)::integer,split_part(j.schedule,' ',1)::integer,0),
  enrichment_timezone='UTC'
from cron.job j where j.jobname='api-football-enrichment-'||c.league_id
  and j.schedule ~ '^([0-9]|[1-5][0-9]) ([0-9]|1[0-9]|2[0-3]) [*] [*] [0-6]$';

create table public.ops_configuration (
  singleton boolean primary key default true check (singleton),
  base_url text not null,
  sync_secret text not null,
  last_tick_at timestamptz,
  scheduling_enabled boolean not null default false
);
create table public.ops_cycles (
  id uuid primary key default gen_random_uuid(),
  label text not null,
  source text not null check (source in ('manual','scheduled','retry')),
  actor text not null,
  paused boolean not null default false,
  cancel_requested boolean not null default false,
  created_at timestamptz not null default now()
);
create table public.ops_tasks (
  id uuid primary key default gen_random_uuid(),
  cycle_id uuid not null references public.ops_cycles(id),
  league_id integer not null references public.ops_competitions(league_id),
  competition_name text not null,
  position integer not null,
  job_kind text not null default 'daily' check (job_kind in ('daily','enrichment')),
  status text not null default 'pending' check (status in ('pending','running','succeeded','failed','cancelled')),
  stage integer not null default 0 check (stage between 0 and 4),
  stage_token uuid,
  stage_dispatched boolean not null default false,
  lease_until timestamptz,
  heartbeat_at timestamptz,
  cancel_requested boolean not null default false,
  attempts integer not null default 0,
  day date not null default ((now() at time zone 'Europe/Paris')::date),
  context jsonb not null default '{}',
  counters jsonb not null default '{}',
  sample jsonb not null default '{}',
  error_message text,
  created_at timestamptz not null default now(),
  started_at timestamptz,
  finished_at timestamptz,
  unique (cycle_id,league_id)
);
create index ops_tasks_queue on public.ops_tasks(status,created_at,position);
create index ops_tasks_cycle on public.ops_tasks(cycle_id,position);
create table public.ops_events (
  id bigint generated always as identity primary key,
  task_id uuid references public.ops_tasks(id),
  cycle_id uuid references public.ops_cycles(id),
  actor text not null,
  kind text not null,
  stage integer,
  message text not null,
  created_at timestamptz not null default now()
);
create index ops_events_task on public.ops_events(task_id,created_at desc);

-- There is no client policy: the authenticated admin Edge Function is the boundary.
do $$ declare t text; begin
  foreach t in array array['ops_competitions','ops_configuration','ops_cycles','ops_tasks','ops_events'] loop
    execute format('alter table public.%I enable row level security',t);
    execute format('alter table public.%I force row level security',t);
    execute format('revoke all on public.%I from public,anon,authenticated',t);
    execute format('grant all on public.%I to service_role',t);
  end loop;
end $$;
grant usage, select on sequence public.ops_events_id_seq to service_role;

create function public.ops_enqueue(p_ids integer[], p_label text, p_source text, p_actor text, p_kind text default 'daily')
returns uuid language plpgsql security definer set search_path = public,pg_temp as $$
declare cycle uuid; begin
  perform pg_advisory_xact_lock(817321);
  if cardinality(p_ids) is null or cardinality(p_ids)=0 then raise exception 'Aucune compétition sélectionnée'; end if;
  if exists(select 1 from unnest(p_ids) x where not exists(select 1 from ops_competitions where league_id=x)) then
    raise exception 'Compétition inconnue';
  end if;
  if exists(select 1 from ops_tasks t where t.league_id=any(p_ids) and t.status in ('pending','running')) then
    raise exception 'Une compétition sélectionnée est déjà en attente ou en cours';
  end if;
  insert into ops_cycles(label,source,actor) values(p_label,p_source,p_actor) returning id into cycle;
  insert into ops_tasks(cycle_id,league_id,competition_name,position,job_kind)
  select cycle,c.league_id,c.name,u.ordinality,p_kind from unnest(p_ids) with ordinality u(id,ordinality)
  join ops_competitions c on c.league_id=u.id;
  insert into ops_events(cycle_id,actor,kind,message) values(cycle,p_actor,'created',p_label);
  return cycle;
end $$;

-- Dispatcher claims one stage globally. A lease prevents duplicate workers.
create function public.ops_dispatch()
returns void language plpgsql security definer set search_path = public,extensions,pg_temp as $$
declare cfg ops_configuration; t ops_tasks; token uuid; request_id bigint; begin
  if not pg_try_advisory_xact_lock(817322) then return; end if;
  select * into cfg from ops_configuration where singleton;
  if not found then return; end if;
  with expired as (
    update ops_tasks set status=case when cancel_requested then 'cancelled' else 'failed' end,
      finished_at=now(), stage_token=null, lease_until=null,
      error_message='Le worker n’a pas confirmé la fin de l’étape avant expiration du délai. Vérifier les journaux avant de relancer.'
    where status='running' and lease_until < now() returning *
  ) insert into ops_events(task_id,cycle_id,actor,kind,stage,message)
    select id,cycle_id,'system','timeout',stage,error_message from expired;
  if exists(select 1 from ops_tasks where status='running') then return; end if;
  update ops_tasks queued set status='cancelled',finished_at=now()
    from ops_cycles c where c.id=queued.cycle_id and queued.status='pending' and (queued.cancel_requested or c.cancel_requested);
  select task.* into t from ops_tasks task join ops_cycles c on c.id=task.cycle_id
    where task.status='pending' and not c.paused and not c.cancel_requested and not task.cancel_requested
    order by task.created_at,task.position limit 1 for update of task skip locked;
  if not found then return; end if;
  token:=gen_random_uuid();
  update ops_tasks set status='running',stage_token=token,stage_dispatched=false,
    lease_until=now()+interval '10 minutes',heartbeat_at=now(),
    day=case when stage=0 and started_at is null then (now() at time zone 'Europe/Paris')::date else day end,
    started_at=coalesce(started_at,now()),attempts=attempts+1 where id=t.id;
  select net.http_post(
    url:=cfg.base_url||'/functions/v1/ops-worker',
    headers:=jsonb_build_object('Content-Type','application/json','Authorization','Bearer '||cfg.sync_secret),
    body:=jsonb_build_object('task_id',t.id,'token',token),timeout_milliseconds:=300000
  ) into request_id;
exception when others then
  -- The enclosing subtransaction rolls back the failed dispatch claim.
  insert into ops_events(actor,kind,message) values('system','dispatch_error',
    'Envoi au worker indisponible ; nouvelle tentative au prochain passage du planificateur.');
end $$;

create function public.ops_claim(p_task uuid,p_token uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare t ops_tasks; begin
  update ops_tasks set stage_dispatched=true,heartbeat_at=now()
    where id=p_task and stage_token=p_token and status='running' and not stage_dispatched and lease_until>now()
    returning * into t;
  if not found then return null; end if;
  insert into ops_events(task_id,cycle_id,actor,kind,stage,message)
    values(t.id,t.cycle_id,'worker','started',t.stage,'Étape démarrée');
  return to_jsonb(t);
end $$;

create function public.ops_checkpoint(p_task uuid,p_token uuid,p_counters jsonb default '{}',p_sample jsonb default '{}')
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare allowed boolean; begin
  update ops_tasks t set heartbeat_at=now(),counters=t.counters||p_counters,
    sample=case when p_sample='{}'::jsonb then t.sample else p_sample end
    where t.id=p_task and t.stage_token=p_token and t.status='running' and lease_until>now()
    returning not t.cancel_requested and not exists(select 1 from ops_cycles c where c.id=t.cycle_id and c.cancel_requested) into allowed;
  return coalesce(allowed,false);
end $$;

create function public.ops_finish(p_task uuid,p_token uuid,p_context jsonb default '{}',p_error text default null,p_continue boolean default false)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare t ops_tasks; stopped boolean; begin
  select * into t from ops_tasks where id=p_task and stage_token=p_token and status='running' and lease_until>now() for update;
  if not found then return; end if;
  select t.cancel_requested or c.cancel_requested into stopped from ops_cycles c where c.id=t.cycle_id;
  update ops_tasks set
    status=case when stopped then 'cancelled' when p_error is not null then 'failed' when t.stage=3 then 'succeeded' else 'pending' end,
    stage=case when p_error is null and not stopped and not p_continue then t.stage+1 else t.stage end,
    context=t.context||p_context,error_message=p_error,
    finished_at=case when stopped or p_error is not null or (t.stage=3 and not p_continue) then now() else null end,
    stage_token=null,lease_until=null,heartbeat_at=now() where id=t.id;
  insert into ops_events(task_id,cycle_id,actor,kind,stage,message) values(t.id,t.cycle_id,'worker',
    case when stopped then 'cancelled' when p_error is not null then 'failed' when p_continue then 'batch_completed' else 'completed' end,t.stage,
    case when stopped then 'Arrêt confirmé' when p_error is not null then p_error when p_continue then 'Lot d’enrichissement terminé ; le suivant est mis en file' else 'Étape terminée' end);
  begin
    perform ops_dispatch();
  exception when others then
    -- A dispatch outage must not roll back the recorded completion/control.
    insert into ops_events(actor,kind,message) values('system','dispatch_error','Envoi au worker indisponible ; nouvelle tentative au prochain passage du planificateur.');
  end;
end $$;

create function public.ops_control(p_action text,p_id uuid,p_actor text)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if p_action in ('pause_cycle','resume_cycle','cancel_cycle') then
    update ops_cycles set paused=case when p_action='pause_cycle' then true when p_action='resume_cycle' then false else paused end,
      cancel_requested=cancel_requested or p_action='cancel_cycle' where id=p_id;
    if not found then raise exception 'Cycle introuvable'; end if;
    if p_action='cancel_cycle' then
      update ops_tasks set cancel_requested=true,
        status=case when status='pending' then 'cancelled' else status end,
        finished_at=case when status='pending' then now() else finished_at end
        where cycle_id=p_id and status in ('running','pending');
    end if;
    insert into ops_events(cycle_id,actor,kind,message) values(p_id,p_actor,p_action,p_action);
  elsif p_action='cancel_task' then
    update ops_tasks set cancel_requested=true,
      status=case when status='pending' then 'cancelled' else status end,
      finished_at=case when status='pending' then now() else finished_at end
      where id=p_id and status in ('pending','running');
    if not found then raise exception 'Ce batch est déjà terminé ou introuvable'; end if;
    insert into ops_events(task_id,actor,kind,message) values(p_id,p_actor,p_action,'Arrêt demandé');
  else raise exception 'Action inconnue'; end if;
  begin
    perform ops_dispatch();
  exception when others then
    -- A dispatch outage must not roll back the recorded completion/control.
    insert into ops_events(actor,kind,message) values('system','dispatch_error','Envoi au worker indisponible ; nouvelle tentative au prochain passage du planificateur.');
  end;
end $$;

create function public.ops_tick()
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare c ops_competitions; ids integer[]; begin
  if not pg_try_advisory_xact_lock(817323) then return; end if;
  update ops_configuration set last_tick_at=now() where singleton;
  if exists(select 1 from ops_configuration where scheduling_enabled) then
    for c in select * from ops_competitions where enabled loop
      if (now() at time zone c.timezone)::time>=c.daily_time
        and c.last_scheduled_date is distinct from (now() at time zone c.timezone)::date
        and not exists(select 1 from ops_tasks where league_id=c.league_id and status in ('pending','running')) then
        ids:=array_append(ids,c.league_id);
      end if;
    end loop;
    if cardinality(ids)>0 then
      perform ops_enqueue(ids,'Cycle quotidien','scheduled','scheduler');
      update ops_competitions set last_scheduled_date=(now() at time zone timezone)::date where league_id=any(ids);
    end if;
    ids:=null;
    for c in select * from ops_competitions where enrichment_enabled loop
      if extract(dow from now() at time zone c.enrichment_timezone)=c.enrichment_day
        and (now() at time zone c.enrichment_timezone)::time>=c.enrichment_time
        and c.last_enrichment_date is distinct from (now() at time zone c.enrichment_timezone)::date
        and not exists(select 1 from ops_tasks where league_id=c.league_id and status in ('pending','running')) then
        ids:=array_append(ids,c.league_id);
      end if;
    end loop;
    if cardinality(ids)>0 then
      perform ops_enqueue(ids,'Enrichissement hebdomadaire','scheduled','scheduler','enrichment');
      update ops_competitions set last_enrichment_date=(now() at time zone enrichment_timezone)::date where league_id=any(ids);
    end if;
  end if;
  begin
    perform ops_dispatch();
  exception when others then
    -- A dispatch outage must not roll back the recorded completion/control.
    insert into ops_events(actor,kind,message) values('system','dispatch_error','Envoi au worker indisponible ; nouvelle tentative au prochain passage du planificateur.');
  end;
end $$;

-- Explicit activation transfers legacy league/enrichment schedules; command text never leaves the DB.
create function public.ops_configure(p_url text,p_secret text,p_scheduling boolean,p_actor text)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
  insert into ops_configuration(singleton,base_url,sync_secret,scheduling_enabled)
    values(true,p_url,p_secret,p_scheduling)
    on conflict(singleton) do update set base_url=excluded.base_url,sync_secret=excluded.sync_secret,scheduling_enabled=excluded.scheduling_enabled;
  if p_scheduling then
    perform cron.alter_job(job_id:=jobid,active:=false) from cron.job
      where jobname like 'api-football-%' and active;
  end if;
  insert into ops_events(actor,kind,message) values(p_actor,'configuration',
    case when p_scheduling then 'Planification pilotée activée ; anciens crons api-football désactivés' else 'Planification pilotée désactivée' end);
end $$;

create function public.ops_save_competition(p_id integer,p_name text,p_enabled boolean,p_time time,p_actor text,p_enrichment boolean default false,p_enrichment_day integer default 0,p_enrichment_time time default '04:15')
returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
  insert into ops_competitions(league_id,name,enabled,daily_time,enrichment_enabled,enrichment_day,enrichment_time)
    values(p_id,p_name,p_enabled,p_time,p_enrichment,p_enrichment_day,p_enrichment_time)
    on conflict(league_id) do update set name=excluded.name,enabled=excluded.enabled,daily_time=excluded.daily_time,
      enrichment_enabled=excluded.enrichment_enabled,enrichment_day=excluded.enrichment_day,enrichment_time=excluded.enrichment_time;
  insert into ops_events(actor,kind,message) values(p_actor,'competition',p_name||' : planification '||case when p_enabled then 'activée' else 'désactivée' end);
end $$;

do $$ declare f record; begin
  for f in select oid::regprocedure as sig from pg_proc where pronamespace='public'::regnamespace and proname like 'ops_%' loop
    execute format('revoke all on function %s from public,anon,authenticated',f.sig);
    execute format('grant execute on function %s to service_role',f.sig);
  end loop;
end $$;
select cron.schedule('lector-ops-dispatch','* * * * *','select public.ops_tick();');

-- Read-only summaries; invoker rights preserve the service-role boundary.
create view public.ops_cycle_overview with (security_invoker=true) as
select c.*, count(t.id)::integer as total,
 count(t.id) filter(where t.status='succeeded')::integer as succeeded,
 count(t.id) filter(where t.status='failed')::integer as failed,
 count(t.id) filter(where t.status='running')::integer as running,
 count(t.id) filter(where t.status='pending')::integer as pending,
 count(t.id) filter(where t.status='cancelled')::integer as cancelled
from public.ops_cycles c left join public.ops_tasks t on t.cycle_id=c.id group by c.id;
create view public.ops_duration_overview with (security_invoker=true) as
select league_id,job_kind,count(*)::integer as samples,
 round(avg(extract(epoch from finished_at-started_at)))::integer as average_seconds
from public.ops_tasks where status='succeeded' and started_at>=now()-interval '48 hours'
group by league_id,job_kind;
revoke all on public.ops_cycle_overview,public.ops_duration_overview from public,anon,authenticated;
grant select on public.ops_cycle_overview,public.ops_duration_overview to service_role;
