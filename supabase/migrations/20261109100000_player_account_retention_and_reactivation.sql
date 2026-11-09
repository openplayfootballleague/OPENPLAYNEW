-- Player account inactivity, closure, restricted archive and secure reactivation.
-- Final erasure is deliberately queued, not hard-deleted, until historical player
-- identity references are separated from live Auth/profile identities.

alter table public.profiles
  add column account_retention_status text not null default 'active'
    check (account_retention_status in ('active','closed','erasure_due')),
  add column last_sign_in_at timestamptz not null default now(),
  add column account_closed_at timestamptz,
  add column archive_expires_at timestamptz,
  add column reactivation_token_hash text,
  add column reactivation_token_expires_at timestamptz,
  add column reactivation_requested_at timestamptz,
  add column retention_hold boolean not null default false,
  add column retention_hold_reason text,
  add constraint profiles_account_retention_state_check check (
    (account_retention_status = 'active'
      and account_closed_at is null
      and archive_expires_at is null
      and reactivation_token_hash is null
      and reactivation_token_expires_at is null)
    or
    (account_retention_status in ('closed','erasure_due')
      and account_closed_at is not null
      and archive_expires_at is not null)
  ),
  add constraint profiles_reactivation_token_pair_check check (
    (reactivation_token_hash is null and reactivation_token_expires_at is null)
    or (reactivation_token_hash is not null and reactivation_token_expires_at is not null)
  );

update public.profiles p
set last_sign_in_at = coalesce(u.last_sign_in_at, u.created_at, p.created_at)
from auth.users u
where u.id = p.id;

create index profiles_account_retention_due_idx
  on public.profiles(account_retention_status, last_sign_in_at, archive_expires_at);

create or replace function public.track_player_account_sign_in()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.last_sign_in_at is distinct from old.last_sign_in_at
     and new.last_sign_in_at is not null then
    update public.profiles
    set last_sign_in_at = new.last_sign_in_at,
        account_retention_status = 'active',
        account_closed_at = null,
        archive_expires_at = null,
        reactivation_token_hash = null,
        reactivation_token_expires_at = null,
        reactivation_requested_at = null,
        updated_at = now()
    where id = new.id;
  end if;
  return new;
end;
$$;

revoke all on function public.track_player_account_sign_in() from public, anon, authenticated;

drop trigger if exists auth_users_track_player_account_sign_in on auth.users;
create trigger auth_users_track_player_account_sign_in
after update of last_sign_in_at on auth.users
for each row execute function public.track_player_account_sign_in();

create or replace function public.get_my_player_account_retention_status()
returns table(account_retention_status text, account_closed_at timestamptz, archive_expires_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select p.account_retention_status, p.account_closed_at, p.archive_expires_at
  from public.profiles p
  where p.id = auth.uid()
$$;
revoke all on function public.get_my_player_account_retention_status() from public, anon;
grant execute on function public.get_my_player_account_retention_status() to authenticated;

-- Service-role worker discovery. It only returns registered players who have
-- no active/pending membership and no successful sign-in for 12 months.
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
    );

  if not found then return false; end if;

  insert into public.audit_log(actor_user_id, action, entity_type, entity_id, reason, after_data)
  values (
    null,
    'player.account.closed_for_inactivity',
    'player_account',
    p_user_id::text,
    'No successful sign-in for 12 months and no active or pending team membership',
    jsonb_build_object('closed_at', v_closed_at, 'archive_expires_at', v_closed_at + interval '12 months')
  );
  return true;
end;
$$;

-- Public request endpoint is invoked only by the server-side Edge Function.
-- The function returns no row for unknown, active, expired or rate-limited accounts;
-- the HTTP layer always returns the same public response to prevent enumeration.
create or replace function public.request_player_account_reactivation(
  p_email text,
  p_token_hash text
)
returns table(user_id uuid, email text)
language plpgsql
security definer
set search_path = ''
as $$
declare v_user_id uuid; v_email text; v_requested_at timestamptz := now();
begin
  if p_email is null or length(trim(p_email)) > 254
     or p_token_hash is null or p_token_hash !~ '^[0-9a-f]{64}$' then
    return;
  end if;

  select p.id, u.email into v_user_id, v_email
  from public.profiles p
  join auth.users u on u.id = p.id
  where lower(u.email) = lower(trim(p_email))
    and u.email_confirmed_at is not null
    and p.account_retention_status = 'closed'
    and p.archive_expires_at > v_requested_at
    and not p.retention_hold
    and (p.reactivation_requested_at is null
      or p.reactivation_requested_at <= v_requested_at - interval '60 seconds')
  for update of p;

  if v_user_id is null then return; end if;

  update public.profiles
  set reactivation_token_hash = p_token_hash,
      reactivation_token_expires_at = v_requested_at + interval '24 hours',
      reactivation_requested_at = v_requested_at,
      updated_at = v_requested_at
  where id = v_user_id;

  return query select v_user_id, v_email;
end;
$$;

