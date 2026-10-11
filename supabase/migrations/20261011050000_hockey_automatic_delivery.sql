-- Only the trusted scheduled publisher can switch the existing public heads.
-- All immutable objects are uploaded and verified before this atomic commit.
create function public.hockey_delivery_publish(p_collection uuid,p_captured_at timestamptz,p_manifests jsonb)
returns integer language plpgsql security definer set search_path=public,pg_temp as $$
declare source sport_feed_snapshots; item jsonb; n integer:=0;
begin
 perform pg_advisory_xact_lock(2026101105);
 select * into source from sport_feed_snapshots where sport='hockey' order by captured_at desc limit 1;
 if not found or source.collection_id is distinct from p_collection::text or source.captured_at is distinct from p_captured_at
  or source.captured_at<now()-interval '36 hours' or source.captured_at>now() then raise exception 'Hockey delivery source is not current'; end if;
 if jsonb_typeof(p_manifests) is distinct from 'array' or jsonb_array_length(p_manifests) not between 1 and 21 then raise exception 'Invalid hockey manifests'; end if;
 if (select count(distinct x->>'day') from jsonb_array_elements(p_manifests) x)<>jsonb_array_length(p_manifests) then raise exception 'Duplicate delivery day'; end if;
 if not exists(select 1 from jsonb_array_elements(p_manifests) x where x->>'day'=(now() at time zone 'Europe/Paris')::date::text) then raise exception 'Missing current hockey day'; end if;
 for item in select * from jsonb_array_elements(p_manifests) loop
  if item->>'sport' is distinct from 'hockey' or item->>'schemaVersion' is distinct from '1'
   or coalesce(item->>'path','') !~ '^delivery/hockey/hockey-[a-f0-9]{24}/[a-zA-Z0-9_.-]+[.]json$'
   or (item->>'day')::date not between source.window_start and source.window_end
   or item->>'collectionId' is distinct from p_collection::text
   or (item->>'capturedAt')::timestamptz is distinct from p_captured_at then raise exception 'Invalid hockey manifest identity'; end if;
  insert into sport_feed_delivery_heads(sport,day,manifest) values('hockey',(item->>'day')::date,item)
   on conflict(sport,day) do update set manifest=excluded.manifest,updated_at=now();
  n:=n+1;
 end loop;
 return n;
end $$;
revoke all on function public.hockey_delivery_publish(uuid,timestamptz,jsonb) from public,anon,authenticated;
grant execute on function public.hockey_delivery_publish(uuid,timestamptz,jsonb) to service_role;
-- The new publisher prepares its own atomic manifests. The older optional
-- generic worker must not replace them with an NHL-only delivery.
update public.sport_feed_delivery_jobs set enabled=false where sport='hockey';
notify pgrst, 'reload schema';
