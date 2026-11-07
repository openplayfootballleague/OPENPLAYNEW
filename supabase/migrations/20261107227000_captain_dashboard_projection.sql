-- A captain-only projection of their own team rosters and join requests.
-- No email, phone, date of birth or other private profile fields are returned.
create or replace function public.get_captain_dashboard()
returns table(
  season_team_id uuid,
  team_name text,
  membership_id uuid,
  player_name text,
  membership_status text,
  is_captain boolean,
  squad_number smallint,
  requested_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare v_user_id uuid := auth.uid();
begin
  if v_user_id is null then raise exception 'Authentication required'; end if;
  if not exists(select 1 from public.team_memberships tm
    where tm.user_id=v_user_id and tm.is_captain=true and tm.status='active') then
    raise exception 'Active captain permission required';
  end if;
  return query
  select tm.season_team_id,st.name,tm.id,p.full_name,tm.status::text,tm.is_captain,tm.squad_number,tm.created_at
  from public.team_memberships captain
  join public.team_memberships tm on tm.season_team_id=captain.season_team_id
  join public.season_teams st on st.id=tm.season_team_id
  join public.players p on p.user_id=tm.user_id
  where captain.user_id=v_user_id and captain.is_captain=true and captain.status='active'
    and tm.status in ('active','pending')
  order by st.name,case when tm.status='pending' then 0 else 1 end,p.full_name;
end;
$$;
revoke all on function public.get_captain_dashboard() from public,anon;
grant execute on function public.get_captain_dashboard() to authenticated;
