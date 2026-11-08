create policy fixture_goal_records_no_direct_client_access
on public.fixture_goal_records
for all
to anon,authenticated
using(false)
with check(false);