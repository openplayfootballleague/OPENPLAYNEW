-- Weather postponements are an administrator-led reschedule, not a payment default.
-- Completed/published gameweeks remain fixed. Open gameweeks are renumbered chronologically.

create table public.weather_gameweek_postponements (
  id uuid primary key default gen_random_uuid(),
  season_id uuid not null references public.seasons(id) on delete restrict,
  original_gameweek integer not null check (original_gameweek>0),
  replacement_date date not null,
  reason text not null check (length(btrim(reason)) between 5 and 500),
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  fixture_count integer not null default 0 check (fixture_count>0)
);
create index weather_gameweek_postponements_season_idx
  on public.weather_gameweek_postponements(season_id,created_at desc);

create table public.weather_postponement_fixtures (
  id uuid primary key default gen_random_uuid(),
  postponement_id uuid not null references public.weather_gameweek_postponements(id) on delete restrict,
  fixture_id uuid not null references public.fixtures(id) on delete restrict,
  original_gameweek integer not null,
  new_gameweek integer not null,
  original_scheduled_at timestamptz not null,
  replacement_scheduled_at timestamptz not null,
  created_at timestamptz not null default now(),
  unique(postponement_id,fixture_id)
);
create index weather_postponement_fixtures_fixture_idx
  on public.weather_postponement_fixtures(fixture_id,created_at desc);

create table public.fixture_gameweek_renumber_history (
  id uuid primary key default gen_random_uuid(),
  postponement_id uuid not null references public.weather_gameweek_postponements(id) on delete restrict,
  fixture_id uuid not null references public.fixtures(id) on delete restrict,
  old_gameweek integer not null,
  new_gameweek integer not null,
  changed_by uuid not null references auth.users(id) on delete restrict,
  reason text not null,
  created_at timestamptz not null default now(),
  unique(postponement_id,fixture_id)
);
create index fixture_gameweek_renumber_history_fixture_idx
  on public.fixture_gameweek_renumber_history(fixture_id,created_at desc);

alter table public.weather_gameweek_postponements enable row level security;
alter table public.weather_postponement_fixtures enable row level security;
alter table public.fixture_gameweek_renumber_history enable row level security;
revoke all on public.weather_gameweek_postponements,public.weather_postponement_fixtures,
  public.fixture_gameweek_renumber_history from public,anon,authenticated;

alter table public.team_fixture_payment_obligations
  add column payment_cycle integer not null default 1 check (payment_cycle>0),
  add column weather_postponement_id uuid references public.weather_gameweek_postponements(id) on delete restrict;
alter table public.team_fixture_payment_obligations
  drop constraint team_fixture_payment_obligations_fixture_id_season_team_id_key;
alter table public.team_fixture_payment_obligations
  add constraint team_fixture_payment_obligations_fixture_team_cycle_key
  unique(fixture_id,season_team_id,payment_cycle);
alter table public.team_fixture_payment_obligations
  drop constraint team_fixture_payment_obligations_status_check;
alter table public.team_fixture_payment_obligations
  add constraint team_fixture_payment_obligations_status_check
  check(status in (
    'due','grace_period','paid','late_paid','defaulted','paid_after_cancellation',
    'refund_pending','refunded','refund_failed','admin_review','weather_cancelled'
  ));
alter table public.team_fixture_payment_obligations
  drop constraint team_fixture_payment_paid_state;
alter table public.team_fixture_payment_obligations
  add constraint team_fixture_payment_paid_state check (
    (status in ('paid','late_paid','paid_after_cancellation','refund_pending','refunded','refund_failed')
      and paid_at is not null and stripe_payment_intent_id is not null)
    or status in ('due','grace_period','defaulted','admin_review','weather_cancelled')
  );
alter table public.team_fixture_payment_refunds
  add column reason text not null default 'payment_default'
  check(reason in ('payment_default','weather_postponement','team_withdrawal'));

create index team_fixture_payment_weather_idx
  on public.team_fixture_payment_obligations(weather_postponement_id)
  where weather_postponement_id is not null;

