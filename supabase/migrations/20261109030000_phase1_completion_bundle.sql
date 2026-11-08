-- BEGIN supabase/migrations/20261108014200_finance_balance_semantics.sql
-- Correct balance semantics: a refund reverses a received payment and increases the amount owed.
create or replace function public.get_finance_ledger(p_season_id uuid default null,p_team_id uuid default null)
returns table(id uuid,season_team_id uuid,team_name text,season_id uuid,season_name text,fixture_id uuid,gameweek integer,entry_type text,amount_pence integer,description text,due_at timestamptz,occurred_at timestamptz,payment_method text,reference text,notes text,created_by uuid,created_at timestamptz,team_balance_pence bigint)
language plpgsql stable security definer set search_path=''
as $$
begin
if auth.uid() is null or not public.has_finance_access() then raise exception 'Finance permission required'; end if;
return query with scoped as (
select e.*,st.name t_name,st.season_id s_id,se.name s_name,f.gameweek,
sum(case when e.entry_type in ('charge','fine','refund') then e.amount_pence::bigint when e.entry_type in ('payment','credit') then -e.amount_pence::bigint else 0 end) over(partition by e.season_team_id) balance
from public.finance_entries e join public.season_teams st on st.id=e.season_team_id join public.seasons se on se.id=st.season_id left join public.fixtures f on f.id=e.fixture_id
where (p_season_id is null or st.season_id=p_season_id) and (p_team_id is null or st.id=p_team_id))
select s.id,s.season_team_id,s.t_name,s.s_id,s.s_name,s.fixture_id,s.gameweek,s.entry_type,s.amount_pence,s.description,s.due_at,s.occurred_at,s.payment_method,s.reference,s.notes,s.created_by,s.created_at,s.balance::bigint from scoped s order by s.created_at desc,s.id;
end; $$;

create or replace function public.get_finance_summary(p_season_id uuid default null)
returns table(season_id uuid,season_name text,teams_with_entries bigint,charges_pence bigint,payments_pence bigint,refunds_pence bigint,credits_pence bigint,fines_pence bigint,outstanding_pence bigint)
language plpgsql stable security definer set search_path=''
as $$
begin
if auth.uid() is null or not public.has_finance_access() then raise exception 'Finance permission required'; end if;
return query with team_totals as (
select st.id team_id,st.season_id,count(e.id) entry_count,
coalesce(sum(e.amount_pence) filter(where e.entry_type='charge'),0)::bigint charges,
coalesce(sum(e.amount_pence) filter(where e.entry_type='payment'),0)::bigint payments,
coalesce(sum(e.amount_pence) filter(where e.entry_type='refund'),0)::bigint refunds,
coalesce(sum(e.amount_pence) filter(where e.entry_type='credit'),0)::bigint credits,
coalesce(sum(e.amount_pence) filter(where e.entry_type='fine'),0)::bigint fines,
coalesce(sum(case when e.entry_type in ('charge','fine','refund') then e.amount_pence::bigint when e.entry_type in ('payment','credit') then -e.amount_pence::bigint else 0 end),0)::bigint balance
from public.season_teams st left join public.finance_entries e on e.season_team_id=st.id group by st.id,st.season_id)
select se.id,se.name,count(t.team_id) filter(where t.entry_count>0),
coalesce(sum(t.charges),0)::bigint,coalesce(sum(t.payments),0)::bigint,coalesce(sum(t.refunds),0)::bigint,coalesce(sum(t.credits),0)::bigint,coalesce(sum(t.fines),0)::bigint,coalesce(sum(greatest(t.balance,0)),0)::bigint
from public.seasons se left join team_totals t on t.season_id=se.id
where p_season_id is null or se.id=p_season_id group by se.id,se.name order by se.name;
end; $$;

