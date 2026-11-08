-- Development/security regression assertions. Run after applying migrations.
do $$
begin
  if exists (
    select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relkind='r' and not c.relrowsecurity
  ) then
    raise exception 'A public application table has row-level security disabled';
  end if;

  if exists (
    select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relkind='r'
      and (
        has_table_privilege('anon',c.oid,'TRUNCATE')
        or has_table_privilege('authenticated',c.oid,'TRUNCATE')
        or has_table_privilege('anon',c.oid,'REFERENCES')
        or has_table_privilege('authenticated',c.oid,'REFERENCES')
        or has_table_privilege('anon',c.oid,'TRIGGER')
        or has_table_privilege('authenticated',c.oid,'TRIGGER')
      )
  ) then
    raise exception 'anon/authenticated retains a table-level privilege that bypasses RLS';
  end if;

  if exists (
    select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.prosecdef
      and has_function_privilege('anon',p.oid,'EXECUTE')
  ) then
    raise exception 'anon can execute a public SECURITY DEFINER function';
  end if;

  if exists (
    select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.prosecdef
      and p.proname in (
        'claim_notification_events','complete_notification_event',
        'dispatch_notification_worker','enqueue_fixture_reminders',
        'enqueue_notification_event','fail_notification_event',
        'fail_notification_event_permanent','mark_notification_event_unconfirmed',
        'mark_stale_notification_events_unconfirmed','handle_new_auth_user',
        'notify_fixture_change','notify_fixture_result_change',
        'notify_player_ban_change','notify_team_membership_change',
        'notify_team_registration_change'
      )
      and has_function_privilege('authenticated',p.oid,'EXECUTE')
  ) then
    raise exception 'authenticated can execute an internal notification function';
  end if;
end $$;
select 'security privilege assertions passed' as result;
