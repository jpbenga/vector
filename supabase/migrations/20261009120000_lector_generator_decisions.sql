-- Workshop sessions and durable choices. Legacy production conversations are unchanged.
create table public.lector_generator_retention (
 id boolean primary key default true check(id), idle_hours integer not null default 24 check(idle_hours between 1 and 168),
 maximum_hours integer not null default 168 check(maximum_hours between 24 and 720), audit_days integer not null default 30 check(audit_days between 1 and 365)
);
insert into public.lector_generator_retention(id) values(true);
alter table public.lector_generator_retention enable row level security;
revoke all on public.lector_generator_retention from public,anon,authenticated;
grant all on public.lector_generator_retention to service_role;
alter table public.lector_generator_conversations add column mode text not null default 'legacy' check(mode in ('legacy','workshop')),
 add column created_at timestamptz not null default now(), add column expires_at timestamptz;
create index on public.lector_generator_conversations(expires_at) where mode='workshop';
create function public.lector_generator_session_guard() returns trigger language plpgsql set search_path=public,pg_temp as $$
declare cfg lector_generator_retention;
begin
 if new.mode='workshop' then
  select * into cfg from lector_generator_retention where id;
  if tg_op='UPDATE' and old.mode='workshop' and old.expires_at<=now() then raise exception 'Session expired'; end if;
  new.expires_at:=least(new.updated_at+make_interval(hours=>cfg.idle_hours),new.created_at+make_interval(hours=>cfg.maximum_hours));
  if new.state ? 'id' then new.state:=new.state||jsonb_build_object('expiresAt',new.expires_at,'sessionStartedAt',new.created_at); end if;
 end if;
 return new;
end $$;
create trigger generator_session_guard before insert or update on public.lector_generator_conversations for each row execute function public.lector_generator_session_guard();

