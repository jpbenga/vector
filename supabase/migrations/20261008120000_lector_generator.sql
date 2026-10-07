-- Independent AI drafts. No change to football/hockey collection or existing tickets.
create table public.lector_generator_conversations (
 id uuid primary key, user_id uuid not null references auth.users(id) on delete cascade,
 revision integer not null default 0, state jsonb not null default '{}',
 updated_at timestamptz not null default now()
);
create table public.lector_generator_turns (
 request_id uuid primary key, user_id uuid not null references auth.users(id) on delete cascade,
 conversation_id uuid not null references public.lector_generator_conversations(id) on delete cascade,
 started_at timestamptz not null default now(), status text not null default 'pending' check(status in ('pending','complete','failed')),
 response jsonb, usage jsonb
);
create index on public.lector_generator_turns(user_id,started_at desc);
create table public.lector_generator_usage (
 day date not null, user_id uuid not null, calls integer not null default 0,
 primary key(day,user_id)
);
-- Lifetime test envelope, never automatically reset. Reserve conservatively
-- for a bounded GPT-4.1 mini request, including failed/unfinished calls.
create table public.lector_generator_budget (
 id boolean primary key default true check(id), limit_usd numeric(10,4) not null default 3 check(limit_usd>=0),
 reserved_usd numeric(10,4) not null default 0 check(reserved_usd>=0)
);
insert into public.lector_generator_budget(id) values(true);
alter table public.lector_generator_conversations enable row level security;
alter table public.lector_generator_conversations force row level security;
alter table public.lector_generator_turns enable row level security;
alter table public.lector_generator_turns force row level security;
alter table public.lector_generator_usage enable row level security;
alter table public.lector_generator_usage force row level security;
alter table public.lector_generator_budget enable row level security;
alter table public.lector_generator_budget force row level security;
revoke all on public.lector_generator_budget from public,anon,authenticated;
grant all on public.lector_generator_budget to service_role;
revoke all on public.lector_generator_conversations,public.lector_generator_turns,public.lector_generator_usage from anon,authenticated;
grant select on public.lector_generator_conversations to authenticated;
create policy own_generator_history on public.lector_generator_conversations for select to authenticated using(auth.uid()=user_id);
grant all on public.lector_generator_conversations,public.lector_generator_turns,public.lector_generator_usage to service_role;

create function public.lector_generator_reserve(p_user uuid,p_conversation uuid,p_request uuid,p_revision integer,p_user_limit integer default 10,p_global_limit integer default 100)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare c lector_generator_conversations; t lector_generator_turns; n integer; d date:=(now() at time zone 'UTC')::date;
begin
 -- Serialize global usage reservations; duplicates and concurrent tabs cannot
 -- bypass limits or execute simultaneous edits to the same conversation.
 perform pg_advisory_xact_lock(814208);
 select * into t from lector_generator_turns where request_id=p_request;
 if found then
  if t.user_id<>p_user or t.conversation_id<>p_conversation then raise exception 'Unauthorized'; end if;
  return jsonb_build_object('cached',t.response,'status',t.status);
 end if;
 insert into lector_generator_conversations(id,user_id) values(p_conversation,p_user) on conflict(id) do nothing;
 select * into c from lector_generator_conversations where id=p_conversation for update;
 if c.user_id<>p_user then raise exception 'Unauthorized'; end if;
 if c.revision<>p_revision then raise exception 'Conversation changed'; end if;
 if exists(select 1 from lector_generator_turns where conversation_id=p_conversation and status='pending' and started_at>now()-interval '2 minutes') then raise exception 'Generation already running'; end if;
 if exists(select 1 from lector_generator_turns where user_id=p_user and started_at>now()-interval '10 seconds') then raise exception 'Please wait before another request'; end if;
 select coalesce(sum(calls),0) into n from lector_generator_usage where day=d;
 if n>=least(greatest(p_global_limit,1),1000) then raise exception 'Daily generator limit reached'; end if;
 select calls into n from lector_generator_usage where day=d and user_id=p_user;
 if coalesce(n,0)>=least(greatest(p_user_limit,1),20) then raise exception 'Daily account limit reached'; end if;
 update lector_generator_budget set reserved_usd=reserved_usd+0.025 where id=true and reserved_usd+0.025<=limit_usd;
 if not found then raise exception 'Generator test budget limit reached'; end if;
 insert into lector_generator_usage values(d,p_user,1) on conflict(day,user_id) do update set calls=lector_generator_usage.calls+1;
 insert into lector_generator_turns(request_id,user_id,conversation_id) values(p_request,p_user,p_conversation);
 return jsonb_build_object('status','reserved');
