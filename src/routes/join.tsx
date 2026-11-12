import { useEffect, useState } from "react";
import { AuthenticatedSessionBoundary } from "../components/authenticated-session-boundary";
import { RefereeBottomNavigation } from "../components/referee-bottom-navigation";
import { PlayerCompetitionSelector, usePlayerCompetitionContext } from "../lib/competition/player-context";
import { Link, createFileRoute } from "@tanstack/react-router";
import type { Session } from "@supabase/supabase-js";
import { getSupabaseClient } from "../lib/supabase/client";
import { getTeamRequestDisplay, type TeamRequestStatus } from "../lib/team-request-status";
import { useOpenPlayAnalytics } from "../components/analytics-provider";

type TeamOption = { id: string; name: string; season_id: string };
type PlayerState = { registration_status: "registered" | "pending_review" | "rejected"; is_banned: boolean };

export const Route = createFileRoute("/join")({ component: JoinPage });

function JoinPage(){
 return <AuthenticatedSessionBoundary label="JOIN OPEN PLAY"><JoinWorkspace/></AuthenticatedSessionBoundary>;
}

function JoinWorkspace() {
  const competition = usePlayerCompetitionContext();
  const capture = useOpenPlayAnalytics();
  const [session,setSession]=useState<Session|null>(null);
  const [player,setPlayer]=useState<PlayerState|null>(null);
  const [loading,setLoading]=useState(true);
  const [mode,setMode]=useState<"join"|"register">("join");
  const [teams,setTeams]=useState<TeamOption[]>([]);
  const [myRequests,setMyRequests]=useState<TeamRequestStatus[]>([]);
  const [teamId,setTeamId]=useState("");
  const [teamName,setTeamName]=useState("");
  const [primaryColour,setPrimaryColour]=useState("");
  const [secondaryColour,setSecondaryColour]=useState("");
  const [error,setError]=useState("");
  const [message,setMessage]=useState("");
  const [busy,setBusy]=useState(false);
  const [recruitmentEnabled,setRecruitmentEnabled]=useState<boolean|null>(null);

  async function refreshMyRequests(){
    const {data,error:requestError}=await getSupabaseClient().rpc("get_my_team_request_statuses");
    if(requestError)throw requestError;
    setMyRequests(data??[]);
  }

  useEffect(()=>{
    const supabase=getSupabaseClient();
    let alive=true;
    async function load(){
      const {data:{session:current}}=await supabase.auth.getSession();
      const {data:recruitmentStatus,error:recruitmentError}=await supabase.rpc("get_public_team_recruitment_status");
      if(!alive)return;
      setRecruitmentEnabled(recruitmentError?false:recruitmentStatus===true);
      if(recruitmentError)setError("Unable to check team recruitment availability. Please try again shortly.");
      setSession(current);
      if(current){
        const {data:playerData}=await supabase.from("players").select("registration_status,is_banned").eq("user_id",current.user.id).maybeSingle();
        if(!alive)return;
        setPlayer(playerData);
        try{await refreshMyRequests();}catch(cause){if(alive)setError(cause instanceof Error?cause.message:"Unable to load your team request history.");}
      }
      if(alive)setLoading(false);
    }
    void load();
    const {data:{subscription}}=supabase.auth.onAuthStateChange((_event,next)=>{
      setSession(next);
      if(!next){setPlayer(null);setTeams([]);setMyRequests([]);}
    });
    return ()=>{alive=false;subscription.unsubscribe();};
  },[]);

  useEffect(()=>{
    let alive=true;
    async function loadTeams(){
      setTeams([]);setTeamId("");
      if(!competition.selectedSeasonId)return;
      const {data,error:queryError}=await getSupabaseClient().from("season_teams").select("id,name,season_id").eq("season_id",competition.selectedSeasonId).eq("registration_status","approved").order("name");
      if(!alive)return;
      if(queryError)setError(queryError.message);else setTeams(data??[]);
    }
    void loadTeams();return ()=>{alive=false;};
  },[competition.selectedSeasonId]);

  async function submitJoin(event:React.FormEvent<HTMLFormElement>){
    event.preventDefault();setError("");setMessage("");setBusy(true);
    try{
      if(!teamId)throw new Error("Choose a team first.");
      const {error:rpcError}=await getSupabaseClient().rpc("request_team_membership",{p_season_team_id:teamId});
      if(rpcError)throw rpcError;
      capture("player_join_request_submitted", { feature: "team_membership", outcome: "success", season_id: competition.selectedSeasonId });
      setMessage("Your request has been sent. You will become a team member only after the captain approves it.");
      try{await refreshMyRequests();}catch{}
    }catch(cause){capture("workflow_error", { feature: "team_membership", error_code: "unexpected_error", outcome: "failure" });setError(cause instanceof Error?cause.message:"Unable to send your team request.");}
    finally{setBusy(false);}
  }

  async function submitTeam(event:React.FormEvent<HTMLFormElement>){
    event.preventDefault();setError("");setMessage("");setBusy(true);
    try{
      if(!competition.selectedSeasonId)throw new Error("There is no open season available for team registration.");
      const {data,error:rpcError}=await getSupabaseClient().rpc("register_team",{p_season_id:competition.selectedSeasonId,p_team_name:teamName.trim(),p_primary_colour:primaryColour||undefined,p_secondary_colour:secondaryColour||undefined});
      if(rpcError)throw rpcError;
      capture("team_registration_submitted", { feature: "team_registration", outcome: "success", season_id: competition.selectedSeasonId });
      setMessage(`Your application for ${data.name} has been submitted for administrator approval. You will become its captain only after approval.`);
      try{await refreshMyRequests();}catch{}
      setTeamName("");setPrimaryColour("");setSecondaryColour("");
    }catch(cause){capture("workflow_error", { feature: "team_registration", error_code: "unexpected_error", outcome: "failure" });setError(cause instanceof Error?cause.message:"Unable to submit team registration.");}
    finally{setBusy(false);}
  }

  const selectedSeason=competition.seasons.find((season)=>season.id===competition.selectedSeasonId);
  const registrationOpen=selectedSeason?.status==="registration_open";

  if(loading)return <main className="notice-page player-facing"><section className="notice-panel"><p>Checking your account…</p></section></main>;
  if(!session)return <main className="notice-page player-facing"><section className="notice-panel"><Link className="notice-brand" to="/player"><img className="open-play-logo" src="/open-play-logo.png" alt="Open Play"/></Link><p className="eyebrow eyebrow-dark">GET INVOLVED</p><h1>Find your<br/><em>place to play.</em></h1><p>Create an account or sign in before joining a team or submitting a team application.</p><div className="auth-form"><Link className="button" to="/sign-up">CREATE ACCOUNT <span>↗</span></Link><Link className="auth-switch" to="/sign-in">Already have an account? Sign in</Link></div></section></main>;
  if(!player||player.registration_status!=="registered"||player.is_banned)return <main className="notice-page player-facing"><section className="notice-panel"><Link className="notice-brand" to="/player"><img className="open-play-logo" src="/open-play-logo.png" alt="Open Play"/></Link><p className="eyebrow eyebrow-dark">PLAYER REGISTRATION</p><h1>Register<br/><em>to play.</em></h1><p>{player?.registration_status==="pending_review"?"Your player registration is awaiting an identity review. You can join or register a team after approval.":player?.is_banned?"Your account cannot submit team requests. Please contact Open Play support.":"You need an approved player profile before you can join an existing team or register a new one."}</p><Link className="button" to="/register-player">PLAYER REGISTRATION <span>↗</span></Link></section></main>;

  return <main className="notice-page player-facing"><section className="notice-panel auth-panel">
    <Link className="notice-brand" to="/player"><img className="open-play-logo" src="/open-play-logo.png" alt="Open Play"/></Link><p className="eyebrow eyebrow-dark">GET INVOLVED</p><h1>Find your<br/><em>place to play.</em></h1>
    <p>Signed in as <strong>{session.user.email}</strong>. Your player registration is approved.</p>
    {myRequests.length>0&&<section className="join-request-list" aria-labelledby="join-request-heading">
      <div className="join-request-heading"><div><p className="eyebrow eyebrow-dark">YOUR TEAM ACTIVITY</p><h2 id="join-request-heading">Requests &amp; memberships</h2></div><span>{myRequests.length} records</span></div>
      {myRequests.map((item)=>{
        const display=getTeamRequestDisplay(item);
        return <article className="join-request-item" key={item.membership_id}>
          <div className="join-request-item-top"><div><strong>{item.team_name}</strong><span>{item.season_name}</span></div><span className={"join-request-status join-request-status--"+display.tone}>{display.label}</span></div>
          <p>{display.description}</p>
        </article>;
      })}
    </section>}
    <PlayerCompetitionSelector context={competition}/>
    {competition.error&&<p className="form-error" role="alert">{competition.error}</p>}
    {error&&<p className="form-error" role="alert">{error}</p>}{message&&<p className="form-note" role="status">{message}</p>}
    {recruitmentEnabled&&<div className="auth-mode-switch"><button type="button" className={mode==="join"?"active":""} onClick={()=>{setMode("join");setError("");setMessage("");}}>JOIN A TEAM</button><button type="button" className={mode==="register"?"active":""} onClick={()=>{capture("team_registration_started",{feature:"team_registration"});setMode("register");setError("");setMessage("");}}>REGISTER A TEAM</button></div>}
    {competition.loading||recruitmentEnabled===null?<p className="form-note">Checking recruitment availability…</p>:!recruitmentEnabled?<p className="form-note">Team recruitment is temporarily paused by Open Play. You can still view public fixtures, results and league tables. Please check back later.</p>:!registrationOpen?<p className="form-note">There is no public season currently accepting registrations for this location. Choose another location or check back when registration opens.</p>:<>
      <p className="form-note">Registration is open for {selectedSeason?.name}.</p>
      {mode==="join"?<form className="auth-form" onSubmit={submitJoin}>
        <label>Team<select required value={teamId} onChange={e=>setTeamId(e.target.value)}><option value="">Choose a team</option>{teams.map(team=><option key={team.id} value={team.id}>{team.name}</option>)}</select></label>
        {teams.length===0&&<p className="form-note">No approved teams are currently listed for this season.</p>}
        <button className="button" type="submit" disabled={busy||!teamId}>{busy?"SENDING REQUEST…":"REQUEST TO JOIN"} <span>↗</span></button>
      </form>:<form className="auth-form" onSubmit={submitTeam}>
        <label>Team name<input required maxLength={80} value={teamName} onChange={e=>setTeamName(e.target.value)}/></label>
        <div className="auth-colours"><label>Primary colour<input type="text" maxLength={30} placeholder="e.g. Orange" value={primaryColour} onChange={e=>setPrimaryColour(e.target.value)}/></label><label>Secondary colour<input type="text" maxLength={30} placeholder="e.g. Black" value={secondaryColour} onChange={e=>setSecondaryColour(e.target.value)}/></label></div>
        <p className="form-note">Team applications require administrator approval. Your captain access is not activated until approval.</p>
        <button className="button" type="submit" disabled={busy||!teamName.trim()}>{busy?"SUBMITTING…":"SUBMIT TEAM APPLICATION"} <span>↗</span></button>
      </form>}
    </>}
    <Link className="auth-switch" to="/player">Back to Player Hub</Link>
  </section><RefereeBottomNavigation /></main>;
}
