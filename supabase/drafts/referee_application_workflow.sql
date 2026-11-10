-- Draft source consumed by the pinned Supabase CLI in CI.
-- The committed migration filename is generated with `supabase migration new`.

create table public.referee_applications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  experience_summary text not null
    check (length(btrim(experience_summary)) between 1 and 2000),
  qualifications text[] not null default '{}'::text[]
    check (cardinality(qualifications) <= 20),
  availability jsonb not null
    check (jsonb_typeof(availability) = 'array'),
  contact_phone text not null
    check (length(btrim(contact_phone)) between 7 and 40),
  preferred_location_ids uuid[] not null
    check (cardinality(preferred_location_ids) between 1 and 10
      and array_position(preferred_location_ids, null) is null),
  additional_notes text
    check (additional_notes is null or length(additional_notes) <= 2000),
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references auth.users(id) on delete restrict,
  review_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint referee_application_review_state_check check (
    (status = 'pending' and reviewed_at is null and reviewed_by is null)
    or
    (status <> 'pending' and reviewed_at is not null and reviewed_by is not null)
  )
);

create unique index referee_applications_one_pending_per_user
  on public.referee_applications(user_id)
  where status = 'pending';
create index referee_applications_status_submitted_idx
  on public.referee_applications(status, submitted_at desc);
create index referee_applications_user_submitted_idx
  on public.referee_applications(user_id, submitted_at desc);

