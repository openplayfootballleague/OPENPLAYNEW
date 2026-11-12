-- Team registration application: pricing snapshot, declarations, private captain details and optional public branding.
alter table public.seasons
  add column if not exists gameweek_count integer not null default 14
  check (gameweek_count between 1 and 52);

alter table public.season_teams
  add column if not exists instagram_url text;

alter table public.season_teams
  add constraint season_teams_instagram_url_format_check
  check (
    instagram_url is null
    or instagram_url ~* '^https?://(www\.)?instagram\.com/[A-Za-z0-9._]+/?$'
  );

create table if not exists public.team_registration_details (
  season_team_id uuid primary key references public.season_teams(id) on delete cascade,
  submitted_by uuid not null references auth.users(id) on delete restrict,
  captain_full_name text not null,
  captain_mobile text not null,
  captain_whatsapp text,
  captain_whatsapp_same_as_mobile boolean not null default false,
  captain_no_whatsapp boolean not null default false,
  team_status text not null check (team_status in ('new','returning')),
  weekly_fee_accepted_pence integer not null check (weekly_fee_accepted_pence >= 0),
  full_season_total_accepted_pence integer not null check (full_season_total_accepted_pence >= 0),
  gameweek_count_accepted integer not null check (gameweek_count_accepted between 1 and 52),
  fee_accepted_at timestamptz not null,
  fee_accepted_by uuid not null references auth.users(id) on delete restrict,
  fee_accepted_competition_id uuid not null references public.leagues(id) on delete restrict,
  declarations_accepted_at timestamptz not null,
  declarations_version text not null,
  declaration_authority boolean not null default true,
  declaration_accuracy boolean not null default true,
  declaration_payment boolean not null default true,
  declaration_age boolean not null default true,
  declaration_rules boolean not null default true,
  additional_information text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint team_registration_details_whatsapp_choice_check
    check (not (captain_whatsapp_same_as_mobile and captain_no_whatsapp)),
  constraint team_registration_details_whatsapp_value_check
    check (
      (captain_no_whatsapp and captain_whatsapp is null)
      or (captain_whatsapp_same_as_mobile and captain_whatsapp is not null)
      or (not captain_no_whatsapp and not captain_whatsapp_same_as_mobile and captain_whatsapp is not null)
    ),
  constraint team_registration_details_declarations_check
    check (declaration_authority and declaration_accuracy and declaration_payment and declaration_age and declaration_rules)
);

alter table public.team_registration_details enable row level security;
revoke all on table public.team_registration_details from public,anon;
revoke insert,update,delete on table public.team_registration_details from authenticated;
grant select on table public.team_registration_details to authenticated;

drop policy if exists team_registration_details_applicant_read on public.team_registration_details;
create policy team_registration_details_applicant_read
on public.team_registration_details
for select to authenticated
using (submitted_by=auth.uid());

drop policy if exists team_registration_details_location_admin_read on public.team_registration_details;
create policy team_registration_details_location_admin_read
on public.team_registration_details
for select to authenticated
using (
  exists (
    select 1
    from public.season_teams st
    join public.seasons s on s.id=st.season_id
    join public.leagues l on l.id=s.league_id
    where st.id=team_registration_details.season_team_id
      and public.can_administer_location(l.location_id)
  )
);

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('team-crests','team-crests',true,5242880,array['image/png','image/jpeg','image/svg+xml'])
on conflict (id) do update
set public=true,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists team_crests_upload_own_folder on storage.objects;
create policy team_crests_upload_own_folder
on storage.objects
for insert to authenticated
with check (
  bucket_id='team-crests'
  and (storage.foldername(name))[1]=auth.uid()::text
);

drop policy if exists team_crests_delete_own_folder on storage.objects;
create policy team_crests_delete_own_folder
on storage.objects
for delete to authenticated
using (
  bucket_id='team-crests'
  and (storage.foldername(name))[1]=auth.uid()::text
);

