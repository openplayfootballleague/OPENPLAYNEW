-- Goal attribution is optional. The official score remains authoritative;
-- only named, eligible players receive individual goal records.
CREATE OR REPLACE FUNCTION public.admin_record_fixture_result_with_appearances(p_fixture_id uuid, p_home_score integer, p_away_score integer, p_home_substitute_appearances uuid[] DEFAULT '{}'::uuid[], p_away_substitute_appearances uuid[] DEFAULT '{}'::uuid[], p_home_scorers uuid[] DEFAULT '{}'::uuid[], p_away_scorers uuid[] DEFAULT '{}'::uuid[], p_reason text DEFAULT NULL::text)
 RETURNS fixture_results
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
 v_actor uuid:=auth.uid();
 v_fixture public.fixtures;
 v_home_sheet public.fixture_team_sheets;
 v_away_sheet public.fixture_team_sheets;
 v_existing public.fixture_results;
 v_result public.fixture_results;
 v_before jsonb;
 v_had_result boolean:=false;
begin
 if not public.can_administer_location((
   select l.location_id
   from public.fixtures f
   join public.seasons s on s.id=f.season_id
   join public.leagues l on l.id=s.league_id
   where f.id=p_fixture_id
 )) then raise exception 'You are not assigned to this location'; end if;
 if v_actor is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
 if p_home_score is null or p_away_score is null or p_home_score<0 or p_away_score<0 or p_home_score>32767 or p_away_score>32767 then raise exception 'Scores must be whole numbers between 0 and 32767'; end if;
 if cardinality(coalesce(p_home_scorers,'{}'::uuid[]))>p_home_score then raise exception 'Home goalscorer attribution cannot exceed the home score'; end if;
 if cardinality(coalesce(p_away_scorers,'{}'::uuid[]))>p_away_score then raise exception 'Away goalscorer attribution cannot exceed the away score'; end if;
 if exists(select 1 from unnest(coalesce(p_home_scorers,'{}'::uuid[])) x where x is null) or exists(select 1 from unnest(coalesce(p_away_scorers,'{}'::uuid[])) x where x is null) then raise exception 'Choose a goalscorer for every goal'; end if;
 if exists(select 1 from unnest(coalesce(p_home_substitute_appearances,'{}'::uuid[])) x where x is null) or exists(select 1 from unnest(coalesce(p_away_substitute_appearances,'{}'::uuid[])) x where x is null) then raise exception 'Choose valid substitute appearances'; end if;
 if cardinality(coalesce(p_home_substitute_appearances,'{}'::uuid[]))<>(select count(distinct x) from unnest(coalesce(p_home_substitute_appearances,'{}'::uuid[])) x) then raise exception 'A home substitute can only be selected once'; end if;
 if cardinality(coalesce(p_away_substitute_appearances,'{}'::uuid[]))<>(select count(distinct x) from unnest(coalesce(p_away_substitute_appearances,'{}'::uuid[])) x) then raise exception 'An away substitute can only be selected once'; end if;

 select * into v_fixture from public.fixtures where id=p_fixture_id for update;
 if not found then raise exception 'Fixture not found'; end if;
 if v_fixture.status in ('cancelled','postponed') then raise exception 'A cancelled or postponed fixture cannot receive a result'; end if;
 select * into v_home_sheet from public.fixture_team_sheets where fixture_id=p_fixture_id and season_team_id=v_fixture.home_team_id and is_locked=true;
 if not found then raise exception 'The home team must submit and lock its team sheet before a result can be published'; end if;
 select * into v_away_sheet from public.fixture_team_sheets where fixture_id=p_fixture_id and season_team_id=v_fixture.away_team_id and is_locked=true;
 if not found then raise exception 'The away team must submit and lock its team sheet before a result can be published'; end if;

 if exists(
   select 1 from unnest(coalesce(p_home_substitute_appearances,'{}'::uuid[])) selected(competition_player_id)
   where not exists(
     select 1 from public.fixture_team_sheet_players tsp
     where tsp.team_sheet_id=v_home_sheet.id
       and tsp.competition_player_id=selected.competition_player_id
       and tsp.role='substitute'
   )
 ) then raise exception 'Home appearances may only include substitutes on the submitted home team sheet'; end if;
 if exists(
   select 1 from unnest(coalesce(p_away_substitute_appearances,'{}'::uuid[])) selected(competition_player_id)
   where not exists(
     select 1 from public.fixture_team_sheet_players tsp
     where tsp.team_sheet_id=v_away_sheet.id
       and tsp.competition_player_id=selected.competition_player_id
       and tsp.role='substitute'
   )
 ) then raise exception 'Away appearances may only include substitutes on the submitted away team sheet'; end if;

 select * into v_existing from public.fixture_results where fixture_id=p_fixture_id;
 v_had_result:=found;
 if v_had_result then
  if p_reason is null or length(btrim(p_reason))<5 then raise exception 'Enter a reason of at least 5 characters to correct an existing result'; end if;
  select jsonb_build_object(
   'home_score',v_existing.home_score,
   'away_score',v_existing.away_score,
   'goals',coalesce((
     select jsonb_agg(jsonb_build_object('season_team_id',g.season_team_id,'competition_player_id',g.competition_player_id) order by g.created_at)
     from public.fixture_goal_records g
     where g.fixture_id=p_fixture_id and g.voided_at is null
   ),'[]'::jsonb),
   'home_appearances',coalesce((
     select jsonb_agg(tsp.competition_player_id order by tsp.competition_player_id)
     from public.fixture_team_sheet_players tsp
     where tsp.team_sheet_id=v_home_sheet.id and tsp.did_appear is true
   ),'[]'::jsonb),
   'away_appearances',coalesce((
     select jsonb_agg(tsp.competition_player_id order by tsp.competition_player_id)
     from public.fixture_team_sheet_players tsp
     where tsp.team_sheet_id=v_away_sheet.id and tsp.did_appear is true
   ),'[]'::jsonb)
  ) into v_before;
  update public.fixture_goal_records
  set voided_at=now(),voided_by=v_actor,void_reason=btrim(p_reason)
  where fixture_id=p_fixture_id and voided_at is null;
 else
  v_before:='{}'::jsonb;
 end if;

 update public.fixture_team_sheet_players tsp
 set did_appear=(tsp.role='starter' or tsp.competition_player_id=any(coalesce(p_home_substitute_appearances,'{}'::uuid[])))
 where tsp.team_sheet_id=v_home_sheet.id;
 update public.fixture_team_sheet_players tsp
 set did_appear=(tsp.role='starter' or tsp.competition_player_id=any(coalesce(p_away_substitute_appearances,'{}'::uuid[])))
 where tsp.team_sheet_id=v_away_sheet.id;

 if exists(
   select 1 from unnest(coalesce(p_home_scorers,'{}'::uuid[])) scorer(competition_player_id)
   where not exists(
     select 1 from public.fixture_team_sheet_players tsp
     where tsp.team_sheet_id=v_home_sheet.id
       and tsp.competition_player_id=scorer.competition_player_id
       and tsp.did_appear is true
   )
 ) then raise exception 'Every home goalscorer must be a player who appeared in the match'; end if;
 if exists(
   select 1 from unnest(coalesce(p_away_scorers,'{}'::uuid[])) scorer(competition_player_id)
   where not exists(
     select 1 from public.fixture_team_sheet_players tsp
     where tsp.team_sheet_id=v_away_sheet.id
       and tsp.competition_player_id=scorer.competition_player_id
       and tsp.did_appear is true
   )
 ) then raise exception 'Every away goalscorer must be a player who appeared in the match'; end if;

 insert into public.fixture_results(fixture_id,home_score,away_score,confirmed_at,confirmed_by,updated_at)
 values(p_fixture_id,p_home_score,p_away_score,now(),v_actor,now())
 on conflict(fixture_id) do update
 set home_score=excluded.home_score,away_score=excluded.away_score,
     confirmed_at=excluded.confirmed_at,confirmed_by=excluded.confirmed_by,updated_at=now()
 returning * into v_result;

 insert into public.fixture_goal_records(fixture_id,season_team_id,scorer_user_id,competition_player_id,created_by)
 select p_fixture_id,v_fixture.home_team_id,p.user_id,selected.competition_player_id,v_actor
 from unnest(coalesce(p_home_scorers,'{}'::uuid[])) selected(competition_player_id)
 join public.competition_player_identities cpi on cpi.id=selected.competition_player_id
 left join public.players p on p.competition_player_id=cpi.id;
 insert into public.fixture_goal_records(fixture_id,season_team_id,scorer_user_id,competition_player_id,created_by)
 select p_fixture_id,v_fixture.away_team_id,p.user_id,selected.competition_player_id,v_actor
 from unnest(coalesce(p_away_scorers,'{}'::uuid[])) selected(competition_player_id)
 join public.competition_player_identities cpi on cpi.id=selected.competition_player_id
 left join public.players p on p.competition_player_id=cpi.id;

 update public.fixtures set status='completed',updated_at=now() where id=p_fixture_id;
 insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,before_data,after_data)
 values(
  v_actor,
  case when v_had_result then 'fixture.result.corrected' else 'fixture.result.recorded' end,
  'fixture',
  p_fixture_id::text,
  nullif(btrim(p_reason),''),
  v_before,
  jsonb_build_object(
   'home_score',p_home_score,
   'away_score',p_away_score,
   'home_scorers',to_jsonb(coalesce(p_home_scorers,'{}'::uuid[])),
   'away_scorers',to_jsonb(coalesce(p_away_scorers,'{}'::uuid[])),
   'home_appearances',coalesce((
     select jsonb_agg(tsp.competition_player_id order by tsp.competition_player_id)
     from public.fixture_team_sheet_players tsp
     where tsp.team_sheet_id=v_home_sheet.id and tsp.did_appear is true
   ),'[]'::jsonb),
   'away_appearances',coalesce((
     select jsonb_agg(tsp.competition_player_id order by tsp.competition_player_id)
     from public.fixture_team_sheet_players tsp
     where tsp.team_sheet_id=v_away_sheet.id and tsp.did_appear is true
   ),'[]'::jsonb),
   'status','completed'
  )
 );
 return v_result;
