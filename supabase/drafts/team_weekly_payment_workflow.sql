-- Team-level weekly fixture payments. This is separate from player fixture checkout.
-- All amounts/deadlines are immutable snapshots; provider callbacks are service-role only.

create table public.team_fixture_payment_obligations (
  id uuid primary key default gen_random_uuid(),
  fixture_id uuid not null references public.fixtures(id) on delete restrict,
  season_team_id uuid not null references public.season_teams(id) on delete restrict,
  amount_pence integer not null check (amount_pence between 1 and 100000000),
  currency text not null default 'gbp' check (currency = lower(currency) and char_length(currency)=3),
  scheduled_at_snapshot timestamptz not null,
  deadline_at timestamptz not null,
  grace_ends_at timestamptz not null,
  status text not null default 'due' check (status in (
    'due','grace_period','paid','late_paid','defaulted','paid_after_cancellation',
    'refund_pending','refunded','refund_failed','admin_review'
  )),
  stripe_checkout_session_id text unique,
  stripe_payment_intent_id text unique,
  paid_at timestamptz,
  finance_charge_entry_id uuid references public.finance_entries(id) on delete restrict,
  finance_payment_entry_id uuid references public.finance_entries(id) on delete restrict,
  created_by uuid not null references auth.users(id) on delete restrict,
  defaulted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(fixture_id,season_team_id),
  constraint team_fixture_payment_deadlines_valid check (
    deadline_at = scheduled_at_snapshot - interval '24 hours'
    and grace_ends_at = scheduled_at_snapshot - interval '12 hours'
    and grace_ends_at > deadline_at
  ),
  constraint team_fixture_payment_paid_state check (
    (status in ('paid','late_paid','paid_after_cancellation','refund_pending','refunded','refund_failed')
      and paid_at is not null and stripe_payment_intent_id is not null)
    or status in ('due','grace_period','defaulted','admin_review')
  )
);
create index team_fixture_payment_due_idx
  on public.team_fixture_payment_obligations(status,grace_ends_at)
  where status in ('due','grace_period');
create index team_fixture_payment_team_idx
  on public.team_fixture_payment_obligations(season_team_id,created_at desc);

create table public.team_payment_strikes (
  id uuid primary key default gen_random_uuid(),
  obligation_id uuid not null unique references public.team_fixture_payment_obligations(id) on delete restrict,
  fixture_id uuid not null references public.fixtures(id) on delete restrict,
  season_team_id uuid not null references public.season_teams(id) on delete restrict,
  original_deadline_at timestamptz not null,
  paid_at timestamptz,
  reason text not null check (reason in ('paid_during_grace','unpaid_at_grace_end','paid_after_cancellation')),
  created_at timestamptz not null default now()
);
create index team_payment_strikes_team_idx
  on public.team_payment_strikes(season_team_id,created_at desc);