create or replace function public.admin_create_finance_entry(p_season_team_id uuid,p_entry_type text,p_amount_pence integer,p_description text,p_fixture_id uuid default null,p_due_at timestamptz default null,p_payment_method text default null,p_reference text default null,p_notes text default null)
returns public.finance_entries language plpgsql security definer set search_path=''
as $$
declare v_actor uuid:=auth.uid(); v_entry public.finance_entries; v_team public.season_teams;
begin
if v_actor is null or not public.has_finance_access() then raise exception 'Finance permission required'; end if;
if p_entry_type not in ('charge','payment','refund','credit','fine') then raise exception 'Invalid finance entry type'; end if;
if p_amount_pence is null or p_amount_pence<=0 or p_amount_pence>100000000 then raise exception 'Amount must be between 1 penny and £1,000,000'; end if;
if p_description is null or length(btrim(p_description)) not between 3 and 240 then raise exception 'Description must be between 3 and 240 characters'; end if;
if p_notes is not null and length(p_notes)>1000 then raise exception 'Notes are too long'; end if;
if p_reference is not null and length(p_reference)>120 then raise exception 'Reference is too long'; end if;
if p_entry_type='payment' and (p_payment_method is null or p_payment_method not in ('cash','bank_transfer','card_terminal','other')) then raise exception 'Choose a valid manual payment method'; end if;
if p_entry_type<>'payment' and p_payment_method is not null then raise exception 'Payment method can only be set on a payment entry'; end if;
select * into v_team from public.season_teams where id=p_season_team_id;
if not found then raise exception 'Season team not found'; end if;
if p_fixture_id is not null and not exists(select 1 from public.fixtures f where f.id=p_fixture_id and f.season_id=v_team.season_id and p_season_team_id in (f.home_team_id,f.away_team_id)) then raise exception 'Fixture must belong to this team and season'; end if;
insert into public.finance_entries(season_team_id,fixture_id,entry_type,amount_pence,description,due_at,payment_method,reference,notes,created_by)
values(p_season_team_id,p_fixture_id,p_entry_type,p_amount_pence,btrim(p_description),p_due_at,p_payment_method,nullif(btrim(p_reference),''),nullif(btrim(p_notes),''),v_actor) returning * into v_entry;
insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,before_data,after_data) values(v_actor,'finance.entry.created','finance_entry',v_entry.id::text,btrim(p_description),null,to_jsonb(v_entry)-'created_by');
return v_entry;
end; $$;
-- END supabase/migrations/20261108014200_finance_balance_semantics.sql

-- BEGIN supabase/migrations/20261108030000_scope_rls_to_global_admins.sql
-- Location-scoped administrators must use the contextual admin RPCs.
-- RLS policies must not treat every league_admin as a global administrator.
-- Keep has_platform_role() for RPC authorization; use this narrower helper in RLS.

create or replace function public.has_global_admin_role()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.user_roles ur
    where ur.user_id = (select auth.uid())
      and ur.role in ('admin', 'super_admin')
  );
$$;

revoke all on function public.has_global_admin_role() from public, anon;
grant execute on function public.has_global_admin_role() to authenticated;

-- Public/member access remains unchanged. Private admin-wide access is global-only.
drop policy if exists locations_admin_manage on public.locations;
create policy locations_admin_manage on public.locations
for all to authenticated
using ((select public.has_global_admin_role()))
with check ((select public.has_global_admin_role()));

drop policy if exists locations_select_authenticated_active_or_admin on public.locations;
create policy locations_select_authenticated_active_or_admin on public.locations
for select to authenticated
using (is_active = true or (select public.has_global_admin_role()));

drop policy if exists leagues_admin_manage on public.leagues;
create policy leagues_admin_manage on public.leagues
for all to authenticated
using ((select public.has_global_admin_role()))
with check ((select public.has_global_admin_role()));

drop policy if exists leagues_select_authenticated_published_or_admin on public.leagues;
create policy leagues_select_authenticated_published_or_admin on public.leagues
for select to authenticated
using (is_published = true or (select public.has_global_admin_role()));

drop policy if exists seasons_admin_manage on public.seasons;
create policy seasons_admin_manage on public.seasons
for all to authenticated
using ((select public.has_global_admin_role()))
with check ((select public.has_global_admin_role()));

