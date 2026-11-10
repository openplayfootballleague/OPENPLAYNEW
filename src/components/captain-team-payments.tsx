import { useCallback,useEffect,useMemo,useState } from "react";
import { getSupabaseClient } from "../lib/supabase/client";

type PaymentFixture={
  fixture_id:string;
  season_team_id:string;
  team_name:string;
  opponent_name:string;
  gameweek:number;
  scheduled_at:string|null;
};
type TeamPayment={
  obligation_id:string;
  fixture_id:string;
  season_team_id:string;
  team_name:string;
  opponent_name:string;
  gameweek:number;
  scheduled_at:string|null;
  amount_pence:number;
  deadline_at:string;
  grace_ends_at:string;
  status:string;
  paid_at:string|null;
};
const money=(pence:number)=>new Intl.NumberFormat("en-GB",{style:"currency",currency:"GBP"}).format(pence/100);
const dateTime=(value:string)=>new Date(value).toLocaleString("en-GB",{dateStyle:"medium",timeStyle:"short"});
function countdown(value:string,now:number){
  const remaining=Math.max(0,new Date(value).getTime()-now);
  const hours=Math.floor(remaining/3600000);
  const minutes=Math.floor((remaining%3600000)/60000);
  const seconds=Math.floor((remaining%60000)/1000);
  const days=Math.floor(hours/24);
  return days>0?days+"d "+(hours%24)+"h "+minutes+"m":hours+"h "+minutes+"m "+seconds+"s";
}
function statusLabel(status:string){
  const labels:Record<string,string>={
    due:"Payment due",grace_period:"Late payment grace period",paid:"Paid on time",
    late_paid:"Paid late · strike recorded",defaulted:"Fixture cancelled · fee still due",
    paid_after_cancellation:"Paid after cancellation · fixture remains cancelled",
    refund_pending:"Opponent refund pending",refunded:"Refund completed",
    refund_failed:"Refund failed · finance review required",admin_review:"Administrator review required",
  };
  return labels[status]??status.replaceAll("_"," ");
}
export function CaptainTeamPayments({fixtures}:{fixtures:PaymentFixture[]}){
  const [payments,setPayments]=useState<TeamPayment[]>([]);
  const [loading,setLoading]=useState(true);
  const [busyId,setBusyId]=useState("");
  const [error,setError]=useState("");
  const [notice,setNotice]=useState("");
  const [now,setNow]=useState(Date.now());
  const load=useCallback(async()=>{
    const {data,error:rpcError}=await getSupabaseClient().rpc("get_captain_team_fixture_payments");
    if(rpcError){setError(rpcError.message);setPayments([]);}
    else{setError("");setPayments((data??[]) as unknown as TeamPayment[]);}
    setLoading(false);
  },[]);
  useEffect(()=>{void load();},[load]);
  useEffect(()=>{const id=window.setInterval(()=>setNow(Date.now()),1000);return()=>window.clearInterval(id);},[]);
  const paymentByFixture=useMemo(()=>new Map(payments.map(p=>[p.fixture_id+":"+p.season_team_id,p])),[payments]);
  async function pay(fixture:PaymentFixture){
    setBusyId(fixture.fixture_id);setError("");setNotice("");
    try{
      const {data,error:invokeError}=await getSupabaseClient().functions.invoke("create-team-fixture-checkout",{
        body:{fixture_id:fixture.fixture_id,season_team_id:fixture.season_team_id},
      });
      if(invokeError)throw invokeError;
      const result=data as {checkout_url?:string;already_paid?:boolean;message?:string;error?:string}|null;
      if(result?.error)throw new Error(result.error);
      if(result?.checkout_url){window.location.assign(result.checkout_url);return;}
      if(result?.already_paid){setNotice(result.message??"This fixture has already been paid.");await load();return;}
      throw new Error("The payment service did not return a checkout link. Please try again.");
    }catch(cause){setError(cause instanceof Error?cause.message:"Unable to start the team payment.");}
    finally{setBusyId("");}
  }
  return <section className="hub-memberships captain-team-payments">
    <div className="hub-section-heading"><span className="hub-kicker">WEEKLY TEAM PAYMENTS</span><span>{payments.length} payment records</span></div>
    <p className="form-note">The team fee is due 24 hours before kick-off. Payment during the following 12 hours is accepted with one team strike. After that, the fixture is cancelled and the fee remains payable.</p>
    {error&&<p className="form-error" role="alert">{error}</p>}
    {notice&&<p className="form-success" role="status">{notice}</p>}
    {loading?<p className="form-note">Loading team payments…</p>:fixtures.length===0?<p className="form-note">No upcoming fixtures currently require a team payment.</p>:fixtures.map(fixture=>{
      const payment=paymentByFixture.get(fixture.fixture_id+":"+fixture.season_team_id);
      const deadline=payment?.deadline_at;
      const graceEnd=payment?.grace_ends_at;
      const payable=!payment||payment.status==="due"||payment.status==="grace_period";
      const actionLabel=payment?.status==="grace_period"?"PAY NOW · LATE STRIKE":"PAY TEAM FEE";
      return <article className="captain-team-payment" key={fixture.fixture_id+":"+fixture.season_team_id}>
        <div className="captain-team-payment-heading">
          <strong>GW {fixture.gameweek} · {fixture.team_name} v {fixture.opponent_name}</strong>
          <span>{fixture.scheduled_at?dateTime(fixture.scheduled_at):"Kick-off to be confirmed"}</span>
        </div>
        {payment?<>
          <div className="captain-team-payment-status"><span>{statusLabel(payment.status)}</span><strong>{money(payment.amount_pence)}</strong></div>
          {deadline&&<p className="form-note">Payment deadline: {dateTime(deadline)}</p>}
          {payment.status==="due"&&deadline&&<p className="payment-countdown">Time until deadline: {countdown(deadline,now)}</p>}
          {payment.status==="grace_period"&&graceEnd&&<p className="payment-countdown">Grace period ends in: {countdown(graceEnd,now)}</p>}
          {payment.paid_at&&<p className="form-note">Paid: {dateTime(payment.paid_at)}</p>}
        </>:<p className="form-note">Create your team's payment from the configured weekly team fee.</p>}
        {payable&&fixture.scheduled_at&&<button type="button" className="button captain-team-pay-button" disabled={busyId===fixture.fixture_id} onClick={()=>void pay(fixture)}>
          {busyId===fixture.fixture_id?"PREPARING CHECKOUT…":actionLabel} <span>↗</span>
        </button>}
      </article>;
    })}
  </section>;
}
