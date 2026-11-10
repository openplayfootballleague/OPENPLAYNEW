create table public.finance_entries (
  id uuid primary key default gen_random_uuid(),
  season_team_id uuid not null references public.season_teams(id) on delete restrict,
  fixture_id uuid references public.fixtures(id) on delete restrict,
  entry_type text not null check (entry_type in ('charge','payment','refund','credit','fine')),
  amount_pence integer not null check (amount_pence > 0 and amount_pence <= 100000000),
  description text not null check (length(btrim(description)) between 3 and 240),
  due_at timestamptz,
  occurred_at timestamptz not null default now(),
  payment_method text check (payment_method is null or payment_method in ('cash','bank_transfer','card_terminal','other')),
  reference text check (reference is null or length(reference) <= 120),
  notes text check (notes is null or length(notes) <= 1000),
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint finance_payment_method_only_for_payment check (entry_type = 'payment' or payment_method is null)
);
create index finance_entries_team_created_idx on public.finance_entries(season_team_id,created_at desc);
create index finance_entries_fixture_idx on public.finance_entries(fixture_id) where fixture_id is not null;
alter table public.finance_entries enable row level security;
revoke all on public.finance_entries from anon, authenticated;

create or replace function public.get_finance_ledger(p_season_id uuid default null,p_team_id uuid default null)
returns table(
  id uuid,season_team_id uuid,team_name text,season_id uuid,season_name text,fixture_id uuid,
  gameweek integer,entry_type text,amount_pence integer,description text,due_at timestamptz,
  occurred_at timestamptz,payment_method text,reference text,notes text,created_by uuid,
  created_at timestamptz,team_balance_pence bigint
)
language plpgsql stable security definer set search_path=''
as $$
begin
  if auth.uid() is null or not public.has_finance_access() then
    raise exception 'Finance permission required';
  end if;
  return query
  with scoped as (
    select e.*,st.name as t_name,st.season_id as s_id,se.name as s_name,f.gameweek,
      sum(case when e.entry_type in ('charge','fine') then e.amount_pence::bigint
        when e.entry_type in ('payment','refund','credit') then -e.amount_pence::bigint else 0 end)
      over(partition by e.season_team_id) as balance
    from public.finance_entries e
    join public.season_teams st on st.id=e.season_team_id
    join public.seasons se on se.id=st.season_id
    left join public.fixtures f on f.id=e.fixture_id
    where (p_season_id is null or st.season_id=p_season_id)
      and (p_team_id is null or st.id=p_team_id)
  )
  select s.id,s.season_team_id,s.t_name,s.s_id,s.s_name,s.fixture_id,s.gameweek,
    s.entry_type,s.amount_pence,s.description,s.due_at,s.occurred_at,s.payment_method,
    s.reference,s.notes,s.created_by,s.created_at,s.balance
  from scoped s order by s.created_at desc,s.id;
end; $$;

create or replace function public.get_finance_summary(p_season_id uuid default null)
returns table(
  season_id uuid,season_name text,teams_with_entries bigint,charges_pence bigint,
  payments_pence bigint,refunds_pence bigint,credits_pence bigint,fines_pence bigint,
  outstanding_pence bigint
)
language plpgsql stable security definer set search_path=''
as $$
begin
  if auth.uid() is null or not public.has_finance_access() then
    raise exception 'Finance permission required';
  end if;
  return query
  select se.id,se.name,count(distinct e.season_team_id),
    coalesce(sum(e.amount_pence) filter(where e.entry_type='charge'),0)::bigint,
    coalesce(sum(e.amount_pence) filter(where e.entry_type='payment'),0)::bigint,
    coalesce(sum(e.amount_pence) filter(where e.entry_type='refund'),0)::bigint,
    coalesce(sum(e.amount_pence) filter(where e.entry_type='credit'),0)::bigint,
    coalesce(sum(e.amount_pence) filter(where e.entry_type='fine'),0)::bigint,
    greatest(coalesce(sum(case when e.entry_type in ('charge','fine') then e.amount_pence::bigint
      when e.entry_type in ('payment','refund','credit') then -e.amount_pence::bigint else 0 end),0),0)::bigint
  from public.seasons se
  join public.season_teams st on st.season_id=se.id
  left join public.finance_entries e on e.season_team_id=st.id
  where p_season_id is null or se.id=p_season_id
  group by se.id,se.name order by se.name;
end; $$;

create or replace function public.admin_create_finance_entry(
  p_season_team_id uuid,p_entry_type text,p_amount_pence integer,p_description text,
  p_fixture_id uuid default null,p_due_at timestamptz default null,
  p_payment_method text default null,p_reference text default null,p_notes text default null
)
returns public.finance_entries
language plpgsql security definer set search_path=''
as $$
declare v_actor uuid:=auth.uid(); v_entry public.finance_entries; v_team public.season_teams;
begin
  if v_actor is null or not public.has_finance_access() then
    raise exception 'Finance permission required';
  end if;
  if p_entry_type not in ('charge','payment','refund','credit','fine') then
    raise exception 'Invalid finance entry type';
  end if;
  if p_amount_pence is null or p_amount_pence<=0 or p_amount_pence>100000000 then
    raise exception 'Amount must be between 1 penny and £1,000,000';
  end if;
  if p_description is null or length(btrim(p_description)) not between 3 and 240 then
    raise exception 'Description must be between 3 and 240 characters';
  end if;
  if p_notes is not null and length(p_notes)>1000 then raise exception 'Notes are too long'; end if;
  if p_reference is not null and length(p_reference)>120 then raise exception 'Reference is too long'; end if;
  if p_entry_type='payment' and p_payment_method not in ('cash','bank_transfer','card_terminal','other') then
    raise exception 'Choose a valid manual payment method';
  end if;
  if p_entry_type<>'payment' and p_payment_method is not null then
    raise exception 'Payment method can only be set on a payment entry';
  end if;
  select * into v_team from public.season_teams where id=p_season_team_id;
  if not found then raise exception 'Season team not found'; end if;
  if p_fixture_id is not null and not exists(
    select 1 from public.fixtures f where f.id=p_fixture_id and f.season_id=v_team.season_id
      and p_season_team_id in (f.home_team_id,f.away_team_id)
  ) then raise exception 'Fixture must belong to this team and season'; end if;
  insert into public.finance_entries(season_team_id,fixture_id,entry_type,amount_pence,description,due_at,payment_method,reference,notes,created_by)
  values(p_season_team_id,p_fixture_id,p_entry_type,p_amount_pence,btrim(p_description),p_due_at,p_payment_method,nullif(btrim(p_reference),''),nullif(btrim(p_notes),''),v_actor)
  returning * into v_entry;
  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,before_data,after_data)
  values(v_actor,'finance.entry.created','finance_entry',v_entry.id::text,
    btrim(p_description),null,to_jsonb(v_entry)-'created_by');
  return v_entry;
end; $$;

revoke all on function public.get_finance_ledger(uuid,uuid) from public,anon;
grant execute on function public.get_finance_ledger(uuid,uuid) to authenticated;
revoke all on function public.get_finance_summary(uuid) from public,anon;
grant execute on function public.get_finance_summary(uuid) to authenticated;
revoke all on function public.admin_create_finance_entry(uuid,text,integer,text,uuid,timestamptz,text,text,text) from public,anon;
grant execute on function public.admin_create_finance_entry(uuid,text,integer,text,uuid,timestamptz,text,text,text) to authenticated;
