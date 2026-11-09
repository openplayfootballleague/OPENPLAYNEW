-- Age-tier eligibility and verified guardian consent for 16- and 17-year-old players.
-- Under-16s may browse public Open Play information but cannot create player registrations.
-- A 16-17-year-old requires verified guardian consent and a separate administrator approval.

create table public.player_guardian_consents (
  id uuid primary key default gen_random_uuid(),
  player_user_id uuid not null unique references auth.users(id) on delete cascade,
  player_date_of_birth date not null,
  guardian_full_name text not null check (char_length(btrim(guardian_full_name)) between 2 and 120),
  guardian_email text not null check (guardian_email = lower(btrim(guardian_email)) and position('@' in guardian_email) > 1),
  status text not null default 'pending_verification'
    check (status in ('pending_verification','pending_admin_review','approved','rejected','withdrawn')),
  verification_token_hash text,
  verification_expires_at timestamptz,
  withdrawal_token_hash text not null,
  verified_at timestamptz,
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  review_reason text,
  withdrawn_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint guardian_consent_dob_reasonable check (player_date_of_birth >= date '1900-01-01'),
  constraint guardian_consent_verification_state check (
    (status = 'pending_verification' and verification_token_hash is not null and verification_expires_at is not null and verified_at is null)
    or (status <> 'pending_verification' and verification_token_hash is null and verification_expires_at is null)
  )
);

-- Preserve the pre-safeguard registration state for existing 16-17-year-olds
-- so administrator approval can restore an eligible existing identity.
alter table public.players
  add column guardian_consent_previous_status public.player_registration_status;

create index player_guardian_consents_review_idx
  on public.player_guardian_consents(status, created_at);

alter table public.player_guardian_consents enable row level security;
revoke all on public.player_guardian_consents from public, anon, authenticated;

-- Resolve the installed pgcrypto schema explicitly. Supabase installations may
-- place extensions outside public, while these security-definer functions use
-- an empty search_path.
create or replace function public.hash_guardian_consent_token(p_token text)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_schema text;
  v_hash text;
begin
  select n.nspname into v_schema
  from pg_catalog.pg_extension e
  join pg_catalog.pg_namespace n on n.oid=e.extnamespace
  where e.extname='pgcrypto';
  if v_schema is null then raise exception 'Secure token hashing is unavailable'; end if;
  execute pg_catalog.format(
    'select pg_catalog.encode(%I.digest($1, %L), %L)',
    v_schema,'sha256','hex'
  ) into v_hash using p_token;
  return v_hash;
end;
$$;
revoke all on function public.hash_guardian_consent_token(text) from public,anon,authenticated;

create or replace function public.request_player_guardian_consent(
  p_player_user_id uuid,
  p_player_date_of_birth date,
  p_guardian_full_name text,
  p_guardian_email text,
  p_verification_token_hash text,
  p_withdrawal_token_hash text
)
returns table(status text, requested_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := p_player_user_id;
  v_email text;
  v_now timestamptz := now();
begin
  if coalesce(auth.role(),'') <> 'service_role' then raise exception 'Trusted consent service required'; end if;
  if v_user is null then raise exception 'Player account is required'; end if;
  select lower(trim(email)) into v_email from auth.users where id=v_user and email_confirmed_at is not null;
  if v_email is null then raise exception 'Verify your account email before requesting guardian consent'; end if;
  if p_player_date_of_birth is null
     or p_player_date_of_birth > current_date - interval '16 years'
     or p_player_date_of_birth <= current_date - interval '18 years' then
    raise exception 'Guardian consent is only required for players aged 16 or 17';
  end if;
  if nullif(btrim(p_guardian_full_name),'') is null or char_length(btrim(p_guardian_full_name))>120 then
    raise exception 'Enter the parent or legal guardian full name';
  end if;
  if p_guardian_email is null or lower(trim(p_guardian_email)) !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
     or lower(trim(p_guardian_email))=v_email then
    raise exception 'Enter a valid parent or legal guardian email address different from your own';
  end if;
  if p_verification_token_hash !~ '^[0-9a-f]{64}$' or p_withdrawal_token_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'Consent verification could not be created securely';
  end if;

  insert into public.player_guardian_consents(
    player_user_id,player_date_of_birth,guardian_full_name,guardian_email,status,
    verification_token_hash,verification_expires_at,withdrawal_token_hash,
    verified_at,reviewed_by,reviewed_at,review_reason,withdrawn_at,updated_at
  ) values (
    v_user,p_player_date_of_birth,btrim(p_guardian_full_name),lower(trim(p_guardian_email)),
    'pending_verification',p_verification_token_hash,v_now+interval '7 days',p_withdrawal_token_hash,
    null,null,null,null,null,v_now
  )
  on conflict(player_user_id) do update set
    player_date_of_birth=excluded.player_date_of_birth,
    guardian_full_name=excluded.guardian_full_name,
    guardian_email=excluded.guardian_email,
    status='pending_verification',
    verification_token_hash=excluded.verification_token_hash,
    verification_expires_at=excluded.verification_expires_at,
    withdrawal_token_hash=excluded.withdrawal_token_hash,
    verified_at=null,reviewed_by=null,reviewed_at=null,review_reason=null,
    withdrawn_at=null,updated_at=v_now
  where public.player_guardian_consents.status in ('pending_verification','pending_admin_review','rejected','withdrawn');

  if not found then raise exception 'Guardian consent is already approved'; end if;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,after_data)
  values(v_user,'player.guardian_consent.requested','player_guardian_consent',v_user::text,
    jsonb_build_object('guardian_email',lower(trim(p_guardian_email)),'player_date_of_birth',p_player_date_of_birth));

  return query select 'pending_verification'::text,v_now;
