import { useCallback,useEffect,useState } from "react";
import { getSupabaseClient } from "../lib/supabase/client";

type PostponableGameweek={
  gameweek_id:string;
  season_id:string;
  season_name:string;
  week_number:number;
  scheduled_at:string|null;
  fixture_count:number;
  paid_team_count:number;
  location_name:string|null;
};
function localDateTimeValue(value:Date){
  const pad=(n:number)=>String(n).padStart(2,"0");
  return `${value.getFullYear()}-${pad(value.getMonth()+1)}-${pad(value.getDate())}T${pad(value.getHours())}:${pad(value.getMinutes())}`;
}
export function AdminGameweekPostponements(){
  const [weeks,setWeeks]=useState<PostponableGameweek[]>([]);
  const [selectedId,setSelectedId]=useState("");
  const [replacementAt,setReplacementAt]=useState("");
  const [reason,setReason]=useState("");
  const [loading,setLoading]=useState(true);
  const [busy,setBusy]=useState(false);
  const [error,setError]=useState("");
  const [notice,setNotice]=useState("");
  const load=useCallback(async()=>{
    const {data,error:rpcError}=await getSupabaseClient().rpc("get_admin_postponable_gameweeks",{p_season_id:null});
    if(rpcError){setError(rpcError.message);setWeeks([]);}
    else{
      const rows=(data??[]) as unknown as PostponableGameweek[];
      setWeeks(rows);
      setSelectedId(current=>rows.some(row=>row.gameweek_id===current)?current:rows[0]?.gameweek_id??"");
    }
    setLoading(false);
  },[]);
  useEffect(()=>{void load();},[load]);
  const selected=weeks.find(week=>week.gameweek_id===selectedId);
  async function postpone(event:React.FormEvent<HTMLFormElement>){
    event.preventDefault();
    if(!selectedId||!replacementAt||reason.trim().length<5)return;
    setBusy(true);setError("");setNotice("");
    try{
      const {data,error:invokeError}=await getSupabaseClient().functions.invoke("admin-postpone-gameweek",{
        body:{gameweek_id:selectedId,replacement_at:new Date(replacementAt).toISOString(),reason:reason.trim()},
      });
      if(invokeError)throw invokeError;
      const result=(data as {result?:{old_week_number:number;new_week_number:number;refunds_queued:number;unpaid_cycles_credited:number}}|null)?.result;
      if(!result)throw new Error("The postponement service did not confirm the change.");
      setNotice(`Gameweek ${result.old_week_number} is now Gameweek ${result.new_week_number}. ${result.refunds_queued} paid team fees queued for refund; ${result.unpaid_cycles_credited} unpaid fees credited.`);
      setReplacementAt("");setReason("");
      await load();
    }catch(cause){setError(cause instanceof Error?cause.message:"Unable to postpone this gameweek.");}
    finally{setBusy(false);}
  }
  return <section className="admin-queue admin-gameweek-postponements">
    <div className="hub-section-heading"><span className="hub-kicker">WEATHER &amp; GAMEWEEK POSTPONEMENTS</span><span>{weeks.length} eligible gameweeks</span></div>
    <p className="form-note">Use this for a weather-cancelled gameweek. All teams that have paid are queued for a full Stripe refund. Unpaid old-cycle charges are credited, and fresh team payment deadlines are created for the replacement date. Gameweek numbers are recalculated chronologically.</p>
    {error&&<p className="form-error" role="alert">{error}</p>}
    {notice&&<p className="form-success" role="status">{notice}</p>}
    {loading?<p className="form-note">Loading eligible gameweeks…</p>:weeks.length===0?<p className="form-note">No wholly unplayed gameweeks are currently available to postpone.</p>:
      <form className="admin-setup-form" onSubmit={postpone}>
        <label>Gameweek<select required value={selectedId} onChange={event=>setSelectedId(event.target.value)}>
          {weeks.map(week=><option key={week.gameweek_id} value={week.gameweek_id}>
            {week.season_name} · GW {week.week_number} · {week.location_name??"Location"}
          </option>)}
        </select></label>
        {selected&&<p className="form-note">{selected.fixture_count} fixtures · {selected.paid_team_count} team payments received · Original date {selected.scheduled_at?new Date(selected.scheduled_at).toLocaleString("en-GB",{dateStyle:"medium",timeStyle:"short"}):"Not set"}</p>}
        <label>Replacement date and kick-off time<input required type="datetime-local" min={localDateTimeValue(new Date(Date.now()+60*60*1000))} value={replacementAt} onChange={event=>setReplacementAt(event.target.value)}/></label>
        <label>Reason<textarea required minLength={5} maxLength={500} rows={3} value={reason} onChange={event=>setReason(event.target.value)} placeholder="e.g. Unsafe pitch conditions following heavy rain"/></label>
        <button type="submit" disabled={busy||!selectedId||!replacementAt||reason.trim().length<5}>
          {busy?"RECONCILING PAYMENTS…":"POSTPONE GAMEWEEK"}
        </button>
      </form>
    }
  </section>;
}
