-- Stripe Connect Express onboarding and referee payout transfers.
-- All new Stripe actions are test-mode-only in their Edge Functions.

create table public.referee_connect_accounts (
  referee_user_id uuid primary key references auth.users(id) on delete restrict,
  stripe_account_id text not null unique,
  onboarding_status text not null default 'onboarding_required'
    check(onboarding_status in ('onboarding_required','verification_pending','enabled','restricted')),
  details_submitted boolean not null default false,
  transfers_enabled boolean not null default false,
  payouts_enabled boolean not null default false,
  charges_enabled boolean not null default false,
  requirements_due jsonb not null default '{}'::jsonb
    check(jsonb_typeof(requirements_due)='object'),
  disabled_reason text,
  last_synced_at timestamptz not null default now(),
  stripe_event_created_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint referee_connect_enabled_state check (
    onboarding_status<>'enabled' or (details_submitted and transfers_enabled)
  )
);
create index referee_connect_accounts_payouts_idx
  on public.referee_connect_accounts(onboarding_status,payouts_enabled,transfers_enabled);

alter table public.referee_report_payouts
  drop constraint referee_report_payouts_status_check;
alter table public.referee_report_payouts
  add constraint referee_report_payouts_status_check
  check(status in ('pending_connect','processing','transferred','failed','cancelled'));
alter table public.referee_report_payouts
  add column if not exists processing_started_at timestamptz,
  add column if not exists transfer_attempts integer not null default 0 check(transfer_attempts>=0),
  add column if not exists failure_reason text;

alter table public.referee_milestone_rewards
  drop constraint referee_milestone_rewards_status_check;
alter table public.referee_milestone_rewards
  add constraint referee_milestone_rewards_status_check
  check(status in ('pending_connect','processing','transferred','failed','cancelled'));
alter table public.referee_milestone_rewards
  add column processing_started_at timestamptz,
  add column transfer_attempts integer not null default 0 check(transfer_attempts>=0),
  add column failure_reason text;

