import { Link } from "@tanstack/react-router";
import { CalendarDays, ShieldPlus, User } from "lucide-react";
import { PlayerBottomNavigation } from "./player-bottom-navigation";

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
          <h3><User aria-hidden="true" />I WANT TO PLAY</h3>
          <p>Register as a player and find a team to play for.</p>
          <Link to="/sign-up">START PLAYER REGISTRATION <span aria-hidden="true">→</span></Link>
        </article>
        <article className="join-landing-path">
          <h3><ShieldPlus aria-hidden="true" />I WANT TO CREATE A TEAM</h3>
          <p>Become a captain and bring your own team together.</p>
          <span className="join-landing-requirement">Player registration required first</span>
          <Link to="/sign-up">START PLAYER REGISTRATION <span aria-hidden="true">→</span></Link>
        </article>
        <article className="join-landing-path">
          <h3><CalendarDays aria-hidden="true" />EXPLORE OUR LEAGUES</h3>
          <p>Discover active competitions and upcoming league launches.</p>
          <Link to="/leagues">VIEW LEAGUES <span aria-hidden="true">→</span></Link>
        </article>
      </div>
      <p className="join-landing-signin">Already registered? <Link to="/sign-in">Sign in to your account.</Link></p>
      <PlayerBottomNavigation />
    </main>
  );
}
