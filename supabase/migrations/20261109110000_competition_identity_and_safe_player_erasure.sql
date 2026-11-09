-- Separate permanent competition history from live player accounts.
-- The account may be erased after the restricted archive without deleting results,
-- goals, appearances or competition statistics.

create table public.competition_player_identities (
  id uuid primary key default gen_random_uuid(),
  display_name text not null,
  counts_for_statistics boolean not null default true,
  anonymised_at timestamptz,
  created_at timestamptz not null default now(),
  constraint competition_player_identity_anonymised_label check (
    anonymised_at is null or display_name = 'Former player'
  )
);
alter table public.competition_player_identities enable row level security;
revoke all on public.competition_player_identities from public, anon, authenticated;

alter table public.players add column competition_player_id uuid;

create temporary table openplay_player_identity_map on commit drop as
select p.user_id, gen_random_uuid() as competition_player_id
from public.players p;

insert into public.competition_player_identities(id, display_name, counts_for_statistics)
select m.competition_player_id, p.full_name,
       (p.is_genuine is true and p.registration_status = 'registered' and p.is_banned is false)
from public.players p
join openplay_player_identity_map m on m.user_id = p.user_id;

update public.players p
set competition_player_id = m.competition_player_id
from openplay_player_identity_map m
where m.user_id = p.user_id;

alter table public.players
  alter column competition_player_id set not null,
  add constraint players_competition_player_id_key unique (competition_player_id),
  add constraint players_competition_player_id_fkey
    foreign key (competition_player_id)
    references public.competition_player_identities(id) on delete restrict;

alter table public.fixture_team_sheet_players
  add column competition_player_id uuid;

update public.fixture_team_sheet_players tsp
set competition_player_id = p.competition_player_id
from public.players p
where p.user_id = tsp.user_id;

do $$
begin
  if exists (select 1 from public.fixture_team_sheet_players where competition_player_id is null) then
    raise exception 'Cannot create permanent competition identities: a historical team-sheet player has no registered player identity';
  end if;
end;
$$;

alter table public.fixture_team_sheet_players
  alter column competition_player_id set not null,
  add constraint fixture_team_sheet_players_competition_player_id_fkey
    foreign key (competition_player_id)
    references public.competition_player_identities(id) on delete restrict,
  add constraint fixture_team_sheet_players_sheet_competition_player_unique
    unique (team_sheet_id, competition_player_id);

create index fixture_team_sheet_players_competition_identity_idx
  on public.fixture_team_sheet_players(competition_player_id, team_sheet_id)
  where did_appear is true;

alter table public.fixture_goal_records
  add column competition_player_id uuid;

update public.fixture_goal_records g
set competition_player_id = p.competition_player_id
from public.players p
where p.user_id = g.scorer_user_id;

do $$
begin
  if exists (select 1 from public.fixture_goal_records where competition_player_id is null) then
    raise exception 'Cannot create permanent competition identities: a historical goalscorer has no registered player identity';
  end if;
end;
$$;

alter table public.fixture_goal_records
  alter column competition_player_id set not null,
  add constraint fixture_goal_records_competition_player_id_fkey
    foreign key (competition_player_id)
    references public.competition_player_identities(id) on delete restrict;

create index fixture_goal_records_competition_identity_active_idx
  on public.fixture_goal_records(competition_player_id)
  where voided_at is null;

-- Convert personal/account references in permanent competition and audit records
-- to nullable references. The independent competition_player_id remains required.
alter table public.fixture_team_sheet_players alter column user_id drop not null;
alter table public.fixture_goal_records alter column scorer_user_id drop not null;
alter table public.fixture_goal_records alter column created_by drop not null;
alter table public.fixture_team_sheets alter column submitted_by drop not null;
alter table public.player_transfer_requests alter column user_id drop not null;
alter table public.player_transfer_requests alter column source_membership_id drop not null;
alter table public.finance_entries alter column created_by drop not null;
alter table public.gallery_items alter column uploaded_by drop not null;
alter table public.location_admin_assignments alter column assigned_by drop not null;

do $$
declare
  r record;
  v_constraint text;
begin
  for r in
    select * from (values
      ('fixture_team_sheet_players','user_id','public.profiles','fixture_team_sheet_players_user_id_set_null_fkey'),
      ('fixture_goal_records','scorer_user_id','public.profiles','fixture_goal_records_scorer_user_id_set_null_fkey'),
      ('fixture_team_sheets','submitted_by','auth.users','fixture_team_sheets_submitted_by_set_null_fkey'),
      ('fixture_goal_records','created_by','auth.users','fixture_goal_records_created_by_set_null_fkey'),
      ('fixture_goal_records','voided_by','auth.users','fixture_goal_records_voided_by_set_null_fkey'),
      ('player_transfer_requests','user_id','public.profiles','player_transfer_requests_user_id_set_null_fkey'),
      ('player_transfer_requests','source_membership_id','public.team_memberships','player_transfer_requests_source_membership_set_null_fkey'),
      ('player_transfer_requests','resolved_by','auth.users','player_transfer_requests_resolved_by_set_null_fkey'),
      ('payment_records','player_user_id','auth.users','payment_records_player_user_set_null_fkey'),
      ('finance_entries','created_by','auth.users','finance_entries_created_by_set_null_fkey'),
      ('gallery_items','uploaded_by','auth.users','gallery_items_uploaded_by_set_null_fkey'),
      ('location_admin_assignments','assigned_by','auth.users','location_admin_assignments_assigned_by_set_null_fkey'),
      ('notification_events','held_by','auth.users','notification_events_held_by_set_null_fkey')
    ) as x(table_name,column_name,target_table,constraint_name)
  loop
    for v_constraint in
      select c.conname
      from pg_catalog.pg_constraint c
      join pg_catalog.pg_attribute a
        on a.attrelid = c.conrelid and a.attnum = any(c.conkey)
      where c.contype = 'f'
        and c.conrelid = format('public.%I', r.table_name)::regclass
        and a.attname = r.column_name
    loop
      execute format('alter table public.%I drop constraint %I', r.table_name, v_constraint);
    end loop;

    execute format(
      'alter table public.%I add constraint %I foreign key (%I) references %s(id) on delete set null',
      r.table_name, r.constraint_name, r.column_name, r.target_table::regclass
    );
  end loop;
end;
$$;

create or replace function public.ensure_player_competition_identity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.competition_player_id is null then
    insert into public.competition_player_identities(display_name, counts_for_statistics)
    values (
      new.full_name,
      new.is_genuine is true and new.registration_status = 'registered' and new.is_banned is false
    )
    returning id into new.competition_player_id;
  elsif not exists (
    select 1 from public.competition_player_identities cpi
    where cpi.id = new.competition_player_id
  ) then
    raise exception 'Competition player identity does not exist';
  end if;
  return new;
end;
$$;
revoke all on function public.ensure_player_competition_identity() from public, anon, authenticated;
drop trigger if exists players_ensure_competition_identity on public.players;
create trigger players_ensure_competition_identity
before insert on public.players
for each row execute function public.ensure_player_competition_identity();

create or replace function public.sync_player_competition_statistics_eligibility()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.competition_player_identities
  set counts_for_statistics =
    (new.is_genuine is true and new.registration_status = 'registered' and new.is_banned is false),
    display_name = case when anonymised_at is null then new.full_name else display_name end
  where id = new.competition_player_id
    and anonymised_at is null;
  return new;
