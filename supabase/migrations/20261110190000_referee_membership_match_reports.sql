-- Referee membership, private fixture allocation and report approval workflow.
-- Forward-only migration. Referee is deliberately NOT a user_roles value:
-- user_roles grants platform administration privileges.

create table public.referee_applications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict,
  experience_summary text not null,
  qualifications text,
  availability_notes text,
  contact_phone text,
  preferred_location_ids uuid[] not null default '{}'::uuid[],
  status text not null default 'pending'
    check (status in ('pending','approved','rejected')),
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  review_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint referee_application_experience_length check (length(btrim(experience_summary)) between 10 and 3000),
  constraint referee_application_review_pair check (
    (status = 'pending' and reviewed_at is null)
    or (status <> 'pending' and reviewed_at is not null)
  ),
  constraint referee_application_reason_length check (
    review_reason is null or length(btrim(review_reason)) >= 5
  )
);
create index referee_applications_status_created_idx
  on public.referee_applications(status, created_at desc);
create unique index referee_applications_one_pending_per_user_idx
  on public.referee_applications(user_id) where status = 'pending';

create table public.referee_memberships (
  user_id uuid primary key references auth.users(id) on delete restrict,
  application_id uuid not null unique references public.referee_applications(id) on delete restrict,
  status text not null default 'active' check (status in ('active','suspended')),
  approved_by uuid not null references auth.users(id) on delete restrict,
  approved_at timestamptz not null default now(),
  suspended_by uuid references auth.users(id) on delete set null,
  suspended_at timestamptz,
  suspension_reason text,
  constraint referee_membership_suspension_pair check (
    (status = 'active' and suspended_at is null and suspended_by is null)
    or (status = 'suspended' and suspended_at is not null and suspended_by is not null)
  )
);
create index referee_memberships_status_idx on public.referee_memberships(status);

create table public.referee_availability (
  id uuid primary key default gen_random_uuid(),
  referee_user_id uuid not null references public.referee_memberships(user_id) on delete restrict,
  available_on date not null,
  starts_at time not null,
  ends_at time not null,
  location_id uuid not null references public.locations(id) on delete restrict,
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint referee_availability_time_order check (ends_at > starts_at),
  constraint referee_availability_unique_slot unique (referee_user_id, available_on, starts_at, ends_at, location_id)
);
create index referee_availability_location_date_idx
  on public.referee_availability(location_id, available_on, starts_at);

create table public.fixture_referee_assignments (
  id uuid primary key default gen_random_uuid(),
  fixture_id uuid not null references public.fixtures(id) on delete restrict,
  referee_user_id uuid not null references public.referee_memberships(user_id) on delete restrict,
  assigned_by uuid not null references auth.users(id) on delete restrict,
  assigned_at timestamptz not null default now(),
  removed_by uuid references auth.users(id) on delete set null,
  removed_at timestamptz,
  change_reason text,
  constraint fixture_referee_assignment_removal_pair check (
    (removed_at is null and removed_by is null)
    or (removed_at is not null and removed_by is not null)
  ),
  constraint fixture_referee_assignment_reason check (
    change_reason is null or length(btrim(change_reason)) >= 5
  )
);
create unique index fixture_referee_one_active_assignment_idx
  on public.fixture_referee_assignments(fixture_id) where removed_at is null;
create index fixture_referee_assignments_referee_active_idx
  on public.fixture_referee_assignments(referee_user_id, fixture_id) where removed_at is null;

create table public.referee_match_reports (
  id uuid primary key default gen_random_uuid(),
  fixture_id uuid not null unique references public.fixtures(id) on delete restrict,
  assignment_id uuid references public.fixture_referee_assignments(id) on delete restrict,
  assigned_referee_user_id uuid references public.referee_memberships(user_id) on delete restrict,
  reporter_user_id uuid not null references auth.users(id) on delete restrict,
  status text not null default 'draft'
    check (status in ('draft','submitted','returned','approved','rejected','unpublished','deleted')),
  completed_at timestamptz not null,
  submitted_at timestamptz,
  home_score smallint not null default 0 check (home_score >= 0),
  away_score smallint not null default 0 check (away_score >= 0),
  match_summary text,
  version integer not null default 1 check (version > 0),
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  review_reason text,
  soft_deleted_at timestamptz,
  soft_deleted_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint referee_report_submission_pair check (
    (status = 'draft' and submitted_at is null)
    or (status in ('submitted','returned','approved','rejected','unpublished','deleted') and submitted_at is not null)
  ),
  constraint referee_report_review_pair check (
    (status in ('approved','rejected','unpublished','deleted') and reviewed_at is not null and reviewed_by is not null)
    or (status in ('draft','submitted','returned') and reviewed_at is null)
  ),
  constraint referee_report_delete_pair check (
    (status = 'deleted' and soft_deleted_at is not null and soft_deleted_by is not null)
    or (status <> 'deleted' and soft_deleted_at is null and soft_deleted_by is null)
  ),
  constraint referee_report_review_reason check (
    review_reason is null or length(btrim(review_reason)) >= 5
  )
);
create index referee_match_reports_review_queue_idx
  on public.referee_match_reports(status, submitted_at) where status = 'submitted';

create table public.referee_match_report_goals (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.referee_match_reports(id) on delete restrict,
  credited_team_id uuid not null references public.season_teams(id) on delete restrict,
  scorer_team_id uuid references public.season_teams(id) on delete restrict,
  scorer_competition_player_id uuid references public.competition_player_identities(id) on delete restrict,
  is_own_goal boolean not null default false,
  created_at timestamptz not null default now(),
  constraint referee_report_goal_identity_check check (
    (is_own_goal is true)
    or (scorer_team_id is not null and scorer_competition_player_id is not null and scorer_team_id = credited_team_id)
  ),
  constraint referee_report_own_goal_team_check check (
    is_own_goal is false or scorer_team_id is null or scorer_team_id <> credited_team_id
  )
);
create index referee_report_goals_report_idx on public.referee_match_report_goals(report_id);

