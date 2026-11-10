-- Permanent player disciplinary strike ledger and three-strike inactivity gate.
-- Strike changes occur only when an approved report's fine is posted to the finance ledger.

create table public.competition_player_discipline (
  competition_player_id uuid primary key
    references public.competition_player_identities(id) on delete restrict,
  straight_red_strikes integer not null default 0 check (straight_red_strikes >= 0),
  inactive_pending_review boolean not null default false,
  last_straight_red_at timestamptz,
  last_reviewed_by uuid references auth.users(id) on delete set null,
  last_reviewed_at timestamptz,
  last_review_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint competition_player_discipline_review_pair check (
    (last_reviewed_by is null and last_reviewed_at is null)
    or (last_reviewed_by is not null and last_reviewed_at is not null)
  ),
  constraint competition_player_discipline_reason check (
    last_review_reason is null or length(btrim(last_review_reason)) >= 5
  )
);
alter table public.competition_player_discipline enable row level security;
revoke all on public.competition_player_discipline from public,anon,authenticated;

create or replace function public.record_approved_referee_straight_red()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare v_strikes integer; v_inactive boolean;
begin
  if old.finance_entry_id is null and new.finance_entry_id is not null
     and new.card_outcome='straight_red'
     and new.recipient_category in ('registered_player','substitute_bench')
     and new.competition_player_id is not null then
    insert into public.competition_player_discipline(
      competition_player_id,straight_red_strikes,inactive_pending_review,last_straight_red_at
    ) values(new.competition_player_id,1,false,new.created_at)
    on conflict(competition_player_id) do update set
      straight_red_strikes=public.competition_player_discipline.straight_red_strikes+1,
      inactive_pending_review=public.competition_player_discipline.inactive_pending_review
        or public.competition_player_discipline.straight_red_strikes+1>=3,
      last_straight_red_at=excluded.last_straight_red_at,
      updated_at=now()
    returning straight_red_strikes,inactive_pending_review into v_strikes,v_inactive;

    insert into public.audit_log(actor_user_id,action,entity_type,entity_id,after_data)
    values(
      auth.uid(),'player.discipline.straight_red_recorded','competition_player_discipline',
      new.competition_player_id::text,
      jsonb_build_object('straight_red_strikes',v_strikes,'inactive_pending_review',v_inactive,'report_id',new.report_id,'incident_id',new.id)
    );
  end if;
  return new;
end;
$$;
revoke all on function public.record_approved_referee_straight_red() from public,anon,authenticated;
drop trigger if exists referee_report_incident_record_straight_red on public.referee_match_report_incidents;
create trigger referee_report_incident_record_straight_red
after update of finance_entry_id on public.referee_match_report_incidents
for each row execute function public.record_approved_referee_straight_red();

create or replace function public.enforce_disciplinary_inactive_team_sheet_player()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare v_fixture_status public.fixture_status;
begin
  if new.competition_player_id is null then return new; end if;
  select f.status into v_fixture_status
  from public.fixture_team_sheets sh
  join public.fixtures f on f.id=sh.fixture_id
  where sh.id=new.team_sheet_id;
  if v_fixture_status in ('scheduled','in_progress') and exists(
    select 1 from public.competition_player_discipline d
    where d.competition_player_id=new.competition_player_id
      and d.inactive_pending_review is true
  ) then
    raise exception 'This player is inactive pending administrator disciplinary review';
  end if;
  return new;
end;
$$;
revoke all on function public.enforce_disciplinary_inactive_team_sheet_player() from public,anon,authenticated;
drop trigger if exists team_sheet_player_disciplinary_inactive_guard on public.fixture_team_sheet_players;
create trigger team_sheet_player_disciplinary_inactive_guard
before insert or update of competition_player_id,user_id,role
on public.fixture_team_sheet_players
for each row execute function public.enforce_disciplinary_inactive_team_sheet_player();

