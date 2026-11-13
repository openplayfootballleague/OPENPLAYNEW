-- Recorded operating costs and finance-led business performance reporting.
-- Forecasts are limited to unpaid team obligations already created for future fixtures.

create table public.finance_operating_costs (
  id uuid primary key default gen_random_uuid(),
  amount_pence integer not null check (amount_pence between 1 and 100000000),
  category text not null check (category in (
    'venue_hire','referee_fees','equipment','marketing','insurance','software','travel','other'
  )),
  description text not null check (length(btrim(description)) between 3 and 240),
  occurred_at timestamptz not null default now(),
  location_id uuid references public.locations(id) on delete restrict,
  league_id uuid references public.leagues(id) on delete restrict,
  season_id uuid references public.seasons(id) on delete restrict,
  reference text check (reference is null or length(reference)<=120),
  notes text check (notes is null or length(notes)<=1000),
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint finance_operating_cost_context_check check (
    (league_id is null or location_id is not null)
    and (season_id is null or (league_id is not null and location_id is not null))
  )
);
create index finance_operating_costs_location_date_idx
  on public.finance_operating_costs(location_id,occurred_at desc);
create index finance_operating_costs_league_date_idx
  on public.finance_operating_costs(league_id,occurred_at desc);
create index finance_operating_costs_season_date_idx
  on public.finance_operating_costs(season_id,occurred_at desc);
alter table public.finance_operating_costs enable row level security;
revoke all on public.finance_operating_costs from public,anon,authenticated;

create or replace function public.admin_create_operating_cost(
  p_amount_pence integer,
  p_category text,
  p_description text,
  p_occurred_at timestamptz,
  p_location_id uuid default null,
  p_league_id uuid default null,
  p_season_id uuid default null,
  p_reference text default null,
  p_notes text default null,
  p_reason text default null
)
returns public.finance_operating_costs
language plpgsql
security definer
set search_path=''
as $$
declare
  v_actor uuid:=auth.uid();
  v_location_id uuid:=p_location_id;
  v_league_id uuid:=p_league_id;
  v_season_league_id uuid;
  v_season_location_id uuid;
  v_cost public.finance_operating_costs;
begin
  if v_actor is null or not public.has_finance_access() then
    raise exception 'Finance permission required';
  end if;
  if p_amount_pence is null or p_amount_pence<1 or p_amount_pence>100000000 then
    raise exception 'Amount must be between 1 penny and £1,000,000';
  end if;
  if p_category is null or p_category not in (
    'venue_hire','referee_fees','equipment','marketing','insurance','software','travel','other'
  ) then raise exception 'Choose a valid operating cost category'; end if;
  if p_description is null or length(btrim(p_description)) not between 3 and 240 then
    raise exception 'Description must be between 3 and 240 characters';
  end if;
  if p_occurred_at is null or p_occurred_at>now()+interval '1 day' then
    raise exception 'Enter a valid cost date';
  end if;
  if p_reference is not null and length(p_reference)>120 then raise exception 'Reference is too long'; end if;
  if p_notes is not null and length(p_notes)>1000 then raise exception 'Notes are too long'; end if;
  if p_reason is null or length(btrim(p_reason))<5 or length(p_reason)>500 then
    raise exception 'A reason of at least five characters is required';
  end if;

  if p_season_id is not null then
    select s.league_id,l.location_id into v_season_league_id,v_season_location_id
    from public.seasons s join public.leagues l on l.id=s.league_id
    where s.id=p_season_id;
    if not found then raise exception 'Season not found'; end if;
    if v_league_id is not null and v_league_id<>v_season_league_id then
      raise exception 'Selected season does not belong to the selected league';
    end if;
    if v_location_id is not null and v_location_id<>v_season_location_id then
      raise exception 'Selected season does not belong to the selected location';
    end if;
    v_league_id:=v_season_league_id;
    v_location_id:=v_season_location_id;
  elsif v_league_id is not null then
    select l.location_id into v_season_location_id
    from public.leagues l where l.id=v_league_id;
    if not found then raise exception 'League not found'; end if;
    if v_location_id is not null and v_location_id<>v_season_location_id then
      raise exception 'Selected league does not belong to the selected location';
    end if;
    v_location_id:=v_season_location_id;
  elsif v_location_id is not null and not exists(
    select 1 from public.locations where id=v_location_id
  ) then
    raise exception 'Location not found';
  end if;

  insert into public.finance_operating_costs(
    amount_pence,category,description,occurred_at,location_id,league_id,season_id,
    reference,notes,created_by
  ) values (
    p_amount_pence,p_category,btrim(p_description),p_occurred_at,v_location_id,v_league_id,p_season_id,
    nullif(btrim(p_reference),''),nullif(btrim(p_notes),''),v_actor
  ) returning * into v_cost;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,before_data,after_data)
  values(v_actor,'finance.operating_cost.created','finance_operating_cost',v_cost.id::text,
    btrim(p_reason),null,to_jsonb(v_cost)-'created_by');
  return v_cost;