create table public.referee_match_report_incidents (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.referee_match_reports(id) on delete restrict,
  team_id uuid not null references public.season_teams(id) on delete restrict,
  recipient_category text not null
    check (recipient_category in ('registered_player','substitute_bench','supporter')),
  competition_player_id uuid references public.competition_player_identities(id) on delete restrict,
  squad_number_snapshot smallint,
  card_outcome text not null check (card_outcome in ('yellow','second_yellow_red','straight_red')),
  fine_amount_pence integer not null check (fine_amount_pence >= 0),
  finance_entry_id uuid references public.finance_entries(id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint referee_incident_squad_number check (
    squad_number_snapshot is null or squad_number_snapshot between 1 and 99
  ),
  constraint referee_incident_identity_category check (
    (recipient_category = 'supporter' and competition_player_id is null)
    or (recipient_category in ('registered_player','substitute_bench') and competition_player_id is not null)
  ),
  constraint referee_incident_fine_matches_card check (
    (card_outcome = 'yellow' and fine_amount_pence = 500)
    or (card_outcome = 'second_yellow_red' and fine_amount_pence = 1500)
    or (card_outcome = 'straight_red' and fine_amount_pence = 3000)
  )
);
create index referee_report_incidents_report_idx on public.referee_match_report_incidents(report_id);
create index referee_report_incidents_team_idx on public.referee_match_report_incidents(team_id);

create table public.referee_match_report_versions (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.referee_match_reports(id) on delete restrict,
  version integer not null check (version > 0),
  actor_user_id uuid references auth.users(id) on delete set null,
  action text not null check (action in ('draft_saved','submitted','returned','approved','rejected','admin_corrected','unpublished','soft_deleted')),
  snapshot jsonb not null,
  created_at timestamptz not null default now(),
  unique (report_id, version)
);
create index referee_report_versions_report_idx on public.referee_match_report_versions(report_id, version desc);

create table public.referee_payment_entitlements (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null unique references public.referee_match_reports(id) on delete restrict,
  referee_user_id uuid not null references public.referee_memberships(user_id) on delete restrict,
  gross_allocation_pence integer not null default 2200 check (gross_allocation_pence = 2200),
  minimum_net_pence integer not null default 2000 check (minimum_net_pence = 2000),
  actual_deductions_pence integer check (actual_deductions_pence is null or actual_deductions_pence >= 0),
  platform_top_up_pence integer not null default 0 check (platform_top_up_pence >= 0),
  net_entitlement_pence integer check (net_entitlement_pence is null or net_entitlement_pence >= 2000),
  status text not null default 'earned'
    check (status in ('earned','pending_transfer','transfer_failed','transferred','payout_pending','paid_out','adjustment_pending','reversed')),
  stripe_transfer_id text,
  stripe_payout_id text,
  paid_out_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index referee_payment_entitlements_referee_idx
  on public.referee_payment_entitlements(referee_user_id, created_at desc);

-- All referee data is intentionally accessed through narrowly scoped RPCs.
-- There are no direct client table policies; SECURITY DEFINER functions enforce roles.
do $$
declare v_table text;
begin
  foreach v_table in array array[
    'referee_applications','referee_memberships','referee_availability',
    'fixture_referee_assignments','referee_match_reports',
    'referee_match_report_goals','referee_match_report_incidents',
    'referee_match_report_versions','referee_payment_entitlements'
  ] loop
    execute format('alter table public.%I enable row level security', v_table);
    execute format('revoke all on public.%I from public, anon, authenticated', v_table);
  end loop;
end;
$$;

create or replace function public.is_active_referee()
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.referee_memberships rm
    where rm.user_id = auth.uid() and rm.status = 'active'
  );
$$;
revoke all on function public.is_active_referee() from public, anon;
grant execute on function public.is_active_referee() to authenticated;

create or replace function public.referee_submit_application(
  p_experience_summary text,
  p_qualifications text default null,
  p_availability_notes text default null,
  p_contact_phone text default null,
  p_preferred_location_ids uuid[] default '{}'::uuid[]
)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare v_actor uuid := auth.uid(); v_id uuid;
begin
  if v_actor is null then raise exception 'Authentication required'; end if;
  if public.is_active_referee() then raise exception 'You already have approved referee access'; end if;
  if p_experience_summary is null or length(btrim(p_experience_summary)) not between 10 and 3000 then
    raise exception 'Provide at least 10 characters describing your refereeing experience';
  end if;
  if exists (select 1 from public.referee_applications a where a.user_id=v_actor and a.status='pending') then
    raise exception 'You already have a pending referee application';
  end if;
  if exists (
    select 1 from unnest(coalesce(p_preferred_location_ids,'{}'::uuid[])) x
    where not exists (select 1 from public.locations l where l.id=x and l.is_active is true)
  ) then raise exception 'One or more selected referee locations are unavailable'; end if;
  insert into public.referee_applications(
    user_id,experience_summary,qualifications,availability_notes,contact_phone,preferred_location_ids
  ) values (
    v_actor,btrim(p_experience_summary),nullif(btrim(p_qualifications),''),nullif(btrim(p_availability_notes),''),
    nullif(btrim(p_contact_phone),''),coalesce(p_preferred_location_ids,'{}'::uuid[])
  ) returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.referee_submit_application(text,text,text,text,uuid[]) from public, anon;
grant execute on function public.referee_submit_application(text,text,text,text,uuid[]) to authenticated;

create or replace function public.admin_list_referee_applications(p_status text default 'pending')
returns table(
  application_id uuid,user_id uuid,experience_summary text,qualifications text,
  availability_notes text,contact_phone text,preferred_location_ids uuid[],
  status text,created_at timestamptz
)
language plpgsql stable security definer set search_path = ''
as $$
begin
  if auth.uid() is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  if p_status not in ('pending','approved','rejected','all') then raise exception 'Invalid application status'; end if;
  return query
  select a.id,a.user_id,a.experience_summary,a.qualifications,a.availability_notes,a.contact_phone,
    a.preferred_location_ids,a.status,a.created_at
  from public.referee_applications a
  where (p_status='all' or a.status=p_status)
    and (
      public.has_global_admin_role()
      or exists (
        select 1 from unnest(a.preferred_location_ids) loc_id
        where public.can_administer_location(loc_id)
      )
    )
  order by case when a.status='pending' then 0 else 1 end,a.created_at;
end;
$$;
revoke all on function public.admin_list_referee_applications(text) from public, anon;
grant execute on function public.admin_list_referee_applications(text) to authenticated;

create or replace function public.admin_review_referee_application(
  p_application_id uuid,p_decision text,p_reason text
)
returns public.referee_applications
language plpgsql security definer set search_path = ''
as $$
declare v_actor uuid:=auth.uid(); v_app public.referee_applications; v_location uuid;
begin
  if v_actor is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  if p_decision not in ('approved','rejected') then raise exception 'Decision must be approved or rejected'; end if;
  if p_reason is null or length(btrim(p_reason))<5 then raise exception 'Enter a reason of at least 5 characters'; end if;
  select * into v_app from public.referee_applications where id=p_application_id for update;
  if not found then raise exception 'Referee application not found'; end if;
  if v_app.status<>'pending' then raise exception 'This referee application has already been reviewed'; end if;
  if not public.has_global_admin_role() and not exists (
    select 1 from unnest(v_app.preferred_location_ids) loc_id
    where public.can_administer_location(loc_id)
  ) then raise exception 'You are not assigned to any location selected by this applicant'; end if;
  update public.referee_applications
  set status=p_decision,reviewed_by=v_actor,reviewed_at=now(),review_reason=btrim(p_reason),updated_at=now()
  where id=p_application_id returning * into v_app;
  if p_decision='approved' then
    insert into public.referee_memberships(user_id,application_id,status,approved_by,approved_at)
    values(v_app.user_id,v_app.id,'active',v_actor,now())
    on conflict(user_id) do update set application_id=excluded.application_id,status='active',
      approved_by=excluded.approved_by,approved_at=excluded.approved_at,
      suspended_by=null,suspended_at=null,suspension_reason=null;
  end if;
  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,after_data)
  values(v_actor,'referee.application.'||p_decision,'referee_application',v_app.id::text,btrim(p_reason),
    jsonb_build_object('user_id',v_app.user_id,'status',p_decision,'preferred_location_ids',v_app.preferred_location_ids));
  return v_app;
