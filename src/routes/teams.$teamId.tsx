import { useEffect,useState } from "react";
import { Link,createFileRoute } from "@tanstack/react-router";
import { RefereeBottomNavigation } from "../components/referee-bottom-navigation";
import { getSupabaseClient } from "../lib/supabase/client";

type Team={id:string;name:string;season_id:string;primary_colour:string|null;secondary_colour:string|null};
type Fixture={id:string;gameweek:number;scheduled_at:string|null;status:string;home_team_id:string;away_team_id:string};
type Result={fixture_id:string;home_score:number;away_score:number};

const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const dateTime=(value:string|null)=>value?new Date(value).toLocaleString("en-GB",{dateStyle:"medium",timeStyle:"short"}):"Time to be confirmed";

export const Route=createFileRoute("/teams/$teamId")({component:PublicTeamProfilePage});

function PublicTeamProfilePage(){
 const {teamId}=Route.useParams();
 const [team,setTeam]=useState<Team|null>(null);
 const [teams,setTeams]=useState<Team[]>([]);
 const [fixtures,setFixtures]=useState<Fixture[]>([]);
 const [results,setResults]=useState<Result[]>([]);
 const [loading,setLoading]=useState(true);
 const [error,setError]=useState("");

 useEffect(()=>{
  let alive=true;
  async function load(){
   setLoading(true);setError("");setTeam(null);setTeams([]);setFixtures([]);setResults([]);
   if(!UUID.test(teamId)){setError("This team profile link is invalid.");setLoading(false);return;}
   const supabase=getSupabaseClient();
   const {data:teamRow,error:teamError}=await supabase.from("season_teams")
    .select("id,name,season_id,primary_colour,secondary_colour")
    .eq("id",teamId).eq("registration_status","approved").maybeSingle();
   if(!alive)return;
   if(teamError){setError("We couldn't load this team profile. Please try again.");setLoading(false);return;}
   if(!teamRow){setError("This team profile is unavailable. It may no longer be published.");setLoading(false);return;}
   const currentTeam=teamRow as Team;
   const [{data:teamRows,error:teamsError},{data:fixtureRows,error:fixturesError}]=await Promise.all([
    supabase.from("season_teams").select("id,name,season_id,primary_colour,secondary_colour")
     .eq("season_id",currentTeam.season_id).eq("registration_status","approved"),
    supabase.from("fixtures").select("id,gameweek,scheduled_at,status,home_team_id,away_team_id")
     .eq("season_id",currentTeam.season_id)
     .or(`home_team_id.eq.${teamId},away_team_id.eq.${teamId}`)
     .order("scheduled_at",{ascending:true}),
   ]);
   if(!alive)return;
   if(teamsError||fixturesError){setError("The team is available, but its match schedule couldn't be loaded.");setTeam(currentTeam);setLoading(false);return;}
   const fixtureList=(fixtureRows??[]) as Fixture[];
   const {data:resultRows,error:resultsError}=fixtureList.length
    ?await supabase.from("fixture_results").select("fixture_id,home_score,away_score").in("fixture_id",fixtureList.map(f=>f.id))
    :{data:[],error:null};
   if(!alive)return;
   if(resultsError){setError("The team is available, but match results couldn't be loaded.");setTeam(currentTeam);setTeams((teamRows??[]) as Team[]);setFixtures(fixtureList);setLoading(false);return;}
   setTeam(currentTeam);setTeams((teamRows??[]) as Team[]);setFixtures(fixtureList);setResults((resultRows??[]) as Result[]);setLoading(false);
  }
  void load().catch(()=>{if(!alive)return;setError("We couldn't load this team profile. Please try again.");setLoading(false);});
  return()=>{alive=false;};
 },[teamId]);

 const names=new Map(teams.map(item=>[item.id,item.name]));
 const resultMap=new Map(results.map(result=>[result.fixture_id,result]));
 return <main className="notice-page player-facing"><section className="notice-panel hub-panel">
  <Link className="notice-brand" to="/"><img className="open-play-logo" src="/open-play-logo.png" alt="Open Play"/></Link>
  <p className="eyebrow eyebrow-dark">PUBLIC TEAM PROFILE</p>
  {loading?<p className="form-note" role="status">Loading team profile…</p>:error&&!team?<section className="hub-empty"><h1>Team unavailable.</h1><p className="form-error" role="alert">{error}</p><Link className="button" to="/teams">BACK TO TEAMS</Link></section>:team?<>
   <span className="team-colour-mark" style={{background:team.primary_colour??"#e96831"}} aria-hidden="true"/>
   <h1>{team.name}</h1>
   <p>Competing in Open Play this season.</p>
   {team.primary_colour||team.secondary_colour?<section className="finance-section"><div className="hub-section-heading"><span className="hub-kicker">TEAM COLOURS</span></div><p className="form-note">Primary: {team.primary_colour??"Not set"} · Secondary: {team.secondary_colour??"Not set"}</p></section>:null}
   {error&&<p className="form-error" role="alert">{error}</p>}
   <section className="finance-section"><div className="hub-section-heading"><span className="hub-kicker">FIXTURES &amp; RESULTS</span><span>{fixtures.length} matches</span></div>
    {fixtures.length===0?<p className="form-note">No fixtures have been published for this team yet.</p>:fixtures.map(f=>{const result=resultMap.get(f.id);const home=f.home_team_id===team.id;const opponentId=home?f.away_team_id:f.home_team_id;return <article className="match-row" key={f.id}><div className="match-meta"><span>GAMEWEEK {f.gameweek}</span><span>{dateTime(f.scheduled_at)}</span></div><div className="match-score"><strong>{home?"Home":"Away"}</strong><b>{result?home?`${result.home_score} – ${result.away_score}`:`${result.away_score} – ${result.home_score}`:"v"}</b><strong>{names.get(opponentId)??"Opponent"}</strong></div><p className="form-note">{result?"Result published":f.status.replaceAll("_"," ")}</p></article>;})}
   </section>
  </>:null}
  <Link className="auth-switch" to="/teams">← Back to all teams</Link><Link className="auth-switch" to="/match-centre">View match centre</Link>
 </section><RefereeBottomNavigation/></main>;
}
