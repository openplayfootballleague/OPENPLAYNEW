-- Historical submitted selections are immutable records; current roster eligibility
-- must not erase former or anonymised players from the admin's submitted-sheet view.
do $historical_team_sheet_regression$
declare
  v_definition text := lower(pg_catalog.pg_get_functiondef(
    'public.get_admin_team_sheets_contextual(uuid,uuid,uuid)'::regprocedure
  ));
  v_players_query text;
  v_roster_query text;
  v_compact_players text;
  v_players_start integer;
  v_roster_start integer;
begin
  v_players_start := pg_catalog.strpos(v_definition, 'fixture_team_sheet_players tsp');
  v_roster_start := pg_catalog.strpos(v_definition, 'from public.team_memberships tm join public.players p');
  if v_players_start = 0 or v_roster_start = 0 or v_roster_start <= v_players_start then
    raise exception 'Could not locate submitted players and current roster queries';
  end if;
  v_players_query := pg_catalog.substr(v_definition, v_players_start, v_roster_start - v_players_start);
  v_roster_query := pg_catalog.substr(v_definition, v_roster_start);
  v_compact_players := pg_catalog.regexp_replace(v_players_query, E'\\s+', '', 'g');

  if pg_catalog.strpos(v_players_query, 'tm.status=''active''') > 0 then
    raise exception 'Historical submitted-sheet players must not be filtered by current membership status';
  end if;
  if pg_catalog.strpos(v_compact_players, 'tm.user_id=tsp.user_id') = 0
     or pg_catalog.strpos(v_compact_players, 'tm.season_team_id=sh.season_team_id') = 0
     or pg_catalog.strpos(v_compact_players, 'leftjoinpublic.team_membershipstm') = 0 then
    raise exception 'Historical membership identity must be optional, not a filter on submitted players';
  end if;
  if pg_catalog.strpos(v_compact_players, 'leftjoinpublic.competition_player_identitiescpi') = 0
     or pg_catalog.strpos(v_compact_players, 'cpi.id=tsp.competition_player_id') = 0
     or pg_catalog.strpos(v_players_query, 'cpi.display_name') = 0 then
    raise exception 'Historical display names must come from the permanent competition identity after erasure';
  end if;
  if pg_catalog.strpos(v_roster_query, 'tm.status=''active''') = 0
     or pg_catalog.strpos(v_roster_query, 'p.registration_status=''registered''') = 0
     or pg_catalog.strpos(v_roster_query, 'p.is_banned=false') = 0 then
    raise exception 'Current roster must remain limited to active, registered, non-banned players';
  end if;
  raise notice 'Historical team-sheet regression assertions passed';
end;
$historical_team_sheet_regression$;