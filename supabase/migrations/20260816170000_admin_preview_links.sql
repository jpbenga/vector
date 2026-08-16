-- Temporary tester links for the admin cockpit.
--
-- Scope:
-- - store only hashed link tokens;
-- - allow service-role Edge Functions to create and redeem links;
-- - keep links private from anon/authenticated REST clients.

create table public.admin_preview_links (
  id uuid primary key default gen_random_uuid(),
  token_hash text not null unique,
  environment text not null default 'unknown',
  label text,
  created_by_user_id uuid,
  created_by_email text,
  expires_at timestamptz not null,
  revoked_at timestamptz,
  last_redeemed_at timestamptz,
  redeemed_count integer not null default 0 check (redeemed_count >= 0),
  created_at timestamptz not null default now(),
  check (expires_at > created_at)
);

comment on table public.admin_preview_links is
  'Hashed one-hour tester links generated from the admin cockpit.';

create index admin_preview_links_expires_at_idx
  on public.admin_preview_links (expires_at desc);

create index admin_preview_links_active_idx
  on public.admin_preview_links (expires_at desc)
  where revoked_at is null;

alter table public.admin_preview_links enable row level security;
alter table public.admin_preview_links force row level security;

revoke all on table public.admin_preview_links
  from anon, authenticated;

grant select, insert, update on public.admin_preview_links
  to service_role;
