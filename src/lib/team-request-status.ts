export type TeamRequestStatus = {
  membership_id: string;
  season_team_id: string;
  season_id: string;
  team_name: string;
  season_name: string;
  team_registration_status: string;
  membership_status: string;
  is_captain: boolean;
  is_transfer_request: boolean;
  created_at: string;
};

export type TeamRequestDisplay = {
  label: string;
  description: string;
  tone: "success" | "pending" | "danger" | "neutral";
};

export function getTeamRequestDisplay(item: TeamRequestStatus): TeamRequestDisplay {
  if (item.is_transfer_request) {
    if (item.membership_status === "pending") {
      return { label: "Transfer awaiting approval", description: "Your request to move teams is waiting for an administrator decision.", tone: "pending" };
    }
    if (item.membership_status === "active") {
      return { label: "Transfer approved", description: "Your membership with this team is active.", tone: "success" };
    }
    if (item.membership_status === "rejected") {
      return { label: "Transfer declined", description: "Your transfer request was not approved.", tone: "danger" };
    }
  }

  if (item.team_registration_status === "pending") {
    return { label: "Team application pending", description: "Open Play is reviewing your team application. Captain access starts only after approval.", tone: "pending" };
  }
  if (item.team_registration_status === "rejected") {
    return { label: "Team application declined", description: "Your team application was not approved. Contact Open Play for the next steps.", tone: "danger" };
  }
  if (item.membership_status === "pending") {
    return { label: "Join request pending", description: "Your request is waiting for the team's captain to approve it.", tone: "pending" };
  }
  if (item.membership_status === "rejected") {
    return { label: "Join request declined", description: "The team did not approve your membership request.", tone: "danger" };
  }
  if (item.membership_status === "suspended") {
    return { label: "Membership suspended", description: "Your team membership is currently suspended. Contact Open Play for clarification.", tone: "danger" };
  }
  if (item.membership_status === "active" && item.is_captain) {
    return { label: "Captain access active", description: "Your team registration is approved and your captain access is active.", tone: "success" };
  }
  if (item.membership_status === "active") {
    return { label: "Team membership active", description: "You are an active member of this team.", tone: "success" };
  }
  return { label: "Previous team record", description: "This is a previous team request or membership record.", tone: "neutral" };
}
