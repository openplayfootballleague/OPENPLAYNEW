create or replace function public.get_admin_team_sheets()
returns table(team_sheet_id uuid,fixture_id uuid,season_team_id uuid,team_name text,opponent_name text,gameweek integer,scheduled_at timestamptz,competition_format public.competition_format,is_locked boolean,submitted_at timestamptz,players jsonb,roster jsonb)
language plpgsql stable security definer set search_path = '' as $$
begin
if auth.uid() is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
return query
select s.id,s.fixture_id,s.season_team_id,st.name,opponent.name,f.gameweek,f.scheduled_at,l.format,s.is_locked,s.submitted_at,
coalesce((select jsonb_agg(jsonb_build_object('membership_id',tm.id,'player_name',p.full_name,'role',tsp.role,'is_goalkeeper',tsp.is_goalkeeper,'squad_number_snapshot',tsp.squad_number_snapshot) order by case when tsp.role='starter' then 0 else 1 end,p.full_name) from public.fixture_team_sheet_players tsp join public.team_memberships tm on tm.user_id=tsp.user_id and tm.season_team_id=s.season_team_id and tm.status='active' join public.players p on p.user_id=tsp.user_id where tsp.team_sheet_id=s.id),'[]'::jsonb),
coalesce((select jsonb_agg(jsonb_build_object('membership_id',tm.id,'player_name',p.full_name,'squad_number',tm.squad_number) order by p.full_name) from public.team_memberships tm join public.players p on p.user_id=tm.user_id where tm.season_team_id=s.season_team_id and tm.status='active' and p.registration_status='registered' and p.is_banned=false),'[]'::jsonb)
from public.fixture_team_sheets s join public.fixtures f on f.id=s.fixture_id join public.seasons se on se.id=f.season_id join public.leagues l on l.id=se.league_id join public.season_teams st on st.id=s.season_team_id join public.season_teams opponent on opponent.id=case when f.home_team_id=s.season_team_id then f.away_team_id else f.home_team_id end
order by f.scheduled_at desc nulls last,f.gameweek desc,st.name;
end; $$;
revoke all on function public.get_admin_team_sheets() from public,anon;
grant execute on function public.get_admin_team_sheets() to authenticated;