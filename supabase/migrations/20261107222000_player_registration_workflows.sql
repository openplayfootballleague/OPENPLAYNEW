-- Permanent player identity and registration workflow.
-- Player registration is immediate unless at least 2 of the 3 identity metrics match.
-- Date of birth is mandatory but is not a matching metric.

create type public.player_registration_status as enum ('registered', 'pending_review', 'rejected');

create table public.players (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  full_name text not null check (char_length(trim(full_name)) between 2 and 160),
  phone text not null check (char_length(trim(phone)) between 7 and 32),
  email text not null check (email = lower(trim(email)) and position('@' in email) > 1),
  date_of_birth date not null,
  registration_status public.player_registration_status not null,
  is_banned boolean not null default false,
  banned_at timestamptz,
  banned_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint players_dob_reasonable check (date_of_birth >= date '1900-01-01'),
  constraint players_ban_metadata check (
    (is_banned = false and banned_at is null)
    or (is_banned = true and banned_at is not null)
  )
);

create index players_full_name_match_idx on public.players (lower(trim(full_name)));
create index players_email_match_idx on public.players (lower(trim(email)));
create index players_phone_match_idx on public.players ((regexp_replace(phone, '[^0-9]', '', 'g')));

create table public.player_registration_reviews (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null unique references public.players(id) on delete cascade,
  name_matched boolean not null,
  phone_matched boolean not null,
  email_matched boolean not null,
  matched_player_ids uuid[] not null default '{}',
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  review_reason text,
  created_at timestamptz not null default now(),
  constraint review_requires_two_matches check (
    (name_matched::int + phone_matched::int + email_matched::int) >= 2
  )
);

create index player_registration_reviews_status_idx
  on public.player_registration_reviews(status, created_at);

alter table public.players enable row level security;
alter table public.player_registration_reviews enable row level security;

create policy players_select_self_or_admin on public.players
for select to authenticated
using (user_id = (select auth.uid()) or public.has_platform_role());

create policy player_registration_reviews_admin_only on public.player_registration_reviews
for select to authenticated
using (public.has_platform_role());

-- Full name is immutable after initial registration. Admin corrections must use
-- a separate audited process rather than ordinary profile updates.
create or replace function public.prevent_player_name_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.full_name is distinct from old.full_name then
    raise exception 'Registered player name cannot be changed';
  end if;
  return new;
end;
$$;

create trigger players_name_immutable
before update on public.players
for each row execute function public.prevent_player_name_change();

create trigger players_set_updated_at
before update on public.players
for each row execute function public.set_updated_at();

-- Registration is performed atomically on the server. Matching metrics are
-- counted independently across existing player records. A single metric never
-- triggers review, including a match against a banned player.
create or replace function public.register_player(
  p_full_name text,
  p_phone text,
  p_email text,
  p_date_of_birth date
)
returns public.players
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_auth_email text;
  v_name_match boolean;
  v_phone_match boolean;
  v_email_match boolean;
  v_match_count integer;
  v_player public.players;
  v_matched_ids uuid[];
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  if nullif(trim(p_full_name), '') is null
     or nullif(trim(p_phone), '') is null
     or nullif(trim(p_email), '') is null
     or p_date_of_birth is null then
    raise exception 'Full name, phone, email and date of birth are required';
  end if;

  if p_date_of_birth > current_date or p_date_of_birth < date '1900-01-01' then
    raise exception 'Date of birth is invalid';
  end if;

  select lower(trim(u.email)) into v_auth_email
  from auth.users u
  where u.id = v_user_id;

  if v_auth_email is null or lower(trim(p_email)) <> v_auth_email then
    raise exception 'Registration email must match the signed-in account email';
  end if;

  if exists (select 1 from public.players p where p.user_id = v_user_id) then
    raise exception 'Player registration has already been submitted';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('openplay-player-registration', 0));

  select
    exists (select 1 from public.players p where lower(trim(p.full_name)) = lower(trim(p_full_name))),
    exists (select 1 from public.players p where regexp_replace(p.phone, '[^0-9]', '', 'g') = regexp_replace(p_phone, '[^0-9]', '', 'g')),
    exists (select 1 from public.players p where lower(trim(p.email)) = lower(trim(p_email)))
  into v_name_match, v_phone_match, v_email_match;

  v_match_count := (case when v_name_match then 1 else 0 end)
    + (case when v_phone_match then 1 else 0 end)
    + (case when v_email_match then 1 else 0 end);

  select coalesce(array_agg(distinct p.id), '{}'::uuid[])
  into v_matched_ids
  from public.players p
  where (v_name_match and lower(trim(p.full_name)) = lower(trim(p_full_name)))
     or (v_phone_match and regexp_replace(p.phone, '[^0-9]', '', 'g') = regexp_replace(p_phone, '[^0-9]', '', 'g'))
     or (v_email_match and lower(trim(p.email)) = lower(trim(p_email)));

  insert into public.players (
    user_id, full_name, phone, email, date_of_birth, registration_status
  ) values (
    v_user_id,
    trim(p_full_name),
    trim(p_phone),
    lower(trim(p_email)),
    p_date_of_birth,
    case when v_match_count >= 2
      then 'pending_review'::public.player_registration_status
      else 'registered'::public.player_registration_status
    end
  )
  returning * into v_player;

  if v_match_count >= 2 then
    insert into public.player_registration_reviews (
      player_id, name_matched, phone_matched, email_matched, matched_player_ids
    ) values (
      v_player.id, v_name_match, v_phone_match, v_email_match, v_matched_ids
    );
  end if;

  insert into public.audit_log (
    actor_user_id, action, entity_type, entity_id, after_data
  ) values (
    v_user_id,
    case when v_match_count >= 2 then 'player.registration.flagged' else 'player.registration.approved' end,
    'player',
    v_player.id::text,
    jsonb_build_object(
      'registration_status', v_player.registration_status,
      'name_matched', v_name_match,
      'phone_matched', v_phone_match,
      'email_matched', v_email_match
    )
  );

  return v_player;