drop policy if exists seasons_select_authenticated_public_or_admin on public.seasons;
create policy seasons_select_authenticated_public_or_admin on public.seasons
for select to authenticated
using (
  (select public.has_global_admin_role())
  or (
    is_public = true
    and exists (
      select 1 from public.leagues l
      where l.id = seasons.league_id and l.is_published = true
    )
  )
);

drop policy if exists teams_admin_manage on public.teams;
create policy teams_admin_manage on public.teams
for all to authenticated
using ((select public.has_global_admin_role()))
with check ((select public.has_global_admin_role()));

drop policy if exists teams_select_authenticated_member_or_admin on public.teams;
create policy teams_select_authenticated_member_or_admin on public.teams
for select to authenticated
using (
  (select public.has_global_admin_role())
  or exists (
    select 1
    from public.season_teams st
    join public.team_memberships tm on tm.season_team_id = st.id
    where st.team_id = teams.id
      and tm.user_id = (select auth.uid())
      and tm.status = 'active'
  )
);

drop policy if exists season_teams_admin_manage on public.season_teams;
create policy season_teams_admin_manage on public.season_teams
for all to authenticated
using ((select public.has_global_admin_role()))
with check ((select public.has_global_admin_role()));

drop policy if exists season_teams_select_authenticated_public_or_member_or_admin on public.season_teams;
create policy season_teams_select_authenticated_public_or_member_or_admin on public.season_teams
for select to authenticated
using (
  (select public.has_global_admin_role())
  or (
    registration_status = 'approved'
    and exists (
      select 1
      from public.seasons s
      join public.leagues l on l.id = s.league_id
      where s.id = season_teams.season_id
        and s.is_public = true
        and l.is_published = true
    )
  )
  or public.is_active_team_member(id)
);

drop policy if exists fixtures_admin_manage on public.fixtures;
create policy fixtures_admin_manage on public.fixtures
for all to authenticated
using ((select public.has_global_admin_role()))
with check ((select public.has_global_admin_role()));

drop policy if exists fixtures_select_authenticated_public_or_member_or_admin on public.fixtures;
create policy fixtures_select_authenticated_public_or_member_or_admin on public.fixtures
for select to authenticated
using (
  (select public.has_global_admin_role())
  or exists (
    select 1
    from public.seasons s
    join public.leagues l on l.id = s.league_id
    where s.id = fixtures.season_id
      and s.is_public = true
      and l.is_published = true
  )
  or public.is_active_team_member(home_team_id)
  or public.is_active_team_member(away_team_id)
);

drop policy if exists fixture_results_admin_manage on public.fixture_results;
create policy fixture_results_admin_manage on public.fixture_results
for all to authenticated
using ((select public.has_global_admin_role()))
with check ((select public.has_global_admin_role()));

drop policy if exists fixture_results_select_authenticated_public_or_admin on public.fixture_results;
create policy fixture_results_select_authenticated_public_or_admin on public.fixture_results
for select to authenticated
using (
  (select public.has_global_admin_role())
  or exists (
    select 1
    from public.fixtures f
    join public.seasons s on s.id = f.season_id
    join public.leagues l on l.id = s.league_id
    where f.id = fixture_results.fixture_id
      and s.is_public = true
      and l.is_published = true
  )
);

drop policy if exists team_memberships_admin_manage on public.team_memberships;
create policy team_memberships_admin_manage on public.team_memberships
for all to authenticated
using ((select public.has_global_admin_role()))
with check ((select public.has_global_admin_role()));

drop policy if exists team_memberships_select_self_captain_or_admin on public.team_memberships;
create policy team_memberships_select_self_captain_or_admin on public.team_memberships
for select to authenticated
using (
  user_id = (select auth.uid())
  or public.is_active_team_captain(season_team_id)
  or (select public.has_global_admin_role())
);

drop policy if exists fixture_availability_admin_manage on public.fixture_availability;
create policy fixture_availability_admin_manage on public.fixture_availability
for all to authenticated
using ((select public.has_global_admin_role()))
with check ((select public.has_global_admin_role()));

