-- Controlled correction of an already-approved referee match report.
-- Corrections preserve the original report, disciplinary incidents and finance ledger.
-- Removed fines are offset by append-only team credits; cash refunds remain a separate admin action.

alter table public.referee_match_report_history
  drop constraint if exists referee_match_report_history_action_check;
alter table public.referee_match_report_history
  add constraint referee_match_report_history_action_check
  check (action in ('resubmitted','admin_edited','rejected','approved','voided','corrected'));

-- Event indexes are an append-only sequence. Repeated corrections may create more than
-- 50 historical rows even though each current report version is capped at 50 events.
alter table public.referee_disciplinary_events
  drop constraint if exists referee_disciplinary_events_event_index_check;
alter table public.referee_disciplinary_events
  add constraint referee_disciplinary_events_event_index_check check (event_index >= 0);

create or replace function public.admin_correct_approved_referee_match_report(
  p_report_id uuid,
  p_expected_version integer,
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
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid:=auth.uid();
  v_report public.referee_match_reports;
  v_fixture public.fixtures;
  v_old_event public.referee_disciplinary_events;
  v_event jsonb;
  v_event_index integer;
  v_team_id uuid;
  v_player_id uuid;
  v_recipient text;
  v_card text;
  v_minute integer;
  v_description text;
  v_fine integer;
  v_strike boolean;
  v_credit_id uuid;
  v_location_id uuid;
  v_new_version integer;
begin
  if v_actor is null or not public.has_platform_role() then
    raise exception 'Administrator permission required';
  end if;
  if length(btrim(coalesce(p_reason,''))) not between 5 and 500 then
    raise exception 'A correction reason of 5 to 500 characters is required';
  end if;
  if p_expected_version is null or p_expected_version < 1 then
    raise exception 'A valid expected report version is required';
  end if;
  if p_disciplinary_events is null or jsonb_typeof(p_disciplinary_events)<>'array'
     or jsonb_array_length(p_disciplinary_events)>50 then
    raise exception 'Disciplinary events must be a list of no more than 50 cards';
  end if;
  if p_match_write_up is not null and length(p_match_write_up)>2000 then
    raise exception 'Match write-up must be 2,000 characters or fewer';
  end if;

  select * into v_report
  from public.referee_match_reports
  where id=p_report_id
  for update;
  if not found then raise exception 'Referee match report not found'; end if;
  if v_report.status<>'approved' then
    raise exception 'Only an approved referee match report can be corrected';
  end if;
  if v_report.version<>p_expected_version then
    raise exception 'The report has changed since it was loaded; refresh before correcting it';
  end if;

  select * into v_fixture
  from public.fixtures
  where id=v_report.fixture_id
  for update;
  if not found then raise exception 'The report fixture no longer exists'; end if;

  select league.location_id into v_location_id
  from public.seasons season
  join public.leagues league on league.id=season.league_id
  where season.id=v_fixture.season_id;
  if v_location_id is null or not public.can_administer_location(v_location_id) then
    raise exception 'You are not assigned to this referee location';
  end if;
  perform public.assert_admin_location_context(v_location_id);

  -- Validate every replacement disciplinary event against the locked fixture sheets.
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
    if v_recipient not in ('registered_player','bench','supporter')
       or v_card not in ('yellow','second_yellow_red','straight_red') then
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
        select 1
        from public.fixture_team_sheet_players tsp
        where tsp.team_sheet_id=case
          when v_team_id=v_fixture.home_team_id then (
            select id from public.fixture_team_sheets
            where fixture_id=v_fixture.id and season_team_id=v_fixture.home_team_id and is_locked=true
          )
          else (
            select id from public.fixture_team_sheets
            where fixture_id=v_fixture.id and season_team_id=v_fixture.away_team_id and is_locked=true
          )
        end
        and tsp.competition_player_id=v_player_id
      ) then
        raise exception 'Registered player cards must identify a player on that team sheet';
      end if;
    elsif v_player_id is not null then
      raise exception 'Bench and supporter events cannot identify a registered player';
    end if;
  end loop;

  insert into public.referee_match_report_history(
    report_id,report_version,action,snapshot,changed_by,reason
  ) values(
    v_report.id,v_report.version,'corrected',to_jsonb(v_report),v_actor,btrim(p_reason)
  );

  -- Reuse the established, location-scoped result correction path. It validates
  -- scorers and appearances and recalculates the official result/statistics.
  perform public.admin_record_fixture_result_with_appearances(
    v_report.fixture_id,p_home_score,p_away_score,
    coalesce(p_home_substitute_appearances,'{}'::uuid[]),
    coalesce(p_away_substitute_appearances,'{}'::uuid[]),
    coalesce(p_home_scorers,'{}'::uuid[]),
    coalesce(p_away_scorers,'{}'::uuid[]),
    btrim(p_reason)
  );

  -- Never delete an incident or mutate an existing finance entry. Void each old
  -- active incident and post an equal team credit to reverse its fine liability.
  for v_old_event in
    select * from public.referee_disciplinary_events
    where report_id=v_report.id and voided_at is null
    order by event_index
    for update
  loop
    if v_old_event.finance_entry_id is not null then
      insert into public.finance_entries(
        season_team_id,fixture_id,entry_type,amount_pence,description,notes,created_by
      ) values(
        v_old_event.season_team_id,v_fixture.id,'credit',v_old_event.fine_amount_pence,
        'Correction credit – reversed referee card fine',
        'Reverses finance entry '||v_old_event.finance_entry_id::text||'. Reason: '||btrim(p_reason),
        v_actor
      ) returning id into v_credit_id;
    end if;

    update public.referee_disciplinary_events
    set voided_at=now(),voided_by=v_actor,void_reason=btrim(p_reason)
    where id=v_old_event.id;

    if v_old_event.strike_applied and v_old_event.competition_player_id is not null then
      update public.players
      set disciplinary_strikes=greatest(0,disciplinary_strikes-1),
          disciplinary_inactive=(disciplinary_inactive and greatest(0,disciplinary_strikes-1)>=3),
          updated_at=now()
      where competition_player_id=v_old_event.competition_player_id;
    end if;
  end loop;

  select coalesce(max(event_index)+1,0) into v_event_index
  from public.referee_disciplinary_events
  where report_id=v_report.id;

  -- Apply the corrected incidents as new rows so the original events remain auditable.
  for v_event in select value from jsonb_array_elements(p_disciplinary_events) loop
    v_team_id:=(v_event->>'season_team_id')::uuid;
    v_recipient:=v_event->>'recipient_type';
    v_card:=v_event->>'card_type';
    v_player_id:=nullif(v_event->>'competition_player_id','')::uuid;
    v_minute:=nullif(v_event->>'minute','')::integer;
    v_description:=nullif(btrim(coalesce(v_event->>'description','')),'');
    v_fine:=case v_card when 'yellow' then 500 when 'second_yellow_red' then 1500 when 'straight_red' then 3000 else null end;
    v_strike:=(v_recipient='registered_player' and v_card='straight_red');

    insert into public.finance_entries(
      season_team_id,fixture_id,entry_type,amount_pence,description,notes,created_by
    ) values(
      v_team_id,v_fixture.id,'fine',v_fine,
      'Referee card fine – corrected approved report',
      coalesce(v_description,'Corrected disciplinary event')||'. Correction reason: '||btrim(p_reason),
      v_actor
    ) returning id into v_credit_id;

    insert into public.referee_disciplinary_events(
      report_id,event_index,fixture_id,season_team_id,competition_player_id,recipient_type,
      card_type,minute,description,fine_amount_pence,strike_applied,finance_entry_id,created_by
    ) values(
      v_report.id,v_event_index,v_fixture.id,v_team_id,v_player_id,v_recipient,
      v_card,v_minute,v_description,v_fine,v_strike,v_credit_id,v_actor
    );

    if v_strike then
      update public.players
      set disciplinary_strikes=disciplinary_strikes+1,
          disciplinary_inactive=(disciplinary_strikes+1>=3),
          updated_at=now()
      where competition_player_id=v_player_id;
    end if;
    v_event_index:=v_event_index+1;
  end loop;

  update public.referee_match_reports
  set home_score=p_home_score,
      away_score=p_away_score,
      home_scorers=coalesce(p_home_scorers,'{}'::uuid[]),
      away_scorers=coalesce(p_away_scorers,'{}'::uuid[]),
      home_substitute_appearances=coalesce(p_home_substitute_appearances,'{}'::uuid[]),
      away_substitute_appearances=coalesce(p_away_substitute_appearances,'{}'::uuid[]),
      disciplinary_events=p_disciplinary_events,
      match_write_up=nullif(btrim(coalesce(p_match_write_up,'')),''),
      version=version+1,
      updated_at=now()
  where id=v_report.id
  returning version into v_new_version;

  insert into public.audit_log(
    actor_user_id,action,entity_type,entity_id,reason,before_data,after_data
  ) values(
    v_actor,'referee.report.corrected','referee_match_report',v_report.id::text,btrim(p_reason),
    jsonb_build_object(
      'version',v_report.version,'home_score',v_report.home_score,'away_score',v_report.away_score,
      'disciplinary_events',v_report.disciplinary_events
    ),
    jsonb_build_object(
      'version',v_new_version,'home_score',p_home_score,'away_score',p_away_score,
      'disciplinary_events',p_disciplinary_events,
      'referee_payout_unchanged',true,
      'fine_reversals_recorded_as_team_credits',true
    )
  );
  return v_new_version;
end;
$$;

revoke all on function public.admin_correct_approved_referee_match_report(
  uuid,integer,integer,integer,uuid[],uuid[],uuid[],uuid[],jsonb,text,text
) from public,anon;
grant execute on function public.admin_correct_approved_referee_match_report(
  uuid,integer,integer,integer,uuid[],uuid[],uuid[],uuid[],jsonb,text,text
) to authenticated;
