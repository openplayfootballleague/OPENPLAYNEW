-- Advance inactivity warnings before account closure.
-- Warning stages are sent once per inactivity anchor. A delayed first run catches up
-- missed stages, and the final closure is held for at least seven days after the
-- 7-day notice is successfully recorded.

create table public.player_account_inactivity_warnings (
  user_id uuid not null references public.profiles(id) on delete cascade,
  inactivity_started_at timestamptz not null,
  warning_days integer not null check (warning_days in (90, 30, 7)),
  status text not null default 'pending' check (status in ('pending', 'sent')),
  claimed_at timestamptz not null default now(),
  sent_at timestamptz,
  created_at timestamptz not null default now(),
  primary key (user_id, inactivity_started_at, warning_days),
  constraint player_account_warning_sent_state_check check (
    (status = 'pending' and sent_at is null)
    or (status = 'sent' and sent_at is not null)
  )
);

alter table public.player_account_inactivity_warnings enable row level security;
revoke all on public.player_account_inactivity_warnings from public, anon, authenticated;
grant all on public.player_account_inactivity_warnings to service_role;

comment on table public.player_account_inactivity_warnings is
  'Service-role-only idempotency ledger for the 90/30/7-day player inactivity warning emails.';

create or replace function public.admin_claim_player_account_inactivity_warnings()
returns table(
  user_id uuid,
  email text,
  warning_days integer,
  inactivity_started_at timestamptz,
  closure_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'Service role required';
  end if;

  return query
  with eligible as materialized (
    select p.id as user_id,
           u.email::text as email,
           p.last_sign_in_at as inactivity_started_at,
           p.last_sign_in_at + interval '12 months' as closure_at,
           stages.warning_days
    from public.profiles p
    join auth.users u on u.id = p.id
    join public.players pl on pl.user_id = p.id
    cross join (values (90), (30), (7)) as stages(warning_days)
    where p.account_retention_status = 'active'
      and p.last_sign_in_at + interval '12 months'
          - make_interval(days => stages.warning_days) <= now()
      and u.email is not null
      and u.email_confirmed_at is not null
      and pl.registration_status = 'registered'
      and pl.is_banned = false
      and not p.retention_hold
      and not exists (
        select 1 from public.team_memberships tm
        where tm.user_id = p.id and tm.status in ('active','pending')
      )
      and not exists (
        select 1 from public.user_roles ur where ur.user_id = p.id
      )
      and not exists (
        select 1 from public.location_admin_assignments la where la.user_id = p.id
      )
      and not exists (
        select 1 from public.payment_records pay
        where pay.player_user_id = p.id
          and pay.status in ('pending','processing','partially_refunded')
      )
      and not exists (
        select 1 from public.player_transfer_requests tr
        where tr.user_id = p.id and tr.status = 'pending'
      )
    order by p.last_sign_in_at, stages.warning_days desc
    limit 600
    for update of p skip locked
  ),
  claimed as (
    insert into public.player_account_inactivity_warnings as existing (
      user_id, inactivity_started_at, warning_days, status, claimed_at
    )
    select e.user_id, e.inactivity_started_at, e.warning_days, 'pending', now()
    from eligible e
    on conflict (user_id, inactivity_started_at, warning_days)
    do update set claimed_at = now()
      where existing.status = 'pending'
        and existing.claimed_at <= now() - interval '30 minutes'
    returning existing.user_id, existing.inactivity_started_at, existing.warning_days
  )
  select c.user_id, e.email, c.warning_days, c.inactivity_started_at, e.closure_at
  from claimed c
  join eligible e
    on e.user_id = c.user_id
   and e.inactivity_started_at = c.inactivity_started_at
   and e.warning_days = c.warning_days;
end;
$$;

create or replace function public.admin_finish_player_account_inactivity_warning(
  p_user_id uuid,
  p_inactivity_started_at timestamptz,
  p_warning_days integer,
  p_delivered boolean
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'Service role required';
  end if;
  if p_warning_days not in (90, 30, 7) or p_delivered is null then
    raise exception 'Invalid warning completion request';
  end if;

  update public.player_account_inactivity_warnings
  set status = case when p_delivered then 'sent' else 'pending' end,
      sent_at = case when p_delivered then now() else null end,
      claimed_at = case when p_delivered then claimed_at else now() - interval '31 minutes' end
  where user_id = p_user_id
    and inactivity_started_at = p_inactivity_started_at
    and warning_days = p_warning_days
    and status = 'pending';

  return found;
end;
$$;

revoke all on function public.admin_claim_player_account_inactivity_warnings() from public, anon, authenticated;
grant execute on function public.admin_claim_player_account_inactivity_warnings() to service_role;
revoke all on function public.admin_finish_player_account_inactivity_warning(uuid, timestamptz, integer, boolean) from public, anon, authenticated;
grant execute on function public.admin_finish_player_account_inactivity_warning(uuid, timestamptz, integer, boolean) to service_role;

create or replace function public.require_player_account_inactivity_warnings_before_closure()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.account_retention_status = 'active'
     and new.account_retention_status = 'closed'
     and not (
       exists (
         select 1 from public.player_account_inactivity_warnings w
         where w.user_id = old.id
           and w.inactivity_started_at = old.last_sign_in_at
           and w.warning_days = 90 and w.status = 'sent'
       )
       and exists (
         select 1 from public.player_account_inactivity_warnings w
         where w.user_id = old.id
           and w.inactivity_started_at = old.last_sign_in_at
           and w.warning_days = 30 and w.status = 'sent'
       )
       and exists (
         select 1 from public.player_account_inactivity_warnings w
         where w.user_id = old.id
           and w.inactivity_started_at = old.last_sign_in_at
           and w.warning_days = 7 and w.status = 'sent'
           and w.sent_at <= now() - interval '7 days'
       )
     ) then
    raise exception 'Player account closure requires delivered 90, 30 and 7-day warnings and a seven-day final grace period';
  end if;
  return new;
end;
$$;

revoke all on function public.require_player_account_inactivity_warnings_before_closure() from public, anon, authenticated;

drop trigger if exists profiles_require_inactivity_warnings_before_closure on public.profiles;
create trigger profiles_require_inactivity_warnings_before_closure
before update of account_retention_status on public.profiles
for each row execute function public.require_player_account_inactivity_warnings_before_closure();

comment on function public.admin_claim_player_account_inactivity_warnings() is
  'Claims unsent 90/30/7-day inactivity warnings for eligible registered players. Pending claims expire after 30 minutes for safe retry; successful stages are unique per inactivity anchor.';
comment on function public.require_player_account_inactivity_warnings_before_closure() is
  'Fail-closed guard: account closure requires all three delivered warning stages and at least seven days since the 7-day warning.';
