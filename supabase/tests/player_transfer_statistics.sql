-- A player changing clubs keeps one season leaderboard identity, while
-- club-specific historical rows remain separately attributable.
do $$
declare
  v_leaderboard_definition text;
  v_club_breakdown_definition text;
  v_club_totals integer[];
  v_goal_totals integer[];
begin
  select pg_get_functiondef('public.get_admin_season_statistics(uuid)'::regprocedure)
    into v_leaderboard_definition;

  if position('group by cpi.id,cpi.display_name' in v_leaderboard_definition) = 0 then
    raise exception 'Season appearances must aggregate by permanent competition identity, not current club membership';
  end if;
  if position('group by g.competition_player_id' in v_leaderboard_definition) = 0 then
    raise exception 'Season goals must aggregate by permanent competition identity across clubs';
  end if;
  if position('order by coalesce(pg.goals,0) desc' in v_leaderboard_definition) = 0 then
    raise exception 'Player leaderboard must rank using the combined season goal total';
  end if;

  select pg_get_functiondef('public.get_admin_season_player_club_statistics(uuid)'::regprocedure)
    into v_club_breakdown_definition;
  if position('group by cpi.id, cpi.display_name, ts.season_team_id, st.name' in v_club_breakdown_definition) = 0 then
    raise exception 'Club appearance history must remain split by team';
  end if;
  if position('group by g.competition_player_id, cpi.display_name, g.season_team_id, st.name' in v_club_breakdown_definition) = 0 then
    raise exception 'Club goal history must remain split by team';
  end if;

  with club_rows(team_id, apps, starts, subs, goals) as (
    values ('club-a', 8, 6, 2, 5), ('club-b', 4, 3, 1, 3)
  )
  select
    array[sum(apps)::integer, sum(starts)::integer, sum(subs)::integer],
    array[sum(goals)::integer]
  into v_club_totals, v_goal_totals
  from club_rows;

  if v_club_totals <> array[12, 9, 3] or v_goal_totals <> array[8] then
    raise exception 'Cross-club season totals were not accumulated correctly';
  end if;

  if (select count(distinct team_id) from (values ('club-a'), ('club-b')) as clubs(team_id)) <> 2 then
    raise exception 'Historical club records must remain separate';
  end if;
end;
$$;
