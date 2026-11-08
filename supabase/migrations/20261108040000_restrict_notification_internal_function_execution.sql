-- Restrict notification dispatch internals to trusted server-side callers.
-- Trigger functions remain attached to their triggers; trigger invocation does not
-- require callers to hold EXECUTE on the trigger function.
revoke execute on function public.claim_notification_events(integer,text[]) from public, anon, authenticated;
revoke execute on function public.complete_notification_event(uuid,text) from public, anon, authenticated;
revoke execute on function public.dispatch_notification_worker() from public, anon, authenticated;
revoke execute on function public.enqueue_fixture_reminders() from public, anon, authenticated;
revoke execute on function public.enqueue_notification_event(uuid,text,jsonb) from public, anon, authenticated;
revoke execute on function public.fail_notification_event(uuid,text) from public, anon, authenticated;
revoke execute on function public.fail_notification_event_permanent(uuid,text) from public, anon, authenticated;
revoke execute on function public.mark_notification_event_unconfirmed(uuid,text) from public, anon, authenticated;
revoke execute on function public.mark_stale_notification_events_unconfirmed() from public, anon, authenticated;
revoke execute on function public.handle_new_auth_user() from public, anon, authenticated;
revoke execute on function public.notify_fixture_change() from public, anon, authenticated;
revoke execute on function public.notify_fixture_result_change() from public, anon, authenticated;
revoke execute on function public.notify_player_ban_change() from public, anon, authenticated;
revoke execute on function public.notify_team_membership_change() from public, anon, authenticated;
revoke execute on function public.notify_team_registration_change() from public, anon, authenticated;
