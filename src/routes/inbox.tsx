import { useEffect, useState } from "react";
import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { SiteNavigation } from "../components/site-navigation";
import { getSupabaseClient } from "../lib/supabase/client";

export const Route = createFileRoute("/inbox")({ component: InboxPage });

function InboxPage() {
  const navigate = useNavigate();
  const [loading, setLoading] = useState(true);
  const [signedIn, setSignedIn] = useState(false);

  useEffect(() => {
    let alive = true;
    void getSupabaseClient().auth.getSession().then(async ({ data: { session } }) => {
      if (!session) await navigate({ to: "/sign-in" });
      else if (alive) setSignedIn(true);
      if (alive) setLoading(false);
    });
    return () => { alive = false; };
  }, [navigate]);

  return <main className="notice-page"><SiteNavigation /><section className="notice-panel notification-page">
    <Link className="account-back-link" to="/account">← MY ACCOUNT</Link>
    <p className="eyebrow eyebrow-dark">YOUR OPEN PLAY</p><h1>IN<em>BOX</em></h1>
    {loading ? <p>Loading your inbox…</p> : signedIn ? <div className="inbox-empty-state"><span aria-hidden="true">✉</span><h2>Your messages will appear here.</h2><p>Open Play's secure messaging centre is being built on the existing account and notification infrastructure. Your account is ready, but conversations are not available yet.</p><Link className="button button-small" to="/notifications">VIEW NOTIFICATIONS <span>↗</span></Link></div> : null}
  </section></main>;
}
