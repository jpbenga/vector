-- Backend Lot 1A - Auth-facing product persistence.
--
-- Scope:
-- - user-owned application rows in public;
-- - remote persistence for compiled profiles, ticket strategies, favorites,
--   saved tickets and ticket selections;
-- - row level security based on auth.uid();
-- - no API-Football data, no snapshots, no sports ingestion in this lot.

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table public.user_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.user_profiles is
  'Application shadow profile for authenticated users. Auth remains owned by auth.users.';

create trigger set_user_profiles_updated_at
before update on public.user_profiles
for each row
execute function public.set_updated_at();

create table public.profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  is_active boolean not null default true,
  profile_schema_version integer not null default 2
    check (profile_schema_version >= 1),
  onboarding_version text not null,
  configuration_state text not null
    check (configuration_state in ('notStarted', 'inProgress', 'completed')),
  decision_profile jsonb,
  compiled_profile jsonb not null,
  compatibility jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.profiles is
  'CompiledDecisionProfile persistence. One active profile per user is expected.';

create unique index profiles_one_active_profile_per_user
  on public.profiles (user_id)
  where is_active;

create index profiles_user_id_idx
  on public.profiles (user_id);

create trigger set_profiles_updated_at
before update on public.profiles
for each row
execute function public.set_updated_at();

create table public.ticket_strategies (
  user_id uuid not null references auth.users(id) on delete cascade,
  id text not null,
  schema_version integer not null default 2
    check (schema_version >= 1),
  name text not null check (length(btrim(name)) > 0),
  is_active boolean not null default true,
  pick_types text[] not null default '{}'::text[]
    check (
      cardinality(pick_types) > 0
      and pick_types <@ array['prudent', 'normal', 'audacious']::text[]
    ),
  minimum_individual_odds numeric(8, 2) not null
    check (minimum_individual_odds >= 1.01),
  maximum_individual_odds numeric(8, 2)
    check (
      maximum_individual_odds is null
      or maximum_individual_odds >= minimum_individual_odds
    ),
  minimum_selections integer not null
    check (minimum_selections > 0),
  maximum_selections integer not null
    check (maximum_selections >= minimum_selections),
  minimum_total_odds numeric(12, 2) not null
    check (minimum_total_odds >= 1),
  maximum_total_odds numeric(12, 2)
    check (
      maximum_total_odds is null
      or maximum_total_odds >= minimum_total_odds
    ),
  priority integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, id)
);

comment on table public.ticket_strategies is
  'Persisted TicketStrategy objects. They are the only source of truth for automatic ticket generation.';

create index ticket_strategies_user_active_priority_idx
  on public.ticket_strategies (user_id, is_active, priority);

create trigger set_ticket_strategies_updated_at
before update on public.ticket_strategies
for each row
execute function public.set_updated_at();

create table public.match_favorites (
  user_id uuid not null references auth.users(id) on delete cascade,
  match_id text not null,
  created_at timestamptz not null default now(),
  primary key (user_id, match_id)
);

comment on table public.match_favorites is
  'User favorites for match identifiers. The current front contract stores a Set<String> of match ids.';

create table public.saved_tickets (
  user_id uuid not null references auth.users(id) on delete cascade,
  id text not null,
  schema_version integer not null default 1
    check (schema_version >= 1),
  source text not null
    check (source in ('copilot', 'copilotModified', 'manual')),
  status text not null
    check (status in ('saved', 'played', 'won', 'lost', 'cancelled')),
  name text,
  strategy_id text,
  strategy_name text,
  total_odds numeric(12, 2) not null
    check (total_odds >= 0),
  planned_stake numeric(12, 2)
    check (planned_stake is null or planned_stake >= 0),
  played_bookmaker text,
  played_stake numeric(12, 2)
    check (played_stake is null or played_stake >= 0),
  played_actual_total_odds numeric(12, 2)
    check (
      played_actual_total_odds is null
      or played_actual_total_odds >= 1
    ),
  played_at timestamptz,
  main_combined_reading_id text,
  main_combined_reading_label text,
  opportunity_ids text[] not null default '{}'::text[],
  modification_summary text,
  modification_details text[] not null default '{}'::text[],
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, id),
  check (
    (played_bookmaker is null and played_stake is null and
      played_actual_total_odds is null and played_at is null)
    or played_at is not null
  )
);

comment on table public.saved_tickets is
  'Saved tickets from Copilot, Copilot modified or manual flows.';

