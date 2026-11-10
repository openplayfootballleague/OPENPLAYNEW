import { useEffect,useMemo,useState } from "react";
import { RefereeBottomNavigation } from "../components/referee-bottom-navigation";
import { PlayerCompetitionSelector, usePlayerCompetitionContext } from "../lib/competition/player-context";
import { Link,createFileRoute } from "@tanstack/react-router";
import { getSupabaseClient } from "../lib/supabase/client";
import { buildStandings, getJointFirstTeams, type Standing } from "../lib/competition/standings";

type Team={id:string;name:string};
type Fixture={id:string;gameweek:number;scheduled_at:string|null;status:string;home_team_id:string;away_team_id:string};
type Result={fixture_id:string;home_score:number;away_score:number};

export const Route=createFileRoute("/match-centre")({component:MatchCentrePage});

function MatchCentrePage(){
 const competition=usePlayerCompetitionContext();
 const [teams,setTeams]=useState<Team[]>([]);
 const [fixtures,setFixtures]=useState<Fixture[]>([]);
 const [results,setResults]=useState<Result[]>([]);
 const [loading,setLoading]=useState(false);
 const [error,setError]=useState("");

 useEffect(()=>{
  if(competition.loading)return;
  if(!competition.selectedSeasonId){setTeams([]);setFixtures([]);setResults([]);setLoading(false);return;}
  let alive=true;setLoading(true);setError("");
  async function load(){
   const supabase=getSupabaseClient();
   const {data:fixtureData,error:fixtureError}=await supabase.from("fixtures").select("id,gameweek,scheduled_at,status,home_team_id,away_team_id").eq("season_id",competition.selectedSeasonId).order("scheduled_at",{ascending:true});
   if(!alive)return;
   if(fixtureError){setError(fixtureError.message);setLoading(false);return;}
   const fs=fixtureData??[];
   const [teamResult,resultResult]=await Promise.all([
    supabase.from("season_teams").select("id,name").eq("season_id",competition.selectedSeasonId).eq("registration_status","approved"),
    fs.length?supabase.from("fixture_results").select("fixture_id,home_score,away_score").in("fixture_id",fs.map(f=>f.id)):Promise.resolve({data:[],error:null})
   ]);
   if(!alive)return;
   if(teamResult.error||resultResult.error)setError(teamResult.error?.message??resultResult.error?.message??"Unable to load match data.");
   setTeams(teamResult.data??[]);setFixtures(fs);setResults(resultResult.data??[]);setLoading(false);
  }
  void load();return()=>{alive=false;};
 },[competition.loading,competition.selectedSeasonId]);

 const teamName=(id:string)=>teams.find(t=>t.id===id)?.name??"Team";
 const resultMap=new Map(results.map(r=>[r.fixture_id,r]));
 const standings=useMemo<Standing[]>(()=>buildStandings(teams,fixtures,results),[teams,fixtures,results]);
 const jointFirstTeams=useMemo(()=>getJointFirstTeams(standings),[standings]);

 return <main className="notice-page player-facing"><section className="notice-panel match-panel">
  <Link className="notice-brand" to="/player"><img className="open-play-logo" src="/open-play-logo.png" alt="Open Play"/></Link><p className="eyebrow eyebrow-dark">PUBLIC MATCH CENTRE</p><h1>Every game.<br/><em>Every point.</em></h1>
  <PlayerCompetitionSelector context={competition}/>
  {error&&<p className="form-error" role="alert">{error}</p>}
  {loading?<p className="form-note">Loading fixtures and results…</p>:!competition.selectedSeasonId?<p className="form-note">No published season is available for this location yet.</p>:<>
   <section className="match-fixtures"><div className="hub-section-heading"><span className="hub-kicker">FIXTURES &amp; RESULTS</span><span>{fixtures.length} matches</span></div>
    {fixtures.length===0?<p className="form-note">No fixtures have been published for this season.</p>:fixtures.map(f=>{const r=resultMap.get(f.id);return <article className="match-row" key={f.id}><div className="match-meta"><span>GAMEWEEK {f.gameweek}</span><span>{f.scheduled_at?new Date(f.scheduled_at).toLocaleString("en-GB",{dateStyle:"medium",timeStyle:"short"}):f.status.replace("_"," ")}</span></div><div className="match-score"><strong>{teamName(f.home_team_id)}</strong><b>{r? `${r.home_score} – ${r.away_score}`:"v"}</b><strong>{teamName(f.away_team_id)}</strong></div></article>;})}
   </section>
   <section className="match-fixtures"><div className="hub-section-heading"><span className="hub-kicker">LEAGUE TABLE</span><span>{standings.length} teams</span></div>
    {standings.length===0?<p className="form-note">No approved teams in this season.</p>:<><p className="form-note">Teams level on points share the same position. Goal difference does not break a tie.</p>{jointFirstTeams.length>1&&<p className="form-note" role="status">Final required between {jointFirstTeams.map(team=>team.name).join(" and ")} because first place is tied on points.</p>}<div className="table-scroll"><table className="league-table"><thead><tr><th>#</th><th>Team</th><th>P</th><th>W</th><th>D</th><th>L</th><th>GF</th><th>GA</th><th>GD</th><th>Pts</th></tr></thead><tbody>{standings.map(s=><tr key={s.id}><td>{s.position}</td><td>{s.name}</td><td>{s.played}</td><td>{s.won}</td><td>{s.drawn}</td><td>{s.lost}</td><td>{s.for}</td><td>{s.against}</td><td>{s.for-s.against}</td><td><strong>{s.points}</strong></td></tr>)}</tbody></table></div></>}
   </section>
  </>}
  <Link className="auth-switch" to="/teams">Explore teams</Link><Link className="auth-switch" to="/">Back to Open Play</Link>
 </section><RefereeBottomNavigation /></main>;
}
