-- PostgREST binds the raw body once for an unnamed JSONB parameter, avoiding
-- expansion of two large named arguments. Delegate all validation, immutable
-- writes and Radar recording to the existing server-only publication function.
create function public.publish_sport_feed_document(jsonb) returns jsonb
language plpgsql security definer set search_path=public,pg_temp
set plan_cache_mode='force_generic_plan' as $$
begin
 return public.publish_sport_feed($1->'p_payload',$1->'p_overview');
end $$;
revoke all on function public.publish_sport_feed_document(jsonb)
 from public,anon,authenticated;
grant execute on function public.publish_sport_feed_document(jsonb) to service_role;
notify pgrst, 'reload schema';
