create table if not exists public.fixture_goal_records (
id uuid primary key default gen_random_uuid(),
fixture_id uuid not null references public.fixtures(id) on delete cascade,
season_team_id uuid not null references public.season_teams(id) on delete restrict,
scorer_user_id uuid not null references public.profiles(id) on delete restrict,
created_by uuid not null references auth.users(id) on delete restrict,
created_at timestamptz not null default now(),
voided_at timestamptz,
voided_by uuid references auth.users(id) on delete set null,
void_reason text,
constraint fixture_goal_records_void_pair check ((voided_at is null)=(voided_by is null)),
constraint fixture_goal_records_void_reason check (voided_at is null or (void_reason is not null and length(btrim(void_reason))>=5))
);
create index if not exists fixture_goal_records_fixture_active_idx on public.fixture_goal_records(fixture_id,season_team_id) where voided_at is null;
create index if not exists fixture_goal_records_scorer_active_idx on public.fixture_goal_records(scorer_user_id) where voided_at is null;
alter table public.fixture_goal_records enable row level security;
revoke all on table public.fixture_goal_records from public,anon,authenticated;
create or replace function public.get_admin_fixture_scorer_options(p_fixture_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_actor uuid:=auth.uid(); v_fixture public.fixtures; v_home_sheet public.fixture_team_sheets; v_away_sheet public.fixture_team_sheets;
begin
if v_actor is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
select * into v_fixture from public.fixtures where id=p_fixture_id;
if not found then raise exception 'Fixture not found'; end if;
select * into v_home_sheet from public.fixture_team_sheets where fixture_id=p_fixture_id and season_team_id=v_fixture.home_team_id and is_locked=true;
select * into v_away_sheet from public.fixture_team_sheets where fixture_id=p_fixture_id and season_team_id=v_fixture.away_team_id and is_locked=true;
return jsonb_build_object(
'fixture_id',p_fixture_id,'home_team_id',v_fixture.home_team_id,'home_team_name',(select name from public.season_teams where id=v_fixture.home_team_id),
'away_team_id',v_fixture.away_team_id,'away_team_name',(select name from public.season_teams where id=v_fixture.away_team_id),
'home_sheet_submitted',v_home_sheet.id is not null,'away_sheet_submitted',v_away_sheet.id is not null,
'home_players',coalesce((select jsonb_agg(jsonb_build_object('user_id',tsp.user_id,'full_name',p.full_name,'role',tsp.role,'is_goalkeeper',tsp.is_goalkeeper) order by case when tsp.role='starter' then 0 else 1 end,p.full_name) from public.fixture_team_sheet_players tsp join public.players p on p.user_id=tsp.user_id where tsp.team_sheet_id=v_home_sheet.id),'[]'::jsonb),
'away_players',coalesce((select jsonb_agg(jsonb_build_object('user_id',tsp.user_id,'full_name',p.full_name,'role',tsp.role,'is_goalkeeper',tsp.is_goalkeeper) order by case when tsp.role='starter' then 0 else 1 end,p.full_name) from public.fixture_team_sheet_players tsp join public.players p on p.user_id=tsp.user_id where tsp.team_sheet_id=v_away_sheet.id),'[]'::jsonb)); end; $$;
drop function if exists public.admin_record_fixture_result(uuid,integer,integer,text);
create function public.admin_record_fixture_result(p_fixture_id uuid,p_home_score integer,p_away_score integer,p_home_scorers uuid[] default '{}'::uuid[],p_away_scorers uuid[] default '{}'::uuid[],p_reason text default null)
returns public.fixture_results language plpgsql security definer set search_path = '' as $$
declare v_actor uuid:=auth.uid(); v_fixture public.fixtures; v_home_sheet public.fixture_team_sheets; v_away_sheet public.fixture_team_sheets; v_existing public.fixture_results; v_result public.fixture_results; v_before jsonb; v_had_result boolean:=false;
begin
if v_actor is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
if p_home_score is null or p_away_score is null or p_home_score<0 or p_away_score<0 or p_home_score>32767 or p_away_score>32767 then raise exception 'Scores must be whole numbers between 0 and 32767'; end if;
if cardinality(coalesce(p_home_scorers,'{}'::uuid[]))<>p_home_score then raise exception 'Select exactly one home-team goalscorer for every home goal'; end if;
if cardinality(coalesce(p_away_scorers,'{}'::uuid[]))<>p_away_score then raise exception 'Select exactly one away-team goalscorer for every away goal'; end if;
if exists(select 1 from unnest(coalesce(p_home_scorers,'{}'::uuid[])) x where x is null) or exists(select 1 from unnest(coalesce(p_away_scorers,'{}'::uuid[])) x where x is null) then raise exception 'Choose a goalscorer for every goal'; end if;
select * into v_fixture from public.fixtures where id=p_fixture_id for update;
if not found then raise exception 'Fixture not found'; end if;
if v_fixture.status in ('cancelled','postponed') then raise exception 'A cancelled or postponed fixture cannot receive a result'; end if;
select * into v_home_sheet from public.fixture_team_sheets where fixture_id=p_fixture_id and season_team_id=v_fixture.home_team_id and is_locked=true;
if not found then raise exception 'The home team must submit and lock its team sheet before a result can be published'; end if;
select * into v_away_sheet from public.fixture_team_sheets where fixture_id=p_fixture_id and season_team_id=v_fixture.away_team_id and is_locked=true;
if not found then raise exception 'The away team must submit and lock its team sheet before a result can be published'; end if;
if exists(select 1 from unnest(coalesce(p_home_scorers,'{}'::uuid[])) scorer(user_id) where not exists(select 1 from public.fixture_team_sheet_players tsp where tsp.team_sheet_id=v_home_sheet.id and tsp.user_id=scorer.user_id)) then raise exception 'Every home goalscorer must appear on the home team submitted sheet'; end if;
if exists(select 1 from unnest(coalesce(p_away_scorers,'{}'::uuid[])) scorer(user_id) where not exists(select 1 from public.fixture_team_sheet_players tsp where tsp.team_sheet_id=v_away_sheet.id and tsp.user_id=scorer.user_id)) then raise exception 'Every away goalscorer must appear on the away team submitted sheet'; end if;
select * into v_existing from public.fixture_results where fixture_id=p_fixture_id;
v_had_result:=found;
if v_had_result then
if p_reason is null or length(btrim(p_reason))<5 then raise exception 'Enter a reason of at least 5 characters to correct an existing result'; end if;
select jsonb_build_object('home_score',v_existing.home_score,'away_score',v_existing.away_score,'goals',coalesce((select jsonb_agg(jsonb_build_object('season_team_id',g.season_team_id,'scorer_user_id',g.scorer_user_id) order by g.created_at) from public.fixture_goal_records g where g.fixture_id=p_fixture_id and g.voided_at is null),'[]'::jsonb)) into v_before;
update public.fixture_goal_records set voided_at=now(),voided_by=v_actor,void_reason=btrim(p_reason) where fixture_id=p_fixture_id and voided_at is null;
else v_before:='{}'::jsonb; end if;
insert into public.fixture_results(fixture_id,home_score,away_score,confirmed_at,confirmed_by,updated_at) values(p_fixture_id,p_home_score,p_away_score,now(),v_actor,now())
on conflict(fixture_id) do update set home_score=excluded.home_score,away_score=excluded.away_score,confirmed_at=excluded.confirmed_at,confirmed_by=excluded.confirmed_by,updated_at=now() returning * into v_result;
insert into public.fixture_goal_records(fixture_id,season_team_id,scorer_user_id,created_by) select p_fixture_id,v_fixture.home_team_id,scorer.user_id,v_actor from unnest(coalesce(p_home_scorers,'{}'::uuid[])) scorer(user_id);
insert into public.fixture_goal_records(fixture_id,season_team_id,scorer_user_id,created_by) select p_fixture_id,v_fixture.away_team_id,scorer.user_id,v_actor from unnest(coalesce(p_away_scorers,'{}'::uuid[])) scorer(user_id);
update public.fixtures set status='completed',updated_at=now() where id=p_fixture_id;
insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,before_data,after_data) values(v_actor,case when v_had_result then 'fixture.result.corrected' else 'fixture.result.recorded' end,'fixture',p_fixture_id::text,nullif(btrim(p_reason),''),v_before,jsonb_build_object('home_score',p_home_score,'away_score',p_away_score,'home_scorers',to_jsonb(coalesce(p_home_scorers,'{}'::uuid[])),'away_scorers',to_jsonb(coalesce(p_away_scorers,'{}'::uuid[])),'status','completed'));
return v_result; end; $$;
revoke all on function public.get_admin_fixture_scorer_options(uuid) from public,anon;
grant execute on function public.get_admin_fixture_scorer_options(uuid) to authenticated;
revoke all on function public.admin_record_fixture_result(uuid,integer,integer,uuid[],uuid[],text) from public,anon;
grant execute on function public.admin_record_fixture_result(uuid,integer,integer,uuid[],uuid[],text) to authenticated;