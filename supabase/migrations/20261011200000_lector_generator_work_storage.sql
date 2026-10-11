-- Temporary work objects are independent of the bounded conversational state.
-- Cascade only with their conversation; retained decisions keep their own snapshot.
create table public.lector_generator_messages (
 id uuid primary key, conversation_id uuid not null references public.lector_generator_conversations(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 position bigint generated always as identity, body jsonb not null check(jsonb_typeof(body)='object')
);
create index on public.lector_generator_messages(conversation_id,position desc);
create table public.lector_generator_work_turns (
 id uuid primary key, conversation_id uuid not null references public.lector_generator_conversations(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 position bigint generated always as identity, body jsonb not null check(jsonb_typeof(body)='object')
);
create index on public.lector_generator_work_turns(conversation_id,position desc);
alter table public.lector_generator_messages enable row level security;
alter table public.lector_generator_messages force row level security;
alter table public.lector_generator_work_turns enable row level security;
alter table public.lector_generator_work_turns force row level security;
revoke all on public.lector_generator_messages,public.lector_generator_work_turns from public,anon,authenticated;
grant all on public.lector_generator_messages,public.lector_generator_work_turns to service_role;
grant usage,select on sequence public.lector_generator_messages_position_seq,public.lector_generator_work_turns_position_seq to service_role;

create function public.lector_generator_work_read(p_user uuid,p_conversation uuid,p_full boolean default false,p_state jsonb default null) returns jsonb
language plpgsql stable security definer set search_path=public,pg_temp as $$
declare c lector_generator_conversations; result jsonb; field text; n integer;
begin
 select * into c from lector_generator_conversations where id=p_conversation;
 if not found then return null; end if;
 if c.user_id is distinct from p_user then raise exception 'Unauthorized'; end if;
 if c.mode='workshop' and c.expires_at<=now() then raise exception 'Session expired'; end if;
 c.state:=coalesce(p_state,c.state);
 if c.state->>'storageVersion' is distinct from '2' then return nullif(c.state,'{}'); end if;
 result:=c.state;
 foreach field in array array['tickets','drafts','proposals','pending'] loop
  if jsonb_typeof(c.state->field)='array' then
   result:=jsonb_set(result,array[field],coalesce((select jsonb_agg(d.ticket order by r.ord) from jsonb_array_elements(c.state->field) with ordinality r(ref,ord)
    join lector_generator_ticket_drafts d on d.id::text=r.ref->>'id' and d.user_id=p_user and d.conversation_id=p_conversation),'[]'));
  end if;
 end loop;
 result:=jsonb_set(result,'{versions}',coalesce((select jsonb_agg(coalesce((select jsonb_agg(d.ticket order by r.ord) from jsonb_array_elements(v.refs) with ordinality r(ref,ord)
  join lector_generator_ticket_drafts d on d.id::text=r.ref->>'id' and d.user_id=p_user and d.conversation_id=p_conversation),'[]') order by v.ord) from jsonb_array_elements(coalesce(c.state->'versions','[]')) with ordinality v(refs,ord)),'[]'));
  result:=jsonb_set(result,'{messages}',coalesce((select jsonb_agg(case when p_full then m.body else (m.body-'analysis')||case when m.body ? 'analysis' then jsonb_build_object('analysisRef',m.id) else '{}' end end order by r.ord) from jsonb_array_elements(c.state->'messages') with ordinality r(ref,ord)
   join lector_generator_messages m on m.id::text=r.ref->>'id' and m.user_id=p_user and m.conversation_id=p_conversation),'[]'));
 select count(*) into n from lector_generator_messages where user_id=p_user and conversation_id=p_conversation;
 result:=jsonb_set(result,'{compositions}',coalesce((select jsonb_agg(distinct key) from (
  select ticket->>'workFingerprint' key from lector_generator_ticket_drafts where user_id=p_user and conversation_id=p_conversation and ticket ? 'workFingerprint'
  union all select jsonb_array_elements_text(coalesce(c.state->'compositions','[]'))
 ) fingerprints where key is not null),'[]'));
 return result||jsonb_build_object('history',jsonb_build_object('messages',n,'offset',least(n,20),'hasMore',n>20));
end $$;

create function public.lector_generator_work_history(p_user uuid,p_conversation uuid,p_offset integer default 0,p_limit integer default 20,p_full boolean default true) returns jsonb
language plpgsql stable security definer set search_path=public,pg_temp as $$
declare c lector_generator_conversations; result jsonb;
begin
 select * into c from lector_generator_conversations where id=p_conversation;
 if not found or c.user_id is distinct from p_user then raise exception 'Unauthorized'; end if;
 if c.mode='workshop' and c.expires_at<=now() then raise exception 'Session expired'; end if;
 if p_offset<0 or p_limit<1 or p_limit>20 then raise exception 'Invalid page'; end if;
 with page as (select position,body from lector_generator_messages where conversation_id=p_conversation and user_id=p_user order by position desc offset p_offset limit p_limit)
 select jsonb_build_object('messages',coalesce(jsonb_agg(case when p_full then body else (body-'analysis')||case when body ? 'analysis' then jsonb_build_object('analysisRef',body->'id','analysis',jsonb_build_object('context',body#>'{analysis,context}')) else '{}' end end order by position),'[]'),'offset',p_offset+count(*),
  'hasMore',(select count(*) from lector_generator_messages where conversation_id=p_conversation and user_id=p_user)>p_offset+count(*)) into result from page;
 return result||jsonb_build_object('drafts',case when p_full then coalesce((select jsonb_agg(ticket) from lector_generator_ticket_drafts where user_id=p_user and conversation_id=p_conversation and id::text in(select jsonb_array_elements_text(coalesce(m->'ticketIds','[]')||coalesce(m->'proposalIds','[]')) from jsonb_array_elements(result->'messages') m)),'[]') else '[]' end,'turns',coalesce((select jsonb_agg(body order by position) from (select body,position from lector_generator_work_turns where conversation_id=p_conversation and user_id=p_user order by position desc offset p_offset/2 limit p_limit) t),'[]'),
 'tickets',coalesce((select jsonb_agg(jsonb_build_object('id',id,'number',ticket->'number','selections',jsonb_array_length(coalesce(ticket->'picks','[]'))) order by created_at,id) from
  (select * from lector_generator_ticket_drafts where conversation_id=p_conversation and user_id=p_user order by created_at desc,id desc offset p_offset limit p_limit) d),'[]'));
end $$;

create function public.lector_generator_work_commit(p_user uuid,p_conversation uuid,p_revision integer,p_state jsonb,p_tickets jsonb,p_messages jsonb,p_turns jsonb,p_request uuid default null,p_usage jsonb default null) returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare c lector_generator_conversations; x jsonb; existing jsonb; result jsonb;
begin
 select * into c from lector_generator_conversations where id=p_conversation for update;
 if not found or c.user_id is distinct from p_user then raise exception 'Unauthorized'; end if;
 if c.mode<>'workshop' or c.expires_at<=now() then raise exception 'Session expired'; end if;
 if c.revision<>p_revision then raise exception 'Conversation changed'; end if;
 if p_state->>'storageVersion' is distinct from '2' or jsonb_typeof(p_tickets)<>'array' or jsonb_typeof(p_messages)<>'array' or jsonb_typeof(p_turns)<>'array' then raise exception 'Invalid work state'; end if;
 -- These are per-commit transport bounds, never a cumulative session quota.
 if octet_length(p_tickets::text)+octet_length(p_messages::text)+octet_length(p_turns::text)>16000000 then raise exception 'Work transfer too large'; end if;
 for x in select value from jsonb_array_elements(p_tickets) loop
  if jsonb_typeof(x->'picks')<>'array' or jsonb_array_length(x->'picks')=0 then raise exception 'Invalid ticket'; end if;
  if exists(select 1 from lector_generator_ticket_drafts where id=(x->>'id')::uuid and (user_id<>p_user or conversation_id<>p_conversation)) then raise exception 'Unauthorized ticket'; end if;
  select ticket into existing from lector_generator_ticket_drafts where id=(x->>'id')::uuid;
  if existing is not null and (existing->'picks' is distinct from x->'picks' or existing->'stake' is distinct from x->'stake') then raise exception 'Immutable ticket changed'; end if;
  insert into lector_generator_ticket_drafts(id,conversation_id,user_id,ticket) values((x->>'id')::uuid,p_conversation,p_user,x) on conflict(id) do nothing;
 end loop;
 for x in select value from jsonb_array_elements(p_messages) loop
  if x->>'role' not in ('user','assistant') or jsonb_typeof(x->'text')<>'string' then raise exception 'Invalid message'; end if;
  if exists(select 1 from lector_generator_messages where id=(x->>'id')::uuid and (user_id<>p_user or conversation_id<>p_conversation)) then raise exception 'Unauthorized message'; end if;
  insert into lector_generator_messages(id,conversation_id,user_id,body) values((x->>'id')::uuid,p_conversation,p_user,x) on conflict(id) do nothing;
 end loop;
 for x in select value from jsonb_array_elements(p_turns) loop
  if exists(select 1 from lector_generator_work_turns where id=(x->>'id')::uuid and (user_id<>p_user or conversation_id<>p_conversation)) then raise exception 'Unauthorized turn'; end if;
  insert into lector_generator_work_turns(id,conversation_id,user_id,body) values((x->>'id')::uuid,p_conversation,p_user,x) on conflict(id) do nothing;
 end loop;
 -- Preserve proposal audit snapshots before compact references reach old triggers.
 insert into lector_generator_proposal_audit(user_id,conversation_id,source_id,snapshot)
 select distinct on(p->>'id') p_user,p_conversation,p->>'id',p from (
  select p from jsonb_array_elements(p_tickets) t cross join lateral jsonb_array_elements(t->'picks') p
  union all select s->'candidate' from jsonb_array_elements(p_messages) m cross join lateral jsonb_array_elements(coalesce(m#>'{analysis,selections}','[]')) s
 ) candidates where p->>'id' is not null on conflict do nothing;
 -- Validate every reference, including versions, before the revision is advanced.
 if exists(select 1 from jsonb_array_elements(coalesce(p_state->'tickets','[]')||coalesce(p_state->'drafts','[]')||coalesce(p_state->'proposals','[]')||coalesce(nullif(p_state->'pending','null'),'[]')||
  coalesce((select jsonb_agg(r) from jsonb_array_elements(coalesce(p_state->'versions','[]')) v cross join lateral jsonb_array_elements(v) r),'[]')) r
  where not exists(select 1 from lector_generator_ticket_drafts d where d.id::text=r->>'id' and d.user_id=p_user and d.conversation_id=p_conversation)) then raise exception 'Unknown ticket reference'; end if;
 if exists(select 1 from jsonb_array_elements(p_state->'messages') r where not exists(select 1 from lector_generator_messages m where m.id::text=r->>'id' and m.user_id=p_user and m.conversation_id=p_conversation)) then raise exception 'Unknown message reference'; end if;
 result:=lector_generator_commit(p_user,p_conversation,p_revision,p_state,p_request,
  coalesce(p_usage,'{}')||jsonb_build_object('work_storage',jsonb_build_object('state_bytes',octet_length(p_state::text),'ticket_bytes',octet_length(p_tickets::text),'message_bytes',octet_length(p_messages::text),'version',2)));
 return result;
end $$;
revoke all on function public.lector_generator_work_read(uuid,uuid,boolean,jsonb),public.lector_generator_work_history(uuid,uuid,integer,integer,boolean),public.lector_generator_work_commit(uuid,uuid,integer,jsonb,jsonb,jsonb,jsonb,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.lector_generator_work_read(uuid,uuid,boolean,jsonb),public.lector_generator_work_history(uuid,uuid,integer,integer,boolean),public.lector_generator_work_commit(uuid,uuid,integer,jsonb,jsonb,jsonb,jsonb,uuid,jsonb) to service_role;
notify pgrst,'reload schema';

-- Keep explicit saved choices compatible with archived analyses.
create or replace function public.lector_generator_keep(p_user uuid,p_conversation uuid,p_kind text,p_source text,p_action text,p_supersedes uuid default null) returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare c lector_generator_conversations; item jsonb; snap jsonb; d lector_generator_decisions; changed boolean; session jsonb;
begin
 if p_kind not in ('ticket','selection') or p_action not in ('save','follow','relevant') or (p_kind='ticket' and p_action<>'save') then raise exception 'Invalid action'; end if;
 session:=lector_generator_session(p_user,p_conversation,false);
 if (session->>'expired')::boolean then raise exception 'Session expired'; end if;
 select * into c from lector_generator_conversations where id=p_conversation and user_id=p_user for update;
 if not found then raise exception 'Unauthorized'; end if;
 if c.state->>'storageVersion'='2' then c.state:=lector_generator_work_read(p_user,p_conversation,true); end if;
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
  if item is null then select p into item from lector_generator_messages m cross join lateral jsonb_array_elements(coalesce(m.body#>'{analysis,selections}','[]')) s cross join lateral (select s->'candidate' p) q where m.user_id=p_user and m.conversation_id=p_conversation and p->>'id'=p_source order by m.position desc limit 1; end if;
  if item is null then raise exception 'Unknown selection'; end if;
  snap:=jsonb_build_object('picks',jsonb_build_array(item),'context',c.state->'context');
 end if;
 -- Preserve the explanatory analysis as well as the exact quoted candidate.
 snap:=snap||jsonb_build_object('generationRevision',c.revision,'sourceConversationId',p_conversation,'retainedAt',now(),
 'analysis',coalesce((select m->'analysis' from jsonb_array_elements(coalesce(c.state->'messages','[]')) m where exists(select 1 from jsonb_array_elements(coalesce(m#>'{analysis,selections}','[]')) s where s#>>'{candidate,id}'=p_source) limit 1),(select body->'analysis' from lector_generator_messages m where user_id=p_user and conversation_id=p_conversation and exists(select 1 from jsonb_array_elements(coalesce(body#>'{analysis,selections}','[]')) s where s#>>'{candidate,id}'=p_source) order by position desc limit 1),'null'));
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
