-- Serialize a player's payment-record creation for a fixture. The unique
-- index remains the final integrity guard; this lock makes concurrent retries
-- return the existing row rather than racing into a uniqueness error.
create or replace function public.create_player_fixture_payment(
  p_fixture_id uuid,
  p_season_team_id uuid
)
returns table(payment_record_id uuid, amount_pence integer, currency text, already_paid boolean)
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_user uuid := auth.uid();
  v_fixture public.fixtures;
  v_team public.season_teams;
  v_fee integer;
  v_payment public.payment_records;
begin
  if v_user is null then raise exception 'Authentication required'; end if;

  select * into v_fixture
  from public.fixtures f
  where f.id = p_fixture_id
    and f.status in ('scheduled','in_progress')
  for share;
  if not found then raise exception 'Fixture is not available for payment'; end if;

  select * into v_team
  from public.season_teams st
  where st.id = p_season_team_id
    and st.season_id = v_fixture.season_id
    and p_season_team_id in (v_fixture.home_team_id, v_fixture.away_team_id);
  if not found then raise exception 'Team is not part of this fixture'; end if;

  if not exists (
    select 1 from public.team_memberships tm
    where tm.season_team_id = p_season_team_id
      and tm.user_id = v_user
      and tm.status = 'active'
  ) then raise exception 'Active team membership required'; end if;

  select sfc.player_fee_pence into v_fee
  from public.season_fee_configs sfc
  where sfc.season_id = v_fixture.season_id
    and sfc.player_fee_pence is not null
    and sfc.effective_from_gameweek <= v_fixture.gameweek
  order by sfc.effective_from_gameweek desc
  limit 1;

  if v_fee is null or v_fee <= 0 then
    raise exception 'Player match fee has not been configured for this fixture';
  end if;

  -- Hash collision only serializes unrelated requests; it cannot merge records.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_user::text || ':' || p_fixture_id::text, 0)
  );

  select * into v_payment
  from public.payment_records pr
  where pr.player_user_id = v_user
    and pr.fixture_id = p_fixture_id
  for update;

  if found then
    if v_payment.status = 'paid' then
      return query select v_payment.id, v_payment.amount_pence, v_payment.currency, true;
      return;
    end if;
    if v_payment.status in ('refunded','partially_refunded') then
      raise exception 'This fixture payment has already been refunded; contact Open Play';
    end if;
    if v_payment.amount_pence <> v_fee then
      raise exception 'The fixture fee has changed; contact Open Play before paying again';
    end if;
    return query select v_payment.id, v_payment.amount_pence, v_payment.currency, false;
    return;
  end if;

  insert into public.payment_records(
    season_team_id, fixture_id, player_user_id, amount_pence, currency,
    status, fee_snapshot
  ) values (
    p_season_team_id, p_fixture_id, v_user, v_fee, 'gbp',
    'pending',
    jsonb_build_object(
      'player_fee_pence', v_fee,
      'season_id', v_fixture.season_id,
      'gameweek', v_fixture.gameweek,
      'season_team_id', p_season_team_id,
      'captured_at', now()
    )
  ) returning * into v_payment;

  return query select v_payment.id, v_payment.amount_pence, v_payment.currency, false;
end;
$function$;
