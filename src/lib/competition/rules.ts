export type CompetitionFormat = "six_a_side" | "seven_a_side";

export type TeamSheetPlayer = {
  playerId: string;
  role: "starter" | "substitute";
  squadNumber?: number | null;
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
 * Squad numbers are optional; when supplied they must be unique and 1–99.
 * This is shared domain validation only. The server must also verify that
 * every player has an active membership of the submitting season team.
 */
export function validateTeamSheet(
  format: CompetitionFormat,
  players: readonly TeamSheetPlayer[],
): TeamSheetValidation {
  const limits = TEAM_SHEET_LIMITS[format];
  const errors: string[] = [];
  const starters = players.filter((player) => player.role === "starter");
  const substitutes = players.filter((player) => player.role === "substitute");

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
