-- Index only hockey player groups once per publication. Keep every Radar
-- criterion, the football path, immutable prematch checks and ACLs unchanged.
create or replace function public.form_radar_record_publication(p_sport text,p_source uuid,p_at timestamptz,p_body jsonb)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare f jsonb; players jsonb; profiles jsonb; kickoff timestamptz; fid text; home_id text; away_id text; v_provider text; hockey_players_by_scope jsonb;
begin
 if p_sport not in ('football','hockey') or p_at is null or p_at>now() then return; end if;
 if p_sport='hockey' then p_body:=p_body||'{}'::jsonb; end if;
 v_provider:=case when p_sport='football' then 'api-football' else 'api-hockey' end;
 players:=coalesce(case when p_sport='football' then p_body#>'{raw,player_form_radar}' else p_body#>'{playerRadar,profiles}' end,'[]');
 -- Index hockey profiles once. Each fixture uses exactly its two team,
 -- competition and season groups; preserve the original profile order.
 if p_sport='hockey' then
  select coalesce(jsonb_object_agg(scope_key,group_profiles),'{}'::jsonb)
  into hockey_players_by_scope
  from (
   select jsonb_build_array(p#>>'{team,id}',p->>'competitionId',p->>'season')::text scope_key,
    jsonb_agg(p order by n) group_profiles
   from jsonb_array_elements(players) with ordinality x(p,n)
   group by jsonb_build_array(p#>>'{team,id}',p->>'competitionId',p->>'season')::text
  ) groups;
 end if;
 for f in select value from jsonb_array_elements(coalesce(case when p_sport='football' then p_body#>'{raw,fixtures}' else p_body->'items' end,'[]')) loop
  kickoff:=(case when p_sport='football' then f#>>'{fixture,date}' else f->>'startsAt' end)::timestamptz;
  fid:=case when p_sport='football' then f#>>'{fixture,id}' else f->>'id' end;
  home_id:=case when p_sport='football' then f#>>'{teams,home,id}' else f#>>'{home,id}' end;
  away_id:=case when p_sport='football' then f#>>'{teams,away,id}' else f#>>'{away,id}' end;
  if kickoff is null or fid is null or kickoff<=now() or p_at>=kickoff
   or (case when p_sport='football' then f#>>'{fixture,status,short}' not in ('NS','TBD') else f->>'status'<>'scheduled' end)
  then continue; end if;
  if p_sport='hockey' then
   players:=coalesce(hockey_players_by_scope->jsonb_build_array(home_id,f->>'competitionId',f->>'season')::text,'[]'::jsonb)
    ||coalesce(hockey_players_by_scope->jsonb_build_array(away_id,f->>'competitionId',f->>'season')::text,'[]'::jsonb);
  end if;
  with candidates as (
   select p,(select max(coalesce(a->>'played_at',a->>'startsAt')::timestamptz)
    from jsonb_array_elements(coalesce(p->'activity','[]')) a) latest
   from jsonb_array_elements(players) p where p#>>'{team,id}' in(home_id,away_id)
    and (p_sport='football' or (p->>'competitionId'=f->>'competitionId' and p->>'season'=f->>'season'))
  ), current_profiles as (
   select distinct on(p#>>'{team,id}',coalesce(p#>>'{player,id}',p->>'id')) p,latest
   from candidates c where latest=(select max(c2.latest) from candidates c2 where c2.p#>>'{team,id}'=c.p#>>'{team,id}')
   order by p#>>'{team,id}',coalesce(p#>>'{player,id}',p->>'id'),latest desc,jsonb_array_length(p->'activity') desc
  ) select coalesce(jsonb_agg(p),'[]') into profiles from current_profiles
  where jsonb_array_length(p->'activity')>=3 and latest<p_at
   and not exists(select 1 from jsonb_array_elements(p->'activity') a where coalesce(a->>'played_at',a->>'startsAt')::timestamptz>=p_at or coalesce(a->>'fixture_id',a->>'id')=fid)
   and (select count(*)=3 and sum((a->>'goals')::int+(a->>'assists')::int)>=2
    from (select value a from jsonb_array_elements(p->'activity') with ordinality x(value,n) order by n desc limit 3) recent
    where a->>'goals' is not null and a->>'assists' is not null);
  insert into form_radar_match_snapshots(sport,provider,fixture_id,kickoff_at,captured_at,source_id,profiles)
  values(p_sport,v_provider,fid,kickoff,p_at,p_source,profiles)
  on conflict(sport,provider,fixture_id) do update set kickoff_at=excluded.kickoff_at,captured_at=excluded.captured_at,
   recorded_at=excluded.recorded_at,source_id=excluded.source_id,profiles=excluded.profiles
   where form_radar_match_snapshots.kickoff_at>now() and form_radar_match_snapshots.captured_at<=excluded.captured_at;
 end loop;
end $$;
notify pgrst, 'reload schema';
