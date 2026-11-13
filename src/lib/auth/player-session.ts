export type PlayerSessionTransition = "same-user" | "user-changed" | "signed-out";

/** Classify auth changes so cached Player Hub data is never reused across accounts. */
export function getPlayerSessionTransition(
  previousUserId: string | null | undefined,
  nextUserId: string | null,
): PlayerSessionTransition {
  if (previousUserId === nextUserId) return "same-user";
  return nextUserId === null ? "signed-out" : "user-changed";
}
