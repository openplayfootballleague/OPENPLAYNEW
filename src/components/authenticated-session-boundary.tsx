import { Fragment, useEffect, useState } from "react";
import type { ReactNode } from "react";
import type { Session } from "@supabase/supabase-js";
import { Link } from "@tanstack/react-router";
import { getSupabaseClient } from "../lib/supabase/client";

export function AuthenticatedSessionBoundary({
  children,
  label = "OPEN PLAY WORKSPACE",
  allowSignUp = false,
}: {
  children: ReactNode;
  label?: string;
  allowSignUp?: boolean;
}) {
  const [session, setSession] = useState<Session | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    let alive = true;
    let authEventSeen = false;
    let supabase: ReturnType<typeof getSupabaseClient>;

    try {
      supabase = getSupabaseClient();
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "Unable to connect to your account.");
      setLoading(false);
      return;
    }

    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, next) => {
      authEventSeen = true;
      if (!alive) return;
      setSession(next);
      setError("");
      setLoading(false);
    });

    void supabase.auth.getSession().then(({ data, error: sessionError }) => {
      if (!alive || authEventSeen) return;
      if (sessionError) {
        setSession(null);
        setError(sessionError.message);
      } else {
        setSession(data.session);
      }
      setLoading(false);
    }).catch((cause: unknown) => {
      if (!alive || authEventSeen) return;
      setSession(null);
      setError(cause instanceof Error ? cause.message : "Unable to verify your account.");
      setLoading(false);
    });

    return () => {
      alive = false;
      subscription.unsubscribe();
    };
  }, []);

  if (loading) {
    return (
      <main className="notice-page player-facing">
        <section className="notice-panel"><p role="status">Checking your account…</p></section>
      </main>
    );
  }

  if (!session) {
    return (
      <main className="notice-page player-facing">
        <section className="notice-panel">
          <p className="eyebrow eyebrow-dark">{label}</p>
          <h1>Sign in to<br /><em>continue.</em></h1>
          {error && <p className="form-error" role="alert">{error}</p>}
          <Link className="button" to="/sign-in">SIGN IN <span>↗</span></Link>
          {allowSignUp && <Link className="auth-switch" to="/sign-up">New to Open Play? Create an account</Link>}
        </section>
      </main>
    );
  }

  // Changing user ID replaces the entire protected subtree. A token refresh
  // for the same user keeps the key stable and does not discard valid state.
  return <Fragment key={session.user.id}>{children}</Fragment>;
}
