import { Link, createFileRoute } from "@tanstack/react-router";

export const Route = createFileRoute("/join")({ component: JoinPage });

function JoinPage() {
  return <main className="notice-page"><section className="notice-panel">
    <Link className="notice-brand" to="/">OPEN PLAY</Link><p className="eyebrow eyebrow-dark">GET INVOLVED</p>
    <h1>Find your<br/><em>place to play.</em></h1>
    <p>Start by creating an account or signing in. You can then register your player profile. Joining an existing team and registering a team will follow as separate, approval-based steps.</p>
    <div className="hero-actions"><Link className="button" to="/sign-up">CREATE ACCOUNT <span aria-hidden="true">↗</span></Link><Link className="auth-switch" to="/sign-in">Already have an account? Sign in</Link></div>
  </section></main>;
}
