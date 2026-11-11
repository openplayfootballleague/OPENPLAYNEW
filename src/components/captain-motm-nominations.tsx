import { useCallback,useEffect,useState } from "react";
import { getSupabaseClient } from "../lib/supabase/client";

type EligiblePlayer={competition_player_id:string;display_name:string};
type MotmOption={
  fixture_id:string;season_team_id:string;team_name:string;opponent_name:string;
  gameweek:number;scheduled_at:string;deadline_at:string;nomination_id:string|null;
  nominated_competition_player_id:string|null;nominated_player_name:string|null;
  can_nominate:boolean;eligible_players:EligiblePlayer[];
};
type RpcClient={rpc(name:string,args?:Record<string,unknown>):Promise<{data:unknown;error:{message:string}|null}>};

export function CaptainMotmNominations(){
  const [options,setOptions]=useState<MotmOption[]>([]);
  const [selected,setSelected]=useState<Record<string,string>>({});
  const [loading,setLoading]=useState(true);
  const [busy,setBusy]=useState("");
  const [error,setError]=useState("");
  const [notice,setNotice]=useState("");
  const load=useCallback(async()=>{
    setLoading(true);setError("");
    try{
      const client=getSupabaseClient() as unknown as RpcClient;
      const {data,error:rpcError}=await client.rpc("get_captain_motm_nomination_options",{});
      if(rpcError)throw new Error(rpcError.message);
      const rows=(data??[]) as MotmOption[];
      setOptions(rows);
      setSelected(current=>Object.fromEntries(rows.map(row=>[
        row.fixture_id,
        row.nomination_id?row.nominated_competition_player_id??"":current[row.fixture_id]??"",
      ])));
    }catch(cause){setOptions([]);setError(cause instanceof Error?cause.message:"Unable to load Man of the Match nominations.");}
    finally{setLoading(false);}
  },[]);
  useEffect(()=>{void load();},[load]);
  async function nominate(fixtureId:string){
    const playerId=selected[fixtureId];
    if(!playerId){setError("Choose an eligible player before submitting.");return;}
    setBusy(fixtureId);setError("");setNotice("");
    try{
      const client=getSupabaseClient() as unknown as RpcClient;
      const {error:rpcError}=await client.rpc("submit_fixture_motm_nomination",{
        p_fixture_id:fixtureId,p_competition_player_id:playerId,
      });
      if(rpcError)throw new Error(rpcError.message);
      setNotice("Your team's Man of the Match nomination has been submitted and locked.");
      await load();
    }catch(cause){setError(cause instanceof Error?cause.message:"Unable to submit this nomination.");}
    finally{setBusy("");}
  }
  return <section className="hub-memberships captain-motm-nominations">
    <div className="hub-section-heading"><span className="hub-kicker">MAN OF THE MATCH</span><span>{options.length} recent fixtures</span></div>
    <p className="form-note">Each team captain may submit one nomination within 24 hours of kick-off. Choose only a player from your team's locked sheet who actually appeared. You may nominate yourself if you meet the same eligibility rules. Once submitted, the nomination is locked unless an authorised administrator corrects it.</p>
    {error&&<p className="form-error" role="alert">{error}</p>}
    {notice&&<p className="form-success" role="status">{notice}</p>}
    {loading?<p className="form-note">Loading eligible nominations…</p>:options.length===0?<p className="form-note">No completed fixtures are currently within the 24-hour nomination window.</p>:
      options.map(option=><article className="admin-queue-row" key={option.fixture_id+"-"+option.season_team_id}>
        <div>
          <strong>GW {option.gameweek} · {option.team_name} v {option.opponent_name}</strong>
          <span>{new Date(option.scheduled_at).toLocaleString("en-GB",{dateStyle:"medium",timeStyle:"short"})}</span>
          <small>Nomination closes {new Date(option.deadline_at).toLocaleString("en-GB",{dateStyle:"medium",timeStyle:"short"})}</small>
        </div>
        {option.nomination_id?
          <div className="captain-actions"><strong>{option.nominated_player_name??"Former player"}</strong><span className="form-note">Nomination submitted · Locked</span></div>
          :option.can_nominate&&option.eligible_players.length>0?
          <div className="admin-sheet-editor">
            <label>Man of the Match<select value={selected[option.fixture_id]??""} onChange={event=>setSelected(current=>({...current,[option.fixture_id]:event.target.value}))}>
              <option value="">Choose an actual appearance</option>
              {option.eligible_players.map(player=><option key={player.competition_player_id} value={player.competition_player_id}>{player.display_name}</option>)}
            </select></label>
            <button type="button" disabled={busy===option.fixture_id||!selected[option.fixture_id]} onClick={()=>void nominate(option.fixture_id)}>
              {busy===option.fixture_id?"SUBMITTING…":"SUBMIT NOMINATION"}
            </button>
          </div>
          :<p className="form-note">No eligible actual appearances were recorded for this team.</p>
        }
      </article>)
    }
    <button type="button" disabled={loading} onClick={()=>void load()}>REFRESH NOMINATIONS</button>
  </section>;
}
