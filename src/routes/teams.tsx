import { useEffect,useRef,useState } from "react";
import { RefereeBottomNavigation } from "../components/referee-bottom-navigation";
import { PlayerCompetitionSelector, usePlayerCompetitionContext } from "../lib/competition/player-context";
import { Link,createFileRoute } from "@tanstack/react-router";
import { getSupabaseClient } from "../lib/supabase/client";
import { useOpenPlayAnalytics } from "../components/analytics-provider";
import { useRequiredSession } from "../lib/auth/use-required-session";

type TeamRow={id:string;name:string;season_id:string;primary_colour:string|null;secondary_colour:string|null};
type ClubLeader={competition_player_id:string;player_name:string;season_team_id:string;team_name:string;motm_awards:number;appearances:number};

export const Route=createFileRoute("/teams")({component:TeamsPage});

function TeamsPage(){
 const competition=usePlayerCompetitionContext();
 const capture=useOpenPlayAnalytics();
 const [teams,setTeams]=useState<TeamRow[]>([]);
 const [loading,setLoading]=useState(false);
 const [error,setError]=useState("");
 const lastTrackedSeason=useRef("");
 const authStatus=useRequiredSession();
 const [leaders,setLeaders]=useState<ClubLeader[]>([]);
 const [leadersLoading,setLeadersLoading]=useState(false);
 const [leadersError,setLeadersError]=useState("");

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

 useEffect(()=>{
  if(competition.loading||authStatus==='loading')return;
  if(authStatus!=='authenticated'){setLeaders([]);setLeadersLoading(false);setLeadersError('');return;}
  if(!competition.selectedSeasonId){setLeaders([]);setLeadersLoading(false);setLeadersError("");return;}
  let alive=true;setLeadersLoading(true);setLeadersError("");
  void (async()=>{
   try{
    const {data,error:rpcError}=await getSupabaseClient().rpc("get_public_season_club_leaders",{p_season_id:competition.selectedSeasonId});
    if(!alive)return;
    if(rpcError)throw new Error(rpcError.message);
    setLeaders((data??[]) as ClubLeader[]);
   }catch(cause){
    if(alive){setLeaders([]);setLeadersError(cause instanceof Error?cause.message:"Unable to load Club Leaders.");}
   }finally{if(alive)setLeadersLoading(false);}
  })();
  return()=>{alive=false;};
 },[competition.loading,competition.selectedSeasonId,authStatus]);

 const selectedSeason=competition.seasons.find((season)=>season.id===competition.selectedSeasonId);

 return <main className="notice-page player-facing"><section className="notice-panel hub-panel">
  <Link className="notice-brand" to="/player"><img className="open-play-logo" src="/open-play-logo.png" alt="Open Play"/></Link><p className="eyebrow eyebrow-dark">PUBLIC TEAM DIRECTORY</p><h1>Meet the<br/><em>teams.</em></h1><p>Explore approved teams competing in Open Play.</p>
  <PlayerCompetitionSelector context={competition}/>
  {competition.selectedSeasonId&&<section className="hub-memberships club-leaders" aria-label="Club Leaders">
   <div className="hub-section-heading"><span className="hub-kicker">CLUB LEADERS</span><span>{leaders.length} ranked players</span></div>
   {authStatus==='unauthenticated'?<p className="form-note">Club Leaders are visible to signed-in Open Play members. <Link to="/sign-in">Sign in</Link> to see this season's Man of the Match leaders.</p>:authStatus==='loading'||leadersLoading?<p className="form-note">Loading Club Leaders…</p>:leadersError?<p className="form-note" role="status">Club Leaders are temporarily unavailable: {leadersError}</p>:leaders.length===0?<p className="form-note">No Man of the Match awards have been recorded for this season yet.</p>:leaders.map((leader,index)=><article className="directory-team" key={leader.competition_player_id+"-"+leader.season_team_id}>
    <span className="leader-rank">{index+1}</span>
    <div><strong>{leader.player_name}</strong><span>{leader.team_name} · {leader.motm_awards} Man of the Match · {leader.appearances} appearances</span></div>
   </article>)}
  </section>}
  {error&&<p className="form-error" role="alert">{error}</p>}
  {loading?<p className="form-note">Loading teams…</p>:!competition.selectedSeasonId?<section className="hub-empty"><h2>No public season available yet.</h2><p>Published teams will appear here when a location and season are active.</p><Link className="button" to="/join">JOIN OPEN PLAY <span>↗</span></Link></section>:teams.length===0?<section className="hub-empty"><h2>No teams published yet.</h2><p>Approved teams will appear here when a public season is active.</p><Link className="button" to="/join">JOIN OPEN PLAY <span>↗</span></Link></section>:<section className="hub-memberships"><div className="hub-section-heading"><span className="hub-kicker">{selectedSeason?.name??"CURRENT SEASON"}</span><span>{teams.length} teams</span></div>{teams.map(team=><Link className="directory-team" key={team.id} to="/teams/$teamId" params={{teamId:team.id}} aria-label={`View ${team.name} team profile`}><span className="team-colour-mark" style={{background:team.primary_colour??"#e96831"}}/><div><strong>{team.name}</strong><span>{team.secondary_colour?`Primary ${team.primary_colour??"not set"} · Secondary ${team.secondary_colour}`:"Open Play team"}</span></div><span aria-hidden="true">↗</span></Link>)}</section>}
  <Link className="auth-switch" to="/match-centre">View match centre</Link><Link className="auth-switch" to="/">Back to Open Play</Link>
 </section><RefereeBottomNavigation /></main>;
}