create or replace function public.get_team_registration_terms(p_season_id uuid)
returns table (
  season_id uuid,
  season_name text,
  competition_id uuid,
  competition_name text,
  weekly_fee_pence integer,
  gameweek_count integer,
  full_season_total_pence integer
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid:=auth.uid();
  v_player public.players;
  v_season public.seasons;
  v_competition public.leagues;
  v_weekly_fee integer;
  v_gameweek_count integer;
  v_total integer;
  v_unpriced_weeks integer;
begin
  if v_user_id is null then raise exception 'Authentication required'; end if;

  select * into v_player from public.players where user_id=v_user_id;
  if not found or v_player.registration_status<>'registered' or v_player.is_banned then
    raise exception 'An approved, eligible player registration is required';
  end if;

  if not coalesce(public.get_public_team_recruitment_status(),false) then
    raise exception 'Team registration is currently paused';
  end if;

  select * into v_season
  from public.seasons
  where id=p_season_id and status='registration_open';
  if not found then raise exception 'This season is not accepting team registrations'; end if;

  select * into v_competition from public.leagues where id=v_season.league_id;
  if not found then raise exception 'The selected competition is unavailable'; end if;

  v_gameweek_count:=coalesce(v_season.gameweek_count,14);

  select c.team_fee_pence into v_weekly_fee
  from public.season_fee_configs c
  where c.season_id=p_season_id and c.effective_from_gameweek<=1
  order by c.effective_from_gameweek desc
  limit 1;

  if v_weekly_fee is null then
    raise exception 'The weekly team fee has not been configured for this season';
  end if;

  select count(*) into v_unpriced_weeks
  from generate_series(1,v_gameweek_count) as gw(gameweek)
  where not exists (
    select 1 from public.season_fee_configs c
    where c.season_id=p_season_id and c.effective_from_gameweek<=gw.gameweek
  );

  if v_unpriced_weeks>0 then
    raise exception 'The team fee schedule is incomplete for this season';
  end if;

  select sum(fee.team_fee_pence)::integer into v_total
  from generate_series(1,v_gameweek_count) as gw(gameweek)
  cross join lateral (
    select c.team_fee_pence
    from public.season_fee_configs c
    where c.season_id=p_season_id and c.effective_from_gameweek<=gw.gameweek
    order by c.effective_from_gameweek desc
    limit 1
  ) fee;

  return query
  select v_season.id,v_season.name,v_competition.id,v_competition.name,
    v_weekly_fee,v_gameweek_count,v_total;
end;
$$;

revoke all on function public.get_team_registration_terms(uuid) from public,anon;
grant execute on function public.get_team_registration_terms(uuid) to authenticated;

drop function if exists public.register_team(uuid,text,text,text);

create or replace function public.register_team(
  p_season_id uuid,
  p_team_name text,
  p_primary_colour text,
  p_instagram_url text,
  p_team_status text,
  p_badge_path text,
  p_captain_whatsapp text,
  p_captain_whatsapp_same_as_mobile boolean,
  p_captain_no_whatsapp boolean,
  p_weekly_fee_accepted_pence integer,
  p_full_season_total_accepted_pence integer,
  p_gameweek_count_accepted integer,
  p_fee_accepted boolean,
  p_declaration_authority boolean,
  p_declaration_accuracy boolean,
  p_declaration_payment boolean,
  p_declaration_age boolean,
  p_declaration_rules boolean,
  p_additional_information text
)
returns public.season_teams
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid:=auth.uid();
  v_player public.players;
  v_season public.seasons;
  v_terms record;
  v_team_id uuid;
  v_slug text;
  v_season_team public.season_teams;
  v_whatsapp text;
  v_location_id uuid;
  v_lock_location_id uuid;
  v_lock_league_id uuid;
begin
  if v_user_id is null then raise exception 'Authentication required'; end if;

  if nullif(trim(p_team_name),'') is null or char_length(trim(p_team_name))>80 then
    raise exception 'Team name must be between 1 and 80 characters';
  end if;
  if p_primary_colour is not null and char_length(trim(p_primary_colour))>40 then
    raise exception 'Preferred kit colour must be 40 characters or fewer';
  end if;
  if p_team_status is null or p_team_status not in ('new','returning') then
    raise exception 'Choose whether this is a new or returning team';
  end if;
  if p_instagram_url is not null
     and p_instagram_url !~* '^https?://(www\.)?instagram\.com/[A-Za-z0-9._]+/?$' then
    raise exception 'Enter a valid full Instagram profile link';
  end if;
  if p_additional_information is not null and char_length(p_additional_information)>2000 then
    raise exception 'Additional information must be 2,000 characters or fewer';
  end if;
  if p_captain_whatsapp_same_as_mobile is null or p_captain_no_whatsapp is null
     or (p_captain_whatsapp_same_as_mobile and p_captain_no_whatsapp) then
    raise exception 'Choose one WhatsApp contact option';
  end if;

  -- Take the same league/location locks used by membership and transfer
  -- workflows before taking row locks or creating the application.
  select * into v_season
  from public.seasons
  where id=p_season_id and status='registration_open';
  if not found then raise exception 'This season is not accepting team registrations'; end if;

  v_lock_league_id:=v_season.league_id;
  select l.location_id into v_lock_location_id
  from public.leagues l where l.id=v_lock_league_id;
  if v_lock_location_id is null then raise exception 'The selected competition has no location'; end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_user_id::text||':'||v_lock_league_id::text,0)
  );
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_user_id::text||':'||v_lock_location_id::text,0)
  );

  select * into v_season
  from public.seasons
  where id=p_season_id and status='registration_open'
  for share;
  if not found then raise exception 'This season is no longer accepting team registrations'; end if;

  select l.location_id into v_location_id
  from public.leagues l where l.id=v_season.league_id;
  if v_season.league_id is distinct from v_lock_league_id
     or v_location_id is distinct from v_lock_location_id then
    raise exception 'The selected competition changed while the application was being prepared. Please retry';
  end if;

  select * into v_player
  from public.players
  where user_id=v_user_id
  for share;
  if not found or v_player.registration_status<>'registered' or v_player.is_banned then
    raise exception 'An approved, eligible player registration is required to register a team';
  end if;
  if nullif(trim(v_player.full_name),'') is null or nullif(trim(v_player.phone),'') is null then
    raise exception 'Complete your player name and mobile number before registering a team';
  end if;

  if p_captain_no_whatsapp then
    v_whatsapp:=null;
  elsif p_captain_whatsapp_same_as_mobile then
    v_whatsapp:=v_player.phone;
  else
    v_whatsapp:=nullif(trim(p_captain_whatsapp),'');
    if v_whatsapp is null or v_whatsapp !~ '^\+?[0-9][0-9 ()-]{6,18}$' then
      raise exception 'Enter a valid WhatsApp number or choose another contact option';
    end if;
  end if;

  select * into v_terms from public.get_team_registration_terms(p_season_id);
  if not found then raise exception 'Team registration terms are unavailable'; end if;

  if not coalesce(p_fee_accepted,false)
     or p_weekly_fee_accepted_pence is distinct from v_terms.weekly_fee_pence
     or p_full_season_total_accepted_pence is distinct from v_terms.full_season_total_pence
     or p_gameweek_count_accepted is distinct from v_terms.gameweek_count then
    raise exception 'The team fee or season details have changed. Review and accept the latest terms before submitting';
  end if;

  if not coalesce(p_declaration_authority,false)
     or not coalesce(p_declaration_accuracy,false)
     or not coalesce(p_declaration_payment,false)
     or not coalesce(p_declaration_age,false)
     or not coalesce(p_declaration_rules,false) then
    raise exception 'All team registration declarations must be accepted';
  end if;

  if p_badge_path is not null then
    if p_badge_path !~ ('^'||v_user_id::text||'/[^/]+\.(png|jpe?g|svg)$')
       or not exists (
         select 1 from storage.objects o
         where o.bucket_id='team-crests' and o.name=p_badge_path
       ) then
      raise exception 'The uploaded team crest is invalid or does not belong to your account';
    end if;
  end if;

  if exists(
    select 1
    from public.team_memberships tm
    join public.season_teams st on st.id=tm.season_team_id
    join public.seasons other_season on other_season.id=st.season_id
    join public.leagues other_league on other_league.id=other_season.league_id
    where tm.user_id=v_user_id and other_season.id=p_season_id
      and other_league.location_id=v_location_id
      and tm.status in ('active','pending')
  ) then
    raise exception 'You already have a team membership or application in this area for this season';
  end if;

  if exists(
    select 1 from public.player_transfer_requests r
    where r.user_id=v_user_id and r.league_id=v_season.league_id and r.status='pending'
  ) then
    raise exception 'Resolve your pending player transfer request before registering a new team';
  end if;

  v_slug:=trim(both '-' from regexp_replace(lower(trim(p_team_name)),'[^a-z0-9]+','-','g'));
  if v_slug='' then raise exception 'Team name must contain letters or numbers'; end if;
  if exists(select 1 from public.season_teams where season_id=p_season_id and slug=v_slug) then
    raise exception 'A team with that name is already registered for this season';
  end if;

  insert into public.teams(created_by) values(v_user_id) returning id into v_team_id;

  insert into public.season_teams(
    team_id,season_id,name,slug,primary_colour,secondary_colour,
    registration_status,badge_path,instagram_url
  ) values (
    v_team_id,p_season_id,trim(p_team_name),v_slug,nullif(trim(p_primary_colour),''),
    null,'pending',p_badge_path,nullif(trim(p_instagram_url),'')
  )
  returning * into v_season_team;

  insert into public.team_registration_details(
    season_team_id,submitted_by,captain_full_name,captain_mobile,captain_whatsapp,
    captain_whatsapp_same_as_mobile,captain_no_whatsapp,team_status,
    weekly_fee_accepted_pence,full_season_total_accepted_pence,gameweek_count_accepted,
    fee_accepted_at,fee_accepted_by,fee_accepted_competition_id,
    declarations_accepted_at,declarations_version,
    declaration_authority,declaration_accuracy,declaration_payment,declaration_age,declaration_rules,
    additional_information
  ) values (
    v_season_team.id,v_user_id,v_player.full_name,v_player.phone,v_whatsapp,
    p_captain_whatsapp_same_as_mobile,p_captain_no_whatsapp,p_team_status,
    v_terms.weekly_fee_pence,v_terms.full_season_total_pence,v_terms.gameweek_count,
    now(),v_user_id,v_terms.competition_id,
    now(),'team-registration-v1-2026-11-12',
    true,true,true,true,true,nullif(trim(p_additional_information),'')
  );

  insert into public.team_memberships(season_team_id,user_id,status,is_captain)
  values(v_season_team.id,v_user_id,'pending',false);

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,after_data)
  values(v_user_id,'team.registration.submitted','season_team',v_season_team.id::text,
    jsonb_build_object(
      'season_id',p_season_id,'competition_id',v_terms.competition_id,
      'team_name',v_season_team.name,'weekly_fee_accepted_pence',v_terms.weekly_fee_pence,
      'full_season_total_accepted_pence',v_terms.full_season_total_pence,
      'gameweek_count_accepted',v_terms.gameweek_count,
      'fee_accepted_at',now(),'declarations_version','team-registration-v1-2026-11-12'
    ));

  return v_season_team;
