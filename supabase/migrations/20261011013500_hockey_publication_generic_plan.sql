-- Avoid custom-plan constant folding of multi-megabyte JSON parameters at each
-- occurrence. The setting is scoped to this publication call and inherited by
-- its Radar trigger; it is restored at function exit. Football never enters
-- publish_sport_feed. Validation, immutable storage and ACLs remain unchanged.
alter function public.publish_sport_feed(jsonb,jsonb)
 set plan_cache_mode='force_generic_plan';
notify pgrst, 'reload schema';
