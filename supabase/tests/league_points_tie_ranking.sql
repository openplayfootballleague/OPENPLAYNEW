-- Regression test: admin season statistics must use points-only shared positions.
do $$
declare
  v_definition text;
  v_positions integer[];
begin
  select pg_get_functiondef('public.get_admin_season_statistics(uuid)'::regprocedure) into v_definition;
  if position('rank() over(order by points desc)' in v_definition) = 0 then
    raise exception 'Admin season statistics must rank teams by points only using rank()';
  end if;
  if position('row_number() over(order by points desc,(goals_for-goals_against)' in v_definition) > 0 then
    raise exception 'Admin season statistics must not use goal difference as a tie-breaker';
  end if;
  with team_totals(team_id, points, goals_for, goals_against) as (
    values ('alpha', 12, 9, 1), ('bravo', 12, 1, 9), ('charlie', 9, 2, 2)
  ), ranked as (
    select team_id, rank() over(order by points desc)::integer as position from team_totals
  )
  select array_agg(position order by team_id) into v_positions from ranked;
  if v_positions <> array[1, 1, 3] then
    raise exception 'Expected tied positions 1,1 followed by 3; got %', v_positions;
  end if;
end;
$$;
