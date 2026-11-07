create or replace function public.get_my_transfer_destinations()
returns table(
  source_membership_id uuid,source_team_id uuid,source_team_name text,
  season_id uuid,season_name text,league_name text,
  destination_team_id uuid,destination_team_name text
)
language plpgsql stable security definer set search_path = '' as $$
declare v_user uuid:=auth.uid();
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if not exists(select 1 from public.players p where p.user_id=v_user and p.registration_status='registered' and p.is_banned=false) then
    return;
  end if;
  return query
  select tm.id,st.id,st.name,se.id,se.name,l.name,dest.id,dest.name
  from public.team_memberships tm
  join public.season_teams st on st.id=tm.season_team_id
  join public.seasons se on se.id=st.season_id
  join public.leagues l on l.id=se.league_id
  join public.season_teams dest on dest.season_id=se.id
    and dest.id<>st.id and dest.registration_status='approved'
  where tm.user_id=v_user and tm.status='active' and tm.is_captain=false
    and se.status in ('registration_open','active')
    and not exists(
      select 1 from public.team_memberships existing
      where existing.user_id=v_user and existing.season_team_id=dest.id
        and existing.status in ('active','pending')
    )
  order by se.name,st.name,dest.name;
end;
$$;
