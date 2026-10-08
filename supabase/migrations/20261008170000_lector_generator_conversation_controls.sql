-- Owner-scoped progress and cancellation. Paid calls retain their reservation.
-- Immutable visual objects stay available when the compact conversation grows.
create table public.lector_generator_ticket_drafts (
 id uuid primary key, conversation_id uuid not null references public.lector_generator_conversations(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade, ticket jsonb not null, created_at timestamptz not null default now()
);
create index on public.lector_generator_ticket_drafts(conversation_id,created_at);
alter table public.lector_generator_ticket_drafts enable row level security;
alter table public.lector_generator_ticket_drafts force row level security;
revoke all on public.lector_generator_ticket_drafts from public,anon,authenticated;
grant all on public.lector_generator_ticket_drafts to service_role;
create or replace function public.lector_generator_commit(p_user uuid,p_conversation uuid,p_revision integer,p_state jsonb,p_request uuid default null,p_usage jsonb default null)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare result jsonb; owner uuid; t lector_generator_turns;
begin
 if jsonb_typeof(p_state)<>'object' or length(p_state::text)>250000 then raise exception 'Invalid conversation state'; end if;
 select user_id into owner from lector_generator_conversations where id=p_conversation for update;
 if owner is distinct from p_user then raise exception 'Unauthorized'; end if;
 if p_request is not null then
  select * into t from lector_generator_turns where request_id=p_request for update;
  if t.user_id is distinct from p_user or t.conversation_id<>p_conversation or t.status<>'pending' then raise exception 'Invalid reservation'; end if;
 end if;
 insert into lector_generator_ticket_drafts(id,conversation_id,user_id,ticket)
 select distinct on(x->>'id') (x->>'id')::uuid,p_conversation,p_user,x
 from jsonb_array_elements(coalesce(p_state->'drafts','[]') || coalesce(p_state->'tickets','[]') || case when jsonb_typeof(p_state->'pending')='array' then p_state->'pending' else '[]' end) x
 on conflict(id) do nothing;
 result:=p_state || jsonb_build_object('revision',p_revision+1,'updatedAt',now());
 update lector_generator_conversations set state=result,revision=p_revision+1,updated_at=now() where id=p_conversation and user_id=p_user and revision=p_revision;
 if not found then raise exception 'Conversation changed'; end if;
 if p_request is not null then update lector_generator_turns set status='complete',response=result,usage=p_usage where request_id=p_request; end if;
 return result;
end $$;


create function public.lector_generator_cancel(p_user uuid,p_conversation uuid,p_request uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare owner uuid; t lector_generator_turns;
begin
 perform pg_advisory_xact_lock(814208);
 insert into lector_generator_conversations(id,user_id) values(p_conversation,p_user) on conflict(id) do nothing;
 select user_id into owner from lector_generator_conversations where id=p_conversation for update;
 if owner is distinct from p_user then raise exception 'Unauthorized'; end if;
 select * into t from lector_generator_turns where request_id=p_request for update;
 if found then
  if t.user_id is distinct from p_user or t.conversation_id<>p_conversation then raise exception 'Unauthorized'; end if;
  if t.status='pending' then update lector_generator_turns set status='failed',usage=coalesce(usage,'{}') || '{"cancelled":true}' where request_id=p_request; end if;
 else
  -- A cancellation can arrive before the initial reservation. Keep a tombstone
  -- so the late worker cannot start a paid call or publish its result.
  insert into lector_generator_turns(request_id,user_id,conversation_id,status,usage) values(p_request,p_user,p_conversation,'failed','{"cancelled":true}');
 end if;
 select * into t from lector_generator_turns where request_id=p_request;
 return jsonb_build_object('status',t.status,'cancelled',coalesce((t.usage->>'cancelled')::boolean,false));
end $$;
create function public.lector_generator_finish_transcription(p_user uuid,p_conversation uuid,p_request uuid,p_transcript text,p_usage jsonb)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare owner uuid; t lector_generator_turns; result jsonb;
begin
 select user_id into owner from lector_generator_conversations where id=p_conversation for update;
 if owner is distinct from p_user then raise exception 'Unauthorized'; end if;
 select * into t from lector_generator_turns where request_id=p_request for update;
 if t.user_id is distinct from p_user or t.conversation_id<>p_conversation or t.status<>'pending' then raise exception 'Invalid reservation'; end if;
 if length(p_transcript)>2000 then raise exception 'Transcript too long'; end if;
 result:=jsonb_build_object('transcript',p_transcript);
 update lector_generator_turns set status='complete',response=result,usage=p_usage where request_id=p_request;
 return result;
end $$;
revoke all on function public.lector_generator_cancel(uuid,uuid,uuid),public.lector_generator_finish_transcription(uuid,uuid,uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.lector_generator_cancel(uuid,uuid,uuid),public.lector_generator_finish_transcription(uuid,uuid,uuid,text,jsonb) to service_role;
notify pgrst,'reload schema';

-- Pending-turn fencing and quotas already serialize generation. Allow a
-- follow-up after a completed response without a ten-second pause.
create or replace function public.lector_generator_reserve(p_user uuid,p_conversation uuid,p_request uuid,p_revision integer,p_user_limit integer default 10,p_global_limit integer default 100)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare c lector_generator_conversations; t lector_generator_turns; n integer; d date:=(now() at time zone 'UTC')::date;
begin
 -- Serialize global usage reservations; duplicates and concurrent tabs cannot
 -- bypass limits or execute simultaneous edits to the same conversation.
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
 select coalesce(sum(calls),0) into n from lector_generator_usage where day=d;
 if n>=least(greatest(p_global_limit,1),1000) then raise exception 'Daily generator limit reached'; end if;
 select calls into n from lector_generator_usage where day=d and user_id=p_user;
 if coalesce(n,0)>=least(greatest(p_user_limit,1),20) then raise exception 'Daily account limit reached'; end if;
 update lector_generator_budget set reserved_usd=reserved_usd+0.025 where id=true and reserved_usd+0.025<=limit_usd;
 if not found then raise exception 'Generator test budget limit reached'; end if;
 insert into lector_generator_usage values(d,p_user,1) on conflict(day,user_id) do update set calls=lector_generator_usage.calls+1;
 insert into lector_generator_turns(request_id,user_id,conversation_id) values(p_request,p_user,p_conversation);
 return jsonb_build_object('status','reserved');
end $$;

