import { useCallback, useEffect, useState } from "react";
import { Link, createFileRoute } from "@tanstack/react-router";
import { getSupabaseClient } from "../lib/supabase/client";
type CaptainRow={season_team_id:string;team_name:string;membership_id:string;player_name:string;membership_status:string;is_captain:boolean;squad_number:number|null;requested_at:string};
export const Route=createFileRoute("/captain")({component:CaptainsHubPage});
function CaptainsHubPage(){
 const [rows,setRows]=useState<CaptainRow[]>([]);const [loading,setLoading]=useState(true);const [error,setError]=useState("");const [message,setMessage]=useState("");const [busyId,setBusyId]=useState("");
 const load=useCallback(async()=>{setError("");const {data,error:rpcError}=await getSupabaseClient().rpc("get_captain_dashboard");if(rpcError){setError(rpcError.message);setRows([]);}else setRows(data??[]);setLoading(false);},[]);
 useEffect(()=>{void load();},[load]);
 async function decide(id:string,decision:"approved"|"rejected"){setBusyId(id);setError("");setMessage("");try{const {error:rpcError}=await getSupabaseClient().rpc("resolve_team_membership_request",{p_membership_id:id,p_decision:decision});if(rpcError)throw rpcError;setMessage(decision==="approved"?"Player approved and added to your squad.":"Team request rejected.");await load();}catch(cause){setError(cause instanceof Error?cause.message:"Unable to update this request.");}finally{setBusyId("");}}
 if(loading)return <main className="notice-page"><section className="notice-panel"><p>Loading Captains Hub…</p></section></main>;
 const pending=rows.filter(r=>r.membership_status==="pending");const active=rows.filter(r=>r.membership_status==="active");const teams=[...new Map(rows.map(r=>[r.season_team_id,r.team_name])).entries()];
 return <main className="notice-page"><section className="notice-panel hub-panel"><Link className="notice-brand" to="/player">OPEN PLAY</Link><p className="eyebrow eyebrow-dark">CAPTAINS HUB</p><h1>Lead your<br/><em>squad.</em></h1>
  {error?<><p className="form-error" role="alert">{error}</p><p className="form-note">This area is available only to an active, approved team captain. Team applications do not grant captain access until an administrator approves them.</p></>:<>
   {teams.map(([teamId,name])=><section className="hub-memberships" key={teamId}><div className="hub-section-heading"><span className="hub-kicker">{name}</span><span>{rows.filter(r=>r.season_team_id===teamId&&r.membership_status==="active").length} players</span></div>
    {rows.filter(r=>r.season_team_id===teamId&&r.membership_status==="pending").map(r=><article className="captain-request" key={r.membership_id}><div><strong>{r.player_name}</strong><span>Requested {new Date(r.requested_at).toLocaleDateString("en-GB")}</span></div><div className="captain-actions"><button type="button" disabled={busyId===r.membership_id} onClick={()=>decide(r.membership_id,"approved")}>Approve</button><button type="button" className="reject" disabled={busyId===r.membership_id} onClick={()=>decide(r.membership_id,"rejected")}>Reject</button></div></article>)}
    {rows.filter(r=>r.season_team_id===teamId&&r.membership_status==="active").map(r=><article className="hub-team-row" key={r.membership_id}><div><strong>{r.player_name}{r.is_captain?" · Captain":""}</strong><span>{r.squad_number?"Squad number "+r.squad_number:"No squad number assigned"}</span></div><span className="status-active">Active</span></article>)}
   </section>)}
   {teams.length===0&&<section className="hub-empty"><h2>No captain teams yet.</h2><p>Once your team registration is approved and captain access is activated, your squad and requests will appear here.</p></section>}
   {message&&<p className="form-success" role="status">{message}</p>}<p className="form-note">{pending.length} pending requests · {active.length} active memberships</p>
  </>}
  <Link className="auth-switch" to="/player">Back to Player Hub</Link>
 </section></main>;
}