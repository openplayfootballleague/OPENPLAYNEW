-- One captain nomination per team/fixture, based only on a locked team sheet
-- and players with a confirmed actual appearance. Captains may nominate themselves.

create table public.fixture_motm_nominations (
  id uuid primary key default gen_random_uuid(),
  fixture_id uuid not null references public.fixtures(id) on delete cascade,
  season_team_id uuid not null references public.season_teams(id) on delete restrict,
  competition_player_id uuid not null references public.competition_player_identities(id) on delete restrict,
  nominated_by uuid not null references auth.users(id) on delete restrict,
  nominated_at timestamptz not null default now(),
  corrected_at timestamptz,
  corrected_by uuid references auth.users(id) on delete set null,
  correction_reason text,
  constraint fixture_motm_one_nomination_per_team unique(fixture_id,season_team_id),
  constraint fixture_motm_correction_pair check (
    (corrected_at is null) = (corrected_by is null)
  ),
  constraint fixture_motm_correction_reason check (
    corrected_at is null or (correction_reason is not null and length(btrim(correction_reason)) between 5 and 500)
  )
);

create index fixture_motm_nominations_identity_idx
  on public.fixture_motm_nominations(competition_player_id,fixture_id);
create index fixture_motm_nominations_fixture_idx
  on public.fixture_motm_nominations(fixture_id,season_team_id);

alter table public.fixture_motm_nominations enable row level security;
revoke all on public.fixture_motm_nominations from public,anon,authenticated;

create or replace function public.get_captain_motm_nomination_options()
returns table(
  fixture_id uuid,
  season_team_id uuid,
  team_name text,
  opponent_name text,
  gameweek integer,
  scheduled_at timestamptz,
  deadline_at timestamptz,
  nomination_id uuid,
  nominated_competition_player_id uuid,
  nominated_player_name text,
  can_nominate boolean,
  eligible_players jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;

  return query
  select
    f.id,
    st.id,
    st.name::text,
    opponent.name::text,
    f.gameweek,
    f.scheduled_at,
    f.scheduled_at + interval '24 hours',
    n.id,
    n.competition_player_id,
    nominated_identity.display_name,
    n.id is null and now() <= f.scheduled_at + interval '24 hours',
    coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'competition_player_id',eligible.id,
          'display_name',eligible.display_name
        ) order by eligible.display_name
      )
      from public.fixture_team_sheets sh
      join public.fixture_team_sheet_players tsp on tsp.team_sheet_id=sh.id
      join public.competition_player_identities eligible on eligible.id=tsp.competition_player_id
      where sh.fixture_id=f.id
        and sh.season_team_id=st.id
        and sh.is_locked
        and tsp.did_appear is true
        and eligible.counts_for_statistics is true
    ),'[]'::jsonb)
  from public.team_memberships tm
  join public.season_teams st on st.id=tm.season_team_id
  join public.fixtures f on st.id in (f.home_team_id,f.away_team_id)
  join public.season_teams opponent
    on opponent.id=case when f.home_team_id=st.id then f.away_team_id else f.home_team_id end
  join public.fixture_results fr on fr.fixture_id=f.id and fr.confirmed_at is not null
  left join public.fixture_motm_nominations n
    on n.fixture_id=f.id and n.season_team_id=st.id
  left join public.competition_player_identities nominated_identity
    on nominated_identity.id=n.competition_player_id
  where tm.user_id=auth.uid()
    and tm.status='active'
    and tm.is_captain is true
    and f.status='completed'
    and f.scheduled_at is not null
    and f.scheduled_at between now()-interval '24 hours' and now()
    and exists(
      select 1 from public.fixture_team_sheets sh
      where sh.fixture_id=f.id and sh.season_team_id=st.id and sh.is_locked
    )
  order by f.scheduled_at desc,f.gameweek desc;
end;
$$;
revoke all on function public.get_captain_motm_nomination_options() from public,anon;
grant execute on function public.get_captain_motm_nomination_options() to authenticated;

