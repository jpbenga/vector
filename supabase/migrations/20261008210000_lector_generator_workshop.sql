-- The workshop has no commercial credits or financial test envelope.
-- Keep ownership, replay, cancellation and concurrent-edit fences intact.
-- The installed legacy reservation and its ledger are unchanged.
create table public.lector_generator_workshop_usage (
 day date not null, user_id uuid not null references auth.users(id) on delete cascade,
 calls integer not null default 0 check(calls>=0), primary key(day,user_id)
);
alter table public.lector_generator_workshop_usage enable row level security;
alter table public.lector_generator_workshop_usage force row level security;
revoke all on public.lector_generator_workshop_usage from public,anon,authenticated;
grant all on public.lector_generator_workshop_usage to service_role;

create function public.lector_generator_workshop_reserve(
 p_user uuid,p_conversation uuid,p_request uuid,p_revision integer,
 p_user_limit integer default 0,p_global_limit integer default 0
) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare c lector_generator_conversations; t lector_generator_turns; d date:=(now() at time zone 'UTC')::date;
begin
 perform pg_advisory_xact_lock(814208);
 select * into t from lector_generator_turns where request_id=p_request;
 if found then
  if t.user_id<>p_user or t.conversation_id<>p_conversation then raise exception 'Unauthorized'; end if;
  return jsonb_build_object('cached',t.response,'status',t.status);
 end if;
 insert into lector_generator_conversations(id,user_id) values(p_conversation,p_user) on conflict(id) do nothing;
 select * into c from lector_generator_conversations where id=p_conversation for update;
 if c.user_id<>p_user then raise exception 'Unauthorized'; end if;
 if c.revision<>p_revision then raise exception 'Conversation changed'; end if;
 if exists(select 1 from lector_generator_turns where conversation_id=p_conversation and status='pending' and started_at>now()-interval '2 minutes') then raise exception 'Generation already running'; end if;
 if exists(select 1 from lector_generator_turns where user_id=p_user and started_at>now()-interval '1 second') then raise exception 'Please wait before another request'; end if;
 -- Count logical turns for observation. Actual model calls/tokens are in usage.
 insert into lector_generator_workshop_usage values(d,p_user,1) on conflict(day,user_id) do update set calls=lector_generator_workshop_usage.calls+1;
 insert into lector_generator_turns(request_id,user_id,conversation_id) values(p_request,p_user,p_conversation);
 return jsonb_build_object('status','reserved');
end $$;
revoke all on function public.lector_generator_workshop_reserve(uuid,uuid,uuid,integer,integer,integer) from public,anon,authenticated;
grant execute on function public.lector_generator_workshop_reserve(uuid,uuid,uuid,integer,integer,integer) to service_role;

-- Cancellation can arrive while a model is still producing a paid response.
-- Merge receipts atomically, preserving the cancellation tombstone and state.
create function public.lector_generator_workshop_record_failure(p_user uuid,p_request uuid,p_usage jsonb)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare t lector_generator_turns;
begin
 select * into t from lector_generator_turns where request_id=p_request for update;
 if not found or t.user_id is distinct from p_user then raise exception 'Unauthorized'; end if;
 if t.status in ('pending','failed') then
  update lector_generator_turns set status='failed',usage=coalesce(usage,'{}')||p_usage where request_id=p_request;
 end if;
end $$;
revoke all on function public.lector_generator_workshop_record_failure(uuid,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.lector_generator_workshop_record_failure(uuid,uuid,jsonb) to service_role;
notify pgrst,'reload schema';
