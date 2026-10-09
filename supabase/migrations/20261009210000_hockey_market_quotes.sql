-- Independent price observations. Refreshing a quote never renews the age of
-- standings/readings, and never mutates an immutable sport publication.
create table public.hockey_market_quotes (
 fixture_id text primary key, competition_id text not null, season text not null,
 home_id text not null, away_id text not null, collected_at timestamptz not null,
 quotes jsonb not null check(jsonb_typeof(quotes)='array')
);
create table public.hockey_odds_configuration (
 singleton boolean primary key default true check(singleton),
 token uuid, lease_until timestamptz, last_started_at timestamptz, last_completed_at timestamptz,
 last_success_at timestamptz, last_error text, requests_last_run integer not null default 0
);
insert into public.hockey_odds_configuration(singleton) values(true);
alter table public.hockey_market_quotes enable row level security;
alter table public.hockey_market_quotes force row level security;
alter table public.hockey_odds_configuration enable row level security;
alter table public.hockey_odds_configuration force row level security;
revoke all on public.hockey_market_quotes,public.hockey_odds_configuration from public,anon,authenticated;
grant all on public.hockey_market_quotes,public.hockey_odds_configuration to service_role;

create function public.hockey_odds_claim() returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare cfg hockey_odds_configuration; tok uuid;
begin
 select * into cfg from hockey_odds_configuration where singleton for update;
 if cfg.lease_until>now() or cfg.last_started_at>now()-interval '55 seconds' then return '{}'::jsonb; end if;
 tok:=gen_random_uuid();
 update hockey_odds_configuration set token=tok,lease_until=now()+interval '90 seconds',last_started_at=now() where singleton;
 return jsonb_build_object('token',tok);
end $$;
create function public.hockey_odds_publish(p_token uuid,p_rows jsonb) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare r jsonb; q jsonb; doc jsonb; at timestamptz;
begin
 if not exists(select 1 from hockey_odds_configuration where singleton and token=p_token and lease_until>now()) then raise exception 'Quote lease revoked'; end if;
 if jsonb_typeof(p_rows) is distinct from 'array' or jsonb_array_length(p_rows)>1000 then raise exception 'Invalid quote batch'; end if;
 select payload into doc from sport_feed_snapshots where sport='hockey' order by captured_at desc limit 1;
 for r in select value from jsonb_array_elements(p_rows) loop
  at:=(r->>'collectedAt')::timestamptz;
  if at is null or at>now()+interval '1 minute' or at<now()-interval '5 minutes'
   or jsonb_typeof(r->'quotes') is distinct from 'array' or jsonb_array_length(r->'quotes')>2000
   or not exists(select 1 from jsonb_array_elements(doc->'items') f where f->>'id'=r->>'matchId'
    and f->>'competitionId'=r->>'competitionId' and f->>'season'=r->>'season'
    and f#>>'{home,id}'=r->>'homeId' and f#>>'{away,id}'=r->>'awayId'
    and (f->>'startsAt')::timestamptz>at) then raise exception 'Invalid quote identity'; end if;
  for q in select value from jsonb_array_elements(r->'quotes') loop
   if coalesce(q->>'marketCode','') not in ('result_regulation','double_chance_regulation','total_goals_regulation')
    or coalesce(q->>'selectionCode','') not in ('home','draw','away','home_draw','draw_away','home_away','over','under')
    or q->>'scope' is distinct from 'regulation' or coalesce(q->>'bookmaker','')='' or coalesce(q->>'bookmakerId','')=''
    or (q->>'capturedAt')::timestamptz is distinct from at or jsonb_typeof(q->'decimalOdds') is distinct from 'number'
    or (q->>'decimalOdds')::numeric<=1 or (q->>'decimalOdds')::numeric>100
    or not ((q->>'marketCode'='result_regulation' and q->>'selectionCode' in ('home','draw','away') and not q ? 'line')
      or (q->>'marketCode'='double_chance_regulation' and q->>'selectionCode' in ('home_draw','draw_away','home_away') and not q ? 'line')
      or (q->>'marketCode'='total_goals_regulation' and q->>'selectionCode' in ('over','under') and jsonb_typeof(q->'line')='number'
       and (q->>'line')::numeric between .5 and 15.5 and mod((q->>'line')::numeric,1)=.5)) then raise exception 'Invalid market quote'; end if;
  end loop;
  insert into hockey_market_quotes values(r->>'matchId',r->>'competitionId',r->>'season',r->>'homeId',r->>'awayId',at,r->'quotes')
  on conflict(fixture_id) do update set collected_at=excluded.collected_at,quotes=excluded.quotes,
   competition_id=excluded.competition_id,season=excluded.season,home_id=excluded.home_id,away_id=excluded.away_id
   where excluded.collected_at>hockey_market_quotes.collected_at;
 end loop;
