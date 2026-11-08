import { useEffect,useState } from "react";
import { Link,createFileRoute } from "@tanstack/react-router";
import { SiteNavigation } from "../components/site-navigation";
import { getSupabaseClient } from "../lib/supabase/client";

type PublicSeason={id:string;name:string};
type PublicTeam={id:string;name:string;season_id:string;primary_colour:string|null;secondary_colour:string|null;teams:{instagram_profile_url:string|null}|null};

export const Route=createFileRoute("/teams/$teamId")({component:PublicTeamProfilePage});

function PublicTeamProfilePage(){
 const {teamId}=Route.useParams();
 const [team,setTeam]=useState<PublicTeam|null>(null);
 const [seasonName,setSeasonName]=useState("");
 const [loading,setLoading]=useState(true);
 const [error,setError]=useState("");

 useEffect(()=>{
  let alive=true;
  async function load(){
   const supabase=getSupabaseClient();
   const {data:seasonData,error:seasonError}=await supabase.from("seasons").select("id,name").eq("is_public",true).in("status",["active","completed"]);
   if(!alive)return;
   if(seasonError){setError("Unable to load this team profile.");setLoading(false);return;}
   const seasons=(seasonData??[]) as PublicSeason[];
   if(!seasons.length){setLoading(false);return;}
   const {data,error:teamError}=await supabase.from("season_teams").select("id,name,season_id,primary_colour,secondary_colour,teams(instagram_profile_url)").eq("id",teamId).eq("registration_status","approved").in("season_id",seasons.map(s=>s.id)).maybeSingle();
   if(!alive)return;
   if(teamError){setError("Unable to load this team profile.");setLoading(false);return;}
   const found=(data??null) as PublicTeam|null;
   setTeam(found);
   setSeasonName(seasons.find(s=>s.id===found?.season_id)?.name??"");
   setLoading(false);
  }
  void load();
  return()=>{alive=false;};
 },[teamId]);

 return <main className="notice-page"><SiteNavigation/><section className="notice-panel hub-panel"><Link className="notice-brand" to="/">OPEN PLAY</Link><p className="eyebrow eyebrow-dark">TEAM PROFILE</p>
  {loading?<p className="form-note">Loading team profile…</p>:error?<p className="form-error" role="alert">{error}</p>:!team?<section className="hub-empty"><h1>Team not available.</h1><p>This team may not be part of a published season.</p></section>:<>
   <span className="team-colour-mark team-profile-colour" style={{background:team.primary_colour??"#e96831"}}/>
   <h1>{team.name}</h1><p>{seasonName}</p>
   <div className="team-profile-colours"><span>Primary colour: {team.primary_colour??"Not set"}</span><span>Secondary colour: {team.secondary_colour??"Not set"}</span></div>
   {team.teams?.instagram_profile_url&&<a className="team-instagram-link team-profile-instagram" href={team.teams.instagram_profile_url} target="_blank" rel="noopener noreferrer" aria-label={`Visit ${team.name} on Instagram`}><svg viewBox="0 0 24 24" aria-hidden="true"><rect x="3" y="3" width="18" height="18" rx="5" fill="none" stroke="currentColor" strokeWidth="1.8"/><circle cx="12" cy="12" r="4" fill="none" stroke="currentColor" strokeWidth="1.8"/><circle cx="17.5" cy="6.8" r="1.1" fill="currentColor"/></svg><span>Visit Instagram</span></a>}
  </>}
  <Link className="auth-switch" to="/teams">Back to teams</Link><Link className="auth-switch" to="/match-centre">View match centre</Link>
 </section></main>;
}
