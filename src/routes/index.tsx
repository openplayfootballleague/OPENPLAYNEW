import { createFileRoute } from "@tanstack/react-router";

export const Route = createFileRoute("/")({
  component: HomePage,
});

function HomePage() {
  return (
    <main className="site-shell">
      <header className="site-header">
        <a className="wordmark" href="/" aria-label="Open Play home">
          <span className="wordmark-mark">OP</span>
          <span>OPEN PLAY</span>
        </a>
        <span className="header-tagline">LOCAL FOOTBALL. BIG ENERGY.</span>
        <a className="header-join" href="/join">JOIN THE GAME <span aria-hidden="true">↗</span></a>
      </header>

      <section className="hero" aria-labelledby="hero-title">
        <div className="hero-image" aria-hidden="true" />
        <div className="hero-content">
          <p className="eyebrow"><span /> BUILT FOR THE LOVE OF THE GAME</p>
          <h1 id="hero-title">YOUR GAME.<br /><span>YOUR LEAGUE.</span></h1>
          <p className="hero-copy">
            More than a match. A place to compete, connect and be part of something.
          </p>
          <div className="hero-actions">
            <a className="button" href="/join">FIND YOUR LEAGUE <span aria-hidden="true">↗</span></a>
            <a className="text-link" href="/match-centre">EXPLORE MATCH CENTRE <span aria-hidden="true">→</span></a>
          </div>
        </div>
        <div className="hero-foot">
          <span>PLAY HARD. RESPECT ALWAYS.</span>
          <span>EST. OPEN PLAY</span>
        </div>
      </section>

      <section className="intro-grid" id="about">
        <div>
          <p className="eyebrow"><span /> THE OPEN PLAY PLATFORM</p>
          <h2>EVERYTHING AROUND<br />THE GAME. <em>IN ONE PLACE.</em></h2>
        </div>
        <p className="intro-copy">
          Follow your team, keep up with every fixture and result, and manage your football life from one simple home.
        </p>
      </section>

      <section className="feature-grid" aria-label="Platform features">
        <a className="feature-card feature-dark" href="/match-centre">
          <span className="feature-index">01 / FOLLOW</span>
          <span className="feature-icon" aria-hidden="true">↗</span>
          <div><h3>MATCH CENTRE</h3><p>Fixtures, live updates, results and league tables.</p></div>
        </a>
        <a className="feature-card feature-orange" href="/teams">
          <span className="feature-index">02 / DISCOVER</span>
          <span className="feature-icon" aria-hidden="true">＋</span>
          <div><h3>FIND YOUR LEAGUE</h3><p>Discover a competition and get involved.</p></div>
        </a>
        <a className="feature-card feature-light" href="/player">
          <span className="feature-index">03 / BELONG</span>
          <span className="feature-icon" aria-hidden="true">◎</span>
          <div><h3>YOUR PLAYER HUB</h3><p>Your profile, team and season — all together.</p></div>
        </a>
      </section>

      <footer className="site-footer">
        <a className="wordmark" href="/"><span className="wordmark-mark">OP</span><span>OPEN PLAY</span></a>
        <span>PLAY HARD. RESPECT ALWAYS.</span>
        <span>© {new Date().getFullYear()} OPEN PLAY</span>
      </footer>
    </main>
  );
}
