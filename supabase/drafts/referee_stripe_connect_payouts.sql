-- Stripe Connect Express onboarding and audited referee payout transfers.
create table public.referee_stripe_connect_accounts (
  referee_user_id uuid primary key references public.referee_memberships(user_id) on delete restrict,
  stripe_account_id text not null unique,
  account_type text not null default 'express' check(account_type='express'),
  country text not null default 'GB' check(country='GB'),
  details_submitted boolean not null default false,
  charges_enabled boolean not null default false,
  payouts_enabled boolean not null default false,
  requirements_currently_due text[] not null default '{}'::text[],
  requirements_past_due text[] not null default '{}'::text[],
  disabled_reason text,
  onboarding_completed_at timestamptz,
  last_synced_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index referee_connect_accounts_payouts_enabled_idx
  on public.referee_stripe_connect_accounts(payouts_enabled,details_submitted);
alter table public.referee_stripe_connect_accounts enable row level security;
revoke all on public.referee_stripe_connect_accounts from public,anon,authenticated;
grant select,insert,update on public.referee_stripe_connect_accounts to service_role;
create trigger referee_connect_accounts_set_updated_at
before update on public.referee_stripe_connect_accounts
for each row execute function public.set_updated_at();

create table public.referee_stripe_webhook_events (
  id text primary key,
  event_type text not null,
  processed_at timestamptz,
  processing_started_at timestamptz,
  processing_error text,
  created_at timestamptz not null default now()
);
alter table public.referee_stripe_webhook_events enable row level security;
revoke all on public.referee_stripe_webhook_events from public,anon,authenticated;
grant select,insert,update on public.referee_stripe_webhook_events to service_role;

create table public.referee_payout_transfer_attempts (
  id uuid primary key default gen_random_uuid(),
  payout_kind text not null check(payout_kind in ('report','milestone')),
  payout_id uuid not null,
  referee_user_id uuid not null references auth.users(id) on delete restrict,
  attempt_number integer not null check(attempt_number>0),
  amount_pence integer not null check(amount_pence>0),
  stripe_transfer_id text,
  idempotency_key text not null,
  status text not null check(status in ('transferred','failed')),
  failure_reason text,
  attempted_at timestamptz not null default now(),
  unique(payout_kind,payout_id,attempt_number)
);
create index referee_payout_transfer_attempts_user_idx
  on public.referee_payout_transfer_attempts(referee_user_id,attempted_at desc);
alter table public.referee_payout_transfer_attempts enable row level security;
revoke all on public.referee_payout_transfer_attempts from public,anon,authenticated;
grant select,insert on public.referee_payout_transfer_attempts to service_role;

alter table public.referee_report_payouts
  add column attempt_count integer not null default 0 check(attempt_count>=0),
  add column last_attempt_at timestamptz;
alter table public.referee_report_payouts
  drop constraint if exists referee_report_payouts_status_check;
alter table public.referee_report_payouts
  add constraint referee_report_payouts_status_check
  check(status in ('pending_connect','processing','transferred','failed','cancelled'));

alter table public.referee_milestone_rewards
  add column attempt_count integer not null default 0 check(attempt_count>=0),
  add column last_attempt_at timestamptz,
  add column failure_reason text;
alter table public.referee_milestone_rewards
  drop constraint if exists referee_milestone_rewards_status_check;
alter table public.referee_milestone_rewards
  add constraint referee_milestone_rewards_status_check
  check(status in ('pending_connect','processing','transferred','failed','cancelled'));

create or replace function public.get_referee_connect_status()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare v_user uuid:=auth.uid(); v_account public.referee_stripe_connect_accounts; v_connected boolean:=false;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if not exists(select 1 from public.referee_memberships m where m.user_id=v_user and m.status='active') then
    raise exception 'An active referee membership is required';
  end if;
  select * into v_account from public.referee_stripe_connect_accounts
  where referee_user_id=v_user;
  v_connected:=found;
  return jsonb_build_object(
    'connected',v_connected,
    'details_submitted',coalesce(v_account.details_submitted,false),
    'charges_enabled',coalesce(v_account.charges_enabled,false),
    'payouts_enabled',coalesce(v_account.payouts_enabled,false),
    'requirements_currently_due',coalesce(v_account.requirements_currently_due,'{}'::text[]),
    'requirements_past_due',coalesce(v_account.requirements_past_due,'{}'::text[]),
    'disabled_reason',v_account.disabled_reason,
    'country',coalesce(v_account.country,'GB'),
    'last_synced_at',v_account.last_synced_at
  );
end;
$$;
revoke all on function public.get_referee_connect_status() from public,anon;
grant execute on function public.get_referee_connect_status() to authenticated;

create or replace function public.get_referee_payout_history()
returns table(
  payout_kind text,payout_id uuid,amount_pence integer,status text,
  created_at timestamptz,transferred_at timestamptz,failure_reason text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare v_user uuid:=auth.uid();
begin
  if v_user is null or not exists(select 1 from public.referee_memberships m where m.user_id=v_user and m.status='active') then
    raise exception 'An active referee membership is required';
  end if;
  return query
    select 'report'::text,p.id,p.referee_net_pence,p.status,p.created_at,p.transferred_at,p.failure_reason
    from public.referee_report_payouts p where p.referee_user_id=v_user
    union all
    select 'milestone'::text,m.id,m.amount_pence,m.status,m.created_at,m.transferred_at,m.failure_reason
    from public.referee_milestone_rewards m where m.referee_user_id=v_user
    order by created_at desc limit 30;
end;
$$;
revoke all on function public.get_referee_payout_history() from public,anon;
grant execute on function public.get_referee_payout_history() to authenticated;

create or replace function public.get_admin_referee_payout_queue()
returns table(
  payout_kind text,payout_id uuid,referee_user_id uuid,referee_name text,
  amount_pence integer,status text,created_at timestamptz,failure_reason text,
  attempt_count integer,connected boolean,payouts_enabled boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not public.has_platform_role() or not public.has_finance_access() then
    raise exception 'Finance administrator permission required';
  end if;
  return query
    select 'report'::text,p.id,p.referee_user_id,coalesce(player.full_name,'Referee'),
      p.referee_net_pence,p.status,p.created_at,p.failure_reason,p.attempt_count,
      (a.stripe_account_id is not null),coalesce(a.payouts_enabled,false)
    from public.referee_report_payouts p
    left join public.players player on player.user_id=p.referee_user_id
    left join public.referee_stripe_connect_accounts a on a.referee_user_id=p.referee_user_id
    where p.status<>'cancelled'
    union all
    select 'milestone'::text,m.id,m.referee_user_id,coalesce(player.full_name,'Referee'),
      m.amount_pence,m.status,m.created_at,m.failure_reason,m.attempt_count,
      (a.stripe_account_id is not null),coalesce(a.payouts_enabled,false)
    from public.referee_milestone_rewards m
    left join public.players player on player.user_id=m.referee_user_id
    left join public.referee_stripe_connect_accounts a on a.referee_user_id=m.referee_user_id
    where m.status<>'cancelled'
    order by created_at desc;
end;
$$;
revoke all on function public.get_admin_referee_payout_queue() from public,anon;
grant execute on function public.get_admin_referee_payout_queue() to authenticated;

create or replace function public.sync_referee_stripe_connect_account(
  p_referee_user_id uuid,p_stripe_account_id text,p_details_submitted boolean,
  p_charges_enabled boolean,p_payouts_enabled boolean,
  p_requirements_currently_due text[],p_requirements_past_due text[],p_disabled_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.role()<>'service_role' then raise exception 'Service role required'; end if;
  if not exists(select 1 from public.referee_memberships m where m.user_id=p_referee_user_id) then
    raise exception 'Referee membership does not exist';
  end if;
  if p_stripe_account_id is null or p_stripe_account_id !~ '^acct_[A-Za-z0-9]+$' then
    raise exception 'Invalid Stripe Connect account ID';
  end if;
  insert into public.referee_stripe_connect_accounts as existing_account(
    referee_user_id,stripe_account_id,details_submitted,charges_enabled,payouts_enabled,
    requirements_currently_due,requirements_past_due,disabled_reason,onboarding_completed_at,last_synced_at
  ) values(
    p_referee_user_id,p_stripe_account_id,coalesce(p_details_submitted,false),
    coalesce(p_charges_enabled,false),coalesce(p_payouts_enabled,false),
    coalesce(p_requirements_currently_due,'{}'::text[]),coalesce(p_requirements_past_due,'{}'::text[]),
    p_disabled_reason,case when p_details_submitted then now() else null end,now()
  )
  on conflict(referee_user_id) do update set
    stripe_account_id=excluded.stripe_account_id,
    details_submitted=excluded.details_submitted,
    charges_enabled=excluded.charges_enabled,
    payouts_enabled=excluded.payouts_enabled,
    requirements_currently_due=excluded.requirements_currently_due,
    requirements_past_due=excluded.requirements_past_due,
    disabled_reason=excluded.disabled_reason,
    onboarding_completed_at=case when excluded.details_submitted
      then coalesce(existing_account.onboarding_completed_at,now()) else null end,
    last_synced_at=now(),updated_at=now();
end;
$$;
revoke all on function public.sync_referee_stripe_connect_account(uuid,text,boolean,boolean,boolean,text[],text[],text) from public,anon,authenticated;
grant execute on function public.sync_referee_stripe_connect_account(uuid,text,boolean,boolean,boolean,text[],text[],text) to service_role;

create or replace function public.claim_referee_report_payout_transfers(p_limit integer default 25)
returns table(payout_id uuid,referee_user_id uuid,stripe_account_id text,amount_pence integer,report_id uuid,attempt_number integer)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.role()<>'service_role' then raise exception 'Service role required'; end if;
  return query
  with candidates as (
    select p.id,p.referee_user_id,a.stripe_account_id,p.referee_net_pence,p.report_id
    from public.referee_report_payouts p
    join public.referee_match_reports r on r.id=p.report_id and r.status='approved'
    join public.referee_memberships m on m.user_id=p.referee_user_id and m.status='active'
    join public.referee_stripe_connect_accounts a on a.referee_user_id=p.referee_user_id
      and a.details_submitted and a.payouts_enabled
    where p.status in ('pending_connect','processing')
      and (p.status='pending_connect' or p.last_attempt_at<now()-interval '10 minutes')
    order by p.created_at
    for update of p skip locked
    limit greatest(1,least(coalesce(p_limit,25),100))
  ), claimed as (
    update public.referee_report_payouts p
    set status='processing',attempt_count=p.attempt_count+1,last_attempt_at=now(),failure_reason=null
    from candidates c where p.id=c.id
    returning p.id,p.referee_user_id,c.stripe_account_id,p.referee_net_pence,p.report_id,p.attempt_count
  )
  select claimed.id,claimed.referee_user_id,claimed.stripe_account_id,
    claimed.referee_net_pence,claimed.report_id,claimed.attempt_count from claimed;
end;
$$;
revoke all on function public.claim_referee_report_payout_transfers(integer) from public,anon,authenticated;
grant execute on function public.claim_referee_report_payout_transfers(integer) to service_role;

create or replace function public.claim_referee_milestone_reward_transfers(p_limit integer default 25)
returns table(payout_id uuid,referee_user_id uuid,stripe_account_id text,amount_pence integer,milestone_number integer,attempt_number integer)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.role()<>'service_role' then raise exception 'Service role required'; end if;
  return query
  with candidates as (
    select m.id,m.referee_user_id,a.stripe_account_id,m.amount_pence,m.milestone_number
    from public.referee_milestone_rewards m
    join public.referee_memberships membership on membership.user_id=m.referee_user_id and membership.status='active'
    join public.referee_stripe_connect_accounts a on a.referee_user_id=m.referee_user_id
      and a.details_submitted and a.payouts_enabled
    where m.status in ('pending_connect','processing')
      and (m.status='pending_connect' or m.last_attempt_at<now()-interval '10 minutes')
    order by m.created_at
    for update of m skip locked
    limit greatest(1,least(coalesce(p_limit,25),100))
  ), claimed as (
    update public.referee_milestone_rewards m
    set status='processing',attempt_count=m.attempt_count+1,last_attempt_at=now(),failure_reason=null
    from candidates c where m.id=c.id
    returning m.id,m.referee_user_id,c.stripe_account_id,m.amount_pence,m.milestone_number,m.attempt_count
  )
  select claimed.id,claimed.referee_user_id,claimed.stripe_account_id,
    claimed.amount_pence,claimed.milestone_number,claimed.attempt_count from claimed;
end;
$$;
revoke all on function public.claim_referee_milestone_reward_transfers(integer) from public,anon,authenticated;
grant execute on function public.claim_referee_milestone_reward_transfers(integer) to service_role;

create or replace function public.record_referee_report_transfer_result(
  p_payout_id uuid,p_success boolean,p_stripe_transfer_id text,p_failure_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_payout public.referee_report_payouts;
begin
  if auth.role()<>'service_role' then raise exception 'Service role required'; end if;
  select * into v_payout from public.referee_report_payouts where id=p_payout_id for update;
  if not found then raise exception 'Referee report payout not found'; end if;
  if v_payout.status='transferred' and v_payout.stripe_transfer_id=p_stripe_transfer_id then return; end if;
  if v_payout.status<>'processing' then raise exception 'Payout is not currently processing'; end if;
  if p_success and (p_stripe_transfer_id is null or p_stripe_transfer_id !~ '^tr_[A-Za-z0-9]+$') then
    raise exception 'A valid Stripe Transfer ID is required';
  end if;
  update public.referee_report_payouts
  set status=case when p_success then 'transferred' else 'failed' end,
    stripe_transfer_id=case when p_success then p_stripe_transfer_id else null end,
    failure_reason=case when p_success then null else left(coalesce(p_failure_reason,'Stripe transfer failed'),500) end,
    transferred_at=case when p_success then now() else null end
  where id=p_payout_id returning * into v_payout;
  insert into public.referee_payout_transfer_attempts(
    payout_kind,payout_id,referee_user_id,attempt_number,amount_pence,stripe_transfer_id,
    idempotency_key,status,failure_reason
  ) values('report',v_payout.id,v_payout.referee_user_id,v_payout.attempt_count,
    v_payout.referee_net_pence,p_stripe_transfer_id,'openplay-referee-report-'||v_payout.id::text,
    case when p_success then 'transferred' else 'failed' end,
    case when p_success then null else left(coalesce(p_failure_reason,'Stripe transfer failed'),500) end);
end;
$$;
revoke all on function public.record_referee_report_transfer_result(uuid,boolean,text,text) from public,anon,authenticated;
grant execute on function public.record_referee_report_transfer_result(uuid,boolean,text,text) to service_role;

create or replace function public.record_referee_milestone_transfer_result(
  p_payout_id uuid,p_success boolean,p_stripe_transfer_id text,p_failure_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_payout public.referee_milestone_rewards;
begin
  if auth.role()<>'service_role' then raise exception 'Service role required'; end if;
  select * into v_payout from public.referee_milestone_rewards where id=p_payout_id for update;
  if not found then raise exception 'Referee milestone reward not found'; end if;
  if v_payout.status='transferred' and v_payout.stripe_transfer_id=p_stripe_transfer_id then return; end if;
  if v_payout.status<>'processing' then raise exception 'Milestone reward is not currently processing'; end if;
  if p_success and (p_stripe_transfer_id is null or p_stripe_transfer_id !~ '^tr_[A-Za-z0-9]+$') then
    raise exception 'A valid Stripe Transfer ID is required';
  end if;
  update public.referee_milestone_rewards
  set status=case when p_success then 'transferred' else 'failed' end,
    stripe_transfer_id=case when p_success then p_stripe_transfer_id else null end,
    failure_reason=case when p_success then null else left(coalesce(p_failure_reason,'Stripe transfer failed'),500) end,
    transferred_at=case when p_success then now() else null end
  where id=p_payout_id returning * into v_payout;
  insert into public.referee_payout_transfer_attempts(
    payout_kind,payout_id,referee_user_id,attempt_number,amount_pence,stripe_transfer_id,
    idempotency_key,status,failure_reason
  ) values('milestone',v_payout.id,v_payout.referee_user_id,v_payout.attempt_count,
    v_payout.amount_pence,p_stripe_transfer_id,'openplay-referee-milestone-'||v_payout.id::text,
    case when p_success then 'transferred' else 'failed' end,
    case when p_success then null else left(coalesce(p_failure_reason,'Stripe transfer failed'),500) end);
end;
$$;
revoke all on function public.record_referee_milestone_transfer_result(uuid,boolean,text,text) from public,anon,authenticated;
grant execute on function public.record_referee_milestone_transfer_result(uuid,boolean,text,text) to service_role;

create or replace function public.admin_retry_referee_payout(
  p_payout_kind text,p_payout_id uuid,p_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_actor uuid:=auth.uid(); v_user_id uuid; v_status text;
begin
  if v_actor is null or not public.has_platform_role() or not public.has_finance_access() then
    raise exception 'Finance administrator permission required';
  end if;
  if p_payout_kind not in ('report','milestone') or length(btrim(coalesce(p_reason,''))) not between 5 and 500 then
    raise exception 'A valid payout type and retry reason are required';
  end if;
  if p_payout_kind='report' then
    select referee_user_id,status into v_user_id,v_status from public.referee_report_payouts where id=p_payout_id for update;
  else
    select referee_user_id,status into v_user_id,v_status from public.referee_milestone_rewards where id=p_payout_id for update;
  end if;
  if v_user_id is null then raise exception 'Payout not found'; end if;
  if v_status<>'failed' then raise exception 'Only failed payouts can be retried'; end if;
  if not exists(select 1 from public.referee_stripe_connect_accounts a
    join public.referee_memberships m on m.user_id=a.referee_user_id
    where a.referee_user_id=v_user_id and a.details_submitted and a.payouts_enabled and m.status='active') then
    raise exception 'Referee must complete Stripe onboarding before retrying this payout';
  end if;
  if p_payout_kind='report' then
    update public.referee_report_payouts set status='pending_connect',failure_reason=null,last_attempt_at=null where id=p_payout_id;
  else
    update public.referee_milestone_rewards set status='pending_connect',failure_reason=null,last_attempt_at=null where id=p_payout_id;
  end if;
  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,before_data,after_data)
  values(v_actor,'referee.payout.retry_requested','referee_payout',p_payout_id::text,btrim(p_reason),
    jsonb_build_object('status','failed'),jsonb_build_object('status','pending_connect','payout_kind',p_payout_kind));
end;
$$;
revoke all on function public.admin_retry_referee_payout(text,uuid,text) from public,anon;
grant execute on function public.admin_retry_referee_payout(text,uuid,text) to authenticated;