end;
$$;
revoke all on function public.admin_review_referee_application(uuid,text,text) from public, anon;
grant execute on function public.admin_review_referee_application(uuid,text,text) to authenticated;

create or replace function public.referee_save_availability(
  p_available_on date,p_starts_at time,p_ends_at time,p_location_id uuid,p_note text default null
)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare v_actor uuid:=auth.uid(); v_id uuid;
begin
  if v_actor is null or not public.is_active_referee() then raise exception 'Approved referee membership required'; end if;
  if p_available_on < current_date then raise exception 'Availability cannot be entered for a past date'; end if;
  if p_ends_at <= p_starts_at then raise exception 'Availability end time must be after its start time'; end if;
  if not exists(select 1 from public.locations l where l.id=p_location_id and l.is_active is true) then
    raise exception 'Selected location is not active';
  end if;
  insert into public.referee_availability(referee_user_id,available_on,starts_at,ends_at,location_id,note)
  values(v_actor,p_available_on,p_starts_at,p_ends_at,p_location_id,nullif(btrim(p_note),''))
  on conflict(referee_user_id,available_on,starts_at,ends_at,location_id)
  do update set note=excluded.note,updated_at=now()
  returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.referee_save_availability(date,time,time,uuid,text) from public, anon;
grant execute on function public.referee_save_availability(date,time,time,uuid,text) to authenticated;

create or replace function public.referee_get_availability()
returns table(id uuid,available_on date,starts_at time,ends_at time,location_id uuid,location_name text,note text)
language plpgsql stable security definer set search_path = ''
as $$
begin
  if auth.uid() is null or not public.is_active_referee() then raise exception 'Approved referee membership required'; end if;
  return query
  select a.id,a.available_on,a.starts_at,a.ends_at,a.location_id,l.name,a.note
  from public.referee_availability a join public.locations l on l.id=a.location_id
  where a.referee_user_id=auth.uid() and a.available_on>=current_date
  order by a.available_on,a.starts_at;
end;
$$;
revoke all on function public.referee_get_availability() from public, anon;
grant execute on function public.referee_get_availability() to authenticated;

