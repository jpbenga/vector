-- Reuse existing turn JSON archives. No table or retention policy is added.
create function public.lector_generator_exploration_read(p_user uuid,p_conversation uuid,p_evaluation uuid default null)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare c lector_generator_conversations; result jsonb;
begin
 select * into c from lector_generator_conversations where id=p_conversation;
 if not found or c.user_id is distinct from p_user then raise exception 'Unauthorized'; end if;
 if c.mode<>'workshop' or c.expires_at<=now() then raise exception 'Session expired'; end if;
 select e into result from lector_generator_turns t
 cross join lateral jsonb_array_elements(case when jsonb_typeof(t.usage->'evaluations')='array' then t.usage->'evaluations' else '[]'::jsonb end) e
 where t.user_id=p_user and t.conversation_id=p_conversation
 and (p_evaluation is null or e->>'id'=p_evaluation::text)
 -- Terminal snapshots win over earlier progress checkpoints. An older terminal
 -- copy wins over a later read-only replay of the same identity.
 order by case when p_evaluation is null then t.started_at end desc,
 (t.status='complete') desc,
 case when p_evaluation is not null then t.started_at end asc,
 case when e->>'evaluated' ~ '^[0-9]{1,9}$' then (e->>'evaluated')::int else 0 end desc limit 1;
 return result;
end $$;
revoke all on function public.lector_generator_exploration_read(uuid,uuid,uuid) from public,anon,authenticated;
grant execute on function public.lector_generator_exploration_read(uuid,uuid,uuid) to service_role;
notify pgrst,'reload schema';
-- Rollback: DROP FUNCTION public.lector_generator_exploration_read(uuid,uuid,uuid).
-- Removing the reader does not delete stored reports; old archives keep their format.
