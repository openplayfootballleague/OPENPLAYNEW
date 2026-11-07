import { Link, createFileRoute } from "@tanstack/react-router";

export const Route = createFileRoute("/join")({
  component: JoinPage,
});

function JoinPage() {
  return (
    <main className="notice-page">
      <div className="notice-panel">
        <Link className="notice-brand" to="/">OPEN PLAY</Link>
        <p className="eyebrow eyebrow-dark">GET INVOLVED</p>
        <h1>Find your<br /><em>place to play.</em></h1>
        <p>
          League discovery and player/team registration are being built.
          Registration will open when the real account and league services are
          connected.
        </p>
        <Link className="button" to="/">Back to Open Play <span aria-hidden="true">↗</span></Link>
      </div>
    </main>
  );
}