create or replace function public.admin_assign_referee(
  p_fixture_id uuid,p_referee_user_id uuid,p_reason text default null
)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare v_actor uuid:=auth.uid(); v_location uuid; v_assignment_id uuid;
begin
  if v_actor is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  if p_reason is not null and length(btrim(p_reason))<5 then raise exception 'Enter a reason of at least 5 characters'; end if;
  select l.location_id into v_location
  from public.fixtures f join public.seasons s on s.id=f.season_id join public.leagues l on l.id=s.league_id
  where f.id=p_fixture_id and f.status in ('scheduled','in_progress');
  if v_location is null then raise exception 'Scheduled fixture not found'; end if;
  if not public.can_administer_location(v_location) then raise exception 'You are not assigned to this location'; end if;
  if not exists(select 1 from public.referee_memberships rm where rm.user_id=p_referee_user_id and rm.status='active') then
    raise exception 'Only an approved active referee can be assigned';
  end if;
  update public.fixture_referee_assignments
  set removed_at=now(),removed_by=v_actor,change_reason=coalesce(nullif(btrim(p_reason),''),'Reassigned by administrator')
  where fixture_id=p_fixture_id and removed_at is null;
  insert into public.fixture_referee_assignments(fixture_id,referee_user_id,assigned_by,change_reason)
  values(p_fixture_id,p_referee_user_id,v_actor,nullif(btrim(p_reason),'')) returning id into v_assignment_id;
  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,after_data)
  values(v_actor,'referee.fixture.assigned','fixture_referee_assignment',v_assignment_id::text,
    coalesce(nullif(btrim(p_reason),''),'Referee assigned'),
    jsonb_build_object('fixture_id',p_fixture_id,'referee_user_id',p_referee_user_id));
  return v_assignment_id;
end;
$$;
revoke all on function public.admin_assign_referee(uuid,uuid,text) from public, anon;
grant execute on function public.admin_assign_referee(uuid,uuid,text) to authenticated;

create or replace function public.admin_remove_referee_assignment(p_assignment_id uuid,p_reason text)
returns boolean
language plpgsql security definer set search_path = ''
as $$
declare v_actor uuid:=auth.uid(); v_fixture_id uuid; v_location uuid;
begin
  if v_actor is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  if p_reason is null or length(btrim(p_reason))<5 then raise exception 'Enter a reason of at least 5 characters'; end if;
  select a.fixture_id,l.location_id into v_fixture_id,v_location
  from public.fixture_referee_assignments a
  join public.fixtures f on f.id=a.fixture_id
  join public.seasons s on s.id=f.season_id
  join public.leagues l on l.id=s.league_id
  where a.id=p_assignment_id and a.removed_at is null for update of a;
  if not found then raise exception 'Active referee assignment not found'; end if;
  if not public.can_administer_location(v_location) then raise exception 'You are not assigned to this location'; end if;
  update public.fixture_referee_assignments set removed_at=now(),removed_by=v_actor,change_reason=btrim(p_reason)
  where id=p_assignment_id;
  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,after_data)
  values(v_actor,'referee.fixture.assignment_removed','fixture_referee_assignment',p_assignment_id::text,btrim(p_reason),
    jsonb_build_object('fixture_id',v_fixture_id));
  return true;
end;
$$;
revoke all on function public.admin_remove_referee_assignment(uuid,text) from public, anon;
grant execute on function public.admin_remove_referee_assignment(uuid,text) to authenticated;

create or replace function public.admin_list_referee_assignments(p_location_id uuid default null)
returns table(
  assignment_id uuid,fixture_id uuid,referee_user_id uuid,referee_name text,
  gameweek integer,scheduled_at timestamptz,home_team_name text,away_team_name text,
  location_id uuid,location_name text,assigned_at timestamptz
)
language plpgsql stable security definer set search_path = ''
as $$
begin
  if auth.uid() is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  if p_location_id is not null and not public.can_administer_location(p_location_id) then
    raise exception 'You are not assigned to this location';
  end if;
  return query
  select a.id,f.id,a.referee_user_id,coalesce(pr.display_name,pr.first_name||' '||pr.last_name,'Referee'),
    f.gameweek,f.scheduled_at,ht.name,at.name,l.location_id,l.name,a.assigned_at
  from public.fixture_referee_assignments a
  join public.fixtures f on f.id=a.fixture_id
  join public.seasons s on s.id=f.season_id
  join public.leagues lg on lg.id=s.league_id
  join public.locations l on l.id=lg.location_id
  join public.season_teams ht on ht.id=f.home_team_id
  join public.season_teams at on at.id=f.away_team_id
  join public.profiles pr on pr.id=a.referee_user_id
  where a.removed_at is null and (p_location_id is null or l.location_id=p_location_id)
    and public.can_administer_location(l.location_id)
  order by f.scheduled_at,a.assigned_at;
end;
$$;
revoke all on function public.admin_list_referee_assignments(uuid) from public, anon;
grant execute on function public.admin_list_referee_assignments(uuid) to authenticated;

