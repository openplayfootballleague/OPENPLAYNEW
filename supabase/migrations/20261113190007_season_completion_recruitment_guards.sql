-- Forward-only guardrails for the approved season completion and manual recruitment lifecycle.
-- A postponed or otherwise unfinished fixture must prevent a season being
-- marked complete and must prevent the following season's recruitment opening.

create or replace function public.enforce_season_fixture_completion()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.status::text='active' and new.status::text='completed' then
    if not exists (
      select 1
      from public.fixtures f
      where f.season_id=old.id
    ) then
      raise exception 'A season cannot be completed before its fixtures have been created'
        using errcode='55000';
    end if;

    if exists (
      select 1
      from public.fixtures f
      left join public.fixture_results r on r.fixture_id=f.id
      where f.season_id=old.id
        and f.status::text<>'cancelled'
        -- Cancelled fixtures are final and never block; postponed ones must be replayed.
        and (f.status::text<>'completed' or r.fixture_id is null or r.confirmed_at is null)
    ) then
      raise exception 'A season cannot be completed while fixtures remain unfinished or unpublished'
        using errcode='55000';
    end if;
  end if;

  return new;
end;
$$;

revoke all on function public.enforce_season_fixture_completion() from public,anon,authenticated;

drop trigger if exists enforce_season_fixture_completion on public.seasons;
create trigger enforce_season_fixture_completion
before update of status on public.seasons
for each row
execute function public.enforce_season_fixture_completion();

create or replace function public.enforce_previous_season_fixtures_before_recruitment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_previous_season_id uuid;
begin
  if old.status::text<>'draft' or new.status::text<>'registration_open' then
    return new;
  end if;

  select previous.id
    into v_previous_season_id
  from public.seasons previous
  where previous.league_id=new.league_id
    and previous.id<>new.id
    and (
      (new.season_number is not null and previous.season_number is not null
        and previous.season_number<new.season_number)
      or
      (new.season_number is null and new.starts_on is not null
        and previous.starts_on is not null and previous.starts_on<new.starts_on)
    )
  order by
    case when new.season_number is not null and previous.season_number is not null then 0 else 1 end,
    previous.season_number desc nulls last,
    previous.starts_on desc nulls last,
    previous.created_at desc
  limit 1;

  if v_previous_season_id is null then
    return new;
  end if;

  if not exists (
    select 1 from public.fixtures f
    where f.season_id=v_previous_season_id
  ) then
    raise exception 'The previous season has no completed fixture record'
      using errcode='55000';
  end if;

  if exists (
    select 1
    from public.fixtures f
    left join public.fixture_results r on r.fixture_id=f.id
    where f.season_id=v_previous_season_id
      and f.status::text<>'cancelled'
        -- Cancelled fixtures are final and never block; postponed ones must be replayed.
        and (f.status::text<>'completed' or r.fixture_id is null or r.confirmed_at is null)
  ) then
    raise exception 'The previous season still has unfinished fixtures or unpublished results'
      using errcode='55000';
  end if;

  return new;
end;
$$;

revoke all on function public.enforce_previous_season_fixtures_before_recruitment() from public,anon,authenticated;

drop trigger if exists enforce_previous_season_fixtures_before_recruitment on public.seasons;
create trigger enforce_previous_season_fixtures_before_recruitment
before update of status on public.seasons
for each row
execute function public.enforce_previous_season_fixtures_before_recruitment();
