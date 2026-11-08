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
      const supabase = getSupabaseClient();
      const { data: authData, error: authError } = await supabase.auth.signInWithPassword({ email: email.trim(), password });
      if (authError) throw authError;
      if (!authData.user) throw new Error("Your account could not be loaded. Please sign in again.");
      const { data: roleRows, error: roleError } = await supabase.from("user_roles").select("role").eq("user_id", authData.user.id);
      if (roleError) throw roleError;
      const roles = (roleRows ?? []).map((row) => row.role);
      if (roles.some((role) => ["admin", "super_admin", "league_admin"].includes(role))) {
        await navigate({ to: "/admin" });
        return;
      }
      if (roles.includes("finance_admin")) {
        await navigate({ to: "/finance" });
        return;
      }
      const { data: player, error: playerError } = await supabase.from("players").select("registration_status,is_banned").eq("user_id", authData.user.id).maybeSingle();
      if (playerError) throw playerError;
      await navigate({ to: player?.registration_status === "registered" && !player.is_banned ? "/player" : "/register-player" });
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "Unable to sign in. Please try again.");
    } finally { setBusy(false); }
  }

  async function resendVerification() {
    setBusy(true); setError(""); setMessage("");
    try {
      if (!email.trim()) throw new Error("Enter your email address first.");
      const { error: resendError } = await getSupabaseClient().auth.resend({
        type: "signup",
        email: email.trim(),
        options: { emailRedirectTo: window.location.origin + "/register-player" },
      });
      if (resendError) throw resendError;
      setMessage("If this account is awaiting email verification, a new confirmation email has been sent.");
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "Unable to request a verification email.");
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
    <Link className="notice-brand" to="/player"><img className="open-play-logo" src="/open-play-logo.png" alt="Open Play"/></Link><p className="eyebrow eyebrow-dark">PLAYER ACCESS</p>
    <h1>Welcome<br/><em>back.</em></h1><p>Sign in to access your Open Play account.</p>
    <form className="auth-form" onSubmit={signIn}>
      <label>Email address<input type="email" autoComplete="email" required value={email} onChange={e=>setEmail(e.target.value)} /></label>
      <label>Password<input type="password" autoComplete="current-password" required value={password} onChange={e=>setPassword(e.target.value)} /></label>
      {error && <p className="form-error" role="alert">{error}</p>}{message && <p className="form-success" role="status">{message}</p>}
      <button className="button" type="submit" disabled={busy}>{busy ? "PLEASE WAIT…" : "SIGN IN"} <span aria-hidden="true">↗</span></button>
    </form>
    <button className="auth-text-button" type="button" onClick={resetPassword} disabled={busy}>Forgot your password?</button>
    <button className="auth-text-button" type="button" onClick={resendVerification} disabled={busy}>Resend verification email</button>
    <p className="auth-switch">New to Open Play? <Link to="/sign-up">Create an account</Link></p><p className="auth-switch"><Link to="/finance">Finance team access</Link></p>
  </section><PlayerBottomNavigation /></main>;
}
