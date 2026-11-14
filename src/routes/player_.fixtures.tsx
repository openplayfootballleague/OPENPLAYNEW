import { createFileRoute } from "@tanstack/react-router";
import { AuthenticatedSessionBoundary } from "../components/authenticated-session-boundary";
import { PlayerMatchesPage } from "../components/player-matches";

/** Player Hub / My Fixtures (spec section 12, visual reference IMG_0572). */
export const Route = createFileRoute("/player_/fixtures")({
  component: () => (
    <AuthenticatedSessionBoundary label="PLAYER HUB">
      <PlayerMatchesPage mode="fixtures" />
    </AuthenticatedSessionBoundary>
  ),
});
