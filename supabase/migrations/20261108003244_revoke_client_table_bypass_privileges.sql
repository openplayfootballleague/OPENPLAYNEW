-- Remove table-level capabilities that bypass row-level security or
-- permit clients to create triggers / declare references on application data.
-- Keep ordinary SELECT/INSERT/UPDATE/DELETE grants unchanged; RLS continues
-- to govern those row operations.
revoke truncate, references, trigger on all tables in schema public from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke truncate, references, trigger on tables from anon, authenticated;
