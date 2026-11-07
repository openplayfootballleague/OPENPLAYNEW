-- Keep goal-correction history referentially intact; a deleted admin
-- account must not null the actor on a voided goal row.
alter table public.fixture_goal_records
  drop constraint if exists fixture_goal_records_voided_by_fkey;
alter table public.fixture_goal_records
  add constraint fixture_goal_records_voided_by_fkey
  foreign key (voided_by) references auth.users(id) on delete restrict;
