-- Referee membership is granted only after a global administrator approves an application.
-- Referees are deliberately excluded from all administrator role helpers.

alter table public.user_roles
  drop constraint if exists user_roles_role_check;

alter table public.user_roles
  add constraint user_roles_role_check
  check (role = any (array['admin'::text, 'super_admin'::text, 'finance_admin'::text, 'league_admin'::text, 'referee'::text]));

create table public.referee_applications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  full_name text not null check (char_length(btrim(full_name)) between 2 and 100),
  phone text not null check (char_length(btrim(phone)) between 7 and 30),
  experience text not null check (char_length(btrim(experience)) between 10 and 3000),
  qualifications text not null default '' check (char_length(qualifications) <= 2000),
  availability text not null check (char_length(btrim(availability)) between 3 and 1000),
  preferred_locations text[] not null default '{}'::text[]
    check (cardinality(preferred_locations) <= 10),
  additional_notes text not null default '' check (char_length(additional_notes) <= 2000),
  status text not null default 'pending'
    check (status = any (array['pending'::text, 'approved'::text, 'rejected'::text])),
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references auth.users(id) on delete set null,
  review_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    (status = 'pending' and reviewed_at is null and reviewed_by is null)
    or
    (status in ('approved','rejected') and reviewed_at is not null and reviewed_by is not null)
  )
);

create index referee_applications_status_submitted_idx
  on public.referee_applications(status, submitted_at desc);

alter table public.referee_applications enable row level security;
revoke all on table public.referee_applications from public, anon, authenticated;

create or replace function public.has_referee_role()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.user_roles ur
    join public.referee_applications ra on ra.user_id = ur.user_id
    where ur.user_id = (select auth.uid())
      and ur.role = 'referee'
      and ra.status = 'approved'
  );
$$;

