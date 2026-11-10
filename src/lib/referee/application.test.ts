import { describe, expect, it } from "vitest";
import {
  normalizeRefereeApplicationDraft,
  validateRefereeApplication,
  type RefereeApplicationDraft,
  type RefereeApplicantEligibility,
} from "./application";

const eligible: RefereeApplicantEligibility = {
  accountStatus: "active",
  registrationStatus: "registered",
  isBanned: false,
};

const validDraft: RefereeApplicationDraft = {
  experienceSummary: "I have refereed local grassroots football for two seasons.",
  qualifications: ["FA Referee Course"],
  availability: [
    { weekday: 5, startTime: "18:00", endTime: "22:00" },
    { weekday: 7, startTime: "09:00", endTime: "13:00" },
  ],
  contactPhone: "+447700900123",
  preferredLocationIds: ["location-barnstaple"],
  additionalNotes: "",
};

describe("referee application validation contract", () => {
  it("accepts an eligible registered applicant with complete details", () => {
    expect(validateRefereeApplication(validDraft, eligible)).toEqual([]);
  });

  it("allows applicants without formal qualifications", () => {
    expect(validateRefereeApplication(
      { ...validDraft, qualifications: [] },
      eligible,
    )).toEqual([]);
  });

  it("requires active account, approved player registration and no ban", () => {
    const issues = validateRefereeApplication(validDraft, {
      accountStatus: "closed",
      registrationStatus: "pending_review",
      isBanned: true,
    });
    expect(issues.map((issue) => issue.code)).toEqual([
      "account_not_active",
      "player_not_registered",
      "player_banned",
    ]);
  });

  it("requires experience, contact, availability and a preferred location", () => {
    const issues = validateRefereeApplication({
      ...validDraft,
      experienceSummary: " ",
      contactPhone: "",
      availability: [],
      preferredLocationIds: [],
    }, eligible);
    expect(issues.map((issue) => issue.code)).toEqual([
      "experience_required",
      "phone_required",
      "availability_required",
      "location_required",
    ]);
  });

  it("rejects invalid availability windows and duplicate locations", () => {
    const issues = validateRefereeApplication({
      ...validDraft,
      availability: [{ weekday: 8, startTime: "22:00", endTime: "18:00" }],
      preferredLocationIds: ["location-barnstaple", "location-barnstaple"],
    }, eligible);
    expect(issues.map((issue) => issue.code)).toEqual([
      "availability_invalid",
      "location_invalid",
    ]);
  });

  it("normalizes text and removes duplicate qualifications and location IDs", () => {
    expect(normalizeRefereeApplicationDraft({
      ...validDraft,
      experienceSummary: "  Grassroots experience  ",
      qualifications: [" FA Level 1 ", "", "FA Level 1"],
      preferredLocationIds: [" location-a ", "location-a", "location-b"],
      additionalNotes: "  Evening availability preferred  ",
    })).toMatchObject({
      experienceSummary: "Grassroots experience",
      qualifications: ["FA Level 1"],
      preferredLocationIds: ["location-a", "location-b"],
      additionalNotes: "Evening availability preferred",
    });
  });
});
