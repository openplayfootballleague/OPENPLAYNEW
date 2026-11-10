-- Referee match reports, administrator approval, disciplinary records and payout obligations.
-- Draft source is generated into a timestamped migration by the pinned Supabase CLI in CI.

alter table public.players
  add column disciplinary_strikes integer not null default 0,
  add column disciplinary_inactive boolean not null default false,
  add constraint players_disciplinary_strikes_nonnegative check (disciplinary_strikes >= 0);

create table public.referee_match_reports (
  id uuid primary key default gen_random_uuid(),
  fixture_id uuid not null unique references public.fixtures(id) on delete restrict,
  referee_user_id uuid references auth.users(id) on delete set null,
  report_source text not null check (report_source in ('referee','admin')),
  submitted_by uuid references auth.users(id) on delete set null,
  status text not null default 'submitted'
    check (status in ('submitted','rejected','approved','voided')),
  home_score smallint not null check (home_score between 0 and 32767),
  away_score smallint not null check (away_score between 0 and 32767),
  home_scorers uuid[] not null default '{}'::uuid[],
  away_scorers uuid[] not null default '{}'::uuid[],
  home_substitute_appearances uuid[] not null default '{}'::uuid[],
  away_substitute_appearances uuid[] not null default '{}'::uuid[],
  disciplinary_events jsonb not null default '[]'::jsonb
    check (jsonb_typeof(disciplinary_events) = 'array'),
  match_write_up text check (match_write_up is null or length(match_write_up) <= 2000),
  version integer not null default 1 check (version > 0),
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references auth.users(id) on delete set null,
  review_reason text,
  approved_at timestamptz,
  approved_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint referee_match_report_review_state check (
    (status = 'submitted' and reviewed_at is null and reviewed_by is null and approved_at is null and approved_by is null)
    or (status = 'rejected' and reviewed_at is not null and reviewed_by is not null and approved_at is null and approved_by is null)
    or (status = 'approved' and reviewed_at is not null and reviewed_by is not null and approved_at is not null and approved_by is not null)
    or (status = 'voided' and reviewed_at is not null and reviewed_by is not null)
  ),
  constraint referee_match_report_source_valid check (report_source in ('referee','admin'))
);
create index referee_match_reports_status_submitted_idx
  on public.referee_match_reports(status, submitted_at desc);
create index referee_match_reports_referee_status_idx
  on public.referee_match_reports(referee_user_id, status, approved_at desc);

create table public.referee_match_report_history (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.referee_match_reports(id) on delete restrict,
  report_version integer not null,
  action text not null check (action in ('resubmitted','admin_edited','rejected','approved','voided')),
  snapshot jsonb not null,
  changed_by uuid references auth.users(id) on delete set null,
  reason text,
  created_at timestamptz not null default now(),
  unique(report_id, report_version, action, created_at)
);
create index referee_match_report_history_report_idx
  on public.referee_match_report_history(report_id, created_at desc);

create table public.referee_disciplinary_events (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.referee_match_reports(id) on delete restrict,
  event_index integer not null check (event_index between 0 and 49),
  fixture_id uuid not null references public.fixtures(id) on delete restrict,
  season_team_id uuid not null references public.season_teams(id) on delete restrict,
  competition_player_id uuid references public.competition_player_identities(id) on delete restrict,
  recipient_type text not null check (recipient_type in ('registered_player','bench','supporter')),
  card_type text not null check (card_type in ('yellow','second_yellow_red','straight_red')),
  minute integer check (minute is null or minute between 0 and 120),
  description text check (description is null or length(description) <= 500),
  fine_amount_pence integer not null check (fine_amount_pence in (500,1500,3000)),
  strike_applied boolean not null default false,
  finance_entry_id uuid references public.finance_entries(id) on delete restrict,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  voided_at timestamptz,
  voided_by uuid references auth.users(id) on delete set null,
  void_reason text,
  constraint referee_disciplinary_event_player_pair check (
    (recipient_type = 'registered_player' and competition_player_id is not null)
    or (recipient_type in ('bench','supporter') and competition_player_id is null)
  ),
  constraint referee_disciplinary_event_strike check (
    strike_applied = (recipient_type = 'registered_player' and card_type = 'straight_red')
  ),
  constraint referee_disciplinary_event_void_pair check (
    (voided_at is null and voided_by is null and void_reason is null)
    or (voided_at is not null and length(btrim(coalesce(void_reason,''))) >= 5)
  ),
  unique(report_id, event_index)
);
create index referee_disciplinary_events_identity_idx
  on public.referee_disciplinary_events(competition_player_id, created_at desc)
  where competition_player_id is not null;