create or replace function public.referee_get_assigned_fixtures()
returns table(
  fixture_id uuid,season_name text,league_name text,location_name text,
  gameweek integer,fixture_number integer,scheduled_at timestamptz,
  home_team_id uuid,home_team_name text,away_team_id uuid,away_team_name text,
  home_sheet jsonb,away_sheet jsonb,report_id uuid,report_status text,report_completed_at timestamptz
)
language plpgsql stable security definer set search_path = ''
as $$
begin
  if auth.uid() is null or not public.is_active_referee() then raise exception 'Approved referee membership required'; end if;
  return query
  select f.id,s.name,lg.name,l.name,f.gameweek,f.fixture_number,f.scheduled_at,
    f.home_team_id,ht.name,f.away_team_id,at.name,
    coalesce((
      select jsonb_agg(jsonb_build_object(
        'competition_player_id',tsp.competition_player_id,
        'player_name',cpi.display_name,'role',tsp.role,
        'squad_number',tsp.squad_number_snapshot,'is_goalkeeper',tsp.is_goalkeeper
      ) order by case when tsp.role='starter' then 0 else 1 end,tsp.squad_number_snapshot nulls last,cpi.display_name)
      from public.fixture_team_sheets sh
      join public.fixture_team_sheet_players tsp on tsp.team_sheet_id=sh.id
      join public.competition_player_identities cpi on cpi.id=tsp.competition_player_id
      where sh.fixture_id=f.id and sh.season_team_id=f.home_team_id and sh.is_locked and sh.submitted_at is not null
    ),'[]'::jsonb),
    coalesce((
      select jsonb_agg(jsonb_build_object(
        'competition_player_id',tsp.competition_player_id,
        'player_name',cpi.display_name,'role',tsp.role,
        'squad_number',tsp.squad_number_snapshot,'is_goalkeeper',tsp.is_goalkeeper
      ) order by case when tsp.role='starter' then 0 else 1 end,tsp.squad_number_snapshot nulls last,cpi.display_name)
      from public.fixture_team_sheets sh
      join public.fixture_team_sheet_players tsp on tsp.team_sheet_id=sh.id
      join public.competition_player_identities cpi on cpi.id=tsp.competition_player_id
      where sh.fixture_id=f.id and sh.season_team_id=f.away_team_id and sh.is_locked and sh.submitted_at is not null
    ),'[]'::jsonb),
    r.id,r.status,r.completed_at
  from public.fixture_referee_assignments a
  join public.fixtures f on f.id=a.fixture_id
  join public.seasons s on s.id=f.season_id
  join public.leagues lg on lg.id=s.league_id
  join public.locations l on l.id=lg.location_id
  join public.season_teams ht on ht.id=f.home_team_id
  join public.season_teams at on at.id=f.away_team_id
  left join public.referee_match_reports r on r.fixture_id=f.id
  where a.referee_user_id=auth.uid() and a.removed_at is null
    and f.status in ('scheduled','in_progress')
    and f.gameweek=(
      select min(f2.gameweek) from public.fixtures f2
      where f2.season_id=f.season_id and f2.status in ('scheduled','in_progress')
    )
  order by f.scheduled_at,f.fixture_number;
end;
$$;
revoke all on function public.referee_get_assigned_fixtures() from public, anon;
grant execute on function public.referee_get_assigned_fixtures() to authenticated;

create or replace function public.referee_save_match_report(
  p_fixture_id uuid,p_completed_at timestamptz,p_home_score integer,p_away_score integer,
  p_match_summary text,p_goals jsonb,p_incidents jsonb,p_submit boolean default true,
  p_admin_override boolean default false
)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  v_actor uuid:=auth.uid(); v_fixture public.fixtures; v_assignment public.fixture_referee_assignments;
  v_report public.referee_match_reports; v_report_id uuid; v_version integer;
  v_goal jsonb; v_incident jsonb; v_credited_team uuid; v_scorer_team uuid;
  v_competition_player uuid; v_recipient text; v_card text; v_team uuid; v_fine integer;
  v_role public.lineup_role; v_squad_number smallint;
  v_home_count integer; v_away_count integer; v_is_referee boolean;
