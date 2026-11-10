import { describe, expect, it } from "vitest";
import {
  assessDisciplinaryIncident,
  calculateDisciplinaryFineAdjustment,
  DISCIPLINARY_FINE_PENCE,
} from "./discipline";

describe("fixed Open Play disciplinary fines", () => {
  it("uses the confirmed fixed fine amounts in pence", () => {
    expect(DISCIPLINARY_FINE_PENCE).toEqual({
      yellow: 500,
      second_yellow_red: 1500,
      straight_red: 3000,
    });
  });

  it("charges £15 total for second yellow followed by red, not £20", () => {
    expect(assessDisciplinaryIncident({
      recipientCategory: "registered_player",
      cardOutcome: "second_yellow_red",
      playerCompetitionIdentityId: "competition-player-1",
    })).toMatchObject({ teamChargePence: 1500, individualStrikeIncrement: 0 });
  });

  it("adds one strike for a straight red to an identifiable registered player", () => {
    expect(assessDisciplinaryIncident({
      recipientCategory: "registered_player",
      cardOutcome: "straight_red",
      playerCompetitionIdentityId: "competition-player-1",
      currentIndividualStrikes: 1,
    })).toMatchObject({
      teamChargePence: 3000,
      individualStrikeIncrement: 1,
      strikesAfterIncident: 2,
      playerSuspensionPendingAdmin: false,
    });
  });

  it("flags the third registered-player straight red for admin approval before return", () => {
    expect(assessDisciplinaryIncident({
      recipientCategory: "registered_player",
      cardOutcome: "straight_red",
      playerCompetitionIdentityId: "competition-player-1",
      currentIndividualStrikes: 2,
    })).toMatchObject({
      individualStrikeIncrement: 1,
      strikesAfterIncident: 3,
      playerSuspensionPendingAdmin: true,
    });
  });

  it("does not invent an individual strike for an unidentified supporter", () => {
    expect(assessDisciplinaryIncident({
      recipientCategory: "supporter",
      cardOutcome: "straight_red",
    })).toMatchObject({
      teamChargePence: 3000,
      individualStrikeIncrement: 0,
      strikesAfterIncident: null,
      playerSuspensionPendingAdmin: false,
    });
  });

  it("allows an identifiable registered substitute to receive a personal strike", () => {
    expect(assessDisciplinaryIncident({
      recipientCategory: "substitute_bench",
      cardOutcome: "straight_red",
      playerCompetitionIdentityId: "competition-player-sub",
    })).toMatchObject({ individualStrikeIncrement: 1, strikesAfterIncident: 1 });
  });

  it("requires an identity for registered-player incidents and forbids supporter identity", () => {
    expect(() => assessDisciplinaryIncident({
      recipientCategory: "registered_player",
      cardOutcome: "yellow",
    })).toThrow(RangeError);
    expect(() => assessDisciplinaryIncident({
      recipientCategory: "supporter",
      cardOutcome: "yellow",
      playerCompetitionIdentityId: "must-not-be-assigned",
    })).toThrow(RangeError);
  });

  it("rejects invalid strike counts", () => {
    expect(() => assessDisciplinaryIncident({
      recipientCategory: "registered_player",
      cardOutcome: "yellow",
      playerCompetitionIdentityId: "competition-player-1",
      currentIndividualStrikes: -1,
    })).toThrow(RangeError);
  });
});

describe("audited fine adjustments", () => {
  it("requires an authorised administrator and a reason", () => {
    expect(calculateDisciplinaryFineAdjustment({
      originalFinePence: 3000,
      adjustedFinePence: 1000,
      administratorAuthorised: true,
      reason: "Evidence reviewed",
    })).toEqual({
      originalFinePence: 3000,
      adjustedFinePence: 1000,
      adjustmentPence: 2000,
      reason: "Evidence reviewed",
    });
    expect(() => calculateDisciplinaryFineAdjustment({
      originalFinePence: 3000,
      adjustedFinePence: 1000,
      administratorAuthorised: false,
      reason: "Evidence reviewed",
    })).toThrow();
    expect(() => calculateDisciplinaryFineAdjustment({
      originalFinePence: 3000,
      adjustedFinePence: 1000,
      administratorAuthorised: true,
      reason: " ",
    })).toThrow(RangeError);
  });

  it("does not allow a fine increase through an adjustment", () => {
    expect(() => calculateDisciplinaryFineAdjustment({
      originalFinePence: 500,
      adjustedFinePence: 1000,
      administratorAuthorised: true,
      reason: "Correction",
    })).toThrow(RangeError);
  });
});
