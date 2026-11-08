import { useState } from "react";
import { PlayerBottomNavigation } from "../components/player-bottom-navigation";
import { Link, createFileRoute, useNavigate } from "@tanstack/react-router";
import { getSupabaseClient } from "../lib/supabase/client";

export const Route = createFileRoute("/sign-in")({ component: SignInPage });

function SignInPage() {
  const navigate = useNavigate();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  async function signIn(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault(); setBusy(true); setError(""); setMessage("");
    try {
      const { error: authError } = await getSupabaseClient().auth.signInWithPassword({ email: email.trim(), password });
      if (authError) throw authError;
      await navigate({ to: "/player" });
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "Unable to sign in. Please try again.");
    } finally { setBusy(false); }
  }

  async function resetPassword() {
    setBusy(true); setError(""); setMessage("");
    try {
      if (!email.trim()) throw new Error("Enter your email address first.");
      const { error: resetError } = await getSupabaseClient().auth.resetPasswordForEmail(email.trim(), { redirectTo: window.location.origin + "/reset-password" });
      if (resetError) throw resetError;
      setMessage("If an account exists for that address, a password reset email has been sent.");
    } catch (cause) { setError(cause instanceof Error ? cause.message : "Unable to request a password reset."); }
    finally { setBusy(false); }
  }

  return <main className="notice-page player-facing"><section className="notice-panel auth-panel">
    <Link className="notice-brand" to="/">OPEN PLAY</Link><p className="eyebrow eyebrow-dark">PLAYER ACCESS</p>
    <h1>Welcome<br/><em>back.</em></h1><p>Sign in to access your Open Play account.</p>
    <form className="auth-form" onSubmit={signIn}>
      <label>Email address<input type="email" autoComplete="email" required value={email} onChange={e=>setEmail(e.target.value)} /></label>
      <label>Password<input type="password" autoComplete="current-password" required value={password} onChange={e=>setPassword(e.target.value)} /></label>
      {error && <p className="form-error" role="alert">{error}</p>}{message && <p className="form-success" role="status">{message}</p>}
      <button className="button" type="submit" disabled={busy}>{busy ? "PLEASE WAIT…" : "SIGN IN"} <span aria-hidden="true">↗</span></button>
    </form>
    <button className="auth-text-button" type="button" onClick={resetPassword} disabled={busy}>Forgot your password?</button>
    <p className="auth-switch">New to Open Play? <Link to="/sign-up">Create an account</Link></p><p className="auth-switch"><Link to="/finance">Finance team access</Link></p>
  </section><PlayerBottomNavigation /></main>;
}
