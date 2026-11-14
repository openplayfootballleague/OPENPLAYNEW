-- Aggregate-only registration funnel reporting.
-- Team and membership conversion is cohort-based: records are grouped by creation
-- day and their current workflow state is reported separately. Pending records are
-- excluded from resolved conversion-rate denominators in the client.
-- Player registration status totals are global-admin/all-context only because a
-- player awaiting review has no competition membership from which to infer a scope.
create or replace function public.get_admin_registration_conversion(
  p_from_date date default null,
  p_to_date date default null,
  p_location_id uuid default null,
  p_league_id uuid default null,
  p_season_id uuid default null
) returns table(
  bucket_date date,
  player_registered bigint,
  player_pending_review bigint,
  player_rejected bigint,
  team_applications bigint,
  team_approved bigint,
  team_rejected bigint,
  team_pending bigint,
  membership_requests bigint,
  membership_accepted bigint,
  membership_rejected bigint,
  membership_pending bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_from date := coalesce(p_from_date, (pg_catalog.timezone('Europe/London', pg_catalog.now()))::date - 29);
  v_to date := coalesce(p_to_date, (pg_catalog.timezone('Europe/London', pg_catalog.now()))::date);
  v_location uuid := p_location_id;
  v_league uuid := p_league_id;
  v_season uuid := p_season_id;
  v_global_admin boolean := public.has_global_admin_role();
  v_global_player_view boolean;
begin
  if auth.uid() is null or not public.has_platform_role() then
    raise exception 'Administrator permission required';
  end if;
  if v_from > v_to then
    raise exception 'Registration report start date must be on or before its end date';
  end if;
  if v_to - v_from > 365 then
    raise exception 'Registration report date range cannot exceed 366 days';
  end if;

  if v_season is not null then
    select s.league_id into v_league from public.seasons s where s.id = v_season;
    if v_league is null then raise exception 'Selected season was not found'; end if;
    if p_league_id is not null and p_league_id <> v_league then
      raise exception 'Season does not belong to selected league';
    end if;
  end if;
  if v_league is not null then
    select l.location_id into v_location from public.leagues l where l.id = v_league;
    if v_location is null then raise exception 'Selected league was not found'; end if;
    if p_location_id is not null and p_location_id <> v_location then
      raise exception 'League does not belong to selected location';
    end if;
  end if;
  if v_location is not null and not exists (
    select 1 from public.locations l where l.id = v_location
  ) then raise exception 'Selected location was not found'; end if;
  if not v_global_admin and (
    v_location is null or not public.can_administer_location(v_location)
  ) then raise exception 'Assigned location administrator permission required'; end if;

  v_global_player_view := v_global_admin
    and v_location is null and v_league is null and v_season is null;

  return query
  with buckets as (
    select generated.day::date as day
    from pg_catalog.generate_series(v_from::timestamp, v_to::timestamp, interval '1 day') generated(day)
  ),
  player_cohorts as (
    select (p.created_at at time zone 'Europe/London')::date as day,
      count(*) filter (where p.registration_status = 'registered')::bigint as registered,
      count(*) filter (where p.registration_status = 'pending_review')::bigint as pending_review,
      count(*) filter (where p.registration_status = 'rejected')::bigint as rejected
    from public.players p
    where v_global_player_view
      and (p.created_at at time zone 'Europe/London')::date between v_from and v_to
    group by 1
  ),
  team_cohorts as (
    select (st.created_at at time zone 'Europe/London')::date as day,
      count(*)::bigint as applications,
      count(*) filter (where st.registration_status = 'approved')::bigint as approved,
      count(*) filter (where st.registration_status = 'rejected')::bigint as rejected,
      count(*) filter (where st.registration_status = 'pending')::bigint as pending
    from public.season_teams st
    join public.seasons s on s.id = st.season_id
    join public.leagues l on l.id = s.league_id
    where (st.created_at at time zone 'Europe/London')::date between v_from and v_to
      and (v_location is null or l.location_id = v_location)
      and (v_league is null or l.id = v_league)
      and (v_season is null or s.id = v_season)
    group by 1
  ),
  membership_cohorts as (
    select (tm.created_at at time zone 'Europe/London')::date as day,
      count(*)::bigint as requests,
      count(*) filter (where tm.status in ('active','left') and tm.joined_at is not null)::bigint as accepted,
      count(*) filter (where tm.status = 'rejected')::bigint as rejected,
      count(*) filter (where tm.status = 'pending')::bigint as pending
    from public.team_memberships tm
    join public.season_teams st on st.id = tm.season_team_id
    join public.seasons s on s.id = st.season_id
    join public.leagues l on l.id = s.league_id
    where (tm.created_at at time zone 'Europe/London')::date between v_from and v_to
      and (v_location is null or l.location_id = v_location)
      and (v_league is null or l.id = v_league)
      and (v_season is null or s.id = v_season)
    group by 1
  )
  select b.day,
    case when v_global_player_view then coalesce(pc.registered,0) else null end,
    case when v_global_player_view then coalesce(pc.pending_review,0) else null end,
    case when v_global_player_view then coalesce(pc.rejected,0) else null end,
    coalesce(tc.applications,0), coalesce(tc.approved,0), coalesce(tc.rejected,0), coalesce(tc.pending,0),
    coalesce(mc.requests,0), coalesce(mc.accepted,0), coalesce(mc.rejected,0), coalesce(mc.pending,0)
  from buckets b
  left join player_cohorts pc on pc.day = b.day
  left join team_cohorts tc on tc.day = b.day
  left join membership_cohorts mc on mc.day = b.day
  order by b.day;
end;
$$;

revoke all on function public.get_admin_registration_conversion(date,date,uuid,uuid,uuid) from public, anon;
grant execute on function public.get_admin_registration_conversion(date,date,uuid,uuid,uuid) to authenticated;