end;
$$;
revoke all on function public.sync_player_competition_statistics_eligibility() from public, anon, authenticated;
drop trigger if exists players_sync_competition_statistics_eligibility on public.players;
create trigger players_sync_competition_statistics_eligibility
after update of is_genuine, registration_status, is_banned, full_name on public.players
for each row execute function public.sync_player_competition_statistics_eligibility();

create or replace function public.prevent_player_name_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.full_name is distinct from old.full_name
     and not (
       new.full_name = 'Former player'
       and exists (
         select 1 from public.profiles p
         where p.id = old.user_id
           and p.account_retention_status = 'erasure_due'
       )
     ) then
    raise exception 'Registered player name cannot be changed';
  end if;
  return new;
end;
$$;

create or replace function public.set_fixture_team_sheet_player_competition_identity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare v_identity uuid;
begin
  if new.user_id is not null then
    select p.competition_player_id into v_identity
    from public.players p where p.user_id = new.user_id;
    if v_identity is null then
      raise exception 'A team-sheet player must have a registered competition identity';
    end if;
    if new.competition_player_id is not null and new.competition_player_id <> v_identity then
      raise exception 'Team-sheet player identity does not match the registered player';
    end if;
    new.competition_player_id := v_identity;
  elsif new.competition_player_id is null then
    raise exception 'A historical team-sheet row requires a competition identity';
  end if;
  return new;
end;
$$;
revoke all on function public.set_fixture_team_sheet_player_competition_identity() from public, anon, authenticated;
drop trigger if exists fixture_team_sheet_player_competition_identity on public.fixture_team_sheet_players;
create trigger fixture_team_sheet_player_competition_identity
before insert or update of user_id, competition_player_id
on public.fixture_team_sheet_players
for each row execute function public.set_fixture_team_sheet_player_competition_identity();

create or replace function public.set_fixture_goal_competition_identity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare v_identity uuid;
begin
  if new.scorer_user_id is not null then
    select p.competition_player_id into v_identity
    from public.players p where p.user_id = new.scorer_user_id;
    if v_identity is null then
      raise exception 'A goalscorer must have a registered competition identity';
    end if;
    if new.competition_player_id is not null and new.competition_player_id <> v_identity then
      raise exception 'Goalscorer identity does not match the registered player';
    end if;
    new.competition_player_id := v_identity;
  elsif new.competition_player_id is null then
    raise exception 'A historical goal requires a competition identity';
  end if;
  return new;
end;
$$;
revoke all on function public.set_fixture_goal_competition_identity() from public, anon, authenticated;
drop trigger if exists fixture_goal_competition_identity on public.fixture_goal_records;
create trigger fixture_goal_competition_identity
before insert or update of scorer_user_id, competition_player_id
on public.fixture_goal_records
for each row execute function public.set_fixture_goal_competition_identity();

-- Serialize membership creation against account closure/erasure. The trigger locks
-- the same profile/player rows used by the retention worker and rejects any new
-- active/pending membership once an account enters the closed/archive lifecycle.
create or replace function public.enforce_player_account_active_for_membership()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_registration_status public.player_registration_status;
  v_is_banned boolean;
  v_account_status text;
begin
  if new.status in ('active','pending') then
    select pl.registration_status,pl.is_banned,pr.account_retention_status
    into v_registration_status,v_is_banned,v_account_status
    from public.players pl
    join public.profiles pr on pr.id=pl.user_id
    where pl.user_id=new.user_id
    for update of pl,pr;

    if not found
       or v_registration_status<>'registered'
       or v_is_banned is true
       or v_account_status<>'active' then
      raise exception 'An active registered player account is required for team membership';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function public.enforce_player_account_active_for_membership() from public,anon,authenticated;
drop trigger if exists team_memberships_require_active_player_account on public.team_memberships;
create trigger team_memberships_require_active_player_account
before insert or update of user_id,status on public.team_memberships
for each row execute function public.enforce_player_account_active_for_membership();

create or replace function public.anonymise_player_audit_json(p_value jsonb, p_user_id uuid)
returns jsonb
language plpgsql
immutable
set search_path = ''
as $$
declare v_result jsonb;
begin
  if p_value is null then return null; end if;
  if jsonb_typeof(p_value) = 'object' then
    select coalesce(jsonb_object_agg(e.key, public.anonymise_player_audit_json(e.value, p_user_id))
      filter (where e.key !~* '^(full_name|player_name|first_name|last_name|display_name|email|phone|date_of_birth|guardian_full_name|guardian_email|emergency_contact_name|emergency_contact_phone|recipient_name|recipient_email|recipient_phone|user_id|player_user_id|player_id|profile_id|scorer_user_id|actor_user_id)$'),
      '{}'::jsonb)
    into v_result
    from jsonb_each(p_value) e;
    return v_result;
  elsif jsonb_typeof(p_value) = 'array' then
    select coalesce(jsonb_agg(public.anonymise_player_audit_json(e.value, p_user_id)), '[]'::jsonb)
    into v_result
    from jsonb_array_elements(p_value) e;
    return v_result;
  elsif jsonb_typeof(p_value) = 'string' and p_value #>> '{}' = p_user_id::text then
    return to_jsonb('anonymised'::text);
  end if;
  return p_value;
end;
$$;
revoke all on function public.anonymise_player_audit_json(jsonb, uuid) from public, anon, authenticated;

-- Location administrators have privileged access even without a global user_roles row.
-- Keep them out of automated player closure and erasure.
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
    and not exists (select 1 from public.user_roles ur where ur.user_id = p.id)
    and not exists (select 1 from public.location_admin_assignments la where la.user_id = p.id)
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
    and not exists (select 1 from public.user_roles ur where ur.user_id = p.id)
    and not exists (select 1 from public.location_admin_assignments la where la.user_id = p.id);

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
    and not exists (select 1 from public.user_roles ur where ur.user_id = p.id)
    and not exists (select 1 from public.location_admin_assignments la where la.user_id = p.id)
  order by p.archive_expires_at
  limit 200
$$;

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
    and not exists (select 1 from public.user_roles ur where ur.user_id = p.id)
    and not exists (select 1 from public.location_admin_assignments la where la.user_id = p.id);

  if found then
    insert into public.audit_log(actor_user_id, action, entity_type, entity_id, reason, after_data)
    values (
      null,
      'player.account.erasure_due',
      'player_account',
      p_user_id::text,
      '12-month restricted archive expired; eligible for permanent account erasure',
      jsonb_build_object('marked_at', now())
    );
    return true;
  end if;

  return exists (
    select 1 from public.profiles p
    where p.id = p_user_id
      and p.account_retention_status = 'erasure_due'
      and p.archive_expires_at <= now()
      and not p.retention_hold
      and not exists (select 1 from public.team_memberships tm where tm.user_id = p.id and tm.status in ('active','pending'))
      and not exists (select 1 from public.user_roles ur where ur.user_id = p.id)
      and not exists (select 1 from public.location_admin_assignments la where la.user_id = p.id)
  );
end;
$$;

