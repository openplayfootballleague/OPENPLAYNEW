-- Record the goalkeeper explicitly and require one of the selected starters.
alter table public.fixture_team_sheet_players
  add column is_goalkeeper boolean not null default false;

alter table public.fixture_team_sheet_players
  add constraint fixture_team_sheet_goalkeeper_must_start
  check (not is_goalkeeper or role = 'starter');

create unique index fixture_team_sheet_one_goalkeeper_idx
  on public.fixture_team_sheet_players(team_sheet_id)
  where is_goalkeeper;

-- Replace the four-argument RPC so callers cannot bypass goalkeeper selection.
drop function if exists public.submit_team_sheet(uuid, uuid, uuid[], uuid[]);

create function public.submit_team_sheet(
  p_fixture_id uuid,
  p_season_team_id uuid,
  p_starters uuid[],
  p_substitutes uuid[] default '{}'::uuid[],
  p_goalkeeper_membership_id uuid default null
)
returns public.fixture_team_sheets
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_fixture public.fixtures;
  v_format public.competition_format;
  v_sheet public.fixture_team_sheets;
  v_expected_starters integer;
  v_max_substitutes integer;
  v_all_memberships uuid[];
begin
  if v_actor is null then raise exception 'Authentication required'; end if;
  if not public.is_active_team_captain(p_season_team_id) then
    raise exception 'Active team captain permission required';
  end if;

  select * into v_fixture from public.fixtures where id = p_fixture_id for update;
  if not found then raise exception 'Fixture not found'; end if;
  if v_fixture.status <> 'scheduled' then raise exception 'Team sheets can only be submitted for scheduled fixtures'; end if;
  if p_season_team_id not in (v_fixture.home_team_id, v_fixture.away_team_id) then raise exception 'This team is not playing in the selected fixture'; end if;

  select l.format into v_format
  from public.seasons s join public.leagues l on l.id = s.league_id
  where s.id = v_fixture.season_id;
  v_expected_starters := case when v_format = 'six_a_side' then 6 else 7 end;
  v_max_substitutes := case when v_format = 'six_a_side' then 3 else 4 end;

  if coalesce(cardinality(p_starters), 0) <> v_expected_starters then raise exception 'Select exactly % starting players', v_expected_starters; end if;
  if coalesce(cardinality(p_substitutes), 0) > v_max_substitutes then raise exception 'Select no more than % substitutes', v_max_substitutes; end if;
  if p_goalkeeper_membership_id is null or not (p_goalkeeper_membership_id = any(coalesce(p_starters, '{}'::uuid[]))) then
    raise exception 'Select one goalkeeper from your starting players';
  end if;

  v_all_memberships := coalesce(p_starters, '{}'::uuid[]) || coalesce(p_substitutes, '{}'::uuid[]);
  if (select count(distinct x) from unnest(v_all_memberships) x) <> cardinality(v_all_memberships) then
    raise exception 'A player can only appear once on a team sheet';
  end if;

  if exists (
    select 1 from unnest(v_all_memberships) x
    where not exists (
      select 1 from public.team_memberships tm
      join public.players p on p.user_id = tm.user_id
      where tm.id = x and tm.season_team_id = p_season_team_id and tm.status = 'active'
        and p.registration_status = 'registered' and p.is_banned = false
    )
  ) then raise exception 'Every selected player must have an active, approved membership in this team'; end if;

  select * into v_sheet from public.fixture_team_sheets
  where fixture_id = p_fixture_id and season_team_id = p_season_team_id for update;

  if found and v_sheet.is_locked then raise exception 'This team sheet is locked'; end if;

  if v_sheet.id is null then
    insert into public.fixture_team_sheets(fixture_id, season_team_id, submitted_by, is_locked)
    values (p_fixture_id, p_season_team_id, v_actor, true) returning * into v_sheet;
  else
    update public.fixture_team_sheets
    set submitted_by = v_actor, submitted_at = now(), is_locked = true
    where id = v_sheet.id returning * into v_sheet;
    delete from public.fixture_team_sheet_players where team_sheet_id = v_sheet.id;
  end if;

  insert into public.fixture_team_sheet_players(team_sheet_id, user_id, role, squad_number_snapshot, is_goalkeeper)
  select v_sheet.id, tm.user_id, 'starter', tm.squad_number, tm.id = p_goalkeeper_membership_id
  from public.team_memberships tm
  where tm.id = any(coalesce(p_starters, '{}'::uuid[]))
    and tm.season_team_id = p_season_team_id and tm.status = 'active';

  insert into public.fixture_team_sheet_players(team_sheet_id, user_id, role, squad_number_snapshot, is_goalkeeper)
  select v_sheet.id, tm.user_id, 'substitute', tm.squad_number, false
  from public.team_memberships tm
  where tm.id = any(coalesce(p_substitutes, '{}'::uuid[]))
    and tm.season_team_id = p_season_team_id and tm.status = 'active';

  insert into public.audit_log(actor_user_id, action, entity_type, entity_id, after_data)
  values (v_actor, 'fixture.team_sheet.submitted', 'fixture_team_sheet', v_sheet.id::text,
    jsonb_build_object('fixture_id', p_fixture_id, 'season_team_id', p_season_team_id,
      'starters', cardinality(p_starters), 'substitutes', cardinality(p_substitutes),
      'goalkeeper_membership_id', p_goalkeeper_membership_id, 'is_locked', true));

  return v_sheet;
end;
$$;

revoke all on function public.submit_team_sheet(uuid, uuid, uuid[], uuid[], uuid) from public, anon;
grant execute on function public.submit_team_sheet(uuid, uuid, uuid[], uuid[], uuid) to authenticated;
