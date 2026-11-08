export type AccountPlayerState = {
  registration_status: string | null | undefined;
  is_banned: boolean | null | undefined;
};

export type AccountAccess = {
  approvedPlayer: boolean;
  captain: boolean;
  admin: boolean;
  finance: boolean;
};

/**
 * Derives presentation-only account capabilities from authoritative records.
 * Database RLS/RPC checks remain the security boundary for protected actions.
 */
export function deriveAccountAccess(
  player: AccountPlayerState | null,
  hasActiveCaptainMembership: boolean,
  roles: readonly string[],
): AccountAccess {
  const approvedPlayer =
    player?.registration_status === "registered" && player.is_banned !== true;

  return {
    approvedPlayer,
    captain: approvedPlayer && hasActiveCaptainMembership,
    admin: roles.some((role) =>
      ["admin", "super_admin", "league_admin"].includes(role),
    ),
    finance: roles.some((role) =>
      ["admin", "super_admin", "finance_admin"].includes(role),
    ),
  };
}
