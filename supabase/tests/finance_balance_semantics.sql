-- Exercises the forward-only finance balance semantics using synthetic
-- teams and a finance_admin actor. All amounts are integer pence.
do $finance_balance_semantics$
declare
  v_summary record;
  v_business record;
  v_balance bigint;
  v_location_id uuid;
  v_league_id uuid;
  v_cost_id uuid;
  v_adjustment_id uuid;
  v_cost_count bigint;
  v_failed boolean;
begin
  if has_table_privilege('anon','public.finance_operating_costs','SELECT')
     or has_table_privilege('authenticated','public.finance_operating_costs','SELECT')
     or has_table_privilege('authenticated','public.finance_operating_costs','INSERT')
     or has_table_privilege('authenticated','public.finance_operating_costs','UPDATE')
     or has_table_privilege('authenticated','public.finance_operating_costs','DELETE') then
    raise exception 'Operating cost ledger must not expose direct client table access';
  end if;

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000007',true);
  perform set_config(
    'request.jwt.claims',
    jsonb_build_object(
      'sub','00000000-0000-4000-8000-000000000007',
      'role','authenticated'
    )::text,
    true
  );

  -- Charge + fine + refund increase the balance owed. Payment + credit reduce it.
  perform public.admin_create_finance_entry(
    '00000000-0000-4000-8000-000000000050',
    'charge',10000,'CI finance charge'
  );
  perform public.admin_create_finance_entry(
    '00000000-0000-4000-8000-000000000050',
    'payment',3000,'CI finance payment',
    null,null,'cash'
  );
  perform public.admin_create_finance_entry(
    '00000000-0000-4000-8000-000000000050',
    'refund',2000,'CI finance refund'
  );
  perform public.admin_create_finance_entry(
    '00000000-0000-4000-8000-000000000050',
    'credit',500,'CI finance credit'
  );
  perform public.admin_create_finance_entry(
    '00000000-0000-4000-8000-000000000050',
    'fine',1000,'CI finance fine'
  );

  -- Seed the second team's overpayment before calculating the scoped business summary.
  perform public.admin_create_finance_entry(
    '00000000-0000-4000-8000-000000000051',
    'payment',5000,'CI finance overpayment',
    null,null,'cash'
  );

  -- Record an operating cost against the same season and verify the business summary.
  select l.location_id,s.league_id into v_location_id,v_league_id
  from public.seasons s join public.leagues l on l.id=s.league_id
  where s.id='00000000-0000-4000-8000-000000000030';

  v_cost_id:=(
    select (public.admin_create_operating_cost(
      2000,'venue_hire','CI venue hire',now()-interval '1 day',
      v_location_id,v_league_id,'00000000-0000-4000-8000-000000000030',
      'CI-COST-001','Synthetic venue cost','Recorded venue hire for finance acceptance'
    )).id
  );

  v_adjustment_id:=(
    select (public.admin_create_operating_cost(
      -500,'adjustment','CI venue hire reversal',now()-interval '1 day',
      v_location_id,v_league_id,'00000000-0000-4000-8000-000000000030',
      'CI-COST-REV-001','Synthetic reversal','Reverse a duplicated venue cost for finance acceptance'
    )).id
  );

  select * into v_business
  from public.get_admin_business_performance(
    v_location_id,v_league_id,'00000000-0000-4000-8000-000000000030'
  );
  if v_business.team_charges_pence<>10000
     or v_business.team_receipts_pence<>8000
     or v_business.team_refunds_pence<>2000
     or v_business.team_credits_pence<>500
     or v_business.team_fines_pence<>1000
     or v_business.outstanding_pence<>9500
     or v_business.recorded_costs_pence<>1500
     or v_business.net_operating_surplus_pence<>4500 then
    raise exception 'Business performance must distinguish charges, receipts, refunds, credits, fines, outstanding, costs and surplus: %',row_to_json(v_business);
  end if;

  select count(*) into v_cost_count
  from public.get_admin_operating_costs(
    v_location_id,v_league_id,'00000000-0000-4000-8000-000000000030',null,null,100
  ) c where c.id=v_cost_id and c.category='venue_hire' and c.amount_pence=2000;
  if v_cost_count<>1 then raise exception 'Recorded operating cost was not returned in the scoped cost register'; end if;

  select * into v_business
  from public.get_admin_business_performance(gen_random_uuid(),null,null);
  if v_business.team_charges_pence<>0 or v_business.recorded_costs_pence<>0 then
    raise exception 'Location-scoped business reporting leaked another location''s finance data';
  end if;

  v_failed:=false;
  begin
    perform public.admin_create_operating_cost(
      1000,'venue_hire','Mismatched cost context',now(),
      gen_random_uuid(),v_league_id,'00000000-0000-4000-8000-000000000030',
      null,null,'Invalid location and season'
    );
  exception when others then
    v_failed:=true;
  end;
  if not v_failed then raise exception 'Operating cost accepted a mismatched location/season context'; end if;

  v_failed:=false;
  begin
    perform public.admin_create_operating_cost(
      -100,'venue_hire','Invalid negative cost',now(),
      v_location_id,v_league_id,'00000000-0000-4000-8000-000000000030',
      null,null,'Negative amount must be an adjustment'
    );
  exception when others then
    v_failed:=true;
  end;
  if not v_failed then raise exception 'Operating cost accepted a negative amount outside the adjustment category'; end if;

  -- The overpaid second team must not offset another team's positive debt.

  select max(team_balance_pence)
  into v_balance
  from public.get_finance_ledger(
    '00000000-0000-4000-8000-000000000030',
    '00000000-0000-4000-8000-000000000050'
  );

  if v_balance <> 9500 then
    raise exception 'Expected team balance 9500 pence after charge/payment/refund/credit/fine, got %',v_balance;
  end if;

  select * into v_summary
  from public.get_finance_summary('00000000-0000-4000-8000-000000000030');

  if v_summary.charges_pence <> 10000
     or v_summary.payments_pence <> 8000
     or v_summary.refunds_pence <> 2000
     or v_summary.credits_pence <> 500
     or v_summary.fines_pence <> 1000
     or v_summary.outstanding_pence <> 9500 then
    raise exception 'Unexpected finance summary for season A: %',row_to_json(v_summary);
  end if;

  -- The overpaid second team retains its own negative balance. Its credit
  -- must not offset the first team's positive debt in the season roll-up.
  select max(team_balance_pence)
  into v_balance
  from public.get_finance_ledger(
    '00000000-0000-4000-8000-000000000030',
    '00000000-0000-4000-8000-000000000051'
  );

  if v_balance <> -5000 then
    raise exception 'Expected the overpaid team''s individual balance to be -5000 pence, got %',v_balance;
  end if;

  select * into v_summary
  from public.get_finance_summary('00000000-0000-4000-8000-000000000030');

  if v_summary.payments_pence <> 8000
     or v_summary.outstanding_pence <> 9500 then
    raise exception 'Overpaid team must not offset another team''s positive debt: %',row_to_json(v_summary);
  end if;

  execute 'reset role';
  if not exists(
    select 1 from public.audit_log
    where action='finance.operating_cost.created' and entity_type='finance_operating_cost'
      and entity_id in (v_cost_id::text,v_adjustment_id::text)
    group by entity_id
    having count(*)=1
  ) then raise exception 'Operating cost creation was not written to the audit log'; end if;
  if (select count(*) from public.audit_log
      where action='finance.operating_cost.created' and entity_type='finance_operating_cost'
        and entity_id in (v_cost_id::text,v_adjustment_id::text))<>2 then
    raise exception 'Both cost and adjustment entries must be audited';
  end if;
end;
$finance_balance_semantics$;