-- No conversation FK: deleting a session cannot delete its retained choices.
create table public.lector_generator_decisions (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 kind text not null check(kind in ('ticket','selection')), source_id text not null, origin_conversation_id uuid not null,
 snapshot jsonb not null check(jsonb_typeof(snapshot)='object'), created_at timestamptz not null default now(),
 relevant boolean not null default false, followed_at timestamptz, saved_at timestamptz, played_at timestamptz,
 supersedes uuid references public.lector_generator_decisions(id) on delete set null,
 result jsonb not null default '{"status":"pending","picks":[]}', verified_at timestamptz,
 unique(user_id,kind,origin_conversation_id,source_id)
);
create index on public.lector_generator_decisions(user_id,created_at desc);
alter table public.lector_generator_decisions enable row level security;
alter table public.lector_generator_decisions force row level security;
revoke all on public.lector_generator_decisions from public,anon,authenticated;
grant all on public.lector_generator_decisions to service_role;
create table public.lector_generator_decision_events (
 id bigint generated always as identity primary key, decision_id uuid not null references public.lector_generator_decisions(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade, action text not null, occurred_at timestamptz not null default now()
);
alter table public.lector_generator_decision_events enable row level security;
alter table public.lector_generator_decision_events force row level security;
revoke all on public.lector_generator_decision_events from public,anon,authenticated;
grant all on public.lector_generator_decision_events to service_role;
grant usage,select on sequence public.lector_generator_decision_events_id_seq to service_role;
create table public.lector_generator_session_audit (
 request_id uuid primary key, user_id uuid not null references auth.users(id) on delete cascade,
 started_at timestamptz not null, status text not null, usage jsonb not null
);
alter table public.lector_generator_session_audit enable row level security;
alter table public.lector_generator_session_audit force row level security;
revoke all on public.lector_generator_session_audit from public,anon,authenticated;
grant all on public.lector_generator_session_audit to service_role;

create table public.lector_generator_proposal_audit (
 user_id uuid not null references auth.users(id) on delete cascade, conversation_id uuid not null,
 source_id text not null, snapshot jsonb not null, generated_at timestamptz not null default now(),
 primary key(user_id,conversation_id,source_id)
);
create table public.lector_generator_outcome_history (
 id bigint generated always as identity primary key,
 decision_id uuid not null references public.lector_generator_decisions(id) on delete cascade,
 result jsonb not null, evaluated_at timestamptz not null default now()
);
alter table public.lector_generator_proposal_audit enable row level security;
alter table public.lector_generator_proposal_audit force row level security;
alter table public.lector_generator_outcome_history enable row level security;
alter table public.lector_generator_outcome_history force row level security;
revoke all on public.lector_generator_proposal_audit,public.lector_generator_outcome_history from public,anon,authenticated;
grant all on public.lector_generator_proposal_audit,public.lector_generator_outcome_history to service_role;
grant usage,select on sequence public.lector_generator_outcome_history_id_seq to service_role;
create function public.lector_generator_proposal_memory() returns trigger language plpgsql set search_path=public,pg_temp as $$
begin
 if new.mode='workshop' and new.state is distinct from old.state then
  insert into lector_generator_proposal_audit(user_id,conversation_id,source_id,snapshot)
  select distinct on(p->>'id') new.user_id,new.id,p->>'id',p from (
    select p from jsonb_array_elements(coalesce(new.state->'tickets','[]')||coalesce(new.state->'proposals','[]')||coalesce(new.state->'drafts','[]')) t cross join lateral jsonb_array_elements(coalesce(t->'picks','[]')) p
    union all select s->'candidate' from jsonb_array_elements(coalesce(new.state->'messages','[]')) m cross join lateral jsonb_array_elements(coalesce(m#>'{analysis,selections}','[]')) s
  ) candidates where p->>'id' is not null on conflict do nothing;
 end if;
 return new;
end $$;
create trigger generator_proposal_memory after update on public.lector_generator_conversations for each row execute function public.lector_generator_proposal_memory();
create function public.lector_generator_outcome_memory() returns trigger language plpgsql set search_path=public,pg_temp as $$
begin
 if new.result is distinct from old.result then insert into lector_generator_outcome_history(decision_id,result) values(new.id,new.result); end if;
 return new;
end $$;
create trigger generator_outcome_memory after update on public.lector_generator_decisions for each row execute function public.lector_generator_outcome_memory();

create function public.lector_generator_session(p_user uuid,p_conversation uuid,p_create boolean default false) returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare c lector_generator_conversations;
begin
 if p_create then insert into lector_generator_conversations(id,user_id,mode) values(p_conversation,p_user,'workshop') on conflict(id) do nothing; end if;
 select * into c from lector_generator_conversations where id=p_conversation for update;
 if not found then return jsonb_build_object('expired',false); end if;
 if c.user_id is distinct from p_user then raise exception 'Unauthorized'; end if;
 if (c.mode='workshop' and c.expires_at<=now()) or (c.mode='legacy' and c.updated_at<=now()-interval '24 hours') then return jsonb_build_object('expired',true); end if;
 -- Adopt a recently used demo session without extending its idle deadline.
 if c.mode='legacy' then
  update lector_generator_conversations set mode='workshop',created_at=least(created_at,updated_at) where id=p_conversation returning * into c;
 end if;
 return jsonb_build_object('expired',false,'expiresAt',c.expires_at,'sessionStartedAt',c.created_at);
end $$;

-- Only identifiers come from the client. The snapshot is resolved from owner-authenticated server objects.
create function public.lector_generator_keep(p_user uuid,p_conversation uuid,p_kind text,p_source text,p_action text,p_supersedes uuid default null) returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare c lector_generator_conversations; item jsonb; snap jsonb; d lector_generator_decisions; changed boolean; session jsonb;
begin
 if p_kind not in ('ticket','selection') or p_action not in ('save','follow','relevant') or (p_kind='ticket' and p_action<>'save') then raise exception 'Invalid action'; end if;
 session:=lector_generator_session(p_user,p_conversation,false);
 if (session->>'expired')::boolean then raise exception 'Session expired'; end if;
 select * into c from lector_generator_conversations where id=p_conversation and user_id=p_user for update;
 if not found then raise exception 'Unauthorized'; end if;
 if p_kind='ticket' and p_supersedes is null and c.state#>>'{intent,action}' in ('replace','remove','restore') then
  select id into p_supersedes from lector_generator_decisions where user_id=p_user and kind='ticket' and origin_conversation_id=p_conversation and source_id=c.state#>>'{intent,referenceTicketId}' order by created_at desc limit 1;
 end if;
 if p_supersedes is not null and not exists(select 1 from lector_generator_decisions where id=p_supersedes and user_id=p_user and kind=p_kind) then raise exception 'Unauthorized version'; end if;
 if p_kind='ticket' then
  select x into item from jsonb_array_elements(coalesce(c.state->'tickets','[]')||coalesce(c.state->'drafts','[]')||coalesce(c.state->'proposals','[]')||coalesce(c.state->'pending','[]')) x where x->>'id'=p_source limit 1;
  if item is null then select ticket into item from lector_generator_ticket_drafts where user_id=p_user and conversation_id=p_conversation and id::text=p_source; end if;
  if item is null or jsonb_array_length(coalesce(item->'picks','[]'))=0 then raise exception 'Unknown ticket'; end if;
  snap:=item;
 else
  select p into item from jsonb_array_elements(coalesce(c.state->'tickets','[]')||coalesce(c.state->'drafts','[]')||coalesce(c.state->'proposals','[]')||coalesce(c.state->'pending','[]')) t cross join lateral jsonb_array_elements(coalesce(t->'picks','[]')) p where p->>'id'=p_source limit 1;
  if item is null then
   select s->'candidate' into item from jsonb_array_elements(coalesce(c.state->'messages','[]')) m cross join lateral jsonb_array_elements(coalesce(m#>'{analysis,selections}','[]')) s where s#>>'{candidate,id}'=p_source limit 1;
  end if;
  if item is null then select p into item from lector_generator_ticket_drafts t cross join lateral jsonb_array_elements(coalesce(t.ticket->'picks','[]')) p where t.user_id=p_user and t.conversation_id=p_conversation and p->>'id'=p_source limit 1; end if;
  if item is null then raise exception 'Unknown selection'; end if;
  snap:=jsonb_build_object('picks',jsonb_build_array(item),'context',c.state->'context');
 end if;
 -- Preserve the explanatory analysis as well as the exact quoted candidate.
 snap:=snap||jsonb_build_object('generationRevision',c.revision,'sourceConversationId',p_conversation,'retainedAt',now(),
 'analysis',coalesce((select m->'analysis' from jsonb_array_elements(coalesce(c.state->'messages','[]')) m where exists(select 1 from jsonb_array_elements(coalesce(m#>'{analysis,selections}','[]')) s where s#>>'{candidate,id}'=p_source) limit 1),'null'));
 insert into lector_generator_decisions(user_id,kind,source_id,origin_conversation_id,snapshot,supersedes) values(p_user,p_kind,p_source,p_conversation,snap,p_supersedes) on conflict(user_id,kind,origin_conversation_id,source_id) do nothing;
 select * into d from lector_generator_decisions where user_id=p_user and kind=p_kind and origin_conversation_id=p_conversation and source_id=p_source for update;
 changed:=case p_action when 'save' then d.saved_at is null when 'follow' then d.followed_at is null else not d.relevant end;
 if changed then
  update lector_generator_decisions set relevant=relevant or p_action='relevant',followed_at=case when p_action='follow' then coalesce(followed_at,now()) else followed_at end,saved_at=case when p_action='save' then coalesce(saved_at,now()) else saved_at end where id=d.id returning * into d;
  insert into lector_generator_decision_events(decision_id,user_id,action) values(d.id,p_user,p_action);
 end if;
 update lector_generator_conversations set updated_at=now() where id=p_conversation returning expires_at into c.expires_at;
 return to_jsonb(d)||jsonb_build_object('sessionExpiresAt',c.expires_at);
end $$;

create function public.lector_generator_decision_action(p_user uuid,p_id uuid,p_action text) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare d lector_generator_decisions; changed boolean;
begin
 select * into d from lector_generator_decisions where id=p_id and user_id=p_user for update;
 if not found then raise exception 'Unauthorized'; end if;
 if p_action='delete' then delete from lector_generator_decisions where id=p_id; return '{}'; end if;
 if p_action not in ('played','unplayed','unfollow','irrelevant') then raise exception 'Invalid action'; end if;
 changed:=case p_action when 'played' then d.played_at is null when 'unplayed' then d.played_at is not null when 'unfollow' then d.followed_at is not null else d.relevant end;
 if not changed then return to_jsonb(d); end if;
 update lector_generator_decisions set played_at=case when p_action='played' then coalesce(played_at,now()) when p_action='unplayed' then null else played_at end,
 followed_at=case when p_action='unfollow' then null else followed_at end,relevant=case when p_action='irrelevant' then false else relevant end where id=p_id returning * into d;
 insert into lector_generator_decision_events(decision_id,user_id,action) values(d.id,p_user,p_action);
 return to_jsonb(d);
end $$;

-- Settlement is deterministic and restricted to the original provider market/value.
-- These football markets refer to regulation time, never extra time/penalty scores.
create function public.lector_generator_settle_pick(p jsonb,r jsonb) returns jsonb language plpgsql immutable set search_path=public,pg_temp as $$
declare h integer; a integer; value text; won boolean; status text:=r->>'status'; market text:=p->>'marketId';
begin
 if r is null or status not in ('FT','AET','PEN','CANC','ABD','AWD','WO','finished','cancelled') then return jsonb_build_object('status','pending','reason','Résultat officiel en attente.'); end if;
 if status in ('CANC','ABD','AWD','WO','cancelled') then return jsonb_build_object('status','unverifiable','reason','Rencontre annulée ou résultat administratif : règlement du bookmaker à confirmer.'); end if;
 if p->>'sport'<>'football' then return jsonb_build_object('status','unverifiable','reason','Règles de règlement de ce marché non prises en charge.'); end if;
 if status='FT' then h:=(r->>'home_goals')::integer; a:=(r->>'away_goals')::integer;
 else h:=(r#>>'{score,fulltime,home}')::integer; a:=(r#>>'{score,fulltime,away}')::integer; end if;
 if h is null or a is null then return jsonb_build_object('status','unverifiable','reason','Score à la fin du temps réglementaire manquant.'); end if;
 value:=split_part(p->>'id',':',4);
 if market='matchResult' and value in ('Home','Away','Draw') then won:=case value when 'Home' then h>a when 'Away' then a>h else h=a end;
 elsif market='doubleChance' and value in ('Home/Draw','Draw/Away','Home/Away') then won:=case value when 'Home/Draw' then h>=a when 'Draw/Away' then a>=h else h<>a end;
 elsif market='goalsTotal' and value in ('Over 2.5','Under 2.5') then won:=case value when 'Over 2.5' then h+a>2.5 else h+a<2.5 end;
 elsif market='bothTeamsScore' and value in ('Yes','No') then won:=case value when 'Yes' then h>0 and a>0 else h=0 or a=0 end;
 else return jsonb_build_object('status','unverifiable','reason','Marché ou valeur non pris en charge ; aucune conclusion déduite.'); end if;
 return jsonb_build_object('status',case when won then 'won' else 'lost' end,'reason','Vérifié sur le score officiel à la fin du temps réglementaire.','homeGoals',h,'awayGoals',a,'source',r->>'id','capturedAt',r->>'captured_at','ruleVersion',1);
end $$;
create function public.lector_generator_ticket_verdict(p_results jsonb) returns text language sql immutable as $$
 select case when jsonb_array_length(p_results)=0 then 'unverifiable'
 when exists(select 1 from jsonb_array_elements(p_results) x where x->>'status'='lost') then 'lost'
 when exists(select 1 from jsonb_array_elements(p_results) x where x->>'status'='pending') then 'pending'
 when exists(select 1 from jsonb_array_elements(p_results) x where x->>'status'='unverifiable') then 'unverifiable'
 when not exists(select 1 from jsonb_array_elements(p_results) x where x->>'status'='won') then 'void'
 else 'won' end
$$;
create function public.lector_generator_verify(p_user uuid default null) returns integer language plpgsql security definer set search_path=public,pg_temp as $$
declare d lector_generator_decisions; p jsonb; r jsonb; results jsonb; outcome jsonb; v_result jsonb; n integer:=0; fixture integer;
begin
 for d in select * from lector_generator_decisions where (p_user is null or user_id=p_user) and (saved_at is not null or followed_at is not null or played_at is not null) order by (result->>'status'='pending') desc,verified_at nulls first limit 2000 loop
  results:='[]';
  for p in select * from jsonb_array_elements(coalesce(d.snapshot->'picks','[]')) loop
   r:=null;
   if p->>'sport'='football' and p->>'matchId' ~ '^api-fixture-[0-9]+$' and to_regclass('public.match_result_snapshots') is not null then
    fixture:=replace(p->>'matchId','api-fixture-','')::integer;
    execute 'select to_jsonb(r) from match_result_snapshots r where fixture_id=$1 order by captured_at desc,created_at desc,id desc limit 1' into r using fixture;
    if r is null and to_regclass('public.match_live_states') is not null then execute 'select to_jsonb(r) from match_live_states r where fixture_id=$1' into r using fixture; end if;
   elsif p->>'sport'='hockey' and to_regclass('public.sport_live_states') is not null then
    execute 'select payload from sport_live_states where sport=''hockey'' and fixture_id=$1' into r using regexp_replace(p->>'matchId','^.*:fixture:','');
   end if;
   outcome:=lector_generator_settle_pick(p,r)||jsonb_build_object('selectionId',p->>'id');
   results:=results||jsonb_build_array(outcome);
  end loop;
  v_result:=jsonb_build_object('status',lector_generator_ticket_verdict(results),'picks',results,'ruleVersion',1);
  if d.result is distinct from v_result then update lector_generator_decisions set result=v_result,verified_at=now() where id=d.id; n:=n+1;
  else update lector_generator_decisions set verified_at=now() where id=d.id; end if;
 end loop;
 return n;
end $$;

-- Lightweight list: original evidence is fetched only when opening a retained object.
create function public.lector_generator_decision_list(p_user uuid,p_offset integer default 0) returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
 with page as (select * from lector_generator_decisions where user_id=p_user order by created_at desc,id desc limit 21 offset least(greatest(p_offset,0),100000)),
 compact as (select id,created_at,jsonb_build_object('id',id,'kind',kind,'source_id',source_id,'created_at',created_at,'relevant',relevant,'followed_at',followed_at,'saved_at',saved_at,'played_at',played_at,'supersedes',supersedes,'result',result,'summaryOnly',true,
 'snapshot',jsonb_build_object('number',snapshot->'number','picks',coalesce((select jsonb_agg(jsonb_build_object('id',p->'id','home',p->'home','away',p->'away','selection',p->'selection','odds',p->'odds')) from jsonb_array_elements(snapshot->'picks') p),'[]'))) value from page order by created_at desc,id desc limit 20)
 select jsonb_build_object('decisions',coalesce((select jsonb_agg(value order by created_at desc,id desc) from compact),'[]'),'hasMore',(select count(*)>20 from page),
 'counts',(select jsonb_build_object('tickets',count(*) filter(where kind='ticket' and saved_at is not null),'followed',count(*) filter(where kind='selection' and followed_at is not null),'feedback',count(*) filter(where relevant and saved_at is null and followed_at is null)) from lector_generator_decisions where user_id=p_user))
$$;

create function public.lector_generator_cleanup() returns integer language plpgsql security definer set search_path=public,pg_temp as $$
declare n integer; days integer;
begin
 select audit_days into days from lector_generator_retention where id;
 insert into lector_generator_session_audit(request_id,user_id,started_at,status,usage)
 select t.request_id,t.user_id,t.started_at,t.status,jsonb_build_object('ai',t.usage->'ai','timings_ms',t.usage->'timings_ms')
 from lector_generator_turns t join lector_generator_conversations c on c.id=t.conversation_id where c.mode='workshop' and c.expires_at<=now() on conflict(request_id) do nothing;
 delete from lector_generator_conversations where mode='workshop' and expires_at<=now(); get diagnostics n=row_count;
 delete from lector_generator_session_audit where started_at<now()-make_interval(days=>days);
 delete from lector_generator_proposal_audit where generated_at<now()-make_interval(days=>days);
 return n;
end $$;
-- Before-commit trigger injects server timestamps; return the actual stored state.
create or replace function public.lector_generator_commit(p_user uuid,p_conversation uuid,p_revision integer,p_state jsonb,p_request uuid default null,p_usage jsonb default null)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare result jsonb; owner uuid; t lector_generator_turns;
begin
 if jsonb_typeof(p_state)<>'object' or length(p_state::text)>250000 then raise exception 'Invalid conversation state'; end if;
 select user_id into owner from lector_generator_conversations where id=p_conversation for update;
 if owner is distinct from p_user then raise exception 'Unauthorized'; end if;
 if p_request is not null then
  select * into t from lector_generator_turns where request_id=p_request for update;
  if t.user_id is distinct from p_user or t.conversation_id<>p_conversation or t.status<>'pending' then raise exception 'Invalid reservation'; end if;
 end if;
 insert into lector_generator_ticket_drafts(id,conversation_id,user_id,ticket)
 select distinct on(x->>'id') (x->>'id')::uuid,p_conversation,p_user,x from jsonb_array_elements(coalesce(p_state->'drafts','[]')||coalesce(p_state->'tickets','[]')||coalesce(p_state->'proposals','[]')||case when jsonb_typeof(p_state->'pending')='array' then p_state->'pending' else '[]' end) x on conflict(id) do nothing;
 result:=p_state||jsonb_build_object('revision',p_revision+1,'updatedAt',now());
 update lector_generator_conversations set state=result,revision=p_revision+1,updated_at=now() where id=p_conversation and user_id=p_user and revision=p_revision returning state into result;
 if not found then raise exception 'Conversation changed'; end if;
 if p_request is not null then update lector_generator_turns set status='complete',response=result,usage=p_usage where request_id=p_request; end if;
 return result;
end $$;
revoke all on function public.lector_generator_session(uuid,uuid,boolean),public.lector_generator_keep(uuid,uuid,text,text,text,uuid),public.lector_generator_decision_action(uuid,uuid,text),public.lector_generator_verify(uuid),public.lector_generator_decision_list(uuid,integer),public.lector_generator_cleanup(),public.lector_generator_settle_pick(jsonb,jsonb),public.lector_generator_ticket_verdict(jsonb),public.lector_generator_session_guard(),public.lector_generator_proposal_memory(),public.lector_generator_outcome_memory() from public,anon,authenticated;
grant execute on function public.lector_generator_session(uuid,uuid,boolean),public.lector_generator_keep(uuid,uuid,text,text,text,uuid),public.lector_generator_decision_action(uuid,uuid,text),public.lector_generator_verify(uuid),public.lector_generator_decision_list(uuid,integer),public.lector_generator_cleanup() to service_role;
do $$ begin
 if exists(select 1 from pg_extension where extname='pg_cron') then
  perform cron.schedule('lector-generator-decisions','*/5 * * * *','select public.lector_generator_verify(); select public.lector_generator_cleanup();');
 end if;
end $$;
notify pgrst,'reload schema';
