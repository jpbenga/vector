-- Account-owned preparation references. No bets, odds snapshots or ticket cascade.
create table public.lector_shortlist_sessions (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 revision bigint not null default 0, status text not null default 'active' check(status in('active','extended','expired')),
 created_at timestamptz not null default now(), last_modified_at timestamptz not null default now(),
 expires_at timestamptz not null default now()+interval '24 hours', extension_until timestamptz,
 timezone text not null default 'Europe/Paris', undo_items jsonb, undo_revision bigint,
 check(expires_at >= created_at)
);
create unique index lector_shortlist_one_active on public.lector_shortlist_sessions(user_id) where status in('active','extended');
create index lector_shortlist_expiry on public.lector_shortlist_sessions(expires_at);
create table public.lector_shortlist_items (
 session_id uuid not null references public.lector_shortlist_sessions(id) on delete cascade,
 sport text not null check(sport in('football','hockey')), fixture_id text not null check(fixture_id ~ '^[0-9]{1,12}$'),
 fixture_date date not null, added_at timestamptz not null default now(),
 primary key(session_id,sport,fixture_id)
);
alter table public.lector_shortlist_sessions enable row level security;
alter table public.lector_shortlist_items enable row level security;
create policy shortlist_session_owner on public.lector_shortlist_sessions for select to authenticated using(user_id=auth.uid());
create policy shortlist_item_owner on public.lector_shortlist_items for select to authenticated using(exists(
 select 1 from public.lector_shortlist_sessions s where s.id=session_id and s.user_id=auth.uid()));
revoke all on public.lector_shortlist_sessions,public.lector_shortlist_items from anon,authenticated;
-- Writes are only the atomic user RPC below, never a client-side replacement list.
grant select on public.lector_shortlist_sessions,public.lector_shortlist_items to authenticated;
grant all on public.lector_shortlist_sessions,public.lector_shortlist_items to service_role;

create function public.lector_shortlist_fixture(p_sport text,p_fixture text,p_date date) returns jsonb
language plpgsql stable security definer set search_path=public,pg_temp as $$
declare f jsonb; body jsonb; captured timestamptz; live_status text;
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
  return jsonb_build_object('key',p_sport||':'||p_fixture,'sport',p_sport,'fixtureId',p_fixture,
   'matchId','api-fixture-'||p_fixture,'home',f#>>'{teams,home,name}','away',f#>>'{teams,away,name}',
   'homeLogo',f#>>'{teams,home,logo}','awayLogo',f#>>'{teams,away,logo}',
   'competition',f#>>'{league,name}','kickoff',f#>>'{fixture,date}','status',f#>>'{fixture,status,short}',
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
   'kickoff',f->>'startsAt','status',f->>'status','available',true,'capturedAt',captured);
 end if;
 return null;
end $$;

create function public.lector_shortlist_read(p_user uuid) returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
 select jsonb_build_object('serverNow',now(),'sessions',coalesce(jsonb_agg(
  jsonb_build_object('id',s.id,'revision',s.revision,'status',case when s.expires_at<=now() then 'expired' else s.status end,
   'createdAt',s.created_at,'lastModifiedAt',s.last_modified_at,'expiresAt',s.expires_at,
   'recoverableUntil',s.expires_at+interval '24 hours','timezone',s.timezone,
   'extensionOptions',coalesce((select jsonb_agg(jsonb_build_object('label',o.label,'until',o.until) order by o.until)
    from (values('Jusqu’à ce soir',((now() at time zone s.timezone)::date+time '23:59:59') at time zone s.timezone),
     ('Jusqu’à demain soir',((now() at time zone s.timezone)::date+1+time '23:59:59') at time zone s.timezone),
     ('Pendant 7 jours',now()+interval '7 days')) o(label,until) where o.until>s.expires_at),'[]'),
   'items',coalesce((select jsonb_agg(jsonb_build_object('key',i.sport||':'||i.fixture_id,
    'sport',i.sport,'fixtureId',i.fixture_id,'date',i.fixture_date,'addedAt',i.added_at,
    'fixture',public.lector_shortlist_fixture(i.sport,i.fixture_id,i.fixture_date)) order by i.added_at,i.sport,i.fixture_id)
    from public.lector_shortlist_items i where i.session_id=s.id),'[]'))
  order by (s.expires_at>now()) desc,s.last_modified_at desc),'[]'))
 from public.lector_shortlist_sessions s where s.user_id=p_user and s.expires_at+interval '24 hours'>now()
