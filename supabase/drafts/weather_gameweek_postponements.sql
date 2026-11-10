-- Stable gameweek identities, weather postponements, payment refunds and chronological renumbering.

create table public.season_gameweeks (
  id uuid primary key default gen_random_uuid(),
  season_id uuid not null references public.seasons(id) on delete restrict,
  week_number integer not null check (week_number>0),
  scheduled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(season_id,week_number)
);
create index season_gameweeks_season_schedule_idx
  on public.season_gameweeks(season_id,scheduled_at,week_number);
alter table public.season_gameweeks enable row level security;
revoke all on public.season_gameweeks from public,anon,authenticated;

insert into public.season_gameweeks(season_id,week_number,scheduled_at)
select f.season_id,f.gameweek,min(f.scheduled_at)
from public.fixtures f
group by f.season_id,f.gameweek
on conflict(season_id,week_number) do nothing;

alter table public.season_gameweeks
  add constraint season_gameweeks_id_season_unique unique(id,season_id);
alter table public.fixtures
  add column gameweek_id uuid references public.season_gameweeks(id) on delete restrict;
alter table public.fixtures
  add constraint fixtures_gameweek_season_fk
  foreign key(gameweek_id,season_id) references public.season_gameweeks(id,season_id) on delete restrict;
update public.fixtures f
set gameweek_id=sg.id
from public.season_gameweeks sg
where sg.season_id=f.season_id and sg.week_number=f.gameweek
  and f.gameweek_id is null;
create index fixtures_gameweek_id_idx on public.fixtures(gameweek_id);

create or replace function public.assign_fixture_gameweek_identity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare v_gameweek_id uuid;
begin
  insert into public.season_gameweeks as existing_week(season_id,week_number,scheduled_at)
  values(new.season_id,new.gameweek,new.scheduled_at)
  on conflict(season_id,week_number) do update
    set scheduled_at=case
      when existing_week.scheduled_at is null then excluded.scheduled_at
      when excluded.scheduled_at is null then existing_week.scheduled_at
      else least(existing_week.scheduled_at,excluded.scheduled_at)
    end
  returning id into v_gameweek_id;
  new.gameweek_id:=v_gameweek_id;
  return new;
end;
$$;
revoke all on function public.assign_fixture_gameweek_identity() from public,anon,authenticated;
drop trigger if exists fixtures_assign_gameweek_identity on public.fixtures;
create trigger fixtures_assign_gameweek_identity
before insert or update of season_id,gameweek,gameweek_id on public.fixtures
for each row execute function public.assign_fixture_gameweek_identity();

-- Each rescheduled gameweek starts a new payment cycle. Previous receipts are
-- refunded; unpaid old charges are credited; the new date gets a fresh deadline.
alter table public.team_fixture_payment_obligations
  drop constraint if exists team_fixture_payment_obligations_fixture_id_season_team_id_key;
alter table public.team_fixture_payment_obligations
  add column payment_cycle integer not null default 1 check (payment_cycle>0),
  add column finance_cancellation_credit_entry_id uuid references public.finance_entries(id) on delete restrict;
alter table public.team_fixture_payment_obligations
  add constraint team_fixture_payment_obligation_cycle_unique
  unique(fixture_id,season_team_id,payment_cycle);
alter table public.team_fixture_payment_obligations
  drop constraint if exists team_fixture_payment_obligations_status_check;
alter table public.team_fixture_payment_obligations
  add constraint team_fixture_payment_obligations_status_check
  check(status in ('due','grace_period','paid','late_paid','defaulted','paid_after_cancellation',
    'refund_pending','refunded','refund_failed','admin_review','cancelled'));
alter table public.team_fixture_payment_obligations
  drop constraint if exists team_fixture_payment_paid_state;
alter table public.team_fixture_payment_obligations
  add constraint team_fixture_payment_paid_state check (
    (status in ('paid','late_paid','paid_after_cancellation','refund_pending','refunded','refund_failed')
      and paid_at is not null and stripe_payment_intent_id is not null)
    or status in ('due','grace_period','defaulted','admin_review','cancelled')
  );

create unique index team_payment_strikes_fixture_team_unique
  on public.team_payment_strikes(fixture_id,season_team_id);