create table public.team_fixture_payment_refunds (
  id uuid primary key default gen_random_uuid(),
  obligation_id uuid not null unique references public.team_fixture_payment_obligations(id) on delete restrict,
  amount_pence integer not null check (amount_pence > 0),
  stripe_payment_intent_id text not null,
  status text not null default 'pending' check (status in ('pending','processing','refunded','failed')),
  stripe_refund_id text unique,
  failure_reason text,
  refund_finance_entry_id uuid references public.finance_entries(id) on delete restrict,
  credit_finance_entry_id uuid references public.finance_entries(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.team_fixture_payment_history (
  id uuid primary key default gen_random_uuid(),
  obligation_id uuid not null references public.team_fixture_payment_obligations(id) on delete restrict,
  action text not null,
  from_status text,
  to_status text,
  actor_user_id uuid references auth.users(id) on delete set null,
  reason text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index team_fixture_payment_history_obligation_idx
  on public.team_fixture_payment_history(obligation_id,created_at desc);

alter table public.team_fixture_payment_obligations enable row level security;
alter table public.team_payment_strikes enable row level security;
alter table public.team_fixture_payment_refunds enable row level security;
alter table public.team_fixture_payment_history enable row level security;
revoke all on public.team_fixture_payment_obligations,public.team_payment_strikes,
  public.team_fixture_payment_refunds,public.team_fixture_payment_history
  from public,anon,authenticated;

create or replace function public.create_team_fixture_payment_obligation(
  p_fixture_id uuid,
  p_season_team_id uuid
)
returns table(obligation_id uuid,amount_pence integer,deadline_at timestamptz,grace_ends_at timestamptz,status text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid:=auth.uid();
  v_fixture public.fixtures;
  v_fee integer;
  v_obligation public.team_fixture_payment_obligations;
  v_charge public.finance_entries;
begin
  if v_actor is null then raise exception 'Authentication required'; end if;
  if not public.is_active_team_captain(p_season_team_id) then
    raise exception 'Active team captain permission required';
  end if;

  select * into v_fixture from public.fixtures
  where id=p_fixture_id for update;
  if not found or v_fixture.status<>'scheduled' or v_fixture.scheduled_at is null
     or v_fixture.scheduled_at<=now() then
    raise exception 'Only future scheduled fixtures can receive a team payment request';
  end if;
  if p_season_team_id not in (v_fixture.home_team_id,v_fixture.away_team_id) then
    raise exception 'Team is not part of this fixture';
  end if;

  select team_fee_pence into v_fee
  from public.season_fee_configs
  where season_id=v_fixture.season_id and team_fee_pence>0
    and effective_from_gameweek<=v_fixture.gameweek
  order by effective_from_gameweek desc limit 1;
  if v_fee is null then raise exception 'Weekly team fee has not been configured for this fixture'; end if;

  insert into public.team_fixture_payment_obligations(
    fixture_id,season_team_id,amount_pence,scheduled_at_snapshot,deadline_at,grace_ends_at,created_by
  ) values(
    p_fixture_id,p_season_team_id,v_fee,v_fixture.scheduled_at,
    v_fixture.scheduled_at-interval '24 hours',
    v_fixture.scheduled_at-interval '12 hours',v_actor
  )
  on conflict(fixture_id,season_team_id) do nothing;

  select * into v_obligation from public.team_fixture_payment_obligations
  where fixture_id=p_fixture_id and season_team_id=p_season_team_id for update;

  if v_obligation.scheduled_at_snapshot is distinct from v_fixture.scheduled_at
     or v_obligation.amount_pence<>v_fee then
    raise exception 'Existing payment snapshot differs from the current fixture or fee; administrator review is required';
  end if;

  if v_obligation.finance_charge_entry_id is null then
    insert into public.finance_entries(
      season_team_id,fixture_id,entry_type,amount_pence,description,due_at,created_by
    ) values(
      p_season_team_id,p_fixture_id,'charge',v_obligation.amount_pence,
      'Weekly team fixture fee — gameweek '||v_fixture.gameweek,
      v_obligation.deadline_at,v_actor
    ) returning * into v_charge;
    update public.team_fixture_payment_obligations
    set finance_charge_entry_id=v_charge.id where id=v_obligation.id
    returning * into v_obligation;
  end if;

  insert into public.team_fixture_payment_history(
    obligation_id,action,from_status,to_status,actor_user_id,reason,metadata
  )
  select v_obligation.id,'created',null,v_obligation.status,v_actor,
    'Captain created the weekly team fixture payment request',
    jsonb_build_object('amount_pence',v_obligation.amount_pence,
      'scheduled_at',v_obligation.scheduled_at_snapshot,
      'deadline_at',v_obligation.deadline_at,'grace_ends_at',v_obligation.grace_ends_at)
  where not exists(select 1 from public.team_fixture_payment_history h
    where h.obligation_id=v_obligation.id and h.action='created');

  return query select v_obligation.id,v_obligation.amount_pence,
    v_obligation.deadline_at,v_obligation.grace_ends_at,v_obligation.status;
end;
$$;
revoke all on function public.create_team_fixture_payment_obligation(uuid,uuid) from public,anon;
grant execute on function public.create_team_fixture_payment_obligation(uuid,uuid) to authenticated;

create or replace function public.get_captain_team_fixture_payments()
returns table(
  obligation_id uuid,fixture_id uuid,season_team_id uuid,team_name text,
  opponent_name text,gameweek integer,scheduled_at timestamptz,amount_pence integer,
  deadline_at timestamptz,grace_ends_at timestamptz,status text,paid_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  return query
  select o.id,o.fixture_id,o.season_team_id,st.name,
    case when f.home_team_id=o.season_team_id then away.name else home.name end,
    f.gameweek,f.scheduled_at,o.amount_pence,o.deadline_at,o.grace_ends_at,o.status,o.paid_at
  from public.team_fixture_payment_obligations o
  join public.fixtures f on f.id=o.fixture_id
  join public.season_teams st on st.id=o.season_team_id
  join public.season_teams home on home.id=f.home_team_id
  join public.season_teams away on away.id=f.away_team_id
  where exists(select 1 from public.team_memberships m
    where m.season_team_id=o.season_team_id and m.user_id=auth.uid()
      and m.status='active' and m.is_captain)
  order by f.scheduled_at desc;
end;
$$;
revoke all on function public.get_captain_team_fixture_payments() from public,anon;
grant execute on function public.get_captain_team_fixture_payments() to authenticated;

create or replace function public.get_admin_team_fixture_payment_queue(p_season_id uuid default null)
returns table(
  obligation_id uuid,fixture_id uuid,season_id uuid,season_name text,
  season_team_id uuid,team_name text,opponent_name text,gameweek integer,
  scheduled_at timestamptz,amount_pence integer,deadline_at timestamptz,
  grace_ends_at timestamptz,status text,paid_at timestamptz,
  refund_status text,strike_created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not public.has_finance_access() then
    raise exception 'Finance access required';
  end if;
  return query
  select o.id,o.fixture_id,s.id,s.name,o.season_team_id,st.name,
    case when f.home_team_id=o.season_team_id then away.name else home.name end,
    f.gameweek,f.scheduled_at,o.amount_pence,o.deadline_at,o.grace_ends_at,o.status,o.paid_at,
    r.status,(select min(ps.created_at) from public.team_payment_strikes ps where ps.obligation_id=o.id)
  from public.team_fixture_payment_obligations o
  join public.fixtures f on f.id=o.fixture_id
  join public.season_teams st on st.id=o.season_team_id
  join public.seasons s on s.id=f.season_id
  join public.season_teams home on home.id=f.home_team_id
  join public.season_teams away on away.id=f.away_team_id
  left join public.team_fixture_payment_refunds r on r.obligation_id=o.id
  where p_season_id is null or s.id=p_season_id
  order by o.deadline_at asc;
end;
$$;
revoke all on function public.get_admin_team_fixture_payment_queue(uuid) from public,anon;
grant execute on function public.get_admin_team_fixture_payment_queue(uuid) to authenticated;

-- Service-role-only scheduler: a fixture is cancelled exactly once at the end
-- of the 12-hour grace period. A changed/postponed fixture is held for review.
create or replace function public.process_team_fixture_payment_deadlines(p_as_of timestamptz default now())
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_obligation public.team_fixture_payment_obligations;
  v_fixture public.fixtures;
  v_opponent_id uuid;
  v_opponent public.team_fixture_payment_obligations;
  v_captain uuid;
  v_opponent_refund_created boolean;
  v_count integer:=0;
begin
  for v_obligation in
    select * from public.team_fixture_payment_obligations
    where status in ('due','grace_period')
      and (deadline_at<=p_as_of or grace_ends_at<=p_as_of)
    order by grace_ends_at
    for update skip locked
  loop
    select * into v_fixture from public.fixtures where id=v_obligation.fixture_id for update;
    if not found then continue; end if;

    if v_fixture.status<>'scheduled'
       or v_fixture.scheduled_at is distinct from v_obligation.scheduled_at_snapshot then
      update public.team_fixture_payment_obligations
      set status='admin_review'
      where id=v_obligation.id;
      insert into public.team_fixture_payment_history(
        obligation_id,action,from_status,to_status,actor_user_id,reason,metadata
      ) values(v_obligation.id,'schedule_changed',v_obligation.status,'admin_review',null,
        'Fixture status or scheduled time changed; payment deadline requires administrator review',
        jsonb_build_object('fixture_status',v_fixture.status,'current_scheduled_at',v_fixture.scheduled_at));
      v_count:=v_count+1;
      continue;
    end if;

    -- At the exact grace boundary, a provider-confirmed payment timestamp
    -- may still qualify. Defer a previously-graced obligation until time is
    -- strictly later, avoiding a race with the payment webhook.
    if v_obligation.status='grace_period' and p_as_of<=v_obligation.grace_ends_at then
      continue;
    end if;

    if p_as_of>=v_obligation.grace_ends_at and v_obligation.stripe_checkout_session_id is not null then
      update public.team_fixture_payment_obligations set status='admin_review' where id=v_obligation.id;
      insert into public.team_fixture_payment_history(
        obligation_id,action,from_status,to_status,actor_user_id,reason,metadata
      ) values(v_obligation.id,'provider_reconciliation_required',v_obligation.status,'admin_review',null,
        'An open Stripe Checkout session must be reconciled before cancellation',
        jsonb_build_object('stripe_checkout_session_id',v_obligation.stripe_checkout_session_id));
      v_count:=v_count+1;
      continue;
    end if;

    if p_as_of>v_obligation.grace_ends_at then
      v_opponent_refund_created:=false;
      update public.team_fixture_payment_obligations
      set status='defaulted',defaulted_at=p_as_of
      where id=v_obligation.id;
      insert into public.team_payment_strikes(
        obligation_id,fixture_id,season_team_id,original_deadline_at,reason
      ) values(v_obligation.id,v_obligation.fixture_id,v_obligation.season_team_id,
        v_obligation.deadline_at,'unpaid_at_grace_end')
      on conflict(obligation_id) do nothing;
      update public.fixtures set status='cancelled' where id=v_fixture.id and status='scheduled';

      v_opponent_id:=case when v_fixture.home_team_id=v_obligation.season_team_id
        then v_fixture.away_team_id else v_fixture.home_team_id end;
      select * into v_opponent from public.team_fixture_payment_obligations
      where fixture_id=v_fixture.id and season_team_id=v_opponent_id
      order by payment_cycle desc
      limit 1
      for update;
      if found and v_opponent.status in ('paid','late_paid') then
        insert into public.team_fixture_payment_refunds(
          obligation_id,amount_pence,stripe_payment_intent_id
        ) values(v_opponent.id,v_opponent.amount_pence,v_opponent.stripe_payment_intent_id)
        on conflict(obligation_id) do nothing;
        update public.team_fixture_payment_obligations
        set status='refund_pending' where id=v_opponent.id and status in ('paid','late_paid');
        v_opponent_refund_created:=true;
      end if;

      insert into public.team_fixture_payment_history(
        obligation_id,action,from_status,to_status,actor_user_id,reason,metadata
      ) values(v_obligation.id,'defaulted',v_obligation.status,'defaulted',null,
        'Payment not received by the end of the 12-hour grace period',
        jsonb_build_object('cancelled_fixture',true,'team_fee_remains_due',true,
          'opponent_refund_created',v_opponent_refund_created));
      for v_captain in select user_id from public.team_memberships
        where season_team_id=v_obligation.season_team_id and status='active' and is_captain
      loop
        perform public.enqueue_notification_event(v_captain,'team.payment.defaulted',
          jsonb_build_object('fixture_id',v_fixture.id,'obligation_id',v_obligation.id,
            'gameweek',v_fixture.gameweek,'fee_remains_due',true));
      end loop;
    else
      update public.team_fixture_payment_obligations
      set status='grace_period' where id=v_obligation.id and status='due';
      insert into public.team_fixture_payment_history(
        obligation_id,action,from_status,to_status,actor_user_id,reason
      ) values(v_obligation.id,'grace_period_started','due','grace_period',null,
        'The original 24-hour payment deadline has passed; the 12-hour grace period has started');
      for v_captain in select user_id from public.team_memberships
        where season_team_id=v_obligation.season_team_id and status='active' and is_captain
      loop
        perform public.enqueue_notification_event(v_captain,'team.payment.grace_period',
          jsonb_build_object('fixture_id',v_fixture.id,'obligation_id',v_obligation.id,
            'deadline_at',v_obligation.deadline_at,'grace_ends_at',v_obligation.grace_ends_at));
      end loop;
    end if;
    v_count:=v_count+1;
  end loop;
  return v_count;
end;
$$;
revoke all on function public.process_team_fixture_payment_deadlines(timestamptz) from public,anon,authenticated;
grant execute on function public.process_team_fixture_payment_deadlines(timestamptz) to service_role;

-- Called only after the signed Stripe webhook has verified the exact amount,
-- currency, obligation metadata and PaymentIntent against the provider.
create or replace function public.record_team_fixture_payment_success(
  p_obligation_id uuid,
  p_stripe_payment_intent_id text,
  p_paid_at timestamptz
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_obligation public.team_fixture_payment_obligations;
  v_fixture public.fixtures;
  v_status text;
  v_entry public.finance_entries;
  v_reason text;
begin
  if p_stripe_payment_intent_id is null or length(btrim(p_stripe_payment_intent_id))<5
     or p_paid_at is null then raise exception 'Verified payment details are required'; end if;
  select * into v_obligation from public.team_fixture_payment_obligations
  where id=p_obligation_id for update;
  if not found then raise exception 'Team fixture payment obligation not found'; end if;
  if v_obligation.stripe_payment_intent_id is not null then
    if v_obligation.stripe_payment_intent_id<>p_stripe_payment_intent_id then
      raise exception 'A different PaymentIntent is already attached to this obligation';
    end if;
    return v_obligation.status;
  end if;
  select * into v_fixture from public.fixtures where id=v_obligation.fixture_id for update;
  if not found then raise exception 'Fixture not found'; end if;

  if v_obligation.status='defaulted' and p_paid_at<=v_obligation.grace_ends_at then
    -- The worker may have cancelled after grace while Stripe's successful
    -- payment event was delayed in transit. Do not misclassify a timely
    -- provider payment as a late settlement or automatically restore play:
    -- preserve cancellation and require an administrator to reconcile it.
    v_status:='admin_review';
    v_reason:='Provider confirmed payment timestamp is within grace, but the fixture was already cancelled; administrator reconciliation required';
  elsif v_obligation.status='defaulted' then
    v_status:='paid_after_cancellation';
    v_reason:='Defaulting team settled its outstanding fee after fixture cancellation; fixture remains cancelled';
    insert into public.team_payment_strikes(
      obligation_id,fixture_id,season_team_id,original_deadline_at,paid_at,reason
    ) values(v_obligation.id,v_obligation.fixture_id,v_obligation.season_team_id,
      v_obligation.deadline_at,p_paid_at,'unpaid_at_grace_end')
    on conflict(obligation_id) do nothing;
  elsif p_paid_at<=v_obligation.deadline_at then
    v_status:='paid';
    v_reason:='Payment received by the original 24-hour deadline';
  elsif p_paid_at<=v_obligation.grace_ends_at then
    v_status:='late_paid';
    v_reason:='Payment received during the 12-hour grace period';
    insert into public.team_payment_strikes(
      obligation_id,fixture_id,season_team_id,original_deadline_at,paid_at,reason
    ) values(v_obligation.id,v_obligation.fixture_id,v_obligation.season_team_id,
      v_obligation.deadline_at,p_paid_at,'paid_during_grace')
    on conflict(obligation_id) do nothing;
  else
    v_status:='paid_after_cancellation';
    v_reason:='Payment received after the 12-hour grace period; fixture remains cancelled';
    insert into public.team_payment_strikes(
      obligation_id,fixture_id,season_team_id,original_deadline_at,paid_at,reason
    ) values(v_obligation.id,v_obligation.fixture_id,v_obligation.season_team_id,
      v_obligation.deadline_at,p_paid_at,'paid_after_cancellation')
    on conflict(obligation_id) do nothing;
    if v_fixture.status='scheduled' then
      update public.fixtures set status='cancelled' where id=v_fixture.id;
    end if;
  end if;

  if v_obligation.status in ('refund_pending','refunded','refund_failed') then
    raise exception 'A refunded or refund-pending payment cannot be re-settled';
  end if;
  update public.team_fixture_payment_obligations
  set status=v_status,paid_at=p_paid_at,stripe_payment_intent_id=p_stripe_payment_intent_id
  where id=v_obligation.id;

  insert into public.finance_entries(
    season_team_id,fixture_id,entry_type,amount_pence,description,payment_method,reference,created_by
  ) values(
    v_obligation.season_team_id,v_obligation.fixture_id,'payment',v_obligation.amount_pence,
    'Stripe weekly team fixture payment','other',p_stripe_payment_intent_id,v_obligation.created_by
  ) returning * into v_entry;
  update public.team_fixture_payment_obligations
  set finance_payment_entry_id=v_entry.id where id=v_obligation.id;

  insert into public.team_fixture_payment_history(
    obligation_id,action,from_status,to_status,actor_user_id,reason,metadata
  ) values(v_obligation.id,'payment_confirmed',v_obligation.status,v_status,null,v_reason,
    jsonb_build_object('stripe_payment_intent_id',p_stripe_payment_intent_id,'paid_at',p_paid_at));
  return v_status;
end;
$$;
revoke all on function public.record_team_fixture_payment_success(uuid,text,timestamptz) from public,anon,authenticated;
grant execute on function public.record_team_fixture_payment_success(uuid,text,timestamptz) to service_role;

create or replace function public.record_team_fixture_payment_refund_result(
  p_refund_id uuid,
  p_succeeded boolean,
  p_stripe_refund_id text default null,
  p_failure_reason text default null
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_refund public.team_fixture_payment_refunds;
  v_obligation public.team_fixture_payment_obligations;
  v_entry public.finance_entries;
  v_credit public.finance_entries;
begin
  select * into v_refund from public.team_fixture_payment_refunds
  where id=p_refund_id for update;
  if not found then raise exception 'Team fixture payment refund not found'; end if;
  select * into v_obligation from public.team_fixture_payment_obligations
  where id=v_refund.obligation_id for update;
  if not found then raise exception 'Refund payment obligation not found'; end if;
  if v_refund.status='refunded' then return 'refunded'; end if;

  if p_succeeded then
    if p_stripe_refund_id is null or length(btrim(p_stripe_refund_id))<5 then
      raise exception 'Stripe refund ID is required for a successful refund';
    end if;
    update public.team_fixture_payment_refunds
    set status='refunded',stripe_refund_id=p_stripe_refund_id,failure_reason=null
    where id=v_refund.id;
    update public.team_fixture_payment_obligations set status='refunded' where id=v_obligation.id;

    insert into public.finance_entries(
      season_team_id,fixture_id,entry_type,amount_pence,description,reference,created_by
    ) values(v_obligation.season_team_id,v_obligation.fixture_id,'refund',v_refund.amount_pence,
      'Stripe refund for cancelled fixture',p_stripe_refund_id,v_obligation.created_by)
    returning * into v_entry;
    insert into public.finance_entries(
      season_team_id,fixture_id,entry_type,amount_pence,description,reference,created_by
    ) values(v_obligation.season_team_id,v_obligation.fixture_id,'credit',v_refund.amount_pence,
      'Fee credit for cancelled fixture refund',p_stripe_refund_id,v_obligation.created_by)
    returning * into v_credit;
    update public.team_fixture_payment_refunds
    set refund_finance_entry_id=v_entry.id,credit_finance_entry_id=v_credit.id
    where id=v_refund.id;
    insert into public.team_fixture_payment_history(
      obligation_id,action,from_status,to_status,actor_user_id,reason,metadata
    ) values(v_obligation.id,'opponent_refund_confirmed','refund_pending','refunded',null,
      'Stripe confirmed the refund and the fee-waiver credit was recorded',
      jsonb_build_object('stripe_refund_id',p_stripe_refund_id,'amount_pence',v_refund.amount_pence));
  else
    update public.team_fixture_payment_refunds
    set status='failed',failure_reason=left(coalesce(p_failure_reason,'Stripe refund failed'),500)
    where id=v_refund.id;
    update public.team_fixture_payment_obligations set status='refund_failed' where id=v_obligation.id;
    insert into public.team_fixture_payment_history(
      obligation_id,action,from_status,to_status,actor_user_id,reason,metadata
    ) values(v_obligation.id,'opponent_refund_failed','refund_pending','refund_failed',null,
      'Stripe refund failed and requires finance administrator follow-up',
      jsonb_build_object('failure_reason',left(coalesce(p_failure_reason,'Stripe refund failed'),500)));
  end if;
  return case when p_succeeded then 'refunded' else 'failed' end;
end;
$$;
revoke all on function public.record_team_fixture_payment_refund_result(uuid,boolean,text,text) from public,anon,authenticated;
grant execute on function public.record_team_fixture_payment_refund_result(uuid,boolean,text,text) to service_role;

create trigger team_fixture_payment_obligations_set_updated_at
before update on public.team_fixture_payment_obligations
for each row execute function public.set_updated_at();
create trigger team_fixture_payment_refunds_set_updated_at
before update on public.team_fixture_payment_refunds
for each row execute function public.set_updated_at();


-- Checkout attempts and a separate webhook inbox keep team-level events isolated
-- from the existing player-level payment_records webhook lifecycle.
alter table public.team_fixture_payment_obligations
  add column checkout_attempt integer not null default 0 check (checkout_attempt>=0);

create table public.team_stripe_webhook_events (
  id text primary key,
  event_type text not null,
  obligation_id uuid references public.team_fixture_payment_obligations(id) on delete set null,
  processed_at timestamptz,
  processing_started_at timestamptz,
  processing_error text,
  created_at timestamptz not null default now()
);
alter table public.team_stripe_webhook_events enable row level security;
revoke all on public.team_stripe_webhook_events from public,anon,authenticated;
create policy team_stripe_webhook_events_deny_client_access
  on public.team_stripe_webhook_events for all to anon,authenticated
  using(false) with check(false);
grant select on public.team_fixture_payment_obligations,public.team_fixture_payment_refunds
  to service_role;
grant select,insert,update on public.team_stripe_webhook_events to service_role;

create or replace function public.claim_team_fixture_payment_checkout_attempt(
  p_obligation_id uuid,
  p_expected_session_id text default null
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_obligation public.team_fixture_payment_obligations;
begin
  select * into v_obligation from public.team_fixture_payment_obligations
  where id=p_obligation_id for update;
  if not found then raise exception 'Team fixture payment obligation not found'; end if;
  if v_obligation.status not in ('due','grace_period','defaulted')
     or (v_obligation.status in ('due','grace_period') and now()>v_obligation.grace_ends_at) then
    raise exception 'The payment window has closed or this obligation cannot be paid';
  end if;
  if v_obligation.stripe_checkout_session_id is distinct from p_expected_session_id then
    raise exception 'Checkout session changed; refresh before retrying';
  end if;
  update public.team_fixture_payment_obligations
  set checkout_attempt=checkout_attempt+1,stripe_checkout_session_id=null
  where id=v_obligation.id
  returning checkout_attempt into v_obligation.checkout_attempt;
  return v_obligation.checkout_attempt;
end;
$$;
revoke all on function public.claim_team_fixture_payment_checkout_attempt(uuid,text) from public,anon,authenticated;
grant execute on function public.claim_team_fixture_payment_checkout_attempt(uuid,text) to service_role;

create or replace function public.set_team_fixture_payment_checkout_session(
  p_obligation_id uuid,
  p_attempt integer,
  p_session_id text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare v_updated integer;
begin
  if p_session_id is null or length(btrim(p_session_id))<5 then
    raise exception 'A valid Stripe Checkout session is required';
  end if;
  update public.team_fixture_payment_obligations
  set stripe_checkout_session_id=p_session_id
  where id=p_obligation_id and checkout_attempt=p_attempt
    and stripe_checkout_session_id is null
    and status in ('due','grace_period','defaulted')
    and (status='defaulted' or now()<grace_ends_at);
  get diagnostics v_updated=row_count;
  return v_updated=1;
end;
$$;
revoke all on function public.set_team_fixture_payment_checkout_session(uuid,integer,text) from public,anon,authenticated;
grant execute on function public.set_team_fixture_payment_checkout_session(uuid,integer,text) to service_role;

create or replace function public.clear_team_fixture_payment_checkout_session(
  p_obligation_id uuid,
  p_session_id text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare v_updated integer;
begin
  update public.team_fixture_payment_obligations
  set stripe_checkout_session_id=null,
      status=case when status='admin_review' then 'grace_period' else status end
  where id=p_obligation_id and stripe_checkout_session_id=p_session_id
    and status in ('due','grace_period','defaulted','admin_review');
  get diagnostics v_updated=row_count;
  return v_updated=1;
end;
$$;
revoke all on function public.clear_team_fixture_payment_checkout_session(uuid,text) from public,anon,authenticated;
grant execute on function public.clear_team_fixture_payment_checkout_session(uuid,text) to service_role;
