import { useEffect, useState } from "react";
import { Link, createFileRoute, useNavigate } from "@tanstack/react-router";
import type { Session } from "@supabase/supabase-js";
import { getSupabaseClient } from "../lib/supabase/client";

type Player = { id:string; full_name:string; registration_status:"registered"|"pending_review"|"rejected"; is_banned:boolean };
type Membership = { id:string; season_team_id:string; status:"pending"|"active"|"suspended"|"left"|"rejected"; is_captain:boolean; squad_number:number|null; joined_at:string|null };
type Team = { id:string; name:string; season_id:string };

export const Route=createFileRoute("/player")({component:PlayerHubPage});

function PlayerHubPage(){
 const navigate=useNavigate();const [session,setSession]=useState<Session|null>(null);const [player,setPlayer]=useState<Player|null>(null);const [memberships,setMemberships]=useState<Membership[]>([]);const [teams,setTeams]=useState<Team[]>([]);const [loading,setLoading]=useState(true);const [error,setError]=useState("");
 useEffect(()=>{let alive=true;const supabase=getSupabaseClient();
  async function load(){const {data:{session:current}}=await supabase.auth.getSession();if(!alive)return;setSession(current);
   if(!current){setLoading(false);return;}
   const [{data:playerData,error:playerError},{data:membershipData,error:membershipError}]=await Promise.all([
    supabase.from("players").select("id,full_name,registration_status,is_banned").eq("user_id",current.user.id).maybeSingle(),
    supabase.from("team_memberships").select("id,season_team_id,status,is_captain,squad_number,joined_at").eq("user_id",current.user.id).order("created_at",{ascending:false}),
   ]);
   if(!alive)return;if(playerError||membershipError)setError(playerError?.message??membershipError?.message??"Unable to load your player hub.");
   setPlayer(playerData);const ms=membershipData??[];setMemberships(ms);
   if(ms.length){const {data:teamData}=await supabase.from("season_teams").select("id,name,season_id").in("id",ms.map(m=>m.season_team_id));if(alive)setTeams(teamData??[]);}
   if(alive)setLoading(false);
  }
  void load();const {data:{subscription}}=supabase.auth.onAuthStateChange((_event,next)=>{setSession(next);if(!next){setPlayer(null);setMemberships([]);setTeams([]);}});
  return()=>{alive=false;subscription.unsubscribe();};
 },[]);
 async function signOut(){await getSupabaseClient().auth.signOut();await navigate({to:"/"});}
 if(loading)return <main className="notice-page"><section className="notice-panel"><p>Loading your Player Hub…</p></section></main>;
 if(!session)return <main className="notice-page"><section className="notice-panel"><Link className="notice-brand" to="/">OPEN PLAY</Link><p className="eyebrow eyebrow-dark">PLAYER HUB</p><h1>Your game.<br/><em>Your account.</em></h1><p>Sign in to see your player profile, team requests and memberships.</p><Link className="button" to="/sign-in">SIGN IN <span>↗</span></Link></section></main>;
 const teamName=(id:string)=>teams.find(t=>t.id===id)?.name??"Team";
 return <main className="notice-page"><section className="notice-panel hub-panel">
  <div className="hub-top"><Link className="notice-brand" to="/">OPEN PLAY</Link><button className="auth-text-button" onClick={signOut}>Sign out</button></div>
  <p className="eyebrow eyebrow-dark">PLAYER HUB</p><h1>Your game.<br/><em>Your account.</em></h1><p className="hub-email">{session.user.email}</p>
  {error&&<p className="form-error" role="alert">{error}</p>}
  {!player?<section className="hub-empty"><span className="hub-kicker">PROFILE NOT YET REGISTERED</span><h2>Start your player profile.</h2><p>Your Open Play account is ready. Register once to create your permanent player identity. You are not automatically added to a team.</p><Link className="button" to="/register-player">REGISTER AS A PLAYER <span>↗</span></Link></section>:<>
   <section className="hub-profile"><span className="hub-kicker">PLAYER PROFILE</span><h2>{player.full_name}</h2><p>Registration: <strong>{player.registration_status.replace("_"," ")}</strong></p>{player.is_banned&&<p className="form-error">Your player account is currently restricted. Contact Open Play support.</p>}
   {player.registration_status==="registered"&&!player.is_banned&&<Link className="button button-small" to="/join">JOIN OR REGISTER A TEAM <span>↗</span></Link>}
   {player.registration_status==="pending_review"&&<p className="form-note">Your registration is awaiting an identity review. Team requests will become available after approval.</p>}
   {player.registration_status==="rejected"&&<p className="form-note">Your registration was not approved. Please contact Open Play support for assistance.</p>}
   </section>
   <section className="hub-memberships"><div className="hub-section-heading"><span className="hub-kicker">YOUR TEAMS</span><span>{memberships.length}</span></div>
    {memberships.length===0?<p className="form-note">You are not currently linked to a team. Once your player registration is approved, you can request to join one or register a team.</p>:memberships.map(m=><article className="hub-team-row" key={m.id}><div><strong>{teamName(m.season_team_id)}</strong><span>{m.is_captain?"Captain":m.status==="active"?"Player":m.status.replace("_"," ")}</span></div><span className={m.status==="active"?"status-active":"status-pending"}>{m.status.replace("_"," ")}</span></article>)}
   </section>
  </>}
  <Link className="auth-switch" to="/">Back to Open Play</Link>
 </section></main>;
}