create table public.referee_connect_webhook_events (
  stripe_event_id text primary key,
  event_type text not null,
  processed_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.referee_payout_transfer_history (
  id uuid primary key default gen_random_uuid(),
  payout_type text not null check(payout_type in ('match_report','milestone')),
  payout_id uuid not null,
  referee_user_id uuid references auth.users(id) on delete set null,
  attempt_number integer not null check(attempt_number>0),
  stripe_transfer_id text unique,
  amount_pence integer not null check(amount_pence>0),
  currency text not null default 'gbp' check(currency='gbp'),
  status text not null check(status in ('transferred','failed','reversed')),
  failure_reason text,
  created_at timestamptz not null default now(),
  unique(payout_type,payout_id,attempt_number)
);
create index referee_payout_transfer_history_payout_idx
  on public.referee_payout_transfer_history(payout_type,payout_id,attempt_number desc);

alter table public.referee_connect_accounts enable row level security;
alter table public.referee_connect_webhook_events enable row level security;
alter table public.referee_payout_transfer_history enable row level security;
revoke all on public.referee_connect_accounts,public.referee_connect_webhook_events,
  public.referee_payout_transfer_history from public,anon,authenticated;

create trigger referee_connect_accounts_set_updated_at
before update on public.referee_connect_accounts
for each row execute function public.set_updated_at();

create or replace function public.get_my_referee_connect_status()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user uuid:=auth.uid();
  v_account public.referee_connect_accounts;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if not exists(
    select 1 from public.referee_memberships
    where user_id=v_user and status='active'
  ) then raise exception 'An active referee membership is required'; end if;

  select * into v_account from public.referee_connect_accounts
  where referee_user_id=v_user;

  if not found then
    return jsonb_build_object(
      'onboarding_status','onboarding_required','details_submitted',false,
      'transfers_enabled',false,'payouts_enabled',false,'charges_enabled',false,
      'requirements_due','{}'::jsonb,'disabled_reason',null,'last_synced_at',null
    );
  end if;

  return jsonb_build_object(
    'onboarding_status',v_account.onboarding_status,
    'details_submitted',v_account.details_submitted,
    'transfers_enabled',v_account.transfers_enabled,
    'payouts_enabled',v_account.payouts_enabled,
    'charges_enabled',v_account.charges_enabled,
    'requirements_due',v_account.requirements_due,
    'disabled_reason',v_account.disabled_reason,
    'last_synced_at',v_account.last_synced_at
  );
end;
$$;
revoke all on function public.get_my_referee_connect_status() from public,anon;
grant execute on function public.get_my_referee_connect_status() to authenticated;

create or replace function public.sync_referee_connect_account(
  p_referee_user_id uuid,
  p_stripe_account_id text,
  p_details_submitted boolean,
  p_transfers_enabled boolean,
  p_payouts_enabled boolean,
  p_charges_enabled boolean,
  p_requirements_due jsonb,
  p_disabled_reason text,
  p_stripe_event_created_at timestamptz default null
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_existing public.referee_connect_accounts;
  v_status text;
begin
  if p_referee_user_id is null or p_stripe_account_id is null
     or length(btrim(p_stripe_account_id))<5 then
    raise exception 'A referee and verified Stripe connected account are required';
  end if;
  -- Stripe account state must continue syncing even if a referee later leaves the active roster.
  if p_requirements_due is null or jsonb_typeof(p_requirements_due)<>'object' then
    raise exception 'Stripe requirements must be a JSON object';
  end if;

  select * into v_existing from public.referee_connect_accounts
  where referee_user_id=p_referee_user_id;
  if found and v_existing.stripe_account_id<>p_stripe_account_id then
    raise exception 'A different Stripe connected account is already linked to this referee';
  end if;
  select * into v_existing from public.referee_connect_accounts
  where stripe_account_id=p_stripe_account_id;
  if found and v_existing.referee_user_id<>p_referee_user_id then
    raise exception 'This Stripe connected account is already linked to another referee';
  end if;

  v_status:=case
    when nullif(btrim(coalesce(p_disabled_reason,'')),'') is not null then 'restricted'
    when coalesce(p_details_submitted,false)
      and coalesce(p_transfers_enabled,false) then 'enabled'
    when coalesce(p_details_submitted,false) then 'verification_pending'
    else 'onboarding_required'
  end;

  insert into public.referee_connect_accounts(
    referee_user_id,stripe_account_id,onboarding_status,details_submitted,
    transfers_enabled,payouts_enabled,charges_enabled,requirements_due,disabled_reason,last_synced_at,stripe_event_created_at
  ) values(
    p_referee_user_id,p_stripe_account_id,v_status,coalesce(p_details_submitted,false),
    coalesce(p_transfers_enabled,false),coalesce(p_payouts_enabled,false),
    coalesce(p_charges_enabled,false),p_requirements_due,left(p_disabled_reason,500),now(),coalesce(p_stripe_event_created_at,now())
  )
  on conflict(referee_user_id) do update set
    onboarding_status=excluded.onboarding_status,
    details_submitted=excluded.details_submitted,
    transfers_enabled=excluded.transfers_enabled,
    payouts_enabled=excluded.payouts_enabled,
    charges_enabled=excluded.charges_enabled,
    requirements_due=excluded.requirements_due,
    disabled_reason=excluded.disabled_reason,
    last_synced_at=excluded.last_synced_at,
    stripe_event_created_at=excluded.stripe_event_created_at
  where public.referee_connect_accounts.stripe_event_created_at < excluded.stripe_event_created_at;

  return v_status;
end;
$$;
revoke all on function public.sync_referee_connect_account(uuid,text,boolean,boolean,boolean,boolean,jsonb,text,timestamptz)
  from public,anon,authenticated;
grant execute on function public.sync_referee_connect_account(uuid,text,boolean,boolean,boolean,boolean,jsonb,text,timestamptz)
  to service_role;

create or replace function public.claim_referee_payout_transfer(
  p_payout_type text,
  p_payout_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid:=auth.uid();
  v_account public.referee_connect_accounts;
  v_report_payout public.referee_report_payouts;
  v_milestone public.referee_milestone_rewards;
  v_location_id uuid;
  v_referee_user_id uuid;
  v_amount integer;
  v_attempt integer;
  v_report_id uuid;
begin
  if v_actor is null then
    raise exception 'Authentication required';
  end if;
  if p_payout_type is null or p_payout_type not in ('match_report','milestone') or p_payout_id is null then
    raise exception 'A valid referee payout type and ID are required';
  end if;
  -- Match-report transfers are authorised by the same location scope as report
  -- approval. Milestone rewards remain restricted to finance-capable global admins.
  if p_payout_type='milestone' and
     (not public.has_platform_role() or not public.has_finance_access()) then
    raise exception 'Global finance administrator permission required for referee milestone rewards';
  end if;

  if p_payout_type='match_report' then
    select payout.* into v_report_payout
    from public.referee_report_payouts payout
    where payout.id=p_payout_id for update;
    if not found then raise exception 'Referee match-report payout not found'; end if;
    if v_report_payout.status not in ('pending_connect','failed') then
      raise exception 'This referee payout is not ready for transfer';
    end if;
    select coalesce(fixture.venue_id,league.location_id) into v_location_id
    from public.referee_match_reports report
    join public.fixtures fixture on fixture.id=report.fixture_id
    join public.seasons season on season.id=fixture.season_id
    join public.leagues league on league.id=season.league_id
    where report.id=v_report_payout.report_id;
    if v_location_id is null or not public.can_administer_location(v_location_id) then
      raise exception 'You cannot administer this referee payout location';
    end if;
    v_referee_user_id:=v_report_payout.referee_user_id;
    v_amount:=v_report_payout.referee_net_pence;
    v_report_id:=v_report_payout.report_id;
    v_attempt:=v_report_payout.transfer_attempts+1;
  else
    select * into v_milestone from public.referee_milestone_rewards
    where id=p_payout_id for update;
    if not found then raise exception 'Referee milestone reward not found'; end if;
    if v_milestone.status not in ('pending_connect','failed') then
      raise exception 'This referee milestone is not ready for transfer';
    end if;
    v_referee_user_id:=v_milestone.referee_user_id;
    v_amount:=v_milestone.amount_pence;
    v_attempt:=v_milestone.transfer_attempts+1;
  end if;

  if v_referee_user_id is null then raise exception 'The referee account is unavailable'; end if;
  select * into v_account from public.referee_connect_accounts
  where referee_user_id=v_referee_user_id for update;
  if not found or v_account.onboarding_status<>'enabled'
     or not v_account.transfers_enabled then
    raise exception 'The referee must complete Stripe Connect verification before receiving a payout';
  end if;

  if p_payout_type='match_report' then
    update public.referee_report_payouts
    set status='processing',processing_started_at=now(),transfer_attempts=v_attempt,failure_reason=null
    where id=p_payout_id;
  else
    update public.referee_milestone_rewards
    set status='processing',processing_started_at=now(),transfer_attempts=v_attempt,failure_reason=null
    where id=p_payout_id;
  end if;

  return jsonb_build_object(
    'payout_type',p_payout_type,'payout_id',p_payout_id,
    'referee_user_id',v_referee_user_id,'stripe_account_id',v_account.stripe_account_id,
    'amount_pence',v_amount,'currency','gbp','attempt',v_attempt,'report_id',v_report_id
  );
end;
$$;
revoke all on function public.claim_referee_payout_transfer(text,uuid) from public,anon;
grant execute on function public.claim_referee_payout_transfer(text,uuid) to authenticated;

create or replace function public.record_referee_payout_transfer_success(
  p_payout_type text,
  p_payout_id uuid,
  p_stripe_transfer_id text,
  p_destination_account_id text,
  p_amount_pence integer,
  p_currency text
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_expected_account text;
  v_referee_user_id uuid;
  v_expected_amount integer;
  v_existing_transfer text;
  v_status text;
  v_attempt integer;
begin
  if p_payout_type is null or p_payout_type not in ('match_report','milestone')
     or p_payout_id is null or p_stripe_transfer_id is null
     or p_destination_account_id is null or p_amount_pence is null
     or lower(coalesce(p_currency,''))<>'gbp' then
    raise exception 'Verified Stripe transfer details are required';
  end if;

  if p_payout_type='match_report' then
    select payout.referee_user_id,payout.referee_net_pence,payout.stripe_transfer_id,payout.status
      into v_referee_user_id,v_expected_amount,v_existing_transfer,v_status
    from public.referee_report_payouts payout
    where payout.id=p_payout_id for update;
  else
    select reward.referee_user_id,reward.amount_pence,reward.stripe_transfer_id,reward.status
      into v_referee_user_id,v_expected_amount,v_existing_transfer,v_status
    from public.referee_milestone_rewards reward
    where reward.id=p_payout_id for update;
  end if;
  if v_status is null then raise exception 'Referee payout not found'; end if;
  select stripe_account_id into v_expected_account
  from public.referee_connect_accounts
  where referee_user_id=v_referee_user_id;
  if v_expected_account is null or v_expected_account<>p_destination_account_id then
    raise exception 'Stripe transfer destination does not match the referee connected account';
  end if;
  if p_amount_pence<>v_expected_amount then
    raise exception 'Stripe transfer amount does not match the approved referee payout';
  end if;
  if v_existing_transfer is not null and v_existing_transfer<>p_stripe_transfer_id then
    raise exception 'A different Stripe transfer is already recorded for this payout';
  end if;
  if exists(
    select 1 from public.referee_payout_transfer_history history
    where history.payout_type=p_payout_type and history.payout_id=p_payout_id
      and history.stripe_transfer_id=p_stripe_transfer_id and history.status='reversed'
  ) then return 'reversed'; end if;
  if v_status not in ('processing','transferred') then
    raise exception 'Referee payout is not in a transferable state';
  end if;

  if p_payout_type='match_report' then
    select transfer_attempts into v_attempt from public.referee_report_payouts where id=p_payout_id;
  else
    select transfer_attempts into v_attempt from public.referee_milestone_rewards where id=p_payout_id;
  end if;
  insert into public.referee_payout_transfer_history(
    payout_type,payout_id,referee_user_id,attempt_number,stripe_transfer_id,
    amount_pence,currency,status
  ) values(
    p_payout_type,p_payout_id,v_referee_user_id,v_attempt,p_stripe_transfer_id,
    p_amount_pence,'gbp','transferred'
  )
  on conflict(payout_type,payout_id,attempt_number) do update set
    stripe_transfer_id=excluded.stripe_transfer_id,status='transferred',failure_reason=null;

  if p_payout_type='match_report' then
    update public.referee_report_payouts
    set status='transferred',stripe_transfer_id=p_stripe_transfer_id,
      transferred_at=coalesce(transferred_at,now()),processing_started_at=null,failure_reason=null
    where id=p_payout_id;
  else
    update public.referee_milestone_rewards
    set status='transferred',stripe_transfer_id=p_stripe_transfer_id,
      transferred_at=coalesce(transferred_at,now()),processing_started_at=null,failure_reason=null
    where id=p_payout_id;
  end if;
  return 'transferred';
end;
$$;
revoke all on function public.record_referee_payout_transfer_success(text,uuid,text,text,integer,text)
  from public,anon,authenticated;
grant execute on function public.record_referee_payout_transfer_success(text,uuid,text,text,integer,text)
  to service_role;

create or replace function public.record_referee_payout_transfer_failure(
  p_payout_type text,
  p_payout_id uuid,
  p_failure_reason text,
  p_transfer_reversed boolean default false,
  p_stripe_transfer_id text default null
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status text;
  v_referee_user_id uuid;
  v_amount integer;
  v_attempt integer;
  v_transfer_id text;
begin
  if p_payout_type is null or p_payout_type not in ('match_report','milestone') or p_payout_id is null then
    raise exception 'A valid referee payout is required';
  end if;
  if p_payout_type='match_report' then
    select status,referee_user_id,referee_net_pence,transfer_attempts,stripe_transfer_id into v_status,v_referee_user_id,v_amount,v_attempt,v_transfer_id from public.referee_report_payouts where id=p_payout_id for update;
    if v_status is null then raise exception 'Referee payout not found'; end if;
    if v_status not in ('processing','transferred') or (v_status='transferred' and not p_transfer_reversed) then
      raise exception 'Referee payout cannot be marked failed from its current state';
    end if;
    if p_transfer_reversed and (p_stripe_transfer_id is null or v_transfer_id is distinct from p_stripe_transfer_id) then
      return 'stale_reversal';
    end if;
    insert into public.referee_payout_transfer_history(
      payout_type,payout_id,referee_user_id,attempt_number,stripe_transfer_id,
      amount_pence,currency,status,failure_reason
    ) values(
      'match_report',p_payout_id,v_referee_user_id,v_attempt,v_transfer_id,v_amount,'gbp',
      case when p_transfer_reversed then 'reversed' else 'failed' end,
      left(coalesce(p_failure_reason,'Stripe transfer failed'),500)
    )
    on conflict(payout_type,payout_id,attempt_number) do update set
      status=excluded.status,failure_reason=excluded.failure_reason;
    update public.referee_report_payouts
    set status='failed',failure_reason=left(coalesce(p_failure_reason,'Stripe transfer failed'),500),
      processing_started_at=null,
      stripe_transfer_id=case when p_transfer_reversed then null else stripe_transfer_id end
    where id=p_payout_id;
  else
    select status,referee_user_id,amount_pence,transfer_attempts,stripe_transfer_id into v_status,v_referee_user_id,v_amount,v_attempt,v_transfer_id from public.referee_milestone_rewards where id=p_payout_id for update;
    if v_status is null then raise exception 'Referee milestone reward not found'; end if;
    if v_status not in ('processing','transferred') or (v_status='transferred' and not p_transfer_reversed) then
      raise exception 'Referee milestone cannot be marked failed from its current state';
    end if;
    if p_transfer_reversed and (p_stripe_transfer_id is null or v_transfer_id is distinct from p_stripe_transfer_id) then
      return 'stale_reversal';
    end if;
    insert into public.referee_payout_transfer_history(
      payout_type,payout_id,referee_user_id,attempt_number,stripe_transfer_id,
      amount_pence,currency,status,failure_reason
    ) values(
      'milestone',p_payout_id,v_referee_user_id,v_attempt,v_transfer_id,v_amount,'gbp',
      case when p_transfer_reversed then 'reversed' else 'failed' end,
      left(coalesce(p_failure_reason,'Stripe transfer failed'),500)
    )
    on conflict(payout_type,payout_id,attempt_number) do update set
      status=excluded.status,failure_reason=excluded.failure_reason;
    update public.referee_milestone_rewards
    set status='failed',failure_reason=left(coalesce(p_failure_reason,'Stripe transfer failed'),500),
      processing_started_at=null,
      stripe_transfer_id=case when p_transfer_reversed then null else stripe_transfer_id end
    where id=p_payout_id;
  end if;
  return 'failed';
end;
$$;
revoke all on function public.record_referee_payout_transfer_failure(text,uuid,text,boolean,text)
  from public,anon,authenticated;
grant execute on function public.record_referee_payout_transfer_failure(text,uuid,text,boolean,text)
  to service_role;

create or replace function public.admin_list_referee_report_payouts_connect(
  p_status text default 'pending_connect'
)
returns table(
  payout_id uuid,report_id uuid,referee_user_id uuid,referee_name text,
  referee_email text,fixture_id uuid,gameweek integer,fixture_number integer,
  scheduled_at timestamptz,location_id uuid,location_name text,
  gross_allocation_pence integer,deductions_pence integer,referee_net_pence integer,
  open_play_top_up_pence integer,status text,stripe_transfer_id text,
  failure_reason text,transfer_attempts integer,connect_status text,
  transfers_enabled boolean,payouts_enabled boolean,created_at timestamptz,transferred_at timestamptz
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
  select payout.id,payout.report_id,payout.referee_user_id,
    coalesce(player.full_name,'Referee'),
    player.email,fixture.id,fixture.gameweek,fixture.fixture_number,fixture.scheduled_at,
    location.id,location.name,payout.gross_allocation_pence,payout.deductions_pence,
    payout.referee_net_pence,payout.open_play_top_up_pence,payout.status,payout.stripe_transfer_id,
    payout.failure_reason,payout.transfer_attempts,coalesce(connect.onboarding_status,'onboarding_required'),
    coalesce(connect.transfers_enabled,false),coalesce(connect.payouts_enabled,false),
    payout.created_at,payout.transferred_at
  from public.referee_report_payouts payout
  join public.referee_match_reports report on report.id=payout.report_id
  join public.fixtures fixture on fixture.id=report.fixture_id
  join public.seasons season on season.id=fixture.season_id
  join public.leagues league on league.id=season.league_id
  join public.locations location on location.id=coalesce(fixture.venue_id,league.location_id)
  left join public.players player on player.user_id=payout.referee_user_id
  left join public.referee_connect_accounts connect on connect.referee_user_id=payout.referee_user_id
  where (p_status='all' or payout.status=p_status)
    and public.can_administer_location(location.id)
  order by payout.created_at desc;
end;
$$;
revoke all on function public.admin_list_referee_report_payouts_connect(text) from public,anon;
grant execute on function public.admin_list_referee_report_payouts_connect(text) to authenticated;

create or replace function public.admin_get_referee_payout_transfer_history(
  p_payout_type text,
  p_payout_id uuid
)
returns table(
  attempt_number integer,status text,amount_pence integer,
  stripe_transfer_id text,failure_reason text,created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_location_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_payout_type='match_report' and not public.has_finance_access() then
    raise exception 'Finance access required';
  end if;
  if p_payout_type='milestone' and not public.has_platform_role() then
    raise exception 'Global administrator permission required for referee milestone history';
  end if;
  if p_payout_type is null or p_payout_type not in ('match_report','milestone') or p_payout_id is null then
    raise exception 'A valid referee payout is required';
  end if;
  if p_payout_type='match_report' then
    select coalesce(fixture.venue_id,league.location_id) into v_location_id
    from public.referee_report_payouts payout
    join public.referee_match_reports report on report.id=payout.report_id
    join public.fixtures fixture on fixture.id=report.fixture_id
    join public.seasons season on season.id=fixture.season_id
    join public.leagues league on league.id=season.league_id
    where payout.id=p_payout_id;
    if v_location_id is null or not public.can_administer_location(v_location_id) then
      raise exception 'You cannot administer this referee payout location';
    end if;
  elsif not exists(select 1 from public.referee_milestone_rewards where id=p_payout_id) then
    raise exception 'Referee milestone reward not found';
  end if;
  return query
  select history.attempt_number,history.status,history.amount_pence,
    history.stripe_transfer_id,history.failure_reason,history.created_at
  from public.referee_payout_transfer_history history
  where history.payout_type=p_payout_type and history.payout_id=p_payout_id
  order by history.attempt_number desc;
end;
$$;
revoke all on function public.admin_get_referee_payout_transfer_history(text,uuid) from public,anon;
grant execute on function public.admin_get_referee_payout_transfer_history(text,uuid) to authenticated;

create or replace function public.admin_list_referee_milestone_rewards_connect(
  p_status text default 'pending_connect'
)
returns table(
  reward_id uuid,referee_user_id uuid,referee_name text,milestone_number integer,
  approved_games integer,amount_pence integer,status text,stripe_transfer_id text,
  failure_reason text,transfer_attempts integer,connect_status text,
  transfers_enabled boolean,payouts_enabled boolean,created_at timestamptz,transferred_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not public.has_platform_role() then
    raise exception 'Global administrator permission required for referee milestone rewards';
  end if;
  return query
  select reward.id,reward.referee_user_id,
    coalesce(player.full_name,'Referee'),
    reward.milestone_number,reward.approved_games,reward.amount_pence,reward.status,
    reward.stripe_transfer_id,reward.failure_reason,reward.transfer_attempts,
    coalesce(connect.onboarding_status,'onboarding_required'),
    coalesce(connect.transfers_enabled,false),coalesce(connect.payouts_enabled,false),
    reward.created_at,reward.transferred_at
  from public.referee_milestone_rewards reward
  left join public.players player on player.user_id=reward.referee_user_id
  left join public.referee_connect_accounts connect on connect.referee_user_id=reward.referee_user_id
  where p_status='all' or reward.status=p_status
  order by reward.created_at desc;
end;
$$;
revoke all on function public.admin_list_referee_milestone_rewards_connect(text) from public,anon;
grant execute on function public.admin_list_referee_milestone_rewards_connect(text) to authenticated;