end;
$$;

revoke all on function public.register_player(text, text, text, date) from public;
grant execute on function public.register_player(text, text, text, date) to authenticated;

-- Admin decision for a flagged registration. The player remains unable to join
-- a team until this function approves the review.
create or replace function public.resolve_player_registration_review(
  p_player_id uuid,
  p_decision text,
  p_reason text default null
)
returns public.players
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_player public.players;
  v_review public.player_registration_reviews;
begin
  if v_actor is null or not public.has_platform_role() then
    raise exception 'Administrator permission required';
  end if;

  if p_decision not in ('approved', 'rejected') then
    raise exception 'Decision must be approved or rejected';
  end if;

  select * into v_review
  from public.player_registration_reviews
  where player_id = p_player_id and status = 'pending'
  for update;

  if not found then
    raise exception 'No pending registration review exists';
  end if;

  update public.players
  set registration_status = case
    when p_decision = 'approved' then 'registered'::public.player_registration_status
    else 'rejected'::public.player_registration_status
  end
  where id = p_player_id
  returning * into v_player;

  update public.player_registration_reviews
  set status = p_decision,
      reviewed_by = v_actor,
      reviewed_at = now(),
      review_reason = nullif(trim(p_reason), '')
  where id = v_review.id;

  insert into public.audit_log (
    actor_user_id, action, entity_type, entity_id, reason, after_data
  ) values (
    v_actor,
    'player.registration.' || p_decision,
    'player',
    p_player_id::text,
    nullif(trim(p_reason), ''),
    jsonb_build_object('registration_status', v_player.registration_status)
  );

  return v_player;
end;
$$;

revoke all on function public.resolve_player_registration_review(uuid, text, text) from public;
grant execute on function public.resolve_player_registration_review(uuid, text, text) to authenticated;

-- A registered player may request membership. Pending-review or rejected
-- registrations cannot pass this server-side gate.
create or replace function public.request_team_membership(p_season_team_id uuid)
returns public.team_memberships
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_player_status public.player_registration_status;
  v_membership public.team_memberships;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  select registration_status into v_player_status
  from public.players
  where user_id = v_user_id;

  if v_player_status is distinct from 'registered'::public.player_registration_status then
    raise exception 'Player registration must be approved before joining a team';
  end if;

  if not exists (
    select 1 from public.season_teams st
    join public.seasons s on s.id = st.season_id
    where st.id = p_season_team_id
      and st.registration_status = 'approved'
      and s.status = 'registration_open'
  ) then
    raise exception 'This team is not currently accepting player requests';
  end if;

  insert into public.team_memberships (season_team_id, user_id, status)
  values (p_season_team_id, v_user_id, 'pending')
  on conflict (season_team_id, user_id) do update
    set status = 'pending', updated_at = now()
    where public.team_memberships.status in ('left')
  returning * into v_membership;

  if v_membership.id is null then
    raise exception 'A membership or request already exists for this team';
  end if;

  insert into public.audit_log(actor_user_id, action, entity_type, entity_id)
  values (v_user_id, 'team.membership.requested', 'team_membership', v_membership.id::text);

  return v_membership;
end;
$$;

revoke all on function public.request_team_membership(uuid) from public;
grant execute on function public.request_team_membership(uuid) to authenticated;

-- Captains can decide only requests for their own active team.
create or replace function public.resolve_team_membership_request(
  p_membership_id uuid,
  p_decision text
)
returns public.team_memberships
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_membership public.team_memberships;
begin
  if v_actor is null then
    raise exception 'Authentication required';
  end if;
  if p_decision not in ('approved', 'rejected') then
    raise exception 'Decision must be approved or rejected';
  end if;

  select * into v_membership
  from public.team_memberships
  where id = p_membership_id and status = 'pending'
  for update;

  if not found then
    raise exception 'No pending team request exists';
  end if;

  if not public.has_platform_role()
     and not public.is_active_team_captain(v_membership.season_team_id) then
    raise exception 'Captain permission required';
  end if;

  update public.team_memberships
  set status = case when p_decision = 'approved'
      then 'active'::public.membership_status
      else 'left'::public.membership_status
    end,
    joined_at = case when p_decision = 'approved' then now() else joined_at end,
    left_at = case when p_decision = 'rejected' then now() else left_at end
  where id = p_membership_id
  returning * into v_membership;

  insert into public.audit_log(actor_user_id, action, entity_type, entity_id)
  values (v_actor, 'team.membership.' || p_decision, 'team_membership', p_membership_id::text);

  return v_membership;
end;
$$;

revoke all on function public.resolve_team_membership_request(uuid, text) from public;
grant execute on function public.resolve_team_membership_request(uuid, text) to authenticated;

-- No direct client writes to permanent player identities or review decisions.
