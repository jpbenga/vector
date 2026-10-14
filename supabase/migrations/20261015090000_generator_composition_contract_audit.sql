-- Retain owner-private composition contract diagnostics under the existing retention policy.
-- Function-only change: no conversations, tickets, sources, ACLs or retention durations changed.
create or replace function public.lector_generator_audit_summary(p_usage jsonb)
returns jsonb language sql immutable set search_path=public,pg_temp as $$
 select jsonb_strip_nulls(jsonb_build_object(
  'release',p_usage->'release','request',p_usage->'request',
  'auditReports',p_usage->'auditReports','ticketRefs',p_usage->'ticketRefs',
  'interpretedIntent',p_usage->'interpretedIntent',
  'catalogSummary',p_usage->'catalogSummary',
  'ai',p_usage->'ai','timings_ms',p_usage->'timings_ms',
  'elapsed_ms',p_usage->'elapsed_ms','failure_stage',p_usage->'failure_stage',
  'failure_name',p_usage->'failure_name','failure_message',p_usage->'failure_message',
  'failure_contract',p_usage->'failure_contract'
 ));
$$;

