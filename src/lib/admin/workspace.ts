export interface AdminWorkspaceLeague {
  id: string;
  location_id: string;
}

export interface AdminWorkspaceSeason {
  id: string;
  league_id: string;
}

export interface AdminWorkspaceSeasonTeam {
  season_id: string;
}

export interface AdminWorkspaceInput<
  TLeague extends AdminWorkspaceLeague,
  TSeason extends AdminWorkspaceSeason,
  TSeasonTeam extends AdminWorkspaceSeasonTeam,
> {
  leagues: readonly TLeague[];
  seasons: readonly TSeason[];
  seasonTeams: readonly TSeasonTeam[];
}

export function resolveAdminWorkspace<
  TLeague extends AdminWorkspaceLeague,
  TSeason extends AdminWorkspaceSeason,
  TSeasonTeam extends AdminWorkspaceSeasonTeam,
>(
  setup: AdminWorkspaceInput<TLeague, TSeason, TSeasonTeam>,
  locationId: string,
  seasonId: string,
) {
  const workspaceLeagues = setup.leagues.filter(
    (league) => locationId === "all" || league.location_id === locationId,
  );
  const workspaceLeagueIds = new Set(workspaceLeagues.map((league) => league.id));
  const workspaceSeasons = setup.seasons.filter((season) =>
    workspaceLeagueIds.has(season.league_id),
  );
  const workspaceSeasonIds = new Set(
    workspaceSeasons
      .filter((season) => seasonId === "all" || season.id === seasonId)
      .map((season) => season.id),
  );
  const workspaceTeams = setup.seasonTeams.filter((team) =>
    workspaceSeasonIds.has(team.season_id),
  );

  return { workspaceLeagues, workspaceSeasons, workspaceTeams };
}