end;
$$;

create or replace function public.verify_player_guardian_consent(p_token text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare v_consent public.player_guardian_consents;
begin
  if p_token is null or length(p_token)<32 then raise exception 'Consent link is invalid or expired'; end if;
  select * into v_consent
  from public.player_guardian_consents
  where verification_token_hash=public.hash_guardian_consent_token(p_token)
    and status='pending_verification'
    and verification_expires_at>now()
  for update;
  if not found then raise exception 'Consent link is invalid or expired'; end if;

  update public.player_guardian_consents
  set status='pending_admin_review',verification_token_hash=null,
      verification_expires_at=null,verified_at=now(),updated_at=now()
  where id=v_consent.id;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,after_data)
  values(null,'player.guardian_consent.verified','player_guardian_consent',v_consent.player_user_id::text,
    jsonb_build_object('verified_at',now()));
  return 'pending_admin_review';
end;
$$;

create or replace function public.withdraw_player_guardian_consent(p_token text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare v_consent public.player_guardian_consents;
declare v_player_id uuid;
declare v_captain_teams integer;
begin
  if p_token is null or length(p_token)<32 then raise exception 'Withdrawal link is invalid'; end if;
  select * into v_consent
  from public.player_guardian_consents
  where withdrawal_token_hash=public.hash_guardian_consent_token(p_token)
    and status in ('pending_verification','pending_admin_review','approved')
    and player_date_of_birth <= current_date - interval '16 years'
    and player_date_of_birth > current_date - interval '18 years'
  for update;
  if not found then raise exception 'Withdrawal link is invalid or consent is already withdrawn'; end if;

  update public.player_guardian_consents
  set status='withdrawn',verification_token_hash=null,verification_expires_at=null,
      withdrawn_at=now(),updated_at=now()
  where id=v_consent.id;

  select id into v_player_id from public.players where user_id=v_consent.player_user_id for update;
  if v_player_id is not null then
    select count(*) into v_captain_teams from public.team_memberships
      where user_id=v_consent.player_user_id and status='active' and is_captain=true;
    update public.team_memberships
    set status=case when status='active' then 'left'::public.membership_status
                    when status='pending' then 'rejected'::public.membership_status else status end,
        is_captain=false,
        left_at=case when status in ('active','pending') then now() else left_at end,
        updated_at=now()
    where user_id=v_consent.player_user_id and status in ('active','pending');
    update public.players
    set guardian_consent_previous_status=coalesce(guardian_consent_previous_status,registration_status),
        registration_status='rejected'::public.player_registration_status,updated_at=now()
    where user_id=v_consent.player_user_id;
    if v_captain_teams>0 then
      insert into public.audit_log(actor_user_id,action,entity_type,entity_id,after_data)
      values(null,'player.guardian_consent.captaincy_revoked','player',v_consent.player_user_id::text,
        jsonb_build_object('teams_requiring_admin_captain_assignment',v_captain_teams));
      perform public.enqueue_notification_event(ur.user_id,'player.guardian_consent.captain_review_required',
        jsonb_build_object('player_user_id',v_consent.player_user_id,'teams_requiring_admin_captain_assignment',v_captain_teams,'changed_at',now()))
      from public.user_roles ur where ur.role in ('admin','super_admin');
    end if;
  end if;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,after_data)
  values(null,'player.guardian_consent.withdrawn','player_guardian_consent',v_consent.player_user_id::text,
    jsonb_build_object('withdrawn_at',now(),'player_registration_suspended',v_player_id is not null));
  return 'withdrawn';
end;
$$;

