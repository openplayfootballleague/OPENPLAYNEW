-- Fixture detail and match report (audit plan step 4; spec "fixture detail" and "match report").
-- Signed-in members only, following the Club Leaders and team-squad precedent: anon must never
-- execute a SECURITY DEFINER function. Visitors still see the fixture, score, venue and form from
-- the public tables through RLS; the named match events below need an account.
--
-- Scope: the fixture must belong to a public season of a published league at an active location,
-- and both teams must be approved. Events are returned only once the result is published
-- (fixture completed and result confirmed), matching the squad and statistics functions.
--
-- Returned per published fixture:
--   goals:   non-voided goal records, credited team side, scorer and assist display names,
--            own-goal flag. There is no match minute in the data model, so goals are ordered by
--            recording order and must not be presented as a timeline.
--   motm:    one Man of the Match nomination per team (current value after any correction).
--   lineups: players who appeared on each team's locked team sheet, role, goalkeeper flag and
--            the squad number snapshot taken when the sheet was submitted.
-- Only competition display names are exposed (anonymised identities already read
-- 'Former player'). No user ids, contact details, dates of birth or account state.

create or replace function public.get_public_fixture_match_report(p_fixture_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_fixture record;
  v_published boolean;
begin
  if auth.uid() is null then
    raise exception 'Sign in to view the match report' using errcode='42501';
  end if;
  if p_fixture_id is null then
    raise exception 'Published fixture not found' using errcode='P0002';
  end if;

  select f.id, f.home_team_id, f.away_team_id, f.status,
    r.confirmed_at is not null as has_confirmed_result
  into v_fixture
  from public.fixtures f
  join public.seasons s on s.id=f.season_id and s.is_public is true
  join public.leagues l on l.id=s.league_id and l.is_published is true
  join public.locations loc on loc.id=l.location_id and loc.is_active is true
  join public.season_teams home on home.id=f.home_team_id and home.registration_status='approved'
  join public.season_teams away on away.id=f.away_team_id and away.registration_status='approved'
  left join public.fixture_results r on r.fixture_id=f.id
  where f.id=p_fixture_id;

  if v_fixture.id is null then
    raise exception 'Published fixture not found' using errcode='P0002';
  end if;

  v_published := v_fixture.status='completed' and coalesce(v_fixture.has_confirmed_result,false);
  if not v_published then
    return jsonb_build_object('published',false,'goals','[]'::jsonb,'motm','[]'::jsonb,'lineups','[]'::jsonb);
  end if;

  return jsonb_build_object(
    'published', true,
    'goals', coalesce((
      select jsonb_agg(jsonb_build_object(
          'team_side', case when g.season_team_id=v_fixture.home_team_id then 'home' else 'away' end,
          'scorer_name', scorer.display_name,
          'assist_name', assist.display_name,
          'is_own_goal', g.is_own_goal
        ) order by g.created_at, g.id)
      from public.fixture_goal_records g
      join public.competition_player_identities scorer on scorer.id=g.competition_player_id
      left join public.competition_player_identities assist on assist.id=g.assist_competition_player_id
      where g.fixture_id=v_fixture.id and g.voided_at is null
        and g.season_team_id in (v_fixture.home_team_id,v_fixture.away_team_id)
    ),'[]'::jsonb),
    'motm', coalesce((
      select jsonb_agg(jsonb_build_object(
          'team_side', case when n.season_team_id=v_fixture.home_team_id then 'home' else 'away' end,
          'player_name', cpi.display_name
        ) order by case when n.season_team_id=v_fixture.home_team_id then 0 else 1 end)
      from public.fixture_motm_nominations n
      join public.competition_player_identities cpi on cpi.id=n.competition_player_id
      where n.fixture_id=v_fixture.id
        and n.season_team_id in (v_fixture.home_team_id,v_fixture.away_team_id)
    ),'[]'::jsonb),
    'lineups', coalesce((
      select jsonb_agg(jsonb_build_object(
          'team_side', case when sh.season_team_id=v_fixture.home_team_id then 'home' else 'away' end,
          'player_name', cpi.display_name,
          'role', tsp.role,
          'is_goalkeeper', tsp.is_goalkeeper,
          'squad_number', tsp.squad_number_snapshot
        ) order by case when sh.season_team_id=v_fixture.home_team_id then 0 else 1 end,
          case when tsp.role='starter' then 0 else 1 end,
          tsp.is_goalkeeper desc,
          tsp.squad_number_snapshot nulls last,
          cpi.display_name)
      from public.fixture_team_sheets sh
      join public.fixture_team_sheet_players tsp on tsp.team_sheet_id=sh.id and tsp.did_appear is true
      join public.competition_player_identities cpi on cpi.id=tsp.competition_player_id
      where sh.fixture_id=v_fixture.id and sh.is_locked is true
        and sh.season_team_id in (v_fixture.home_team_id,v_fixture.away_team_id)
    ),'[]'::jsonb)
  );
end;
$$;

comment on function public.get_public_fixture_match_report(uuid) is
  'Signed-in, published-scope match report: goals, Man of the Match and appearances for a fixture with a confirmed result. Display names only.';

revoke all on function public.get_public_fixture_match_report(uuid) from public,anon;
grant execute on function public.get_public_fixture_match_report(uuid) to authenticated;