begin
  if v_actor is null then raise exception 'Authentication required'; end if;
  if p_admin_override and not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  v_is_referee:=public.is_active_referee() and not p_admin_override;
  if not v_is_referee and not public.has_platform_role() then
    raise exception 'Approved referee membership or administrator permission required';
  end if;
  if p_home_score is null or p_away_score is null or p_home_score not between 0 and 99 or p_away_score not between 0 and 99 then
    raise exception 'Enter a valid final score';
  end if;
  if p_completed_at is null or p_completed_at>now() then raise exception 'A valid match completion time is required'; end if;
  select * into v_fixture from public.fixtures f where f.id=p_fixture_id for update;
  if not found or v_fixture.status not in ('scheduled','in_progress') then raise exception 'Fixture is not available for referee reporting'; end if;
  if v_fixture.scheduled_at is null or p_completed_at<v_fixture.scheduled_at then raise exception 'Match completion cannot be before scheduled kick-off'; end if;
  if v_is_referee then
    if now()>p_completed_at+interval '24 hours' then raise exception 'The referee report deadline has expired; an administrator must complete this report'; end if;
    if v_fixture.gameweek<>(select min(f2.gameweek) from public.fixtures f2 where f2.season_id=v_fixture.season_id and f2.status in ('scheduled','in_progress')) then
      raise exception 'Referee reporting is limited to the latest active gameweek';
    end if;
    select * into v_assignment from public.fixture_referee_assignments a
    where a.fixture_id=p_fixture_id and a.referee_user_id=v_actor and a.removed_at is null for update;
    if not found then raise exception 'You are not assigned to this fixture'; end if;
  else
    if not public.can_administer_location((
      select lg.location_id from public.seasons se join public.leagues lg on lg.id=se.league_id where se.id=v_fixture.season_id
    )) then raise exception 'You are not assigned to this location'; end if;
    select * into v_assignment from public.fixture_referee_assignments a
    where a.fixture_id=p_fixture_id and a.removed_at is null for update;
  end if;
  if not exists (
    select 1 from public.fixture_team_sheets sh
    where sh.fixture_id=p_fixture_id and sh.season_team_id in (v_fixture.home_team_id,v_fixture.away_team_id)
      and sh.is_locked is true and sh.submitted_at is not null
    group by sh.fixture_id having count(*)=2
  ) then raise exception 'Both teams must submit their team sheets before a referee report can be submitted'; end if;
  if jsonb_typeof(coalesce(p_goals,'[]'::jsonb))<>'array' or jsonb_typeof(coalesce(p_incidents,'[]'::jsonb))<>'array' then
    raise exception 'Goals and disciplinary incidents must be supplied as lists';
  end if;

  select * into v_report from public.referee_match_reports where fixture_id=p_fixture_id for update;
  if found then
    if (v_is_referee and v_report.status not in ('draft','returned')) or (not v_is_referee and v_report.status not in ('draft','returned','submitted')) then raise exception 'This report is already approved or closed'; end if;
    v_report_id:=v_report.id; v_version:=v_report.version+1;
    update public.referee_match_reports set assignment_id=v_assignment.id,assigned_referee_user_id=coalesce(v_assignment.referee_user_id,v_report.assigned_referee_user_id),
      reporter_user_id=v_actor,status=case when p_submit then 'submitted' else 'draft' end,
      completed_at=p_completed_at,submitted_at=case when p_submit then now() else null end,
      home_score=p_home_score,away_score=p_away_score,match_summary=nullif(btrim(p_match_summary),''),
      version=v_version,updated_at=now(),reviewed_by=null,reviewed_at=null,review_reason=null
    where id=v_report_id;
    delete from public.referee_match_report_goals where report_id=v_report_id;
    delete from public.referee_match_report_incidents where report_id=v_report_id;
  else
    v_version:=1;
    insert into public.referee_match_reports(
      fixture_id,assignment_id,assigned_referee_user_id,reporter_user_id,status,completed_at,
      submitted_at,home_score,away_score,match_summary,version
    ) values (
      p_fixture_id,v_assignment.id,v_assignment.referee_user_id,v_actor,case when p_submit then 'submitted' else 'draft' end,
      p_completed_at,case when p_submit then now() else null end,p_home_score,p_away_score,
      nullif(btrim(p_match_summary),''),v_version
    ) returning id into v_report_id;
  end if;

  for v_goal in select value from jsonb_array_elements(coalesce(p_goals,'[]'::jsonb)) loop
    v_credited_team:=nullif(v_goal->>'credited_team_id','')::uuid;
    v_scorer_team:=nullif(v_goal->>'scorer_team_id','')::uuid;
    v_competition_player:=nullif(v_goal->>'scorer_competition_player_id','')::uuid;
    if v_credited_team not in (v_fixture.home_team_id,v_fixture.away_team_id) then raise exception 'Goal credited to a team outside this fixture'; end if;
    if coalesce((v_goal->>'is_own_goal')::boolean,false) then
      if v_scorer_team is not null and v_scorer_team not in (v_fixture.home_team_id,v_fixture.away_team_id) then raise exception 'Own-goal player team is outside this fixture'; end if;
      if v_scorer_team=v_credited_team then raise exception 'An own goal must be credited to the opposing team'; end if;
      if v_competition_player is not null then
        if v_scorer_team is null or not exists(
          select 1 from public.fixture_team_sheets sh join public.fixture_team_sheet_players tsp on tsp.team_sheet_id=sh.id
          where sh.fixture_id=p_fixture_id and sh.season_team_id=v_scorer_team and sh.is_locked
            and tsp.competition_player_id=v_competition_player
        ) then raise exception 'Own-goal identity must belong to the opposing submitted team sheet'; end if;
      end if;
      insert into public.referee_match_report_goals(report_id,credited_team_id,scorer_team_id,scorer_competition_player_id,is_own_goal)
      values(v_report_id,v_credited_team,nullif(v_scorer_team,v_credited_team),v_competition_player,true);
    else
      if v_scorer_team is distinct from v_credited_team or v_competition_player is null then
        raise exception 'A normal goal requires a scorer from the team receiving the goal credit';
      end if;
      if not exists(
        select 1 from public.fixture_team_sheets sh join public.fixture_team_sheet_players tsp on tsp.team_sheet_id=sh.id
        where sh.fixture_id=p_fixture_id and sh.season_team_id=v_scorer_team and sh.is_locked
          and tsp.competition_player_id=v_competition_player
      ) then raise exception 'Goalscorer must be selected from the relevant submitted team sheet'; end if;
      insert into public.referee_match_report_goals(report_id,credited_team_id,scorer_team_id,scorer_competition_player_id,is_own_goal)
      values(v_report_id,v_credited_team,v_scorer_team,v_competition_player,false);
    end if;
  end loop;

  select count(*) filter(where credited_team_id=v_fixture.home_team_id),
         count(*) filter(where credited_team_id=v_fixture.away_team_id)
  into v_home_count,v_away_count
  from public.referee_match_report_goals where report_id=v_report_id;
  if v_home_count<>p_home_score or v_away_count<>p_away_score then
    raise exception 'Goalscorer and own-goal entries must add up exactly to the final score';
  end if;

  for v_incident in select value from jsonb_array_elements(coalesce(p_incidents,'[]'::jsonb)) loop
    v_team:=nullif(v_incident->>'team_id','')::uuid;
    v_recipient:=v_incident->>'recipient_category';
    v_card:=v_incident->>'card_outcome';
    v_competition_player:=nullif(v_incident->>'competition_player_id','')::uuid;
    if v_team not in (v_fixture.home_team_id,v_fixture.away_team_id) then raise exception 'Disciplinary incident team is outside this fixture'; end if;
    if v_card not in ('yellow','second_yellow_red','straight_red') then raise exception 'Invalid disciplinary card outcome'; end if;
    v_fine:=case v_card when 'yellow' then 500 when 'second_yellow_red' then 1500 when 'straight_red' then 3000 end;
    if v_recipient='supporter' then
      if v_competition_player is not null then raise exception 'Supporter incidents cannot be linked to a player identity'; end if;
      v_role:=null; v_squad_number:=null;
    elsif v_recipient in ('registered_player','substitute_bench') then
      if v_competition_player is null then raise exception 'Select a player from the submitted team sheet'; end if;
      select tsp.role,tsp.squad_number_snapshot into v_role,v_squad_number
      from public.fixture_team_sheets sh join public.fixture_team_sheet_players tsp on tsp.team_sheet_id=sh.id
      where sh.fixture_id=p_fixture_id and sh.season_team_id=v_team and sh.is_locked
        and tsp.competition_player_id=v_competition_player
      limit 1;
      if not found then raise exception 'Disciplinary player must be on the relevant submitted team sheet'; end if;
      if v_recipient='registered_player' and v_role<>'starter' then raise exception 'Select a starter for a registered-player incident'; end if;
      if v_recipient='substitute_bench' and v_role<>'substitute' then raise exception 'Select a substitute for a bench incident'; end if;
    else raise exception 'Invalid disciplinary recipient category'; end if;
    insert into public.referee_match_report_incidents(
      report_id,team_id,recipient_category,competition_player_id,squad_number_snapshot,card_outcome,fine_amount_pence
    ) values(v_report_id,v_team,v_recipient,v_competition_player,v_squad_number,v_card,v_fine);
  end loop;

  insert into public.referee_match_report_versions(report_id,version,actor_user_id,action,snapshot)
  values(v_report_id,v_version,v_actor,case when p_submit then 'submitted' else 'draft_saved' end,
    jsonb_build_object(
      'status',case when p_submit then 'submitted' else 'draft' end,
      'home_score',p_home_score,'away_score',p_away_score,'completed_at',p_completed_at,
      'match_summary',nullif(btrim(p_match_summary),''),
      'goals',coalesce((select jsonb_agg(to_jsonb(g)) from public.referee_match_report_goals g where g.report_id=v_report_id),'[]'::jsonb),
      'incidents',coalesce((select jsonb_agg(to_jsonb(i)) from public.referee_match_report_incidents i where i.report_id=v_report_id),'[]'::jsonb)
    )
  );
  return v_report_id;