drop policy if exists fixture_availability_select_player_captain_or_admin on public.fixture_availability;
create policy fixture_availability_select_player_captain_or_admin on public.fixture_availability
for select to authenticated
using (
  user_id = (select auth.uid())
  or (select public.has_global_admin_role())
  or exists (
    select 1
    from public.fixtures f
    join public.team_memberships captain
      on captain.user_id = (select auth.uid())
      and captain.is_captain = true
      and captain.status = 'active'
      and (
        captain.season_team_id = f.home_team_id
        or captain.season_team_id = f.away_team_id
      )
    join public.team_memberships player_membership
      on player_membership.season_team_id = captain.season_team_id
      and player_membership.user_id = fixture_availability.user_id
      and player_membership.status = 'active'
    where f.id = fixture_availability.fixture_id
  )
);

drop policy if exists fixture_team_sheets_admin_manage on public.fixture_team_sheets;
create policy fixture_team_sheets_admin_manage on public.fixture_team_sheets
for all to authenticated
using ((select public.has_global_admin_role()))
with check ((select public.has_global_admin_role()));

drop policy if exists fixture_team_sheets_select_team_or_admin on public.fixture_team_sheets;
create policy fixture_team_sheets_select_team_or_admin on public.fixture_team_sheets
for select to authenticated
using (
  (select public.has_global_admin_role())
  or public.is_active_team_member(season_team_id)
  or public.is_active_team_captain(season_team_id)
);

drop policy if exists fixture_team_sheet_players_admin_manage on public.fixture_team_sheet_players;
create policy fixture_team_sheet_players_admin_manage on public.fixture_team_sheet_players
for all to authenticated
using ((select public.has_global_admin_role()))
with check ((select public.has_global_admin_role()));

drop policy if exists fixture_team_sheet_players_select_team_or_admin on public.fixture_team_sheet_players;
create policy fixture_team_sheet_players_select_team_or_admin on public.fixture_team_sheet_players
for select to authenticated
using (
  (select public.has_global_admin_role())
  or exists (
    select 1
    from public.fixture_team_sheets ts
    where ts.id = fixture_team_sheet_players.team_sheet_id
      and public.is_active_team_member(ts.season_team_id)
  )
);

-- Personal identity, notification, review, transfer and role data are not
-- directly readable by location admins. Their scoped admin views use RPCs.
drop policy if exists notification_events_select_owner_or_admin on public.notification_events;
create policy notification_events_select_owner_or_admin on public.notification_events
for select to authenticated
using (user_id = (select auth.uid()) or (select public.has_global_admin_role()));

drop policy if exists notification_preferences_select_owner_or_admin on public.notification_preferences;
create policy notification_preferences_select_owner_or_admin on public.notification_preferences
for select to authenticated
using (user_id = (select auth.uid()) or (select public.has_global_admin_role()));

drop policy if exists player_registration_reviews_admin_only on public.player_registration_reviews;
create policy player_registration_reviews_admin_only on public.player_registration_reviews
for select to authenticated
using ((select public.has_global_admin_role()));

drop policy if exists players_select_self_or_admin on public.players;
create policy players_select_self_or_admin on public.players
for select to authenticated
using (user_id = (select auth.uid()) or (select public.has_global_admin_role()));

drop policy if exists profiles_select_self_or_admin on public.profiles;
create policy profiles_select_self_or_admin on public.profiles
for select to authenticated
using (id = (select auth.uid()) or (select public.has_global_admin_role()));

drop policy if exists profiles_update_self_or_admin on public.profiles;
create policy profiles_update_self_or_admin on public.profiles
for update to authenticated
using (id = (select auth.uid()) or (select public.has_global_admin_role()))
with check (id = (select auth.uid()) or (select public.has_global_admin_role()));

drop policy if exists season_registrations_admin_manage on public.season_registrations;
create policy season_registrations_admin_manage on public.season_registrations
for all to authenticated
using ((select public.has_global_admin_role()))
with check ((select public.has_global_admin_role()));

