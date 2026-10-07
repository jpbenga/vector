-- Public delivery pointers contain no account data or provider responses.
-- Originals and public compact snapshots keep their existing contracts.
create table public.sport_feed_delivery_parts (
  sport text not null check (sport in ('football','hockey')),
  source_id text not null, scope_key text not null,
  captured_at timestamptz not null, as_of timestamptz not null,
  window_start date not null, window_end date not null,
  full_path text not null, overview jsonb not null,
  primary key (sport,source_id), check (window_end >= window_start)
);
create index sport_feed_delivery_parts_lookup on public.sport_feed_delivery_parts(sport,scope_key,as_of desc);
create table public.sport_feed_delivery_jobs (
  sport text primary key check (sport in ('football','hockey')),
  enabled boolean not null default false,
  revision bigint not null default 0, completed_revision bigint not null default -1,
  token uuid, lease_until timestamptz, last_error text
);
insert into public.sport_feed_delivery_jobs(sport) values ('football'),('hockey');
create table public.sport_feed_delivery_heads (
  sport text not null check (sport in ('football','hockey')), day date not null,
  manifest jsonb not null, updated_at timestamptz not null default now(),
  primary key (sport,day)
);
alter table public.sport_feed_delivery_parts enable row level security;
alter table public.sport_feed_delivery_parts force row level security;
alter table public.sport_feed_delivery_jobs enable row level security;
alter table public.sport_feed_delivery_jobs force row level security;
alter table public.sport_feed_delivery_heads enable row level security;
alter table public.sport_feed_delivery_heads force row level security;
revoke all on public.sport_feed_delivery_parts,public.sport_feed_delivery_jobs,public.sport_feed_delivery_heads from public,anon,authenticated;
grant all on public.sport_feed_delivery_parts,public.sport_feed_delivery_jobs,public.sport_feed_delivery_heads to service_role;
grant select on public.sport_feed_delivery_heads to anon,authenticated;
create policy delivery_head_read on public.sport_feed_delivery_heads for select to anon,authenticated using(true);

create function public.feed_delivery_register(p_sport text,p_source_id text,p_scope_key text,p_captured_at timestamptz,p_as_of timestamptz,p_window_start date,p_window_end date,p_full_path text,p_overview jsonb)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if p_full_path !~ ('^delivery/'||p_sport||'/[a-zA-Z0-9_-]+/full[.]json$')
    or jsonb_typeof(p_overview) is distinct from 'object' then raise exception 'Invalid delivery part'; end if;
  insert into sport_feed_delivery_parts values(p_sport,p_source_id,p_scope_key,p_captured_at,p_as_of,p_window_start,p_window_end,p_full_path,p_overview)
  on conflict(sport,source_id) do nothing;
  if found then update sport_feed_delivery_jobs set revision=revision+1 where sport=p_sport; end if;
end $$;


create function public.feed_delivery_parts_for_day(p_sport text,p_day date) returns jsonb
language sql stable security definer set search_path=public,pg_temp as $$
  select coalesce(jsonb_agg(to_jsonb(chosen)-'overview' order by chosen.as_of desc),'[]'::jsonb)
  from (
    select distinct on(scope_key) * from sport_feed_delivery_parts
    where sport=p_sport and (
      p_day >= (now() at time zone 'Europe/Paris')::date
      or (window_start<=p_day and window_end>=p_day
        and as_of < ((p_day+1)::timestamp at time zone 'Europe/Paris'))
    )
    order by scope_key,
      case when window_start<=p_day and window_end>=p_day then 0 else 1 end,
      as_of desc,source_id desc
  ) chosen;
$$;
revoke all on function public.feed_delivery_parts_for_day(text,date) from public,anon,authenticated;
grant execute on function public.feed_delivery_parts_for_day(text,date) to service_role;

create function public.feed_delivery_claim(p_sport text) returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare cfg sport_feed_delivery_jobs; tok uuid;
begin
  select * into cfg from sport_feed_delivery_jobs where sport=p_sport for update;
  if not found or not cfg.enabled or cfg.revision=cfg.completed_revision or cfg.lease_until>now() then return '{}'::jsonb; end if;
  tok:=gen_random_uuid();
  update sport_feed_delivery_jobs set token=tok,lease_until=now()+interval '120 seconds' where sport=p_sport;
  return jsonb_build_object('token',tok,'revision',cfg.revision);
end $$;

create function public.feed_delivery_finish(p_sport text,p_token uuid,p_revision bigint,p_manifests jsonb,p_error text default null) returns boolean
language plpgsql security definer set search_path=public,pg_temp as $$
declare cfg sport_feed_delivery_jobs; item jsonb;
begin
  select * into cfg from sport_feed_delivery_jobs where sport=p_sport for update;
  if not found or cfg.token is distinct from p_token or cfg.lease_until<=now() then return false; end if;
  -- Never install an older worker's pointer after new parts arrived.
  if cfg.revision<>p_revision or p_error is not null then
    update sport_feed_delivery_jobs set token=null,lease_until=null,last_error=p_error where sport=p_sport;
    return false;
  end if;
  if jsonb_typeof(p_manifests) is distinct from 'array' then raise exception 'Invalid delivery manifests'; end if;
  for item in select * from jsonb_array_elements(p_manifests) loop
    if item->>'sport' is distinct from p_sport or item->>'schemaVersion' is distinct from '1'
      or item->>'path' !~ ('^delivery/'||p_sport||'/[a-zA-Z0-9_-]+/[a-zA-Z0-9_.-]+[.]json$') then raise exception 'Invalid delivery manifest'; end if;
    insert into sport_feed_delivery_heads(sport,day,manifest) values(p_sport,(item->>'day')::date,item)
      on conflict(sport,day) do update set manifest=excluded.manifest,updated_at=now();
  end loop;
  update sport_feed_delivery_jobs set completed_revision=p_revision,token=null,lease_until=null,last_error=null where sport=p_sport;
  return true;
end $$;
revoke all on function public.feed_delivery_register(text,text,text,timestamptz,timestamptz,date,date,text,jsonb), public.feed_delivery_claim(text),public.feed_delivery_finish(text,uuid,bigint,jsonb,text) from public,anon,authenticated;
grant execute on function public.feed_delivery_register(text,text,text,timestamptz,timestamptz,date,date,text,jsonb), public.feed_delivery_claim(text),public.feed_delivery_finish(text,uuid,bigint,jsonb,text) to service_role;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('lector-feed-delivery','lector-feed-delivery',true,33554432,array['application/json']) on conflict(id) do nothing;
-- No client upload/update/delete policy is installed.
create function public.feed_delivery_tick() returns void
language plpgsql security definer set search_path=public,extensions,pg_temp as $$
declare cfg ops_configuration; s text;
begin
  select * into cfg from ops_configuration where singleton;
  if cfg.base_url is null or cfg.sync_secret is null then return; end if;
  for s in select sport from sport_feed_delivery_jobs where enabled and revision<>completed_revision and (lease_until is null or lease_until<=now()) loop
    perform net.http_post(url:=cfg.base_url||'/functions/v1/build-feed-delivery',
      headers:=jsonb_build_object('authorization','Bearer '||cfg.sync_secret,'Content-Type','application/json'),
      body:=jsonb_build_object('sport',s),timeout_milliseconds:=120000);
  end loop;
end $$;
revoke all on function public.feed_delivery_tick() from public,anon,authenticated;
grant execute on function public.feed_delivery_tick() to service_role;
select cron.schedule('lector-feed-delivery','*/5 * * * *','select public.feed_delivery_tick();');
