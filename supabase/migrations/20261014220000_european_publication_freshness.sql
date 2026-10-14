-- Disabled until the operator approves activation after publishing the three
-- collector functions. Calendar publications remain immutable and available.
create table public.european_refresh_control (
  singleton boolean primary key default true check(singleton),
  enabled boolean not null default false
);
insert into public.european_refresh_control(singleton) values(true);
alter table public.european_refresh_control enable row level security;
alter table public.european_refresh_control force row level security;
revoke all on public.european_refresh_control from public,anon,authenticated;
grant select,update on public.european_refresh_control to service_role;

create function public.european_publication_health(p_now timestamptz default now())
returns table(league_id integer,source_id uuid,analysis_as_of timestamptz,
  next_kickoff timestamptz,upcoming_count bigint,oldest_quote_update timestamptz,
  missing_or_old_quotes bigint,needs_refresh boolean,analytically_stale boolean)
language sql stable security definer set search_path=public,pg_temp as $$
with leagues(id) as(values(2),(3),(848)), sources as (
 select l.id league_id,a.* from leagues l cross join lateral(
  select a.* from match_feed_analysis_snapshots a
  where a.league_ids=array[l.id] and a.window_start <= (p_now at time zone 'Europe/Paris')::date
    and a.window_end >= (p_now at time zone 'Europe/Paris')::date and a.captured_at<=p_now
  order by a.as_of desc,a.created_at desc,a.id desc limit 1
 ) a
), fixtures as (
 select s.league_id,s.id source_id,
   coalesce(nullif(s.payload#>>'{quoteRevision,analysisAsOf}','')::timestamptz,s.as_of) analysis_as_of,
   f#>>'{fixture,id}' fixture_id,(f#>>'{fixture,date}')::timestamptz kickoff,s.payload
 from sources s cross join lateral jsonb_array_elements(coalesce(s.payload#>'{raw,fixtures}','[]')) f
 where f#>>'{fixture,status,short}' in ('NS','TBD')
   and (f#>>'{fixture,date}')::timestamptz>p_now
   and (f#>>'{fixture,date}')::timestamptz<=p_now+interval '6 hours'
), priced as (
 select f.*,q.updated from fixtures f left join lateral(
   select max(nullif(o->>'update','')::timestamptz) updated
   from jsonb_array_elements(coalesce(f.payload#>'{raw,odds}','[]')) o
   where o#>>'{fixture,id}'=f.fixture_id and jsonb_array_length(coalesce(o->'bookmakers','[]'))>0
 ) q on true
)
select league_id,source_id,analysis_as_of,min(kickoff),count(*),min(updated),
 count(*) filter(where updated is null or updated<p_now-interval '48 hours'),
 analysis_as_of<p_now-interval '12 hours' or bool_or(updated is null or updated<p_now-interval '24 hours'),
 analysis_as_of<p_now-interval '36 hours'
from priced group by league_id,source_id,analysis_as_of;
$$;
revoke all on function public.european_publication_health(timestamptz) from public,anon,authenticated;
grant execute on function public.european_publication_health(timestamptz) to service_role;

create table public.european_publication_alerts (
 league_id integer not null check(league_id in(2,3,848)),
 hour_bucket timestamptz not null,health jsonb not null,
 created_at timestamptz not null default now(),primary key(league_id,hour_bucket)
);
alter table public.european_publication_alerts enable row level security;
alter table public.european_publication_alerts force row level security;
revoke all on public.european_publication_alerts from public,anon,authenticated;
grant select,insert,delete on public.european_publication_alerts to service_role;

create function public.european_publication_tick(p_now timestamptz default now())
returns integer language plpgsql security definer set search_path=public,pg_temp as $$
declare h record;n integer:=0; inserted integer;v_hour timestamptz:=date_trunc('hour',p_now);
begin
 if not coalesce((select enabled from european_refresh_control where singleton),false) then return 0;end if;
 -- Only technical sporting health, no conversations, tokens or credentials.
 delete from european_publication_alerts where created_at<p_now-interval '30 days';
 for h in select * from european_publication_health(p_now) where needs_refresh loop
  insert into european_publication_alerts(league_id,hour_bucket,health,created_at)
    values(h.league_id,v_hour,to_jsonb(h),p_now) on conflict do nothing;
  get diagnostics inserted=row_count;
  if inserted>0 then
   insert into ops_events(actor,kind,message) values('european-freshness','publication_freshness',
     jsonb_build_object('competitionId',h.league_id,'sourceId',h.source_id,'analysisAsOf',h.analysis_as_of,
       'nextKickoff',h.next_kickoff,'upcoming',h.upcoming_count,'oldestQuoteUpdate',h.oldest_quote_update,
       'missingOrOldQuotes',h.missing_or_old_quotes,'analyticallyStale',h.analytically_stale)::text);
  end if;
  if not exists(select 1 from api_football_sync_queue_jobs where status in('queued','running','retrying')
    and cancel_requested_at is null and payload->'league_ids' @> jsonb_build_array(h.league_id)) then
   insert into api_football_sync_queue_jobs(dedupe_key,payload,priority)
    values('prematch:'||h.league_id||':'||v_hour::text,
      jsonb_build_object('league_ids',jsonb_build_array(h.league_id),'timezone','Europe/Paris',
        'bounded_european',true,'window_start',(p_now at time zone 'Europe/Paris')::date,
        'window_end',(p_now at time zone 'Europe/Paris')::date+13,'trigger','prematch_freshness'),500)
    on conflict(dedupe_key) do nothing;
   get diagnostics inserted=row_count;n:=n+inserted;
  end if;
 end loop;
 return n;
end;
$$;
revoke all on function public.european_publication_tick(timestamptz) from public,anon,authenticated;
grant execute on function public.european_publication_tick(timestamptz) to service_role;

-- Separate operator activation: enable the control row AND the cron after
-- verified function deployment. No remote HTTP call or provider call here.
select cron.schedule('lector-european-prematch-freshness','*/15 * * * *',
  'select public.european_publication_tick();');
select cron.alter_job(job_id:=jobid,active:=false) from cron.job
 where jobname='lector-european-prematch-freshness';
