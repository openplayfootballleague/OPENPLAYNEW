-- Open Play player-to-fixture Stripe Checkout foundation.
-- Test-mode credentials are configured separately as Supabase Edge Function secrets.
-- Never place Stripe secrets in client code or migrations.

alter type public.payment_status add value if not exists 'partially_refunded';

alter table public.season_fee_configs
  add column if not exists player_fee_pence integer
  check (player_fee_pence is null or player_fee_pence between 1 and 100000000);

alter table public.payment_records
  add column if not exists player_user_id uuid references auth.users(id) on delete restrict,
  add column if not exists stripe_customer_id text,
  add column if not exists amount_refunded_pence integer not null default 0
    check (amount_refunded_pence >= 0 and amount_refunded_pence <= amount_pence),
  add column if not exists stripe_fee_pence integer
    check (stripe_fee_pence is null or stripe_fee_pence >= 0),
  add column if not exists net_amount_pence integer
    check (net_amount_pence is null or net_amount_pence >= 0),
  add column if not exists last_stripe_event_at timestamptz;

create unique index if not exists payment_records_player_fixture_unique
  on public.payment_records(player_user_id, fixture_id)
  where player_user_id is not null and fixture_id is not null;

create table if not exists public.stripe_webhook_events (
  id text primary key,
  event_type text not null,
  payment_record_id uuid references public.payment_records(id) on delete set null,
  livemode boolean not null default false check (livemode = false),
  processed_at timestamptz,
  processing_error text,
  created_at timestamptz not null default now()
);
alter table public.stripe_webhook_events enable row level security;
revoke all on public.stripe_webhook_events from anon, authenticated;
create policy stripe_webhook_events_deny_client_access
  on public.stripe_webhook_events for all to anon, authenticated
  using (false) with check (false);

-- A player can only request payment for a fixture involving their own active team.
-- The amount is read from the server-side season fee snapshot, never from the browser.
create or replace function public.create_player_fixture_payment(p_fixture_id uuid, p_season_team_id uuid)
returns table(payment_record_id uuid, amount_pence integer, currency text, already_paid boolean)
language plpgsql
security definer
set search_path = ''
as $$
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
$$;

revoke all on function public.create_player_fixture_payment(uuid,uuid) from public, anon;
grant execute on function public.create_player_fixture_payment(uuid,uuid) to authenticated;

-- Only service-role webhook processing may update Stripe-backed payment state.
revoke all on public.payment_records from anon, authenticated;
