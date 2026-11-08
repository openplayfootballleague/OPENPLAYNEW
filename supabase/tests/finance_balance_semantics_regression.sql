-- Run after the finance balance semantics reconciliation migration.
-- These are fail-closed source-contract checks. Runtime role/ledger arithmetic
-- acceptance still requires an isolated database with disposable Auth identities.
do $$
declare
  v_ledger text := lower(pg_catalog.pg_get_functiondef('public.get_finance_ledger(uuid,uuid)'::regprocedure));
  v_summary text := lower(pg_catalog.pg_get_functiondef('public.get_finance_summary(uuid)'::regprocedure));
  v_create text := lower(pg_catalog.pg_get_functiondef('public.admin_create_finance_entry(uuid,text,integer,text,uuid,timestamptz,text,text,text)'::regprocedure));
begin
  if position('entry_type in (''charge'',''fine'',''refund'')' in v_ledger) = 0 then
    raise exception 'Finance ledger must increase outstanding balance for charges, fines and refunds';
  end if;
  if position('entry_type in (''payment'',''credit'')' in v_ledger) = 0 then
    raise exception 'Finance ledger must decrease outstanding balance for payments and credits';
  end if;
  if position('entry_type in (''charge'',''fine'',''refund'')' in v_summary) = 0 then
    raise exception 'Finance summary must increase outstanding balance for charges, fines and refunds';
  end if;
  if position('entry_type in (''payment'',''credit'')' in v_summary) = 0 then
    raise exception 'Finance summary must decrease outstanding balance for payments and credits';
  end if;
  if position('greatest(t.balance,0)' in v_summary) = 0 then
    raise exception 'Finance summary must not report negative outstanding team balances';
  end if;
  if position('has_finance_access()' in v_ledger) = 0
    or position('has_finance_access()' in v_summary) = 0
    or position('has_finance_access()' in v_create) = 0 then
    raise exception 'Finance RPCs must retain the shared finance-role guard';
  end if;
  if position('insert into public.audit_log' in v_create) = 0 then
    raise exception 'Finance entry creation must retain its audit record';
  end if;
end;
$$;