drop policy if exists season_registrations_select_self_or_admin on public.season_registrations;
create policy season_registrations_select_self_or_admin on public.season_registrations
for select to authenticated
using (user_id = (select auth.uid()) or (select public.has_global_admin_role()));

drop policy if exists transfer_requests_select_player_or_admin on public.transfer_requests;
create policy transfer_requests_select_player_or_admin on public.transfer_requests
for select to authenticated
using (player_id = (select auth.uid()) or (select public.has_global_admin_role()));

drop policy if exists player_transfer_requests_select_owner_or_admin on public.player_transfer_requests;
create policy player_transfer_requests_select_owner_or_admin on public.player_transfer_requests
for select to authenticated
using (user_id = (select auth.uid()) or (select public.has_global_admin_role()));

drop policy if exists user_roles_select_self_or_admin on public.user_roles;
create policy user_roles_select_self_or_admin on public.user_roles
for select to authenticated
using (user_id = (select auth.uid()) or (select public.has_global_admin_role()));

-- END supabase/migrations/20261108030000_scope_rls_to_global_admins.sql

-- BEGIN supabase/migrations/20261108031000_revoke_unscoped_admin_rpcs.sql
-- These legacy admin RPCs return unscoped cross-location data.
-- The current application uses the corresponding *_contextual RPCs instead.
-- Revoke client execution so location-scoped league_admin users cannot bypass
-- location context through SECURITY DEFINER endpoints.

revoke all on function public.get_admin_dashboard() from public, anon, authenticated;
revoke all on function public.get_admin_player_register(text, text, integer, integer) from public, anon, authenticated;
revoke all on function public.get_admin_team_sheets() from public, anon, authenticated;
revoke all on function public.admin_get_transfer_requests(text) from public, anon, authenticated;

-- These table-returning/admin functions have output or parameter names that
-- overlap with user_roles columns. Qualify every role-table reference so
-- PL/pgSQL resolves the intended columns and the global-admin guard runs.