create or replace function public.get_player_account_reactivation_target(p_token_hash text)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p.id
  from public.profiles p
  where p.account_retention_status = 'closed'
    and p.archive_expires_at > now()
    and p.reactivation_token_hash = p_token_hash
    and p.reactivation_token_expires_at > now()
    and p_token_hash ~ '^[0-9a-f]{64}$'
  limit 1
$$;

create or replace function public.complete_player_account_reactivation(
  p_user_id uuid,
  p_token_hash text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare v_now timestamptz := now();
begin
  update public.profiles p
  set account_retention_status = 'active',
      last_sign_in_at = v_now,
      account_closed_at = null,
      archive_expires_at = null,
      reactivation_token_hash = null,
      reactivation_token_expires_at = null,
      reactivation_requested_at = null,
      updated_at = v_now
  where p.id = p_user_id
    and p.account_retention_status = 'closed'
    and p.archive_expires_at > v_now
    and p.reactivation_token_hash = p_token_hash
    and p.reactivation_token_expires_at > v_now
    and p_token_hash ~ '^[0-9a-f]{64}$';

  if not found then return false; end if;

  -- A returning player comes back unattached. Never revive old membership rows.
  update public.team_memberships tm
  set status = case when tm.status = 'active' then 'left'::public.membership_status
                    when tm.status = 'pending' then 'rejected'::public.membership_status
                    else tm.status end,
      is_captain = false,
      left_at = case when tm.status in ('active','pending') then v_now else tm.left_at end,
      updated_at = v_now
  where tm.user_id = p_user_id and tm.status in ('active','pending');

  insert into public.audit_log(actor_user_id, action, entity_type, entity_id, reason, after_data)
  values (
    null,
    'player.account.reactivated',
    'player_account',
    p_user_id::text,
    'Player reactivated through a verified single-use email link; no team membership or captaincy restored',
    jsonb_build_object('reactivated_at', v_now, 'returned_without_team', true)
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
  where p.account_retention_status = 'closed'
    and p.archive_expires_at <= now()
    and not p.retention_hold
    and not exists (
      select 1 from public.team_memberships tm
      where tm.user_id = p.id and tm.status in ('active','pending')
    )
    and not exists (
      select 1 from public.user_roles ur where ur.user_id = p.id
    )
  order by p.archive_expires_at
  limit 200
$$;

-- Queue for controlled erasure/anonymisation. Do not hard-delete the Auth user:
-- historic goals and team sheets currently retain restrictive profile foreign keys.
create or replace function public.admin_mark_player_account_erasure_due(p_user_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.profiles p
  set account_retention_status = 'erasure_due',
      reactivation_token_hash = null,
      reactivation_token_expires_at = null,
      reactivation_requested_at = null,
      updated_at = now()
  where p.id = p_user_id
    and p.account_retention_status = 'closed'
    and p.archive_expires_at <= now()
    and not p.retention_hold
    and not exists (
      select 1 from public.team_memberships tm
      where tm.user_id = p.id and tm.status in ('active','pending')
    )
    and not exists (
      select 1 from public.user_roles ur where ur.user_id = p.id
    );

  if not found then return false; end if;

  insert into public.audit_log(actor_user_id, action, entity_type, entity_id, reason, after_data)
  values (
    null,
    'player.account.erasure_due',
    'player_account',
    p_user_id::text,
    '12-month restricted archive expired; awaiting safe historical identity anonymisation',
    jsonb_build_object('marked_at', now())
  );
  return true;
end;
$$;

revoke all on function public.admin_list_inactive_player_accounts() from public, anon, authenticated;
grant execute on function public.admin_list_inactive_player_accounts() to service_role;
revoke all on function public.admin_close_inactive_player_account(uuid) from public, anon, authenticated;
grant execute on function public.admin_close_inactive_player_account(uuid) to service_role;
revoke all on function public.request_player_account_reactivation(text,text) from public, anon, authenticated;
grant execute on function public.request_player_account_reactivation(text,text) to service_role;
revoke all on function public.get_player_account_reactivation_target(text) from public, anon, authenticated;
grant execute on function public.get_player_account_reactivation_target(text) to service_role;
revoke all on function public.complete_player_account_reactivation(uuid,text) from public, anon, authenticated;
grant execute on function public.complete_player_account_reactivation(uuid,text) to service_role;
revoke all on function public.admin_list_expired_player_account_archives() from public, anon, authenticated;
grant execute on function public.admin_list_expired_player_account_archives() to service_role;
revoke all on function public.admin_mark_player_account_erasure_due(uuid) from public, anon, authenticated;
grant execute on function public.admin_mark_player_account_erasure_due(uuid) to service_role;

comment on column public.profiles.account_retention_status is
  'Player account retention lifecycle: active, closed for a 12-month restricted archive, or erasure_due after archive expiry.';
comment on column public.profiles.retention_hold is
  'Prevents automated account closure/erasure while a documented legal, safeguarding or financial hold applies.';
