create extension if not exists pg_net with schema extensions;

create table public.notification_dispatch_settings (
  id boolean primary key default true check (id),
  enabled boolean not null default false,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  reason text
);
insert into public.notification_dispatch_settings(id,enabled)
values(true,false) on conflict(id) do nothing;
alter table public.notification_dispatch_settings enable row level security;
create policy notification_dispatch_settings_no_direct_client_access
on public.notification_dispatch_settings for all to anon,authenticated
using(false) with check(false);
revoke all on public.notification_dispatch_settings from anon,authenticated;

create or replace function public.dispatch_notification_worker()
returns bigint
language plpgsql
security definer
set search_path=''
as $$
declare
  v_enabled boolean;
  v_project_url text;
  v_service_key text;
  v_request_id bigint;
begin
  select enabled into v_enabled from public.notification_dispatch_settings where id=true;
  if coalesce(v_enabled,false)=false then return null; end if;

  select decrypted_secret into v_project_url
  from vault.decrypted_secrets where name='open_play_supabase_url';
  select decrypted_secret into v_service_key
  from vault.decrypted_secrets where name='open_play_service_role_key';
  if nullif(v_project_url,'') is null or nullif(v_service_key,'') is null then return null; end if;
  if not pg_try_advisory_xact_lock(hashtext('open-play-notification-dispatch')) then return null; end if;

  v_request_id := net.http_post(
    url := rtrim(v_project_url,'/') || '/functions/v1/deliver-notifications',
    headers := jsonb_build_object(
      'Content-Type','application/json',
      'Authorization','Bearer ' || v_service_key,
      'apikey',v_service_key
    ),
    body := jsonb_build_object('batch_size',25),
    timeout_milliseconds := 10000
  );
  return v_request_id;
end;
$$;
revoke all on function public.dispatch_notification_worker() from public,anon,authenticated;
grant execute on function public.dispatch_notification_worker() to postgres;

do $$
declare v_job_id bigint;
begin
  select jobid into v_job_id from cron.job where jobname='open-play-notification-dispatch' limit 1;
  if v_job_id is null then
    v_job_id := cron.schedule('open-play-notification-dispatch','* * * * *','select public.dispatch_notification_worker();');
  end if;
  perform cron.alter_job(v_job_id,active:=false);
end;
$$;

create or replace function public.admin_get_notification_dispatch_status()
returns table(enabled boolean,vault_credentials_configured boolean,schedule_active boolean,updated_at timestamptz,updated_by uuid,reason text)
language plpgsql
stable
security definer
set search_path=''
as $$
begin
  if auth.uid() is null or not public.has_platform_role() then
    raise exception 'Administrator permission required';
  end if;
  return query
  select s.enabled,
    exists(select 1 from vault.decrypted_secrets where name='open_play_supabase_url' and decrypted_secret<>'')
      and exists(select 1 from vault.decrypted_secrets where name='open_play_service_role_key' and decrypted_secret<>''),
    coalesce((select j.active from cron.job j where j.jobname='open-play-notification-dispatch' limit 1),false),
    s.updated_at,s.updated_by,s.reason
  from public.notification_dispatch_settings s where s.id=true;
end;
$$;

create or replace function public.admin_set_notification_dispatch_enabled(
  p_enabled boolean,
  p_reason text,
  p_confirm_provider_configuration boolean default false
)
returns table(enabled boolean,vault_credentials_configured boolean,schedule_active boolean,updated_at timestamptz,updated_by uuid,reason text)
language plpgsql
security definer
set search_path=''
as $$
declare v_actor uuid:=auth.uid(); v_job_id bigint;
begin
  if v_actor is null or not public.has_platform_role() then
    raise exception 'Administrator permission required';
  end if;
  if p_reason is null or length(btrim(p_reason))<10 then
    raise exception 'Enter a reason of at least 10 characters';
  end if;
  if p_enabled then
    if not exists(select 1 from vault.decrypted_secrets where name='open_play_supabase_url' and decrypted_secret<>'')
      or not exists(select 1 from vault.decrypted_secrets where name='open_play_service_role_key' and decrypted_secret<>'') then
      raise exception 'Add open_play_supabase_url and open_play_service_role_key to Supabase Vault before enabling dispatch';
    end if;
    if not coalesce(p_confirm_provider_configuration,false) then
      raise exception 'Confirm that the required Resend and/or Twilio Edge Function secrets are configured and approved for live delivery';
    end if;
  end if;
  update public.notification_dispatch_settings
  set enabled=p_enabled,updated_by=v_actor,updated_at=now(),reason=btrim(p_reason)
  where id=true;
  select jobid into v_job_id from cron.job where jobname='open-play-notification-dispatch' limit 1;
  if v_job_id is null then raise exception 'Notification dispatch cron job is missing'; end if;
  perform cron.alter_job(v_job_id,active:=p_enabled);
  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,before_data,after_data)
  values(v_actor,case when p_enabled then 'notification.dispatch.enabled' else 'notification.dispatch.disabled' end,
    'notification_dispatch_settings','open-play-notification-dispatch',btrim(p_reason),null,
    jsonb_build_object('enabled',p_enabled,'schedule_active',p_enabled));
  return query select * from public.admin_get_notification_dispatch_status();
end;
$$;

revoke all on function public.admin_get_notification_dispatch_status() from public,anon;
grant execute on function public.admin_get_notification_dispatch_status() to authenticated;
revoke all on function public.admin_set_notification_dispatch_enabled(boolean,text,boolean) from public,anon;
grant execute on function public.admin_set_notification_dispatch_enabled(boolean,text,boolean) to authenticated;