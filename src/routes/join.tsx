import { useEffect, useState } from "react";
import { SiteNavigation } from "../components/site-navigation";
import { Link, createFileRoute } from "@tanstack/react-router";
import type { Session } from "@supabase/supabase-js";
import { getSupabaseClient } from "../lib/supabase/client";
import { normalizeInstagramProfileUrl } from "../lib/teams/instagram";
import { normalizeInstagramHandle } from "../lib/teams/instagram-handle";
import { useOpenPlayAnalytics } from "../components/analytics-provider";

type SeasonOption = { id: string; name: string };
type TeamOption = { id: string; name: string; season_id: string };
type PlayerState = { registration_status: "registered" | "pending_review" | "rejected"; is_banned: boolean };

export const Route = createFileRoute("/join")({ component: JoinPage });

function JoinPage() {
  const capture=useOpenPlayAnalytics();
  const [session,setSession]=useState<Session|null>(null);
  const [player,setPlayer]=useState<PlayerState|null>(null);
  const [loading,setLoading]=useState(true);
  const [mode,setMode]=useState<"join"|"register">("join");
  const [seasons,setSeasons]=useState<SeasonOption[]>([]);
  const [teams,setTeams]=useState<TeamOption[]>([]);
  const [seasonId,setSeasonId]=useState("");
  const [teamId,setTeamId]=useState("");
  const [teamName,setTeamName]=useState("");
  const [primaryColour,setPrimaryColour]=useState("");
  const [secondaryColour,setSecondaryColour]=useState("");
  const [instagramHandle,setInstagramHandle]=useState("");
  const [instagramProfileUrl,setInstagramProfileUrl]=useState("");
  const [error,setError]=useState("");
  const [message,setMessage]=useState("");
  const [busy,setBusy]=useState(false);

  useEffect(()=>{
    const supabase=getSupabaseClient();
    let alive=true;
    async function load(){
      const {data:{session:current}}=await supabase.auth.getSession();
      if(!alive)return;
      setSession(current);
      if(current){
        const [{data:playerData},{data:seasonData}]=await Promise.all([
          supabase.from("players").select("registration_status,is_banned").eq("user_id",current.user.id).maybeSingle(),
          supabase.from("seasons").select("id,name").eq("status","registration_open").eq("is_public",true).order("starts_on",{ascending:true}),
        ]);
        if(!alive)return;
        setPlayer(playerData);
        const available=seasonData??[];setSeasons(available);if(available[0])setSeasonId(available[0].id);
      }
      if(alive)setLoading(false);
    }
    void load();
    const {data:{subscription}}=supabase.auth.onAuthStateChange((_event,next)=>{setSession(next);if(!next){setPlayer(null);setSeasons([]);setTeams([]);}});
    return ()=>{alive=false;subscription.unsubscribe();};
  },[]);

  useEffect(()=>{
    let alive=true;
    async function loadTeams(){
      setTeams([]);setTeamId("");
      if(!seasonId)return;
      const {data,error:queryError}=await getSupabaseClient().from("season_teams").select("id,name,season_id").eq("season_id",seasonId).eq("registration_status","approved").order("name");
      if(!alive)return;
      if(queryError)setError(queryError.message);else setTeams(data??[]);
    }
    void loadTeams();return ()=>{alive=false;};
  },[seasonId]);

  async function submitJoin(event:React.FormEvent<HTMLFormElement>){
    event.preventDefault();setError("");setMessage("");setBusy(true);
    try{
      if(!teamId)throw new Error("Choose a team first.");
      const {error:rpcError}=await getSupabaseClient().rpc("request_team_membership",{p_season_team_id:teamId});
      if(rpcError)throw rpcError;
      capture("player_join_request_submitted", { feature: "team_membership", outcome: "success" });
      setMessage("Your request has been sent. You will become a team member only after the captain approves it.");
    }catch(cause){capture("workflow_error", { feature: "team_membership", error_code: "unexpected_error", outcome: "failure" });setError(cause instanceof Error?cause.message:"Unable to send your team request.");}
    finally{setBusy(false);}
  }
  async function submitTeam(event:React.FormEvent<HTMLFormElement>){
    event.preventDefault();setError("");setMessage("");setBusy(true);
    try{
      if(!seasonId)throw new Error("There is no open season available for team registration.");
      const handle=normalizeInstagramHandle(instagramHandle);
      const instagramUrl=normalizeInstagramProfileUrl(instagramProfileUrl);
      const {data,error:rpcError}=await getSupabaseClient().rpc("register_team",{p_season_id:seasonId,p_team_name:teamName.trim(),p_primary_colour:primaryColour||undefined,p_secondary_colour:secondaryColour||undefined,p_instagram_profile_url:instagramUrl,p_instagram_handle:handle});
      if(rpcError)throw rpcError;
      capture("team_registration_submitted", { feature: "team_registration", outcome: "success" });
      setMessage(`Your application for ${data.name} has been submitted for administrator approval. You will become its captain only after approval.`);
      setTeamName("");setPrimaryColour("");setSecondaryColour("");setInstagramHandle("");setInstagramProfileUrl("");
    }catch(cause){capture("workflow_error", { feature: "team_registration", error_code: "unexpected_error", outcome: "failure" });setError(cause instanceof Error?cause.message:"Unable to submit team registration.");}
    finally{setBusy(false);}
  }

  if(loading)return <main className="notice-page"><SiteNavigation /><section className="notice-panel"><p>Checking your account…</p></section></main>;
  if(!session)return <main className="notice-page"><SiteNavigation /><section className="notice-panel"><Link className="notice-brand" to="/">OPEN PLAY</Link><p className="eyebrow eyebrow-dark">GET INVOLVED</p><h1>Find your<br/><em>place to play.</em></h1><p>Create an account or sign in before joining a team or submitting a team application.</p><div className="auth-form"><Link className="button" to="/sign-up">CREATE ACCOUNT <span>↗</span></Link><Link className="auth-switch" to="/sign-in">Already have an account? Sign in</Link></div></section></main>;
  if(!player||player.registration_status!=="registered"||player.is_banned)return <main className="notice-page"><SiteNavigation /><section className="notice-panel"><Link className="notice-brand" to="/">OPEN PLAY</Link><p className="eyebrow eyebrow-dark">PLAYER REGISTRATION</p><h1>Register<br/><em>to play.</em></h1><p>{player?.registration_status==="pending_review"?"Your player registration is awaiting an identity review. You can join or register a team after approval.":player?.is_banned?"Your account cannot submit team requests. Please contact Open Play support.":"You need an approved player profile before you can join an existing team or register a new one."}</p><Link className="button" to="/register-player">PLAYER REGISTRATION <span>↗</span></Link></section></main>;

  return <main className="notice-page"><SiteNavigation /><section className="notice-panel auth-panel">
    <Link className="notice-brand" to="/">OPEN PLAY</Link><p className="eyebrow eyebrow-dark">GET INVOLVED</p><h1>Find your<br/><em>place to play.</em></h1>
    <p>Signed in as <strong>{session.user.email}</strong>. Your player registration is approved.</p>
    <div className="auth-mode-switch"><button type="button" className={mode==="join"?"active":""} onClick={()=>{setMode("join");setError("");setMessage("");}}>JOIN A TEAM</button><button type="button" className={mode==="register"?"active":""} onClick={()=>{setMode("register");capture("team_registration_started", { feature: "team_registration" });setError("");setMessage("");}}>REGISTER A TEAM</button></div>
    {seasons.length===0?<p className="form-note">There are no public seasons currently accepting registrations. Please check back when a season opens.</p>:<>
      <label className="auth-select-label">Season<select value={seasonId} onChange={e=>setSeasonId(e.target.value)}>{seasons.map(season=><option key={season.id} value={season.id}>{season.name}</option>)}</select></label>
      {mode==="join"?<form className="auth-form" onSubmit={submitJoin}>
        <label>Team<select required value={teamId} onChange={e=>setTeamId(e.target.value)}><option value="">Choose a team</option>{teams.map(team=><option key={team.id} value={team.id}>{team.name}</option>)}</select></label>
        {teams.length===0&&<p className="form-note">No approved teams are currently listed for this season.</p>}
        <button className="button" type="submit" disabled={busy||!teamId}>{busy?"SENDING REQUEST…":"REQUEST TO JOIN"} <span>↗</span></button>
      </form>:<form className="auth-form" onSubmit={submitTeam}>
        <label>Team name<input required maxLength={80} value={teamName} onChange={e=>setTeamName(e.target.value)}/></label>
        <div className="auth-colours"><label>Primary colour<input type="text" maxLength={30} placeholder="e.g. Orange" value={primaryColour} onChange={e=>setPrimaryColour(e.target.value)}/></label><label>Secondary colour<input type="text" maxLength={30} placeholder="e.g. Black" value={secondaryColour} onChange={e=>setSecondaryColour(e.target.value)}/></label></div>
        <label>Instagram handle (optional)<input type="text" maxLength={32} autoCapitalize="none" autoCorrect="off" spellCheck={false} placeholder="@yourteam" value={instagramHandle} onChange={e=>setInstagramHandle(e.target.value)}/></label>
        <label>Instagram profile link (optional)<input type="url" maxLength={200} placeholder="https://www.instagram.com/yourteam/" value={instagramProfileUrl} onChange={e=>setInstagramProfileUrl(e.target.value)}/></label>
        <p className="form-note">Add a link to your team’s Instagram profile so players and supporters can visit your page directly from Open Play.</p>
        <p className="form-note">Team applications require administrator approval. Your captain access is not activated until approval.</p>
        <button className="button" type="submit" disabled={busy||!teamName.trim()}>{busy?"SUBMITTING…":"SUBMIT TEAM APPLICATION"} <span>↗</span></button>
      </form>}
    </>}
    {error&&<p className="form-error" role="alert">{error}</p>}{message&&<p className="form-success" role="status">{message}</p>}
    <Link className="auth-switch" to="/">Back to Open Play</Link>
  </section></main>;
}
