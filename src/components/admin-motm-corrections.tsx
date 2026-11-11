import { useCallback,useEffect,useState } from "react";
import { getSupabaseClient } from "../lib/supabase/client";

type EligiblePlayer={competition_player_id:string;display_name:string};
type Nomination={
  nomination_id:string;fixture_id:string;season_team_id:string;team_name:string;opponent_name:string;
  gameweek:number;scheduled_at:string|null;location_id:string;location_name:string;
  competition_player_id:string;nominated_player_name:string;nominated_by:string;nominated_at:string;
  corrected_at:string|null;correction_reason:string|null;eligible_players:EligiblePlayer[];
};
type RpcClient={rpc(name:string,args?:Record<string,unknown>):Promise<{data:unknown;error:{message:string}|null}>};

export function AdminMotmCorrections({locationId}:{locationId:string}){
  const [rows,setRows]=useState<Nomination[]>([]);
  const [selected,setSelected]=useState<Record<string,string>>({});
  const [reasons,setReasons]=useState<Record<string,string>>({});
  const [loading,setLoading]=useState(true);
  const [busy,setBusy]=useState("");
  const [error,setError]=useState("");
  const [notice,setNotice]=useState("");
  const load=useCallback(async()=>{
    setLoading(true);setError("");
    try{
      const client=getSupabaseClient() as unknown as RpcClient;
      const {data,error:rpcError}=await client.rpc("admin_list_fixture_motm_nominations",{p_location_id:locationId||null});
      if(rpcError)throw new Error(rpcError.message);
      const items=(data??[]) as Nomination[];
      setRows(items);
      setSelected(Object.fromEntries(items.map(item=>[item.nomination_id,item.competition_player_id])));
    }catch(cause){setRows([]);setError(cause instanceof Error?cause.message:"Unable to load Man of the Match nominations.");}
    finally{setLoading(false);}
  },[locationId]);
  useEffect(()=>{void load();},[load]);
  async function correct(item:Nomination){
    const candidate=selected[item.nomination_id];
    const reason=reasons[item.nomination_id]?.trim()??"";
    if(!candidate||candidate===item.competition_player_id){setError("Choose a different eligible player for the correction.");return;}
    if(reason.length<5){setError("Enter a correction reason of at least 5 characters.");return;}
    setBusy(item.nomination_id);setError("");setNotice("");
    try{
      const client=getSupabaseClient() as unknown as RpcClient;
      const {error:rpcError}=await client.rpc("admin_correct_fixture_motm_nomination",{
        p_nomination_id:item.nomination_id,p_competition_player_id:candidate,p_reason:reason,
      });
      if(rpcError)throw new Error(rpcError.message);
      setNotice("Man of the Match nomination corrected and audited.");
      setReasons(current=>({...current,[item.nomination_id]:""}));
      await load();
    }catch(cause){setError(cause instanceof Error?cause.message:"Unable to correct this nomination.");}
    finally{setBusy("");}
  }
  return <section className="admin-queue admin-motm-corrections">
    <div className="hub-section-heading"><span className="hub-kicker">MAN OF THE MATCH REVIEW</span><span>{rows.length} nominations</span></div>
    <p className="form-note">Only authorised administrators can correct a submitted nomination. Corrections must select an actual appearance from the same team's locked sheet and include a reason. The original nomination and correction are retained in the audit history.</p>
    {error&&<p className="form-error" role="alert">{error}</p>}
    {notice&&<p className="form-success" role="status">{notice}</p>}
    {loading?<p className="form-note">Loading nominations…</p>:rows.length===0?<p className="form-note">No Man of the Match nominations have been submitted for this location yet.</p>:
      rows.map(item=><article className="admin-queue-row" key={item.nomination_id}>
        <div>
          <strong>GW {item.gameweek} · {item.team_name} v {item.opponent_name}</strong>
          <span>{item.location_name} · {item.scheduled_at?new Date(item.scheduled_at).toLocaleString("en-GB",{dateStyle:"medium",timeStyle:"short"}):"Date not set"}</span>
          <small>Current nomination: {item.nominated_player_name}</small>
          {item.corrected_at&&<small>Last corrected {new Date(item.corrected_at).toLocaleString("en-GB",{dateStyle:"medium",timeStyle:"short"})}: {item.correction_reason}</small>}
        </div>
        <div className="admin-sheet-editor">
          <label>Correct to<select value={selected[item.nomination_id]??item.competition_player_id} onChange={event=>setSelected(current=>({...current,[item.nomination_id]:event.target.value}))}>
            {item.eligible_players.map(player=><option key={player.competition_player_id} value={player.competition_player_id}>{player.display_name}</option>)}
          </select></label>
          <label>Correction reason<textarea rows={2} maxLength={500} value={reasons[item.nomination_id]??""} onChange={event=>setReasons(current=>({...current,[item.nomination_id]:event.target.value}))} placeholder="Explain the correction."/></label>
          <button type="button" disabled={busy===item.nomination_id||!selected[item.nomination_id]||selected[item.nomination_id]===item.competition_player_id||(reasons[item.nomination_id]?.trim().length??0)<5} onClick={()=>void correct(item)}>
            {busy===item.nomination_id?"SAVING…":"SAVE CORRECTION"}
          </button>
        </div>
      </article>)
    }
    <button type="button" disabled={loading} onClick={()=>void load()}>REFRESH NOMINATIONS</button>
  </section>;
}