create or replace function public.submit_fixture_motm_nomination(
  p_fixture_id uuid,
  p_competition_player_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid:=auth.uid();
  v_fixture public.fixtures;
  v_team_count integer;
  v_team_id uuid;
  v_nomination_id uuid;
  v_location_id uuid;
  v_player_name text;
begin
  if v_actor is null then raise exception 'Authentication required'; end if;
  if p_fixture_id is null or p_competition_player_id is null then
    raise exception 'Choose a fixture and an eligible player';
  end if;

  select * into v_fixture
  from public.fixtures f
  where f.id=p_fixture_id
  for update;
  if not found then raise exception 'Fixture not found'; end if;
  if v_fixture.status<>'completed'
     or not exists(select 1 from public.fixture_results r where r.fixture_id=v_fixture.id and r.confirmed_at is not null) then
    raise exception 'A Man of the Match nomination is available only after the official result is published';
  end if;
  if v_fixture.scheduled_at is null
     or now()<v_fixture.scheduled_at
     or now()>v_fixture.scheduled_at+interval '24 hours' then
    raise exception 'Man of the Match nominations close 24 hours after the scheduled kick-off';
  end if;

  select count(distinct tm.season_team_id),
         (array_agg(distinct tm.season_team_id))[1]
  into v_team_count,v_team_id
  from public.team_memberships tm
  where tm.user_id=v_actor
    and tm.status='active'
    and tm.is_captain is true
    and tm.season_team_id in (v_fixture.home_team_id,v_fixture.away_team_id);
  if v_team_count<>1 or v_team_id is null then
    raise exception 'Only an active captain of a team in this fixture can nominate Man of the Match';
  end if;

  if exists(select 1 from public.fixture_motm_nominations n
    where n.fixture_id=v_fixture.id and n.season_team_id=v_team_id) then
    raise exception 'Your team has already submitted its Man of the Match nomination';
  end if;

  select cpi.display_name into v_player_name
  from public.fixture_team_sheets sh
  join public.fixture_team_sheet_players tsp on tsp.team_sheet_id=sh.id
  join public.competition_player_identities cpi on cpi.id=tsp.competition_player_id
  where sh.fixture_id=v_fixture.id
    and sh.season_team_id=v_team_id
    and sh.is_locked is true
    and tsp.did_appear is true
    and tsp.competition_player_id=p_competition_player_id
    and cpi.counts_for_statistics is true;
  if not found then
    raise exception 'Choose a player from your team’s locked sheet who actually appeared in this fixture';
  end if;

  select coalesce(f.venue_id,l.location_id) into v_location_id
  from public.fixtures f
  join public.seasons s on s.id=f.season_id
  join public.leagues l on l.id=s.league_id
  where f.id=v_fixture.id;

  begin
    insert into public.fixture_motm_nominations(
      fixture_id,season_team_id,competition_player_id,nominated_by
    ) values(v_fixture.id,v_team_id,p_competition_player_id,v_actor)
    returning id into v_nomination_id;
  exception when unique_violation then
    raise exception 'Your team has already submitted its Man of the Match nomination';
  end;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,after_data)
  values(v_actor,'fixture.motm.nominated','fixture_motm_nomination',v_nomination_id::text,
    'Captain nomination within the 24-hour match window',
    jsonb_build_object(
      'fixture_id',v_fixture.id,
      'season_team_id',v_team_id,
      'competition_player_id',p_competition_player_id,
      'player_name',v_player_name,
      'location_id',v_location_id
    ));
  return v_nomination_id;
end;
$$;
revoke all on function public.submit_fixture_motm_nomination(uuid,uuid) from public,anon;
grant execute on function public.submit_fixture_motm_nomination(uuid,uuid) to authenticated;