create or replace function public.get_my_guardian_consent_status()
returns table(
  status text,player_date_of_birth date,guardian_full_name text,guardian_email text,
  verified_at timestamptz,reviewed_at timestamptz,review_reason text,withdrawn_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select c.status,c.player_date_of_birth,c.guardian_full_name,c.guardian_email,c.verified_at,c.reviewed_at,c.review_reason,c.withdrawn_at
  from public.player_guardian_consents c
  where c.player_user_id=auth.uid()
$$;

create or replace function public.admin_get_guardian_consent_queue()
returns table(
  id uuid,player_user_id uuid,player_email text,player_date_of_birth date,
  guardian_full_name text,guardian_email text,status text,verified_at timestamptz,created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not exists(
    select 1 from public.user_roles where user_id=auth.uid() and role in ('admin','super_admin')
  ) then raise exception 'Global administrator permission required'; end if;
  return query
  select c.id,c.player_user_id,u.email,c.player_date_of_birth,c.guardian_full_name,c.guardian_email,
    c.status,c.verified_at,c.created_at
  from public.player_guardian_consents c
  join auth.users u on u.id=c.player_user_id
  where c.status in ('pending_admin_review','approved','rejected','withdrawn')
  order by case c.status when 'pending_admin_review' then 0 else 1 end,c.created_at;
end;
$$;

create or replace function public.admin_review_guardian_consent(
  p_consent_id uuid,p_decision text,p_reason text
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare v_actor uuid:=auth.uid(); v_consent public.player_guardian_consents;
begin
  if v_actor is null or not exists(
    select 1 from public.user_roles where user_id=v_actor and role in ('admin','super_admin')
  ) then raise exception 'Global administrator permission required'; end if;
  if p_decision not in ('approved','rejected') then raise exception 'Decision must be approved or rejected'; end if;
  if p_reason is null or length(btrim(p_reason))<5 then raise exception 'Enter a reason of at least 5 characters'; end if;
  select * into v_consent from public.player_guardian_consents
  where id=p_consent_id and status='pending_admin_review' for update;
  if not found then raise exception 'No verified guardian consent is awaiting review'; end if;

  update public.player_guardian_consents
  set status=p_decision,reviewed_by=v_actor,reviewed_at=now(),review_reason=btrim(p_reason),updated_at=now()
  where id=p_consent_id;

  if p_decision='approved' then
    update public.players
    set registration_status=guardian_consent_previous_status,
        guardian_consent_previous_status=null,updated_at=now()
    where user_id=v_consent.player_user_id
      and guardian_consent_previous_status is not null;
  end if;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,after_data)
  values(v_actor,'player.guardian_consent.'||p_decision,'player_guardian_consent',v_consent.player_user_id::text,
    btrim(p_reason),jsonb_build_object('guardian_email',v_consent.guardian_email,'verified_at',v_consent.verified_at));

  return p_decision;
end;
$$;

create or replace function public.enforce_player_age_and_guardian_consent()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare v_age integer;
begin
  -- Suspended/rejected records may remain in the database without consent.
  -- Any new player identity or attempt to retain/restore player access must
  -- satisfy the age and guardian-consent policy, including admin review RPCs.
  if tg_op='INSERT' or new.registration_status<>'rejected' then
    v_age:=extract(year from age(current_date,new.date_of_birth))::integer;
    if v_age<16 then raise exception 'Players must be at least 16 years old to register'; end if;
    if v_age<18 and not exists(
      select 1 from public.player_guardian_consents c
      where c.player_user_id=new.user_id
        and c.player_date_of_birth=new.date_of_birth
        and c.status='approved'
        and c.verified_at is not null
        and c.reviewed_at is not null
    ) then
      raise exception 'Verified parent or legal-guardian consent and administrator approval are required for players aged 16 or 17';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists players_enforce_age_and_guardian_consent on public.players;
create trigger players_enforce_age_and_guardian_consent
before insert or update of date_of_birth,registration_status on public.players
for each row execute function public.enforce_player_age_and_guardian_consent();

-- Existing under-18 player records cannot retain access without the new consent.
update public.players p
set guardian_consent_previous_status=p.registration_status,
    registration_status='rejected'::public.player_registration_status,updated_at=now()
where p.date_of_birth>current_date-interval '18 years'
  and not exists(select 1 from public.player_guardian_consents c
    where c.player_user_id=p.user_id and c.player_date_of_birth=p.date_of_birth
      and c.status='approved' and c.verified_at is not null and c.reviewed_at is not null);

update public.team_memberships tm
set status=case when tm.status='active' then 'left'::public.membership_status
                when tm.status='pending' then 'rejected'::public.membership_status else tm.status end,
    is_captain=false,left_at=case when tm.status in ('active','pending') then now() else tm.left_at end,
    updated_at=now()
where tm.status in ('active','pending')
  and exists(select 1 from public.players p where p.user_id=tm.user_id
    and p.registration_status='rejected'
    and p.date_of_birth>current_date-interval '18 years');

revoke all on function public.request_player_guardian_consent(uuid,date,text,text,text,text) from public,anon,authenticated;
grant execute on function public.request_player_guardian_consent(uuid,date,text,text,text,text) to service_role;
revoke all on function public.verify_player_guardian_consent(text) from public,authenticated;
grant execute on function public.verify_player_guardian_consent(text) to anon;
revoke all on function public.withdraw_player_guardian_consent(text) from public,authenticated;
grant execute on function public.withdraw_player_guardian_consent(text) to anon;
revoke all on function public.get_my_guardian_consent_status() from public,anon;
grant execute on function public.get_my_guardian_consent_status() to authenticated;
revoke all on function public.admin_get_guardian_consent_queue() from public,anon;
grant execute on function public.admin_get_guardian_consent_queue() to authenticated;
revoke all on function public.admin_review_guardian_consent(uuid,text,text) from public,anon;
grant execute on function public.admin_review_guardian_consent(uuid,text,text) to authenticated;

comment on table public.player_guardian_consents is
  'Verified parent/legal-guardian consent and administrator review for 16-17-year-old Open Play players.';