create or replace function public.admin_list_location_assignments(p_location_id uuid default null)
returns table(
  assignment_id uuid,
  user_id uuid,
  location_id uuid,
  location_name text,
  assigned_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not exists (
    select 1
    from public.user_roles ur
    where ur.user_id = auth.uid()
      and ur.role in ('admin','super_admin')
  ) then
    raise exception 'Global administrator permission required';
  end if;

  return query
  select a.id, a.user_id, a.location_id, l.name, a.created_at
  from public.location_admin_assignments a
  join public.locations l on l.id = a.location_id
  where p_location_id is null or a.location_id = p_location_id
  order by l.name, a.created_at desc;
end;
$$;

create or replace function public.admin_set_location_assignment(
  p_user_id uuid,
  p_location_id uuid,
  p_assigned boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not exists (
    select 1
    from public.user_roles ur
    where ur.user_id = auth.uid()
      and ur.role in ('admin','super_admin')
  ) then
    raise exception 'Global administrator permission required';
  end if;

  if not exists (
    select 1
    from public.user_roles ur
    where ur.user_id = p_user_id
      and ur.role = 'league_admin'
  ) then
    raise exception 'The selected user must have the league_admin role';
  end if;

  if not exists (
    select 1 from public.locations l where l.id = p_location_id
  ) then
    raise exception 'Location not found';
  end if;

  if p_assigned then
    insert into public.location_admin_assignments(user_id,location_id,assigned_by)
    values (p_user_id,p_location_id,auth.uid())
    on conflict(user_id,location_id) do nothing;
  else
    delete from public.location_admin_assignments
    where user_id = p_user_id and location_id = p_location_id;
  end if;
end;
$$;

revoke all on function public.admin_list_location_assignments(uuid) from public, anon;
revoke all on function public.admin_set_location_assignment(uuid,uuid,boolean) from public, anon;
grant execute on function public.admin_list_location_assignments(uuid) to authenticated;
grant execute on function public.admin_set_location_assignment(uuid,uuid,boolean) to authenticated;

-- END supabase/migrations/20261108031000_revoke_unscoped_admin_rpcs.sql

-- BEGIN supabase/migrations/20261108032000_fix_captain_membership_approval_scope.sql
-- Captains may approve/reject requests for their own active team.
-- Location administrators and global admins may act only within the location
-- scope granted by can_administer_location(). Do not gate captains on a
-- location-admin assignment before checking captain ownership.

create or replace function public.resolve_team_membership_request(
  p_membership_id uuid,
  p_decision text
)
returns public.team_memberships
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_actor uuid := auth.uid();
  v_membership public.team_memberships;
  v_team public.season_teams;
  v_season public.seasons;
  v_player public.players;
  v_location_id uuid;
begin
  if v_actor is null then
    raise exception 'Authentication required';
  end if;

  if p_decision not in ('approved','rejected') then
    raise exception 'Decision must be approved or rejected';
  end if;

  -- Read the pending request first so we can evaluate its owning team and
  -- location before taking a write lock.
  select *
  into v_membership
  from public.team_memberships
  where id = p_membership_id
    and status = 'pending';

  if not found then
    raise exception 'No pending team request exists';
  end if;

  select l.location_id
  into v_location_id
  from public.season_teams st
  join public.seasons s on s.id = st.season_id
  join public.leagues l on l.id = s.league_id
  where st.id = v_membership.season_team_id;

  if not public.is_active_team_captain(v_membership.season_team_id)
     and not public.can_administer_location(v_location_id) then
    raise exception 'Captain or assigned location administrator permission required';
  end if;

  -- Recheck and lock the request after authorization to prevent stale writes.
  select *
  into v_membership
  from public.team_memberships
  where id = p_membership_id
    and status = 'pending'
  for update;

  if not found then
    raise exception 'No pending team request exists';
  end if;

  if p_decision = 'approved' then
    select *
    into v_team
    from public.season_teams
    where id = v_membership.season_team_id
    for share;

    if not found or v_team.registration_status <> 'approved' then
      raise exception 'Only approved teams can accept players';
    end if;

    select *
    into v_season
    from public.seasons
    where id = v_team.season_id
    for share;

    if not found or v_season.status not in ('registration_open','active') then
      raise exception 'Membership approvals are closed for this season';
    end if;

    select *
    into v_player
    from public.players
    where user_id = v_membership.user_id
    for share;

    if not found or v_player.registration_status <> 'registered' or v_player.is_banned then
      raise exception 'Only registered, eligible players can join a team';
    end if;

    -- Serialize approvals for the same player/season across different teams.
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(
        v_membership.user_id::text || ':' || v_team.season_id::text,
        0
      )
    );

    if exists (
      select 1
      from public.team_memberships tm
      join public.season_teams other_team on other_team.id = tm.season_team_id
      where tm.user_id = v_membership.user_id
        and tm.status = 'active'
        and other_team.season_id = v_team.season_id
        and tm.season_team_id <> v_membership.season_team_id
    ) then
      raise exception 'This player is already active in another team in this season. Use the transfer workflow.';
    end if;
  end if;

  update public.team_memberships
  set
    status = case
      when p_decision = 'approved' then 'active'::public.membership_status
      else 'rejected'::public.membership_status
    end,
    joined_at = case when p_decision = 'approved' then now() else joined_at end,
    left_at = case when p_decision = 'rejected' then now() else null end
  where id = p_membership_id
  returning * into v_membership;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,after_data)
  values (
    v_actor,
    'team.membership.' || p_decision,
    'team_membership',
    p_membership_id::text,
    jsonb_build_object('status',v_membership.status)
  );

  return v_membership;
end;
$function$;

revoke all on function public.resolve_team_membership_request(uuid,text) from public, anon;
grant execute on function public.resolve_team_membership_request(uuid,text) to authenticated;

-- END supabase/migrations/20261108032000_fix_captain_membership_approval_scope.sql

-- BEGIN supabase/migrations/20261109000000_correct_membership_location_and_finance_authorization.sql
-- Forward-only correction for three live authorization mismatches.
-- This migration intentionally preserves the existing business logic and audit paths.
do $migration$
declare
  v_def text;
  v_old text;
  v_new text;
