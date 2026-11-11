import { createFileRoute } from "@tanstack/react-router";

export const Route = createFileRoute("/")({
  component: HomePage,
});

function HomePage() {
  return (
    <main className="site-shell home-v2">
      <header className="home-header">
        <a className="home-wordmark" href="/" aria-label="Open Play home">
          <span className="home-mark">OP</span>
          <span>OPEN PLAY</span>
        </a>
        <nav className="home-nav" aria-label="Main navigation">
          <a href="/match-centre">MATCH CENTRE</a>
          <a href="/teams">TEAMS</a>
          <a href="#platform">THE PLATFORM</a>
        </nav>
        <div className="home-header-actions">
          <a className="home-sign-in" href="/join">SIGN IN</a>
          <a className="home-join" href="/join">JOIN OPEN PLAY <span aria-hidden="true">↗</span></a>
        </div>
      </header>

      <section className="home-hero" aria-labelledby="home-hero-title">
        <div className="home-hero-photo" aria-hidden="true" />
        <div className="home-hero-shade" aria-hidden="true" />
        <div className="home-hero-inner">
          <p className="home-kicker"><span /> LOCAL FOOTBALL. BIG ENERGY.</p>
          <h1 id="home-hero-title">YOUR GAME.<br /><em>YOUR LEAGUE.</em></h1>
          <p className="home-hero-copy">
            More than a match. A place to compete, connect and be part of something.
          </p>
          <div className="home-hero-actions">
            <a className="home-primary-cta" href="/join">FIND YOUR LEAGUE <span aria-hidden="true">↗</span></a>
            <a className="home-secondary-cta" href="/match-centre">EXPLORE MATCH CENTRE <span aria-hidden="true">→</span></a>
          </div>
        </div>
        <div className="home-hero-bottom">
          <span>PLAY HARD. RESPECT ALWAYS.</span>
          <span>BUILT FOR THE LOVE OF THE GAME</span>
        </div>
        <span className="home-hero-index" aria-hidden="true">01 / 04</span>
      </section>

      <section className="home-manifesto" id="platform">
        <div className="home-manifesto-heading">
          <p className="home-kicker"><span /> THE OPEN PLAY PLATFORM</p>
          <h2>EVERYTHING<br />AROUND THE GAME.<br /><em>IN ONE PLACE.</em></h2>
        </div>
        <div className="home-manifesto-aside">
          <p className="home-aside-label">MORE THAN 90 MINUTES</p>
          <p>From the first whistle to the final table, Open Play brings your football community together — with the tools to play, follow and run your league.</p>
          <a href="/teams" className="home-inline-link">DISCOVER YOUR LEAGUE <span>↗</span></a>
        </div>
      </section>

      <section className="home-platform-grid" aria-label="Explore Open Play">
        <a className="home-platform-card home-card-match" href="/match-centre">
          <span className="home-card-top"><span>01 / FOLLOW</span><span>↗</span></span>
          <div><p className="home-card-eyebrow">EVERY GAME. EVERY MOMENT.</p><h3>MATCH<br />CENTRE<span>.</span></h3><p className="home-card-description">Fixtures, results and league tables. Stay close to every moment of your competition.</p></div>
          <span className="home-card-bottom">EXPLORE MATCH CENTRE <b>↗</b></span>
        </a>
        <a className="home-platform-card home-card-league" href="/teams">
          <span className="home-card-top"><span>02 / DISCOVER</span><span>＋</span></span>
          <div><p className="home-card-eyebrow">FIND YOUR PEOPLE</p><h3>FIND YOUR<br />LEAGUE<span>.</span></h3><p className="home-card-description">Discover local competitions, meet your team and find your place in the game.</p></div>
          <span className="home-card-bottom">EXPLORE TEAMS <b>↗</b></span>
        </a>
        <a className="home-platform-card home-card-player" href="/player">
          <span className="home-card-top"><span>03 / BELONG</span><span>◎</span></span>
          <div><p className="home-card-eyebrow">YOUR SEASON. YOUR STORY.</p><h3>PLAYER<br />HUB<span>.</span></h3><p className="home-card-description">Your profile, team, fixtures and stats — all together in one place.</p></div>
          <span className="home-card-bottom">OPEN PLAYER HUB <b>↗</b></span>
        </a>
      </section>

      <section className="home-join-band">
        <div>
          <p className="home-kicker"><span /> YOUR NEXT CHAPTER STARTS HERE</p>
          <h2>READY TO<br /><em>GET IN THE GAME?</em></h2>
        </div>
        <div className="home-join-band-action">
          <p>Whether you're building a team or looking for your next competition, there's a place for you at Open Play.</p>
          <a className="home-primary-cta" href="/join">JOIN OPEN PLAY <span aria-hidden="true">↗</span></a>
        </div>
      </section>

      <footer className="home-footer">
        <a className="home-wordmark" href="/" aria-label="Open Play home"><span className="home-mark">OP</span><span>OPEN PLAY</span></a>
        <span>PLAY HARD. RESPECT ALWAYS.</span>
        <span>© {new Date().getFullYear()} OPEN PLAY</span>
      </footer>
    </main>
  );
}