create table public.referee_report_payouts (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null unique references public.referee_match_reports(id) on delete restrict,
  referee_user_id uuid references auth.users(id) on delete set null,
  gross_allocation_pence integer not null default 2200 check (gross_allocation_pence = 2200),
  deductions_pence integer not null default 0 check (deductions_pence >= 0),
  referee_net_pence integer not null default 2200 check (referee_net_pence >= 2000),
  open_play_top_up_pence integer not null default 0 check (open_play_top_up_pence >= 0),
  constraint referee_report_payout_net_reconciliation check (referee_net_pence = gross_allocation_pence - deductions_pence + open_play_top_up_pence),
  status text not null default 'pending_connect'
    check (status in ('pending_connect','transferred','failed','cancelled')),
  stripe_transfer_id text unique,
  failure_reason text,
  created_at timestamptz not null default now(),
  transferred_at timestamptz
);
create index referee_report_payouts_referee_status_idx
  on public.referee_report_payouts(referee_user_id, status, created_at desc);

create table public.referee_milestone_rewards (
  id uuid primary key default gen_random_uuid(),
  referee_user_id uuid references auth.users(id) on delete set null,
  milestone_number integer not null check (milestone_number between 1 and 10),
  approved_games integer not null check (approved_games = milestone_number * 50),
  amount_pence integer not null default 5000 check (amount_pence = 5000),
  status text not null default 'pending_connect'
    check (status in ('pending_connect','transferred','failed','cancelled')),
  stripe_transfer_id text unique,
  created_at timestamptz not null default now(),
  transferred_at timestamptz,
  unique(referee_user_id, milestone_number)
);

alter table public.referee_match_reports enable row level security;
alter table public.referee_match_report_history enable row level security;
alter table public.referee_disciplinary_events enable row level security;
alter table public.referee_report_payouts enable row level security;
alter table public.referee_milestone_rewards enable row level security;
revoke all on public.referee_match_reports, public.referee_match_report_history,
  public.referee_disciplinary_events, public.referee_report_payouts,
  public.referee_milestone_rewards from public, anon, authenticated;

create or replace function public.prevent_disciplinary_inactive_team_sheet_player()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (
    select 1 from public.players player
    where player.competition_player_id = new.competition_player_id
      and player.disciplinary_inactive is true
  ) then
    raise exception 'This player is inactive following disciplinary strikes and requires administrator reactivation';
  end if;
  return new;
end;
$$;
revoke all on function public.prevent_disciplinary_inactive_team_sheet_player() from public, anon, authenticated;
create trigger fixture_team_sheet_player_disciplinary_guard
before insert or update of competition_player_id, role
on public.fixture_team_sheet_players
for each row execute function public.prevent_disciplinary_inactive_team_sheet_player();

