import type { AnalyticsActor } from "./events";

/**
 * Resolve the analytics actor without allowing an account-service failure to
 * escape into the application. An unavailable identity is never treated as
 * anonymous or as a player.
 */
export async function resolveAnalyticsActorSafely(
  configured: boolean,
  resolve: () => Promise<AnalyticsActor>,
): Promise<AnalyticsActor> {
  if (!configured) return "unknown";

  try {
    return await resolve();
  } catch {
    return "unknown";
  }
}
