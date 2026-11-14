-- Permission-scoped, aggregate-only user growth reporting for Analytics & Reports.
-- Account signups are intentionally global-admin-only and disappear for scoped views.
create or replace function public.get_admin_user_growth(
  p_from_date date default null,
  p_to_date date default null,
  p_location_id uuid default null,
  p_league_id uuid default null,
  p_season_id uuid default null
) returns table(
  bucket_date date,
  account_signups bigint,
  player_registrations bigint,
  team_applications bigint,
  team_approvals bigint
)
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_from date := coalesce(p_from_date, (pg_catalog.timezone('Europe/London', pg_catalog.now()))::date - 29);
  v_to date := coalesce(p_to_date, (pg_catalog.timezone('Europe/London', pg_catalog.now()))::date);
  v_location uuid := p_location_id;
  v_league uuid := p_league_id;
  v_season uuid := p_season_id;
  v_global_admin boolean := public.has_global_admin_role();
begin
  if auth.uid() is null or not public.has_platform_role() then
    raise exception 'Administrator permission required';
  end if;

  if v_from > v_to then
    raise exception 'Growth report start date must be on or before its end date';
  end if;
  if v_to - v_from > 365 then
    raise exception 'Growth report date range cannot exceed 366 days';
  end if;

  if v_season is not null then
    select s.league_id into v_league
    from public.seasons s
    where s.id = v_season;
    if v_league is null then raise exception 'Selected season was not found'; end if;
    if p_league_id is not null and p_league_id <> v_league then
      raise exception 'Season does not belong to selected league';
    end if;
  end if;

  if v_league is not null then
    select l.location_id into v_location
    from public.leagues l
    where l.id = v_league;
    if v_location is null then raise exception 'Selected league was not found'; end if;
    if p_location_id is not null and p_location_id <> v_location then
      raise exception 'League does not belong to selected location';
    end if;
  end if;

  if v_location is not null and not exists (
    select 1 from public.locations l where l.id = v_location
  ) then
    raise exception 'Selected location was not found';
  end if;

  if not v_global_admin and (
    v_location is null or not public.can_administer_location(v_location)
  ) then
    raise exception 'Assigned location administrator permission required';
  end if;

  return query
  with buckets as (
    select generated.day::date as day
    from pg_catalog.generate_series(v_from::timestamp, v_to::timestamp, interval '1 day') generated(day)
  ),
  account_counts as (
    select (p.created_at at time zone 'Europe/London')::date as day, count(*)::bigint as total
    from public.profiles p
    where v_global_admin
      and v_location is null and v_league is null and v_season is null
      and (p.created_at at time zone 'Europe/London')::date between v_from and v_to
    group by 1
  ),
  player_counts as (
    select (p.created_at at time zone 'Europe/London')::date as day, count(distinct p.id)::bigint as total
    from public.players p
    where (p.created_at at time zone 'Europe/London')::date between v_from and v_to
      and (
        (v_location is null and v_league is null and v_season is null)
        or exists (
          select 1
          from public.team_memberships tm
          join public.season_teams st on st.id = tm.season_team_id
          join public.seasons s on s.id = st.season_id
          join public.leagues l on l.id = s.league_id
          where tm.user_id = p.user_id
            and (v_location is null or l.location_id = v_location)
            and (v_league is null or l.id = v_league)
            and (v_season is null or s.id = v_season)
        )
      )
    group by 1
  ),
  team_application_counts as (
    select (st.created_at at time zone 'Europe/London')::date as day, count(*)::bigint as total
    from public.season_teams st
    join public.seasons s on s.id = st.season_id
    join public.leagues l on l.id = s.league_id
    where (st.created_at at time zone 'Europe/London')::date between v_from and v_to
      and (v_location is null or l.location_id = v_location)
      and (v_league is null or l.id = v_league)
      and (v_season is null or s.id = v_season)
    group by 1
  ),
  team_approval_counts as (
    select (st.approved_at at time zone 'Europe/London')::date as day, count(*)::bigint as total
    from public.season_teams st
    join public.seasons s on s.id = st.season_id
    join public.leagues l on l.id = s.league_id
    where st.registration_status = 'approved'
      and st.approved_at is not null
      and (st.approved_at at time zone 'Europe/London')::date between v_from and v_to
      and (v_location is null or l.location_id = v_location)
      and (v_league is null or l.id = v_league)
      and (v_season is null or s.id = v_season)
    group by 1
  )
  select
    b.day,
    case
      when v_global_admin and v_location is null and v_league is null and v_season is null
      then coalesce(a.total, 0)
      else null
    end,
    coalesce(p.total, 0),
    coalesce(ta.total, 0),
    coalesce(tap.total, 0)
  from buckets b
  left join account_counts a on a.day = b.day
  left join player_counts p on p.day = b.day
  left join team_application_counts ta on ta.day = b.day
  left join team_approval_counts tap on tap.day = b.day
  order by b.day;
end;
$$;

revoke all on function public.get_admin_user_growth(date,date,uuid,uuid,uuid) from public, anon;
grant execute on function public.get_admin_user_growth(date,date,uuid,uuid,uuid) to authenticated;
