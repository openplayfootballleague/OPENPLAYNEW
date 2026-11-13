import { createFileRoute } from "@tanstack/react-router";
import { AuthenticatedSessionBoundary } from "../components/authenticated-session-boundary";
import { PlayerMatchesPage } from "../components/player-matches";

/** Player Hub / My Results (spec section 11, visual reference IMG_0573). */
export const Route = createFileRoute("/player_/results")({
  component: () => (
    <AuthenticatedSessionBoundary label="PLAYER HUB">
      <PlayerMatchesPage mode="results" />
    </AuthenticatedSessionBoundary>
  ),
});
