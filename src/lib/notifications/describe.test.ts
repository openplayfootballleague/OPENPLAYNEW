import { describe, expect, it } from "vitest";
import { describeNotification } from "./describe";

describe("notification descriptions", () => {
  it("formats fixture results with team names and score", () => {
    expect(describeNotification("fixture.result_published", { home_team_name: "Abbotsham", away_team_name: "Instow", home_score: 3, away_score: 1 }).body)
      .toBe("Result: Abbotsham 3–1 Instow.");
  });

  it("falls back safely for missing payload fields and unknown events", () => {
    expect(describeNotification("team.membership_removed", null).body).toBe(
      "Your membership with the team has been ended by an administrator. Reason: Contact Open Play for details.",
    );
    expect(describeNotification("something.new", {}).body).toBe("You have a new Open Play update.");
  });

  it("separates message alerts from league notifications for the Inbox", () => {
    expect(describeNotification("message.new", {}).category).toBe("message");
    expect(describeNotification("fixture.scheduled", {}).category).toBe("league");
    expect(describeNotification("fixture.reminder_24h", {}).title).toBe("fixture reminder 24h");
  });
});
