import { Link } from "@tanstack/react-router";
import { PlayerBottomNavigation } from "./player-bottom-navigation";

const iconProps = { viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", strokeWidth: 1.8, strokeLinecap: "round" as const, strokeLinejoin: "round" as const, "aria-hidden": true };

/**
 * Public Join Open Play page for signed-out visitors (reference IMG_0581).
 * Every pathway starts with an account and Phase 1 player registration; creating a team
 * is never offered as a way around player registration (accounts-roles-and-workflows spec).
 */
export function PublicJoinLanding() {
  return (
    <main className="notice-page player-facing join-landing">
      <section className="join-landing-hero" aria-labelledby="join-landing-heading">
        <span className="join-landing-kicker">YOUR NEXT CHAPTER STARTS HERE</span>
        <h1 id="join-landing-heading">JOIN THE GAME.<span>JOIN OPEN PLAY.</span></h1>
        <p>Whether you want to play, start a team or discover a new league, there's a place for you.</p>
        <Link className="join-landing-primary" to="/sign-up">REGISTER NOW</Link>
        <p className="join-landing-note">Every new member starts by creating a player account.</p>
      </section>

      <h2 className="join-landing-section">HOW WOULD YOU LIKE TO GET INVOLVED?</h2>
      <div className="join-landing-paths">
        <article className="join-landing-path">
          <h3><svg {...iconProps}><circle cx="12" cy="8" r="4" /><path d="M4 21v-1a8 8 0 0 1 16 0v1" /></svg>I WANT TO PLAY</h3>
          <p>Register as a player and find a team to play for.</p>
          <Link to="/sign-up">START PLAYER REGISTRATION <span aria-hidden="true">→</span></Link>
        </article>
        <article className="join-landing-path">
          <h3><svg {...iconProps}><path d="M12 3 4 6v6c0 5 3.5 8 8 9 4.5-1 8-4 8-9V6l-8-3Z" /><path d="M12 9v6M9 12h6" /></svg>I WANT TO CREATE A TEAM</h3>
          <p>Become a captain and bring your own team together.</p>
          <span className="join-landing-requirement">Player registration required first</span>
          <Link to="/sign-up">START PLAYER REGISTRATION <span aria-hidden="true">→</span></Link>
        </article>
        <article className="join-landing-path">
          <h3><svg {...iconProps}><rect x="3" y="5" width="18" height="16" rx="2" /><path d="M3 10h18M8 3v4M16 3v4M8 14h.01M12 14h.01M16 14h.01M8 17h.01M12 17h.01" /></svg>EXPLORE OUR LEAGUES</h3>
          <p>Discover active competitions and upcoming league launches.</p>
          <Link to="/leagues">VIEW LEAGUES <span aria-hidden="true">→</span></Link>
        </article>
      </div>
      <p className="join-landing-signin">Already registered? <Link to="/sign-in">Sign in to your account.</Link></p>
      <PlayerBottomNavigation />
    </main>
  );
}
