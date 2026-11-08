export type TeamFormat = 6 | 7;

export type InitialSquadMember = {
  playerId: string;
  registrationStatus: "registered" | "pending_review" | "rejected";
  isBanned: boolean;
  isStarter: boolean;
  isCaptain: boolean;
};

export type InitialSquadValidation =
  | { valid: true; starters: number; substitutes: number }
  | { valid: false; errors: string[] };

/**
 * Validates a proposed season squad before it is sent to the atomic
 * registration RPC. This is client-side feedback only; the database must
 * repeat every eligibility, identity, uniqueness and capacity check.
 */
export function validateInitialSquad(
  format: TeamFormat,
  applicantUserId: string,
  members: readonly InitialSquadMember[],
): InitialSquadValidation {
  const errors: string[] = [];
  const requiredStarters = format;
  const maximumSubstitutes = format === 6 ? 3 : 4;
  const maximumSquad = requiredStarters + maximumSubstitutes;

  const applicantId = applicantUserId.trim().toLowerCase();
  if (!applicantId) errors.push("The applicant identity is missing.");
  if (members.length > maximumSquad) {
    errors.push(`A ${format}-a-side squad can contain no more than ${maximumSquad} players.`);
  }

  const ids = members.map((member) => member.playerId.trim().toLowerCase());
  if (ids.some((id) => !id)) errors.push("Every squad member must have a player identity.");
  if (new Set(ids).size !== ids.length) errors.push("A player can only appear once in the initial squad.");

  const starters = members.filter((member) => member.isStarter).length;
  const substitutes = members.length - starters;
  if (starters !== requiredStarters) {
    errors.push(`A ${format}-a-side squad must name exactly ${requiredStarters} starters.`);
  }
  if (substitutes > maximumSubstitutes) {
    errors.push(`A ${format}-a-side squad can name no more than ${maximumSubstitutes} substitutes.`);
  }

  const captains = members.filter((member) => member.isCaptain);
  if (captains.length !== 1) {
    errors.push("The initial squad must identify exactly one captain.");
  } else if (captains[0].playerId.trim().toLowerCase() !== applicantId) {
    errors.push("The team applicant must be the nominated captain.");
  }

  if (members.some((member) => member.registrationStatus !== "registered")) {
    errors.push("Every initial squad member must have an approved player registration.");
  }
  if (members.some((member) => member.isBanned)) {
    errors.push("A banned player cannot be included in an initial squad.");
  }

  return errors.length
    ? { valid: false, errors }
    : { valid: true, starters, substitutes };
}
