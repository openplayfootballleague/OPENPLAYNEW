import { useEffect,useState } from "react";
import { RefereeBottomNavigation } from "../components/referee-bottom-navigation";
import { PlayerCompetitionSelector, usePlayerCompetitionContext } from "../lib/competition/player-context";
import { Link,createFileRoute } from "@tanstack/react-router";
import { getSupabaseClient } from "../lib/supabase/client";

type TeamRow={season_team_id:string;team_name:string;season_id:string;season_name:string;starts_on:string|null;primary_colour:string|null;secondary_colour:string|null;instagram_profile_url:string|null;instagram_handle:string|null};

export const Route=createFileRoute("/teams")({component:TeamsPage});

function TeamsPage(){
 const competition=usePlayerCompetitionContext();
 const [teams,setTeams]=useState<TeamRow[]>([]);
 const [loading,setLoading]=useState(false);
 const [error,setError]=useState("");

 useEffect(()=>{
  if(competition.loading)return;
  if(!competition.selectedSeasonId){setTeams([]);setLoading(false);return;}
  let alive=true;setLoading(true);setError("");
  async function load(){
   const {data,error:teamError}=await getSupabaseClient().rpc("get_public_team_directory",{p_season_id:competition.selectedSeasonId});
   if(!alive)return;
   if(teamError)setError(teamError.message);
   setTeams((data??[]) as TeamRow[]);setLoading(false);
  }
  void load();return()=>{alive=false;};
 },[competition.loading,competition.selectedSeasonId]);

 const selectedSeason=competition.seasons.find((season)=>season.id===competition.selectedSeasonId);

 return <main className="notice-page player-facing"><section className="notice-panel hub-panel">
  <Link className="notice-brand" to="/player"><img className="open-play-logo" src="/open-play-logo.png" alt="Open Play"/></Link><p className="eyebrow eyebrow-dark">PUBLIC TEAM DIRECTORY</p><h1>Meet the<br/><em>teams.</em></h1><p>Explore approved teams competing in Open Play.</p>
  <PlayerCompetitionSelector context={competition}/>
  {error&&<p className="form-error" role="alert">{error}</p>}
  {loading?<p className="form-note">Loading teams…</p>:!competition.selectedSeasonId?<section className="hub-empty"><h2>No public season available yet.</h2><p>Published teams will appear here when a location and season are active.</p><Link className="button" to="/join">JOIN OPEN PLAY <span>↗</span></Link></section>:teams.length===0?<section className="hub-empty"><h2>No teams published yet.</h2><p>Approved teams will appear here when a public season is active.</p><Link className="button" to="/join">JOIN OPEN PLAY <span>↗</span></Link></section>:<section className="hub-memberships"><div className="hub-section-heading"><span className="hub-kicker">{selectedSeason?.name??"CURRENT SEASON"}</span><span>{teams.length} teams</span></div>{teams.map(team=><article className="directory-team" key={team.season_team_id}><span className="team-colour-mark" style={{background:team.primary_colour??"#e96831"}}/><div><Link className="directory-team-profile-link" to="/teams/$teamId" params={{teamId:team.season_team_id}}><strong>{team.team_name}</strong></Link><span>{team.secondary_colour?`Primary ${team.primary_colour??"not set"} · Secondary ${team.secondary_colour}`:"Open Play team"}</span>{team.instagram_handle&&!team.instagram_profile_url&&<small>@{team.instagram_handle}</small>}{team.instagram_profile_url&&<a className="team-instagram-link" href={team.instagram_profile_url} target="_blank" rel="noopener noreferrer" aria-label={`Visit ${team.team_name} on Instagram`} title={`Visit ${team.team_name} on Instagram`}><svg viewBox="0 0 24 24" aria-hidden="true"><rect x="3" y="3" width="18" height="18" rx="5" fill="none" stroke="currentColor" strokeWidth="1.8"/><circle cx="12" cy="12" r="4" fill="none" stroke="currentColor" strokeWidth="1.8"/><circle cx="17.5" cy="6.8" r="1.1" fill="currentColor"/></svg></a>}</div></article>)}</section>}
  <Link className="auth-switch" to="/match-centre">View match centre</Link><Link className="auth-switch" to="/">Back to Open Play</Link>
 </section><RefereeBottomNavigation /></main>;
}
