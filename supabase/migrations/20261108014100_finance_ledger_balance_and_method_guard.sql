-- Additional finance-role scoped options for the manual ledger.
create or replace function public.get_finance_options()
returns table(season_id uuid,season_name text,team_id uuid,team_name text,league_name text,season_status text)
language plpgsql stable security definer set search_path=''
as $$
begin
if auth.uid() is null or not public.has_finance_access() then raise exception 'Finance permission required'; end if;
return query select se.id,se.name,st.id,st.name,l.name,se.status::text
from public.seasons se join public.leagues l on l.id=se.league_id join public.season_teams st on st.season_id=se.id
order by se.created_at desc,st.name;
end; $$;
revoke all on function public.get_finance_options() from public,anon;
grant execute on function public.get_finance_options() to authenticated;