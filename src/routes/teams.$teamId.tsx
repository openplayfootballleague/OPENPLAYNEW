import { useEffect,useState } from "react";
import { Link,createFileRoute } from "@tanstack/react-router";
import { SiteNavigation } from "../components/site-navigation";
import { getSupabaseClient } from "../lib/supabase/client";

type PublicTeam={season_team_id:string;team_name:string;season_id:string;season_name:string;starts_on:string;primary_colour:string|null;secondary_colour:string|null;instagram_profile_url:string|null};

export const Route=createFileRoute("/teams/$teamId")({component:PublicTeamProfilePage});

function PublicTeamProfilePage(){
 const {teamId}=Route.useParams();
 const [team,setTeam]=useState<PublicTeam|null>(null);
 const [loading,setLoading]=useState(true);
 const [error,setError]=useState("");

 useEffect(()=>{
  let alive=true;
  async function load(){
   const {data,error:rpcError}=await getSupabaseClient().rpc("get_public_team_directory",{p_season_team_id:teamId});
   if(!alive)return;
   if(rpcError){setError("Unable to load this team profile.");setLoading(false);return;}
   setTeam(((data??[]) as PublicTeam[])[0]??null);
   setLoading(false);
  }
  void load();
  return()=>{alive=false;};
 },[teamId]);

 return <main className="notice-page"><SiteNavigation/><section className="notice-panel hub-panel"><Link className="notice-brand" to="/">OPEN PLAY</Link><p className="eyebrow eyebrow-dark">TEAM PROFILE</p>
  {loading?<p className="form-note">Loading team profile…</p>:error?<p className="form-error" role="alert">{error}</p>:!team?<section className="hub-empty"><h1>Team not available.</h1><p>This team may not be part of a published season.</p></section>:<>
   <span className="team-colour-mark team-profile-colour" style={{background:team.primary_colour??"#e96831"}}/>
   <h1>{team.team_name}</h1><p>{team.season_name}</p>
   <div className="team-profile-colours"><span>Primary colour: {team.primary_colour??"Not set"}</span><span>Secondary colour: {team.secondary_colour??"Not set"}</span></div>
   {team.instagram_profile_url&&<a className="team-instagram-link team-profile-instagram" href={team.instagram_profile_url} target="_blank" rel="noopener noreferrer" aria-label={"Visit "+team.team_name+" on Instagram"}><svg viewBox="0 0 24 24" aria-hidden="true"><rect x="3" y="3" width="18" height="18" rx="5" fill="none" stroke="currentColor" strokeWidth="1.8"/><circle cx="12" cy="12" r="4" fill="none" stroke="currentColor" strokeWidth="1.8"/><circle cx="17.5" cy="6.8" r="1.1" fill="currentColor"/></svg><span>Visit Instagram</span></a>}
  </>}
  <Link className="auth-switch" to="/teams">Back to teams</Link><Link className="auth-switch" to="/match-centre">View match centre</Link>
 </section></main>;
}