create table public.referee_memberships (
  user_id uuid primary key references auth.users(id) on delete restrict,
  application_id uuid not null unique references public.referee_applications(id) on delete restrict,
  status text not null default 'active'
    check (status in ('active', 'suspended')),
  approved_at timestamptz not null default now(),
  approved_by uuid not null references auth.users(id) on delete restrict,
  status_changed_at timestamptz not null default now(),
  status_changed_by uuid not null references auth.users(id) on delete restrict,
  status_reason text not null
    check (length(btrim(status_reason)) between 5 and 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index referee_memberships_status_idx
  on public.referee_memberships(status, approved_at desc);

alter table public.referee_applications enable row level security;
alter table public.referee_memberships enable row level security;

revoke all on public.referee_applications from anon, authenticated;
revoke all on public.referee_memberships from anon, authenticated;
grant select on public.referee_applications to authenticated;
grant select on public.referee_memberships to authenticated;

create policy referee_applications_select_owner_or_location_admin
  on public.referee_applications
  for select
  to authenticated
  using (
    user_id = (select auth.uid())
    or public.has_global_admin_role()
    or exists (
      select 1
      from unnest(preferred_location_ids) as preferred(location_id)
      where public.can_administer_location(preferred.location_id)
    )
  );

create policy referee_memberships_select_owner_or_location_admin
  on public.referee_memberships
  for select
  to authenticated
  using (
    user_id = (select auth.uid())
    or exists (
      select 1
      from public.referee_applications application
      cross join lateral unnest(application.preferred_location_ids) as preferred(location_id)
      where application.id = referee_memberships.application_id
        and (
          public.has_global_admin_role()
          or public.can_administer_location(preferred.location_id)
        )
    )
  );

create or replace function public.submit_referee_application(
  p_experience_summary text,
  p_qualifications text[],
  p_availability jsonb,
  p_contact_phone text,
  p_preferred_location_ids uuid[],
  p_additional_notes text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_application_id uuid;
  v_slot jsonb;
  v_qualifications text[];
  v_location_count integer;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  if not exists (
    select 1
    from public.players player
    where player.user_id = v_user_id
      and player.registration_status::text = 'registered'
      and player.is_banned = false
  ) then
    raise exception 'An active, registered and unrestricted player account is required to apply';
  end if;

  if exists (
    select 1
    from public.referee_memberships membership
    where membership.user_id = v_user_id
  ) then
    raise exception 'A referee membership already exists; contact an administrator if it needs reinstating';
  end if;

  if length(btrim(coalesce(p_experience_summary, ''))) not between 1 and 2000 then
    raise exception 'Experience summary must be between 1 and 2,000 characters';
  end if;

  if coalesce(cardinality(p_qualifications), 0) > 20
     or exists (
       select 1
       from unnest(coalesce(p_qualifications, '{}'::text[])) as q(qualification)
       where length(btrim(coalesce(q.qualification, ''))) > 120
     ) then
    raise exception 'Qualifications must contain no more than 20 entries of 120 characters each';
  end if;

  select coalesce(array_agg(distinct btrim(qualification)), '{}'::text[])
    into v_qualifications
  from unnest(coalesce(p_qualifications, '{}'::text[])) as q(qualification)
  where length(btrim(coalesce(q.qualification, ''))) > 0;

  if p_availability is null or jsonb_typeof(p_availability) <> 'array' then
    raise exception 'Availability must be supplied as a list of windows';
  end if;
  if jsonb_array_length(p_availability) not between 1 and 21 then
    raise exception 'Add between one and 21 availability windows';
  end if;

  for v_slot in
    select value from jsonb_array_elements(p_availability)
  loop
    if jsonb_typeof(v_slot) <> 'object'
       or coalesce(v_slot->>'weekday', '') !~ '^[1-7]$'
       or coalesce(v_slot->>'start_time', '') !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
       or coalesce(v_slot->>'end_time', '') !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
       or (v_slot->>'start_time') >= (v_slot->>'end_time') then
      raise exception 'Availability must use ISO weekdays and valid 24-hour windows with start before end';
    end if;
  end loop;

  if exists (
    with slots as (
      select
        (value->>'weekday')::integer as weekday,
        (value->>'start_time')::time as starts_at,
        (value->>'end_time')::time as ends_at,
        ordinality
      from jsonb_array_elements(p_availability) with ordinality
    )
    select 1
    from slots first_slot
    join slots second_slot
      on second_slot.weekday = first_slot.weekday
     and second_slot.ordinality > first_slot.ordinality
     and first_slot.starts_at < second_slot.ends_at
     and second_slot.starts_at < first_slot.ends_at
  ) then
    raise exception 'Availability windows on the same day must not overlap';
  end if;

  if length(btrim(coalesce(p_contact_phone, ''))) not between 7 and 40 then
    raise exception 'A valid contact telephone number is required';
  end if;

  if p_preferred_location_ids is null
     or cardinality(p_preferred_location_ids) not between 1 and 10
     or array_position(p_preferred_location_ids, null) is not null
     or cardinality(p_preferred_location_ids) <>
        (select count(distinct ids.location_id) from unnest(p_preferred_location_ids) as ids(location_id)) then
    raise exception 'Choose between one and ten distinct preferred locations';
  end if;

  select count(*) into v_location_count
  from unnest(p_preferred_location_ids) as preferred(preferred_location_id)
  join public.locations location
    on location.id = preferred.preferred_location_id
   and location.is_active = true;

  if v_location_count <> cardinality(p_preferred_location_ids) then
    raise exception 'Every preferred location must be active';
  end if;

  if p_additional_notes is not null and length(p_additional_notes) > 2000 then
    raise exception 'Additional notes must be 2,000 characters or fewer';
  end if;

  insert into public.referee_applications (
    user_id,
    experience_summary,
    qualifications,
    availability,
    contact_phone,
    preferred_location_ids,
    additional_notes
  ) values (
    v_user_id,
    btrim(p_experience_summary),
    v_qualifications,
    p_availability,
    public.normalize_player_phone(btrim(p_contact_phone)),
    p_preferred_location_ids,
    nullif(btrim(coalesce(p_additional_notes, '')), '')
  )
  returning id into v_application_id;

  insert into public.audit_log (
    actor_user_id, action, entity_type, entity_id, after_data, reason
  ) values (
    v_user_id,
    'referee.application_submitted',
    'referee_application',
    v_application_id::text,
    jsonb_build_object(
      'status', 'pending',
      'preferred_location_ids', p_preferred_location_ids
    ),
    'Referee application submitted'
  );

  return v_application_id;
end;
$$;

revoke all on function public.submit_referee_application(text,text[],jsonb,text,uuid[],text)
  from public, anon;
grant execute on function public.submit_referee_application(text,text[],jsonb,text,uuid[],text)
  to authenticated;

create or replace function public.review_referee_application(
  p_application_id uuid,
  p_decision text,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_application public.referee_applications;
begin
  if v_actor is null then
    raise exception 'Authentication required';
  end if;
  if p_decision is null or p_decision not in ('approved', 'rejected') then
    raise exception 'Decision must be approved or rejected';
  end if;
  if length(btrim(coalesce(p_reason, ''))) not between 5 and 500 then
    raise exception 'A review reason of 5 to 500 characters is required';
  end if;

  select * into v_application
  from public.referee_applications
  where id = p_application_id
  for update;
  if not found then
    raise exception 'Referee application not found';
  end if;
  if v_application.status <> 'pending' then
    raise exception 'Only pending referee applications can be reviewed';
  end if;

  if not public.has_global_admin_role()
     and not exists (
       select 1
       from unnest(v_application.preferred_location_ids) preferred(location_id)
       where public.can_administer_location(preferred.location_id)
     ) then
    raise exception 'Administrator access to a preferred location is required';
  end if;

  if p_decision = 'approved' then
    if not exists (
      select 1
      from public.players player
      where player.user_id = v_application.user_id
        and player.registration_status::text = 'registered'
        and player.is_banned = false
    ) then
      raise exception 'Applicant is no longer eligible for referee approval';
    end if;

    insert into public.referee_memberships (
      user_id, application_id, status, approved_by,
      status_changed_by, status_reason
    ) values (
      v_application.user_id, v_application.id, 'active', v_actor,
      v_actor, btrim(p_reason)
    );
  end if;

  update public.referee_applications
  set status = p_decision,
      reviewed_at = now(),
      reviewed_by = v_actor,
      review_reason = btrim(p_reason),
      updated_at = now()
  where id = v_application.id;

  insert into public.audit_log (
    actor_user_id, action, entity_type, entity_id, before_data, after_data, reason
  ) values (
    v_actor,
    case when p_decision = 'approved'
      then 'referee.application_approved'
      else 'referee.application_rejected'
    end,
    'referee_application',
    v_application.id::text,
    jsonb_build_object('status', v_application.status),
    jsonb_build_object('status', p_decision, 'user_id', v_application.user_id),
    btrim(p_reason)
  );
end;
$$;

revoke all on function public.review_referee_application(uuid,text,text)
  from public, anon;
grant execute on function public.review_referee_application(uuid,text,text)
  to authenticated;

create or replace function public.set_referee_membership_status(
  p_user_id uuid,
  p_status text,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_membership public.referee_memberships;
  v_application public.referee_applications;
begin
  if v_actor is null then
    raise exception 'Authentication required';
  end if;
  if p_status is null or p_status not in ('active', 'suspended') then
    raise exception 'Referee status must be active or suspended';
  end if;
  if length(btrim(coalesce(p_reason, ''))) not between 5 and 500 then
    raise exception 'A reason of 5 to 500 characters is required';
  end if;

  select * into v_membership
  from public.referee_memberships
  where user_id = p_user_id
  for update;
  if not found then
    raise exception 'Referee membership not found';
  end if;

  select * into v_application
  from public.referee_applications
  where id = v_membership.application_id;

  if not public.has_global_admin_role()
     and not exists (
       select 1
       from unnest(v_application.preferred_location_ids) preferred(location_id)
       where public.can_administer_location(preferred.location_id)
     ) then
    raise exception 'Administrator access to a preferred location is required';
  end if;

  if v_membership.status = p_status then
    return;
  end if;

  update public.referee_memberships
  set status = p_status,
      status_changed_at = now(),
      status_changed_by = v_actor,
      status_reason = btrim(p_reason),
      updated_at = now()
  where user_id = p_user_id;

  insert into public.audit_log (
    actor_user_id, action, entity_type, entity_id, before_data, after_data, reason
  ) values (
    v_actor,
    case when p_status = 'suspended'
      then 'referee.membership_suspended'
      else 'referee.membership_reinstated'
    end,
    'referee_membership',
    p_user_id::text,
    jsonb_build_object('status', v_membership.status),
    jsonb_build_object('status', p_status),
    btrim(p_reason)
  );
end;
$$;

revoke all on function public.set_referee_membership_status(uuid,text,text)
  from public, anon;
grant execute on function public.set_referee_membership_status(uuid,text,text)
  to authenticated;


create or replace function public.get_my_referee_portal_state()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_application jsonb;
  v_membership jsonb;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  select jsonb_build_object(
    'id',application.id,
    'status',application.status,
    'experience_summary',application.experience_summary,
    'qualifications',application.qualifications,
    'availability',application.availability,
    'contact_phone',application.contact_phone,
    'preferred_location_ids',application.preferred_location_ids,
    'additional_notes',application.additional_notes,
    'submitted_at',application.submitted_at,
    'reviewed_at',application.reviewed_at,
    'review_reason',application.review_reason
  )
  into v_application
  from public.referee_applications application
  where application.user_id=v_user_id
  order by application.submitted_at desc
  limit 1;

  select jsonb_build_object(
    'status',membership.status,
    'approved_at',membership.approved_at,
    'status_changed_at',membership.status_changed_at,
    'status_reason',membership.status_reason
  )
  into v_membership
  from public.referee_memberships membership
  where membership.user_id=v_user_id;

  return jsonb_build_object(
    'application',v_application,
    'membership',v_membership
  );
end;
$$;
revoke all on function public.get_my_referee_portal_state() from public,anon;
grant execute on function public.get_my_referee_portal_state() to authenticated;

create or replace function public.get_active_referee_locations()
returns table(id uuid,name text,town text,region text)
language sql
stable
security definer
set search_path = ''
as $$
  select location.id,location.name,location.town,location.region
  from public.locations location
  where location.is_active=true
  order by location.name
$$;
revoke all on function public.get_active_referee_locations() from public,anon;
grant execute on function public.get_active_referee_locations() to authenticated;