create or replace function public.get_my_referee_application()
returns table (
  id uuid,
  full_name text,
  phone text,
  experience text,
  qualifications text,
  availability text,
  preferred_locations text[],
  additional_notes text,
  status text,
  submitted_at timestamptz,
  reviewed_at timestamptz,
  review_reason text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication is required';
  end if;

  return query
  select ra.id, ra.full_name, ra.phone, ra.experience, ra.qualifications,
         ra.availability, ra.preferred_locations, ra.additional_notes,
         ra.status, ra.submitted_at, ra.reviewed_at, ra.review_reason
  from public.referee_applications ra
  where ra.user_id = (select auth.uid());
end;
$$;

create or replace function public.submit_referee_application(
  p_full_name text,
  p_phone text,
  p_experience text,
  p_qualifications text default '',
  p_availability text default '',
  p_preferred_locations text[] default '{}'::text[],
  p_additional_notes text default ''
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_application public.referee_applications%rowtype;
  v_locations text[];
  v_was_rejected boolean := false;
begin
  if v_user_id is null then
    raise exception 'Authentication is required';
  end if;

  if not exists (
    select 1 from auth.users u
    where u.id = v_user_id and u.email_confirmed_at is not null
  ) then
    raise exception 'Verify your email address before applying to become an Open Play referee';
  end if;

  if char_length(btrim(coalesce(p_full_name, ''))) not between 2 and 100 then
    raise exception 'Enter your full name';
  end if;
  if char_length(btrim(coalesce(p_phone, ''))) not between 7 and 30 then
    raise exception 'Enter a valid contact telephone number';
  end if;
  if char_length(btrim(coalesce(p_experience, ''))) not between 10 and 3000 then
    raise exception 'Tell us a little about your refereeing or football experience';
  end if;
  if char_length(coalesce(p_qualifications, '')) > 2000
     or char_length(btrim(coalesce(p_availability, ''))) not between 3 and 1000
     or char_length(coalesce(p_additional_notes, '')) > 2000 then
    raise exception 'One or more application fields are invalid';
  end if;
  if cardinality(coalesce(p_preferred_locations, '{}'::text[])) > 10 then
    raise exception 'Choose no more than 10 preferred locations';
  end if;

  select coalesce(array_agg(distinct btrim(location_name)), '{}'::text[])
  into v_locations
  from unnest(coalesce(p_preferred_locations, '{}'::text[])) as location_name
  where char_length(btrim(location_name)) between 1 and 80;

  select * into v_application
  from public.referee_applications
  where user_id = v_user_id
  for update;

  if found then
    if v_application.status = 'approved' then
      raise exception 'Your referee application has already been approved';
    end if;
    if v_application.status = 'pending' then
      raise exception 'You already have a referee application awaiting review';
    end if;
    v_was_rejected := v_application.status = 'rejected';

    update public.referee_applications
    set full_name = btrim(p_full_name),
        phone = btrim(p_phone),
        experience = btrim(p_experience),
        qualifications = btrim(coalesce(p_qualifications, '')),
        availability = btrim(p_availability),
        preferred_locations = v_locations,
        additional_notes = btrim(coalesce(p_additional_notes, '')),
        status = 'pending',
        submitted_at = now(),
        reviewed_at = null,
        reviewed_by = null,
        review_reason = null,
        updated_at = now()
    where id = v_application.id
    returning * into v_application;
  else
    insert into public.referee_applications (
      user_id, full_name, phone, experience, qualifications,
      availability, preferred_locations, additional_notes
    )
    values (
      v_user_id, btrim(p_full_name), btrim(p_phone), btrim(p_experience),
      btrim(coalesce(p_qualifications, '')), btrim(p_availability),
      v_locations, btrim(coalesce(p_additional_notes, ''))
    )
    returning * into v_application;
  end if;

  insert into public.audit_log(actor_user_id, action, entity_type, entity_id, reason, after_data)
  values (
    v_user_id,
    'referee.application.submitted',
    'referee_application',
    v_application.id::text,
    case when v_was_rejected then 'Resubmitted after rejection' else null end,
    jsonb_build_object('status', 'pending')
  );

  return v_application.id;
end;
$$;

create or replace function public.admin_get_referee_applications(p_status text default 'pending')
returns table (
  id uuid,
  user_id uuid,
  full_name text,
  email text,
  phone text,
  experience text,
  qualifications text,
  availability text,
  preferred_locations text[],
  additional_notes text,
  status text,
  submitted_at timestamptz,
  reviewed_at timestamptz,
  review_reason text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not public.has_global_admin_role() then
    raise exception 'Global administrator access is required';
  end if;
  if coalesce(p_status, 'pending') not in ('pending','approved','rejected','all') then
    raise exception 'Invalid referee application status';
  end if;

  return query
  select ra.id, ra.user_id, ra.full_name, u.email::text, ra.phone,
         ra.experience, ra.qualifications, ra.availability,
         ra.preferred_locations, ra.additional_notes, ra.status,
         ra.submitted_at, ra.reviewed_at, ra.review_reason
  from public.referee_applications ra
  join auth.users u on u.id = ra.user_id
  where coalesce(p_status, 'pending') = 'all' or ra.status = coalesce(p_status, 'pending')
  order by case when ra.status = 'pending' then 0 else 1 end, ra.submitted_at desc
  limit 200;
end;
$$;

create or replace function public.admin_resolve_referee_application(
  p_user_id uuid,
  p_decision text,
  p_reason text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_application public.referee_applications%rowtype;
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
begin
  if auth.uid() is null or not public.has_global_admin_role() then
    raise exception 'Global administrator access is required';
  end if;
  if p_decision not in ('approved','rejected') then
    raise exception 'Decision must be approved or rejected';
  end if;
  if p_decision = 'rejected' and char_length(coalesce(v_reason, '')) < 5 then
    raise exception 'Enter a rejection reason of at least 5 characters';
  end if;

  select * into v_application
  from public.referee_applications
  where user_id = p_user_id
  for update;

  if not found or v_application.status <> 'pending' then
    raise exception 'This referee application is no longer awaiting review';
  end if;

  update public.referee_applications
  set status = p_decision,
      reviewed_at = now(),
      reviewed_by = (select auth.uid()),
      review_reason = v_reason,
      updated_at = now()
  where id = v_application.id
  returning * into v_application;

  if p_decision = 'approved' then
    insert into public.user_roles(user_id, role, granted_by)
    values (v_application.user_id, 'referee', (select auth.uid()))
    on conflict (user_id, role) do nothing;
  else
    delete from public.user_roles
    where user_id = v_application.user_id and role = 'referee';
  end if;

  insert into public.audit_log(actor_user_id, action, entity_type, entity_id, reason, before_data, after_data)
  values (
    (select auth.uid()),
    case when p_decision = 'approved' then 'referee.application.approved' else 'referee.application.rejected' end,
    'referee_application',
    v_application.id::text,
    v_reason,
    jsonb_build_object('status', 'pending'),
    jsonb_build_object('status', p_decision, 'referee_role_granted', p_decision = 'approved')
  );

  return v_application.id;
end;
$$;

revoke all on function public.has_referee_role() from public, anon;
revoke all on function public.get_my_referee_application() from public, anon;
revoke all on function public.submit_referee_application(text,text,text,text,text,text[],text) from public, anon;
revoke all on function public.admin_get_referee_applications(text) from public, anon;
revoke all on function public.admin_resolve_referee_application(uuid,text,text) from public, anon;

grant execute on function public.has_referee_role() to authenticated;
grant execute on function public.get_my_referee_application() to authenticated;
grant execute on function public.submit_referee_application(text,text,text,text,text,text[],text) to authenticated;
grant execute on function public.admin_get_referee_applications(text) to authenticated;
grant execute on function public.admin_resolve_referee_application(uuid,text,text) to authenticated;