create or replace function public.admin_prepare_player_account_erasure(p_user_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_player_id uuid;
  v_competition_player_id uuid;
  v_counts_for_statistics boolean;
  v_now timestamptz := now();
begin
  select pl.id, pl.competition_player_id
  into v_player_id, v_competition_player_id
  from public.profiles p
  join public.players pl on pl.user_id = p.id
  where p.id = p_user_id
    and p.account_retention_status = 'erasure_due'
    and p.archive_expires_at <= v_now
    and not p.retention_hold
    and not exists (select 1 from public.team_memberships tm where tm.user_id = p.id and tm.status in ('active','pending'))
    and not exists (select 1 from public.user_roles ur where ur.user_id = p.id)
    and not exists (select 1 from public.location_admin_assignments la where la.user_id = p.id)
  for update of p, pl;

  if v_player_id is null or v_competition_player_id is null then return false; end if;

  select counts_for_statistics into v_counts_for_statistics
  from public.competition_player_identities
  where id = v_competition_player_id;

  update public.competition_player_identities
  set display_name = 'Former player',
      anonymised_at = coalesce(anonymised_at, v_now)
  where id = v_competition_player_id;

  -- Historical records keep the random competition identity, never the account ID.
  update public.fixture_team_sheet_players
  set user_id = null
  where user_id = p_user_id;

  update public.fixture_goal_records
  set scorer_user_id = case when scorer_user_id = p_user_id then null else scorer_user_id end,
      created_by = case when created_by = p_user_id then null else created_by end,
      voided_by = case when voided_by = p_user_id then null else voided_by end
  where scorer_user_id = p_user_id
     or created_by = p_user_id
     or voided_by = p_user_id;

  update public.fixture_team_sheets
  set submitted_by = null
  where submitted_by = p_user_id;

  update public.payment_records
  set player_user_id = null,
      stripe_customer_id = null
  where player_user_id = p_user_id;

  update public.player_transfer_requests
  set user_id = case when user_id = p_user_id then null else user_id end,
      source_membership_id = case when user_id = p_user_id then null else source_membership_id end,
      resolved_by = case when resolved_by = p_user_id then null else resolved_by end,
      reason = case when user_id = p_user_id then 'Anonymised following account retention' else reason end,
      resolution_reason = case when user_id = p_user_id or resolved_by = p_user_id then null else resolution_reason end
  where user_id = p_user_id
     or resolved_by = p_user_id;

  update public.finance_entries
  set created_by = null
  where created_by = p_user_id;

  update public.gallery_items
  set uploaded_by = null
  where uploaded_by = p_user_id;

  update public.location_admin_assignments
  set assigned_by = null
  where assigned_by = p_user_id;

  update public.notification_events
  set held_by = null
  where held_by = p_user_id;

  delete from public.notification_events
  where user_id = p_user_id;

  update public.notification_events
  set payload = public.anonymise_player_audit_json(
    public.anonymise_player_audit_json(payload, p_user_id), v_player_id
  )
  where payload::text like '%' || p_user_id::text || '%'
     or payload::text like '%' || v_player_id::text || '%';

  update public.player_registration_reviews
  set matched_player_ids = array_remove(matched_player_ids, v_player_id)
  where v_player_id = any(matched_player_ids);

  delete from public.player_guardian_consents
  where player_user_id = p_user_id;

  update public.audit_log
  set actor_user_id = case when actor_user_id = p_user_id then null else actor_user_id end,
      entity_id = case when entity_id in (p_user_id::text, v_player_id::text) then 'anonymised' else entity_id end,
      reason = case
        when actor_user_id = p_user_id
          or entity_id in (p_user_id::text, v_player_id::text)
          or coalesce(before_data::text, '') like '%' || p_user_id::text || '%'
          or coalesce(after_data::text, '') like '%' || p_user_id::text || '%'
        then null else reason end,
      before_data = public.anonymise_player_audit_json(
        public.anonymise_player_audit_json(before_data, p_user_id), v_player_id
      ),
      after_data = public.anonymise_player_audit_json(
        public.anonymise_player_audit_json(after_data, p_user_id), v_player_id
      )
  where actor_user_id = p_user_id
     or entity_id in (p_user_id::text, v_player_id::text)
     or coalesce(before_data::text, '') like '%' || p_user_id::text || '%'
     or coalesce(after_data::text, '') like '%' || p_user_id::text || '%'
     or coalesce(before_data::text, '') like '%' || v_player_id::text || '%'
     or coalesce(after_data::text, '') like '%' || v_player_id::text || '%';

  -- Scrub the remaining live profile and player record before the Auth delete.
  -- If the Auth API is temporarily unavailable, the account stays banned and
  -- contains no contact, DOB, emergency-contact or guardian information.
  update public.profiles
  set first_name = null,
      last_name = null,
      display_name = null,
      date_of_birth = null,
      phone = null,
      emergency_contact_name = null,
      emergency_contact_phone = null,
      preferred_position = null,
      avatar_path = null,
      retention_hold_reason = null,
      reactivation_token_hash = null,
      reactivation_token_expires_at = null,
      reactivation_requested_at = null,
      updated_at = v_now
  where id = p_user_id;

  update public.players
  set full_name = 'Former player',
      phone = '+447700900000',
      email = 'deleted+' || p_user_id::text || '@deleted.openplay.invalid',
      date_of_birth = date '1900-01-01',
      registration_status = 'rejected',
      is_banned = true,
      banned_at = coalesce(banned_at, v_now),
      banned_reason = 'Anonymised after retention expiry',
      guardian_consent_previous_status = null,
      updated_at = v_now
  where id = v_player_id;

  -- The operational player row is no longer eligible, but historical statistics
  -- retain the eligibility snapshot that applied before the account was erased.
  update public.competition_player_identities
  set counts_for_statistics = coalesce(v_counts_for_statistics, false)
  where id = v_competition_player_id;

  insert into public.audit_log(actor_user_id, action, entity_type, entity_id, reason, after_data)
  values (
    null,
    'player.account.anonymised',
    'competition_player_identity',
    v_competition_player_id::text,
    'Personal account data scrubbed after the 12-month restricted archive; competition history retained without an account link',
    jsonb_build_object('competition_player_id', v_competition_player_id, 'anonymised', true, 'anonymised_at', v_now)
  );

  return true;
end;
$$;

revoke all on function public.admin_list_inactive_player_accounts() from public, anon, authenticated;
grant execute on function public.admin_list_inactive_player_accounts() to service_role;
revoke all on function public.admin_close_inactive_player_account(uuid) from public, anon, authenticated;
grant execute on function public.admin_close_inactive_player_account(uuid) to service_role;
revoke all on function public.admin_list_expired_player_account_archives() from public, anon, authenticated;
grant execute on function public.admin_list_expired_player_account_archives() to service_role;
revoke all on function public.admin_mark_player_account_erasure_due(uuid) from public, anon, authenticated;
grant execute on function public.admin_mark_player_account_erasure_due(uuid) to service_role;
revoke all on function public.admin_prepare_player_account_erasure(uuid) from public, anon, authenticated;
grant execute on function public.admin_prepare_player_account_erasure(uuid) to service_role;

-- The result-entry RPC now accepts permanent competition identity UUIDs rather
-- than account/profile UUIDs. The browser still sends UUID arrays, but the IDs
-- are explicitly competition_player_id values returned by the scorer-options RPC.
create or replace function public.admin_record_fixture_result_with_appearances(
 p_fixture_id uuid,p_home_score integer,p_away_score integer,
 p_home_substitute_appearances uuid[] default '{}'::uuid[],
 p_away_substitute_appearances uuid[] default '{}'::uuid[],
 p_home_scorers uuid[] default '{}'::uuid[],
 p_away_scorers uuid[] default '{}'::uuid[],
 p_reason text default null
)
returns public.fixture_results
language plpgsql
security definer
set search_path = ''
as $function$
declare
 v_actor uuid := auth.uid();
 v_fixture public.fixtures;
 v_home_sheet public.fixture_team_sheets;
 v_away_sheet public.fixture_team_sheets;
 v_existing public.fixture_results;
 v_result public.fixture_results;
 v_before jsonb;
 v_had_result boolean := false;
begin
 if v_actor is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
 if p_home_score is null or p_away_score is null or p_home_score < 0 or p_away_score < 0 or p_home_score > 32767 or p_away_score > 32767 then raise exception 'Scores must be whole numbers between 0 and 32767'; end if;
 if cardinality(coalesce(p_home_scorers,'{}'::uuid[])) <> p_home_score then raise exception 'Select exactly one home-team goalscorer for every home goal'; end if;
 if cardinality(coalesce(p_away_scorers,'{}'::uuid[])) <> p_away_score then raise exception 'Select exactly one away-team goalscorer for every away goal'; end if;
 if exists(select 1 from unnest(coalesce(p_home_scorers,'{}'::uuid[])) x where x is null)
    or exists(select 1 from unnest(coalesce(p_away_scorers,'{}'::uuid[])) x where x is null) then
   raise exception 'Choose a goalscorer for every goal';
 end if;
 if exists(select 1 from unnest(coalesce(p_home_substitute_appearances,'{}'::uuid[])) x where x is null)
    or exists(select 1 from unnest(coalesce(p_away_substitute_appearances,'{}'::uuid[])) x where x is null) then
   raise exception 'Choose valid substitute appearances';
 end if;
 if cardinality(coalesce(p_home_substitute_appearances,'{}'::uuid[])) <>
    (select count(distinct x) from unnest(coalesce(p_home_substitute_appearances,'{}'::uuid[])) x) then
   raise exception 'A home substitute can only be selected once';
 end if;
 if cardinality(coalesce(p_away_substitute_appearances,'{}'::uuid[])) <>
    (select count(distinct x) from unnest(coalesce(p_away_substitute_appearances,'{}'::uuid[])) x) then
   raise exception 'An away substitute can only be selected once';
 end if;

 select * into v_fixture from public.fixtures where id = p_fixture_id for update;
 if not found then raise exception 'Fixture not found'; end if;
 if v_fixture.status in ('cancelled','postponed') then raise exception 'A cancelled or postponed fixture cannot receive a result'; end if;

 select * into v_home_sheet from public.fixture_team_sheets
 where fixture_id = p_fixture_id and season_team_id = v_fixture.home_team_id and is_locked = true;
 if not found then raise exception 'The home team must submit and lock its team sheet before a result can be published'; end if;

 select * into v_away_sheet from public.fixture_team_sheets
 where fixture_id = p_fixture_id and season_team_id = v_fixture.away_team_id and is_locked = true;
 if not found then raise exception 'The away team must submit and lock its team sheet before a result can be published'; end if;

 if exists (
   select 1 from unnest(coalesce(p_home_substitute_appearances,'{}'::uuid[])) selected(identity_id)
   where not exists (
     select 1 from public.fixture_team_sheet_players tsp
     where tsp.team_sheet_id = v_home_sheet.id
       and tsp.competition_player_id = selected.identity_id
       and tsp.role = 'substitute'
   )
 ) then raise exception 'Home appearances may only include substitutes on the submitted home team sheet'; end if;

 if exists (
   select 1 from unnest(coalesce(p_away_substitute_appearances,'{}'::uuid[])) selected(identity_id)
   where not exists (
     select 1 from public.fixture_team_sheet_players tsp
     where tsp.team_sheet_id = v_away_sheet.id
       and tsp.competition_player_id = selected.identity_id
       and tsp.role = 'substitute'
   )
 ) then raise exception 'Away appearances may only include substitutes on the submitted away team sheet'; end if;

 select * into v_existing from public.fixture_results where fixture_id = p_fixture_id;
 v_had_result := found;
 if v_had_result then
   if p_reason is null or length(btrim(p_reason)) < 5 then raise exception 'Enter a reason of at least 5 characters to correct an existing result'; end if;
   select jsonb_build_object(
     'home_score', v_existing.home_score,
     'away_score', v_existing.away_score,
     'goals', coalesce((
       select jsonb_agg(jsonb_build_object('season_team_id',g.season_team_id,'competition_player_id',g.competition_player_id) order by g.created_at)
       from public.fixture_goal_records g where g.fixture_id = p_fixture_id and g.voided_at is null
     ), '[]'::jsonb),
     'home_appearances', coalesce((
       select jsonb_agg(tsp.competition_player_id order by tsp.competition_player_id)
       from public.fixture_team_sheet_players tsp where tsp.team_sheet_id = v_home_sheet.id and tsp.did_appear is true
     ), '[]'::jsonb),
     'away_appearances', coalesce((
       select jsonb_agg(tsp.competition_player_id order by tsp.competition_player_id)
       from public.fixture_team_sheet_players tsp where tsp.team_sheet_id = v_away_sheet.id and tsp.did_appear is true
     ), '[]'::jsonb)
   ) into v_before;
   update public.fixture_goal_records
   set voided_at = now(), voided_by = v_actor, void_reason = btrim(p_reason)
   where fixture_id = p_fixture_id and voided_at is null;
 else
   v_before := '{}'::jsonb;
 end if;

 update public.fixture_team_sheet_players tsp
 set did_appear = (tsp.role = 'starter' or tsp.competition_player_id = any(coalesce(p_home_substitute_appearances,'{}'::uuid[])))
 where tsp.team_sheet_id = v_home_sheet.id;

 update public.fixture_team_sheet_players tsp
 set did_appear = (tsp.role = 'starter' or tsp.competition_player_id = any(coalesce(p_away_substitute_appearances,'{}'::uuid[])))
 where tsp.team_sheet_id = v_away_sheet.id;

 if exists (
   select 1 from unnest(coalesce(p_home_scorers,'{}'::uuid[])) scorer(identity_id)
   where not exists (
     select 1 from public.fixture_team_sheet_players tsp
     where tsp.team_sheet_id = v_home_sheet.id
       and tsp.competition_player_id = scorer.identity_id
       and tsp.did_appear is true
   )
 ) then raise exception 'Every home goalscorer must be a player who appeared in the match'; end if;

 if exists (
   select 1 from unnest(coalesce(p_away_scorers,'{}'::uuid[])) scorer(identity_id)
   where not exists (
     select 1 from public.fixture_team_sheet_players tsp
     where tsp.team_sheet_id = v_away_sheet.id
       and tsp.competition_player_id = scorer.identity_id
       and tsp.did_appear is true
   )
 ) then raise exception 'Every away goalscorer must be a player who appeared in the match'; end if;

 insert into public.fixture_results(fixture_id,home_score,away_score,confirmed_at,confirmed_by,updated_at)
 values(p_fixture_id,p_home_score,p_away_score,now(),v_actor,now())
 on conflict(fixture_id) do update set
   home_score=excluded.home_score,away_score=excluded.away_score,
   confirmed_at=excluded.confirmed_at,confirmed_by=excluded.confirmed_by,updated_at=now()
 returning * into v_result;

 insert into public.fixture_goal_records(fixture_id,season_team_id,scorer_user_id,competition_player_id,created_by)
 select p_fixture_id,v_fixture.home_team_id,p.user_id,scorer.identity_id,v_actor
 from unnest(coalesce(p_home_scorers,'{}'::uuid[])) scorer(identity_id)
 left join public.players p on p.competition_player_id=scorer.identity_id;

 insert into public.fixture_goal_records(fixture_id,season_team_id,scorer_user_id,competition_player_id,created_by)
 select p_fixture_id,v_fixture.away_team_id,p.user_id,scorer.identity_id,v_actor
 from unnest(coalesce(p_away_scorers,'{}'::uuid[])) scorer(identity_id)
 left join public.players p on p.competition_player_id=scorer.identity_id;

 update public.fixtures set status='completed',updated_at=now() where id=p_fixture_id;

 insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,before_data,after_data)
 values(
   v_actor,
   case when v_had_result then 'fixture.result.corrected' else 'fixture.result.recorded' end,
   'fixture',p_fixture_id::text,nullif(btrim(p_reason),''),
   v_before,
   jsonb_build_object(
     'home_score',p_home_score,'away_score',p_away_score,
     'home_scorers',to_jsonb(coalesce(p_home_scorers,'{}'::uuid[])),
     'away_scorers',to_jsonb(coalesce(p_away_scorers,'{}'::uuid[])),
     'home_appearances',(select coalesce(jsonb_agg(tsp.competition_player_id order by tsp.competition_player_id),'[]'::jsonb) from public.fixture_team_sheet_players tsp where tsp.team_sheet_id=v_home_sheet.id and tsp.did_appear is true),
     'away_appearances',(select coalesce(jsonb_agg(tsp.competition_player_id order by tsp.competition_player_id),'[]'::jsonb) from public.fixture_team_sheet_players tsp where tsp.team_sheet_id=v_away_sheet.id and tsp.did_appear is true),
     'status','completed'
   )
 );
 return v_result;
