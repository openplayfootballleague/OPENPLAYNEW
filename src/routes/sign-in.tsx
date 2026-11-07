import { Link, createFileRoute } from "@tanstack/react-router";

export const Route = createFileRoute("/sign-in")({
  component: SignInPage,
});

function SignInPage() {
  return (
    <main className="notice-page">
      <div className="notice-panel">
        <Link className="notice-brand" to="/">OPEN PLAY</Link>
        <p className="eyebrow eyebrow-dark">PLAYER ACCESS</p>
        <h1>Sign in is<br /><em>coming next.</em></h1>
        <p>
          Account access will be connected to the new Open Play Supabase
          project during the backend phase. No sign-in is being simulated here.
        </p>
        <Link className="button" to="/">Back to Open Play <span aria-hidden="true">↗</span></Link>
      </div>
    </main>
  );
}
