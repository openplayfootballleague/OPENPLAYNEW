-- Durable, transactionally-enqueued referee match-fee transfers.
-- The admin approval RPC inserts the payout; this trigger inserts the outbox job
-- in the same transaction so browser closure cannot lose the transfer request.
create table public.referee_payout_transfer_jobs (
  id uuid primary key default gen_random_uuid(),
  payout_id uuid not null unique references public.referee_report_payouts(id) on delete restrict,
  status text not null default 'queued'
    check(status in ('queued','processing','completed','failed')),
  attempts integer not null default 0 check(attempts>=0),
  available_at timestamptz not null default now(),
  locked_at timestamptz,
  first_attempt_at timestamptz,
  lock_token uuid,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint referee_payout_transfer_job_lock_state check (
    (status='processing' and locked_at is not null and lock_token is not null)
    or status<>'processing'
  )
);
create index referee_payout_transfer_jobs_queue_idx
  on public.referee_payout_transfer_jobs(status,available_at,created_at);
alter table public.referee_payout_transfer_jobs enable row level security;
revoke all on public.referee_payout_transfer_jobs from public,anon,authenticated;

create or replace function public.sync_referee_report_payout_transfer_job()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
begin
  if tg_op='INSERT' then
    if new.status in ('pending_connect','failed') then
      insert into public.referee_payout_transfer_jobs(payout_id,status)
      values(new.id,'queued')
      on conflict(payout_id) do nothing;
    end if;
    return new;
  end if;

  if new.status is distinct from old.status then
    if new.status='processing' then
      update public.referee_payout_transfer_jobs
      set status='processing',
          locked_at=coalesce(locked_at,now()),
          lock_token=coalesce(lock_token,gen_random_uuid()),
          first_attempt_at=case when status='failed' then now() else coalesce(first_attempt_at,now()) end,
          updated_at=now()
      where payout_id=new.id and status in ('queued','failed');
    elsif new.status='transferred' then
      update public.referee_payout_transfer_jobs
      set status='completed',locked_at=null,lock_token=null,last_error=null,updated_at=now()
      where payout_id=new.id;
    elsif new.status='failed' then
      update public.referee_payout_transfer_jobs
      set status='failed',locked_at=null,lock_token=null,
          last_error=left(coalesce(new.failure_reason,'Transfer failed'),500),updated_at=now()
      where payout_id=new.id;
    elsif new.status='pending_connect' then
      update public.referee_payout_transfer_jobs
      set status='queued',locked_at=null,lock_token=null,available_at=now(),updated_at=now()
      where payout_id=new.id and status<>'completed';
    end if;
  end if;
  return new;
end;
$$;

create trigger referee_report_payout_transfer_job_sync
after insert or update of status on public.referee_report_payouts
for each row execute function public.sync_referee_report_payout_transfer_job();
revoke all on function public.sync_referee_report_payout_transfer_job() from public,anon,authenticated;

-- Backfill pre-existing entitlements. Preserve any in-flight attempt as a
-- processing lease so it can be reconciled with its original idempotency key.
insert into public.referee_payout_transfer_jobs(
  payout_id,status,locked_at,first_attempt_at,lock_token
)
select payout.id,
  case when payout.status='processing' then 'processing' else 'queued' end,
  case when payout.status='processing' then coalesce(payout.processing_started_at,now()) else null end,
  case when payout.status='processing' then coalesce(payout.processing_started_at,payout.created_at) else null end,
  case when payout.status='processing' then gen_random_uuid() else null end
from public.referee_report_payouts payout
where payout.status in ('pending_connect','failed','processing')
on conflict(payout_id) do nothing;