create or replace function public._save_referee_match_report(
  p_actor uuid,
  p_source text,
  p_fixture_id uuid,
  p_home_score integer,
  p_away_score integer,
  p_home_substitute_appearances uuid[],
  p_away_substitute_appearances uuid[],
  p_home_scorers uuid[],
  p_away_scorers uuid[],
  p_disciplinary_events jsonb,
  p_match_write_up text,
  p_reason text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_fixture public.fixtures;
  v_home_sheet public.fixture_team_sheets;
  v_away_sheet public.fixture_team_sheets;
  v_existing public.referee_match_reports;
  v_report_id uuid;
  v_report_source text;
  v_referee_user_id uuid;
  v_latest_gameweek integer;
  v_latest_fixture_at timestamptz;
  v_event jsonb;
  v_team_id uuid;
  v_player_id uuid;
  v_recipient text;
  v_card text;
  v_minute integer;
  v_description text;
  v_deadline timestamptz;
  v_before jsonb;
begin
  if p_actor is null or p_source not in ('referee','admin') then
    raise exception 'A valid authenticated report submitter is required';
  end if;
  if p_home_score is null or p_away_score is null or p_home_score not between 0 and 32767 or p_away_score not between 0 and 32767 then
    raise exception 'Scores must be whole numbers between 0 and 32767';
  end if;
  if cardinality(coalesce(p_home_scorers,'{}'::uuid[])) <> p_home_score
     or cardinality(coalesce(p_away_scorers,'{}'::uuid[])) <> p_away_score then
    raise exception 'Select exactly one goalscorer for every goal';
  end if;
  if cardinality(coalesce(p_home_substitute_appearances,'{}'::uuid[])) <>
     (select count(distinct x) from unnest(coalesce(p_home_substitute_appearances,'{}'::uuid[])) x)
     or cardinality(coalesce(p_away_substitute_appearances,'{}'::uuid[])) <>
     (select count(distinct x) from unnest(coalesce(p_away_substitute_appearances,'{}'::uuid[])) x) then
    raise exception 'A substitute can only be selected once';
  end if;
  if exists(select 1 from unnest(coalesce(p_home_substitute_appearances,'{}'::uuid[])) x where x is null)
     or exists(select 1 from unnest(coalesce(p_away_substitute_appearances,'{}'::uuid[])) x where x is null)
     or exists(select 1 from unnest(coalesce(p_home_scorers,'{}'::uuid[])) x where x is null)
     or exists(select 1 from unnest(coalesce(p_away_scorers,'{}'::uuid[])) x where x is null) then
    raise exception 'Player selections cannot contain empty values';
  end if;
  if p_disciplinary_events is null or jsonb_typeof(p_disciplinary_events) <> 'array'
     or jsonb_array_length(p_disciplinary_events) > 50 then
    raise exception 'Disciplinary events must be a list of no more than 50 cards';
  end if;
  if p_match_write_up is not null and length(p_match_write_up) > 2000 then
    raise exception 'Match write-up must be 2,000 characters or fewer';
  end if;

  select * into v_fixture from public.fixtures where id=p_fixture_id for update;
  if not found then raise exception 'Fixture not found'; end if;
  if v_fixture.scheduled_at is null or v_fixture.scheduled_at > now()
     or v_fixture.status in ('cancelled','postponed') then
    raise exception 'Only a fixture that has taken place can receive a match report';
  end if;

  select * into v_home_sheet from public.fixture_team_sheets
  where fixture_id=p_fixture_id and season_team_id=v_fixture.home_team_id and is_locked=true;
  if not found then raise exception 'The home team must submit and lock its team sheet before a report can be submitted'; end if;
  select * into v_away_sheet from public.fixture_team_sheets
  where fixture_id=p_fixture_id and season_team_id=v_fixture.away_team_id and is_locked=true;
  if not found then raise exception 'The away team must submit and lock its team sheet before a report can be submitted'; end if;

  for v_event in select value from jsonb_array_elements(p_disciplinary_events) loop
    v_team_id:=nullif(v_event->>'season_team_id','')::uuid;
    v_recipient:=v_event->>'recipient_type';
    v_card:=v_event->>'card_type';
    v_player_id:=nullif(v_event->>'competition_player_id','')::uuid;
    v_minute:=nullif(v_event->>'minute','')::integer;
    v_description:=nullif(btrim(coalesce(v_event->>'description','')),'');
    if v_team_id is null or v_team_id not in (v_fixture.home_team_id,v_fixture.away_team_id) then
      raise exception 'Each disciplinary event must belong to one of the fixture teams';
    end if;
    if v_recipient is null or v_recipient not in ('registered_player','bench','supporter')
       or v_card is null or v_card not in ('yellow','second_yellow_red','straight_red') then
      raise exception 'Invalid disciplinary recipient or card type';
    end if;
    if v_minute is not null and v_minute not between 0 and 120 then
      raise exception 'Disciplinary event minute must be between 0 and 120';
    end if;
    if v_description is not null and length(v_description)>500 then
      raise exception 'Disciplinary event notes must be 500 characters or fewer';
    end if;
    if v_recipient='registered_player' then
      if v_player_id is null or not exists(
        select 1 from public.fixture_team_sheet_players tsp
        where tsp.team_sheet_id=case when v_team_id=v_fixture.home_team_id then v_home_sheet.id else v_away_sheet.id end
          and tsp.competition_player_id=v_player_id
      ) then
        raise exception 'Registered player cards must identify a player on that team sheet';
      end if;
    elsif v_player_id is not null then
      raise exception 'Bench and supporter events cannot identify a registered player';
    end if;
  end loop;

  if exists (
    select 1 from unnest(coalesce(p_home_substitute_appearances,'{}'::uuid[])) selected(identity_id)
    where not exists(select 1 from public.fixture_team_sheet_players tsp
      where tsp.team_sheet_id=v_home_sheet.id and tsp.competition_player_id=selected.identity_id and tsp.role='substitute')
  ) or exists (
    select 1 from unnest(coalesce(p_away_substitute_appearances,'{}'::uuid[])) selected(identity_id)
    where not exists(select 1 from public.fixture_team_sheet_players tsp
      where tsp.team_sheet_id=v_away_sheet.id and tsp.competition_player_id=selected.identity_id and tsp.role='substitute')
  ) then
    raise exception 'Substitute appearances must match the submitted team sheets';
  end if;

  if exists (
    select 1 from unnest(coalesce(p_home_scorers,'{}'::uuid[])) scorer(identity_id)
    where not exists(select 1 from public.fixture_team_sheet_players tsp
      where tsp.team_sheet_id=v_home_sheet.id and tsp.competition_player_id=scorer.identity_id
        and (tsp.role='starter' or scorer.identity_id=any(coalesce(p_home_substitute_appearances,'{}'::uuid[]))))
  ) or exists (
    select 1 from unnest(coalesce(p_away_scorers,'{}'::uuid[])) scorer(identity_id)
    where not exists(select 1 from public.fixture_team_sheet_players tsp
      where tsp.team_sheet_id=v_away_sheet.id and tsp.competition_player_id=scorer.identity_id
        and (tsp.role='starter' or scorer.identity_id=any(coalesce(p_away_substitute_appearances,'{}'::uuid[]))))
  ) then
    raise exception 'Every goalscorer must be a starter or a substitute marked as having appeared';
  end if;

  if p_source='referee' then
    if not exists(select 1 from public.referee_memberships membership
      where membership.user_id=p_actor and membership.status='active') then
      raise exception 'An active referee membership is required to submit a match report';
    end if;
    if not exists(select 1 from public.referee_fixture_assignments assignment
      where assignment.fixture_id=p_fixture_id and assignment.referee_user_id=p_actor
        and assignment.cancelled_at is null) then
      raise exception 'Only the appointed referee can submit this fixture report';
    end if;
    select max(gameweek) into v_latest_gameweek
    from public.fixtures
    where season_id=v_fixture.season_id and scheduled_at<=now()
      and status not in ('cancelled','postponed');
    select max(scheduled_at) into v_latest_fixture_at
    from public.fixtures
    where season_id=v_fixture.season_id and gameweek=v_latest_gameweek
      and scheduled_at is not null and status not in ('cancelled','postponed');
    v_deadline:=v_latest_fixture_at+interval '24 hours';
  else
    if not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
    perform public.assert_admin_location_context((
      select league.location_id from public.seasons season
      join public.leagues league on league.id=season.league_id
      where season.id=v_fixture.season_id
    ));
  end if;

  select * into v_existing from public.referee_match_reports where fixture_id=p_fixture_id for update;
  if found then
    if v_existing.status='approved' or v_existing.status='voided' then
      raise exception 'An approved or voided match report cannot be overwritten';
    end if;
    if p_source='referee' and (v_existing.status<>'rejected'
       or v_existing.report_source<>'referee' or v_existing.referee_user_id<>p_actor) then
      raise exception 'Only your rejected report can be resubmitted';
    end if;
    if p_source='referee' and v_existing.status<>'rejected' and v_fixture.gameweek<>v_latest_gameweek then
      raise exception 'Referees can only submit reports for the latest completed gameweek';
    end if;
    if p_source='referee' and v_existing.status<>'rejected' and now()>v_deadline then
      raise exception 'The 24-hour referee reporting window has closed';
    end if;
    v_report_source:=v_existing.report_source;
    v_referee_user_id:=v_existing.referee_user_id;
    v_before:=jsonb_build_object(
      'status',v_existing.status,'home_score',v_existing.home_score,'away_score',v_existing.away_score,
      'home_scorers',to_jsonb(v_existing.home_scorers),'away_scorers',to_jsonb(v_existing.away_scorers),
      'home_substitute_appearances',to_jsonb(v_existing.home_substitute_appearances),
      'away_substitute_appearances',to_jsonb(v_existing.away_substitute_appearances),
      'disciplinary_events',v_existing.disciplinary_events,'match_write_up',v_existing.match_write_up,
      'review_reason',v_existing.review_reason
    );
    insert into public.referee_match_report_history(report_id,report_version,action,snapshot,changed_by,reason)
    values(v_existing.id,v_existing.version,
      case when p_source='admin' then 'admin_edited' else 'resubmitted' end,
      v_before,p_actor,nullif(btrim(p_reason),''));
    update public.referee_match_reports
    set report_source=v_report_source,referee_user_id=v_referee_user_id,
        submitted_by=p_actor,status='submitted',home_score=p_home_score,away_score=p_away_score,
        home_scorers=coalesce(p_home_scorers,'{}'::uuid[]),
        away_scorers=coalesce(p_away_scorers,'{}'::uuid[]),
        home_substitute_appearances=coalesce(p_home_substitute_appearances,'{}'::uuid[]),
        away_substitute_appearances=coalesce(p_away_substitute_appearances,'{}'::uuid[]),
        disciplinary_events=p_disciplinary_events,match_write_up=nullif(btrim(coalesce(p_match_write_up,'')),''),
        version=version+1,submitted_at=now(),reviewed_at=null,reviewed_by=null,review_reason=null,
        approved_at=null,approved_by=null,updated_at=now()
    where id=v_existing.id returning id into v_report_id;
  else
    v_report_source:=case when p_source='referee' then 'referee' else 'admin' end;
    v_referee_user_id:=case when p_source='referee' then p_actor else null end;
    if p_source='referee' then
      if v_fixture.gameweek<>v_latest_gameweek then
        raise exception 'Referees can only submit reports for the latest completed gameweek';
      end if;
      if now()>v_deadline then raise exception 'The 24-hour referee reporting window has closed'; end if;
    end if;
    insert into public.referee_match_reports(
      fixture_id,referee_user_id,report_source,submitted_by,status,home_score,away_score,
      home_scorers,away_scorers,home_substitute_appearances,away_substitute_appearances,
      disciplinary_events,match_write_up
    ) values(
      p_fixture_id,v_referee_user_id,v_report_source,p_actor,'submitted',p_home_score,p_away_score,
      coalesce(p_home_scorers,'{}'::uuid[]),coalesce(p_away_scorers,'{}'::uuid[]),
      coalesce(p_home_substitute_appearances,'{}'::uuid[]),coalesce(p_away_substitute_appearances,'{}'::uuid[]),
      p_disciplinary_events,nullif(btrim(coalesce(p_match_write_up,'')),'')
    ) returning id into v_report_id;
    v_before:='{}'::jsonb;
  end if;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,before_data,after_data)
  values(p_actor,case when p_source='admin' then 'referee.report.admin_submitted' else 'referee.report.submitted' end,
    'referee_match_report',v_report_id::text,nullif(btrim(p_reason),''),
    v_before,jsonb_build_object('fixture_id',p_fixture_id,'status','submitted','version',
      (select version from public.referee_match_reports where id=v_report_id)));
  return v_report_id;
