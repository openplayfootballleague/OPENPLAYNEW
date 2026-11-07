import { useEffect, useState } from "react";
import { Link, createFileRoute, useNavigate } from "@tanstack/react-router";
import type { Session } from "@supabase/supabase-js";
import { getSupabaseClient } from "../lib/supabase/client";

export const Route = createFileRoute("/register-player")({ component: RegisterPlayerPage });

function RegisterPlayerPage() {
  const navigate=useNavigate(); const [session,setSession]=useState<Session|null>(null); const [loading,setLoading]=useState(true);
  const [name,setName]=useState(""); const [phone,setPhone]=useState(""); const [dob,setDob]=useState("");
  const [error,setError]=useState(""); const [message,setMessage]=useState(""); const [submitted,setSubmitted]=useState(false); const [busy,setBusy]=useState(false);
  useEffect(()=>{
    const supabase=getSupabaseClient();
    supabase.auth.getSession().then(({data})=>{setSession(data.session);setLoading(false);});
    const {data:{subscription}}=supabase.auth.onAuthStateChange((_event,next)=>setSession(next));
    return ()=>subscription.unsubscribe();
  },[]);
  async function submit(event:React.FormEvent<HTMLFormElement>){
    event.preventDefault();setError("");setMessage("");setBusy(true);
    try{
      if(!session?.user.email) throw new Error("Please sign in with a verified email address first.");
      const {error:rpcError}=await getSupabaseClient().rpc("register_player",{p_full_name:name.trim(),p_phone:phone.trim(),p_email:session.user.email,p_date_of_birth:dob});
      if(rpcError) throw rpcError;
      setMessage("Your player registration has been submitted. If it needs a manual identity check, it will remain pending review. Your account and player registration are separate from joining a team.");
      setSubmitted(true);
    }catch(cause){setError(cause instanceof Error?cause.message:"Unable to submit player registration.");}
    finally{setBusy(false);}
  }
  if(loading)return <main className="notice-page"><section className="notice-panel"><p>Checking your account…</p></section></main>;
  if(!session)return <main className="notice-page"><section className="notice-panel"><Link className="notice-brand" to="/">OPEN PLAY</Link><p className="eyebrow eyebrow-dark">PLAYER REGISTRATION</p><h1>One more<br/><em>step.</em></h1><p>You need an Open Play account before registering as a player.</p><Link className="button" to="/sign-in">SIGN IN <span>↗</span></Link><p className="auth-switch">New here? <Link to="/sign-up">Create an account</Link></p></section></main>;
  return <main className="notice-page"><section className="notice-panel auth-panel"><Link className="notice-brand" to="/">OPEN PLAY</Link><p className="eyebrow eyebrow-dark">PLAYER PROFILE</p><h1>Register<br/><em>to play.</em></h1><p>Signed in as <strong>{session.user.email}</strong>. This creates your permanent player identity; it does not automatically add you to a team.</p>
    {submitted?<section className="hub-empty"><p className="form-success" role="status">{message}</p><h2>You're in the system.</h2><p>Your Player Hub will show your registration status. You can request to join or register a team once your player registration is approved.</p><Link className="button" to="/player">OPEN PLAYER HUB <span>↗</span></Link></section>:<form className="auth-form" onSubmit={submit}>
      <label>Full name<input autoComplete="name" required maxLength={120} value={name} onChange={e=>setName(e.target.value)}/></label>
      <label>Mobile number<input type="tel" autoComplete="tel" required maxLength={30} value={phone} onChange={e=>setPhone(e.target.value)}/></label>
      <label>Date of birth<input type="date" required max={new Date().toISOString().slice(0,10)} value={dob} onChange={e=>setDob(e.target.value)}/></label>
      {error&&<p className="form-error" role="alert">{error}</p>}
      <button className="button" type="submit" disabled={busy}>{busy?"SUBMITTING…":"SUBMIT PLAYER REGISTRATION"} <span aria-hidden="true">↗</span></button>
    </form>}<button className="auth-text-button" type="button" onClick={async()=>{await getSupabaseClient().auth.signOut();await navigate({to:"/"});}}>Sign out</button>
  </section></main>;
}