end;
$$;

revoke all on function public.register_team(uuid,text,text,text,text,text,text,boolean,boolean,integer,integer,integer,boolean,boolean,boolean,boolean,boolean,boolean,text) from public,anon;
grant execute on function public.register_team(uuid,text,text,text,text,text,text,boolean,boolean,integer,integer,integer,boolean,boolean,boolean,boolean,boolean,boolean,text) to authenticated;


-- Expose the submitted application details only through the authenticated,
-- location-scoped administrator dashboard projection.
create or replace function public.get_admin_dashboard_contextual(
  p_location_id uuid default null,
  p_league_id uuid default null,
  p_season_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
  v_location uuid:=p_location_id;
  v_league uuid:=p_league_id;
  v_season uuid:=p_season_id;
begin
  if auth.uid() is null or not public.has_platform_role() then
    raise exception 'Administrator permission required';
  end if;

  if v_season is not null then
    select s.league_id into v_league from public.seasons s where s.id=v_season;
    if v_league is null then raise exception 'Selected season was not found'; end if;
    if p_league_id is not null and p_league_id<>v_league then raise exception 'Season does not belong to selected league'; end if;
  end if;

  if v_league is not null then
    select l.location_id into v_location from public.leagues l where l.id=v_league;
    if v_location is null then raise exception 'Selected league was not found'; end if;
    if p_location_id is not null and p_location_id<>v_location then raise exception 'League does not belong to selected location'; end if;
  end if;

  if v_location is not null and not exists(select 1 from public.locations l where l.id=v_location) then
    raise exception 'Selected location was not found';
  end if;

  perform public.assert_admin_location_context(v_location);

  select jsonb_build_object(
    'counts',jsonb_build_object(
      'pending_player_reviews',(select count(*) from public.player_registration_reviews r where r.status='pending'),
      'pending_team_applications',(select count(*) from public.season_teams st join public.seasons s on s.id=st.season_id join public.leagues l on l.id=s.league_id where st.registration_status='pending' and (v_season is null or s.id=v_season) and (v_league is null or l.id=v_league) and (v_location is null or l.location_id=v_location)),
      'pending_membership_requests',(select count(*) from public.team_memberships tm join public.season_teams st on st.id=tm.season_team_id join public.seasons s on s.id=st.season_id join public.leagues l on l.id=s.league_id where tm.status='pending' and st.registration_status='approved' and (v_season is null or s.id=v_season) and (v_league is null or l.id=v_league) and (v_location is null or l.location_id=v_location)),
      'open_seasons',(select count(*) from public.seasons s join public.leagues l on l.id=s.league_id where s.status='registration_open' and (v_season is null or s.id=v_season) and (v_league is null or l.id=v_league) and (v_location is null or l.location_id=v_location))
    ),
    'player_reviews',coalesce((
      select jsonb_agg(jsonb_build_object(
        'player_id',p.id,'full_name',p.full_name,'email',p.email,'phone',p.phone,
        'created_at',r.created_at,'name_matched',r.name_matched,'phone_matched',r.phone_matched,'email_matched',r.email_matched
      ) order by r.created_at)
      from public.player_registration_reviews r
      join public.players p on p.id=r.player_id
      where r.status='pending'
    ),'[]'::jsonb),
    'team_applications',coalesce((
      select jsonb_agg(jsonb_build_object(
        'season_team_id',st.id,
        'team_name',st.name,
        'season_name',s.name,
        'created_at',st.created_at,
        'team_status',trd.team_status,
        'captain_full_name',trd.captain_full_name,
        'captain_mobile',trd.captain_mobile,
        'captain_whatsapp',trd.captain_whatsapp,
        'captain_whatsapp_same_as_mobile',trd.captain_whatsapp_same_as_mobile,
        'captain_no_whatsapp',trd.captain_no_whatsapp,
        'preferred_kit_colour',st.primary_colour,
        'instagram_url',st.instagram_url,
        'badge_path',st.badge_path,
        'weekly_fee_accepted_pence',trd.weekly_fee_accepted_pence,
        'full_season_total_accepted_pence',trd.full_season_total_accepted_pence,
        'gameweek_count_accepted',trd.gameweek_count_accepted,
        'fee_accepted_at',trd.fee_accepted_at,
        'fee_accepted_competition_id',trd.fee_accepted_competition_id,
        'declarations_accepted_at',trd.declarations_accepted_at,
        'declarations_version',trd.declarations_version,
        'declaration_authority',trd.declaration_authority,
        'declaration_accuracy',trd.declaration_accuracy,
        'declaration_payment',trd.declaration_payment,
        'declaration_age',trd.declaration_age,
        'declaration_rules',trd.declaration_rules,
        'additional_information',trd.additional_information
      ) order by st.created_at)
      from public.season_teams st
      join public.seasons s on s.id=st.season_id
      join public.leagues l on l.id=s.league_id
      left join public.team_registration_details trd on trd.season_team_id=st.id
      where st.registration_status='pending'
        and (v_season is null or s.id=v_season)
        and (v_league is null or l.id=v_league)
        and (v_location is null or l.location_id=v_location)
    ),'[]'::jsonb),
    'membership_requests',coalesce((
      select jsonb_agg(jsonb_build_object(
        'membership_id',tm.id,'team_name',st.name,'player_name',p.full_name,'created_at',tm.created_at
      ) order by tm.created_at)
      from public.team_memberships tm
      join public.season_teams st on st.id=tm.season_team_id
      join public.seasons s on s.id=st.season_id
      join public.leagues l on l.id=s.league_id
      join public.players p on p.user_id=tm.user_id
      where tm.status='pending' and st.registration_status='approved'
        and (v_season is null or s.id=v_season)
        and (v_league is null or l.id=v_league)
        and (v_location is null or l.location_id=v_location)
    ),'[]'::jsonb)
  ) into v_result;

  return v_result;
end;
$$;

revoke all on function public.get_admin_dashboard_contextual(uuid,uuid,uuid) from public,anon;
grant execute on function public.get_admin_dashboard_contextual(uuid,uuid,uuid) to authenticated;