end;
$$;
revoke all on function public.referee_save_match_report(uuid,timestamptz,integer,integer,text,jsonb,jsonb,boolean,boolean) from public, anon;
grant execute on function public.referee_save_match_report(uuid,timestamptz,integer,integer,text,jsonb,jsonb,boolean,boolean) to authenticated;

-- Admin fallback uses the same validation and report storage but bypasses the
-- referee assignment/latest-gameweek/24-hour restrictions after location authorization.
create or replace function public.admin_save_referee_match_report(
  p_fixture_id uuid,p_completed_at timestamptz,p_home_score integer,p_away_score integer,
  p_match_summary text,p_goals jsonb,p_incidents jsonb,p_submit boolean default true
)
returns uuid
language plpgsql security definer set search_path = ''
as $$
begin
  if auth.uid() is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  return public.referee_save_match_report(
    p_fixture_id,p_completed_at,p_home_score,p_away_score,p_match_summary,p_goals,p_incidents,p_submit,true
  );
end;
$$;
revoke all on function public.admin_save_referee_match_report(uuid,timestamptz,integer,integer,text,jsonb,jsonb,boolean) from public, anon;
grant execute on function public.admin_save_referee_match_report(uuid,timestamptz,integer,integer,text,jsonb,jsonb,boolean) to authenticated;

create or replace function public.admin_list_referee_report_queue(p_status text default 'submitted',p_location_id uuid default null)
returns table(
  report_id uuid,fixture_id uuid,gameweek integer,scheduled_at timestamptz,
  home_team_name text,away_team_name text,referee_user_id uuid,referee_name text,
  status text,home_score integer,away_score integer,submitted_at timestamptz,match_summary text
)
language plpgsql stable security definer set search_path = ''
as $$
begin
  if auth.uid() is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  if p_status not in ('submitted','returned','approved','rejected','all') then raise exception 'Invalid report status filter'; end if;
  return query
  select r.id,f.id,f.gameweek,f.scheduled_at,ht.name,at.name,r.assigned_referee_user_id,
    coalesce(pr.display_name,pr.first_name||' '||pr.last_name,'Admin completed'),
    r.status,r.home_score,r.away_score,r.submitted_at,r.match_summary
  from public.referee_match_reports r
  join public.fixtures f on f.id=r.fixture_id
  join public.seasons s on s.id=f.season_id
  join public.leagues lg on lg.id=s.league_id
  join public.season_teams ht on ht.id=f.home_team_id
  join public.season_teams at on at.id=f.away_team_id
  left join public.profiles pr on pr.id=r.assigned_referee_user_id
  where (p_status='all' or r.status=p_status)
    and (p_location_id is null or lg.location_id=p_location_id)
    and public.can_administer_location(lg.location_id)
  order by r.submitted_at nulls last,f.scheduled_at desc;
end;
$$;
revoke all on function public.admin_list_referee_report_queue(text,uuid) from public, anon;
grant execute on function public.admin_list_referee_report_queue(text,uuid) to authenticated;

create or replace function public.admin_review_referee_match_report(
  p_report_id uuid,p_decision text,p_reason text default null
)
returns public.referee_match_reports
language plpgsql security definer set search_path = ''
as $$
declare
  v_actor uuid:=auth.uid(); v_report public.referee_match_reports; v_fixture public.fixtures;
  v_location uuid; v_home_count integer; v_away_count integer; v_goal record; v_incident record;
  v_user_id uuid; v_entitlement_id uuid; v_before jsonb;
