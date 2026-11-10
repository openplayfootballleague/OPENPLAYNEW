create or replace function public.get_finance_summary(p_season_id uuid default null)
returns table(season_id uuid,season_name text,teams_with_entries bigint,charges_pence bigint,payments_pence bigint,refunds_pence bigint,credits_pence bigint,fines_pence bigint,outstanding_pence bigint)
language plpgsql stable security definer set search_path=''
as $$
begin
if auth.uid() is null or not public.has_finance_access() then raise exception 'Finance permission required'; end if;
return query
with team_totals as (
 select st.id as team_id,st.season_id,
 count(e.id) as entry_count,
 coalesce(sum(e.amount_pence) filter(where e.entry_type='charge'),0)::bigint charges,
 coalesce(sum(e.amount_pence) filter(where e.entry_type='payment'),0)::bigint payments,
 coalesce(sum(e.amount_pence) filter(where e.entry_type='refund'),0)::bigint refunds,
 coalesce(sum(e.amount_pence) filter(where e.entry_type='credit'),0)::bigint credits,
 coalesce(sum(e.amount_pence) filter(where e.entry_type='fine'),0)::bigint fines,
 coalesce(sum(case when e.entry_type in ('charge','fine','refund') then e.amount_pence::bigint when e.entry_type in ('payment','credit') then -e.amount_pence::bigint else 0 end),0)::bigint balance
 from public.season_teams st left join public.finance_entries e on e.season_team_id=st.id
 group by st.id,st.season_id
)
select se.id,se.name,count(t.team_id) filter(where t.entry_count>0),
coalesce(sum(t.charges),0)::bigint,coalesce(sum(t.payments),0)::bigint,
coalesce(sum(t.refunds),0)::bigint,coalesce(sum(t.credits),0)::bigint,
coalesce(sum(t.fines),0)::bigint,
coalesce(sum(greatest(t.balance,0)),0)::bigint
from public.seasons se left join team_totals t on t.season_id=se.id
where p_season_id is null or se.id=p_season_id
group by se.id,se.name order by se.name;
end; $$;