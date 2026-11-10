-- Referee application, approval, RLS and membership lifecycle regression tests.
-- Runs only against the disposable local Supabase database created by CI.

do $referee_application_workflow$
declare
  v_admin constant uuid := '91000000-0000-4000-8000-000000000001';
  v_applicant constant uuid := '91000000-0000-4000-8000-000000000002';
  v_other_applicant constant uuid := '91000000-0000-4000-8000-000000000003';
  v_unregistered constant uuid := '91000000-0000-4000-8000-000000000004';
  v_banned constant uuid := '91000000-0000-4000-8000-000000000005';
  v_location uuid;
  v_other_location uuid;
  v_application uuid;
  v_other_application uuid;
  v_count integer;
  v_rejected boolean;
  v_availability jsonb := '[{"weekday":5,"start_time":"18:00","end_time":"22:00"},{"weekday":7,"start_time":"09:00","end_time":"13:00"}]'::jsonb;
begin
  insert into auth.users
    (id,aud,role,email,encrypted_password,raw_user_meta_data,email_confirmed_at,created_at,updated_at)
  values
    (v_admin,'authenticated','authenticated','ci-referee-admin@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_applicant,'authenticated','authenticated','ci-referee-applicant@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_other_applicant,'authenticated','authenticated','ci-referee-other@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_unregistered,'authenticated','authenticated','ci-referee-unregistered@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_banned,'authenticated','authenticated','ci-referee-banned@openplay.invalid','','{"role":"referee"}'::jsonb,now(),now(),now());

  insert into public.players(user_id,full_name,phone,email,date_of_birth,registration_status,is_banned)
  values
    (v_applicant,'Referee Applicant','07700900602','ci-referee-applicant@openplay.invalid',date '1990-01-02','registered',false),
    (v_other_applicant,'Referee Other Applicant','07700900603','ci-referee-other@openplay.invalid',date '1990-01-03','registered',false),
    (v_unregistered,'Unregistered Applicant','07700900604','ci-referee-unregistered@openplay.invalid',date '1990-01-04','rejected',false),
    (v_banned,'Banned Applicant','07700900605','ci-referee-banned@openplay.invalid',date '1990-01-05','registered',false);

  update public.players
  set is_banned=true,banned_at=now(),banned_reason='CI referee eligibility test'
  where user_id=v_banned;

  insert into public.user_roles(user_id,role,granted_by)
  values(v_admin,'admin',v_admin);

  insert into public.locations(name,slug,town,region,is_active)
  values
    ('CI Referee Location','ci-referee-location','Bideford','North Devon',true),
    ('CI Referee Inactive Location','ci-referee-inactive-location','Bideford','North Devon',false);

  select id into v_location from public.locations where slug='ci-referee-location';
  select id into v_other_location from public.locations where slug='ci-referee-inactive-location';

  -- Eligible player can submit with no formal qualifications.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_applicant::text,true);
  perform set_config('request.jwt.claim.role','authenticated',true);

  v_application := public.submit_referee_application(
    'Two seasons of grassroots refereeing experience.',
    '{}'::text[],
    v_availability,
    '+447700900602',
    array[v_location],
    null
  );

  if not exists (
    select 1 from public.referee_applications
    where id=v_application
      and user_id=v_applicant
      and status='pending'
      and cardinality(qualifications)=0
      and contact_phone='+447700900602'
  ) then
    raise exception 'Eligible referee application was not stored with normalized contact details';
  end if;

  -- Applicant cannot submit a second pending application.
  v_rejected := false;
  begin
    perform public.submit_referee_application(
      'Duplicate pending application.',
      '{}'::text[],
      v_availability,
      '+447700900602',
      array[v_location],
      null
    );
  exception when others then
    v_rejected := true;
  end;
  if not v_rejected then
    raise exception 'Duplicate pending referee application was accepted';
  end if;

  -- Invalid availability windows and inactive locations are rejected server-side.
  v_rejected := false;
  begin
    perform public.submit_referee_application(
      'Invalid availability test.',
      '{}'::text[],
      '[{"weekday":8,"start_time":"22:00","end_time":"18:00"}]'::jsonb,
      '+447700900602',
      array[v_location],
      null
    );
  exception when others then
    v_rejected := true;
  end;
  if not v_rejected then
    raise exception 'Invalid availability window was accepted';
  end if;

  v_rejected := false;
  begin
    perform public.submit_referee_application(
      'Inactive location test.',
      '{}'::text[],
      v_availability,
      '+447700900602',
      array[v_other_location],
      null
    );
  exception when others then
    v_rejected := true;
  end;
  if not v_rejected then
    raise exception 'Inactive preferred location was accepted';
  end if;

  -- Direct table writes are denied; the application RPC is the only write path.
  v_rejected := false;
  begin
    insert into public.referee_applications(
      user_id,experience_summary,qualifications,availability,contact_phone,preferred_location_ids
    ) values (
      v_applicant,'Direct write attempt','{}'::text[],v_availability,
      '+447700900602',array[v_location]
    );
  exception when insufficient_privilege then
    v_rejected := true;
  end;
  if not v_rejected then
    raise exception 'Authenticated user could write directly to referee_applications';
  end if;

  -- Applicant sees their own application only.
  select count(*) into v_count from public.referee_applications;
  if v_count <> 1 then
    raise exception 'Applicant could not read their own application';
  end if;
  execute 'reset role';

  -- Another eligible player submits an application; the first applicant cannot read it.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_other_applicant::text,true);
  v_other_application := public.submit_referee_application(
    'Community football and school competition experience.',
    array['FA Referee Course'],
    v_availability,
    '+447700900603',
    array[v_location],
    'Available most Friday evenings.'
  );
  execute 'reset role';

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_applicant::text,true);
  select count(*) into v_count from public.referee_applications;
  if v_count <> 1 then
    raise exception 'Applicant could read another user''s referee application';
  end if;

  -- Applicants cannot review or approve their own application.
  v_rejected := false;
  begin
    perform public.review_referee_application(v_application,'approved','Self approval attempt');
  exception when others then
    v_rejected := true;
  end;
  if not v_rejected then
    raise exception 'Applicant was able to approve their own referee application';
  end if;
  execute 'reset role';

  -- Unregistered and banned players cannot apply, regardless of user metadata.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_unregistered::text,true);
  v_rejected := false;
  begin
    perform public.submit_referee_application(
      'Should not be eligible.',
      '{}'::text[],
      v_availability,
      '+447700900604',
      array[v_location],
      null
    );
  exception when others then
    v_rejected := true;
  end;
  if not v_rejected then
    raise exception 'Unregistered player was allowed to apply as a referee';
  end if;

  perform set_config('request.jwt.claim.sub',v_banned::text,true);
  v_rejected := false;
  begin
    perform public.submit_referee_application(
      'Banned account should not be eligible.',
      '{}'::text[],
      v_availability,
      '+447700900605',
      array[v_location],
      null
    );
  exception when others then
    v_rejected := true;
  end;
  if not v_rejected then
    raise exception 'Banned player was allowed to apply as a referee';
  end if;

  select count(*) into v_count from public.referee_memberships;
  if v_count <> 0 then
    raise exception 'User metadata or an application created referee access without approval';
  end if;
  execute 'reset role';

  -- Global admin can review applications and the approval creates a distinct referee membership.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  perform public.review_referee_application(v_application,'approved','Experience and availability verified');
  if not exists (
    select 1 from public.referee_memberships
    where user_id=v_applicant and application_id=v_application and status='active'
  ) then
    raise exception 'Approved application did not create an active referee membership';
  end if;

  -- Suspension removes active referee access; reinstatement restores it with an audit reason.
  perform public.set_referee_membership_status(v_applicant,'suspended','Temporary safeguarding review');
  if not exists (
    select 1 from public.referee_memberships
    where user_id=v_applicant and status='suspended'
  ) then
    raise exception 'Referee membership suspension was not applied';
  end if;
  perform public.set_referee_membership_status(v_applicant,'active','Safeguarding review completed');
  if not exists (
    select 1 from public.referee_memberships
    where user_id=v_applicant and status='active'
  ) then
    raise exception 'Referee membership reinstatement was not applied';
  end if;

  perform public.review_referee_application(v_other_application,'rejected','Insufficient refereeing experience');
  if not exists (
    select 1 from public.referee_applications
    where id=v_other_application and status='rejected'
      and reviewed_by=v_admin and reviewed_at is not null
  ) then
    raise exception 'Rejected application decision was not recorded';
  end if;
  if exists (
    select 1 from public.referee_memberships where user_id=v_other_applicant
  ) then
    raise exception 'Rejected applicant was granted referee membership';
  end if;
  execute 'reset role';

  if (select count(*) from public.audit_log
      where entity_type='referee_application'
        and entity_id in (v_application::text,v_other_application::text)) <> 4 then
    raise exception 'Referee application submission and review actions were not fully audited';
  end if;
  if (select count(*) from public.audit_log
      where entity_type='referee_membership'
        and entity_id=v_applicant::text
        and action in ('referee.membership_suspended','referee.membership_reinstated')) <> 2 then
    raise exception 'Referee suspension and reinstatement actions were not audited';
  end if;
end;
$referee_application_workflow$;
