-- Forward-only correction for safe Stripe Connect transfer reconciliation.
-- The original Connect migration remains immutable; replace only the failure/reversal RPC.
create or replace function public.record_referee_payout_transfer_failure(
  p_payout_type text,
  p_payout_id uuid,
  p_failure_reason text,
  p_transfer_reversed boolean default false,
  p_stripe_transfer_id text default null
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status text;
  v_referee_user_id uuid;
  v_amount integer;
  v_attempt integer;
  v_transfer_id text;
begin
  if p_payout_type is null or p_payout_type not in ('match_report','milestone') or p_payout_id is null then
    raise exception 'A valid referee payout is required';
  end if;
  if p_payout_type='match_report' then
    select status,referee_user_id,referee_net_pence,transfer_attempts,stripe_transfer_id into v_status,v_referee_user_id,v_amount,v_attempt,v_transfer_id from public.referee_report_payouts where id=p_payout_id for update;
    if v_status is null then raise exception 'Referee payout not found'; end if;
    if v_status not in ('processing','transferred') or (v_status='transferred' and not p_transfer_reversed) then
      raise exception 'Referee payout cannot be marked failed from its current state';
    end if;
    if p_transfer_reversed and p_stripe_transfer_id is null then
      return 'unmatched_reversal';
    end if;
    if p_transfer_reversed and v_transfer_id is distinct from p_stripe_transfer_id then
      if exists(
        select 1 from public.referee_payout_transfer_history history
        where history.payout_type='match_report' and history.payout_id=p_payout_id
          and history.stripe_transfer_id=p_stripe_transfer_id and history.status='reversed'
      ) then return 'stale_reversal'; end if;
      update public.referee_payout_transfer_history
      set status='reversed',failure_reason=left(coalesce(p_failure_reason,'Stripe transfer reversed'),500)
      where payout_type='match_report' and payout_id=p_payout_id
        and stripe_transfer_id=p_stripe_transfer_id and status='transferred';
      if found then return 'stale_reversal'; end if;
      return 'unmatched_reversal';
    end if;
    insert into public.referee_payout_transfer_history(
      payout_type,payout_id,referee_user_id,attempt_number,stripe_transfer_id,
      amount_pence,currency,status,failure_reason
    ) values(
      'match_report',p_payout_id,v_referee_user_id,v_attempt,v_transfer_id,v_amount,'gbp',
      case when p_transfer_reversed then 'reversed' else 'failed' end,
      left(coalesce(p_failure_reason,'Stripe transfer failed'),500)
    )
    on conflict(payout_type,payout_id,attempt_number) do update set
      status=excluded.status,failure_reason=excluded.failure_reason;
    update public.referee_report_payouts
    set status='failed',failure_reason=left(coalesce(p_failure_reason,'Stripe transfer failed'),500),
      processing_started_at=null,
      stripe_transfer_id=case when p_transfer_reversed then null else stripe_transfer_id end
    where id=p_payout_id;
  else
    select status,referee_user_id,amount_pence,transfer_attempts,stripe_transfer_id into v_status,v_referee_user_id,v_amount,v_attempt,v_transfer_id from public.referee_milestone_rewards where id=p_payout_id for update;
    if v_status is null then raise exception 'Referee milestone reward not found'; end if;
    if v_status not in ('processing','transferred') or (v_status='transferred' and not p_transfer_reversed) then
      raise exception 'Referee milestone cannot be marked failed from its current state';
    end if;
    if p_transfer_reversed and p_stripe_transfer_id is null then
      return 'unmatched_reversal';
    end if;
    if p_transfer_reversed and v_transfer_id is distinct from p_stripe_transfer_id then
      if exists(
        select 1 from public.referee_payout_transfer_history history
        where history.payout_type='milestone' and history.payout_id=p_payout_id
          and history.stripe_transfer_id=p_stripe_transfer_id and history.status='reversed'
      ) then return 'stale_reversal'; end if;
      update public.referee_payout_transfer_history
      set status='reversed',failure_reason=left(coalesce(p_failure_reason,'Stripe transfer reversed'),500)
      where payout_type='milestone' and payout_id=p_payout_id
        and stripe_transfer_id=p_stripe_transfer_id and status='transferred';
      if found then return 'stale_reversal'; end if;
      return 'unmatched_reversal';
    end if;
    insert into public.referee_payout_transfer_history(
      payout_type,payout_id,referee_user_id,attempt_number,stripe_transfer_id,
      amount_pence,currency,status,failure_reason
    ) values(
      'milestone',p_payout_id,v_referee_user_id,v_attempt,v_transfer_id,v_amount,'gbp',
      case when p_transfer_reversed then 'reversed' else 'failed' end,
      left(coalesce(p_failure_reason,'Stripe transfer failed'),500)
    )
    on conflict(payout_type,payout_id,attempt_number) do update set
      status=excluded.status,failure_reason=excluded.failure_reason;
    update public.referee_milestone_rewards
    set status='failed',failure_reason=left(coalesce(p_failure_reason,'Stripe transfer failed'),500),
      processing_started_at=null,
      stripe_transfer_id=case when p_transfer_reversed then null else stripe_transfer_id end
    where id=p_payout_id;
  end if;
  return 'failed';
end;
$$;