end;
$$;
revoke all on function public.admin_create_operating_cost(integer,text,text,timestamptz,uuid,uuid,uuid,text,text,text) from public,anon;
grant execute on function public.admin_create_operating_cost(integer,text,text,timestamptz,uuid,uuid,uuid,text,text,text) to authenticated;

create or replace function public.get_admin_operating_costs(
  p_location_id uuid default null,
  p_league_id uuid default null,
  p_season_id uuid default null,
  p_from_date date default null,
  p_to_date date default null,
  p_limit integer default 100
)
returns table(
  id uuid,amount_pence integer,category text,description text,occurred_at timestamptz,
  location_id uuid,location_name text,league_id uuid,league_name text,
  season_id uuid,season_name text,reference text,notes text,created_by uuid,created_at timestamptz
)
language plpgsql
stable
security definer
set search_path=''
as $$
begin
  if auth.uid() is null or not public.has_finance_access() then
    raise exception 'Finance permission required';
  end if;
  if p_season_id is not null and not exists(
    select 1 from public.seasons s join public.leagues l on l.id=s.league_id
    where s.id=p_season_id
      and (p_league_id is null or s.league_id=p_league_id)
      and (p_location_id is null or l.location_id=p_location_id)
  ) then raise exception 'Selected reporting context is invalid'; end if;
  if p_league_id is not null and not exists(
    select 1 from public.leagues l
    where l.id=p_league_id and (p_location_id is null or l.location_id=p_location_id)
  ) then raise exception 'Selected reporting context is invalid'; end if;

  return query
  select c.id,c.amount_pence,c.category,c.description,c.occurred_at,
    c.location_id,l.name,c.league_id,g.name,c.season_id,s.name,
    c.reference,c.notes,c.created_by,c.created_at
  from public.finance_operating_costs c
  left join public.locations l on l.id=c.location_id
  left join public.leagues g on g.id=c.league_id
  left join public.seasons s on s.id=c.season_id
  where (p_location_id is null or c.location_id=p_location_id)
    and (p_league_id is null or c.league_id=p_league_id)
    and (p_season_id is null or c.season_id=p_season_id)
    and (p_from_date is null or c.occurred_at>=p_from_date::timestamptz)
    and (p_to_date is null or c.occurred_at<(p_to_date+1)::timestamptz)
  order by c.occurred_at desc,c.created_at desc
  limit least(greatest(coalesce(p_limit,100),1),200);
end;
$$;
revoke all on function public.get_admin_operating_costs(uuid,uuid,uuid,date,date,integer) from public,anon;
grant execute on function public.get_admin_operating_costs(uuid,uuid,uuid,date,date,integer) to authenticated;

