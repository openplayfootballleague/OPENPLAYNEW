import { useEffect, useState } from "react";
import { PlayerBottomNavigation } from "../components/player-bottom-navigation";
import { Link, createFileRoute, useNavigate } from "@tanstack/react-router";
import type { Session } from "@supabase/supabase-js";
import { getSupabaseClient } from "../lib/supabase/client";

type ExistingPlayer = { registration_status: "registered" | "pending_review" | "rejected"; is_banned: boolean };
type GuardianConsent = {
  status: "pending_verification" | "pending_admin_review" | "approved" | "rejected" | "withdrawn";
  player_date_of_birth: string;
  guardian_full_name: string;
  guardian_email: string;
  verified_at: string | null;
  reviewed_at: string | null;
  review_reason: string | null;
  withdrawn_at: string | null;
};
function ageOn(dateOfBirth: string): number | null {
  const match = /^(\\d{4})-(\\d{2})-(\\d{2})$/.exec(dateOfBirth);
  if (!match) return null;
  const birthYear = Number(match[1]), birthMonth = Number(match[2]), birthDay = Number(match[3]);
  const today = new Date();
  let age = today.getFullYear() - birthYear;
  if (today.getMonth() + 1 < birthMonth || (today.getMonth() + 1 === birthMonth && today.getDate() < birthDay)) age -= 1;
  return age;
}

export const Route = createFileRoute("/register-player")({ component: RegisterPlayerPage });