-- Create a new payment cycle when a postponed fixture receives its replacement date.
-- Retries within a cycle return the same obligation; old paid/refunded cycles remain immutable.
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
  v_cycle integer;
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

  select * into v_obligation
  from public.team_fixture_payment_obligations
  where fixture_id=p_fixture_id and season_team_id=p_season_team_id
  order by payment_cycle desc limit 1 for update;

  if not found then
    v_cycle:=1;
  elsif v_obligation.weather_postponement_id is not null
     and v_obligation.status in ('weather_cancelled','refund_pending','refunded','refund_failed') then
    select coalesce(max(payment_cycle),0)+1 into v_cycle
    from public.team_fixture_payment_obligations
    where fixture_id=p_fixture_id and season_team_id=p_season_team_id;
    v_obligation:=null;
  else
    v_cycle:=v_obligation.payment_cycle;
    if v_obligation.scheduled_at_snapshot is distinct from v_fixture.scheduled_at
       or v_obligation.amount_pence<>v_fee then
      raise exception 'Existing payment snapshot differs from the current fixture or fee; administrator review is required';
    end if;
  end if;

  if v_obligation.id is null then
    insert into public.team_fixture_payment_obligations(
      fixture_id,season_team_id,payment_cycle,amount_pence,scheduled_at_snapshot,
      deadline_at,grace_ends_at,created_by
    ) values(
      p_fixture_id,p_season_team_id,v_cycle,v_fee,v_fixture.scheduled_at,
      v_fixture.scheduled_at-interval '24 hours',
      v_fixture.scheduled_at-interval '12 hours',v_actor
    ) returning * into v_obligation;
  end if;

  if v_obligation.finance_charge_entry_id is null then
    insert into public.finance_entries(
      season_team_id,fixture_id,entry_type,amount_pence,description,due_at,created_by,
      reference
    ) values(
      p_season_team_id,p_fixture_id,'charge',v_obligation.amount_pence,
      'Weekly team fixture fee — gameweek '||v_fixture.gameweek,
      v_obligation.deadline_at,v_actor,
      'team-fixture:'||v_obligation.id::text
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
    jsonb_build_object('payment_cycle',v_obligation.payment_cycle,
      'amount_pence',v_obligation.amount_pence,'scheduled_at',v_obligation.scheduled_at_snapshot,
      'deadline_at',v_obligation.deadline_at,'grace_ends_at',v_obligation.grace_ends_at)
  where not exists(select 1 from public.team_fixture_payment_history h
    where h.obligation_id=v_obligation.id and h.action='created');

  return query select v_obligation.id,v_obligation.amount_pence,
    v_obligation.deadline_at,v_obligation.grace_ends_at,v_obligation.status;
end;
$$;
revoke all on function public.create_team_fixture_payment_obligation(uuid,uuid) from public,anon;
grant execute on function public.create_team_fixture_payment_obligation(uuid,uuid) to authenticated;

-- A payment that clears after a weather cancellation is still refunded. It must not
-- create a late-payment strike or revive the postponed fixture.
create or replace function public.record_team_fixture_payment_success(
  p_obligation_id uuid,p_stripe_payment_intent_id text,p_paid_at timestamptz
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

  if v_obligation.status='weather_cancelled' then
    v_status:='refund_pending';
    v_reason:='Payment completed after a weather postponement; full refund queued and no strike applied';
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
  elsif p_paid_at<v_obligation.grace_ends_at then
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

  if v_obligation.status='weather_cancelled' then
    insert into public.team_fixture_payment_refunds(
      obligation_id,amount_pence,stripe_payment_intent_id,reason
    ) values(v_obligation.id,v_obligation.amount_pence,p_stripe_payment_intent_id,'weather_postponement')
    on conflict(obligation_id) do nothing;
  end if;

  insert into public.team_fixture_payment_history(
    obligation_id,action,from_status,to_status,actor_user_id,reason,metadata
  ) values(v_obligation.id,'payment_confirmed',v_obligation.status,v_status,null,v_reason,
    jsonb_build_object('stripe_payment_intent_id',p_stripe_payment_intent_id,'paid_at',p_paid_at));
  return v_status;
end;
$$;
revoke all on function public.record_team_fixture_payment_success(uuid,text,timestamptz) from public,anon,authenticated;
grant execute on function public.record_team_fixture_payment_success(uuid,text,timestamptz) to service_role;

-- Admin can postpone an entire not-yet-played gameweek. The replacement date retains
-- each fixture's original local kickoff time. Refunds are full and automatic via
-- the existing team-payment refund worker; unpaid charges are offset by ledger credits.
create or replace function public.admin_postpone_gameweek_weather(
  p_season_id uuid,p_gameweek integer,p_replacement_date date,p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid:=auth.uid();
  v_postponement uuid;
  v_fixture record;
  v_new_scheduled_at timestamptz;
  v_old_max integer;
  v_offset integer;
  v_frozen_max integer;
  v_changed integer:=0;
  v_renumbered integer:=0;
  v_refund_count integer:=0;
  v_waiver_count integer:=0;
  v_member uuid;
  v_assignment record;
  v_week record;
begin
  if v_actor is null then
    raise exception 'Authentication required';
  end if;
  if p_gameweek is null or p_gameweek<1 then raise exception 'Choose a valid gameweek'; end if;
  if p_replacement_date is null or p_replacement_date <=
    (now() at time zone 'Europe/London')::date then
    raise exception 'Replacement date must be in the future';
  end if;
  if length(btrim(coalesce(p_reason,''))) not between 5 and 500 then
    raise exception 'A weather postponement reason of 5 to 500 characters is required';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_season_id::text,0));

  if not exists(select 1 from public.seasons where id=p_season_id) then
    raise exception 'Season not found';
  end if;
  if exists(
    select 1 from public.fixtures f
    left join public.fixture_results r on r.fixture_id=f.id
    where f.season_id=p_season_id and f.gameweek=p_gameweek
      and (f.status in ('completed','in_progress','cancelled') or r.fixture_id is not null)
  ) then
    raise exception 'This gameweek contains a completed, in-progress or separately cancelled fixture. Completed/published gameweeks cannot be silently postponed or renumbered';
  end if;
  if not exists(select 1 from public.fixtures where season_id=p_season_id and gameweek=p_gameweek and status='scheduled') then
    raise exception 'No scheduled fixtures were found in this gameweek';
  end if;
  if exists(select 1 from public.fixtures
    where season_id=p_season_id and gameweek=p_gameweek and status<>'scheduled') then
    raise exception 'Every fixture in the gameweek must still be scheduled before the whole gameweek can be postponed';
  end if;

  insert into public.weather_gameweek_postponements(
    season_id,original_gameweek,replacement_date,reason,created_by,fixture_count
  ) select p_season_id,p_gameweek,p_replacement_date,btrim(p_reason),v_actor,count(*)::integer
    from public.fixtures where season_id=p_season_id and gameweek=p_gameweek
    returning id into v_postponement;

  for v_fixture in
    select f.*,coalesce(f.venue_id,l.location_id) as admin_location_id
    from public.fixtures f
    join public.seasons s on s.id=f.season_id
    join public.leagues l on l.id=s.league_id
    where f.season_id=p_season_id and f.gameweek=p_gameweek and f.status='scheduled'
    order by f.fixture_number
    for update of f
  loop
    if v_fixture.scheduled_at is null then
      raise exception 'Every fixture in the gameweek needs an existing kickoff time before it can be postponed';
    end if;
    if not public.can_administer_location(v_fixture.admin_location_id) then
      raise exception 'You are not authorised to postpone every fixture in this gameweek';
    end if;
    v_new_scheduled_at:=(
      p_replacement_date + (v_fixture.scheduled_at at time zone 'Europe/London')::time
    ) at time zone 'Europe/London';
    if v_new_scheduled_at<=now()+interval '36 hours' then
      raise exception 'Replacement kickoff must be at least 36 hours away so the 24-hour deadline and 12-hour grace period can operate correctly';
    end if;

    insert into public.weather_postponement_fixtures(
      postponement_id,fixture_id,original_gameweek,new_gameweek,
      original_scheduled_at,replacement_scheduled_at
    ) values(v_postponement,v_fixture.id,v_fixture.gameweek,v_fixture.gameweek,
      v_fixture.scheduled_at,v_new_scheduled_at);
    update public.fixtures set scheduled_at=v_new_scheduled_at
    where id=v_fixture.id;

    -- Cancel active referee appointments without deleting their audit trail.
    for v_assignment in
      select * from public.referee_fixture_assignments
      where fixture_id=v_fixture.id and cancelled_at is null for update
    loop
      update public.referee_fixture_assignments
      set cancelled_at=now(),cancelled_by=v_actor,
        cancellation_reason='Weather postponement: '||left(btrim(p_reason),450)
      where id=v_assignment.id;
      perform public.enqueue_notification_event(
        v_assignment.referee_user_id,'referee.fixture_assignment_cancelled',
        jsonb_build_object('assignment_id',v_assignment.id,'fixture_id',v_fixture.id,
          'reason','Weather postponement: '||btrim(p_reason))
      );
    end loop;

    for v_member in
      select user_id from public.team_memberships
      where season_team_id in (v_fixture.home_team_id,v_fixture.away_team_id)
        and status='active'
    loop
      perform public.enqueue_notification_event(
        v_member,'fixture.weather_postponed',
        jsonb_build_object('fixture_id',v_fixture.id,'season_id',p_season_id,
          'old_gameweek',p_gameweek,'replacement_date',p_replacement_date,'reason',btrim(p_reason))
      );
    end loop;

    -- Paid teams are refunded; unpaid obligations are cancelled with a matching
    -- credit so no fee remains due. A late Stripe success is refunded by webhook.
    update public.team_fixture_payment_obligations
    set weather_postponement_id=v_postponement
    where fixture_id=v_fixture.id;

    for v_week in
      select * from public.team_fixture_payment_obligations
      where fixture_id=v_fixture.id
      for update
    loop
      if v_week.status in ('paid','late_paid') then
        insert into public.team_fixture_payment_refunds(
          obligation_id,amount_pence,stripe_payment_intent_id,reason
        ) values(v_week.id,v_week.amount_pence,v_week.stripe_payment_intent_id,'weather_postponement')
        on conflict(obligation_id) do nothing;
        update public.team_fixture_payment_obligations
        set status='refund_pending' where id=v_week.id;
        v_refund_count:=v_refund_count+1;
      elsif v_week.status in ('due','grace_period','admin_review') then
        update public.team_fixture_payment_obligations
        set status='weather_cancelled' where id=v_week.id;
        if v_week.finance_charge_entry_id is not null and not exists(
          select 1 from public.finance_entries
          where reference='weather-waiver:'||v_week.id::text
        ) then
          insert into public.finance_entries(
            season_team_id,fixture_id,entry_type,amount_pence,description,reference,created_by
          ) values(v_week.season_team_id,v_fixture.id,'credit',v_week.amount_pence,
            'Weekly team fee waived following weather postponement',
            'weather-waiver:'||v_week.id::text,v_actor);
          v_waiver_count:=v_waiver_count+1;
        end if;
      end if;
      insert into public.team_fixture_payment_history(
        obligation_id,action,from_status,to_status,actor_user_id,reason,metadata
      ) values(v_week.id,'weather_postponed',v_week.status,
        case when v_week.status in ('paid','late_paid') then 'refund_pending'
             when v_week.status in ('due','grace_period','admin_review') then 'weather_cancelled'
             else v_week.status end,
        v_actor,'Whole gameweek postponed due to weather',
        jsonb_build_object('postponement_id',v_postponement,'replacement_date',p_replacement_date));
    end loop;
    v_changed:=v_changed+1;
  end loop;

  select coalesce(max(gameweek),0) into v_old_max
  from public.fixtures where season_id=p_season_id;
  select coalesce(max(gameweek),0) into v_frozen_max
  from public.fixtures f
  where f.season_id=p_season_id
    and (f.status in ('completed','cancelled','in_progress')
      or exists(select 1 from public.fixture_results r where r.fixture_id=f.id));

  update public.weather_gameweek_postponements
  set fixture_count=v_changed where id=v_postponement;
  update public.seasons set ends_on=greatest(coalesce(ends_on,p_replacement_date),p_replacement_date)
  where id=p_season_id;

  -- Snapshot all unplayed gameweek numbers by their earliest scheduled kickoff.
  -- A completed/cancelled gameweek is frozen and never renumbered.
  insert into public.fixture_gameweek_renumber_history(
    postponement_id,fixture_id,old_gameweek,new_gameweek,changed_by,reason
  )
  with open_weeks as (
    select f.gameweek,min(f.scheduled_at) as first_kickoff
    from public.fixtures f
    where f.season_id=p_season_id and f.status='scheduled'
      and not exists(
        select 1 from public.fixtures frozen
        left join public.fixture_results result on result.fixture_id=frozen.id
        where frozen.season_id=p_season_id and frozen.gameweek=f.gameweek
          and (frozen.status in ('completed','cancelled','in_progress') or result.fixture_id is not null)
      )
    group by f.gameweek
  ), ranked as (
    select gameweek,first_kickoff,
      v_frozen_max+row_number() over(order by first_kickoff,gameweek)::integer as new_gameweek
    from open_weeks
  )
  select p.id,f.id,f.gameweek,r.new_gameweek,v_actor,
    'Chronological renumbering after weather postponement '||v_postponement::text
  from public.fixtures f join ranked r on r.gameweek=f.gameweek
  cross join public.weather_gameweek_postponements p
  where p.id=v_postponement and f.season_id=p_season_id and f.status='scheduled'
    and f.gameweek<>r.new_gameweek;

  get diagnostics v_renumbered = row_count;
  v_offset:=v_old_max+1000000;
  -- Move all open fixtures out of the live unique-key range before applying
  -- the new consecutive gameweek numbers.
  update public.fixtures f set gameweek=f.gameweek+v_offset
  where f.season_id=p_season_id and f.status='scheduled'
    and exists(select 1 from public.fixture_gameweek_renumber_history h
      where h.postponement_id=v_postponement and h.fixture_id=f.id);
  update public.fixtures f set gameweek=h.new_gameweek
  from public.fixture_gameweek_renumber_history h
  where h.postponement_id=v_postponement and h.fixture_id=f.id;

  update public.weather_postponement_fixtures w
  set new_gameweek=f.gameweek
  from public.fixtures f
  where w.postponement_id=v_postponement and w.fixture_id=f.id;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,before_data,after_data)
  values(v_actor,'fixture.gameweek.weather_postponed','weather_gameweek_postponement',
    v_postponement::text,btrim(p_reason),
    jsonb_build_object('season_id',p_season_id,'original_gameweek',p_gameweek),
    jsonb_build_object('replacement_date',p_replacement_date,'fixtures',v_changed,
      'renumbered_fixtures',v_renumbered,'refunds_queued',v_refund_count,
      'unpaid_fees_waived',v_waiver_count));

  return jsonb_build_object('postponement_id',v_postponement,'fixtures_postponed',v_changed,
    'replacement_date',p_replacement_date,'refunds_queued',v_refund_count,
    'unpaid_fees_waived',v_waiver_count,'renumbered_fixtures',v_renumbered);
