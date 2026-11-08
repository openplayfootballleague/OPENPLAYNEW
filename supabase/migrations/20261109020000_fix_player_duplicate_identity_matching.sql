-- Phase 1: evaluate duplicate identity metrics against each existing player.
-- A registration is flagged only when one candidate player matches at least two
-- of name, phone, and email. Date of birth is required but is not a match metric.

alter table public.player_registration_reviews
  add column if not exists match_evidence jsonb not null default '[]'::jsonb;

create or replace function public.register_player(
  p_full_name text,
  p_phone text,
  p_email text,
  p_date_of_birth date
)
returns public.players
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_auth_email text;
  v_email_confirmed_at timestamptz;
  v_name_match boolean := false;
  v_phone_match boolean := false;
  v_email_match boolean := false;
  v_match_evidence jsonb := '[]'::jsonb;
  v_player public.players;
  v_matched_ids uuid[] := '{}'::uuid[];
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

  select lower(trim(u.email)), u.email_confirmed_at
    into v_auth_email, v_email_confirmed_at
  from auth.users u
  where u.id = v_user_id;

  if v_auth_email is null or lower(trim(p_email)) <> v_auth_email then
    raise exception 'Registration email must match the signed-in account email';
  end if;

  if v_email_confirmed_at is null then
    raise exception 'Verify your email address before registering as a player';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('openplay-player-registration', 0)
  );

  -- Recheck after taking the transaction lock so concurrent submissions by the
  -- same account cannot pass the precondition together.
  if exists (
    select 1 from public.players p where p.user_id = v_user_id
  ) then
    raise exception 'Player registration has already been submitted';
  end if;

  with candidate_matches as (
    select
      p.id,
      lower(trim(p.full_name)) = lower(trim(p_full_name)) as name_match,
      pg_catalog.regexp_replace(coalesce(p.phone, ''), '[^0-9]', '', 'g')
        = pg_catalog.regexp_replace(p_phone, '[^0-9]', '', 'g') as phone_match,
      lower(trim(coalesce(p.email, ''))) = lower(trim(p_email)) as email_match
    from public.players p
  ),
  qualifying_matches as (
    select
      id,
      name_match,
      phone_match,
      email_match
    from candidate_matches
    where
      (case when name_match then 1 else 0 end)
      + (case when phone_match then 1 else 0 end)
      + (case when email_match then 1 else 0 end) >= 2
  )
  select
    coalesce(pg_catalog.array_agg(id order by id), '{}'::uuid[]),
    coalesce(
      pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'player_id', id,
          'name_matched', name_match,
          'phone_matched', phone_match,
          'email_matched', email_match
        ) order by id
      ),
      '[]'::jsonb
    ),
    coalesce(pg_catalog.bool_or(name_match), false),
    coalesce(pg_catalog.bool_or(phone_match), false),
    coalesce(pg_catalog.bool_or(email_match), false)
  into
    v_matched_ids,
    v_match_evidence,
    v_name_match,
    v_phone_match,
    v_email_match
  from qualifying_matches;

  insert into public.players (
    user_id,
    full_name,
    phone,
    email,
    date_of_birth,
    registration_status
  )
  values (
    v_user_id,
    trim(p_full_name),
    trim(p_phone),
    lower(trim(p_email)),
    p_date_of_birth,
    case
      when pg_catalog.cardinality(v_matched_ids) > 0
        then 'pending_review'::public.player_registration_status
      else 'registered'::public.player_registration_status
    end
  )
  returning * into v_player;

  if pg_catalog.cardinality(v_matched_ids) > 0 then
    insert into public.player_registration_reviews (
      player_id,
      name_matched,
      phone_matched,
      email_matched,
      matched_player_ids,
      match_evidence
    )
    values (
      v_player.id,
      v_name_match,
      v_phone_match,
      v_email_match,
      v_matched_ids,
      v_match_evidence
    );
  end if;

  insert into public.audit_log (
    actor_user_id,
    action,
    entity_type,
    entity_id,
    after_data
  )
  values (
    v_user_id,
    case
      when pg_catalog.cardinality(v_matched_ids) > 0
        then 'player.registration.flagged'
      else 'player.registration.approved'
    end,
    'player',
    v_player.id::text,
    pg_catalog.jsonb_build_object(
      'registration_status', v_player.registration_status,
      'matched_candidate_count', pg_catalog.cardinality(v_matched_ids),
      'name_matched', v_name_match,
      'phone_matched', v_phone_match,
      'email_matched', v_email_match
    )
  );

  return v_player;
end;
$function$;