end;
$function$;

create or replace function public.admin_record_fixture_result(
 p_fixture_id uuid,p_home_score integer,p_away_score integer,
 p_home_scorers uuid[] default '{}'::uuid[],p_away_scorers uuid[] default '{}'::uuid[],p_reason text default null
)
returns public.fixture_results
language sql
security invoker
set search_path = ''
as $function$
 select public.admin_record_fixture_result_with_appearances(
   p_fixture_id,p_home_score,p_away_score,'{}'::uuid[],'{}'::uuid[],p_home_scorers,p_away_scorers,p_reason
 );
$function$;

revoke all on function public.admin_record_fixture_result_with_appearances(uuid,integer,integer,uuid[],uuid[],uuid[],uuid[],text) from public,anon;
grant execute on function public.admin_record_fixture_result_with_appearances(uuid,integer,integer,uuid[],uuid[],uuid[],uuid[],text) to authenticated;
revoke all on function public.admin_record_fixture_result(uuid,integer,integer,uuid[],uuid[],text) from public,anon;
grant execute on function public.admin_record_fixture_result(uuid,integer,integer,uuid[],uuid[],text) to authenticated;

create or replace function public.get_admin_fixture_scorer_options(p_fixture_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_actor uuid := auth.uid();
  v_fixture public.fixtures;
  v_home_sheet public.fixture_team_sheets;
  v_away_sheet public.fixture_team_sheets;
begin
  if v_actor is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  select * into v_fixture from public.fixtures where id = p_fixture_id;
  if not found then raise exception 'Fixture not found'; end if;
  select * into v_home_sheet from public.fixture_team_sheets where fixture_id=p_fixture_id and season_team_id=v_fixture.home_team_id and is_locked=true;
  select * into v_away_sheet from public.fixture_team_sheets where fixture_id=p_fixture_id and season_team_id=v_fixture.away_team_id and is_locked=true;
  return jsonb_build_object(
    'fixture_id',p_fixture_id,
    'home_team_id',v_fixture.home_team_id,
    'home_team_name',(select name from public.season_teams where id=v_fixture.home_team_id),
    'away_team_id',v_fixture.away_team_id,
    'away_team_name',(select name from public.season_teams where id=v_fixture.away_team_id),
    'home_sheet_submitted',v_home_sheet.id is not null,
    'away_sheet_submitted',v_away_sheet.id is not null,
    'home_players',coalesce((
      select jsonb_agg(jsonb_build_object(
        'competition_player_id',tsp.competition_player_id,
        'full_name',cpi.display_name,
        'role',tsp.role,'is_goalkeeper',tsp.is_goalkeeper,'did_appear',tsp.did_appear
      ) order by case when tsp.role='starter' then 0 else 1 end,cpi.display_name)
      from public.fixture_team_sheet_players tsp
      join public.competition_player_identities cpi on cpi.id=tsp.competition_player_id
      where tsp.team_sheet_id=v_home_sheet.id
    ),'[]'::jsonb),
    'away_players',coalesce((
      select jsonb_agg(jsonb_build_object(
        'competition_player_id',tsp.competition_player_id,
        'full_name',cpi.display_name,
        'role',tsp.role,'is_goalkeeper',tsp.is_goalkeeper,'did_appear',tsp.did_appear
      ) order by case when tsp.role='starter' then 0 else 1 end,cpi.display_name)
      from public.fixture_team_sheet_players tsp
      join public.competition_player_identities cpi on cpi.id=tsp.competition_player_id
      where tsp.team_sheet_id=v_away_sheet.id
    ),'[]'::jsonb)
  );
end;
$function$;
revoke all on function public.get_admin_fixture_scorer_options(uuid) from public,anon;
grant execute on function public.get_admin_fixture_scorer_options(uuid) to authenticated;

create or replace function public.get_admin_season_statistics(p_season_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_actor uuid := auth.uid();
  v_season public.seasons;
begin
  if v_actor is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  select * into v_season from public.seasons where id=p_season_id;
  if not found then raise exception 'Season not found'; end if;

  return (
    with published_results as (
      select f.id,f.season_id,f.home_team_id,f.away_team_id,r.home_score,r.away_score
      from public.fixtures f
      join public.fixture_results r on r.fixture_id=f.id and r.confirmed_at is not null
      where f.status='completed'
    ),
    team_matches as (
      select home_team_id as team_id,
        case when home_score>away_score then 1 else 0 end as wins,
        case when home_score=away_score then 1 else 0 end as draws,
        case when home_score<away_score then 1 else 0 end as losses,
        home_score as goals_for,away_score as goals_against,
        case when away_score=0 then 1 else 0 end as clean_sheet
      from published_results where season_id=p_season_id
      union all
      select away_team_id as team_id,
        case when away_score>home_score then 1 else 0 end,
        case when home_score=away_score then 1 else 0 end,
        case when away_score<home_score then 1 else 0 end,
        away_score,home_score,
        case when home_score=0 then 1 else 0 end
      from published_results where season_id=p_season_id
    ),
    team_totals as (
      select st.id as team_id,st.name,
        count(tm.team_id)::integer as played,
        coalesce(sum(tm.wins),0)::integer as wins,
        coalesce(sum(tm.draws),0)::integer as draws,
        coalesce(sum(tm.losses),0)::integer as losses,
        coalesce(sum(tm.goals_for),0)::integer as goals_for,
        coalesce(sum(tm.goals_against),0)::integer as goals_against,
        coalesce(sum(tm.clean_sheet),0)::integer as clean_sheets,
        (coalesce(sum(tm.wins),0)*3+coalesce(sum(tm.draws),0))::integer as points
      from public.season_teams st
      left join team_matches tm on tm.team_id=st.id
      where st.season_id=p_season_id
      group by st.id,st.name
    ),
    ranked_teams as (
      select row_number() over(order by points desc,(goals_for-goals_against) desc,goals_for desc,name asc)::integer as position,
        team_id,name,played,wins,draws,losses,goals_for,goals_against,
        (goals_for-goals_against)::integer as goal_difference,points,clean_sheets
      from team_totals
    ),
    player_apps as (
      select cpi.id as competition_player_id,cpi.display_name as full_name,
        count(distinct f.id)::integer as apps,
        count(distinct f.id) filter(where tsp.role='starter')::integer as starts,
        count(distinct f.id) filter(where tsp.role='substitute')::integer as subs,
        count(distinct f.id) filter(where tsp.is_goalkeeper)::integer as goalkeeper_apps,
        count(distinct f.id) filter(where tsp.is_goalkeeper and
          ((ts.season_team_id=f.home_team_id and pr.away_score=0) or
           (ts.season_team_id=f.away_team_id and pr.home_score=0)))::integer as goalkeeper_clean_sheets
      from public.fixture_team_sheet_players tsp
      join public.competition_player_identities cpi on cpi.id=tsp.competition_player_id
      join public.fixture_team_sheets ts on ts.id=tsp.team_sheet_id and ts.is_locked=true
      join public.fixtures f on f.id=ts.fixture_id and f.status='completed'
      join published_results pr on pr.id=f.id
      where f.season_id=p_season_id and tsp.did_appear is true
        and cpi.counts_for_statistics is true
      group by cpi.id,cpi.display_name
    ),
    player_goals as (
      select g.competition_player_id,count(*)::integer as goals
      from public.fixture_goal_records g
      join published_results pr on pr.id=g.fixture_id
      join public.fixtures f on f.id=g.fixture_id
      join public.competition_player_identities cpi on cpi.id=g.competition_player_id
        and cpi.counts_for_statistics is true
      where f.season_id=p_season_id and g.voided_at is null
      group by g.competition_player_id
    ),
    season_summary as (
      select
        (select count(*)::integer from public.fixtures f where f.season_id=p_season_id and f.status<>'cancelled') as fixtures,
        (select count(*)::integer from published_results pr where pr.season_id=p_season_id) as published_results,
        coalesce((select sum(pr.home_score+pr.away_score)::integer from published_results pr where pr.season_id=p_season_id),0) as goals,
        coalesce((select count(*)::integer from published_results pr where pr.season_id=p_season_id and pr.home_score>pr.away_score),0) as home_wins,
        coalesce((select count(*)::integer from published_results pr where pr.season_id=p_season_id and pr.away_score>pr.home_score),0) as away_wins,
        coalesce((select count(*)::integer from published_results pr where pr.season_id=p_season_id and pr.home_score=pr.away_score),0) as draws,
        coalesce((select sum(rt.clean_sheets)::integer from ranked_teams rt),0) as team_clean_sheets
    ),
    season_history as (
      select s.id,s.name,s.season_number,
        count(pr.id)::integer as published_results,
        coalesce(sum(pr.home_score+pr.away_score),0)::integer as goals,
        coalesce(round(sum(pr.home_score+pr.away_score)::numeric/nullif(count(pr.id),0),2),0) as goals_per_match
      from public.seasons s
      left join published_results pr on pr.season_id=s.id
      where s.league_id=v_season.league_id and s.is_public=true
      group by s.id,s.name,s.season_number,s.created_at
      order by s.created_at
    )
    select jsonb_build_object(
      'season',jsonb_build_object('id',v_season.id,'name',v_season.name,'status',v_season.status,'is_public',v_season.is_public),
      'summary',(select jsonb_build_object(
        'fixtures',ss.fixtures,'published_results',ss.published_results,'goals',ss.goals,
        'goals_per_match',coalesce(round(ss.goals::numeric/nullif(ss.published_results,0),2),0),
        'home_wins',ss.home_wins,'away_wins',ss.away_wins,'draws',ss.draws,
        'team_clean_sheets',ss.team_clean_sheets
      ) from season_summary ss),
      'teams',coalesce((select jsonb_agg(to_jsonb(rt) order by rt.position) from ranked_teams rt),'[]'::jsonb),
      'players',coalesce((
        select jsonb_agg(jsonb_build_object(
          'competition_player_id',pa.competition_player_id,'full_name',pa.full_name,'apps',pa.apps,
          'starts',pa.starts,'subs',pa.subs,'apps_display',pa.starts||'('||pa.subs||')',
          'goals',coalesce(pg.goals,0),'goalkeeper_apps',pa.goalkeeper_apps,
          'goalkeeper_clean_sheets',pa.goalkeeper_clean_sheets
        ) order by coalesce(pg.goals,0) desc,pa.apps desc,pa.full_name)
        from player_apps pa left join player_goals pg on pg.competition_player_id=pa.competition_player_id
      ),'[]'::jsonb),
      'history',coalesce((select jsonb_agg(to_jsonb(sh) order by sh.season_number nulls last,sh.name) from season_history sh),'[]'::jsonb)
    )
  );
end;
$function$;
revoke all on function public.get_admin_season_statistics(uuid) from public,anon;
grant execute on function public.get_admin_season_statistics(uuid) to authenticated;

create or replace function public.get_admin_team_sheets_contextual(
  p_location_id uuid default null,p_league_id uuid default null,p_season_id uuid default null
) returns table(
  team_sheet_id uuid,fixture_id uuid,season_team_id uuid,team_name text,opponent_name text,
  gameweek integer,scheduled_at timestamptz,competition_format public.competition_format,
  is_locked boolean,submitted_at timestamptz,players jsonb,roster jsonb
)
language plpgsql stable security definer set search_path=''
as $$
declare v_location uuid:=p_location_id;v_league uuid:=p_league_id;v_season uuid:=p_season_id;v_league_location uuid;v_season_league uuid;
begin
  if auth.uid() is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  if v_season is not null then
    select s.league_id into v_season_league from public.seasons s where s.id=v_season;
    if v_season_league is null then raise exception 'Selected season was not found'; end if;
    if v_league is not null and v_league<>v_season_league then raise exception 'Season does not belong to selected league'; end if;
    v_league:=v_season_league;
  end if;
  if v_league is not null then
    select l.location_id into v_league_location from public.leagues l where l.id=v_league;
    if v_league_location is null then raise exception 'Selected league was not found'; end if;
    if v_location is not null and v_location<>v_league_location then raise exception 'League does not belong to selected location'; end if;
    v_location:=v_league_location;
  end if;
  if v_location is not null and not exists(select 1 from public.locations where id=v_location) then raise exception 'Selected location was not found'; end if;
  return query
  select sh.id,sh.fixture_id,sh.season_team_id,st.name,opponent.name,f.gameweek,f.scheduled_at,l.format,sh.is_locked,sh.submitted_at,
    coalesce((
      select jsonb_agg(jsonb_build_object(
        'membership_id',tm.id,'player_name',cpi.display_name,'role',tsp.role,
        'is_goalkeeper',tsp.is_goalkeeper,'squad_number_snapshot',tsp.squad_number_snapshot
      ) order by case when tsp.role='starter' then 0 else 1 end,cpi.display_name)
      from public.fixture_team_sheet_players tsp
      join public.competition_player_identities cpi on cpi.id=tsp.competition_player_id
      left join public.team_memberships tm on tm.user_id=tsp.user_id and tm.season_team_id=sh.season_team_id and tm.status='active'
      where tsp.team_sheet_id=sh.id
    ),'[]'::jsonb),
    coalesce((
      select jsonb_agg(jsonb_build_object('membership_id',tm.id,'player_name',p.full_name,'squad_number',tm.squad_number) order by p.full_name)
      from public.team_memberships tm join public.players p on p.user_id=tm.user_id
      where tm.season_team_id=sh.season_team_id and tm.status='active'
        and p.registration_status='registered' and p.is_banned=false
    ),'[]'::jsonb)
  from public.fixture_team_sheets sh
  join public.fixtures f on f.id=sh.fixture_id
  join public.seasons se on se.id=f.season_id
  join public.leagues l on l.id=se.league_id
  join public.season_teams st on st.id=sh.season_team_id
  join public.season_teams opponent on opponent.id=case when f.home_team_id=sh.season_team_id then f.away_team_id else f.home_team_id end
  where (v_location is null or l.location_id=v_location)
    and (v_league is null or l.id=v_league)
    and (v_season is null or se.id=v_season)
  order by f.scheduled_at desc nulls last,f.gameweek desc,st.name;
end;
$$;
revoke all on function public.get_admin_team_sheets_contextual(uuid,uuid,uuid) from public,anon;
grant execute on function public.get_admin_team_sheets_contextual(uuid,uuid,uuid) to authenticated;

create or replace function public.get_admin_team_sheets()
returns table(team_sheet_id uuid,fixture_id uuid,season_team_id uuid,team_name text,opponent_name text,gameweek integer,scheduled_at timestamptz,competition_format public.competition_format,is_locked boolean,submitted_at timestamptz,players jsonb,roster jsonb)
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  return query
  select s.id,s.fixture_id,s.season_team_id,st.name,opponent.name,f.gameweek,f.scheduled_at,l.format,s.is_locked,s.submitted_at,
    coalesce((
      select jsonb_agg(jsonb_build_object(
        'membership_id',tm.id,'player_name',cpi.display_name,'role',tsp.role,
        'is_goalkeeper',tsp.is_goalkeeper,'squad_number_snapshot',tsp.squad_number_snapshot
      ) order by case when tsp.role='starter' then 0 else 1 end,cpi.display_name)
      from public.fixture_team_sheet_players tsp
      join public.competition_player_identities cpi on cpi.id=tsp.competition_player_id
      left join public.team_memberships tm on tm.user_id=tsp.user_id and tm.season_team_id=s.season_team_id and tm.status='active'
      where tsp.team_sheet_id=s.id
    ),'[]'::jsonb),
    coalesce((
      select jsonb_agg(jsonb_build_object('membership_id',tm.id,'player_name',p.full_name,'squad_number',tm.squad_number) order by p.full_name)
      from public.team_memberships tm join public.players p on p.user_id=tm.user_id
      where tm.season_team_id=s.season_team_id and tm.status='active'
        and p.registration_status='registered' and p.is_banned=false
    ),'[]'::jsonb)
  from public.fixture_team_sheets s
  join public.fixtures f on f.id=s.fixture_id
  join public.seasons se on se.id=f.season_id
  join public.leagues l on l.id=se.league_id
  join public.season_teams st on st.id=s.season_team_id
  join public.season_teams opponent on opponent.id=case when f.home_team_id=s.season_team_id then f.away_team_id else f.home_team_id end
  order by f.scheduled_at desc nulls last,f.gameweek desc,st.name;
end;
$$;
revoke all on function public.get_admin_team_sheets() from public,anon;
grant execute on function public.get_admin_team_sheets() to authenticated;

create or replace function public.admin_amend_team_sheet(
 p_team_sheet_id uuid,p_starters uuid[],p_substitutes uuid[] default '{}'::uuid[],
 p_goalkeeper_membership_id uuid default null,p_reason text default null
)
returns public.fixture_team_sheets
language plpgsql security definer set search_path = '' as $$
declare
 v_actor uuid:=auth.uid(); v_sheet public.fixture_team_sheets; v_fixture public.fixtures;
 v_format public.competition_format; v_expected_starters integer; v_max_substitutes integer;
 v_all_memberships uuid[]; v_before jsonb;
begin
 if v_actor is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
 if p_reason is null or length(btrim(p_reason))<5 then raise exception 'Enter a reason of at least 5 characters for this amendment'; end if;
 select * into v_sheet from public.fixture_team_sheets where id=p_team_sheet_id for update;
 if not found then raise exception 'Team sheet not found'; end if;
 if not v_sheet.is_locked then raise exception 'Only submitted, locked team sheets can be amended here'; end if;
 select * into v_fixture from public.fixtures where id=v_sheet.fixture_id;
 if not found then raise exception 'Fixture not found'; end if;
 if v_sheet.season_team_id not in (v_fixture.home_team_id,v_fixture.away_team_id) then raise exception 'Team sheet does not belong to this fixture'; end if;
 select l.format into v_format from public.seasons s join public.leagues l on l.id=s.league_id where s.id=v_fixture.season_id;
 v_expected_starters:=case when v_format='six_a_side' then 6 else 7 end;
 v_max_substitutes:=case when v_format='six_a_side' then 3 else 4 end;
 if coalesce(cardinality(p_starters),0)<>v_expected_starters then raise exception 'Select exactly % starting players',v_expected_starters; end if;
 if coalesce(cardinality(p_substitutes),0)>v_max_substitutes then raise exception 'Select no more than % substitutes',v_max_substitutes; end if;
 if p_goalkeeper_membership_id is null or not (p_goalkeeper_membership_id=any(coalesce(p_starters,'{}'::uuid[]))) then raise exception 'Select one goalkeeper from your starting players'; end if;
 v_all_memberships:=coalesce(p_starters,'{}'::uuid[])||coalesce(p_substitutes,'{}'::uuid[]);
 if (select count(distinct x) from unnest(v_all_memberships) x)<>cardinality(v_all_memberships) then raise exception 'A player can only appear once on a team sheet'; end if;
 if exists(
   select 1 from unnest(v_all_memberships) x
   where not exists(
     select 1 from public.team_memberships tm join public.players p on p.user_id=tm.user_id
     where tm.id=x and tm.season_team_id=v_sheet.season_team_id and tm.status='active'
       and p.registration_status='registered' and p.is_banned=false
   )
 ) then raise exception 'Every selected player must have an active, approved membership in this team'; end if;

 if exists(
   select 1
   from public.fixture_team_sheet_players tsp
   left join public.team_memberships tm
     on tm.user_id=tsp.user_id and tm.season_team_id=v_sheet.season_team_id and tm.status='active'
   where tsp.team_sheet_id=v_sheet.id and tm.id is null
 ) then
   raise exception 'This sheet contains a former or anonymised player. Its historic appearance record is protected from standard roster amendments';
 end if;
 select coalesce(jsonb_agg(jsonb_build_object(
   'competition_player_id',tsp.competition_player_id,'role',tsp.role,
   'is_goalkeeper',tsp.is_goalkeeper,'squad_number_snapshot',tsp.squad_number_snapshot
  )),'[]'::jsonb)
 into v_before from public.fixture_team_sheet_players tsp where tsp.team_sheet_id=v_sheet.id;

 -- The guard above ensures every existing sheet row still maps to an active membership.
 delete from public.fixture_team_sheet_players where team_sheet_id=v_sheet.id;

 insert into public.fixture_team_sheet_players(team_sheet_id,user_id,role,squad_number_snapshot,is_goalkeeper)
 select v_sheet.id,tm.user_id,'starter',tm.squad_number,tm.id=p_goalkeeper_membership_id
 from public.team_memberships tm
 where tm.id=any(coalesce(p_starters,'{}'::uuid[]))
   and tm.season_team_id=v_sheet.season_team_id and tm.status='active';

 insert into public.fixture_team_sheet_players(team_sheet_id,user_id,role,squad_number_snapshot,is_goalkeeper)
 select v_sheet.id,tm.user_id,'substitute',tm.squad_number,false
 from public.team_memberships tm
 where tm.id=any(coalesce(p_substitutes,'{}'::uuid[]))
   and tm.season_team_id=v_sheet.season_team_id and tm.status='active';

 insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,before_data,after_data)
 values(v_actor,'fixture.team_sheet.admin_amended','fixture_team_sheet',v_sheet.id::text,btrim(p_reason),v_before,
   jsonb_build_object('starters',p_starters,'substitutes',p_substitutes,
     'goalkeeper_membership_id',p_goalkeeper_membership_id,'reason',btrim(p_reason),'is_locked',true));
 return v_sheet;
end;
$$;
revoke all on function public.admin_amend_team_sheet(uuid,uuid[],uuid[],uuid,text) from public,anon;
grant execute on function public.admin_amend_team_sheet(uuid,uuid[],uuid[],uuid,text) to authenticated;

create or replace function public.get_captain_team_sheet(p_fixture_id uuid)
returns table(season_team_id uuid,starters uuid[],substitutes uuid[],goalkeeper_membership_id uuid,is_locked boolean,submitted_at timestamptz,draft_saved_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
declare v_actor uuid:=auth.uid();
begin
  if v_actor is null then raise exception 'Authentication required'; end if;
  return query
  select s.season_team_id,
    coalesce(array_agg(tm.id) filter(where tsp.role='starter' and tm.id is not null),'{}'::uuid[]),
    coalesce(array_agg(tm.id) filter(where tsp.role='substitute' and tm.id is not null),'{}'::uuid[]),
    (array_agg(tm.id) filter(where tsp.is_goalkeeper and tm.id is not null))[1],
    s.is_locked,s.submitted_at,s.draft_saved_at
  from public.fixture_team_sheets s
  join public.team_memberships captain on captain.season_team_id=s.season_team_id
    and captain.user_id=v_actor and captain.is_captain=true and captain.status='active'
  left join public.fixture_team_sheet_players tsp on tsp.team_sheet_id=s.id
  left join public.team_memberships tm on tm.user_id=tsp.user_id and tm.season_team_id=s.season_team_id and tm.status='active'
  where s.fixture_id=p_fixture_id
  group by s.id;
end;
$$;

create or replace function public.admin_get_transfer_requests_contextual(
  p_status text default 'pending',p_location_id uuid default null,p_league_id uuid default null,p_season_id uuid default null
) returns table(id uuid,user_id uuid,player_name text,source_membership_id uuid,source_team_name text,destination_team_id uuid,destination_team_name text,season_name text,league_name text,reason text,status text,requested_at timestamptz)
language plpgsql stable security definer set search_path=''
as $$
declare v_location uuid:=p_location_id;v_league uuid:=p_league_id;v_season uuid:=p_season_id;v_league_location uuid;v_season_league uuid;
begin
  if auth.uid() is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  if p_status is not null and p_status not in ('all','pending','approved','rejected','cancelled') then raise exception 'Invalid transfer status filter'; end if;
  if v_season is not null then
    select s.league_id into v_season_league from public.seasons s where s.id=v_season;
    if v_season_league is null then raise exception 'Selected season was not found'; end if;
    if v_league is not null and v_league<>v_season_league then raise exception 'Season does not belong to selected league'; end if;
    v_league:=v_season_league;
  end if;
  if v_league is not null then
    select l.location_id into v_league_location from public.leagues l where l.id=v_league;
    if v_league_location is null then raise exception 'Selected league was not found'; end if;
    if v_location is not null and v_location<>v_league_location then raise exception 'League does not belong to selected location'; end if;
    v_location:=v_league_location;
  end if;
  if v_location is not null and not exists(select 1 from public.locations where id=v_location) then raise exception 'Selected location was not found'; end if;
  return query
  select r.id,r.user_id,coalesce(p.full_name,'Former player'),r.source_membership_id,
    src.name,dst.id,dst.name,se.name,l.name,r.reason,r.status,r.requested_at
  from public.player_transfer_requests r
  left join public.players p on p.user_id=r.user_id
  join public.season_teams src on src.id=r.source_season_team_id
  join public.season_teams dst on dst.id=r.destination_season_team_id
  join public.seasons se on se.id=src.season_id
  join public.leagues l on l.id=se.league_id
  where (p_status is null or p_status='all' or r.status=p_status)
    and (v_location is null or l.location_id=v_location)
    and (v_league is null or l.id=v_league)
    and (v_season is null or se.id=v_season)
  order by case when r.status='pending' then 0 else 1 end,r.requested_at desc;
end;
$$;
revoke all on function public.admin_get_transfer_requests_contextual(text,uuid,uuid,uuid) from public,anon;
grant execute on function public.admin_get_transfer_requests_contextual(text,uuid,uuid,uuid) to authenticated;

create or replace function public.get_admin_stripe_payments(p_season_id uuid default null)
returns table(
  payment_record_id uuid,fixture_id uuid,gameweek integer,scheduled_at timestamptz,
  season_id uuid,season_name text,team_name text,player_name text,amount_pence integer,
  currency text,status public.payment_status,amount_refunded_pence integer,
  stripe_fee_pence integer,net_amount_pence integer,paid_at timestamptz,created_at timestamptz
)
language plpgsql stable security definer set search_path=''
as $$
begin
  if not public.has_finance_access() then raise exception 'Finance access required'; end if;
  return query
  select pr.id,pr.fixture_id,f.gameweek,f.scheduled_at,s.id,s.name,st.name,
    coalesce(p.full_name,'Former player'),pr.amount_pence,pr.currency,pr.status,
    pr.amount_refunded_pence,pr.stripe_fee_pence,pr.net_amount_pence,pr.paid_at,pr.created_at
  from public.payment_records pr
  join public.season_teams st on st.id=pr.season_team_id
  join public.seasons s on s.id=st.season_id
  left join public.fixtures f on f.id=pr.fixture_id
  left join public.players p on p.user_id=pr.player_user_id
  where p_season_id is null or s.id=p_season_id
  order by pr.created_at desc;
end;
$$;
revoke all on function public.get_admin_stripe_payments(uuid) from public,anon;
grant execute on function public.get_admin_stripe_payments(uuid) to authenticated;

comment on table public.competition_player_identities is
  'Permanent, account-independent competition identities. After account erasure the display label becomes Former player and the unlinked identity retains only competition statistics.';
comment on column public.fixture_team_sheet_players.competition_player_id is
  'Permanent competition identity for historic appearances; independent of the live account/profile UUID.';
comment on column public.fixture_goal_records.competition_player_id is
  'Permanent competition identity for historic goals; independent of the live account/profile UUID.';