$$;

create function public.lector_shortlist(p_action text default 'read',p_session uuid default null,
 p_sport text default null,p_fixture text default null,p_date date default null,p_until timestamptz default null,
 p_timezone text default 'Europe/Paris',p_revision bigint default null)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare u uuid:=auth.uid(); s public.lector_shortlist_sessions; current_session public.lector_shortlist_sessions;
 touched bigint:=0; canonical jsonb; actual_date date; undo jsonb;
begin
 if u is null then raise exception 'Connectez-vous pour préparer votre Shortlist.' using errcode='42501'; end if;
 if p_action not in('read','add','remove','extend','clear','undo_clear','restore','merge','new') then raise exception 'Action Shortlist invalide'; end if;
 -- Every operation for the same owner is serialized, including concurrent creation.
 perform pg_advisory_xact_lock(hashtextextended('lector-shortlist:'||u::text,0));
 if p_action='read' then return public.lector_shortlist_read(u); end if;
 perform now() at time zone p_timezone;
 update public.lector_shortlist_sessions set status='expired' where user_id=u and status<>'expired' and expires_at<=now();
 if p_session is not null then
  select * into s from public.lector_shortlist_sessions where id=p_session and user_id=u for update;
  if s.id is null then raise exception 'Session Shortlist indisponible' using errcode='42501'; end if;
 end if;
 select * into current_session from public.lector_shortlist_sessions where user_id=u and status in('active','extended') for update;
 if p_action in('restore','merge') then
  if s.id is null or s.expires_at>now() or s.expires_at+interval '24 hours'<=now() then raise exception 'Cette session ne peut plus être restaurée'; end if;
  if current_session.id is not null and p_action<>'merge' then raise exception 'Une préparation est déjà active. Choisissez la fusion.'; end if;
  if current_session.id is null then
   update public.lector_shortlist_sessions set status='active',expires_at=now()+interval '24 hours',extension_until=null,
    revision=revision+1,last_modified_at=now(),undo_items=null,undo_revision=null where id=s.id;
  else
   if (select count(distinct (sport,fixture_id)) from public.lector_shortlist_items where session_id in(s.id,current_session.id))>200 then raise exception 'La fusion dépasserait les 200 rencontres de la Shortlist.'; end if;
   insert into public.lector_shortlist_items(session_id,sport,fixture_id,fixture_date,added_at)
    select current_session.id,sport,fixture_id,fixture_date,added_at from public.lector_shortlist_items where session_id=s.id on conflict do nothing;
   get diagnostics touched=row_count;
   if touched>0 then update public.lector_shortlist_sessions set revision=revision+1,last_modified_at=now(),
    expires_at=greatest(expires_at,now()+interval '24 hours'),undo_items=null,undo_revision=null where id=current_session.id; end if;
   delete from public.lector_shortlist_sessions where id=s.id;
  end if;
  return public.lector_shortlist_read(u);
 end if;
 if p_action in('add','new') and current_session.id is null then
  insert into public.lector_shortlist_sessions(user_id,timezone) values(u,p_timezone) returning * into current_session;
 end if;
 if p_action='new' then return public.lector_shortlist_read(u); end if;
 if s.id is null then s:=current_session; end if;
 if s.id is null or s.status='expired' or s.expires_at<=now() then raise exception 'La Shortlist a expiré. Restaurez-la ou commencez une nouvelle préparation.'; end if;
 if p_action='add' then
  if p_sport not in('football','hockey') or p_fixture is null or p_fixture !~ '^[0-9]{1,12}$' or p_date is null then raise exception 'Rencontre invalide'; end if;
  -- A duplicate is a true no-op and does not renew the preparation period.
  if exists(select 1 from public.lector_shortlist_items where session_id=s.id and sport=p_sport and fixture_id=p_fixture) then return public.lector_shortlist_read(u); end if;
  if (select count(*) from public.lector_shortlist_items where session_id=s.id)>=200 then raise exception 'La Shortlist contient déjà 200 rencontres.'; end if;
  canonical:=public.lector_shortlist_fixture(p_sport,p_fixture,p_date);
  if canonical is null then raise exception 'Cette rencontre n’est plus disponible dans les publications.'; end if;
  actual_date:=((canonical->>'kickoff')::timestamptz at time zone s.timezone)::date;
  insert into public.lector_shortlist_items(session_id,sport,fixture_id,fixture_date) values(s.id,p_sport,p_fixture,actual_date) on conflict do nothing;
  get diagnostics touched=row_count;
 elsif p_action='remove' then
  delete from public.lector_shortlist_items where session_id=s.id and sport=p_sport and fixture_id=p_fixture;
  get diagnostics touched=row_count;
 elsif p_action='clear' then
  select coalesce(jsonb_agg(to_jsonb(i)),'[]') into undo from public.lector_shortlist_items i where session_id=s.id;
  delete from public.lector_shortlist_items where session_id=s.id;
  get diagnostics touched=row_count;
  if touched>0 then update public.lector_shortlist_sessions set undo_items=undo,undo_revision=revision+1 where id=s.id; end if;
 elsif p_action='undo_clear' then
  if p_revision is null or s.undo_revision is distinct from p_revision or s.revision<>p_revision or s.undo_items is null then raise exception 'La liste a changé sur un autre appareil. Ce vidage ne peut plus être annulé.'; end if;
  insert into public.lector_shortlist_items(session_id,sport,fixture_id,fixture_date,added_at)
   select s.id,x.sport,x.fixture_id,x.fixture_date,x.added_at from jsonb_to_recordset(s.undo_items) x(sport text,fixture_id text,fixture_date date,added_at timestamptz);
  get diagnostics touched=row_count;
 elsif p_action='extend' then
  if p_until is null or p_until<=s.expires_at or p_until>now()+interval '7 days' then raise exception 'Choisissez une prolongation jusqu’à sept jours.'; end if;
  update public.lector_shortlist_sessions set status='extended',expires_at=p_until,extension_until=p_until,
   revision=revision+1,last_modified_at=now(),undo_items=null,undo_revision=null where id=s.id;
  return public.lector_shortlist_read(u);
 end if;
 if touched>0 then
  update public.lector_shortlist_sessions set revision=revision+1,last_modified_at=now(),
   expires_at=greatest(expires_at,now()+interval '24 hours'),
   undo_items=case when p_action='clear' then undo_items else null end,
   undo_revision=case when p_action='clear' then undo_revision else null end where id=s.id;
 end if;
 return public.lector_shortlist_read(u);
end $$;

create function public.lector_shortlist_cleanup() returns bigint language plpgsql security definer set search_path=public,pg_temp as $$
declare removed bigint;
begin
 delete from public.lector_shortlist_sessions where expires_at+interval '24 hours'<=now();
 get diagnostics removed=row_count; return removed;
end $$;
revoke all on function public.lector_shortlist_fixture(text,text,date),public.lector_shortlist_read(uuid),public.lector_shortlist_cleanup() from public,anon,authenticated;
grant execute on function public.lector_shortlist_read(uuid),public.lector_shortlist_cleanup() to service_role;
revoke all on function public.lector_shortlist(text,uuid,text,text,date,timestamptz,text,bigint) from public,anon;
grant execute on function public.lector_shortlist(text,uuid,text,text,date,timestamptz,text,bigint) to authenticated;
-- Expiration is checked on each read. Cleanup only purges the recovery window.
select cron.schedule('lector-shortlist-cleanup','17 * * * *','select public.lector_shortlist_cleanup()');
notify pgrst,'reload schema';