create or replace function public.claim_referee_payout_transfer_jobs(p_limit integer default 10)
returns table(job_id uuid,payout_id uuid,lock_token uuid)
language plpgsql
security invoker
set search_path=''
as $$
begin
  -- Execute privilege is granted only to service_role; this invoker function
  -- therefore runs with the service role's explicit table grants.
  -- Recover expired leases only while Stripe's idempotency window is safely open.
  -- Replays reuse the same payout attempt key; after 23h, leave the job held for
  -- explicit reconciliation rather than risk a second transfer after key expiry.
  update public.referee_payout_transfer_jobs job
  set status='queued',locked_at=null,lock_token=null,available_at=now(),
      last_error='Recovered expired transfer lease for idempotent reconciliation',updated_at=now()
  where job.status='processing'
    and job.locked_at<now()-interval '5 minutes'
    and job.first_attempt_at>now()-interval '23 hours'
    and exists(
      select 1 from public.referee_report_payouts payout
      where payout.id=job.payout_id
        and payout.stripe_transfer_id is null
        and (
          payout.status in ('pending_connect','failed')
          or (payout.status='processing' and payout.processing_started_at<now()-interval '5 minutes')
        )
    );
  return query
  with candidates as (
    select job.id
    from public.referee_payout_transfer_jobs job
    join public.referee_report_payouts payout on payout.id=job.payout_id
    join public.referee_connect_accounts account on account.referee_user_id=payout.referee_user_id
    where job.status='queued'
      and job.available_at<=now()
      and (payout.status in ('pending_connect','failed') or
        (payout.status='processing' and payout.processing_started_at<now()-interval '5 minutes'
          and job.first_attempt_at>now()-interval '23 hours'))
      and account.onboarding_status='enabled'
      and account.transfers_enabled=true
      and payout.stripe_transfer_id is null
    order by job.created_at,job.id
    for update of job skip locked
    limit greatest(1,least(coalesce(p_limit,10),50))
  )
  update public.referee_payout_transfer_jobs job
  set status='processing',attempts=job.attempts+1,locked_at=now(),
      first_attempt_at=coalesce(job.first_attempt_at,now()),
      lock_token=gen_random_uuid(),last_error=null,updated_at=now()
  from candidates
  where job.id=candidates.id
  returning job.id,job.payout_id,job.lock_token;
end;
$$;
revoke all on function public.claim_referee_payout_transfer_jobs(integer) from public,anon,authenticated;
grant select,update on public.referee_payout_transfer_jobs to service_role;
grant select,update on public.referee_report_payouts to service_role;
grant select on public.referee_match_reports,public.referee_connect_accounts to service_role;
grant execute on function public.claim_referee_payout_transfer_jobs(integer) to service_role;

create or replace function public.claim_referee_payout_transfer_worker(
  p_job_id uuid,
  p_payout_id uuid,
  p_lock_token uuid
)
returns jsonb
language plpgsql
security invoker
set search_path=''
as $$
declare
  v_job public.referee_payout_transfer_jobs;
  v_payout public.referee_report_payouts;
  v_account public.referee_connect_accounts;
  v_report public.referee_match_reports;
begin
  select * into v_job from public.referee_payout_transfer_jobs
  where id=p_job_id and payout_id=p_payout_id and status='processing'
    and lock_token=p_lock_token
  for update;
  if not found then raise exception 'Referee payout job lease is no longer valid'; end if;

  select * into v_payout from public.referee_report_payouts
  where id=p_payout_id for update;
  if not found or v_payout.status not in ('pending_connect','failed','processing')
     or v_payout.stripe_transfer_id is not null then
    raise exception 'Referee payout is not ready for a worker transfer';
  end if;
  if v_payout.status='processing'
     and (v_payout.processing_started_at is null
       or v_payout.processing_started_at>now()-interval '5 minutes'
       or v_payout.processing_started_at<now()-interval '23 hours') then
    raise exception 'An in-flight referee transfer is not yet safe to reconcile';
  end if;
  select * into v_report from public.referee_match_reports
  where id=v_payout.report_id;
  if not found or v_report.status<>'approved' or v_report.report_source<>'referee'
     or v_report.referee_user_id is distinct from v_payout.referee_user_id then
    raise exception 'Only an approved referee-submitted report can be transferred';
  end if;
  select * into v_account from public.referee_connect_accounts
  where referee_user_id=v_payout.referee_user_id for update;
  if not found or v_account.onboarding_status<>'enabled' or not v_account.transfers_enabled then
    raise exception 'The referee connected account is not eligible for transfers';
  end if;

  update public.referee_report_payouts
  set status='processing',processing_started_at=now(),
      transfer_attempts=case when status='processing' then transfer_attempts else transfer_attempts+1 end,
      failure_reason=null
  where id=p_payout_id
  returning * into v_payout;

  return jsonb_build_object(
    'payout_type','match_report','payout_id',v_payout.id,
    'referee_user_id',v_payout.referee_user_id,
    'stripe_account_id',v_account.stripe_account_id,
    'amount_pence',v_payout.referee_net_pence,
    'currency','gbp','attempt',v_payout.transfer_attempts,
    'report_id',v_payout.report_id
  );