end;
$$;
revoke all on function public.admin_postpone_gameweek_weather(uuid,integer,date,text) from public,anon;
grant execute on function public.admin_postpone_gameweek_weather(uuid,integer,date,text) to authenticated;

create or replace function public.get_admin_weather_postponements(p_season_id uuid default null)
returns table(
  postponement_id uuid,season_id uuid,season_name text,original_gameweek integer,
  replacement_date date,reason text,created_at timestamptz,fixture_count integer,
  refunds_pending bigint,refunds_completed bigint,refunds_failed bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  return query
  select p.id,p.season_id,s.name,p.original_gameweek,p.replacement_date,p.reason,
    p.created_at,p.fixture_count,
    (select count(*) from public.team_fixture_payment_refunds r
      join public.team_fixture_payment_obligations o on o.id=r.obligation_id
      join public.weather_postponement_fixtures wf on wf.fixture_id=o.fixture_id
      where wf.postponement_id=p.id and r.status in ('pending','processing')),
    (select count(*) from public.team_fixture_payment_refunds r
      join public.team_fixture_payment_obligations o on o.id=r.obligation_id
      join public.weather_postponement_fixtures wf on wf.fixture_id=o.fixture_id
      where wf.postponement_id=p.id and r.status='refunded'),
    (select count(*) from public.team_fixture_payment_refunds r
      join public.team_fixture_payment_obligations o on o.id=r.obligation_id
      join public.weather_postponement_fixtures wf on wf.fixture_id=o.fixture_id
      where wf.postponement_id=p.id and r.status='failed')
  from public.weather_gameweek_postponements p
  join public.seasons s on s.id=p.season_id
  where (p_season_id is null or p.season_id=p_season_id)
    and exists(
      select 1
      from public.weather_postponement_fixtures wf
      join public.fixtures fixture on fixture.id=wf.fixture_id
      join public.seasons season on season.id=fixture.season_id
      join public.leagues league on league.id=season.league_id
      where wf.postponement_id=p.id
        and public.can_administer_location(coalesce(fixture.venue_id,league.location_id))
    )
  order by p.created_at desc;
end;
$$;
revoke all on function public.get_admin_weather_postponements(uuid) from public,anon;
grant execute on function public.get_admin_weather_postponements(uuid) to authenticated;
