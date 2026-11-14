-- Owner decision D6: no new online card payments without explicit approval.
-- Adds an owner-controlled, audited platform flag that is OFF by default. Player and
-- team checkout Edge Functions refuse to start a checkout while it is off, and the UI
-- hides payment actions. Existing ledgers, obligations and recorded payments are untouched.

alter table public.platform_feature_flags
  drop constraint platform_feature_flags_feature_key_check;
alter table public.platform_feature_flags
  add constraint platform_feature_flags_feature_key_check
  check (feature_key in ('team_recruitment','announcements','online_card_payments'));

insert into public.platform_feature_flags(feature_key,enabled)
values ('online_card_payments',false)
on conflict (feature_key) do nothing;

drop policy public_read_platform_feature_switches on public.platform_feature_flags;
create policy public_read_platform_feature_switches
on public.platform_feature_flags
for select to anon,authenticated
using (feature_key in ('team_recruitment','announcements','online_card_payments'));

create or replace function public.admin_set_platform_feature_flag(
  p_feature_key text,
  p_enabled boolean,
  p_reason text
)
returns public.platform_feature_flags
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid:=auth.uid();
  v_before public.platform_feature_flags;
  v_after public.platform_feature_flags;
begin
  if v_actor is null or not public.has_global_admin_role() then
    raise exception 'Global administrator permission required' using errcode='42501';
  end if;
  if p_feature_key not in ('team_recruitment','announcements','online_card_payments') then
    raise exception 'Unknown feature flag' using errcode='22023';
  end if;
  if p_enabled is null then
    raise exception 'A feature state is required' using errcode='22023';
  end if;
  if p_reason is null or length(btrim(p_reason))<5 or length(btrim(p_reason))>500 then
    raise exception 'Enter a reason between 5 and 500 characters' using errcode='22023';
  end if;

  select * into v_before
  from public.platform_feature_flags
  where feature_key=p_feature_key
  for update;
  if not found then raise exception 'Feature flag is not configured' using errcode='P0002'; end if;
  if v_before.enabled is not distinct from p_enabled then
    raise exception 'Feature already has the requested state' using errcode='22023';
  end if;

  update public.platform_feature_flags
  set enabled=p_enabled,updated_by=v_actor,updated_at=now()
  where feature_key=p_feature_key
  returning * into v_after;

  insert into public.audit_log(
    actor_user_id,action,entity_type,entity_id,reason,before_data,after_data
  ) values (
    v_actor,'platform.feature_flag.updated','platform_feature_flag',p_feature_key,btrim(p_reason),
    jsonb_build_object('enabled',v_before.enabled),
    jsonb_build_object('enabled',v_after.enabled)
  );
  return v_after;
end;
$$;
revoke all on function public.admin_set_platform_feature_flag(text,boolean,text) from public,anon;
grant execute on function public.admin_set_platform_feature_flag(text,boolean,text) to authenticated;
