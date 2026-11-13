import { useEffect,useRef,useState } from "react";
import { RefereeBottomNavigation } from "../components/referee-bottom-navigation";
import { PlayerCompetitionSelector, usePlayerCompetitionContext } from "../lib/competition/player-context";
import { Link,createFileRoute } from "@tanstack/react-router";
import { getSupabaseClient } from "../lib/supabase/client";
import { useOpenPlayAnalytics } from "../components/analytics-provider";

type TeamRow={id:string;name:string;season_id:string;primary_colour:string|null;secondary_colour:string|null};

export const Route=createFileRoute("/teams")({component:TeamsPage});

function TeamsPage(){
 const competition=usePlayerCompetitionContext();
 const capture=useOpenPlayAnalytics();
 const [teams,setTeams]=useState<TeamRow[]>([]);
 const [loading,setLoading]=useState(false);
 const [error,setError]=useState("");
 const lastTrackedSeason=useRef("");

 useEffect(()=>{
  if(competition.loading)return;
  if(!competition.selectedSeasonId){setTeams([]);setLoading(false);return;}
  let alive=true;setLoading(true);setError("");
  async function load(){
   const {data,error:teamError}=await getSupabaseClient().from("season_teams").select("id,name,season_id,primary_colour,secondary_colour").eq("season_id",competition.selectedSeasonId).eq("registration_status","approved").order("name");
   if(!alive)return;
   if(teamError){setError(teamError.message);capture("data_load_failed",{feature:"team_directory",error_code:"network_error",outcome:"failure"});}
   setTeams(data??[]);setLoading(false);
  }
  void load();return()=>{alive=false;};
 },[competition.loading,competition.selectedSeasonId,capture]);

 useEffect(()=>{
  if(loading||error||!competition.selectedSeasonId||teams.length===0||lastTrackedSeason.current===competition.selectedSeasonId)return;
  if(capture("core_value_action",{feature:"team_directory",season_id:competition.selectedSeasonId})){
   lastTrackedSeason.current=competition.selectedSeasonId;
  }
 },[capture,competition.selectedSeasonId,error,loading,teams.length]);

 const selectedSeason=competition.seasons.find((season)=>season.id===competition.selectedSeasonId);

 return <main className="notice-page player-facing"><section className="notice-panel hub-panel">
  <Link className="notice-brand" to="/player"><img className="open-play-logo" src="/open-play-logo.png" alt="Open Play"/></Link><p className="eyebrow eyebrow-dark">PUBLIC TEAM DIRECTORY</p><h1>Meet the<br/><em>teams.</em></h1><p>Explore approved teams competing in Open Play.</p>
  <PlayerCompetitionSelector context={competition}/>
  {error&&<p className="form-error" role="alert">{error}</p>}
  {loading?<p className="form-note">Loading teams…</p>:!competition.selectedSeasonId?<section className="hub-empty"><h2>No public season available yet.</h2><p>Published teams will appear here when a location and season are active.</p><Link className="button" to="/join">JOIN OPEN PLAY <span>↗</span></Link></section>:teams.length===0?<section className="hub-empty"><h2>No teams published yet.</h2><p>Approved teams will appear here when a public season is active.</p><Link className="button" to="/join">JOIN OPEN PLAY <span>↗</span></Link></section>:<section className="hub-memberships"><div className="hub-section-heading"><span className="hub-kicker">{selectedSeason?.name??"CURRENT SEASON"}</span><span>{teams.length} teams</span></div>{teams.map(team=><article className="directory-team" key={team.id}><span className="team-colour-mark" style={{background:team.primary_colour??"#e96831"}}/><div><strong>{team.name}</strong><span>{team.secondary_colour?`Primary ${team.primary_colour??"not set"} · Secondary ${team.secondary_colour}`:"Open Play team"}</span></div></article>)}</section>}
  <Link className="auth-switch" to="/match-centre">View match centre</Link><Link className="auth-switch" to="/">Back to Open Play</Link>
 </section><RefereeBottomNavigation /></main>;
}
