import { useEffect, useState } from "react";
import { PlayerBottomNavigation } from "../components/player-bottom-navigation";
import { Link, createFileRoute } from "@tanstack/react-router";
import type { Session } from "@supabase/supabase-js";
import { getSupabaseClient } from "../lib/supabase/client";

export const Route = createFileRoute("/reset-password")({ component: ResetPasswordPage });

function ResetPasswordPage() {
  const [session, setSession] = useState<Session | null>(null);
  const [loading, setLoading] = useState(true);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [error, setError] = useState("");
  const [message, setMessage] = useState("");
  const [busy, setBusy] = useState(false);
  const [updated, setUpdated] = useState(false);

  useEffect(() => {
    const supabase = getSupabaseClient();
    let active = true;
    supabase.auth.getSession().then(({ data }) => {
      if (!active) return;
      setSession(data.session);
      setEmail(data.session?.user.email ?? "");
      setLoading(false);
    }).catch(() => {
      if (active) {
        setSession(null);
        setLoading(false);
      }
    });
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, next) => {
      if (active) setSession(next);
    });
    return () => {
      active = false;
      subscription.unsubscribe();
    };
  }, []);

  async function requestReset(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    setMessage("");
    setBusy(true);
    try {
      const { error: resetError } = await getSupabaseClient().auth.resetPasswordForEmail(
        email.trim(),
        { redirectTo: window.location.origin + "/reset-password" },
      );
      if (resetError) throw resetError;
      setMessage("If an account exists for that address, a new password reset email has been sent.");
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "Unable to request a password reset.");
    } finally {
      setBusy(false);
    }
  }

  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    setMessage("");
    if (password.length < 10) {
      setError("Use a password with at least 10 characters.");
      return;
    }
    if (password !== confirm) {
      setError("Your passwords do not match.");
      return;
    }
    setBusy(true);
    try {
      const { error: changeError } = await getSupabaseClient().auth.updateUser({ password });
      if (changeError) throw changeError;
      await getSupabaseClient().auth.signOut();
      setSession(null);
      setUpdated(true);
      setPassword("");
      setConfirm("");
      setMessage("Your password has been updated. Sign in using your new password.");
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "Unable to update your password. Request a fresh reset email and try again.");
    } finally {
      setBusy(false);
    }
  }

  if (loading) {
    return <main className="notice-page player-facing"><section className="notice-panel"><p>Checking your password reset link…</p></section></main>;
  }

  return (
    <main className="notice-page player-facing">
      <section className="notice-panel auth-panel">
        <Link className="notice-brand" to="/"><img className="open-play-logo" src="/open-play-logo.png" alt="Open Play" /></Link>
        <p className="eyebrow eyebrow-dark">ACCOUNT RECOVERY</p>
        <h1>Reset your<br /><em>password.</em></h1>
        {session && !updated ? (
          <>
            <p>Choose a new password for your Open Play account.</p>
            <form className="auth-form" onSubmit={submit}>
              <label>New password<input type="password" minLength={10} autoComplete="new-password" required value={password} onChange={event => setPassword(event.target.value)} /><small>At least 10 characters.</small></label>
              <label>Confirm new password<input type="password" autoComplete="new-password" required value={confirm} onChange={event => setConfirm(event.target.value)} /></label>
              <button className="button" type="submit" disabled={busy}>{busy ? "UPDATING…" : "UPDATE PASSWORD"} <span aria-hidden="true">↗</span></button>
            </form>
          </>
        ) : updated ? (
          <Link className="button" to="/sign-in">BACK TO SIGN IN <span aria-hidden="true">↗</span></Link>
        ) : (
          <>
            <p>Your reset link may have expired. Enter your email and we'll send a fresh secure link.</p>
            <form className="auth-form" onSubmit={requestReset}>
              <label>Email address<input type="email" autoComplete="email" required value={email} onChange={event => setEmail(event.target.value)} /></label>
              <button className="button" type="submit" disabled={busy}>{busy ? "SENDING…" : "SEND NEW RESET LINK"} <span aria-hidden="true">↗</span></button>
            </form>
          </>
        )}
        {error && <p className="form-error" role="alert">{error}</p>}
        {message && <p className="form-success" role="status">{message}</p>}
        <p className="auth-switch"><Link to="/sign-in">Back to sign in</Link></p>
      </section>
      <PlayerBottomNavigation />
    </main>
  );
}
