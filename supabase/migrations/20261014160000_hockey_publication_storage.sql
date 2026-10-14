-- Preserve publication validation, immutable versions and server-only ACLs.
-- Validate all fixture boundaries in one query. A successful INSERT already
-- stores the supplied values: only a conflicting version needs a full reread.
create or replace function public.publish_sport_feed(p_payload jsonb,p_overview jsonb) returns jsonb
language plpgsql security definer set search_path=public,pg_temp set plan_cache_mode='force_generic_plan' as $$
declare doc sport_feed_snapshots; publication_id uuid; at timestamptz; lower_day date; upper_day date; competitions jsonb;
begin
 -- Materialize large RPC arguments once, before repeated JSON access.
 p_payload := p_payload || '{}'::jsonb;
 p_overview := p_overview || '{}'::jsonb;
 competitions := p_payload->'competitions';
 at := (p_payload->>'capturedAt')::timestamptz;
 lower_day := (p_payload->>'windowStart')::date; upper_day := (p_payload->>'windowEnd')::date;
 if p_payload->>'schemaVersion' is distinct from '1'
  or p_payload->>'sport' is null or p_payload->>'sport' !~ '^[a-z]+$' or p_payload->>'sport'='football'
  or coalesce(p_payload->>'provider','')='' or coalesce(p_payload->>'collectionId','')=''
  or at is null or at>now() or lower_day is null or upper_day is null or upper_day<lower_day
  or jsonb_typeof(p_payload->'items') is distinct from 'array'
  or jsonb_typeof(p_payload->'competitions') is distinct from 'array'
  or p_overview->>'sport' is distinct from p_payload->>'sport'
  or p_overview->>'capturedAt' is distinct from p_payload->>'capturedAt'
  or p_overview->>'collectionId' is distinct from p_payload->>'collectionId'
  or jsonb_typeof(p_overview->'items') is distinct from 'array'
  or jsonb_array_length(p_overview->'items')<>jsonb_array_length(p_payload->'items')
  or (p_payload ? 'baseCapturedAt' and (p_payload->>'baseCapturedAt')::timestamptz>at)
 then raise exception 'Invalid shared publication'; end if;
 if exists(select 1 from jsonb_array_elements(p_payload->'items') x group by x->>'id' having count(*)>1) then
  raise exception 'Duplicate match identity'; end if;
 if exists(select 1 from jsonb_array_elements(p_payload->'items') item
  where coalesce(item->>'id','')='' or (item#>>'{home,id}') is null or (item#>>'{away,id}') is null
   or item#>>'{home,id}'=item#>>'{away,id}'
   or item->>'status' not in ('scheduled','live','finished','postponed','cancelled','unknown')
   or (item->>'calendarDate')::date not between lower_day and upper_day
   or (item->>'startsAt')::timestamptz is null
   or not exists(select 1 from jsonb_array_elements(competitions) c
     where c->>'id'=item->>'competitionId' and c->>'season'=item->>'season')
 ) then raise exception 'Invalid match boundary'; end if;
 insert into sport_feed_snapshots(sport,provider,collection_id,captured_at,window_start,window_end,payload,overview)
 values(p_payload->>'sport',p_payload->>'provider',p_payload->>'collectionId',at,lower_day,upper_day,p_payload,p_overview)
 on conflict(sport,captured_at) do nothing returning id into publication_id;
 if publication_id is null then
  select * into doc from sport_feed_snapshots where sport=p_payload->>'sport' and captured_at=at;
  if doc.payload<>p_payload or doc.overview<>p_overview then raise exception 'Publication version is immutable'; end if;
  publication_id:=doc.id;
 end if;
 return jsonb_build_object('id',publication_id,'sport',p_payload->>'sport','capturedAt',p_payload->>'capturedAt','matches',jsonb_array_length(p_payload->'items'));
end $$;

notify pgrst, 'reload schema';
