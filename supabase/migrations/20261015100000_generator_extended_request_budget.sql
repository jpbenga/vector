-- Hold the workshop concurrency fence for the paid Edge worker lifetime.
-- One long request must not overlap a second turn with the same conversation revision.
create or replace function public.lector_generator_workshop_reserve(
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
 if exists(select 1 from lector_generator_turns where conversation_id=p_conversation and status='pending' and started_at>now()-interval '400 seconds') then raise exception 'Generation already running'; end if;
 if exists(select 1 from lector_generator_turns where user_id=p_user and started_at>now()-interval '1 second') then raise exception 'Please wait before another request'; end if;
 -- Count logical turns for observation. Actual model calls/tokens are in usage.
 insert into lector_generator_workshop_usage values(d,p_user,1) on conflict(day,user_id) do update set calls=lector_generator_workshop_usage.calls+1;
 insert into lector_generator_turns(request_id,user_id,conversation_id) values(p_request,p_user,p_conversation);
 return jsonb_build_object('status','reserved');
end $$;
revoke all on function public.lector_generator_workshop_reserve(uuid,uuid,uuid,integer,integer,integer) from public,anon,authenticated;
grant execute on function public.lector_generator_workshop_reserve(uuid,uuid,uuid,integer,integer,integer) to service_role;

notify pgrst,'reload schema';