create index saved_tickets_user_created_at_idx
  on public.saved_tickets (user_id, created_at desc);

create index saved_tickets_user_source_status_idx
  on public.saved_tickets (user_id, source, status);

create trigger set_saved_tickets_updated_at
before update on public.saved_tickets
for each row
execute function public.set_updated_at();

create table public.saved_ticket_selections (
  user_id uuid not null references auth.users(id) on delete cascade,
  ticket_id text not null,
  id text not null,
  position integer not null
    check (position >= 0),
  match_id text not null,
  home_team text not null,
  away_team text not null,
  competition_name text not null,
  market_id text not null,
  market_label text not null,
  selection_id text not null,
  selection_label text not null,
  odds numeric(8, 2) not null
    check (odds >= 1.01),
  home_logo_url text,
  away_logo_url text,
  bookmaker_name text,
  opportunity_id text,
  created_at timestamptz not null default now(),
  primary key (user_id, ticket_id, id),
  foreign key (user_id, ticket_id)
    references public.saved_tickets (user_id, id)
    on delete cascade,
  unique (user_id, ticket_id, position),
  unique (user_id, ticket_id, match_id)
);

comment on table public.saved_ticket_selections is
  'Selections attached to a saved ticket. A ticket cannot contain the same match twice.';

create index saved_ticket_selections_ticket_idx
  on public.saved_ticket_selections (user_id, ticket_id, position);

alter table public.user_profiles enable row level security;
alter table public.profiles enable row level security;
alter table public.ticket_strategies enable row level security;
alter table public.match_favorites enable row level security;
alter table public.saved_tickets enable row level security;
alter table public.saved_ticket_selections enable row level security;

alter table public.user_profiles force row level security;
alter table public.profiles force row level security;
alter table public.ticket_strategies force row level security;
alter table public.match_favorites force row level security;
alter table public.saved_tickets force row level security;
alter table public.saved_ticket_selections force row level security;

create policy "Users can read their own app profile"
  on public.user_profiles
  for select
  using (id = auth.uid());

create policy "Users can insert their own app profile"
  on public.user_profiles
  for insert
  with check (id = auth.uid());

create policy "Users can update their own app profile"
  on public.user_profiles
  for update
  using (id = auth.uid())
  with check (id = auth.uid());

create policy "Users can delete their own app profile"
  on public.user_profiles
  for delete
  using (id = auth.uid());

create policy "Users can read their own decision profiles"
  on public.profiles
  for select
  using (user_id = auth.uid());

create policy "Users can insert their own decision profiles"
  on public.profiles
  for insert
  with check (user_id = auth.uid());

create policy "Users can update their own decision profiles"
  on public.profiles
  for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "Users can delete their own decision profiles"
  on public.profiles
  for delete
  using (user_id = auth.uid());

create policy "Users can read their own ticket strategies"
  on public.ticket_strategies
  for select
  using (user_id = auth.uid());

create policy "Users can insert their own ticket strategies"
  on public.ticket_strategies
  for insert
  with check (user_id = auth.uid());

create policy "Users can update their own ticket strategies"
  on public.ticket_strategies
  for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "Users can delete their own ticket strategies"
  on public.ticket_strategies
  for delete
  using (user_id = auth.uid());

create policy "Users can read their own match favorites"
  on public.match_favorites
  for select
  using (user_id = auth.uid());

create policy "Users can insert their own match favorites"
  on public.match_favorites
  for insert
  with check (user_id = auth.uid());

create policy "Users can delete their own match favorites"
  on public.match_favorites
  for delete
  using (user_id = auth.uid());

create policy "Users can read their own saved tickets"
  on public.saved_tickets
  for select
  using (user_id = auth.uid());

create policy "Users can insert their own saved tickets"
  on public.saved_tickets
  for insert
  with check (user_id = auth.uid());

create policy "Users can update their own saved tickets"
  on public.saved_tickets
  for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "Users can delete their own saved tickets"
  on public.saved_tickets
  for delete
  using (user_id = auth.uid());

create policy "Users can read their own saved ticket selections"
  on public.saved_ticket_selections
  for select
  using (user_id = auth.uid());

create policy "Users can insert their own saved ticket selections"
  on public.saved_ticket_selections
  for insert
  with check (user_id = auth.uid());

create policy "Users can update their own saved ticket selections"
  on public.saved_ticket_selections
  for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "Users can delete their own saved ticket selections"
  on public.saved_ticket_selections
  for delete
  using (user_id = auth.uid());
