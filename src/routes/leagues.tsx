import { useEffect,useState } from "react";
import { Link,createFileRoute } from "@tanstack/react-router";
import { RefereeBottomNavigation } from "../components/referee-bottom-navigation";
import { getSupabaseClient } from "../lib/supabase/client";

type Location={id:string;name:string;town:string;region:string};
type League={id:string;location_id:string;name:string};
type Season={id:string;name:string;league_id:string;status:"draft"|"registration_open"|"active"|"completed";recruitment_status:"closed"|"open"|"closed_after_opening";starts_on:string|null};

const dateLabel=(value:string|null)=>value?new Date(value+"T00:00:00").toLocaleDateString("en-GB",{day:"numeric",month:"long",year:"numeric"}):"Start date to be confirmed";
const seasonStatus=(season:Season)=>season.recruitment_status==="open"?"Recruiting open":season.status==="draft"?"Coming soon · recruiting closed":season.status==="completed"?"Season completed":"Recruiting closed";

export const Route=createFileRoute("/leagues")({component:PublicLeaguesPage});

function PublicLeaguesPage(){
 const [locations,setLocations]=useState<Location[]>([]);
 const [leagues,setLeagues]=useState<League[]>([]);
 const [seasons,setSeasons]=useState<Season[]>([]);
 const [loading,setLoading]=useState(true);
 const [error,setError]=useState("");

 useEffect(()=>{
  let alive=true;
  async function load(){
   setLoading(true);setError("");
   const supabase=getSupabaseClient();
   const {data:locationRows,error:locationError}=await supabase.from("locations")
    .select("id,name,town,region").eq("is_active",true).order("name");
   if(!alive)return;
   if(locationError)throw locationError;
   const activeLocations=(locationRows??[]) as Location[];
   setLocations(activeLocations);
   if(activeLocations.length===0){setLoading(false);return;}
   const {data:leagueRows,error:leagueError}=await supabase.from("leagues")
    .select("id,location_id,name").eq("is_published",true)
    .in("location_id",activeLocations.map(location=>location.id)).order("name");
   if(!alive)return;
   if(leagueError)throw leagueError;
   const publishedLeagues=(leagueRows??[]) as League[];
   setLeagues(publishedLeagues);
   if(publishedLeagues.length===0){setLoading(false);return;}
   const {data:seasonRows,error:seasonError}=await supabase.from("seasons")
    .select("id,name,league_id,status,recruitment_status,starts_on")
    .eq("is_public",true).in("status",["draft","registration_open","active","completed"])
    .in("league_id",publishedLeagues.map(league=>league.id))
    .order("starts_on",{ascending:false,nullsFirst:false});
   if(!alive)return;
   if(seasonError)throw seasonError;
   setSeasons((seasonRows??[]) as Season[]);
   setLoading(false);
  }
  void load().catch(()=>{if(!alive)return;setError("We couldn't load the public league directory. Please try again.");setLoading(false);});
  return()=>{alive=false;};
 },[]);

 return <main className="notice-page player-facing"><section className="notice-panel hub-panel">
  <Link className="notice-brand" to="/"><img className="open-play-logo" src="/open-play-logo.png" alt="Open Play"/></Link>
  <p className="eyebrow eyebrow-dark">PUBLIC LEAGUE DIRECTORY</p>
  <h1>Find your<br/><em>competition.</em></h1>
  <p>Explore published Open Play locations, leagues and seasons. Recruitment only opens when an administrator activates it.</p>
  {error&&<p className="form-error" role="alert">{error}</p>}
  {loading?<p className="form-note" role="status">Loading locations and leagues…</p>:locations.length===0?<section className="hub-empty"><h2>No locations published yet.</h2><p>Open Play league information will appear here when a location is activated and published.</p></section>:locations.map(location=>{
   const locationLeagues=leagues.filter(league=>league.location_id===location.id);
   return <section className="finance-section" key={location.id}>
    <div className="hub-section-heading"><span className="hub-kicker">{location.town.toUpperCase()}</span><span>{location.region}</span></div>
    <h2>{location.name}</h2>
    {locationLeagues.length===0?<p className="form-note">No public leagues are currently listed for this location.</p>:locationLeagues.map(league=>{
     const leagueSeasons=seasons.filter(season=>season.league_id===league.id);
     return <article className="league-directory-card" key={league.id}>
      <h3>{league.name}</h3>
      {leagueSeasons.length===0?<p className="form-note">No public seasons have been announced.</p>:leagueSeasons.map(season=><div className="league-directory-season" key={season.id}>
       <div><strong>{season.name}</strong><span>{dateLabel(season.starts_on)}</span></div>
       <span className={season.recruitment_status==="open"?"player-recruitment-status is-open":"player-recruitment-status"}>{seasonStatus(season)}</span>
      </div>)}
     </article>;
    })}
   </section>;
  })}
  <section className="hub-memberships"><div className="hub-section-heading"><span className="hub-kicker">EXPLORE OPEN PLAY</span></div>
   <Link className="admin-inline-action" to="/teams">BROWSE TEAMS <span aria-hidden="true">↗</span></Link>
   <Link className="admin-inline-action" to="/match-centre">FIXTURES, RESULTS &amp; TABLES <span aria-hidden="true">↗</span></Link>
   <Link className="admin-inline-action" to="/join">JOIN OPEN PLAY <span aria-hidden="true">↗</span></Link>
  </section>
  <Link className="auth-switch" to="/">Back to Open Play home</Link>
 </section><RefereeBottomNavigation/></main>;
}
