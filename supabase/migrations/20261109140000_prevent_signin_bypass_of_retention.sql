-- A successful Auth sign-in timestamp must never reopen a closed or
-- erasure_due account. Only the single-use, verified reactivation flow may
-- move a closed account back to active.
create or replace function public.track_player_account_sign_in()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.last_sign_in_at is distinct from old.last_sign_in_at
     and new.last_sign_in_at is not null then
    update public.profiles
    set last_sign_in_at = new.last_sign_in_at,
        updated_at = now()
    where id = new.id
      and account_retention_status = 'active';
  end if;
  return new;
end;
$$;

revoke all on function public.track_player_account_sign_in() from public, anon, authenticated;
