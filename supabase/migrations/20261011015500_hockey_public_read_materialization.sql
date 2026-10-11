-- Materialize public JSON once per request; identities, prices, ACLs and
-- the immutable publication contract are preserved. No new table or grant.
create or replace function public.read_sport_feed_without_prices(p_sport text,p_day date default null,p_section text default 'radar',p_match text default null,p_captured_at timestamptz default null)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp set plan_cache_mode='force_generic_plan' as $$
declare doc sport_feed_snapshots; body jsonb; items jsonb; teams text[]; leagues text[];
begin
 if p_section not in ('full','radar','day','match') then raise exception 'Invalid section'; end if;
 select * into doc from sport_feed_snapshots where sport=p_sport and captured_at<=now()
  and (p_captured_at is null or captured_at=p_captured_at)
  and (p_day is null or p_day between window_start and window_end)
 order by captured_at desc limit 1;
 if not found then return null; end if;
 if p_section='full' then return doc.payload; end if;
 if p_section='radar' then return doc.overview; end if;
 -- Materialize the TOAST value once. Repeated JSON operators otherwise
 -- repeatedly decompress the same multi-megabyte publication.
 body := (case when p_section='match' then doc.payload else doc.overview end)||'{}'::jsonb;
 select coalesce(jsonb_agg(f),'[]') into items from jsonb_array_elements(body->'items') f
 where (p_section='match' and f->>'id'=p_match) or (p_section='day' and (f->>'calendarDate')::date=p_day);
 if p_section='match' and jsonb_array_length(items)=0 then return null; end if;
 teams := array(select distinct team from jsonb_array_elements(items) f
  cross join lateral(values(f#>>'{home,id}'),(f#>>'{away,id}')) t(team));
 leagues := array(select distinct f->>'competitionId' from jsonb_array_elements(items) f);
 return body||jsonb_build_object('items',items,'playerRadar',coalesce(body->'playerRadar','{}')||jsonb_build_object(
  'profiles',coalesce((select jsonb_agg(x) from jsonb_array_elements(coalesce(body#>'{playerRadar,profiles}','[]')) x where x#>>'{team,id}'=any(teams)),'[]'),
  'coverage',coalesce((select jsonb_agg(x) from jsonb_array_elements(coalesce(body#>'{playerRadar,coverage}','[]')) x where x->>'teamId'=any(teams)),'[]')),
  'competitions',case when p_section='match' then coalesce((select jsonb_agg(c) from jsonb_array_elements(body->'competitions') c where c->>'id'=any(leagues)),'[]') else body->'competitions' end);
end $$;

create or replace function public.with_hockey_market_quotes(p_body jsonb)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp set plan_cache_mode='force_generic_plan' as $$
declare body jsonb; items jsonb;
begin
 if p_body is null then return null; end if;
 body := p_body||'{}'::jsonb;
 select coalesce(jsonb_agg(
  f||case when q.fixture_id is null then '{}'::jsonb
   else jsonb_build_object('quotes',q.quotes,'quotesCollectedAt',q.collected_at) end order by n),'[]'::jsonb)
 into items
 from jsonb_array_elements(body->'items') with ordinality x(f,n)
 left join public.hockey_market_quotes q on q.fixture_id=f->>'id'
  and q.competition_id=f->>'competitionId' and q.season=f->>'season'
  and q.home_id=f#>>'{home,id}' and q.away_id=f#>>'{away,id}'
  and q.collected_at<=(f->>'startsAt')::timestamptz;
 return body||jsonb_build_object('items',items);
end $$;
notify pgrst, 'reload schema';
