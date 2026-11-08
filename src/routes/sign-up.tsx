import { useState } from "react";
import { Link, createFileRoute, useNavigate } from "@tanstack/react-router";
import { usePostHog } from "posthog-js/react";
import { getSupabaseClient } from "../lib/supabase/client";

export const Route = createFileRoute("/sign-up")({ component: SignUpPage });

function SignUpPage() {
  const navigate = useNavigate();
  const posthog = usePostHog();
  const [email,setEmail]=useState(""); const [password,setPassword]=useState(""); const [confirm,setConfirm]=useState("");
  const [error,setError]=useState(""); const [message,setMessage]=useState(""); const [busy,setBusy]=useState(false);
  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault(); setError(""); setMessage("");
    if(password.length<10){setError("Use a password with at least 10 characters.");return;}
    if(password!==confirm){setError("Your passwords do not match.");return;}
    setBusy(true);
    try {
      const {data,error:authError}=await getSupabaseClient().auth.signUp({email:email.trim(),password,options:{emailRedirectTo:window.location.origin+"/player"}});
      if(authError) throw authError;
      posthog.capture("account_created", { email_verification_required: !data.session });
      if(data.session) await navigate({to:"/player"});
      else setMessage("Your account request is in. Check your inbox to verify your email before signing in. Creating an account does not register you as a player or make you a captain.");
    } catch(cause){setError(cause instanceof Error?cause.message:"Unable to create your account. Please try again.");}
    finally{setBusy(false);}
  }
  return <main className="notice-page"><section className="notice-panel auth-panel">
    <Link className="notice-brand" to="/">OPEN PLAY</Link><p className="eyebrow eyebrow-dark">JOIN THE COMMUNITY</p>
    <h1>Create<br/><em>account.</em></h1><p>Start with your account. You can register as a player separately after verifying your email.</p>
    <form className="auth-form" onSubmit={submit}>
      <label>Email address<input type="email" autoComplete="email" required value={email} onChange={e=>setEmail(e.target.value)}/></label>
      <label>Password<input type="password" autoComplete="new-password" minLength={10} required value={password} onChange={e=>setPassword(e.target.value)}/><small>At least 10 characters.</small></label>
      <label>Confirm password<input type="password" autoComplete="new-password" required value={confirm} onChange={e=>setConfirm(e.target.value)}/></label>
      {error&&<p className="form-error" role="alert">{error}</p>}{message&&<p className="form-success" role="status">{message}</p>}
      <button className="button" type="submit" disabled={busy}>{busy?"CREATING ACCOUNT…":"CREATE ACCOUNT"} <span aria-hidden="true">↗</span></button>
    </form><p className="auth-switch">Already registered? <Link to="/sign-in">Sign in</Link></p>
  </section></main>;
}