function RegisterPlayerPage() {
  const navigate=useNavigate(); const [session,setSession]=useState<Session|null>(null); const [loading,setLoading]=useState(true);
  const [name,setName]=useState(""); const [phone,setPhone]=useState(""); const [dob,setDob]=useState("");
  const [error,setError]=useState(""); const [message,setMessage]=useState(""); const [submitted,setSubmitted]=useState(false); const [busy,setBusy]=useState(false);
  const [existingPlayer,setExistingPlayer]=useState<ExistingPlayer|null>(null);
  const [guardianConsent,setGuardianConsent]=useState<GuardianConsent|null>(null);
  const [guardianName,setGuardianName]=useState("");
  const [guardianEmail,setGuardianEmail]=useState("");
  useEffect(()=>{
    const supabase=getSupabaseClient();
    let active=true;
    async function load(){
      const {data:{session:current}}=await supabase.auth.getSession();
      if(!active)return;
      setSession(current);
      if(current){
        const [{data:playerData,error:playerError},{data:consentRows,error:consentError}]=await Promise.all([
          supabase.from("players").select("registration_status,is_banned").eq("user_id",current.user.id).maybeSingle(),
          supabase.rpc("get_my_guardian_consent_status")
        ]);
        if(!active)return;
        if(playerError||consentError)setError(playerError?.message??consentError?.message??"Unable to load registration status.");
        else {
          setExistingPlayer(playerData as ExistingPlayer|null);
          const consent=(consentRows??[])[0] as GuardianConsent|undefined;
          if(consent){setGuardianConsent(consent);setGuardianName(consent.guardian_full_name);setGuardianEmail(consent.guardian_email);}
        }
      }
      if(active)setLoading(false);
    }
    void load();
    const {data:{subscription}}=supabase.auth.onAuthStateChange((_event,next)=>setSession(next));
    return ()=>{active=false;subscription.unsubscribe();};
  },[]);
  async function submit(event:React.FormEvent<HTMLFormElement>){
    event.preventDefault();setError("");setMessage("");setBusy(true);
    try{
      if(!session?.user.email||!session.user.email_confirmed_at) throw new Error("Please verify your email address before registering as a player.");
      const age=ageOn(dob);
      if(age===null) throw new Error("Enter a valid date of birth.");
      if(age<16) throw new Error("Players must be at least 16 years old to register. Under-16s can still browse public fixtures, results and tables.");
      if(age<18 && !(guardianConsent?.status==="approved" && guardianConsent.player_date_of_birth===dob)) {
        if(guardianConsent?.status==="pending_admin_review" && guardianConsent.player_date_of_birth===dob) {
          setMessage("Your parent or legal guardian has verified consent. Open Play administrators must review it before you can register as a player.");
          return;
        }
        if(guardianName.trim().length<2 || !guardianEmail.trim()) throw new Error("Enter your parent or legal guardian's name and email address.");
        const {data:consentData,error:consentError}=await getSupabaseClient().functions.invoke("guardian-consent",{
          body:{date_of_birth:dob,guardian_full_name:guardianName.trim(),guardian_email:guardianEmail.trim()}
        });
        if(consentError) throw consentError;
        if(consentData?.error) throw new Error(consentData.error);
        const {data:consentRows,error:statusError}=await getSupabaseClient().rpc("get_my_guardian_consent_status");
        if(statusError) throw statusError;
        setGuardianConsent((consentRows??[])[0] as GuardianConsent ?? null);
        setMessage("A verification email has been sent to your parent or legal guardian. They must confirm consent, then Open Play administrators will review it. You cannot register as a player until both steps are complete.");
        return;
      }
      const {data:playerData,error:rpcError}=await getSupabaseClient().rpc("register_player",{p_full_name:name.trim(),p_phone:phone.trim(),p_email:session.user.email,p_date_of_birth:dob});
      if(rpcError) throw rpcError;
      if(!playerData)throw new Error("Your registration could not be confirmed. Please try again.");
      setExistingPlayer({registration_status:playerData.registration_status,is_banned:playerData.is_banned});
      setMessage("Your player registration has been submitted. If it needs a manual identity check, it will remain pending review. Your account and player registration are separate from joining a team.");
      setSubmitted(true);
    }catch(cause){setError(cause instanceof Error?cause.message:"Unable to submit player registration.");}
    finally{setBusy(false);}
  }
  async function resendVerification(){
    if(!session?.user.email)return;
    setError("");setMessage("");setBusy(true);
    try{
      const {error:resendError}=await getSupabaseClient().auth.resend({
        type:"signup",
        email:session.user.email,
        options:{emailRedirectTo:window.location.origin+"/register-player"}
      });
      if(resendError)throw resendError;
      setMessage("A new verification email has been sent. Open the link in your inbox before registering as a player.");
    }catch(cause){setError(cause instanceof Error?cause.message:"Unable to resend the verification email. Please try again later.");}
    finally{setBusy(false);}
  }
  if(loading)return <main className="notice-page player-facing"><section className="notice-panel"><p>Checking your account…</p></section></main>;
  if(!session)return <main className="notice-page player-facing"><section className="notice-panel"><Link className="notice-brand" to="/player"><img className="open-play-logo" src="/open-play-logo.png" alt="Open Play"/></Link><p className="eyebrow eyebrow-dark">PLAYER REGISTRATION</p><h1>One more<br/><em>step.</em></h1><p>You need an Open Play account before registering as a player.</p><Link className="button" to="/sign-in">SIGN IN <span>↗</span></Link><p className="auth-switch">New here? <Link to="/sign-up">Create an account</Link></p></section></main>;
  if(!session.user.email_confirmed_at)return <main className="notice-page player-facing"><section className="notice-panel auth-panel"><Link className="notice-brand" to="/player"><img className="open-play-logo" src="/open-play-logo.png" alt="Open Play"/></Link><p className="eyebrow eyebrow-dark">VERIFY YOUR EMAIL</p><h1>Check your<br/><em>inbox.</em></h1><p>Verify <strong>{session.user.email}</strong> before submitting your player registration. Your player profile will only be created after email verification.</p>{error&&<p className="form-error" role="alert">{error}</p>}{message&&<p className="form-success" role="status">{message}</p>}<button className="button" type="button" onClick={resendVerification} disabled={busy}>{busy?"SENDING…":"RESEND VERIFICATION EMAIL"}</button><p className="auth-switch"><Link to="/sign-in">Back to sign in</Link></p></section><PlayerBottomNavigation /></main>;
  if(existingPlayer&&!submitted)return <main className="notice-page player-facing"><section className="notice-panel auth-panel"><Link className="notice-brand" to="/player"><img className="open-play-logo" src="/open-play-logo.png" alt="Open Play"/></Link><p className="eyebrow eyebrow-dark">PLAYER REGISTRATION STATUS</p><h1>{existingPlayer.is_banned?"Account":"Registration"}<br/><em>{existingPlayer.is_banned?"restricted":existingPlayer.registration_status==="registered"?"approved":existingPlayer.registration_status==="pending_review"?"under review":"not approved"}.</em></h1><p>{existingPlayer.is_banned?"Your account cannot submit player or team requests. Please contact Open Play support.":existingPlayer.registration_status==="registered"?"Your player registration is approved. You can now access your Player Hub and request to join or register a team.":existingPlayer.registration_status==="pending_review"?"Your player registration is awaiting an identity review. You do not need to submit another application.":"Your player registration was not approved. Please contact Open Play support for the next steps."}</p>{existingPlayer.registration_status==="registered"&&!existingPlayer.is_banned?<Link className="button" to="/player">OPEN PLAYER HUB <span>↗</span></Link>:<Link className="button" to="/">BACK TO OPEN PLAY <span>↗</span></Link>}</section><PlayerBottomNavigation /></main>;
  return <main className="notice-page player-facing"><section className="notice-panel auth-panel"><Link className="notice-brand" to="/player"><img className="open-play-logo" src="/open-play-logo.png" alt="Open Play"/></Link><p className="eyebrow eyebrow-dark">PLAYER PROFILE</p><h1>Register<br/><em>to play.</em></h1><p>Signed in as <strong>{session.user.email}</strong>. This creates your permanent player identity; it does not automatically add you to a team.</p>
    {submitted?<section className="hub-empty"><p className="form-success" role="status">{message}</p><h2>You're in the system.</h2><p>Your Player Hub will show your registration status. You can request to join or register a team once your player registration is approved.</p><Link className="button" to="/player">OPEN PLAYER HUB <span>↗</span></Link></section>:<form className="auth-form" onSubmit={submit}>
      <label>Full name<input autoComplete="name" required maxLength={120} value={name} onChange={e=>setName(e.target.value)}/></label>
      <label>Mobile number<input type="tel" autoComplete="tel" required maxLength={30} value={phone} onChange={e=>setPhone(e.target.value)}/></label>
      <label>Date of birth<input type="date" required max={new Date().toISOString().slice(0,10)} value={dob} onChange={e=>setDob(e.target.value)}/></label>
      {dob&&ageOn(dob)!==null&&ageOn(dob)!==undefined&&ageOn(dob)!<16&&<p className="form-error" role="status">Under-16s can browse public Open Play information but cannot register as players or join teams.</p>}
      {dob&&ageOn(dob)!>=16&&ageOn(dob)!<18&&guardianConsent?.player_date_of_birth===dob&&guardianConsent.status==="pending_verification"&&<p className="form-success" role="status">Waiting for your parent or legal guardian to verify the consent email.</p>}
      {dob&&ageOn(dob)!>=16&&ageOn(dob)!<18&&guardianConsent?.player_date_of_birth===dob&&guardianConsent.status==="pending_admin_review"&&<p className="form-success" role="status">Guardian consent verified. Waiting for Open Play administrator review.</p>}
      {dob&&ageOn(dob)!>=16&&ageOn(dob)!<18&&guardianConsent?.player_date_of_birth===dob&&guardianConsent.status==="approved"&&<p className="form-success" role="status">Guardian consent approved. You can now submit your player registration.</p>}
      {dob&&ageOn(dob)!>=16&&ageOn(dob)!<18&&(!guardianConsent||guardianConsent.player_date_of_birth!==dob||guardianConsent.status==="rejected"||guardianConsent.status==="withdrawn"||guardianConsent.status==="pending_verification")&&guardianConsent?.status!=="pending_admin_review"&&guardianConsent?.status!=="approved"&&<>
        <p>Players aged 16–17 need verified parent or legal-guardian consent and Open Play administrator approval before registration.</p>
        <label>Parent or legal guardian full name<input autoComplete="name" required maxLength={120} value={guardianName} onChange={e=>setGuardianName(e.target.value)}/></label>
        <label>Parent or legal guardian email<input type="email" autoComplete="email" required maxLength={254} value={guardianEmail} onChange={e=>setGuardianEmail(e.target.value)}/></label>
      </>}
      {error&&<p className="form-error" role="alert">{error}</p>}
      {message&&<p className="form-success" role="status">{message}</p>}
      <button className="button" type="submit" disabled={busy||Boolean(dob&&ageOn(dob)!==null&&ageOn(dob)!<16)||Boolean(dob&&ageOn(dob)!==null&&ageOn(dob)!>=16&&ageOn(dob)!<18&&guardianConsent?.player_date_of_birth===dob&&guardianConsent.status==="pending_admin_review")}>{busy?"PLEASE WAIT…":dob&&ageOn(dob)!==null&&ageOn(dob)!>=16&&ageOn(dob)!<18&&!(guardianConsent?.status==="approved"&&guardianConsent.player_date_of_birth===dob)?"REQUEST GUARDIAN CONSENT":"SUBMIT PLAYER REGISTRATION"} <span aria-hidden="true">↗</span></button>
    </form>}<button className="auth-text-button" type="button" onClick={async()=>{await getSupabaseClient().auth.signOut();await navigate({to:"/"});}}>Sign out</button>
  </section><PlayerBottomNavigation /></main>;
}
