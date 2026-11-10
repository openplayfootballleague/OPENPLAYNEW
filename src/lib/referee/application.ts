export type RefereeApplicationAvailability = {
  /** Monday = 1 ... Sunday = 7 (ISO weekday numbering). */
  weekday: number;
  startTime: string;
  endTime: string;
};

export type RefereeApplicationDraft = {
  experienceSummary: string;
  qualifications: string[];
  availability: RefereeApplicationAvailability[];
  contactPhone: string;
  preferredLocationIds: string[];
  additionalNotes?: string;
};

export type RefereeApplicantEligibility = {
  accountStatus: "active" | "inactive" | "closed";
  registrationStatus: "registered" | "pending_review" | "rejected" | "unregistered";
  isBanned: boolean;
};

export type RefereeApplicationIssue = {
  field: keyof RefereeApplicationDraft | "eligibility";
  code:
    | "account_not_active"
    | "player_not_registered"
    | "player_banned"
    | "experience_required"
    | "phone_required"
    | "availability_required"
    | "availability_invalid"
    | "location_required"
    | "location_invalid"
    | "notes_too_long";
  message: string;
};

const TIME_PATTERN = /^(?:[01]\d|2[0-3]):[0-5]\d$/;

/**
 * Validates the application payload and the server-resolved account state.
 * Qualifications are intentionally optional: applicants without formal
 * qualifications must still be able to apply and describe their experience.
 * This is domain validation only; the database must repeat these checks and
 * enforce one active application per user with RLS/RPC constraints.
 */
export function validateRefereeApplication(
  draft: RefereeApplicationDraft,
  eligibility: RefereeApplicantEligibility,
): RefereeApplicationIssue[] {
  const issues: RefereeApplicationIssue[] = [];

  if (eligibility.accountStatus !== "active") {
    issues.push({
      field: "eligibility",
      code: "account_not_active",
      message: "Your Open Play account must be active to apply.",
    });
  }
  if (eligibility.registrationStatus !== "registered") {
    issues.push({
      field: "eligibility",
      code: "player_not_registered",
      message: "You must have an approved player registration to apply.",
    });
  }
  if (eligibility.isBanned) {
    issues.push({
      field: "eligibility",
      code: "player_banned",
      message: "An account restriction prevents this application.",
    });
  }

  if (!draft.experienceSummary.trim()) {
    issues.push({
      field: "experienceSummary",
      code: "experience_required",
      message: "Describe your refereeing or relevant football experience.",
    });
  }
  if (!draft.contactPhone.trim()) {
    issues.push({
      field: "contactPhone",
      code: "phone_required",
      message: "Provide a contact telephone number.",
    });
  }
  if (draft.availability.length === 0) {
    issues.push({
      field: "availability",
      code: "availability_required",
      message: "Add at least one regular availability window.",
    });
  } else if (
    draft.availability.some((slot) =>
      !Number.isInteger(slot.weekday) ||
      slot.weekday < 1 ||
      slot.weekday > 7 ||
      !TIME_PATTERN.test(slot.startTime) ||
      !TIME_PATTERN.test(slot.endTime) ||
      slot.startTime >= slot.endTime
    )
  ) {
    issues.push({
      field: "availability",
      code: "availability_invalid",
      message: "Availability must use valid weekdays and a start time before the end time.",
    });
  }
  if (draft.preferredLocationIds.length === 0) {
    issues.push({
      field: "preferredLocationIds",
      code: "location_required",
      message: "Choose at least one preferred Open Play location.",
    });
  } else if (
    draft.preferredLocationIds.some((id) => !id.trim()) ||
    new Set(draft.preferredLocationIds).size !== draft.preferredLocationIds.length
  ) {
    issues.push({
      field: "preferredLocationIds",
      code: "location_invalid",
      message: "Preferred locations must be valid and must not be duplicated.",
    });
  }
  if ((draft.additionalNotes ?? "").length > 2000) {
    issues.push({
      field: "additionalNotes",
      code: "notes_too_long",
      message: "Additional notes must be 2,000 characters or fewer.",
    });
  }

  return issues;
}

export function normalizeRefereeApplicationDraft(
  draft: RefereeApplicationDraft,
): RefereeApplicationDraft {
  return {
    experienceSummary: draft.experienceSummary.trim(),
    qualifications: [...new Set(draft.qualifications.map((value) => value.trim()).filter(Boolean))],
    availability: draft.availability.map((slot) => ({
      weekday: slot.weekday,
      startTime: slot.startTime,
      endTime: slot.endTime,
    })),
    contactPhone: draft.contactPhone.trim(),
    preferredLocationIds: [...new Set(draft.preferredLocationIds.map((id) => id.trim()).filter(Boolean))],
    additionalNotes: draft.additionalNotes?.trim() || undefined,
  };
}
