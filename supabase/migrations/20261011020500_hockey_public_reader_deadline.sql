-- PostgREST hoists this RPC-specific timeout before executing the statement.
-- Large, quote-enriched hockey projections can exceed anon's default 3s.
-- Keep the fallback bounded without changing any role's general timeout.
alter function public.read_sport_feed(text,date,text,text,timestamptz)
  set statement_timeout = '8s';
notify pgrst, 'reload schema';