begin
  -- Location activation is a platform-wide control: only admin/super_admin.
  v_def := pg_catalog.pg_get_functiondef(
    'public.admin_set_location_active(uuid,boolean,text)'::regprocedure
  );
  v_old := ' if not public.can_administer_location(p_location_id) then raise exception ''You are not assigned to this location''; end if;' || E'\n';
  if pg_catalog.strpos(v_def, v_old) = 0 then
    raise exception 'Expected location activation scope guard not found; refusing partial migration';
  end if;
  v_def := pg_catalog.replace(v_def, v_old, '');
  v_old := '  if v_actor is null or not public.has_platform_role() then' || E'\n' ||
           '    raise exception ''Administrator permission required'' using errcode = ''42501'';' || E'\n' ||
           '  end if;';
  v_new := '  if v_actor is null or not exists (' || E'\n' ||
           '    select 1 from public.user_roles ur' || E'\n' ||
           '    where ur.user_id=v_actor and ur.role in (''admin'',''super_admin'')' || E'\n' ||
           '  ) then' || E'\n' ||
           '    raise exception ''Global administrator permission required'' using errcode = ''42501'';' || E'\n' ||
           '  end if;';
  if pg_catalog.strpos(v_def, v_old) = 0 then
    raise exception 'Expected location activation role guard not found; refusing partial migration';
  end if;
  v_def := pg_catalog.replace(v_def, v_old, v_new);
  execute v_def;

  -- finance_admin is intentionally a global finance role per has_finance_access().
  -- Validate the season below; do not impose unrelated league-admin assignment.
  v_def := pg_catalog.pg_get_functiondef(
    'public.admin_set_player_fixture_fee(uuid,integer,integer,text)'::regprocedure
  );
  v_old := ' if not public.can_administer_location((select l.location_id from public.seasons s join public.leagues l on l.id=s.league_id where s.id=p_season_id)) then raise exception ''You are not assigned to this location''; end if;' || E'\n';
  if pg_catalog.strpos(v_def, v_old) = 0 then
    raise exception 'Expected player-fee location guard not found; refusing partial migration';
  end if;
  v_def := pg_catalog.replace(v_def, v_old, '');
  if pg_catalog.strpos(v_def, 'if not public.has_finance_access()') = 0 then
    raise exception 'Finance authorization guard missing; refusing partial migration';
  end if;
  execute v_def;
end;
$migration$;

-- END supabase/migrations/20261109000000_correct_membership_location_and_finance_authorization.sql

-- BEGIN supabase/migrations/20261109020000_fix_player_duplicate_identity_matching.sql
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

-- END supabase/migrations/20261109020000_fix_player_duplicate_identity_matching.sql

-- BEGIN supabase/migrations/20261109021000_restrict_identity_reviews_to_global_admins.sql
-- Phase 1: identity-review evidence is visible only to global administrators.
-- League administrators retain their location-scoped operational permissions but
-- must not be able to read global player identity-review evidence directly.

drop policy if exists player_registration_reviews_admin_only
  on public.player_registration_reviews;

create policy player_registration_reviews_admin_only
  on public.player_registration_reviews
  for select
  to authenticated
  using (public.has_global_admin_role());

-- Identity-review rows are private to global administrators. Remove any
-- inherited/default grants to anonymous or PUBLIC while retaining the
-- authenticated SELECT grant required for the global-admin RLS policy.
revoke all privileges on table public.player_registration_reviews from anon, public;
grant select on table public.player_registration_reviews to authenticated;

-- END supabase/migrations/20261109021000_restrict_identity_reviews_to_global_admins.sql

-- Phase 1 profile self-service is picture-only, as confirmed in issue #25.
-- Verified email/phone changes and administrator corrections use separate guarded workflows.
revoke update on table public.profiles from authenticated;
revoke update (
  first_name,
  last_name,
  display_name,
  phone,
  preferred_position
) on table public.profiles from authenticated;
grant update (avatar_path) on table public.profiles to authenticated;
