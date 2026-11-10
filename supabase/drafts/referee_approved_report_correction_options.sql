-- Admin correction UI reads approved report snapshots through a scoped, read-only RPC.
-- The write path remains admin_correct_approved_referee_match_report with optimistic versioning.
create or replace function public.admin_get_approved_referee_report_correction_options(
  p_report_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $admin_approved_report_correction_options$
declare
  v_report public.referee_match_reports;
  v_fixture public.fixtures;
  v_home_sheet public.fixture_team_sheets;
  v_away_sheet public.fixture_team_sheets;
  v_location_id uuid;
begin
  if auth.uid() is null or not public.has_platform_role() then
    raise exception 'Administrator permission required';
  end if;
  if p_report_id is null then raise exception 'An approved report is required'; end if;

  select * into v_report
  from public.referee_match_reports
  where id=p_report_id and status='approved';
  if not found then raise exception 'Approved referee report not found'; end if;

  select * into v_fixture from public.fixtures where id=v_report.fixture_id;
  if not found or v_fixture.status<>'completed' then
    raise exception 'Only completed fixtures with an approved report can be corrected';
  end if;
  if not exists(select 1 from public.fixture_results where fixture_id=v_fixture.id) then
    raise exception 'The published fixture result is missing; administrator review is required';
  end if;

  select coalesce(fixture.venue_id,league.location_id) into v_location_id
  from public.fixtures fixture
  join public.seasons season on season.id=fixture.season_id
  join public.leagues league on league.id=season.league_id
  where fixture.id=v_fixture.id;
  perform public.assert_admin_location_context(v_location_id);

  select * into v_home_sheet from public.fixture_team_sheets
  where fixture_id=v_fixture.id and season_team_id=v_fixture.home_team_id and is_locked=true;
  select * into v_away_sheet from public.fixture_team_sheets
  where fixture_id=v_fixture.id and season_team_id=v_fixture.away_team_id and is_locked=true;
  if v_home_sheet.id is null or v_away_sheet.id is null then
    raise exception 'Both locked team sheets are required to correct an approved report';
  end if;

  return jsonb_build_object(
    'fixture',jsonb_build_object(
      'id',v_fixture.id,'scheduled_at',v_fixture.scheduled_at,'gameweek',v_fixture.gameweek,
      'fixture_number',v_fixture.fixture_number,
      'home_team_id',v_fixture.home_team_id,
      'home_team_name',(select name from public.season_teams where id=v_fixture.home_team_id),
      'away_team_id',v_fixture.away_team_id,
      'away_team_name',(select name from public.season_teams where id=v_fixture.away_team_id)
    ),
    'report',jsonb_build_object(
      'id',v_report.id,'status',v_report.status,'version',v_report.version,
      'home_score',v_report.home_score,'away_score',v_report.away_score,
      'home_scorers',to_jsonb(v_report.home_scorers),'away_scorers',to_jsonb(v_report.away_scorers),
      'home_substitute_appearances',to_jsonb(v_report.home_substitute_appearances),
      'away_substitute_appearances',to_jsonb(v_report.away_substitute_appearances),
      'disciplinary_events',v_report.disciplinary_events,
      'match_write_up',v_report.match_write_up,'review_reason',v_report.review_reason,
      'approved_at',v_report.approved_at,'approved_by',v_report.approved_by
    ),
    'home_players',coalesce((
      select jsonb_agg(jsonb_build_object(
        'competition_player_id',tsp.competition_player_id,'full_name',player_identity.display_name,
        'role',tsp.role,'is_goalkeeper',tsp.is_goalkeeper,
        'disciplinary_inactive',coalesce(player.disciplinary_inactive,false)
      ) order by case when tsp.role='starter' then 0 else 1 end,player_identity.display_name)
      from public.fixture_team_sheet_players tsp
      join public.competition_player_identities player_identity on player_identity.id=tsp.competition_player_id
      left join public.players player on player.competition_player_id=tsp.competition_player_id
      where tsp.team_sheet_id=v_home_sheet.id and tsp.role in ('starter','substitute')
    ),'[]'::jsonb),
    'away_players',coalesce((
      select jsonb_agg(jsonb_build_object(
        'competition_player_id',tsp.competition_player_id,'full_name',player_identity.display_name,
        'role',tsp.role,'is_goalkeeper',tsp.is_goalkeeper,
        'disciplinary_inactive',coalesce(player.disciplinary_inactive,false)
      ) order by case when tsp.role='starter' then 0 else 1 end,player_identity.display_name)
      from public.fixture_team_sheet_players tsp
      join public.competition_player_identities player_identity on player_identity.id=tsp.competition_player_id
      left join public.players player on player.competition_player_id=tsp.competition_player_id
      where tsp.team_sheet_id=v_away_sheet.id and tsp.role in ('starter','substitute')
    ),'[]'::jsonb)
  );
end;
$admin_approved_report_correction_options$;
revoke all on function public.admin_get_approved_referee_report_correction_options(uuid) from public,anon;
grant execute on function public.admin_get_approved_referee_report_correction_options(uuid) to authenticated;
