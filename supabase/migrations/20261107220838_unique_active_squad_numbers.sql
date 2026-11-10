-- Squad numbers are optional, but active players in the same season team
-- cannot share a number. NULL remains available to players without a number.
create unique index if not exists team_memberships_unique_active_squad_number_idx
on public.team_memberships(season_team_id,squad_number)
where status='active' and squad_number is not null;