end;
$function$;

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
  if cardinality(coalesce(p_home_scorers,'{}'::uuid[])) > p_home_score
     or cardinality(coalesce(p_away_scorers,'{}'::uuid[])) > p_away_score then
    raise exception 'Goalscorer attribution cannot exceed the final team score';
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

  -- Authorise before revealing fixture or locked team-sheet information.
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
  else
    if not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  end if;

  select * into v_fixture from public.fixtures where id=p_fixture_id for update;
  if not found then raise exception 'Fixture not found'; end if;
  if v_fixture.scheduled_at is null or v_fixture.scheduled_at > now()
     or v_fixture.status in ('cancelled','postponed') then
    raise exception 'Only a fixture that has taken place can receive a match report';
  end if;
  if p_source='admin' then
    perform public.assert_admin_location_context((
      select league.location_id from public.seasons season
      join public.leagues league on league.id=season.league_id
      where season.id=v_fixture.season_id
    ));
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
    select max(gameweek) into v_latest_gameweek
    from public.fixtures
    where season_id=v_fixture.season_id and scheduled_at<=now()
      and status not in ('cancelled','postponed');
    select max(scheduled_at) into v_latest_fixture_at
    from public.fixtures
    where season_id=v_fixture.season_id and gameweek=v_latest_gameweek
      and scheduled_at is not null and status not in ('cancelled','postponed');
    v_deadline:=v_latest_fixture_at+interval '24 hours';
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

comment on function public.admin_record_fixture_result_with_appearances(uuid,integer,integer,uuid[],uuid[],uuid[],uuid[],text) is
  'Records the official score and verified appearances. Goalscorer attribution is optional and only supplied eligible players receive individual goal records.';

comment on function public._save_referee_match_report(uuid,text,uuid,integer,integer,uuid[],uuid[],uuid[],uuid[],jsonb,text,text) is
  'Stores referee/admin reports. The final score is mandatory; goalscorer attribution is optional and limited to the score and players who appeared.';
