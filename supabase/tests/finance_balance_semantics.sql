-- Exercises the forward-only finance balance semantics using synthetic
-- teams and a finance_admin actor. All amounts are integer pence.
do $finance_balance_semantics$
declare
  v_summary record;
  v_balance bigint;
begin
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

  -- An overpaid team must not offset another team's positive debt.
  perform public.admin_create_finance_entry(
    '00000000-0000-4000-8000-000000000052',
    'payment',5000,'CI finance overpayment',
    null,null,'cash'
  );

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
     or v_summary.payments_pence <> 3000
     or v_summary.refunds_pence <> 2000
     or v_summary.credits_pence <> 500
     or v_summary.fines_pence <> 1000
     or v_summary.outstanding_pence <> 9500 then
    raise exception 'Unexpected finance summary for season A: %',row_to_json(v_summary);
  end if;

  select * into v_summary
  from public.get_finance_summary('00000000-0000-4000-8000-000000000030');

  if v_summary.payments_pence <> 5000
     or v_summary.outstanding_pence <> 0 then
    raise exception 'Overpaid team should have zero outstanding and must not offset another season: %',row_to_json(v_summary);
  end if;

  execute 'reset role';
end;
$finance_balance_semantics$;
