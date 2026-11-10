import { useCallback,useEffect,useState } from "react";
import { getSupabaseClient } from "../lib/supabase/client";

type ConnectStatus={
  connected:boolean;details_submitted:boolean;charges_enabled:boolean;payouts_enabled:boolean;
  requirements_currently_due:string[];requirements_past_due:string[];disabled_reason:string|null;
};
type PayoutItem={
  payout_kind:"report"|"milestone";payout_id:string;amount_pence:number;status:string;
  created_at:string;transferred_at:string|null;failure_reason:string|null;
};
const money=(pence:number)=>new Intl.NumberFormat("en-GB",{style:"currency",currency:"GBP"}).format(pence/100);
export function RefereeStripeConnectPanel(){
  const [status,setStatus]=useState<ConnectStatus|null>(null);
  const [payouts,setPayouts]=useState<PayoutItem[]>([]);
  const [loading,setLoading]=useState(true);
  const [busy,setBusy]=useState(false);
  const [error,setError]=useState("");
  const [notice,setNotice]=useState("");
  const load=useCallback(async()=>{
    const supabase=getSupabaseClient();
    const [connectResult,payoutResult]=await Promise.all([
      supabase.rpc("get_referee_connect_status"),
      supabase.rpc("get_referee_payout_history"),
    ]);
    if(connectResult.error)setError(connectResult.error.message);
    else setStatus(connectResult.data as unknown as ConnectStatus);
    if(payoutResult.error)setError(current=>current||payoutResult.error!.message);
    else setPayouts((payoutResult.data??[]) as unknown as PayoutItem[]);
    setLoading(false);
  },[]);
  useEffect(()=>{
    let active=true;
    async function initialize(){
      const query=new URLSearchParams(window.location.search);
      if(query.has("stripe")){
        const {error:refreshError}=await getSupabaseClient().functions.invoke("refresh-referee-connect-status",{body:{}});
        if(active){
          if(refreshError)setError("Stripe returned to Open Play, but account verification could not be refreshed. Try refreshing status.");
          else setNotice("Stripe account status refreshed.");
          const next=new URL(window.location.href);next.searchParams.delete("stripe");
          window.history.replaceState({}, "", next.toString());
        }
      }
      if(active)await load();
    }
    void initialize();
    return()=>{active=false;};
  },[load]);
  async function startOnboarding(){
    setBusy(true);setError("");setNotice("");
    try{
      const {data,error:invokeError}=await getSupabaseClient().functions.invoke("start-referee-connect-onboarding",{body:{}});
      if(invokeError)throw invokeError;
      const url=(data as {url?:string}|null)?.url;
      if(!url||!url.startsWith("https://"))throw new Error("Stripe did not return a valid onboarding link.");
      window.location.assign(url);
    }catch(cause){setError(cause instanceof Error?cause.message:"Unable to start Stripe onboarding.");setBusy(false);}
  }
  async function refreshStatus(){
    setBusy(true);setError("");setNotice("");
    try{
      const {data,error:invokeError}=await getSupabaseClient().functions.invoke("refresh-referee-connect-status",{body:{}});
      if(invokeError)throw invokeError;
      const next=data as ConnectStatus;
      if(next?.connected)setStatus(next);
      await load();setNotice("Stripe account status refreshed.");
    }catch(cause){setError(cause instanceof Error?cause.message:"Unable to refresh Stripe status.");}
    finally{setBusy(false);}
  }
  const ready=Boolean(status?.connected&&status.details_submitted&&status.payouts_enabled);
  return <section className="hub-memberships referee-connect-panel">
    <div className="hub-section-heading"><span className="hub-kicker">REFEREE PAYMENTS</span><span>{ready?"PAYOUTS ENABLED":status?.connected?"SETUP REQUIRED":"NOT CONNECTED"}</span></div>
    <h2>Receive referee payments.</h2>
    <p>Connect a Stripe Express account to receive your match fees and milestone rewards. Open Play only sees the account readiness needed to pay you.</p>
    {error&&<p className="form-note" role="alert">{error}</p>}
    {notice&&<p className="form-note" role="status">{notice}</p>}
    {loading?<p className="form-note">Checking your payout account…</p>:(
      <>
        {status?.disabled_reason&&<p className="form-note">Stripe needs attention: {status.disabled_reason.replaceAll("_"," ")}</p>}
        {status?.requirements_past_due?.length>0&&<p className="form-note">Overdue verification: {status.requirements_past_due.join(", ")}</p>}
        {status?.requirements_currently_due?.length>0&&<p className="form-note">Still required: {status.requirements_currently_due.join(", ")}</p>}
        <div className="referee-connect-actions">
          {!ready&&<button type="button" disabled={busy} onClick={()=>void startOnboarding()}>{busy?"OPENING STRIPE…":status?.connected?"COMPLETE STRIPE SETUP":"CONNECT STRIPE"}</button>}
          <button type="button" className="admin-inline-action" disabled={busy} onClick={()=>void refreshStatus()}>REFRESH ACCOUNT STATUS</button>
        </div>
        <div className="referee-payout-history">
          <div className="hub-section-heading"><span className="hub-kicker">PAYOUT HISTORY</span><span>{payouts.length} records</span></div>
          {payouts.length===0?<p className="form-note">Approved match fees and milestone rewards will appear here.</p>:payouts.map(item=><div className="referee-payout-row" key={item.payout_id}>
            <div><strong>{item.payout_kind==="report"?"Match fee":"Milestone reward"}</strong><span>{new Date(item.created_at).toLocaleDateString("en-GB")}</span></div>
            <div><strong>{money(item.amount_pence)}</strong><span>{item.status.replaceAll("_"," ")}</span></div>
            {item.failure_reason&&<p className="form-note">{item.failure_reason}</p>}
          </div>)}
        </div>
      </>
    )}
  </section>;
}
