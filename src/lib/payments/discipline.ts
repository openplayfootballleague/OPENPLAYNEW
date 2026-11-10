export type DisciplinaryRecipientCategory =
  | "registered_player"
  | "substitute_bench"
  | "supporter";

export type DisciplinaryCardOutcome =
  | "yellow"
  | "second_yellow_red"
  | "straight_red";

export const DISCIPLINARY_FINE_PENCE: Record<DisciplinaryCardOutcome, number> = {
  yellow: 500,
  second_yellow_red: 1_500,
  straight_red: 3_000,
};

export type DisciplinaryIncidentAssessment = {
  teamChargePence: number;
  individualStrikeIncrement: 0 | 1;
  strikesAfterIncident: number | null;
  playerSuspensionPendingAdmin: boolean;
  requiresPlayerIdentity: boolean;
};

export function assessDisciplinaryIncident(input: {
  recipientCategory: DisciplinaryRecipientCategory;
  cardOutcome: DisciplinaryCardOutcome;
  playerCompetitionIdentityId?: string | null;
  currentIndividualStrikes?: number;
}): DisciplinaryIncidentAssessment {
  const identity = input.playerCompetitionIdentityId?.trim() || null;
  const currentStrikes = input.currentIndividualStrikes ?? 0;
  if (!Number.isSafeInteger(currentStrikes) || currentStrikes < 0) {
    throw new RangeError("Current disciplinary strikes must be a non-negative integer.");
  }
  if (input.recipientCategory === "registered_player" && !identity) {
    throw new RangeError("A registered-player incident requires a permanent player identity.");
  }
  if (input.recipientCategory === "supporter" && identity) {
    throw new RangeError("A supporter incident must not be assigned a player identity.");
  }

  const individualStrikeIncrement: 0 | 1 =
    input.cardOutcome === "straight_red" && identity ? 1 : 0;
  const strikesAfterIncident = identity ? currentStrikes + individualStrikeIncrement : null;
  return {
    teamChargePence: DISCIPLINARY_FINE_PENCE[input.cardOutcome],
    individualStrikeIncrement,
    strikesAfterIncident,
    playerSuspensionPendingAdmin: individualStrikeIncrement === 1 && (strikesAfterIncident ?? 0) >= 3,
    requiresPlayerIdentity: input.recipientCategory === "registered_player",
  };
}

/** Fine waivers/adjustments require an authorised administrator and an auditable reason. */
export function calculateDisciplinaryFineAdjustment(input: {
  originalFinePence: number;
  adjustedFinePence: number;
  administratorAuthorised: boolean;
  reason: string;
}): { originalFinePence: number; adjustedFinePence: number; adjustmentPence: number; reason: string } {
  const { originalFinePence, adjustedFinePence } = input;
  if (!Number.isSafeInteger(originalFinePence) || originalFinePence < 0 ||
    !Number.isSafeInteger(adjustedFinePence) || adjustedFinePence < 0 ||
    adjustedFinePence > originalFinePence) {
    throw new RangeError("Fine adjustment must be a valid non-negative reduction in integer pence.");
  }
  const reason = input.reason.trim();
  if (!input.administratorAuthorised) throw new Error("Only an authorised administrator may adjust a fine.");
  if (!reason) throw new RangeError("A reason is required for every fine adjustment.");
  return {
    originalFinePence,
    adjustedFinePence,
    adjustmentPence: originalFinePence - adjustedFinePence,
    reason,
  };
}
