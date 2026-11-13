-- Historical submitted selections are immutable records; current roster eligibility
-- must not erase former or anonymised players from the admin's submitted-sheet view.
do $historical_team_sheet_regression$
declare
  v_definition text := lower(pg_catalog.pg_get_functiondef(
    'public.get_admin_team_sheets_contextual(uuid,uuid,uuid)'::regprocedure
  ));
  v_players_query text;
  v_players_where text;
  v_roster_query text;
  v_compact_players text;
  v_players_start integer;
  v_players_where_start integer;
  v_roster_start integer;
begin
  v_players_start := pg_catalog.strpos(v_definition, 'fixture_team_sheet_players tsp');
  v_roster_start := pg_catalog.strpos(v_definition, 'from public.team_memberships tm join public.players p');
  if v_players_start = 0 or v_roster_start = 0 or v_roster_start <= v_players_start then
    raise exception 'Could not locate submitted players and current roster queries';
  end if;
  v_players_query := pg_catalog.substr(v_definition, v_players_start, v_roster_start - v_players_start);
  v_roster_query := pg_catalog.substr(v_definition, v_roster_start);
  -- Whitespace is removed everywhere, including inside string literals, so the
  -- 'Former player' fallback is matched as 'formerplayer' below.
  v_compact_players := pg_catalog.regexp_replace(v_players_query, '[[:space:]]+', '', 'g');
  v_players_where_start := pg_catalog.strpos(v_players_query, 'where tsp.team_sheet_id=sh.id');
  if v_players_where_start = 0 then
    raise exception 'Could not locate the submitted-player row filter';
  end if;
  v_players_where := pg_catalog.substr(v_players_query, v_players_where_start);

  if pg_catalog.strpos(v_compact_players, 'tm.user_id=tsp.user_id') = 0
     or pg_catalog.strpos(v_compact_players, 'tm.season_team_id=sh.season_team_id') = 0
     or pg_catalog.strpos(v_compact_players, 'leftjoinpublic.team_membershipstm') = 0
     or pg_catalog.strpos(v_compact_players, 'andtm.status=''active''') = 0 then
    raise exception 'Only an active membership may supply an amendment ID; the historical membership join must remain optional';
  end if;
  if v_players_where is null or pg_catalog.strpos(v_players_where, 'tm.status') > 0 then
    raise exception 'Historical submitted-player rows must not be filtered out by current membership status';
  end if;
  if pg_catalog.strpos(v_compact_players, 'leftjoinpublic.competition_player_identitiescpi') = 0
     or pg_catalog.strpos(v_compact_players, 'cpi.id=tsp.competition_player_id') = 0
     -- The display-name fallback is in the SELECT list, which precedes the FROM clause
     -- where v_players_query starts, so it is checked against the whole definition. It is
     -- anchored to player_name because the same expression also appears in ORDER BY.
     or pg_catalog.strpos(pg_catalog.regexp_replace(v_definition, '[[:space:]]+', '', 'g'),
          '''player_name'',coalesce(cpi.display_name,p.full_name,''formerplayer'')') = 0 then
    raise exception 'Historical identity assertion failed; compact submitted-player query: %', v_compact_players;
  end if;
  if pg_catalog.strpos(v_roster_query, 'tm.status=''active''') = 0
     or pg_catalog.strpos(v_roster_query, 'p.registration_status=''registered''') = 0
     or pg_catalog.strpos(v_roster_query, 'p.is_banned=false') = 0 then
    raise exception 'Current roster must remain limited to active, registered, non-banned players';
  end if;
  raise notice 'Historical team-sheet regression assertions passed';
end;
$historical_team_sheet_regression$;