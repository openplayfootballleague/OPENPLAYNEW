import { Link, createFileRoute } from "@tanstack/react-router";
import { PlayerBottomNavigation } from "../components/player-bottom-navigation";

export const Route = createFileRoute("/more")({ component: MorePage });

function MorePage() {
  return (
    <main className="notice-page player-facing">
      <section className="notice-panel hub-panel">
        <Link className="notice-brand" to="/player">
          <img className="open-play-logo" src="/open-play-logo.png" alt="Open Play" />
        </Link>
        <p className="eyebrow eyebrow-dark">OPEN PLAY</p>
        <h1>More<br /><em>to explore.</em></h1>
        <p>Everything else you need to follow your league and manage your Open Play account.</p>
        <section className="hub-memberships">
          <div className="hub-section-heading"><span className="hub-kicker">EXPLORE</span></div>
          <Link className="admin-inline-action" to="/teams">TEAMS &amp; LEAGUES <span aria-hidden="true">↗</span></Link>
          <Link className="admin-inline-action" to="/gallery">MATCHDAY GALLERY <span aria-hidden="true">↗</span></Link>
          <Link className="admin-inline-action" to="/match-centre">FIXTURES, RESULTS &amp; TABLES <span aria-hidden="true">↗</span></Link>
        </section>
        <section className="hub-memberships">
          <div className="hub-section-heading"><span className="hub-kicker">YOUR OPEN PLAY</span></div>
          <Link className="admin-inline-action" to="/player">PLAYER HUB <span aria-hidden="true">↗</span></Link>
          <Link className="admin-inline-action" to="/captain">CAPTAIN HUB <span aria-hidden="true">↗</span></Link>
          <Link className="admin-inline-action" to="/admin">ADMIN DASHBOARD <span aria-hidden="true">↗</span></Link>
          <Link className="admin-inline-action" to="/finance">FINANCE WORKSPACE <span aria-hidden="true">↗</span></Link>
        </section>
        <section className="hub-memberships">
          <div className="hub-section-heading"><span className="hub-kicker">ACCOUNT</span></div>
          <Link className="admin-inline-action" to="/sign-in">SIGN IN <span aria-hidden="true">↗</span></Link>
          <Link className="admin-inline-action" to="/sign-up">CREATE AN ACCOUNT <span aria-hidden="true">↗</span></Link>
        </section>
        <Link className="auth-switch" to="/">Back to Open Play home</Link>
      </section>
      <PlayerBottomNavigation />
    </main>
  );
}