end $$;
create function public.hockey_odds_finish(p_token uuid,p_requests integer,p_error text default null) returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if p_requests not between 0 and 7 then raise exception 'Invalid quote request count'; end if;
 update hockey_odds_configuration set token=null,lease_until=null,last_completed_at=now(),requests_last_run=p_requests,last_error=left(p_error,500),
  last_success_at=case when p_error is null then now() else last_success_at end where singleton and token=p_token;
end $$;

-- Prices are joined by all identity fields, including home/away. Archive prices
-- remain observable after kickoff; freshness is checked by the Generator.
create function public.with_hockey_market_quotes(p_body jsonb) returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
 select case when p_body is null then null else p_body||jsonb_build_object('items',coalesce((select jsonb_agg(
  f||case when q.fixture_id is null then '{}'::jsonb else jsonb_build_object('quotes',q.quotes,'quotesCollectedAt',q.collected_at) end order by n)
  from jsonb_array_elements(p_body->'items') with ordinality x(f,n)
  left join hockey_market_quotes q on q.fixture_id=f->>'id' and q.competition_id=f->>'competitionId'
   and q.season=f->>'season' and q.home_id=f#>>'{home,id}' and q.away_id=f#>>'{away,id}'
   and q.collected_at<=(f->>'startsAt')::timestamptz),'[]'::jsonb)) end;
$$;
alter function public.read_sport_feed(text,date,text,text,timestamptz) rename to read_sport_feed_without_prices;
create function public.read_sport_feed(p_sport text,p_day date default null,p_section text default 'radar',p_match text default null,p_captured_at timestamptz default null)
returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
 select case when p_sport='hockey' then with_hockey_market_quotes(read_sport_feed_without_prices(p_sport,p_day,p_section,p_match,p_captured_at))
 else read_sport_feed_without_prices(p_sport,p_day,p_section,p_match,p_captured_at) end;
$$;
alter function public.lector_generator_published_sources(date,text,text[],text[],text[],jsonb) rename to lector_generator_published_sources_without_prices;
create function public.lector_generator_published_sources(p_date date,p_timezone text,p_sports text[],p_competitions text[] default null,p_readings text[] default null,p_radar jsonb default null)
returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
 select coalesce(jsonb_agg(case when s->>'sport'='hockey' then s||jsonb_build_object('payload',with_hockey_market_quotes(s->'payload')) else s end),'[]')
 from jsonb_array_elements(lector_generator_published_sources_without_prices(p_date,p_timezone,p_sports,p_competitions,p_readings,p_radar)) s;
$$;
revoke all on function public.hockey_odds_claim(),public.hockey_odds_publish(uuid,jsonb),public.hockey_odds_finish(uuid,integer,text),public.with_hockey_market_quotes(jsonb),public.read_sport_feed_without_prices(text,date,text,text,timestamptz),public.lector_generator_published_sources_without_prices(date,text,text[],text[],text[],jsonb),public.read_sport_feed(text,date,text,text,timestamptz),public.lector_generator_published_sources(date,text,text[],text[],text[],jsonb) from public,anon,authenticated;
grant execute on function public.hockey_odds_claim(),public.hockey_odds_publish(uuid,jsonb),public.hockey_odds_finish(uuid,integer,text),public.with_hockey_market_quotes(jsonb),public.read_sport_feed_without_prices(text,date,text,text,timestamptz),public.lector_generator_published_sources_without_prices(date,text,text[],text[],text[],jsonb),public.read_sport_feed(text,date,text,text,timestamptz),public.lector_generator_published_sources(date,text,text[],text[],text[],jsonb) to service_role;
grant execute on function public.read_sport_feed(text,date,text,text,timestamptz) to anon,authenticated;

-- Hosted scheduler (extensions are already installed for live collection).
create function public.hockey_odds_tick() returns bigint language plpgsql security definer set search_path=public,pg_temp as $$
declare cfg ops_configuration;
begin
 select * into cfg from ops_configuration where singleton;
 if cfg.base_url is null or cfg.sync_secret is null then return null; end if;
 return net.http_post(url:=rtrim(cfg.base_url,'/')||'/functions/v1/sync-hockey-odds',
  headers:=jsonb_build_object('Content-Type','application/json','Authorization','Bearer '||cfg.sync_secret),body:='{}'::jsonb,timeout_milliseconds:=60000);
end $$;
revoke all on function public.hockey_odds_tick() from public,anon,authenticated;
grant execute on function public.hockey_odds_tick() to service_role;
select cron.schedule('lector-hockey-odds','17 */6 * * *','select public.hockey_odds_tick();');
notify pgrst, 'reload schema';
