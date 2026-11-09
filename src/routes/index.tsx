import { useEffect, useState } from "react";
import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { getSupabaseClient } from "../lib/supabase/client";
import { PlayerBottomNavigation } from "../components/player-bottom-navigation";

export const Route = createFileRoute("/")({
  component: HomePage,
});

function HomePage() {
  const navigate = useNavigate();
  const [checkingAccess, setCheckingAccess] = useState(true);

  useEffect(() => {
    let alive = true;
    const supabase = getSupabaseClient();

    async function resolveHome(userId: string | null) {
      if (!userId) {
        if (alive) setCheckingAccess(false);
        return;
      }

      const [{ data: player, error: playerError }, { data: captainMemberships, error: captainError }] =
        await Promise.all([
          supabase
            .from("players")
            .select("registration_status")
            .eq("user_id", userId)
            .maybeSingle(),
          supabase
            .from("team_memberships")
            .select("id")
            .eq("user_id", userId)
            .eq("status", "active")
            .eq("is_captain", true)
            .limit(1),
        ]);

      if (!alive) return;

      // Fail closed to the public home if role data cannot be read. This avoids
      // accidentally hiding the public site because of a transient query error.
      if (!playerError && !captainError &&
          (player?.registration_status === "registered" || (captainMemberships?.length ?? 0) > 0)) {
        await navigate({ to: "/player", replace: true });
        return;
      }

      setCheckingAccess(false);
    }

    void supabase.auth.getSession().then(({ data: { session } }) => {
      void resolveHome(session?.user.id ?? null);
    });

    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      void resolveHome(session?.user.id ?? null);
    });

    return () => {
      alive = false;
      subscription.unsubscribe();
    };
  }, [navigate]);

  if (checkingAccess) {
    return (
      <main className="notice-page" aria-live="polite">
        <section className="notice-panel">
          <p>Loading your Open Play home…</p>
        </section>
      </main>
    );
  }

  return (
    <>
    <main className="site-shell">
      <header className="site-header">
        <a className="wordmark" href="/player" aria-label="Open Play Player Hub">
          <img className="open-play-logo" src="/open-play-logo.png" alt="Open Play"/>
        </a>
        <nav className="header-nav" aria-label="Main navigation">
          <a href="/match-centre">Match centre</a>
          <a href="/teams">Leagues</a>
          <a href="/gallery">Gallery</a>
          <a href="#about">About</a>
        </nav>
        <div className="header-actions">
          <a className="login-link" href="/sign-in">Sign in</a>
          <a className="button button-small" href="/join">Join Open Play</a>
        </div>
      </header>

      <section className="hero" aria-labelledby="hero-title">
        <div className="hero-image" aria-hidden="true" />
        <div className="hero-content">
          <p className="eyebrow"><span /> LOCAL FOOTBALL. BIG ENERGY.</p>
          <h1 id="hero-title">
            YOUR GAME.
            <br />
            <span>YOUR LEAGUE.</span>
          </h1>
          <p className="hero-copy">
            More than a match. A place to compete, connect and be part of
            something.
          </p>
          <div className="hero-actions">
            <a className="button" href="/join">Find your league <span aria-hidden="true">↗</span></a>
            <a className="text-link" href="/match-centre">Explore match centre <span aria-hidden="true">→</span></a>
          </div>
        </div>
        <div className="hero-foot">
          <span>BUILT FOR THE LOVE OF THE GAME</span>
          <span>EST. OPEN PLAY</span>
        </div>
      </section>

      <section className="intro-grid" id="about">
        <div>
          <p className="eyebrow eyebrow-dark">THE OPEN PLAY PLATFORM</p>
          <h2>Everything around<br />the game. <em>In one place.</em></h2>
        </div>
        <p className="intro-copy">
          Follow your team, keep up with every fixture and result, and manage
          your football life from one simple home.
        </p>
      </section>

      <section className="feature-grid" aria-label="Platform features">
        <a className="feature-card feature-dark" href="/match-centre">
          <span className="feature-index">01 / FOLLOW</span>
          <span className="feature-icon" aria-hidden="true">↗</span>
          <div>
            <h3>Match centre</h3>
            <p>Fixtures, live updates, results and league tables.</p>
          </div>
        </a>
        <a className="feature-card feature-orange" href="/teams">
          <span className="feature-index">02 / DISCOVER</span>
          <span className="feature-icon" aria-hidden="true">＋</span>
          <div>
            <h3>Find your league</h3>
            <p>Discover a competition and get involved.</p>
          </div>
        </a>
        <a className="feature-card feature-light" href="/join">
          <span className="feature-index">03 / BELONG</span>
          <span className="feature-icon" aria-hidden="true">◎</span>
          <div>
            <h3>Join Open Play</h3>
            <p>Find a team or register your own.</p>
          </div>
        </a>
      </section>

      <footer className="site-footer">
        <a className="wordmark" href="/player" aria-label="Open Play Player Hub">
          <img className="open-play-logo" src="/open-play-logo.png" alt="Open Play"/>
        </a>
        <span>PLAY HARD. RESPECT ALWAYS.</span>
        <span>© {new Date().getFullYear()} OPEN PLAY</span>
      </footer>
    </main>
    <PlayerBottomNavigation />
    </>
  );
}
