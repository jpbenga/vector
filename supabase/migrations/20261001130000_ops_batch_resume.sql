-- Replace the original four-argument RPC with a compatible resumable form.
-- The final parameter has a default, so existing callers may omit it.
drop function if exists public.ops_finish(uuid, uuid, jsonb, text);

create or replace function public.ops_finish(
  p_task uuid,
  p_token uuid,
  p_context jsonb default '{}',
  p_error text default null,
  p_continue boolean default false
)
returns void
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  t ops_tasks;
  stopped boolean;
begin
  select * into t
  from ops_tasks
  where id=p_task and stage_token=p_token and status='running' and lease_until>now()
  for update;
  if not found then return; end if;

  select t.cancel_requested or c.cancel_requested
  into stopped
  from ops_cycles c
  where c.id=t.cycle_id;

  update ops_tasks set
    status=case
      when stopped then 'cancelled'
      when p_error is not null then 'failed'
      when t.stage=3 then 'succeeded'
      else 'pending'
    end,
    stage=case
      when p_error is null and not stopped and not p_continue then t.stage+1
      else t.stage
    end,
    context=t.context||p_context,
    error_message=p_error,
    finished_at=case
      when stopped or p_error is not null or (t.stage=3 and not p_continue) then now()
      else null
    end,
    stage_token=null,
    lease_until=null,
    heartbeat_at=now()
  where id=t.id;

  insert into ops_events(task_id,cycle_id,actor,kind,stage,message)
  values(
    t.id,
    t.cycle_id,
    'worker',
    case
      when stopped then 'cancelled'
      when p_error is not null then 'failed'
      when p_continue then 'batch_completed'
      else 'completed'
    end,
    t.stage,
    case
      when stopped then 'Arrêt confirmé'
      when p_error is not null then p_error
      when p_continue then 'Lot d’enrichissement terminé ; le suivant est mis en file'
      else 'Étape terminée'
    end
  );

  begin
    perform ops_dispatch();
  exception when others then
    insert into ops_events(actor,kind,message)
    values(
      'system',
      'dispatch_error',
      'Envoi au worker indisponible ; nouvelle tentative au prochain passage du planificateur.'
    );
  end;
end
$$;

revoke all on function public.ops_finish(uuid, uuid, jsonb, text, boolean)
  from public, anon, authenticated;
grant execute on function public.ops_finish(uuid, uuid, jsonb, text, boolean)
  to service_role;

notify pgrst, 'reload schema';
