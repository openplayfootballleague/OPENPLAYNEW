import { useEffect, useState } from "react";
import { Link, createFileRoute, useNavigate } from "@tanstack/react-router";
import type { Session } from "@supabase/supabase-js";
import { getSupabaseClient } from "../lib/supabase/client";

type Player = { id:string; full_name:string; registration_status:"registered"|"pending_review"|"rejected"; is_banned:boolean };
type Profile = { first_name:string|null; last_name:string|null; display_name:string|null; phone:string|null; preferred_position:string|null; avatar_path:string|null };
type Membership = { id:string; season_team_id:string; status:"pending"|"active"|"suspended"|"left"|"rejected"; is_captain:boolean; squad_number:number|null; joined_at:string|null };
type Team = { id:string; name:string; season_id:string };

export const Route=createFileRoute("/player")({component:PlayerHubPage});

function PlayerHubPage(){
 const navigate=useNavigate();const [session,setSession]=useState<Session|null>(null);const [player,setPlayer]=useState<Player|null>(null);const [profile,setProfile]=useState<Profile|null>(null);const [memberships,setMemberships]=useState<Membership[]>([]);const [editing,setEditing]=useState(false);const [saving,setSaving]=useState(false);const [firstName,setFirstName]=useState("");const [lastName,setLastName]=useState("");const [displayName,setDisplayName]=useState("");const [phone,setPhone]=useState("");const [position,setPosition]=useState("");const [avatarUrl,setAvatarUrl]=useState("");const [isAdmin,setIsAdmin]=useState(false);const [teams,setTeams]=useState<Team[]>([]);const [loading,setLoading]=useState(true);const [error,setError]=useState("");
 useEffect(()=>{let alive=true;const supabase=getSupabaseClient();
  async function load(){const {data:{session:current}}=await supabase.auth.getSession();if(!alive)return;setSession(current);
   if(!current){setLoading(false);return;}
   const [{data:playerData,error:playerError},{data:membershipData,error:membershipError},{data:profileData,error:profileError},{data:roleData}]=await Promise.all([
    supabase.from("players").select("id,full_name,registration_status,is_banned").eq("user_id",current.user.id).maybeSingle(),
    supabase.from("team_memberships").select("id,season_team_id,status,is_captain,squad_number,joined_at").eq("user_id",current.user.id).order("created_at",{ascending:false}),
    supabase.from("profiles").select("first_name,last_name,display_name,phone,preferred_position,avatar_path").eq("id",current.user.id).maybeSingle(),
    supabase.from("user_roles").select("role").eq("user_id",current.user.id),
   ]);
   if(!alive)return;
   if(playerError||membershipError||profileError)setError(playerError?.message??membershipError?.message??profileError?.message??"Unable to load your player hub.");
   setPlayer(playerData);setProfile(profileData);setFirstName(profileData?.first_name??"");setLastName(profileData?.last_name??"");setDisplayName(profileData?.display_name??"");setPhone(profileData?.phone??"");setPosition(profileData?.preferred_position??"");
   if(profileData?.avatar_path)setAvatarUrl(supabase.storage.from("profile-avatars").getPublicUrl(profileData.avatar_path).data.publicUrl);
   setIsAdmin((roleData??[]).some(r=>["admin","super_admin","league_admin"].includes(r.role)));
   const ms=membershipData??[];setMemberships(ms);
   if(ms.length){const {data:teamData}=await supabase.from("season_teams").select("id,name,season_id").in("id",ms.map(m=>m.season_team_id));if(alive)setTeams(teamData??[]);}
   if(alive)setLoading(false);
  }
  void load();const {data:{subscription}}=supabase.auth.onAuthStateChange((_event,next)=>{setSession(next);if(!next){setPlayer(null);setMemberships([]);setTeams([]);}});
  return()=>{alive=false;subscription.unsubscribe();};
 },[]);
 async function signOut(){await getSupabaseClient().auth.signOut();await navigate({to:"/"});}
 async function saveProfile(event:React.FormEvent<HTMLFormElement>){event.preventDefault();if(!session)return;setSaving(true);setError("");try{const {data,error:saveError}=await getSupabaseClient().from("profiles").update({first_name:firstName.trim()||null,last_name:lastName.trim()||null,display_name:displayName.trim()||null,phone:phone.trim()||null,preferred_position:position||null}).eq("id",session.user.id).select("first_name,last_name,display_name,phone,preferred_position,avatar_path").single();if(saveError)throw saveError;setProfile(data);setEditing(false);}catch(cause){setError(cause instanceof Error?cause.message:"Unable to save your profile.");}finally{setSaving(false);}}
 async function uploadAvatar(event:React.ChangeEvent<HTMLInputElement>){const file=event.target.files?.[0];if(!file||!session)return;setError("");if(!["image/jpeg","image/png","image/webp"].includes(file.type)){setError("Choose a JPG, PNG or WebP image.");return;}if(file.size>5*1024*1024){setError("Profile pictures must be 5 MB or smaller.");return;}setSaving(true);try{const ext=file.type==="image/jpeg"?"jpg":file.type==="image/png"?"png":"webp";const path=session.user.id+"/"+crypto.randomUUID()+"."+ext;const storage=getSupabaseClient().storage.from("profile-avatars");const {error:uploadError}=await storage.upload(path,file,{contentType:file.type,upsert:false});if(uploadError)throw uploadError;const {data,error:updateError}=await getSupabaseClient().from("profiles").update({avatar_path:path}).eq("id",session.user.id).select("first_name,last_name,display_name,phone,preferred_position,avatar_path").single();if(updateError)throw updateError;setProfile(data);setAvatarUrl(storage.getPublicUrl(path).data.publicUrl);}catch(cause){setError(cause instanceof Error?cause.message:"Unable to upload your profile picture.");}finally{setSaving(false);event.target.value="";}}
 if(loading)return <main className="notice-page"><section className="notice-panel"><p>Loading your Player Hub…</p></section></main>;
 if(!session)return <main className="notice-page"><section className="notice-panel"><Link className="notice-brand" to="/">OPEN PLAY</Link><p className="eyebrow eyebrow-dark">PLAYER HUB</p><h1>Your game.<br/><em>Your account.</em></h1><p>Sign in to see your player profile, team requests and memberships.</p><Link className="button" to="/sign-in">SIGN IN <span>↗</span></Link></section></main>;
 const teamName=(id:string)=>teams.find(t=>t.id===id)?.name??"Team";
 return <main className="notice-page"><section className="notice-panel hub-panel">
  <div className="hub-top"><Link className="notice-brand" to="/">OPEN PLAY</Link><button className="auth-text-button" onClick={signOut}>Sign out</button></div>
  <p className="eyebrow eyebrow-dark">PLAYER HUB</p><h1>Your game.<br/><em>Your account.</em></h1><p className="hub-email">{session.user.email}</p>
  {error&&<p className="form-error" role="alert">{error}</p>}
  {!player?<section className="hub-empty"><span className="hub-kicker">PROFILE NOT YET REGISTERED</span><h2>Start your player profile.</h2><p>Your Open Play account is ready. Register once to create your permanent player identity. You are not automatically added to a team.</p><Link className="button" to="/register-player">REGISTER AS A PLAYER <span>↗</span></Link></section>:<>
   <section className="hub-profile"><span className="hub-kicker">PLAYER PROFILE</span><div className="hub-profile-head">{avatarUrl?<img className="hub-avatar" src={avatarUrl} alt="Your profile"/>:<div className="hub-avatar hub-avatar-empty" aria-hidden="true">{player.full_name.slice(0,1).toUpperCase()}</div>}<div><h2>{player.full_name}</h2><p>{profile?.display_name||"Your player account"}</p></div></div><label className="avatar-upload">Change profile picture<input type="file" accept="image/jpeg,image/png,image/webp" onChange={uploadAvatar} disabled={saving}/></label><button type="button" className="auth-text-button" onClick={()=>setEditing(v=>!v)}>{editing?"Cancel profile edit":"Edit profile details"}</button>{editing&&<form className="auth-form hub-edit-form" onSubmit={saveProfile}><label>First name<input value={firstName} onChange={e=>setFirstName(e.target.value)} maxLength={80}/></label><label>Last name<input value={lastName} onChange={e=>setLastName(e.target.value)} maxLength={80}/></label><label>Display name<input value={displayName} onChange={e=>setDisplayName(e.target.value)} maxLength={100}/></label><label>Contact phone<input type="tel" value={phone} onChange={e=>setPhone(e.target.value)} maxLength={30}/></label><label>Preferred position<select value={position} onChange={e=>setPosition(e.target.value)}><option value="">Not specified</option><option value="Goalkeeper">Goalkeeper</option><option value="Defender">Defender</option><option value="Midfielder">Midfielder</option><option value="Forward">Forward</option><option value="Any">Any position</option></select></label><button className="button button-small" disabled={saving}>{saving?"SAVING…":"SAVE PROFILE"}</button></form> }<p>Registration: <strong>{player.registration_status.replace("_"," ")}</strong></p>{player.is_banned&&<p className="form-error">Your player account is currently restricted. Contact Open Play support.</p>}
   {player.registration_status==="registered"&&!player.is_banned&&<Link className="button button-small" to="/join">JOIN OR REGISTER A TEAM <span>↗</span></Link>}{memberships.some(m=>m.is_captain&&m.status==="active")&&<Link className="button button-small captain-link" to="/captain">OPEN CAPTAINS HUB <span>↗</span></Link>}
   {player.registration_status==="pending_review"&&<p className="form-note">Your registration is awaiting an identity review. Team requests will become available after approval.</p>}
   {player.registration_status==="rejected"&&<p className="form-note">Your registration was not approved. Please contact Open Play support for assistance.</p>}
   </section>
   <section className="hub-memberships"><div className="hub-section-heading"><span className="hub-kicker">YOUR TEAMS</span><span>{memberships.length}</span></div>
    {memberships.length===0?<p className="form-note">You are not currently linked to a team. Once your player registration is approved, you can request to join one or register a team.</p>:memberships.map(m=><article className="hub-team-row" key={m.id}><div><strong>{teamName(m.season_team_id)}</strong><span>{m.is_captain?"Captain":m.status==="active"?"Player":m.status.replace("_"," ")}</span></div><span className={m.status==="active"?"status-active":"status-pending"}>{m.status.replace("_"," ")}</span></article>)}
   </section>
  </>}
  {isAdmin&&<Link className="button button-small admin-link" to="/admin">OPEN ADMIN DASHBOARD <span>↗</span></Link>}<Link className="auth-switch" to="/">Back to Open Play</Link>
 </section></main>;
}