begin
  if v_actor is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  if p_decision not in ('approve','return','reject') then raise exception 'Invalid report decision'; end if;
  if p_decision<>'approve' and (p_reason is null or length(btrim(p_reason))<5) then raise exception 'Enter a reason of at least 5 characters'; end if;
  select * into v_report from public.referee_match_reports where id=p_report_id for update;
  if not found then raise exception 'Match report not found'; end if;
  select * into v_fixture from public.fixtures where id=v_report.fixture_id for update;
  if not found then raise exception 'Fixture not found'; end if;
  select lg.location_id into v_location from public.seasons s join public.leagues lg on lg.id=s.league_id where s.id=v_fixture.season_id;
  if not public.can_administer_location(v_location) then raise exception 'You are not assigned to this location'; end if;
  if v_report.status<>'submitted' then raise exception 'Only submitted reports can be reviewed'; end if;

  v_before:=jsonb_build_object('status',v_report.status,'home_score',v_report.home_score,'away_score',v_report.away_score);
  if p_decision='return' then
    update public.referee_match_reports set status='returned',version=version+1,reviewed_by=null,reviewed_at=null,review_reason=btrim(p_reason),updated_at=now()
    where id=p_report_id returning * into v_report;
    insert into public.referee_match_report_versions(report_id,version,actor_user_id,action,snapshot)
    values(p_report_id,v_report.version,v_actor,'returned',jsonb_build_object('before',v_before,'reason',btrim(p_reason)));
  elsif p_decision='reject' then
    update public.referee_match_reports set status='rejected',version=version+1,reviewed_by=v_actor,reviewed_at=now(),review_reason=btrim(p_reason),updated_at=now()
    where id=p_report_id returning * into v_report;
    insert into public.referee_match_report_versions(report_id,version,actor_user_id,action,snapshot)
    values(p_report_id,v_report.version,v_actor,'rejected',jsonb_build_object('before',v_before,'reason',btrim(p_reason)));
  else
    select count(*) filter(where credited_team_id=v_fixture.home_team_id),
           count(*) filter(where credited_team_id=v_fixture.away_team_id)
    into v_home_count,v_away_count
    from public.referee_match_report_goals where report_id=p_report_id;
    if v_home_count<>v_report.home_score or v_away_count<>v_report.away_score then
      raise exception 'Report score does not reconcile to its goal entries';
    end if;
    if exists(select 1 from public.fixture_results fr where fr.fixture_id=v_fixture.id and fr.confirmed_at is not null) then
      raise exception 'This fixture already has a published result; use the audited admin correction workflow';
    end if;
    insert into public.fixture_results(fixture_id,home_score,away_score,confirmed_at,confirmed_by)
    values(v_fixture.id,v_report.home_score,v_report.away_score,now(),v_actor)
    on conflict(fixture_id) do update set home_score=excluded.home_score,away_score=excluded.away_score,
      confirmed_at=excluded.confirmed_at,confirmed_by=excluded.confirmed_by,updated_at=now();
    update public.fixtures set status='completed',updated_at=now() where id=v_fixture.id;
    -- Preserve any unconfirmed legacy goal rows as voided history before
    -- making this approved report the sole active goalscorer source.
    update public.fixture_goal_records
    set voided_at=now(),voided_by=v_actor,void_reason='Superseded by approved referee report'
    where fixture_id=v_fixture.id and voided_at is null;

    for v_goal in
      select g.* from public.referee_match_report_goals g
      where g.report_id=p_report_id and g.is_own_goal is false
    loop
      select tsp.user_id into v_user_id
      from public.fixture_team_sheets sh
      join public.fixture_team_sheet_players tsp on tsp.team_sheet_id=sh.id
      where sh.fixture_id=v_fixture.id and sh.season_team_id=v_goal.credited_team_id
        and tsp.competition_player_id=v_goal.scorer_competition_player_id
      limit 1;
      insert into public.fixture_goal_records(
        fixture_id,season_team_id,scorer_user_id,competition_player_id,created_by
      ) values(v_fixture.id,v_goal.credited_team_id,v_user_id,v_goal.scorer_competition_player_id,v_actor);
    end loop;
    for v_incident in
      select i.* from public.referee_match_report_incidents i
      where i.report_id=p_report_id and i.finance_entry_id is null
    loop
      insert into public.finance_entries(
        season_team_id,fixture_id,entry_type,amount_pence,description,occurred_at,created_by,notes
      ) values(
        v_incident.team_id,v_fixture.id,'fine',v_incident.fine_amount_pence,
        case v_incident.card_outcome
          when 'yellow' then 'Yellow card fine'
          when 'second_yellow_red' then 'Second yellow and red fine'
          else 'Straight red fine'
        end, v_incident.created_at,v_actor,
        'Referee report '||p_report_id::text||'; recipient category: '||v_incident.recipient_category
      ) returning id into v_entitlement_id;
      update public.referee_match_report_incidents set finance_entry_id=v_entitlement_id where id=v_incident.id;
    end loop;
    if v_report.assigned_referee_user_id is not null then
      insert into public.referee_payment_entitlements(report_id,referee_user_id)
      values(p_report_id,v_report.assigned_referee_user_id)
      on conflict(report_id) do nothing;
    end if;
    update public.referee_match_reports set status='approved',version=version+1,reviewed_by=v_actor,reviewed_at=now(),
      review_reason=null,updated_at=now() where id=p_report_id returning * into v_report;
    insert into public.referee_match_report_versions(report_id,version,actor_user_id,action,snapshot)
    values(p_report_id,v_report.version,v_actor,'approved',jsonb_build_object('before',v_before,'home_score',v_report.home_score,'away_score',v_report.away_score));
  end if;
  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,before_data,after_data)
  values(v_actor,'referee.report.'||p_decision,'referee_match_report',p_report_id::text,
    nullif(btrim(p_reason),''),v_before,jsonb_build_object('status',v_report.status,'home_score',v_report.home_score,'away_score',v_report.away_score));
  return v_report;
end;
$$;
revoke all on function public.admin_review_referee_match_report(uuid,text,text) from public, anon;
grant execute on function public.admin_review_referee_match_report(uuid,text,text) to authenticated;

comment on table public.referee_applications is
  'Referee applications are separate from platform user_roles; approval is required before referee membership and portal access.';
comment on table public.fixture_referee_assignments is
  'Private administrative referee assignments. Active assignment is unique per fixture; removal/reassignment history is retained.';
comment on table public.referee_match_reports is
  'One versioned report per fixture. Only admin approval publishes official result, goals, fines and referee entitlement.';
comment on table public.referee_payment_entitlements is
  'One £22 gross allocation and £20 minimum net guarantee per approved assigned referee report. Stripe transfer/payout is a separate workflow.';
