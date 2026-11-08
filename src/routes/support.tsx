import { createFileRoute, Link } from "@tanstack/react-router";
import { SiteNavigation } from "../components/site-navigation";

export const Route = createFileRoute("/support")({ component: SupportPage });

function SupportPage() {
  return <main className="notice-page"><SiteNavigation /><section className="notice-panel auth-panel">
    <Link className="account-back-link" to="/account">← MY ACCOUNT</Link>
    <p className="eyebrow eyebrow-dark">OPEN PLAY HELP</p>
    <h1>HELP &amp; <em>SUPPORT</em></h1>
    <p>Find help with your Open Play account and player access.</p>
    <section className="account-security-section">
      <h2>Account access</h2>
      <p>For sign-in problems, use the password reset option on the sign-in page. Email changes and password updates are available in Privacy &amp; Security.</p>
      <Link className="button button-small" to="/privacy-security">PRIVACY &amp; SECURITY <span>↗</span></Link>
    </section>
    <section className="account-security-section">
      <h2>Player registration and teams</h2>
      <p>Your account and player registration are separate. Check your Player Hub for registration status and team membership information.</p>
      <Link className="button button-small" to="/player">OPEN PLAYER HUB <span>↗</span></Link>
    </section>
    <section className="account-security-section">
      <h2>Notifications</h2>
      <p>Review in-app alerts and manage available email, SMS and in-app delivery preferences.</p>
      <Link className="button button-small" to="/notifications">NOTIFICATION CENTRE <span>↗</span></Link>
    </section>
    <p className="form-note">A private support-request inbox is not connected yet. This page does not send a message or claim that a support case has been created.</p>
  </section></main>;
}
