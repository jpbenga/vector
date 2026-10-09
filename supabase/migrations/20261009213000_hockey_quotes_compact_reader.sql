-- Keep the large immutable export on its original fast path. Applications and
-- Generator use compact projections; mutable prices are joined to those views.
-- Local/export consumers hydrate price observations from the pinned radar view.
create or replace function public.read_sport_feed(p_sport text,p_day date default null,p_section text default 'radar',p_match text default null,p_captured_at timestamptz default null)
returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
 select case when p_sport='hockey' and p_section<>'full'
 then with_hockey_market_quotes(read_sport_feed_without_prices(p_sport,p_day,p_section,p_match,p_captured_at))
 else read_sport_feed_without_prices(p_sport,p_day,p_section,p_match,p_captured_at) end;
$$;
notify pgrst, 'reload schema';
