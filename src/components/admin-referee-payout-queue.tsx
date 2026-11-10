import { useCallback,useEffect,useState } from "react";
import { getSupabaseClient } from "../lib/supabase/client";
type RefereePayout={
  payout_kind:"report"|"milestone";payout_id:string;referee_user_id:string;referee_name:string;
  amount_pence:number;status:string;created_at:string;failure_reason:string|null;
  attempt_count:number;connected:boolean;payouts_enabled:boolean;
};
const money=(pence:number)=>new Intl.NumberFormat("en-GB",{style:"currency",currency:"GBP"}).format(pence/100);
export function AdminRefereePayoutQueue(){
  const [rows,setRows]=useState<RefereePayout[]>([]);
  const [reasons,setReasons]=useState<Record<string,string>>({});
  const [loading,setLoading]=useState(true);
  const [busyId,setBusyId]=useState("");
  const [error,setError]=useState("");
  const [notice,setNotice]=useState("");
  const load=useCallback(async()=>{
    const {data,error:rpcError}=await getSupabaseClient().rpc("get_admin_referee_payout_queue");
    if(rpcError){setError(rpcError.message);setRows([]);}
    else{setRows((data??[]) as unknown as RefereePayout[]);setError("");}
    setLoading(false);
  },[]);
  useEffect(()=>{void load();},[load]);
  async function retry(row:RefereePayout){
    const key=row.payout_kind+":"+row.payout_id;
    const reason=reasons[key]?.trim()??"";
    if(reason.length<5)return;
    setBusyId(key);setError("");setNotice("");
    const {error:rpcError}=await getSupabaseClient().rpc("admin_retry_referee_payout",{
      p_payout_kind:row.payout_kind,p_payout_id:row.payout_id,p_reason:reason,
    });
    if(rpcError)setError(rpcError.message);
    else{setNotice(`Retry queued for ${row.referee_name}.`);setReasons(current=>({...current,[key]:""}));await load();}
    setBusyId("");
  }
  return <section className="finance-section referee-payout-admin">
    <div className="hub-section-heading"><span className="hub-kicker">REFEREE STRIPE PAYOUTS</span><span>{rows.length} records</span></div>
    <p className="form-note">Transfers are only released to active referees whose Stripe Express account has completed verification and enabled payouts. Failed transfers require an audited administrator retry.</p>
    {error&&<p className="form-note" role="alert">{error}</p>}
    {notice&&<p className="form-note" role="status">{notice}</p>}
    {loading?<p className="form-note">Loading referee payout queue…</p>:rows.length===0?<p className="form-note">No referee payout obligations are currently recorded.</p>:
      <div className="finance-table-wrap"><table className="finance-table">
        <thead><tr><th>Referee</th><th>Type</th><th>Amount</th><th>Status</th><th>Stripe readiness</th><th>Action</th></tr></thead>
        <tbody>{rows.map(row=>{
          const key=row.payout_kind+":"+row.payout_id;
          return <tr key={key}>
            <td><strong>{row.referee_name}</strong><small>{row.attempt_count} transfer attempts</small></td>
            <td>{row.payout_kind==="report"?"Match fee":"Milestone"}</td>
            <td>{money(row.amount_pence)}</td>
            <td><span className={"finance-type finance-"+row.status}>{row.status.replaceAll("_"," ")}</span>{row.failure_reason&&<small>{row.failure_reason}</small>}</td>
            <td>{!row.connected?"Not connected":row.payouts_enabled?"Payouts enabled":"Verification required"}</td>
            <td>{row.status==="failed"?<div className="referee-payout-retry">
              <input aria-label={"Retry reason for "+row.referee_name} minLength={5} maxLength={500} value={reasons[key]??""} onChange={event=>setReasons(current=>({...current,[key]:event.target.value}))} placeholder="Reason for retry"/>
              <button type="button" className="admin-inline-action" disabled={busyId===key||!row.payouts_enabled||(reasons[key]?.trim().length??0)<5} onClick={()=>void retry(row)}>{busyId===key?"QUEUING…":"RETRY PAYOUT"}</button>
            </div>:<span>—</span>}</td>
          </tr>;
        })}</tbody>
      </table></div>
    }
  </section>;
}
