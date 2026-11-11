import { createFileRoute } from "@tanstack/react-router";

export const Route = createFileRoute("/")({ component: PublicHomePage });

function PublicHomePage() {
  return (
    <main className="site-shell home-reference">
      <header className="reference-header">
        <a className="reference-brand" href="/" aria-label="Open Play home">
          <span className="reference-mark">OP</span><span>OPEN PLAY</span>
        </a>
        <a className="reference-location" href="/teams"><span>⌖</span> BIDEFORD <span className="reference-chevron">⌄</span></a>
        <a className="reference-account" href="/sign-in" aria-label="Sign in"><span>♙</span></a>
      </header>

      <section className="reference-welcome">
        <div className="reference-welcome-top">
          <span className="reference-label">OPEN PLAY</span>
          <span className="reference-season">NORTH DEVON FOOTBALL</span>
        </div>
        <div className="reference-welcome-main">
          <div>
            <h1>YOUR GAME<br />STARTS HERE.</h1>
            <p>Local football. Real teams. Your place to play.</p>
            <div className="reference-actions">
              <a className="reference-primary" href="/join">JOIN OPEN PLAY <span>↗</span></a>
              <a className="reference-secondary" href="/match-centre">EXPLORE MATCH CENTRE <span>›</span></a>
            </div>
          </div>
          <div className="reference-ball-art" aria-hidden="true"><span>OP</span></div>
        </div>
        <div className="reference-welcome-foot">
          <span>PLAY HARD. RESPECT ALWAYS.</span>
          <span>BUILT FOR THE LOVE OF THE GAME</span>
        </div>
      </section>

      <section className="reference-grid" aria-label="Open Play">
        <a href="/match-centre" className="reference-card"><span className="reference-card-icon">▦</span><span className="reference-card-arrow">›</span><strong>Match Centre</strong><small>Fixtures, results and league tables</small></a>
        <a href="/teams" className="reference-card"><span className="reference-card-icon">♧</span><span className="reference-card-arrow">›</span><strong>Find Your League</strong><small>Explore local teams and competitions</small></a>
        <a href="/join" className="reference-card"><span className="reference-card-icon">＋</span><span className="reference-card-arrow">›</span><strong>Join Open Play</strong><small>Register as a player or apply with a team</small></a>
        <a href="/player" className="reference-card"><span className="reference-card-icon">◎</span><span className="reference-card-arrow">›</span><strong>Player Hub</strong><small>Your fixtures, results and player profile</small></a>
        <a href="/captain" className="reference-card"><span className="reference-card-icon">⬡</span><span className="reference-card-arrow">›</span><strong>Captain Hub</strong><small>Squads, team sheets and matchday tools</small></a>
        <a href="/more" className="reference-card"><span className="reference-card-icon">☰</span><span className="reference-card-arrow">›</span><strong>More from Open Play</strong><small>Information, updates and support</small></a>
      </section>

      <section className="reference-next">
        <div className="reference-section-heading"><h2>GET IN THE GAME</h2><a href="/join">JOIN NOW <span>›</span></a></div>
        <div className="reference-next-panel">
          <div><span className="reference-label">YOUR LOCAL FOOTBALL COMMUNITY</span><h3>Find your team.<br />Make your mark.</h3><p>Whether you're joining as a player or bringing a team, your next game starts here.</p></div>
          <a className="reference-primary" href="/join">GET STARTED <span>↗</span></a>
        </div>
      </section>

      <footer className="reference-footer"><span>OP&nbsp; OPEN PLAY</span><span>PLAY HARD. RESPECT ALWAYS.</span><span>© OPEN PLAY</span></footer>
      <nav className="reference-bottom-nav" aria-label="Main navigation">
        <a className="active" href="/"><span>⌂</span><small>HOME</small></a>
        <a href="/match-centre"><span>♜</span><small>MATCH CENTRE</small></a>
        <a href="/teams"><span>⬡</span><small>TEAMS</small></a>
        <a href="/more"><span>☰</span><small>MORE</small></a>
      </nav>
    </main>
  );
}
