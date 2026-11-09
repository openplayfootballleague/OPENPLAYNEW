-- Audited global-admin workflow for player account-retention holds.
-- Holds may be set while an account is active or in its restricted archive.
-- Once an account reaches erasure_due, the irreversible erasure workflow has begun
-- and a hold can no longer be applied safely.

create or replace function public.admin_list_player_retention_accounts(p_search text default null)
returns table(
  user_id uuid,
  full_name text,
  email text,
  account_retention_status text,
  last_sign_in_at timestamptz,
  account_closed_at timestamptz,
  archive_expires_at timestamptz,
  retention_hold boolean,
  retention_hold_reason text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not exists (
    select 1 from public.user_roles ur
    where ur.user_id = auth.uid() and ur.role in ('admin','super_admin')
  ) then
    raise exception 'Global administrator permission required';
  end if;

  if p_search is not null and length(btrim(p_search)) > 100 then
    raise exception 'Search must be 100 characters or fewer';
  end if;

  return query
  select pl.user_id, pl.full_name, u.email, pr.account_retention_status,
         pr.last_sign_in_at, pr.account_closed_at, pr.archive_expires_at,
         pr.retention_hold, pr.retention_hold_reason
  from public.profiles pr
  join public.players pl on pl.user_id = pr.id
  join auth.users u on u.id = pr.id
  where p_search is null
     or btrim(p_search) = ''
     or pl.full_name ilike '%' || btrim(p_search) || '%'
     or u.email ilike '%' || btrim(p_search) || '%'
  order by pr.retention_hold desc, pr.account_retention_status, pl.full_name
  limit 100;
end;
$$;

create or replace function public.admin_set_player_retention_hold(
  p_user_id uuid,
  p_hold boolean,
  p_reason text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_before jsonb;
  v_status text;
  v_previous_hold boolean;
begin
  if v_actor is null or not exists (
    select 1 from public.user_roles ur
    where ur.user_id = v_actor and ur.role in ('admin','super_admin')
  ) then
    raise exception 'Global administrator permission required';
  end if;
  if p_user_id is null then raise exception 'Select a player account'; end if;
  if p_hold is null then raise exception 'Choose whether to set or clear the retention hold'; end if;
  if p_reason is null or length(btrim(p_reason)) < 5 or length(btrim(p_reason)) > 500 then
    raise exception 'Enter an audit reason between 5 and 500 characters';
  end if;

  select pr.account_retention_status, pr.retention_hold
    into v_status, v_previous_hold
  from public.profiles pr
  join public.players pl on pl.user_id = pr.id
  where pr.id = p_user_id
  for update of pr, pl;

  if not found then raise exception 'Registered player account not found'; end if;
  if v_status = 'erasure_due' then
    raise exception 'The account has entered the final erasure process; a retention hold can no longer be applied safely';
  end if;
  if v_previous_hold = p_hold then
    raise exception case when p_hold then 'A retention hold is already active' else 'No retention hold is active' end;
  end if;

  v_before := jsonb_build_object(
    'retention_hold', v_previous_hold,
    'retention_hold_reason', (select pr.retention_hold_reason from public.profiles pr where pr.id = p_user_id),
    'account_retention_status', v_status
  );

  update public.profiles
  set retention_hold = p_hold,
      retention_hold_reason = case when p_hold then btrim(p_reason) else null end,
      updated_at = now()
  where id = p_user_id;

  insert into public.audit_log(
    actor_user_id, action, entity_type, entity_id, reason, before_data, after_data
  ) values (
    v_actor,
    case when p_hold then 'player.retention_hold.set' else 'player.retention_hold.cleared' end,
    'player_account',
    p_user_id::text,
    btrim(p_reason),
    v_before,
    jsonb_build_object(
      'retention_hold', p_hold,
      'retention_hold_reason', case when p_hold then btrim(p_reason) else null end,
      'account_retention_status', v_status
    )
  );

  return true;
end;
$$;

revoke all on function public.admin_list_player_retention_accounts(text) from public, anon;
grant execute on function public.admin_list_player_retention_accounts(text) to authenticated;
revoke all on function public.admin_set_player_retention_hold(uuid, boolean, text) from public, anon;
grant execute on function public.admin_set_player_retention_hold(uuid, boolean, text) to authenticated;

comment on function public.admin_set_player_retention_hold(uuid, boolean, text) is
  'Global-admin-only, reason-required and audited retention hold control. Holds can be set/cleared before the final erasure_due stage.';