create index team_payment_strikes_obligation_idx
  on public.team_payment_strikes(obligation_id);

create table public.gameweek_postponement_history (
  id uuid primary key default gen_random_uuid(),
  gameweek_id uuid not null references public.season_gameweeks(id) on delete restrict,
  season_id uuid not null references public.seasons(id) on delete restrict,
  old_week_number integer not null,
  new_week_number integer not null,
  old_scheduled_at timestamptz not null,
  new_scheduled_at timestamptz not null,
  reason text not null check(length(btrim(reason)) between 5 and 500),
  actor_user_id uuid not null references auth.users(id) on delete restrict,
  affected_fixtures integer not null check(affected_fixtures>0),
  refunded_team_payments integer not null default 0 check(refunded_team_payments>=0),
  credited_unpaid_obligations integer not null default 0 check(credited_unpaid_obligations>=0),
  created_at timestamptz not null default now(),
  before_data jsonb not null default '{}'::jsonb,
  after_data jsonb not null default '{}'::jsonb
);
alter table public.gameweek_postponement_history enable row level security;
revoke all on public.gameweek_postponement_history from public,anon,authenticated;

create or replace function public.get_admin_postponable_gameweeks(p_season_id uuid default null)
returns table(
  gameweek_id uuid,season_id uuid,season_name text,week_number integer,
  scheduled_at timestamptz,fixture_count bigint,paid_team_count bigint,
  location_name text
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
  return query
  select sg.id,s.id,s.name,sg.week_number,sg.scheduled_at,count(f.id),
    count(o.id) filter(where o.status in ('paid','late_paid')),
    min(loc.name)
  from public.season_gameweeks sg
  join public.seasons s on s.id=sg.season_id
  join public.leagues l on l.id=s.league_id
  join public.fixtures f on f.gameweek_id=sg.id
  left join public.locations loc on loc.id=coalesce(f.venue_id,l.location_id)
  left join public.team_fixture_payment_obligations o on o.fixture_id=f.id
    and o.payment_cycle=(select max(latest.payment_cycle)
      from public.team_fixture_payment_obligations latest
      where latest.fixture_id=f.id and latest.season_team_id=o.season_team_id)
  where (p_season_id is null or s.id=p_season_id)
    and f.status in ('scheduled','postponed')
    and not exists(select 1 from public.fixtures done
      where done.gameweek_id=sg.id and done.status not in ('scheduled','postponed'))
  group by sg.id,s.id,s.name,sg.week_number,sg.scheduled_at
  having bool_and(public.can_administer_location(coalesce(f.venue_id,l.location_id)))
  order by s.name,sg.week_number;
end;
$$;
revoke all on function public.get_admin_postponable_gameweeks(uuid) from public,anon;
grant execute on function public.get_admin_postponable_gameweeks(uuid) to authenticated;

-- The captain RPC now returns only the latest payment cycle for each fixture/team.
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
    and o.payment_cycle=(select max(latest.payment_cycle)
      from public.team_fixture_payment_obligations latest
      where latest.fixture_id=o.fixture_id and latest.season_team_id=o.season_team_id)
  order by f.scheduled_at desc;
end;
$$;
revoke all on function public.get_captain_team_fixture_payments() from public,anon;
grant execute on function public.get_captain_team_fixture_payments() to authenticated;

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
  v_cycle integer;
  v_obligation public.team_fixture_payment_obligations;
  v_charge public.finance_entries;
begin
  if v_actor is null then raise exception 'Authentication required'; end if;
  if not public.is_active_team_captain(p_season_team_id) then
    raise exception 'Active team captain permission required';
  end if;
  select * into v_fixture from public.fixtures where id=p_fixture_id for update;
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

  select max(payment_cycle) into v_cycle
  from public.team_fixture_payment_obligations
  where fixture_id=p_fixture_id and season_team_id=p_season_team_id;
  v_cycle:=coalesce(v_cycle,1);
  select * into v_obligation from public.team_fixture_payment_obligations
  where fixture_id=p_fixture_id and season_team_id=p_season_team_id
    and payment_cycle=v_cycle for update;
  if found then
    if v_obligation.scheduled_at_snapshot is distinct from v_fixture.scheduled_at
       or v_obligation.amount_pence<>v_fee then
      raise exception 'Existing payment snapshot differs from the current fixture or fee; administrator review is required';
    end if;
    return query select v_obligation.id,v_obligation.amount_pence,
      v_obligation.deadline_at,v_obligation.grace_ends_at,v_obligation.status;
    return;
  end if;

  insert into public.team_fixture_payment_obligations(
    fixture_id,season_team_id,amount_pence,scheduled_at_snapshot,deadline_at,grace_ends_at,
    created_by,payment_cycle
  ) values(
    p_fixture_id,p_season_team_id,v_fee,v_fixture.scheduled_at,
    v_fixture.scheduled_at-interval '24 hours',
    v_fixture.scheduled_at-interval '12 hours',v_actor,v_cycle
  ) returning * into v_obligation;

  insert into public.finance_entries(
    season_team_id,fixture_id,entry_type,amount_pence,description,due_at,created_by
  ) values(
    p_season_team_id,p_fixture_id,'charge',v_obligation.amount_pence,
    'Weekly team fixture fee — gameweek '||v_fixture.gameweek||' (cycle '||v_cycle||')',
    v_obligation.deadline_at,v_actor
  ) returning * into v_charge;
  update public.team_fixture_payment_obligations
  set finance_charge_entry_id=v_charge.id where id=v_obligation.id
  returning * into v_obligation;

  insert into public.team_fixture_payment_history(
    obligation_id,action,from_status,to_status,actor_user_id,reason,metadata
  ) values(v_obligation.id,'created',null,v_obligation.status,v_actor,
    'Captain created the weekly team fixture payment request',
    jsonb_build_object('payment_cycle',v_cycle,'amount_pence',v_obligation.amount_pence,
      'scheduled_at',v_obligation.scheduled_at_snapshot,
      'deadline_at',v_obligation.deadline_at,'grace_ends_at',v_obligation.grace_ends_at));
  return query select v_obligation.id,v_obligation.amount_pence,
    v_obligation.deadline_at,v_obligation.grace_ends_at,v_obligation.status;
end;
$$;
revoke all on function public.create_team_fixture_payment_obligation(uuid,uuid) from public,anon;
grant execute on function public.create_team_fixture_payment_obligation(uuid,uuid) to authenticated;

create or replace function public.admin_postpone_gameweek(
  p_gameweek_id uuid,
  p_replacement_at timestamptz,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid:=auth.uid();
  v_week public.season_gameweeks;
  v_existing_history public.gameweek_postponement_history;
  v_season_id uuid;
  v_location_id uuid;
  v_fixture_count integer;
  v_old_payment public.team_fixture_payment_obligations;
  v_new_obligation public.team_fixture_payment_obligations;
  v_fixture public.fixtures;
  v_fee integer;
  v_cycle integer;
  v_charge public.finance_entries;
  v_credit public.finance_entries;
  v_old_number integer;
  v_new_number integer;
  v_completed_max integer;
  v_offset integer;
  v_refunds integer:=0;
  v_credits integer:=0;
  v_delta interval;
  v_captain uuid;
  v_history_id uuid;
begin
  if v_actor is null or not public.has_platform_role() then
    raise exception 'Administrator permission required';
  end if;
  if p_replacement_at is null or p_replacement_at<=now() then
    raise exception 'Choose a replacement date and time in the future';
  end if;
  if p_reason is null or length(btrim(p_reason)) not between 5 and 500 then
    raise exception 'Enter a reason between 5 and 500 characters';
  end if;

  select * into v_week from public.season_gameweeks where id=p_gameweek_id for update;
  if not found then raise exception 'Gameweek not found'; end if;
  v_old_number:=v_week.week_number;
  v_season_id:=v_week.season_id;
  select coalesce(f.venue_id,l.location_id) into v_location_id
  from public.fixtures f
  join public.seasons s on s.id=f.season_id
  join public.leagues l on l.id=s.league_id
  where f.gameweek_id=p_gameweek_id
  order by f.fixture_number limit 1;
  if v_location_id is null or not public.can_administer_location(v_location_id) then
    raise exception 'You are not assigned to this gameweek location';
  end if;
  if v_week.scheduled_at is null then raise exception 'Gameweek has no original scheduled date'; end if;
  select * into v_existing_history from public.gameweek_postponement_history
  where gameweek_id=p_gameweek_id and new_scheduled_at=p_replacement_at limit 1;
  if found and v_week.scheduled_at=p_replacement_at then
    return jsonb_build_object('gameweek_id',p_gameweek_id,
      'old_week_number',v_existing_history.old_week_number,
      'new_week_number',v_existing_history.new_week_number,
      'scheduled_at',v_existing_history.new_scheduled_at,
      'fixture_count',v_existing_history.affected_fixtures,
      'refunds_queued',v_existing_history.refunded_team_payments,
      'unpaid_cycles_credited',v_existing_history.credited_unpaid_obligations,
      'already_applied',true);
  end if;
  if v_week.scheduled_at=p_replacement_at then raise exception 'Choose a different replacement date and time'; end if;

  perform 1 from public.fixtures where gameweek_id=p_gameweek_id for update;
  select count(*) into v_fixture_count from public.fixtures where gameweek_id=p_gameweek_id;
  if v_fixture_count=0 then raise exception 'Gameweek has no fixtures'; end if;
  if exists(select 1 from public.fixtures where gameweek_id=p_gameweek_id
      and (status not in ('scheduled','postponed') or scheduled_at is null)) then
    raise exception 'Only a wholly unplayed gameweek can be postponed';
  end if;
  if exists(select 1 from public.team_fixture_payment_obligations o
      join public.fixtures f on f.id=o.fixture_id
      where f.gameweek_id=p_gameweek_id and o.status in ('admin_review','defaulted','paid_after_cancellation')
        and o.payment_cycle=(select max(latest.payment_cycle) from public.team_fixture_payment_obligations latest
          where latest.fixture_id=o.fixture_id and latest.season_team_id=o.season_team_id)) then
    raise exception 'A payment or fixture exception is already under administrator review';
  end if;
  if exists(select 1 from public.team_fixture_payment_obligations o
      join public.fixtures f on f.id=o.fixture_id
      where f.gameweek_id=p_gameweek_id and o.status in ('due','grace_period')
        and o.stripe_checkout_session_id is not null) then
    raise exception 'An active Stripe checkout must be expired before this gameweek can be postponed';
  end if;

  v_delta:=p_replacement_at-v_week.scheduled_at;
  update public.fixtures
  set scheduled_at=scheduled_at+v_delta,status='scheduled'
  where gameweek_id=p_gameweek_id;
  update public.season_gameweeks set scheduled_at=p_replacement_at where id=p_gameweek_id;

  -- Reconcile old-cycle receipts and unpaid charges before opening a fresh cycle.
  for v_old_payment in
    select o.* from public.team_fixture_payment_obligations o
    join public.fixtures f on f.id=o.fixture_id
    where f.gameweek_id=p_gameweek_id
      and o.payment_cycle=(select max(latest.payment_cycle)
        from public.team_fixture_payment_obligations latest
        where latest.fixture_id=o.fixture_id and latest.season_team_id=o.season_team_id)
      and o.status in ('due','grace_period','paid','late_paid')
    for update
  loop
    if v_old_payment.status in ('paid','late_paid') then
      if v_old_payment.stripe_payment_intent_id is null then
        raise exception 'A paid team obligation is missing its Stripe PaymentIntent';
      end if;
      insert into public.team_fixture_payment_refunds(
        obligation_id,amount_pence,stripe_payment_intent_id
      ) values(v_old_payment.id,v_old_payment.amount_pence,v_old_payment.stripe_payment_intent_id)
      on conflict do nothing;
      update public.team_fixture_payment_obligations
      set status='refund_pending' where id=v_old_payment.id;
      v_refunds:=v_refunds+1;
      insert into public.team_fixture_payment_history(
        obligation_id,action,from_status,to_status,actor_user_id,reason,metadata
      ) values(v_old_payment.id,'weather_refund_queued',v_old_payment.status,'refund_pending',v_actor,
        'Paid team fee refunded because the gameweek was postponed for weather',
        jsonb_build_object('gameweek_id',p_gameweek_id,'reason',p_reason));
    else
      insert into public.finance_entries(
        season_team_id,fixture_id,entry_type,amount_pence,description,reference,created_by
      ) values(v_old_payment.season_team_id,v_old_payment.fixture_id,'credit',
        v_old_payment.amount_pence,'Weather postponement credit for previous payment cycle',
        'gameweek-postponement:'||p_gameweek_id::text||':'||v_old_payment.id::text,v_old_payment.created_by)
      returning * into v_credit;
      update public.team_fixture_payment_obligations
      set status='cancelled',finance_cancellation_credit_entry_id=v_credit.id
      where id=v_old_payment.id;
      v_credits:=v_credits+1;
      insert into public.team_fixture_payment_history(
        obligation_id,action,from_status,to_status,actor_user_id,reason,metadata
      ) values(v_old_payment.id,'weather_fee_credited',v_old_payment.status,'cancelled',v_actor,
        'Unpaid previous-cycle fee credited because the gameweek was postponed for weather',
        jsonb_build_object('gameweek_id',p_gameweek_id,'credit_entry_id',v_credit.id));
    end if;
  end loop;

  -- Move all unplayed rounds into temporary numbers first to avoid the
  -- existing (season_id,gameweek,fixture_number) unique constraint.
  select coalesce(max(week_number),0) into v_offset
  from public.season_gameweeks where season_id=v_season_id;
  v_offset:=v_offset+1000;
  update public.season_gameweeks sg
  set week_number=sg.week_number+v_offset
  where sg.season_id=v_season_id
    and exists(select 1 from public.fixtures f where f.gameweek_id=sg.id)
    and exists(select 1 from public.fixtures f where f.gameweek_id=sg.id and f.status<>'completed');
  update public.fixtures f set gameweek=sg.week_number
  from public.season_gameweeks sg
  where sg.id=f.gameweek_id and sg.season_id=v_season_id and sg.week_number>=v_offset;

  select coalesce(max(sg.week_number),0) into v_completed_max
  from public.season_gameweeks sg
  where sg.season_id=v_season_id
    and exists(select 1 from public.fixtures f where f.gameweek_id=sg.id)
    and not exists(select 1 from public.fixtures f where f.gameweek_id=sg.id and f.status<>'completed');

  with ordered as (
    select sg.id,row_number() over(order by sg.scheduled_at,sg.id)::integer as position
    from public.season_gameweeks sg
    where sg.season_id=v_season_id and sg.week_number>=v_offset
  )
  update public.season_gameweeks sg
  set week_number=v_completed_max+ordered.position
  from ordered where ordered.id=sg.id;
  update public.fixtures f set gameweek=sg.week_number
  from public.season_gameweeks sg where sg.id=f.gameweek_id and sg.season_id=v_season_id;

  select week_number into v_new_number from public.season_gameweeks where id=p_gameweek_id;

  -- Re-open a new payment cycle using the replacement kick-off and its new week number.
  for v_old_payment in
    select o.* from public.team_fixture_payment_obligations o
    join public.fixtures f on f.id=o.fixture_id
    where f.gameweek_id=p_gameweek_id
      and o.payment_cycle=(select max(latest.payment_cycle) from public.team_fixture_payment_obligations latest
        where latest.fixture_id=o.fixture_id and latest.season_team_id=o.season_team_id)
      and o.status in ('cancelled','refund_pending')
    order by o.fixture_id,o.season_team_id
  loop
    select * into v_fixture from public.fixtures where id=v_old_payment.fixture_id;
    select team_fee_pence into v_fee from public.season_fee_configs
    where season_id=v_season_id and team_fee_pence>0 and effective_from_gameweek<=v_fixture.gameweek
    order by effective_from_gameweek desc limit 1;
    if v_fee is null then raise exception 'A weekly team fee is not configured for the rescheduled gameweek'; end if;
    v_cycle:=v_old_payment.payment_cycle+1;
    insert into public.team_fixture_payment_obligations(
      fixture_id,season_team_id,amount_pence,scheduled_at_snapshot,deadline_at,grace_ends_at,
      created_by,payment_cycle
    ) values(
      v_old_payment.fixture_id,v_old_payment.season_team_id,v_fee,v_fixture.scheduled_at,
      v_fixture.scheduled_at-interval '24 hours',v_fixture.scheduled_at-interval '12 hours',
      v_old_payment.created_by,v_cycle
    ) returning * into v_new_obligation;
    insert into public.finance_entries(
      season_team_id,fixture_id,entry_type,amount_pence,description,due_at,created_by
    ) values(
      v_new_obligation.season_team_id,v_new_obligation.fixture_id,'charge',v_fee,
      'Weekly team fixture fee — rescheduled gameweek '||v_fixture.gameweek||' (cycle '||v_cycle||')',
      v_new_obligation.deadline_at,v_old_payment.created_by
    ) returning * into v_charge;
    update public.team_fixture_payment_obligations
    set finance_charge_entry_id=v_charge.id where id=v_new_obligation.id;
    insert into public.team_fixture_payment_history(
      obligation_id,action,from_status,to_status,actor_user_id,reason,metadata
    ) values(v_new_obligation.id,'weather_rescheduled_cycle_created',null,'due',v_actor,
      'New payment cycle created for the replacement gameweek date',
      jsonb_build_object('previous_obligation_id',v_old_payment.id,'payment_cycle',v_cycle,
        'gameweek',v_fixture.gameweek,'scheduled_at',v_fixture.scheduled_at));
  end loop;

  insert into public.gameweek_postponement_history(
    gameweek_id,season_id,old_week_number,new_week_number,old_scheduled_at,new_scheduled_at,
    reason,actor_user_id,affected_fixtures,refunded_team_payments,credited_unpaid_obligations,
    before_data,after_data
  ) values(
    p_gameweek_id,v_season_id,v_old_number,v_new_number,v_week.scheduled_at,p_replacement_at,
    btrim(p_reason),v_actor,v_fixture_count,v_refunds,v_credits,
    jsonb_build_object('week_number',v_old_number,'scheduled_at',v_week.scheduled_at),
    jsonb_build_object('week_number',v_new_number,'scheduled_at',p_replacement_at)
  ) returning id into v_history_id;
  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,before_data,after_data)
  values(v_actor,'gameweek.postponed','season_gameweek',p_gameweek_id::text,btrim(p_reason),
    jsonb_build_object('week_number',v_old_number,'scheduled_at',v_week.scheduled_at),
    jsonb_build_object('week_number',v_new_number,'scheduled_at',p_replacement_at,
      'refunded_team_payments',v_refunds,'credited_unpaid_obligations',v_credits));

  for v_captain in
    select distinct tm.user_id
    from public.fixtures f
    join public.team_memberships tm
      on tm.season_team_id in (f.home_team_id,f.away_team_id)
    where f.gameweek_id=p_gameweek_id and tm.status='active' and tm.is_captain
  loop
    perform public.enqueue_notification_event(v_captain,'gameweek.postponed',
      jsonb_build_object('postponement_id',v_history_id,'gameweek_id',p_gameweek_id,'old_gameweek',v_old_number,
        'new_gameweek',v_new_number,'replacement_at',p_replacement_at,
        'refunds_queued',v_refunds,'reason',btrim(p_reason)));
  end loop;

  return jsonb_build_object('gameweek_id',p_gameweek_id,'old_week_number',v_old_number,
    'new_week_number',v_new_number,'scheduled_at',p_replacement_at,'fixture_count',v_fixture_count,
    'refunds_queued',v_refunds,'unpaid_cycles_credited',v_credits);
end;
$$;
revoke all on function public.admin_postpone_gameweek(uuid,timestamptz,text) from public,anon;
grant execute on function public.admin_postpone_gameweek(uuid,timestamptz,text) to authenticated;

create trigger season_gameweeks_set_updated_at
before update on public.season_gameweeks
for each row execute function public.set_updated_at();

-- The unique strike key is now fixture/team rather than payment cycle. Use an
-- untargeted conflict clause so a rescheduled late payment cannot add another strike.
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

    if p_as_of>=v_obligation.grace_ends_at then
      v_opponent_refund_created:=false;
      update public.team_fixture_payment_obligations
      set status='defaulted',defaulted_at=p_as_of
      where id=v_obligation.id;
      insert into public.team_payment_strikes(
        obligation_id,fixture_id,season_team_id,original_deadline_at,reason
      ) values(v_obligation.id,v_obligation.fixture_id,v_obligation.season_team_id,
        v_obligation.deadline_at,'unpaid_at_grace_end')
      on conflict do nothing;
      update public.fixtures set status='cancelled' where id=v_fixture.id and status='scheduled';

      v_opponent_id:=case when v_fixture.home_team_id=v_obligation.season_team_id
        then v_fixture.away_team_id else v_fixture.home_team_id end;
      select * into v_opponent from public.team_fixture_payment_obligations
      where fixture_id=v_fixture.id and season_team_id=v_opponent_id for update;
      if found and v_opponent.status in ('paid','late_paid') then
        insert into public.team_fixture_payment_refunds(
          obligation_id,amount_pence,stripe_payment_intent_id
        ) values(v_opponent.id,v_opponent.amount_pence,v_opponent.stripe_payment_intent_id)
        on conflict do nothing;
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

  if v_obligation.status='defaulted' then
    v_status:='paid_after_cancellation';
    v_reason:='Defaulting team settled its outstanding fee after fixture cancellation; fixture remains cancelled';
    insert into public.team_payment_strikes(
      obligation_id,fixture_id,season_team_id,original_deadline_at,paid_at,reason
    ) values(v_obligation.id,v_obligation.fixture_id,v_obligation.season_team_id,
      v_obligation.deadline_at,p_paid_at,'unpaid_at_grace_end')
    on conflict do nothing;
  elsif p_paid_at<=v_obligation.deadline_at then
    v_status:='paid';
    v_reason:='Payment received by the original 24-hour deadline';
  elsif p_paid_at<v_obligation.grace_ends_at then
    v_status:='late_paid';
    v_reason:='Payment received during the 12-hour grace period';
    insert into public.team_payment_strikes(
      obligation_id,fixture_id,season_team_id,original_deadline_at,paid_at,reason
    ) values(v_obligation.id,v_obligation.fixture_id,v_obligation.season_team_id,
      v_obligation.deadline_at,p_paid_at,'paid_during_grace')
    on conflict do nothing;
  else
    v_status:='paid_after_cancellation';
    v_reason:='Payment received after the 12-hour grace period; fixture remains cancelled';
    insert into public.team_payment_strikes(
      obligation_id,fixture_id,season_team_id,original_deadline_at,paid_at,reason
    ) values(v_obligation.id,v_obligation.fixture_id,v_obligation.season_team_id,
      v_obligation.deadline_at,p_paid_at,'paid_after_cancellation')
    on conflict do nothing;
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



-- Include the unique postponement history ID in notification deduplication so
-- a second weather postponement of the same gameweek can notify captains again.
create or replace function public.enqueue_notification_event(
  p_user_id uuid,
  p_event_type text,
  p_payload jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_preferences public.notification_preferences; v_dedupe text;
begin
  if p_user_id is null or p_event_type is null or length(btrim(p_event_type))<3 then return; end if;
  insert into public.notification_preferences(user_id) values(p_user_id) on conflict(user_id) do nothing;
  select * into v_preferences from public.notification_preferences where user_id=p_user_id;
  v_dedupe:=p_event_type||':'||coalesce(
    p_payload->>'postponement_id',
    p_payload->>'fixture_id',
    p_payload->>'membership_id',
    p_payload->>'season_team_id',
    'event'
  )||':'||p_user_id::text;

  if v_preferences.email_enabled then
    insert into public.notification_events(user_id,channel,event_type,status,payload,dedupe_key)
    values(p_user_id,'email',p_event_type,'queued',coalesce(p_payload,'{}'::jsonb),v_dedupe||':email')
    on conflict(dedupe_key) where dedupe_key is not null do nothing;
  end if;
  if v_preferences.sms_enabled then
    insert into public.notification_events(user_id,channel,event_type,status,payload,dedupe_key)
    values(p_user_id,'sms',p_event_type,'queued',coalesce(p_payload,'{}'::jsonb),v_dedupe||':sms')
    on conflict(dedupe_key) where dedupe_key is not null do nothing;
  end if;
  if v_preferences.in_app_enabled then
    insert into public.notification_events(user_id,channel,event_type,status,payload,dedupe_key,sent_at)
    values(p_user_id,'in_app',p_event_type,'sent',coalesce(p_payload,'{}'::jsonb),v_dedupe||':in_app',now())
    on conflict(dedupe_key) where dedupe_key is not null do nothing;
  end if;
end;
$$;