end;
$$;
revoke all on function public.claim_referee_payout_transfer_worker(uuid,uuid,uuid) from public,anon,authenticated;
grant execute on function public.claim_referee_payout_transfer_worker(uuid,uuid,uuid) to service_role;

create or replace function public.release_referee_payout_transfer_job(
  p_job_id uuid,p_lock_token uuid,p_reason text,p_delay_seconds integer default 300
)
returns boolean
language plpgsql
security invoker
set search_path=''
as $$
begin
  update public.referee_payout_transfer_jobs
  set status='queued',available_at=now()+make_interval(secs=>greatest(60,least(coalesce(p_delay_seconds,300),3600))),
      locked_at=null,lock_token=null,last_error=left(coalesce(p_reason,'Worker could not claim payout'),500),
      updated_at=now()
  where id=p_job_id and status='processing' and lock_token=p_lock_token
    and not exists(
      select 1 from public.referee_report_payouts payout
      where payout.id=referee_payout_transfer_jobs.payout_id
        and payout.status in ('processing','transferred')
    );
  return found;
end;
$$;
revoke all on function public.release_referee_payout_transfer_job(uuid,uuid,text,integer) from public,anon,authenticated;
grant execute on function public.release_referee_payout_transfer_job(uuid,uuid,text,integer) to service_role;

-- A one-minute, no-op-until-configured scheduler. The secret and service-role
-- key live only in Supabase Vault, never in repository files or browser code.
create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;

create or replace function public.dispatch_referee_payout_transfer_worker()
returns bigint
language plpgsql
security definer
set search_path=''
as $$
declare
  v_project_url text;
  v_service_key text;
  v_cron_secret text;
  v_request_id bigint;
begin
  select decrypted_secret into v_project_url
  from vault.decrypted_secrets where name='open_play_supabase_url';
  select decrypted_secret into v_service_key
  from vault.decrypted_secrets where name='open_play_service_role_key';
  select decrypted_secret into v_cron_secret
  from vault.decrypted_secrets where name='referee_payout_cron_secret';
  if nullif(v_project_url,'') is null or nullif(v_service_key,'') is null
     or nullif(v_cron_secret,'') is null then return null; end if;
  if not pg_try_advisory_xact_lock(hashtext('open-play-referee-payout-dispatch')) then return null; end if;
  v_request_id:=net.http_post(
    url:=rtrim(v_project_url,'/')||'/functions/v1/process-referee-payout-queue',
    headers:=jsonb_build_object(
      'Content-Type','application/json',
      'Authorization','Bearer '||v_service_key,
      'apikey',v_service_key,
      'x-referee-payout-cron-secret',v_cron_secret
    ),
    body:=jsonb_build_object('batch_size',10),
    timeout_milliseconds:=60000
  );
  return v_request_id;
end;
$$;
revoke all on function public.dispatch_referee_payout_transfer_worker() from public,anon,authenticated;
grant execute on function public.dispatch_referee_payout_transfer_worker() to postgres;

do $$
declare v_job_id bigint;
begin
  select jobid into v_job_id from cron.job
  where jobname='open-play-referee-payout-dispatch' limit 1;
  if v_job_id is null then
    perform cron.schedule('open-play-referee-payout-dispatch','* * * * *',
      'select public.dispatch_referee_payout_transfer_worker();');
  else
    perform cron.alter_job(v_job_id,active:=true);
  end if;
end;
$$;
