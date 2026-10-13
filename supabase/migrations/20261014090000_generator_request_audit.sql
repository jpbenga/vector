-- Keep a bounded audit after session expiry. No conversation/ticket is changed,
-- no new table is introduced, and audit reads stay private to the verified owner.
create function public.lector_generator_audit_summary(p_usage jsonb)
returns jsonb language sql immutable set search_path=public,pg_temp as $$
 select jsonb_strip_nulls(jsonb_build_object(
  'release',p_usage->'release','request',p_usage->'request',
  'auditReports',p_usage->'auditReports','ticketRefs',p_usage->'ticketRefs',
  'interpretedIntent',p_usage->'interpretedIntent',
  'catalogSummary',p_usage->'catalogSummary',
  'ai',p_usage->'ai','timings_ms',p_usage->'timings_ms',
  'elapsed_ms',p_usage->'elapsed_ms','failure_stage',p_usage->'failure_stage',
  'failure_name',p_usage->'failure_name','failure_message',p_usage->'failure_message'
 ));
$$;

create or replace function public.lector_generator_cleanup() returns integer
language plpgsql security definer set search_path=public,pg_temp as $$
declare n integer; days integer;
begin
 select audit_days into days from lector_generator_retention where id;
 insert into lector_generator_session_audit(request_id,user_id,started_at,status,usage)
 select t.request_id,t.user_id,t.started_at,t.status,public.lector_generator_audit_summary(t.usage)
 from lector_generator_turns t join lector_generator_conversations c on c.id=t.conversation_id
 where c.mode='workshop' and c.expires_at<=now() on conflict(request_id) do nothing;
 delete from lector_generator_conversations where mode='workshop' and expires_at<=now();
 get diagnostics n=row_count;
 delete from lector_generator_session_audit where started_at<now()-make_interval(days=>days);
 delete from lector_generator_proposal_audit where generated_at<now()-make_interval(days=>days);
 return n;
end $$;

create function public.lector_generator_request_audit_read(p_user uuid,p_request uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare report jsonb; owner uuid;
begin
 select user_id into owner from lector_generator_turns where request_id=p_request;
 if owner is not null then
  if owner is distinct from p_user then raise exception 'Unauthorized'; end if;
  select jsonb_build_object('requestId',request_id,'startedAt',started_at,'status',status,
    'audit',public.lector_generator_audit_summary(usage)) into report
   from lector_generator_turns where request_id=p_request and user_id=p_user;
  return report;
 end if;
 select user_id into owner from lector_generator_session_audit where request_id=p_request;
 if owner is not null and owner is distinct from p_user then raise exception 'Unauthorized'; end if;
 select jsonb_build_object('requestId',request_id,'startedAt',started_at,'status',status,'audit',usage)
 into report from lector_generator_session_audit
 where request_id=p_request and user_id=p_user;
 return report;
end $$;

-- Archive consultations have an ID too; polling the original turn is not duplicated.
create function public.lector_generator_request_audit_write(p_user uuid,p_request uuid,p_usage jsonb)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare owner uuid;
begin
 if p_user is null or p_request is null or octet_length(p_usage::text)>16000
  then raise exception 'Invalid audit event'; end if;
 select user_id into owner from lector_generator_session_audit where request_id=p_request;
 if owner is not null and owner is distinct from p_user then raise exception 'Unauthorized'; end if;
 insert into lector_generator_session_audit(request_id,user_id,started_at,status,usage)
 values(p_request,p_user,now(),'complete',public.lector_generator_audit_summary(p_usage))
 on conflict(request_id) do nothing;
end $$;

revoke all on function public.lector_generator_audit_summary(jsonb),public.lector_generator_request_audit_read(uuid,uuid),public.lector_generator_request_audit_write(uuid,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.lector_generator_audit_summary(jsonb),public.lector_generator_request_audit_read(uuid,uuid),public.lector_generator_request_audit_write(uuid,uuid,jsonb) to service_role;
-- Existing cleanup permissions and configurable audit_days are preserved.
notify pgrst,'reload schema';