create or replace function public.admin_review_player_disciplinary_return(
  p_competition_player_id uuid,p_reason text
)
returns public.competition_player_discipline
language plpgsql security definer set search_path = ''
as $$
declare v_actor uuid:=auth.uid(); v_discipline public.competition_player_discipline; v_user_id uuid; v_player_name text;
begin
  if v_actor is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  if p_reason is null or length(btrim(p_reason))<5 then raise exception 'Enter a reason of at least 5 characters'; end if;
  if not public.has_global_admin_role() and not exists(
    select 1
    from public.fixture_team_sheet_players tsp
    join public.fixture_team_sheets sh on sh.id=tsp.team_sheet_id
    join public.fixtures f on f.id=sh.fixture_id
    join public.seasons s on s.id=f.season_id
    join public.leagues l on l.id=s.league_id
    where tsp.competition_player_id=p_competition_player_id
      and public.can_administer_location(l.location_id)
  ) then raise exception 'You are not assigned to a location with this player''s competition history'; end if;

  select cpi.user_id,cpi.display_name into v_user_id,v_player_name
  from public.competition_player_identities cpi where cpi.id=p_competition_player_id;
  select * into v_discipline from public.competition_player_discipline
  where competition_player_id=p_competition_player_id for update;
  if not found then raise exception 'Disciplinary record not found'; end if;
  if not v_discipline.inactive_pending_review then raise exception 'This player is not awaiting disciplinary return approval'; end if;

  update public.competition_player_discipline
  set inactive_pending_review=false,last_reviewed_by=v_actor,last_reviewed_at=now(),
      last_review_reason=btrim(p_reason),updated_at=now()
  where competition_player_id=p_competition_player_id returning * into v_discipline;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,before_data,after_data)
  values(v_actor,'player.discipline.return_approved','competition_player_discipline',
    p_competition_player_id::text,btrim(p_reason),
    jsonb_build_object('inactive_pending_review',true,'straight_red_strikes',v_discipline.straight_red_strikes),
    jsonb_build_object('inactive_pending_review',false,'straight_red_strikes',v_discipline.straight_red_strikes));
  if v_user_id is not null then
    perform public.enqueue_notification_event(v_user_id,'player_disciplinary_return_approved',jsonb_build_object(
      'competition_player_id',p_competition_player_id::text,'title','Approved to return to play',
      'message','An Open Play administrator has approved your return. Your permanent straight-red history remains on your competition record.',
      'reason',btrim(p_reason),'changed_at',now()::text,'url','/player-hub'));
  end if;
  return v_discipline;
end;
$$;
revoke all on function public.admin_review_player_disciplinary_return(uuid,text) from public,anon;
grant execute on function public.admin_review_player_disciplinary_return(uuid,text) to authenticated;


create or replace function public.admin_list_disciplinary_suspensions(p_location_id uuid default null)
returns table(
  competition_player_id uuid,player_name text,straight_red_strikes integer,
  last_straight_red_at timestamptz,last_fixture_id uuid,last_gameweek integer,last_team_name text
)
language plpgsql stable security definer set search_path = ''
as $suspensions$
begin
  if auth.uid() is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  if p_location_id is not null and not public.can_administer_location(p_location_id) then
    raise exception 'You are not assigned to this location';
  end if;
  return query
  select d.competition_player_id,cpi.display_name,d.straight_red_strikes,d.last_straight_red_at,
    last_incident.fixture_id,last_incident.gameweek,last_incident.team_name
  from public.competition_player_discipline d
  join public.competition_player_identities cpi on cpi.id=d.competition_player_id
  left join lateral (
    select f.id as fixture_id,f.gameweek,st.name as team_name,i.created_at
    from public.referee_match_report_incidents i
    join public.referee_match_reports r on r.id=i.report_id and r.status='approved'
    join public.fixtures f on f.id=r.fixture_id
    join public.seasons se on se.id=f.season_id
    join public.leagues lg on lg.id=se.league_id
    join public.season_teams st on st.id=i.team_id
    where i.competition_player_id=d.competition_player_id and i.card_outcome='straight_red'
      and (p_location_id is null or lg.location_id=p_location_id)
      and public.can_administer_location(lg.location_id)
    order by i.created_at desc limit 1
  ) last_incident on true
  where d.inactive_pending_review is true
    and exists(
      select 1 from public.referee_match_report_incidents i
      join public.referee_match_reports r on r.id=i.report_id and r.status='approved'
      join public.fixtures f on f.id=r.fixture_id
      join public.seasons se on se.id=f.season_id
      join public.leagues lg on lg.id=se.league_id
      where i.competition_player_id=d.competition_player_id and i.card_outcome='straight_red'
        and (p_location_id is null or lg.location_id=p_location_id)
        and public.can_administer_location(lg.location_id)
    )
  order by d.last_straight_red_at desc,cpi.display_name;
end;
$suspensions$;
revoke all on function public.admin_list_disciplinary_suspensions(uuid) from public,anon;
grant execute on function public.admin_list_disciplinary_suspensions(uuid) to authenticated;

comment on table public.competition_player_discipline is
  'Permanent disciplinary record keyed to competition identity. Three straight-red strikes suspend future team-sheet eligibility until an authorised administrator approves return; the strike history is never reset.';
