-- Large, immutable league snapshots can take longer than the default
-- PostgREST service_role statement timeout when inserted as JSONB.
-- Keep the override bounded and limited to trusted server-side requests.

alter role service_role set statement_timeout = '30s';
notify pgrst, 'reload config';