create or replace function public.admin_list_fixture_motm_nominations(p_location_id uuid default null)
returns table(
  nomination_id uuid,
  fixture_id uuid,
  season_team_id uuid,
  team_name text,
  opponent_name text,
  gameweek integer,
  scheduled_at timestamptz,
  location_id uuid,
  location_name text,
  competition_player_id uuid,
  nominated_player_name text,
  nominated_by uuid,
  nominated_at timestamptz,
  corrected_at timestamptz,
  correction_reason text,
  eligible_players jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not public.has_platform_role() then
    raise exception 'Administrator permission required';
  end if;
  perform public.assert_admin_location_context(p_location_id);

  return query
  select
    n.id,
    f.id,
    n.season_team_id,
    st.name::text,
    opponent.name::text,
    f.gameweek,
    f.scheduled_at,
    loc.id,
    loc.name::text,
    n.competition_player_id,
    cpi.display_name,
    n.nominated_by,
    n.nominated_at,
    n.corrected_at,
    n.correction_reason,
    coalesce((
      select jsonb_agg(jsonb_build_object(
        'competition_player_id',eligible.id,
        'display_name',eligible.display_name
      ) order by eligible.display_name)
      from public.fixture_team_sheets sh
      join public.fixture_team_sheet_players tsp on tsp.team_sheet_id=sh.id
      join public.competition_player_identities eligible on eligible.id=tsp.competition_player_id
      where sh.fixture_id=f.id
        and sh.season_team_id=n.season_team_id
        and sh.is_locked is true
        and tsp.did_appear is true
        and eligible.counts_for_statistics is true
    ),'[]'::jsonb)
  from public.fixture_motm_nominations n
  join public.fixtures f on f.id=n.fixture_id
  join public.season_teams st on st.id=n.season_team_id
  join public.season_teams opponent
    on opponent.id=case when f.home_team_id=st.id then f.away_team_id else f.home_team_id end
  join public.seasons s on s.id=f.season_id
  join public.leagues l on l.id=s.league_id
  join public.locations loc on loc.id=coalesce(f.venue_id,l.location_id)
  join public.competition_player_identities cpi on cpi.id=n.competition_player_id
  where (p_location_id is null or loc.id=p_location_id)
    and public.can_administer_location(loc.id)
  order by f.scheduled_at desc,n.nominated_at desc;
end;
$$;
revoke all on function public.admin_list_fixture_motm_nominations(uuid) from public,anon;
grant execute on function public.admin_list_fixture_motm_nominations(uuid) to authenticated;

create or replace function public.admin_correct_fixture_motm_nomination(
  p_nomination_id uuid,
  p_competition_player_id uuid,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid:=auth.uid();
  v_nomination public.fixture_motm_nominations;
  v_fixture public.fixtures;
  v_location_id uuid;
  v_old_name text;
  v_new_name text;
begin
  if v_actor is null or not public.has_platform_role() then
    raise exception 'Administrator permission required';
  end if;
  if length(btrim(coalesce(p_reason,''))) not between 5 and 500 then
    raise exception 'A correction reason of 5 to 500 characters is required';
  end if;
  if p_competition_player_id is null then raise exception 'Choose an eligible player'; end if;

  select * into v_nomination
  from public.fixture_motm_nominations n
  where n.id=p_nomination_id
  for update;
  if not found then raise exception 'Man of the Match nomination not found'; end if;

  select * into v_fixture from public.fixtures f where f.id=v_nomination.fixture_id;
  select coalesce(f.venue_id,l.location_id) into v_location_id
  from public.fixtures f
  join public.seasons s on s.id=f.season_id
  join public.leagues l on l.id=s.league_id
  where f.id=v_fixture.id;
  perform public.assert_admin_location_context(v_location_id);

  select cpi.display_name into v_new_name
  from public.fixture_team_sheets sh
  join public.fixture_team_sheet_players tsp on tsp.team_sheet_id=sh.id
  join public.competition_player_identities cpi on cpi.id=tsp.competition_player_id
  where sh.fixture_id=v_nomination.fixture_id
    and sh.season_team_id=v_nomination.season_team_id
    and sh.is_locked is true
    and tsp.did_appear is true
    and tsp.competition_player_id=p_competition_player_id
    and cpi.counts_for_statistics is true;
  if not found then
    raise exception 'Correction candidate must be an eligible actual appearance on the nominated team’s locked sheet';
  end if;

  select cpi.display_name into v_old_name
  from public.competition_player_identities cpi
  where cpi.id=v_nomination.competition_player_id;

  if v_nomination.competition_player_id=p_competition_player_id then
    raise exception 'Choose a different player to correct this nomination';
  end if;

  update public.fixture_motm_nominations
  set competition_player_id=p_competition_player_id,
      corrected_at=now(),
      corrected_by=v_actor,
      correction_reason=btrim(p_reason)
  where id=v_nomination.id;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,before_data,after_data)
  values(v_actor,'fixture.motm.corrected','fixture_motm_nomination',v_nomination.id::text,btrim(p_reason),
    jsonb_build_object('fixture_id',v_nomination.fixture_id,'season_team_id',v_nomination.season_team_id,
      'competition_player_id',v_nomination.competition_player_id,'player_name',v_old_name),
    jsonb_build_object('fixture_id',v_nomination.fixture_id,'season_team_id',v_nomination.season_team_id,
      'competition_player_id',p_competition_player_id,'player_name',v_new_name,
      'corrected_by',v_actor,'corrected_at',now()));
end;
$$;
revoke all on function public.admin_correct_fixture_motm_nomination(uuid,uuid,text) from public,anon;
grant execute on function public.admin_correct_fixture_motm_nomination(uuid,uuid,text) to authenticated;

create or replace function public.get_my_player_motm_awards(p_season_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid:=auth.uid();
  v_identity uuid;
  v_season_awards integer:=0;
  v_career_awards integer:=0;
  v_account_status text;
begin
  if v_actor is null then raise exception 'Authentication required'; end if;

  select p.competition_player_id into v_identity
  from public.players p
  where p.user_id=v_actor
    and p.registration_status='registered'
    and p.is_banned is false;
  if not found then raise exception 'An active registered player account is required'; end if;

  select pr.account_retention_status into v_account_status
  from public.profiles pr where pr.id=v_actor;
  if not found or v_account_status<>'active' then
    raise exception 'An active registered player account is required';
  end if;
  if not exists(select 1 from public.competition_player_identities cpi
    where cpi.id=v_identity and cpi.counts_for_statistics is true) then
    raise exception 'Player statistics are unavailable for this competition identity';
  end if;
  if p_season_id is not null and not exists(
    select 1 from public.seasons s join public.leagues l on l.id=s.league_id
    where s.id=p_season_id and s.is_public is true and l.is_published is true
  ) then raise exception 'Select a published season'; end if;

  select count(*)::integer into v_career_awards
  from public.fixture_motm_nominations n
  join public.fixtures f on f.id=n.fixture_id
  join public.competition_player_identities cpi on cpi.id=n.competition_player_id
  where n.competition_player_id=v_identity and f.status='completed'
    and cpi.counts_for_statistics is true;

  if p_season_id is not null then
    select count(*)::integer into v_season_awards
    from public.fixture_motm_nominations n
    join public.fixtures f on f.id=n.fixture_id
    join public.competition_player_identities cpi on cpi.id=n.competition_player_id
    where n.competition_player_id=v_identity and f.season_id=p_season_id
      and f.status='completed' and cpi.counts_for_statistics is true;
  end if;

  return jsonb_build_object(
    'season_awards',v_season_awards,
    'career_awards',v_career_awards
  );
end;
$$;
revoke all on function public.get_my_player_motm_awards(uuid) from public,anon;
grant execute on function public.get_my_player_motm_awards(uuid) to authenticated;

create or replace function public.get_public_season_club_leaders(p_season_id uuid)
returns table(
  competition_player_id uuid,
  player_name text,
  season_team_id uuid,
  team_name text,
  motm_awards bigint,
  appearances bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not exists(
    select 1 from public.seasons s
    join public.leagues l on l.id=s.league_id
    join public.locations loc on loc.id=l.location_id
    where s.id=p_season_id and s.is_public is true
      and l.is_published is true and loc.is_active is true
  ) then raise exception 'Published season not found'; end if;

  return query
  with appearances as (
    select tsp.competition_player_id,sh.season_team_id,
      count(distinct sh.fixture_id)::bigint as appearances
    from public.fixture_team_sheets sh
    join public.fixtures appeared_fixture
      on appeared_fixture.id=sh.fixture_id
      and appeared_fixture.season_id=p_season_id
      and appeared_fixture.status='completed'
    join public.fixture_team_sheet_players tsp
      on tsp.team_sheet_id=sh.id and tsp.did_appear is true
    where sh.is_locked is true
    group by tsp.competition_player_id,sh.season_team_id
  )
  select n.competition_player_id,cpi.display_name,n.season_team_id,st.name::text,
    count(*)::bigint,
    coalesce(max(a.appearances),0)::bigint
  from public.fixture_motm_nominations n
  join public.fixtures f on f.id=n.fixture_id and f.status='completed'
  join public.seasons s on s.id=f.season_id and s.is_public is true
  join public.leagues l on l.id=s.league_id and l.is_published is true
  join public.locations loc on loc.id=l.location_id and loc.is_active is true
  join public.season_teams st on st.id=n.season_team_id and st.registration_status='approved'
  join public.competition_player_identities cpi on cpi.id=n.competition_player_id
  left join appearances a
    on a.competition_player_id=n.competition_player_id
    and a.season_team_id=n.season_team_id
  where f.season_id=p_season_id and cpi.counts_for_statistics is true
  group by n.competition_player_id,cpi.display_name,n.season_team_id,st.name
  order by count(*) desc, cpi.display_name, st.name
  limit 20;
end;
$$;
revoke all on function public.get_public_season_club_leaders(uuid) from public,anon;
-- Signed-in members only. The platform invariant (security_definer_grants_regression.sql) forbids
-- anon-executable SECURITY DEFINER functions; visitor access needs a privacy-reviewed public
-- statistics design (tracked in docs/owner-decisions follow-ups), not a broader grant here.
grant execute on function public.get_public_season_club_leaders(uuid) to authenticated;
