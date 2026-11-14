import { createFileRoute } from "@tanstack/react-router";
import { AuthenticatedSessionBoundary } from "../components/authenticated-session-boundary";
import { PlayerProfilePage } from "../components/player-profile";

/** Player Hub / My Profile (spec section 6, visual reference IMG_0575). */
export const Route = createFileRoute("/player_/profile")({
  component: () => (
    <AuthenticatedSessionBoundary label="PLAYER HUB">
      <PlayerProfilePage />
    </AuthenticatedSessionBoundary>
  ),
});