end $$;

create function public.lector_generator_commit(p_user uuid,p_conversation uuid,p_revision integer,p_state jsonb,p_request uuid default null,p_usage jsonb default null)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare result jsonb; owner uuid; t lector_generator_turns;
begin
 if jsonb_typeof(p_state)<>'object' or length(p_state::text)>250000 then raise exception 'Invalid conversation state'; end if;
 select user_id into owner from lector_generator_conversations where id=p_conversation for update;
 if owner is distinct from p_user then raise exception 'Unauthorized'; end if;
 if p_request is not null then
  select * into t from lector_generator_turns where request_id=p_request;
  if t.user_id is distinct from p_user or t.conversation_id<>p_conversation or t.status<>'pending' then raise exception 'Invalid reservation'; end if;
 end if;
 result:=p_state || jsonb_build_object('revision',p_revision+1,'updatedAt',now());
 update lector_generator_conversations set state=result,revision=p_revision+1,updated_at=now() where id=p_conversation and user_id=p_user and revision=p_revision;
 if not found then raise exception 'Conversation changed'; end if;
 if p_request is not null then update lector_generator_turns set status='complete',response=result,usage=p_usage where request_id=p_request; end if;
 return result;
end $$;

-- Reduced authoritative material: no client supplied prices or analyses.
-- This works even before the optional delivery-storage migration is installed.
create function public.lector_generator_sources(p_date date,p_timezone text default 'Europe/Paris') returns jsonb
language sql stable security definer set search_path=public,pg_temp as $$
 with football as (
 select distinct on(scope_key) id,captured_at,payload from match_feed_analysis_snapshots
 where window_start<=p_date and window_end>=p_date and captured_at<=now() and captured_at>now()-interval '36 hours'
 order by scope_key,as_of desc,id desc
 ), f as (
 select id,captured_at,
 coalesce((select jsonb_agg(x) from jsonb_array_elements(coalesce(payload#>'{raw,fixtures}','[]')) x where (x#>>'{fixture,date}')::timestamptz at time zone p_timezone >= p_date and ((x#>>'{fixture,date}')::timestamptz at time zone p_timezone)::date=p_date),'[]') fixtures,
 payload from football
 ), source as (
 select id::text id,'football' sport,captured_at,
 jsonb_build_object('raw',jsonb_build_object('fixtures',fixtures,
 'odds',coalesce((select jsonb_agg(x) from jsonb_array_elements(coalesce(payload#>'{raw,odds}','[]')) x where x#>>'{fixture,id}' in(select y#>>'{fixture,id}' from jsonb_array_elements(fixtures) y)),'[]'),
 'player_form_radar',coalesce(payload#>'{raw,player_form_radar}','[]')),
 'computed',jsonb_build_object('fixtures',coalesce((select jsonb_agg(x) from jsonb_array_elements(coalesce(payload#>'{computed,fixtures}','[]')) x where x->>'fixture_id' in(select y#>>'{fixture,id}' from jsonb_array_elements(fixtures) y)),'[]'))) payload from f
 union all
 select run_id::text,'hockey',captured_at,jsonb_build_object('items',coalesce((select jsonb_agg(x) from jsonb_array_elements(coalesce(payload->'items','[]')) x where ((x->>'startsAt')::timestamptz at time zone p_timezone)::date=p_date),'[]'),'playerRadar',payload->'playerRadar','competitions',coalesce((select jsonb_agg(jsonb_build_object('id',x->'id','formPhaseVerified',x->'formPhaseVerified')) from jsonb_array_elements(coalesce(payload->'competitions','[]')) x),'[]'))
 from sport_feed_publications where sport='hockey' and captured_at>now()-interval '36 hours'
 ) select coalesce(jsonb_agg(jsonb_build_object('id',id,'sport',sport,'capturedAt',captured_at,'payload',payload)),'[]') from source;
$$;
revoke all on function public.lector_generator_reserve(uuid,uuid,uuid,integer,integer,integer),public.lector_generator_commit(uuid,uuid,integer,jsonb,uuid,jsonb),public.lector_generator_sources(date,text) from public,anon,authenticated;
grant execute on function public.lector_generator_reserve(uuid,uuid,uuid,integer,integer,integer),public.lector_generator_commit(uuid,uuid,integer,jsonb,uuid,jsonb),public.lector_generator_sources(date,text) to service_role;
