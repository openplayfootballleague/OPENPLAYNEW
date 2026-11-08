import { useEffect, useState } from "react";
import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { SiteNavigation } from "../components/site-navigation";
import { getSupabaseClient } from "../lib/supabase/client";

export const Route = createFileRoute("/privacy-security")({ component: PrivacySecurityPage });

function PrivacySecurityPage() {
  const navigate = useNavigate();
  const [email, setEmail] = useState("");
  const [newEmail, setNewEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [loading, setLoading] = useState(true);
  const [savingEmail, setSavingEmail] = useState(false);
  const [savingPassword, setSavingPassword] = useState(false);
  const [error, setError] = useState("");
  const [message, setMessage] = useState("");

  useEffect(() => {
    let alive = true;
    async function load() {
      const { data: { session }, error: sessionError } = await getSupabaseClient().auth.getSession();
      if (sessionError) throw sessionError;
      if (!session) {
        await navigate({ to: "/sign-in" });
        return;
      }
      if (alive) setEmail(session.user.email ?? "");
    }
    void load().catch(cause => {
      if (alive) setError(cause instanceof Error ? cause.message : "Unable to load account security.");
    }).finally(() => { if (alive) setLoading(false); });
    return () => { alive = false; };
  }, [navigate]);

  async function changeEmail(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSavingEmail(true); setError(""); setMessage("");
    try {
      const candidate = newEmail.trim().toLowerCase();
      if (!candidate || candidate === email.toLowerCase()) throw new Error("Enter a different email address.");
      const { error: updateError } = await getSupabaseClient().auth.updateUser({ email: candidate });
      if (updateError) throw updateError;
      setMessage("Email change requested. Follow the verification message sent by Open Play to confirm the new address. Your current email remains in use until verification is complete.");
      setNewEmail("");
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "Unable to request an email change.");
    } finally { setSavingEmail(false); }
  }

  async function changePassword(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSavingPassword(true); setError(""); setMessage("");
    try {
      if (password.length < 12) throw new Error("Use a password with at least 12 characters.");
      if (password !== confirmPassword) throw new Error("The password confirmation does not match.");
      const { error: updateError } = await getSupabaseClient().auth.updateUser({ password });
      if (updateError) throw updateError;
      setPassword(""); setConfirmPassword("");
      setMessage("Your password has been updated.");
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "Unable to update your password.");
    } finally { setSavingPassword(false); }
  }

  if (loading) return <main className="notice-page"><SiteNavigation /><section className="notice-panel"><p>Loading security settings…</p></section></main>;

  return <main className="notice-page"><SiteNavigation /><section className="notice-panel auth-panel">
    <Link className="account-back-link" to="/account">← MY ACCOUNT</Link>
    <p className="eyebrow eyebrow-dark">ACCOUNT SETTINGS</p>
    <h1>PRIVACY &amp; <em>SECURITY</em></h1>
    <p>Manage your sign-in details. Changes are processed through Supabase Auth; your player registration identity and eligibility details are not editable here.</p>
    {error && <p className="form-error" role="alert">{error}</p>}
    {message && <p className="form-success" role="status">{message}</p>}
    <section className="account-security-section">
      <h2>Email address</h2>
      <p>Current address: <strong>{email || "Not available"}</strong></p>
      <form className="auth-form" onSubmit={changeEmail}>
        <label>New email address<input type="email" autoComplete="email" required value={newEmail} onChange={event => setNewEmail(event.target.value)} /></label>
        <button className="button" type="submit" disabled={savingEmail}>{savingEmail ? "PLEASE WAIT…" : "REQUEST EMAIL CHANGE"}</button>
      </form>
      <p className="form-note">Your new address is not used until the verification process is completed.</p>
    </section>
    <section className="account-security-section">
      <h2>Password</h2>
      <form className="auth-form" onSubmit={changePassword}>
        <label>New password<input type="password" autoComplete="new-password" minLength={12} required value={password} onChange={event => setPassword(event.target.value)} /></label>
        <label>Confirm new password<input type="password" autoComplete="new-password" minLength={12} required value={confirmPassword} onChange={event => setConfirmPassword(event.target.value)} /></label>
        <button className="button" type="submit" disabled={savingPassword}>{savingPassword ? "PLEASE WAIT…" : "UPDATE PASSWORD"}</button>
      </form>
    </section>
    <section className="account-security-section">
      <h2>More security controls</h2>
      <p>Phone-number verification, active-device review and remote device revocation are not available in this release yet. No device list or verification status is shown until those controls are connected to a secure server-side workflow.</p>
    </section>
  </section></main>;
}