create or replace function public.get_admin_business_performance(
  p_location_id uuid default null,
  p_league_id uuid default null,
  p_season_id uuid default null,
  p_from_date date default null,
  p_to_date date default null
)
returns table(
  team_charges_pence bigint,
  team_receipts_pence bigint,
  team_refunds_pence bigint,
  team_credits_pence bigint,
  team_fines_pence bigint,
  outstanding_pence bigint,
  upcoming_team_forecast_pence bigint,
  upcoming_team_obligations bigint,
  player_card_gross_pence bigint,
  player_card_refunds_pence bigint,
  player_card_fees_pence bigint,
  player_card_net_pence bigint,
  recorded_costs_pence bigint,
  net_operating_surplus_pence bigint
)
language plpgsql
stable
security definer
set search_path=''
as $$
begin
  if auth.uid() is null or not public.has_finance_access() then
    raise exception 'Finance permission required';
  end if;
  if p_season_id is not null and not exists(
    select 1 from public.seasons s join public.leagues l on l.id=s.league_id
    where s.id=p_season_id
      and (p_league_id is null or s.league_id=p_league_id)
      and (p_location_id is null or l.location_id=p_location_id)
  ) then raise exception 'Selected reporting context is invalid'; end if;
  if p_league_id is not null and not exists(
    select 1 from public.leagues l
    where l.id=p_league_id and (p_location_id is null or l.location_id=p_location_id)
  ) then raise exception 'Selected reporting context is invalid'; end if;

  return query
  with scoped_seasons as (
    select s.id
    from public.seasons s
    join public.leagues l on l.id=s.league_id
    where (p_location_id is null or l.location_id=p_location_id)
      and (p_league_id is null or l.id=p_league_id)
      and (p_season_id is null or s.id=p_season_id)
  ),
  team_ledger as (
    select e.season_team_id,
      coalesce(sum(e.amount_pence) filter(where e.entry_type='charge'),0)::bigint charges,
      coalesce(sum(e.amount_pence) filter(where e.entry_type='payment'),0)::bigint receipts,
      coalesce(sum(e.amount_pence) filter(where e.entry_type='refund'),0)::bigint refunds,
      coalesce(sum(e.amount_pence) filter(where e.entry_type='credit'),0)::bigint credits,
      coalesce(sum(e.amount_pence) filter(where e.entry_type='fine'),0)::bigint fines,
      coalesce(sum(case when e.entry_type in ('charge','fine','refund') then e.amount_pence::bigint
        when e.entry_type in ('payment','credit') then -e.amount_pence::bigint else 0 end),0)::bigint balance
    from public.finance_entries e
    join public.season_teams st on st.id=e.season_team_id
    join scoped_seasons ss on ss.id=st.season_id
    where (p_from_date is null or e.occurred_at>=p_from_date::timestamptz)
      and (p_to_date is null or e.occurred_at<(p_to_date+1)::timestamptz)
    group by e.season_team_id
  ),
  ledger_totals as (
    select coalesce(sum(charges),0)::bigint charges,
      coalesce(sum(receipts),0)::bigint receipts,
      coalesce(sum(refunds),0)::bigint refunds,
      coalesce(sum(credits),0)::bigint credits,
      coalesce(sum(fines),0)::bigint fines,
      coalesce(sum(greatest(balance,0)),0)::bigint outstanding
    from team_ledger
  ),
  forecast as (
    select coalesce(sum(o.amount_pence),0)::bigint amount,
      count(*)::bigint obligations
    from public.team_fixture_payment_obligations o
    join public.season_teams st on st.id=o.season_team_id
    join scoped_seasons ss on ss.id=st.season_id
    where o.status in ('due','grace_period')
      and o.scheduled_at_snapshot>=now()
      and (p_from_date is null or o.scheduled_at_snapshot>=p_from_date::timestamptz)
      and (p_to_date is null or o.scheduled_at_snapshot<(p_to_date+1)::timestamptz)
  ),
  player_cards as (
    select
      coalesce(sum(pr.amount_pence) filter(where pr.status in ('paid','partially_refunded','refunded')),0)::bigint gross,
      coalesce(sum(pr.amount_refunded_pence) filter(where pr.status in ('paid','partially_refunded','refunded')),0)::bigint refunds,
      coalesce(sum(pr.stripe_fee_pence) filter(where pr.status in ('paid','partially_refunded','refunded')),0)::bigint fees,
      coalesce(sum(greatest(coalesce(pr.net_amount_pence,pr.amount_pence-coalesce(pr.stripe_fee_pence,0))-pr.amount_refunded_pence,0))
        filter(where pr.status in ('paid','partially_refunded','refunded')),0)::bigint net
    from public.payment_records pr
    join public.season_teams st on st.id=pr.season_team_id
    join scoped_seasons ss on ss.id=st.season_id
    where (p_from_date is null or coalesce(pr.paid_at,pr.created_at)>=p_from_date::timestamptz)
      and (p_to_date is null or coalesce(pr.paid_at,pr.created_at)<(p_to_date+1)::timestamptz)
  ),
  costs as (
    select coalesce(sum(c.amount_pence),0)::bigint amount
    from public.finance_operating_costs c
    where (p_location_id is null or c.location_id=p_location_id)
      and (p_league_id is null or c.league_id=p_league_id)
      and (p_season_id is null or c.season_id=p_season_id)
      and (p_from_date is null or c.occurred_at>=p_from_date::timestamptz)
      and (p_to_date is null or c.occurred_at<(p_to_date+1)::timestamptz)
  )
  select lt.charges,lt.receipts,lt.refunds,lt.credits,lt.fines,lt.outstanding,
    f.amount,f.obligations,pc.gross,pc.refunds,pc.fees,pc.net,c.amount,
    (lt.receipts-lt.refunds+pc.net-c.amount)::bigint
  from ledger_totals lt cross join forecast f cross join player_cards pc cross join costs c;
end;
$$;
revoke all on function public.get_admin_business_performance(uuid,uuid,uuid,date,date) from public,anon;
grant execute on function public.get_admin_business_performance(uuid,uuid,uuid,date,date) to authenticated;
