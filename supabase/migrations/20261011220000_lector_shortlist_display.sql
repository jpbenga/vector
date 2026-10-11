-- Keep preparation references unchanged. Hydrate compact display facts from
-- the latest publication; no AI request, copied odds or predictive score.
create or replace function public.lector_shortlist_fixture(p_sport text,p_fixture text,p_date date) returns jsonb
language plpgsql stable security definer set search_path=public,pg_temp as $$
declare f jsonb; body jsonb; captured timestamptz; live_status text; readings jsonb;
begin
 if p_sport='football' then
  select x,s.payload,s.captured_at into f,body,captured from public.match_feed_analysis_snapshots s
   cross join lateral jsonb_array_elements(coalesce(s.payload#>'{raw,fixtures}','[]')) x
   where s.window_start<=p_date and s.window_end>=p_date and s.captured_at<=now()
    and s.captured_at>now()-interval '36 hours' and x#>>'{fixture,id}'=p_fixture
   order by s.captured_at desc,s.id desc limit 1;
  if f is null then return null; end if;
  select l.status into live_status from public.match_live_states l where l.fixture_id::text=p_fixture and l.captured_at>=captured and l.captured_at<=now();
  if live_status is not null then f:=jsonb_set(f,'{fixture,status,short}',to_jsonb(live_status)); end if;
  select coalesce(jsonb_agg(jsonb_build_object('id',r->>'id','label',r->>'label',
   'is_contradiction',r->'is_contradiction')), '[]') into readings
   from jsonb_array_elements(coalesce(body#>'{computed,fixtures}','[]')) a
   cross join lateral jsonb_array_elements(coalesce(a->'readings','[]')) r
   where a->>'fixture_id'=p_fixture and r->>'id'<>'head_to_head_dominance';
  return jsonb_build_object('key',p_sport||':'||p_fixture,'sport',p_sport,'fixtureId',p_fixture,
   'matchId','api-fixture-'||p_fixture,'home',f#>>'{teams,home,name}','away',f#>>'{teams,away,name}',
   'homeLogo',f#>>'{teams,home,logo}','awayLogo',f#>>'{teams,away,logo}',
   'competition',f#>>'{league,name}','country',f#>>'{league,country}',
   'countryFlag',f#>>'{league,flag}','readings',readings,'kickoff',f#>>'{fixture,date}','status',f#>>'{fixture,status,short}',
   'available',true,'capturedAt',captured);
 elsif p_sport='hockey' then
  select x,s.overview,s.captured_at into f,body,captured from public.sport_feed_snapshots s
   cross join lateral jsonb_array_elements(coalesce(s.overview->'items','[]')) x
   where s.sport='hockey' and s.window_start<=p_date and s.window_end>=p_date and s.captured_at<=now()
    and s.captured_at>now()-interval '36 hours' and x->>'id'=p_fixture
   order by s.captured_at desc,s.id desc limit 1;
  if f is null then return null; end if;
  select l.payload->>'status' into live_status from public.sport_live_states l where l.sport='hockey' and l.provider='api-hockey' and l.fixture_id=p_fixture and l.captured_at>=captured and l.captured_at<=now();
  if live_status is not null then f:=jsonb_set(f,'{status}',to_jsonb(live_status)); end if;
  return jsonb_build_object('key',p_sport||':'||p_fixture,'sport',p_sport,'fixtureId',p_fixture,
   'matchId','hockey:'||coalesce(body->>'provider','api-hockey')||':match:'||p_fixture,
   'home',f#>>'{home,name}','away',f#>>'{away,name}','homeLogo',coalesce(f#>>'{home,logoUrl}',f#>>'{home,logo}'),
   'awayLogo',coalesce(f#>>'{away,logoUrl}',f#>>'{away,logo}'),'competition',coalesce(f->>'competitionName',f->>'competitionId'),
   'countryFlag',coalesce(f->>'countryFlag',body#>>'{country,flag}'),
   'readings',coalesce((select jsonb_agg(jsonb_build_object('id',r->>'id','label',r->>'label',
    'is_contradiction',coalesce(r->'is_contradiction',r->'isContradiction')))
    from jsonb_array_elements(coalesce(f->'readings','[]')) r
    where r->>'id'<>'head_to_head_dominance' and coalesce(r->>'status','detected')='detected'),'[]'),
   'kickoff',f->>'startsAt','status',f->>'status','available',true,'capturedAt',captured);
 end if;
 return null;
end $$;

-- CREATE OR REPLACE preserves the existing owner-only execution permissions.
revoke all on function public.lector_shortlist_fixture(text,text,date) from public,anon,authenticated;
grant execute on function public.lector_shortlist_fixture(text,text,date) to service_role;
