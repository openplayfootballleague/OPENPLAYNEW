-- Make SMS opt-in explicit, timestamped and auditable; force preference
-- changes through the RPC so clients cannot bypass the consent record.
alter table public.notification_preferences
  add column if not exists sms_consented_at timestamptz,
  add column if not exists sms_consent_revoked_at timestamptz,
  add column if not exists sms_consent_version text;

alter table public.notification_preferences
  drop constraint if exists notification_preferences_sms_consent_check;
alter table public.notification_preferences
  add constraint notification_preferences_sms_consent_check
  check (not sms_enabled or (sms_consented_at is not null and sms_consent_version is not null));

drop policy if exists notification_preferences_update_owner on public.notification_preferences;
revoke update on public.notification_preferences from authenticated;
grant select on public.notification_preferences to authenticated;

create or replace function public.update_my_notification_preferences(
  p_email_enabled boolean,
  p_sms_enabled boolean,
  p_in_app_enabled boolean
)
returns public.notification_preferences
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid:=auth.uid();
  v_preferences public.notification_preferences;
  v_old public.notification_preferences;
  v_consent_at timestamptz;
  v_revoked_at timestamptz;
  v_consent_version text;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if p_sms_enabled and not exists(
    select 1 from public.profiles
    where id=v_user and phone is not null and length(btrim(phone))>0
  ) then raise exception 'Add a contact phone number before opting into SMS/text updates'; end if;

  select * into v_old from public.notification_preferences where user_id=v_user for update;
  if not found then
    v_old.email_enabled:=true;
    v_old.sms_enabled:=false;
    v_old.in_app_enabled:=true;
  end if;

  v_consent_at:=v_old.sms_consented_at;
  v_revoked_at:=v_old.sms_consent_revoked_at;
  v_consent_version:=v_old.sms_consent_version;
  if p_sms_enabled and not coalesce(v_old.sms_enabled,false) then
    v_consent_at:=now();
    v_revoked_at:=null;
    v_consent_version:='open-play-sms-v1';
  elsif not p_sms_enabled and coalesce(v_old.sms_enabled,false) then
    v_revoked_at:=now();
  end if;

  insert into public.notification_preferences(
    user_id,email_enabled,sms_enabled,in_app_enabled,
    sms_consented_at,sms_consent_revoked_at,sms_consent_version,updated_at
  )
  values(v_user,p_email_enabled,p_sms_enabled,p_in_app_enabled,
    v_consent_at,v_revoked_at,v_consent_version,now())
  on conflict(user_id) do update set
    email_enabled=excluded.email_enabled,
    sms_enabled=excluded.sms_enabled,
    in_app_enabled=excluded.in_app_enabled,
    sms_consented_at=excluded.sms_consented_at,
    sms_consent_revoked_at=excluded.sms_consent_revoked_at,
    sms_consent_version=excluded.sms_consent_version,
    updated_at=now()
  returning * into v_preferences;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,before_data,after_data)
  values(v_user,'notification.preferences_updated','notification_preferences',v_user::text,
    jsonb_build_object('email_enabled',v_old.email_enabled,'sms_enabled',v_old.sms_enabled,'in_app_enabled',v_old.in_app_enabled),
    jsonb_build_object('email_enabled',p_email_enabled,'sms_enabled',p_sms_enabled,'in_app_enabled',p_in_app_enabled,
      'sms_consented_at',v_consent_at,'sms_consent_revoked_at',v_revoked_at,'sms_consent_version',v_consent_version));
  return v_preferences;
end;
$$;

revoke all on function public.update_my_notification_preferences(boolean,boolean,boolean) from public,anon;
grant execute on function public.update_my_notification_preferences(boolean,boolean,boolean) to authenticated;
