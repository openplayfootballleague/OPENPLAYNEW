import { useState } from "react";
import { Link, createFileRoute, useNavigate } from "@tanstack/react-router";
import { getSupabaseClient } from "../lib/supabase/client";

export const Route = createFileRoute("/more")({ component: MorePage });

function MorePage() {
  const navigate = useNavigate();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  async function signOut() {
    setBusy(true);
    setError("");
    const { error: signOutError } = await getSupabaseClient().auth.signOut();
    if (signOutError) {
      setError(signOutError.message);
      setBusy(false);
      return;
    }
    await navigate({ to: "/sign-in" });
  }

  return (
    <main className="notice-page">
      <section className="notice-panel hub-panel more-panel">
        <Link className="notice-brand" to="/player">OPEN PLAY</Link>
        <p className="eyebrow eyebrow-dark">YOUR ACCOUNT</p>
        <h1>MORE.</h1>
        <p>Manage your Open Play account and find your way around the platform.</p>
        <div className="more-link-list">
          <Link to="/player"><span><strong>PLAYER HUB</strong><small>Your team, fixtures and player information</small></span><b>›</b></Link>
          <Link to="/match-centre"><span><strong>MATCH CENTRE</strong><small>Fixtures, results and league tables</small></span><b>›</b></Link>
          <Link to="/teams"><span><strong>TEAMS</strong><small>Browse teams in your league</small></span><b>›</b></Link>
          <Link to="/captain"><span><strong>CAPTAIN'S HUB</strong><small>Team sheets and squad management</small></span><b>›</b></Link>
        </div>
        {error && <p className="form-error" role="alert">{error}</p>}
        <button className="button more-signout" type="button" onClick={() => void signOut()} disabled={busy}>
          {busy ? "SIGNING OUT…" : "SIGN OUT"} <span aria-hidden="true">↗</span>
        </button>
      </section>
    </main>
  );
}