end;
$$;
revoke all on function public._save_referee_match_report(uuid,text,uuid,integer,integer,uuid[],uuid[],uuid[],uuid[],jsonb,text,text)
  from public,anon,authenticated;

create or replace function public.get_my_referee_fixture_report_options(p_fixture_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid:=auth.uid();
  v_fixture public.fixtures;
  v_home_sheet public.fixture_team_sheets;
  v_away_sheet public.fixture_team_sheets;
  v_report public.referee_match_reports;
  v_latest_gameweek integer;
  v_latest_fixture_at timestamptz;
  v_deadline timestamptz;
begin
  if v_actor is null or not exists(select 1 from public.referee_memberships
    where user_id=v_actor and status='active') then
    raise exception 'An active referee membership is required';
  end if;
  select * into v_fixture from public.fixtures where id=p_fixture_id;
  if not found then raise exception 'Fixture not found'; end if;
  if not exists(select 1 from public.referee_fixture_assignments
    where fixture_id=p_fixture_id and referee_user_id=v_actor and cancelled_at is null) then
    raise exception 'You are not appointed to this fixture';
  end if;
  select * into v_home_sheet from public.fixture_team_sheets
    where fixture_id=p_fixture_id and season_team_id=v_fixture.home_team_id and is_locked=true;
  select * into v_away_sheet from public.fixture_team_sheets
    where fixture_id=p_fixture_id and season_team_id=v_fixture.away_team_id and is_locked=true;
  if v_home_sheet.id is null or v_away_sheet.id is null then
    raise exception 'Both team sheets must be submitted before a report can be prepared';
  end if;
  select max(gameweek) into v_latest_gameweek from public.fixtures
    where season_id=v_fixture.season_id and scheduled_at<=now() and status not in ('cancelled','postponed');
  select max(scheduled_at) into v_latest_fixture_at from public.fixtures
    where season_id=v_fixture.season_id and gameweek=v_latest_gameweek
      and scheduled_at is not null and status not in ('cancelled','postponed');
  v_deadline:=v_latest_fixture_at+interval '24 hours';
  select * into v_report from public.referee_match_reports where fixture_id=p_fixture_id;
  return jsonb_build_object(
    'fixture',jsonb_build_object('id',v_fixture.id,'gameweek',v_fixture.gameweek,
      'fixture_number',v_fixture.fixture_number,'scheduled_at',v_fixture.scheduled_at,
      'home_team_id',v_fixture.home_team_id,'home_team_name',(select name from public.season_teams where id=v_fixture.home_team_id),
      'away_team_id',v_fixture.away_team_id,'away_team_name',(select name from public.season_teams where id=v_fixture.away_team_id)),
    'latest_gameweek',v_latest_gameweek,'report_deadline_at',v_deadline,
    'can_submit',(v_report.id is null and v_fixture.gameweek=v_latest_gameweek and now()<=v_deadline)
      or (v_report.status='rejected' and v_report.referee_user_id=v_actor),
    'report',case when v_report.id is null then null else jsonb_build_object(
      'id',v_report.id,'status',v_report.status,'version',v_report.version,
      'home_score',v_report.home_score,'away_score',v_report.away_score,
      'home_scorers',to_jsonb(v_report.home_scorers),'away_scorers',to_jsonb(v_report.away_scorers),
      'home_substitute_appearances',to_jsonb(v_report.home_substitute_appearances),
      'away_substitute_appearances',to_jsonb(v_report.away_substitute_appearances),
      'disciplinary_events',v_report.disciplinary_events,'match_write_up',v_report.match_write_up,
      'review_reason',v_report.review_reason
    ) end,
    'home_players',coalesce((select jsonb_agg(jsonb_build_object(
      'competition_player_id',tsp.competition_player_id,'full_name',identity.display_name,
      'role',tsp.role,'is_goalkeeper',tsp.is_goalkeeper,'disciplinary_inactive',coalesce(player.disciplinary_inactive,false)
    ) order by case when tsp.role='starter' then 0 else 1 end,identity.display_name)
      from public.fixture_team_sheet_players tsp
      join public.competition_player_identities identity on identity.id=tsp.competition_player_id
      left join public.players player on player.competition_player_id=tsp.competition_player_id
      where tsp.team_sheet_id=v_home_sheet.id),'[]'::jsonb),
    'away_players',coalesce((select jsonb_agg(jsonb_build_object(
      'competition_player_id',tsp.competition_player_id,'full_name',identity.display_name,
      'role',tsp.role,'is_goalkeeper',tsp.is_goalkeeper,'disciplinary_inactive',coalesce(player.disciplinary_inactive,false)
    ) order by case when tsp.role='starter' then 0 else 1 end,identity.display_name)
      from public.fixture_team_sheet_players tsp
      join public.competition_player_identities identity on identity.id=tsp.competition_player_id
      left join public.players player on player.competition_player_id=tsp.competition_player_id
      where tsp.team_sheet_id=v_away_sheet.id),'[]'::jsonb)
  );
end;
$$;
revoke all on function public.get_my_referee_fixture_report_options(uuid) from public,anon;
grant execute on function public.get_my_referee_fixture_report_options(uuid) to authenticated;

create or replace function public.submit_referee_match_report(
  p_fixture_id uuid,p_home_score integer,p_away_score integer,
  p_home_substitute_appearances uuid[] default '{}'::uuid[],
  p_away_substitute_appearances uuid[] default '{}'::uuid[],
  p_home_scorers uuid[] default '{}'::uuid[],
  p_away_scorers uuid[] default '{}'::uuid[],
  p_disciplinary_events jsonb default '[]'::jsonb,
  p_match_write_up text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
begin
  return public._save_referee_match_report(auth.uid(),'referee',p_fixture_id,p_home_score,p_away_score,
    p_home_substitute_appearances,p_away_substitute_appearances,p_home_scorers,p_away_scorers,
    p_disciplinary_events,p_match_write_up,null);
end;
$$;
revoke all on function public.submit_referee_match_report(uuid,integer,integer,uuid[],uuid[],uuid[],uuid[],jsonb,text) from public,anon;
grant execute on function public.submit_referee_match_report(uuid,integer,integer,uuid[],uuid[],uuid[],uuid[],jsonb,text) to authenticated;

create or replace function public.admin_submit_referee_match_report(
  p_fixture_id uuid,p_home_score integer,p_away_score integer,
  p_home_substitute_appearances uuid[] default '{}'::uuid[],
  p_away_substitute_appearances uuid[] default '{}'::uuid[],
  p_home_scorers uuid[] default '{}'::uuid[],
  p_away_scorers uuid[] default '{}'::uuid[],
  p_disciplinary_events jsonb default '[]'::jsonb,
  p_match_write_up text default null,
  p_reason text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
begin
  if length(btrim(coalesce(p_reason,''))) not between 5 and 500 then
    raise exception 'A reason of 5 to 500 characters is required for an administrator report or amendment';
  end if;
  return public._save_referee_match_report(auth.uid(),'admin',p_fixture_id,p_home_score,p_away_score,
    p_home_substitute_appearances,p_away_substitute_appearances,p_home_scorers,p_away_scorers,
    p_disciplinary_events,p_match_write_up,p_reason);
end;
$$;
revoke all on function public.admin_submit_referee_match_report(uuid,integer,integer,uuid[],uuid[],uuid[],uuid[],jsonb,text,text) from public,anon;
grant execute on function public.admin_submit_referee_match_report(uuid,integer,integer,uuid[],uuid[],uuid[],uuid[],jsonb,text,text) to authenticated;

create or replace function public.admin_list_referee_match_reports(
  p_status text default 'submitted',
  p_location_id uuid default null
)
returns table(
  report_id uuid,fixture_id uuid,referee_user_id uuid,referee_name text,referee_email text,
  report_source text,status text,version integer,submitted_at timestamptz,review_reason text,
  scheduled_at timestamptz,gameweek integer,fixture_number integer,location_id uuid,location_name text,
  home_team_name text,away_team_name text,home_score integer,away_score integer,
  home_scorers uuid[],away_scorers uuid[],home_substitute_appearances uuid[],away_substitute_appearances uuid[],
  disciplinary_events jsonb,match_write_up text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  if p_status not in ('submitted','rejected','approved','voided','all') then raise exception 'Invalid report status filter'; end if;
  if p_location_id is not null and not public.can_administer_location(p_location_id) then
    raise exception 'You are not assigned to this referee location';
  end if;
  return query
  select report.id,fixture.id,report.referee_user_id,
    coalesce(player.full_name,'Open Play referee'),account.email::text,
    report.report_source,report.status,report.version,report.submitted_at,report.review_reason,
    fixture.scheduled_at,fixture.gameweek,fixture.fixture_number,location.id,location.name,
    home_team.name,away_team.name,report.home_score::integer,report.away_score::integer,
    report.home_scorers,report.away_scorers,report.home_substitute_appearances,report.away_substitute_appearances,
    report.disciplinary_events,report.match_write_up
  from public.referee_match_reports report
  join public.fixtures fixture on fixture.id=report.fixture_id
  join public.seasons season on season.id=fixture.season_id
  join public.leagues league on league.id=season.league_id
  join public.locations location on location.id=coalesce(fixture.venue_id,league.location_id)
  join public.season_teams home_team on home_team.id=fixture.home_team_id
  join public.season_teams away_team on away_team.id=fixture.away_team_id
  left join auth.users account on account.id=report.referee_user_id
  left join public.players player on player.user_id=report.referee_user_id
  where (p_status='all' or report.status=p_status)
    and (p_location_id is null or location.id=p_location_id)
    and public.can_administer_location(location.id)
  order by report.submitted_at desc,fixture.scheduled_at desc;
end;
$$;
revoke all on function public.admin_list_referee_match_reports(text,uuid) from public,anon;
grant execute on function public.admin_list_referee_match_reports(text,uuid) to authenticated;

create or replace function public.admin_review_referee_match_report(
  p_report_id uuid,p_decision text,p_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid:=auth.uid();
  v_report public.referee_match_reports;
  v_fixture public.fixtures;
  v_location_id uuid;
  v_event jsonb;
  v_event_index integer:=0;
  v_team_id uuid;
  v_player_id uuid;
  v_recipient text;
  v_card text;
  v_minute integer;
  v_fine integer;
  v_strike boolean;
  v_description text;
  v_finance_entry_id uuid;
  v_strikes integer;
  v_inactive boolean;
  v_approved_games integer;
begin
  if v_actor is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  if p_decision not in ('approved','rejected') then raise exception 'Decision must be approved or rejected'; end if;
  if length(btrim(coalesce(p_reason,''))) not between 5 and 500 then raise exception 'A review reason of 5 to 500 characters is required'; end if;
  select * into v_report from public.referee_match_reports where id=p_report_id for update;
  if not found then raise exception 'Referee match report not found'; end if;
  if v_report.status<>'submitted' then raise exception 'Only submitted referee reports can be reviewed'; end if;
  select * into v_fixture from public.fixtures where id=v_report.fixture_id for update;
  select league.location_id into v_location_id from public.seasons season
    join public.leagues league on league.id=season.league_id where season.id=v_fixture.season_id;
  if not public.can_administer_location(v_location_id) then raise exception 'You are not assigned to this referee location'; end if;
  perform public.assert_admin_location_context(v_location_id);

  insert into public.referee_match_report_history(report_id,report_version,action,snapshot,changed_by,reason)
  values(v_report.id,v_report.version,p_decision,
    jsonb_build_object('status',v_report.status,'home_score',v_report.home_score,'away_score',v_report.away_score,
      'home_scorers',to_jsonb(v_report.home_scorers),'away_scorers',to_jsonb(v_report.away_scorers),
      'disciplinary_events',v_report.disciplinary_events,'match_write_up',v_report.match_write_up),
    v_actor,btrim(p_reason));

  if p_decision='rejected' then
    update public.referee_match_reports set status='rejected',reviewed_at=now(),reviewed_by=v_actor,
      review_reason=btrim(p_reason),updated_at=now() where id=v_report.id;
    insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,before_data,after_data)
    values(v_actor,'referee.report.rejected','referee_match_report',v_report.id::text,btrim(p_reason),
      jsonb_build_object('status','submitted'),jsonb_build_object('status','rejected'));
    return;
  end if;

  perform public.admin_record_fixture_result_with_appearances(
    v_report.fixture_id,v_report.home_score,v_report.away_score,
    v_report.home_substitute_appearances,v_report.away_substitute_appearances,
    v_report.home_scorers,v_report.away_scorers,btrim(p_reason)
  );

  for v_event in select value from jsonb_array_elements(v_report.disciplinary_events) loop
    v_team_id:=(v_event->>'season_team_id')::uuid;
    v_recipient:=v_event->>'recipient_type';
    v_card:=v_event->>'card_type';
    v_player_id:=nullif(v_event->>'competition_player_id','')::uuid;
    v_minute:=nullif(v_event->>'minute','')::integer;
    v_description:=nullif(btrim(coalesce(v_event->>'description','')),'');
    v_fine:=case v_card when 'yellow' then 500 when 'second_yellow_red' then 1500 when 'straight_red' then 3000 else null end;
    v_strike:=(v_recipient='registered_player' and v_card='straight_red');
    if v_team_id not in (v_fixture.home_team_id,v_fixture.away_team_id) or v_fine is null then
      raise exception 'Invalid disciplinary event in approved referee report';
    end if;
    insert into public.finance_entries(season_team_id,fixture_id,entry_type,amount_pence,description,notes,created_by)
    values(v_team_id,v_fixture.id,'fine',v_fine,
      'Referee card fine - '||replace(v_card,'_',' '),
      coalesce(v_description,'Disciplinary event recorded in approved referee report'),v_actor)
    returning id into v_finance_entry_id;
    insert into public.referee_disciplinary_events(
      report_id,event_index,fixture_id,season_team_id,competition_player_id,recipient_type,
      card_type,minute,description,fine_amount_pence,strike_applied,finance_entry_id,created_by
    ) values(
      v_report.id,v_event_index,v_fixture.id,v_team_id,v_player_id,v_recipient,
      v_card,v_minute,v_description,v_fine,v_strike,v_finance_entry_id,v_actor
    );
    if v_strike then
      update public.players
      set disciplinary_strikes=disciplinary_strikes+1,
          disciplinary_inactive=(disciplinary_strikes+1>=3),
          updated_at=now()
      where competition_player_id=v_player_id
      returning disciplinary_strikes,disciplinary_inactive into v_strikes,v_inactive;
    end if;
    v_event_index:=v_event_index+1;
  end loop;

  update public.referee_match_reports set status='approved',reviewed_at=now(),reviewed_by=v_actor,
    review_reason=btrim(p_reason),approved_at=now(),approved_by=v_actor,updated_at=now()
  where id=v_report.id;

  if v_report.report_source='referee' and v_report.referee_user_id is not null then
    insert into public.referee_report_payouts(
      report_id,referee_user_id,gross_allocation_pence,deductions_pence,
      referee_net_pence,open_play_top_up_pence,status
    ) values(v_report.id,v_report.referee_user_id,2200,0,2200,0,'pending_connect')
    on conflict(report_id) do nothing;
    select count(*) into v_approved_games from public.referee_match_reports
      where referee_user_id=v_report.referee_user_id and report_source='referee' and status='approved';
    if v_approved_games between 50 and 500 and mod(v_approved_games,50)=0 then
      insert into public.referee_milestone_rewards(referee_user_id,milestone_number,approved_games,amount_pence)
      values(v_report.referee_user_id,(v_approved_games/50)::integer,v_approved_games,5000)
      on conflict(referee_user_id,milestone_number) do nothing;
    end if;
  end if;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,before_data,after_data)
  values(v_actor,'referee.report.approved','referee_match_report',v_report.id::text,btrim(p_reason),
    jsonb_build_object('status','submitted'),
    jsonb_build_object('status','approved','fixture_id',v_fixture.id,'home_score',v_report.home_score,
      'away_score',v_report.away_score,'referee_user_id',v_report.referee_user_id,
      'referee_gross_allocation_pence',case when v_report.report_source='referee' then 2200 else 0 end,
      'referee_minimum_net_pence',case when v_report.report_source='referee' then 2000 else 0 end));
end;
$$;
revoke all on function public.admin_review_referee_match_report(uuid,text,text) from public,anon;
grant execute on function public.admin_review_referee_match_report(uuid,text,text) to authenticated;

create or replace function public.admin_void_referee_match_report(p_report_id uuid,p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid:=auth.uid();
  v_report public.referee_match_reports;
  v_location_id uuid;
begin
  if v_actor is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  if length(btrim(coalesce(p_reason,''))) not between 5 and 500 then raise exception 'A void reason of 5 to 500 characters is required'; end if;
  select * into v_report from public.referee_match_reports where id=p_report_id for update;
  if not found then raise exception 'Referee match report not found'; end if;
  if v_report.status='approved' then raise exception 'Approved reports require a controlled result and finance correction; they cannot be deleted'; end if;
  if v_report.status='voided' then raise exception 'Report is already voided'; end if;
  select league.location_id into v_location_id from public.fixtures fixture
    join public.seasons season on season.id=fixture.season_id
    join public.leagues league on league.id=season.league_id where fixture.id=v_report.fixture_id;
  if not public.can_administer_location(v_location_id) then raise exception 'You are not assigned to this referee location'; end if;
  insert into public.referee_match_report_history(report_id,report_version,action,snapshot,changed_by,reason)
  values(v_report.id,v_report.version,'voided',to_jsonb(v_report),v_actor,btrim(p_reason));
  update public.referee_match_reports set status='voided',reviewed_at=now(),reviewed_by=v_actor,
    review_reason=btrim(p_reason),updated_at=now() where id=v_report.id;
  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,before_data,after_data)
  values(v_actor,'referee.report.voided','referee_match_report',v_report.id::text,btrim(p_reason),
    jsonb_build_object('status',v_report.status),jsonb_build_object('status','voided'));
end;
$$;
revoke all on function public.admin_void_referee_match_report(uuid,text) from public,anon;
grant execute on function public.admin_void_referee_match_report(uuid,text) to authenticated;

create or replace function public.admin_reactivate_disciplined_player(p_competition_player_id uuid,p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid:=auth.uid();
  v_player public.players;
  v_allowed boolean:=false;
begin
  if v_actor is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  if length(btrim(coalesce(p_reason,''))) not between 5 and 500 then raise exception 'A reactivation reason of 5 to 500 characters is required'; end if;
  select * into v_player from public.players where competition_player_id=p_competition_player_id for update;
  if not found then raise exception 'Active player account not found for this competition identity'; end if;
  select exists(
    select 1 from public.team_memberships membership
    join public.season_teams team on team.id=membership.season_team_id
    join public.seasons season on season.id=team.season_id
    join public.leagues league on league.id=season.league_id
    where membership.user_id=v_player.user_id and membership.status='active'
      and public.can_administer_location(league.location_id)
  ) or public.has_global_admin_role() into v_allowed;
  if not v_allowed then raise exception 'Administrator access to one of the player locations is required'; end if;
  update public.players set disciplinary_inactive=false,updated_at=now()
    where user_id=v_player.user_id;
  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,before_data,after_data)
  values(v_actor,'player.disciplinary_reactivated','player',v_player.user_id::text,btrim(p_reason),
    jsonb_build_object('disciplinary_strikes',v_player.disciplinary_strikes,'disciplinary_inactive',v_player.disciplinary_inactive),
    jsonb_build_object('disciplinary_strikes',v_player.disciplinary_strikes,'disciplinary_inactive',false));
end;
$$;
revoke all on function public.admin_reactivate_disciplined_player(uuid,text) from public,anon;
grant execute on function public.admin_reactivate_disciplined_player(uuid,text) to authenticated;
