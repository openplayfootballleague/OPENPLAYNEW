/**
 * Goal event rules (Blueprint 11.2): assists and own goals. Mirrors the server-side
 * validation in `admin_record_fixture_goal_events`, which remains authoritative.
 */

export type TeamSide = "home" | "away";

export type SheetPlayer = { competition_player_id: string; full_name: string; did_appear: boolean };

export type GoalEvent = {
  /** Team credited with the goal. */
  teamSide: TeamSide;
  scorerId: string;
  isOwnGoal: boolean;
  assistId: string | null;
};

export type FixtureSheets = { home: SheetPlayer[]; away: SheetPlayer[] };

const other = (side: TeamSide): TeamSide => (side === "home" ? "away" : "home");
const appeared = (players: SheetPlayer[]) => players.filter((player) => player.did_appear);

/** A normal goal is scored by the credited team; an own goal by the opponent. */
export function eligibleScorers(sheets: FixtureSheets, teamSide: TeamSide, isOwnGoal: boolean): SheetPlayer[] {
  return appeared(sheets[isOwnGoal ? other(teamSide) : teamSide]);
}

/** Assists come from the credited team, never on an own goal, never by the scorer. */
export function eligibleAssisters(sheets: FixtureSheets, event: Pick<GoalEvent, "teamSide" | "isOwnGoal" | "scorerId">): SheetPlayer[] {
  if (event.isOwnGoal) return [];
  return appeared(sheets[event.teamSide]).filter((player) => player.competition_player_id !== event.scorerId);
}

export function validateGoalEvents(events: GoalEvent[], sheets: FixtureSheets, score: { home: number; away: number }): string[] {
  const errors: string[] = [];
  for (const side of ["home", "away"] as const) {
    const count = events.filter((event) => event.teamSide === side).length;
    if (count > score[side]) errors.push(`${side === "home" ? "Home" : "Away"} goal events (${count}) exceed the ${side} score (${score[side]}).`);
  }
  events.forEach((event, index) => {
    const label = `Goal ${index + 1}`;
    if (!event.scorerId) {
      errors.push(`${label}: choose the scorer.`);
      return;
    }
    if (!eligibleScorers(sheets, event.teamSide, event.isOwnGoal).some((p) => p.competition_player_id === event.scorerId)) {
      errors.push(`${label}: the scorer must have appeared for the ${event.isOwnGoal ? "opposing" : "credited"} team.`);
    }
    if (event.assistId) {
      if (event.isOwnGoal) errors.push(`${label}: an own goal cannot have an assist.`);
      else if (!eligibleAssisters(sheets, event).some((p) => p.competition_player_id === event.assistId)) {
        errors.push(`${label}: the assist must be by a different player who appeared for the credited team.`);
      }
    }
  });
  return errors;
}

/** Wire format for `admin_record_fixture_goal_events`. */
export function toGoalEventPayload(events: GoalEvent[]) {
  return events.map((event) => ({
    team_side: event.teamSide,
    scorer_competition_player_id: event.scorerId,
    is_own_goal: event.isOwnGoal,
    assist_competition_player_id: event.isOwnGoal ? null : event.assistId,
  }));
}
