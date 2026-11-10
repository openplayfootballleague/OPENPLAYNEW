-- Keep retention exclusions consistent through closure, archive expiry and erasure.
-- Retry accounts already marked erasure_due after transient storage/Auth failures.
-- This migration is forward-only; no previously recorded migration source is edited.

create or replace function public.admin_list_inactive_player_accounts()
returns table(user_id uuid, email text, last_sign_in_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, u.email, p.last_sign_in_at
  from public.profiles p
  join auth.users u on u.id = p.id
  join public.players pl on pl.user_id = p.id
  where p.account_retention_status = 'active'
    and p.last_sign_in_at <= now() - interval '12 months'
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
  order by p.last_sign_in_at
  limit 200
$$;

create or replace function public.admin_close_inactive_player_account(p_user_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare v_closed_at timestamptz := now();
begin
  update public.profiles p
  set account_retention_status = 'closed',
      account_closed_at = v_closed_at,
      archive_expires_at = v_closed_at + interval '12 months',
      reactivation_token_hash = null,
      reactivation_token_expires_at = null,
      reactivation_requested_at = null,
      updated_at = v_closed_at
  where p.id = p_user_id
    and p.account_retention_status = 'active'
    and p.last_sign_in_at <= v_closed_at - interval '12 months'
    and not p.retention_hold
    and exists (
      select 1 from public.players pl
      where pl.user_id = p.id
        and pl.registration_status = 'registered'
        and pl.is_banned = false
    )
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
    );

  if not found then return false; end if;

  insert into public.audit_log(actor_user_id, action, entity_type, entity_id, reason, after_data)
  values (
    null,
    'player.account.closed_for_inactivity',
    'player_account',
    p_user_id::text,
    'No successful sign-in for 12 months, no active or pending team membership, and no unresolved administrative or financial obligation',
    jsonb_build_object('closed_at', v_closed_at, 'archive_expires_at', v_closed_at + interval '12 months')
  );
  return true;
end;
$$;

create or replace function public.admin_list_expired_player_account_archives()
returns table(user_id uuid, email text, archive_expires_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, u.email, p.archive_expires_at
  from public.profiles p
  join auth.users u on u.id = p.id
  where p.account_retention_status in ('closed','erasure_due')
    and p.archive_expires_at <= now()
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
  order by p.archive_expires_at
  limit 200
$$;

create or replace function public.admin_mark_player_account_erasure_due(p_user_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_previous_status text;
  v_marked_at timestamptz := now();
begin
  select p.account_retention_status
    into v_previous_status
  from public.profiles p
  where p.id = p_user_id
  for update;

  if not found or v_previous_status not in ('closed','erasure_due') then
    return false;
  end if;

  update public.profiles p
  set account_retention_status = 'erasure_due',
      reactivation_token_hash = null,
      reactivation_token_expires_at = null,
      reactivation_requested_at = null,
      updated_at = v_marked_at
  where p.id = p_user_id
    and p.account_retention_status in ('closed','erasure_due')
    and p.archive_expires_at <= v_marked_at
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
    );

  if not found then return false; end if;

  if v_previous_status = 'closed' then
    insert into public.audit_log(actor_user_id, action, entity_type, entity_id, reason, after_data)
    values (
      null,
      'player.account.erasure_due',
      'player_account',
      p_user_id::text,
      '12-month restricted archive expired; account entered the retryable safe-erasure queue',
      jsonb_build_object('marked_at', v_marked_at)
    );
  end if;

  return true;
end;
$$;

comment on function public.admin_list_expired_player_account_archives() is
  'Returns closed archives and already-erasure_due accounts so transient storage/Auth deletion failures are retried.';
comment on function public.admin_mark_player_account_erasure_due(uuid) is
  'Idempotently confirms an expired closed archive remains eligible for safe erasure; repeated calls keep retryable erasure_due accounts in the worker queue.';
