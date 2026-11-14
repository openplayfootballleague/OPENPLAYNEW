-- Fix: get_admin_contextual_fixtures always failed with
--   "structure of query does not match function result type"
-- because fixture_results.home_score/away_score are smallint while the function
-- declares integer result columns (PL/pgSQL RETURN QUERY does not coerce). It
-- failed on every call, even with no fixtures, so the Admin Dashboard and
-- Analytics fixture loads could not succeed.
--
-- Forward-only and non-destructive: the function is recreated from its
-- currently deployed definition (20261108010816) with only ::integer casts
-- added. Signature, SECURITY DEFINER, search_path and permission checks are
-- unchanged; grants are re-stated exactly as originally declared.
CREATE OR REPLACE FUNCTION public.get_admin_contextual_fixtures(p_location_id uuid DEFAULT NULL::uuid, p_league_id uuid DEFAULT NULL::uuid, p_season_id uuid DEFAULT NULL::uuid)
 RETURNS TABLE(id uuid, season_id uuid, season_name text, gameweek integer, fixture_number integer, home_team_id uuid, away_team_id uuid, home_team_name text, away_team_name text, venue_id uuid, venue_name text, scheduled_at timestamp with time zone, status text, home_score integer, away_score integer, notes text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_location uuid:=p_location_id;v_league uuid:=p_league_id;v_season uuid:=p_season_id;v_league_location uuid;v_season_league uuid;
begin
  if auth.uid() is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  if v_season is not null then
    select s.league_id into v_season_league from public.seasons s where s.id=v_season;
    if v_season_league is null then raise exception 'Selected season was not found'; end if;
    if v_league is not null and v_league<>v_season_league then raise exception 'Season does not belong to selected league'; end if;
    v_league:=v_season_league;
  end if;
  if v_league is not null then
    select l.location_id into v_league_location from public.leagues l where l.id=v_league;
    if v_league_location is null then raise exception 'Selected league was not found'; end if;
    if v_location is not null and v_location<>v_league_location then raise exception 'League does not belong to selected location'; end if;
    v_location:=v_league_location;
  end if;
  perform public.assert_admin_location_context(v_location);
  return query
  select f.id,f.season_id,se.name,f.gameweek,f.fixture_number,f.home_team_id,f.away_team_id,ht.name,at.name,
    f.venue_id,venue.name,f.scheduled_at,f.status::text,r.home_score::integer,r.away_score::integer,f.notes
  from public.fixtures f join public.seasons se on se.id=f.season_id join public.leagues l on l.id=se.league_id
  join public.season_teams ht on ht.id=f.home_team_id join public.season_teams at on at.id=f.away_team_id
  left join public.locations venue on venue.id=f.venue_id left join public.fixture_results r on r.fixture_id=f.id
  where (v_location is null or l.location_id=v_location) and (v_league is null or l.id=v_league) and (v_season is null or se.id=v_season)
  order by f.scheduled_at desc nulls last,f.gameweek desc,f.fixture_number;
end;
$function$

;
revoke all on function public.get_admin_contextual_fixtures(uuid,uuid,uuid) from public,anon;
grant execute on function public.get_admin_contextual_fixtures(uuid,uuid,uuid) to authenticated;
