export type CompetitionFormat = "six_a_side" | "seven_a_side";

export type TeamSheetPlayer = {
  playerId: string;
  role: "starter" | "substitute";
  squadNumber?: number | null;
  isGoalkeeper?: boolean;
};

export type TeamSheetValidation = {
  valid: boolean;
  errors: string[];
  starterCount: number;
  substituteCount: number;
};

const TEAM_SHEET_LIMITS: Record<
  CompetitionFormat,
  { starters: number; substitutes: number }
> = {
  six_a_side: { starters: 6, substitutes: 3 },
  seven_a_side: { starters: 7, substitutes: 4 },
};

/**
 * Validates a submitted team sheet against the competition format.
 * Exactly one starter must be designated as goalkeeper. Squad numbers are
 * optional; when supplied they must be unique and 1–99. The server must also
 * verify that every player has an active membership of the submitting team.
 */
export function validateTeamSheet(
  format: CompetitionFormat,
  players: readonly TeamSheetPlayer[],
): TeamSheetValidation {
  const limits = TEAM_SHEET_LIMITS[format];
  const errors: string[] = [];
  const starters = players.filter((player) => player.role === "starter");
  const substitutes = players.filter((player) => player.role === "substitute");
  const goalkeepers = players.filter((player) => player.isGoalkeeper === true);

  if (starters.length !== limits.starters) {
    errors.push(
      `Select exactly ${limits.starters} starting players; ${starters.length} selected.`,
    );
  }

  if (substitutes.length > limits.substitutes) {
    errors.push(
      `Select no more than ${limits.substitutes} substitutes; ${substitutes.length} selected.`,
    );
  }

  if (goalkeepers.length !== 1) {
    errors.push("Select exactly one goalkeeper from the starting players.");
  } else if (goalkeepers.some((player) => player.role !== "starter")) {
    errors.push("The goalkeeper must be one of the starting players.");
  }

  const playerIds = players.map((player) => player.playerId);
  if (new Set(playerIds).size !== playerIds.length) {
    errors.push("A player can only appear once on a team sheet.");
  }

  const assignedNumbers = players
    .map((player) => player.squadNumber)
    .filter((number): number is number => number !== undefined && number !== null);

  if (assignedNumbers.some((number) => !Number.isInteger(number) || number < 1 || number > 99)) {
    errors.push("Squad numbers must be whole numbers from 1 to 99.");
  }

  if (new Set(assignedNumbers).size !== assignedNumbers.length) {
    errors.push("Squad numbers must be unique within the team sheet.");
  }

  return {
    valid: errors.length === 0,
    errors,
    starterCount: starters.length,
    substituteCount: substitutes.length,
  };
}

export function getTeamSheetLimits(format: CompetitionFormat) {
  return TEAM_SHEET_LIMITS[format];
}

export type FixtureStatus =
  | "scheduled"
  | "in_progress"
  | "completed"
  | "postponed"
  | "cancelled";

const FIXTURE_TRANSITIONS: Record<FixtureStatus, readonly FixtureStatus[]> = {
  scheduled: ["in_progress", "postponed", "cancelled"],
  in_progress: ["postponed", "cancelled"],
  completed: [],
  postponed: ["scheduled", "cancelled"],
  cancelled: [],
};

export function canTransitionFixtureStatus(
  current: FixtureStatus,
  next: FixtureStatus,
): boolean {
  return FIXTURE_TRANSITIONS[current].includes(next);
}

/** PostgreSQL stores fixture scores as non-negative SMALLINT values. */
export function isValidFixtureScore(score: number): boolean {
  return Number.isInteger(score) && score >= 0 && score <= 32767;
}

/** A scorer is selected once per goal; duplicate IDs are allowed for hat-tricks. */
export function hasOneScorerPerGoal(score: number, scorerIds: readonly string[]): boolean {
  return isValidFixtureScore(score) &&
    scorerIds.length === score &&
    scorerIds.every((id) => typeof id === "string" && id.trim().length > 0);
}
