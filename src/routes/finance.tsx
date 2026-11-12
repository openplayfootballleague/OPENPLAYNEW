import { useCallback,useEffect,useMemo,useState } from "react";
import { AuthenticatedSessionBoundary } from "../components/authenticated-session-boundary";
import { Link,createFileRoute,useNavigate } from "@tanstack/react-router";
import { useRequiredSession } from "../lib/auth/use-required-session";
import { getSupabaseClient } from "../lib/supabase/client";
import { poundsToPence } from "../lib/finance/ledger";

type FinanceOption={season_id:string;season_name:string;team_id:string;team_name:string;league_name:string;season_status:string};
type FinanceEntry={id:string;season_team_id:string;team_name:string;season_id:string;season_name:string;fixture_id:string|null;gameweek:number|null;entry_type:"charge"|"payment"|"refund"|"credit"|"fine";amount_pence:number;description:string;due_at:string|null;occurred_at:string;payment_method:string|null;reference:string|null;notes:string|null;created_by:string;created_at:string;team_balance_pence:number};
type FinanceSummary={season_id:string;season_name:string;teams_with_entries:number;charges_pence:number;payments_pence:number;refunds_pence:number;credits_pence:number;fines_pence:number;outstanding_pence:number};
type StripePayment={payment_record_id:string;fixture_id:string|null;gameweek:number|null;scheduled_at:string|null;season_id:string;season_name:string;team_name:string;player_name:string|null;amount_pence:number;currency:string;status:string;amount_refunded_pence:number;stripe_fee_pence:number|null;net_amount_pence:number|null;paid_at:string|null;created_at:string};
const money=(pence:number)=>new Intl.NumberFormat("en-GB",{style:"currency",currency:"GBP"}).format(pence/100);
const dateTime=(value:string|null)=>value?new Date(value).toLocaleString("en-GB",{dateStyle:"medium",timeStyle:"short"}):"—";

export const Route=createFileRoute("/finance")({component:FinancePage});
function FinancePage(){
 return <AuthenticatedSessionBoundary label="FINANCE WORKSPACE"><FinanceWorkspace/></AuthenticatedSessionBoundary>;
}

function FinanceWorkspace(){
 const authStatus=useRequiredSession();const navigate=useNavigate();
 useEffect(()=>{if(authStatus==="unauthenticated")void navigate({to:"/sign-in",replace:true});},[authStatus,navigate]);
 const [options,setOptions]=useState<FinanceOption[]>([]);
 const [entries,setEntries]=useState<FinanceEntry[]>([]);
 const [summary,setSummary]=useState<FinanceSummary[]>([]);
 const [stripePayments,setStripePayments]=useState<StripePayment[]>([]);
 const [feeSeasonId,setFeeSeasonId]=useState("");
 const [playerFee,setPlayerFee]=useState("");
 const [feeGameweek,setFeeGameweek]=useState("1");
 const [feeReason,setFeeReason]=useState("");
 const [seasonFilter,setSeasonFilter]=useState("");
 const [teamFilter,setTeamFilter]=useState("");
 const [teamId,setTeamId]=useState("");
 const [entryType,setEntryType]=useState<FinanceEntry["entry_type"]>("charge");
 const [amount,setAmount]=useState("");
 const [description,setDescription]=useState("");
 const [dueDate,setDueDate]=useState("");
 const [paymentMethod,setPaymentMethod]=useState("bank_transfer");
 const [reference,setReference]=useState("");
 const [notes,setNotes]=useState("");
 const [loading,setLoading]=useState(true);
 const [saving,setSaving]=useState(false);
 const [error,setError]=useState("");
 const [notice,setNotice]=useState("");
 const filteredOptions=useMemo(()=>options.filter(o=>!seasonFilter||o.season_id===seasonFilter),[options,seasonFilter]);
 const load=useCallback(async()=>{
  setLoading(true);setError("");
  const [{data:optionRows,error:optionError},{data:summaryRows,error:summaryError},{data:entryRows,error:entryError},{data:stripeRows,error:stripeError}]=await Promise.all([
   getSupabaseClient().rpc("get_finance_options"),
   getSupabaseClient().rpc("get_finance_summary",{p_season_id:seasonFilter||undefined}),
   getSupabaseClient().rpc("get_finance_ledger",{p_season_id:seasonFilter||undefined,p_team_id:teamFilter||undefined}),
   getSupabaseClient().rpc("get_admin_stripe_payments",{p_season_id:seasonFilter||undefined}),
  ]);
  if(optionError||summaryError||entryError||stripeError){setError(optionError?.message??summaryError?.message??entryError?.message??stripeError?.message??"Unable to load finance records.");}
  else{setOptions((optionRows??[]) as unknown as FinanceOption[]);setSummary((summaryRows??[]) as unknown as FinanceSummary[]);setEntries((entryRows??[]) as unknown as FinanceEntry[]);setStripePayments((stripeRows??[]) as unknown as StripePayment[]);}
  setLoading(false);
 },[seasonFilter,teamFilter]);
 useEffect(()=>{if(authStatus==="authenticated")void load();},[load,authStatus]);
 async function savePlayerFee(event:React.FormEvent<HTMLFormElement>){
  event.preventDefault();const pence=poundsToPence(playerFee);
  if(!feeSeasonId){setError("Choose a season for the player fee.");return;}
  if(pence===null||pence<1||pence>100000000){setError("Enter a player fee between £0.01 and £1,000,000.00.");return;}
  const gameweek=Number(feeGameweek);if(!Number.isInteger(gameweek)||gameweek<1||gameweek>100){setError("Enter a valid effective gameweek.");return;}
  setSaving(true);setError("");setNotice("");
  try{const {error:feeError}=await getSupabaseClient().rpc("admin_set_player_fixture_fee",{p_season_id:feeSeasonId,p_player_fee_pence:pence,p_effective_from_gameweek:gameweek,p_reason:feeReason.trim()});if(feeError)throw feeError;setNotice("Player fixture fee saved. New checkouts will use this fee from the selected gameweek; existing payment snapshots remain unchanged.");setPlayerFee("");setFeeReason("");await load();}
  catch(cause){setError(cause instanceof Error?cause.message:"Unable to save player fixture fee.");}
  finally{setSaving(false);}
 }
 async function createEntry(event:React.FormEvent<HTMLFormElement>){
  event.preventDefault();const pence=poundsToPence(amount);
  if(!teamId){setError("Choose a team.");return;}
  if(pence===null||pence<=0||pence>100000000){setError("Enter a valid amount between £0.01 and £1,000,000.00.");return;}
  setSaving(true);setError("");setNotice("");
  try{
   const {error:rpcError}=await getSupabaseClient().rpc("admin_create_finance_entry",{
    p_season_team_id:teamId,p_entry_type:entryType,p_amount_pence:pence,p_description:description.trim(),
    p_due_at:dueDate?new Date(dueDate+"T00:00:00").toISOString():undefined,
    p_payment_method:entryType==="payment"?paymentMethod:undefined,
    p_reference:reference.trim()||undefined,p_notes:notes.trim()||undefined,
   });
   if(rpcError)throw rpcError;
   setNotice("Finance entry recorded and audit logged. Ledger entries cannot be edited or deleted; add a correcting entry if needed.");
   setAmount("");setDescription("");setDueDate("");setReference("");setNotes("");
   await load();
  }catch(cause){setError(cause instanceof Error?cause.message:"Unable to record finance entry.");}
  finally{setSaving(false);}
 }
 const total=(key:"charges_pence"|"payments_pence"|"refunds_pence"|"credits_pence"|"fines_pence"|"outstanding_pence")=>summary.reduce((n,s)=>n+Number(s[key]??0),0);
 if(authStatus!=="authenticated")return <main className="notice-page finance-page"><section className="notice-panel finance-panel"><p>{authStatus==="loading"?"Checking your account…":"Redirecting to sign in…"}</p></section></main>;
 return <main className="notice-page finance-page"><section className="notice-panel finance-panel">
  <Link className="notice-brand" to="/player"><img className="open-play-logo" src="/open-play-logo.png" alt="Open Play"/></Link>
  <p className="eyebrow eyebrow-dark">FINANCE · LEDGER & CARD PAYMENTS</p>
  <h1>Money<br/><em>matters.</em></h1>
  <p className="finance-intro">Manage the internal team ledger and review player fixture payments processed through the separately configured Stripe Checkout service.</p>
  {error&&<p className="form-error" role="alert">{error}</p>}{notice&&<p className="form-success" role="status">{notice}</p>}
  <div className="finance-filters">
   <label>Season<select value={seasonFilter} onChange={e=>{setSeasonFilter(e.target.value);setTeamFilter("");setTeamId("");}}><option value="">All seasons</option>{Array.from(new Map(options.map(o=>[o.season_id,o.season_name])).entries()).map(([id,name])=><option key={id} value={id}>{name}</option>)}</select></label>
   <label>Team<select value={teamFilter} onChange={e=>setTeamFilter(e.target.value)}><option value="">All teams</option>{filteredOptions.map(o=><option key={o.team_id} value={o.team_id}>{o.team_name} · {o.season_name}</option>)}</select></label>
  </div>
  <div className="finance-summary-grid">
   <article><span>Charges</span><strong>{money(total("charges_pence"))}</strong></article>
   <article><span>Payments received</span><strong>{money(total("payments_pence"))}</strong></article>
   <article><span>Fines</span><strong>{money(total("fines_pence"))}</strong></article>
   <article><span>Outstanding</span><strong>{money(total("outstanding_pence"))}</strong></article>
  </div>
  <section className="finance-section">
   <div className="hub-section-heading"><span className="hub-kicker">PLAYER MATCH FEE SETTINGS</span><span>Season-specific</span></div>
   <form className="finance-entry-form" onSubmit={savePlayerFee}>
    <label>Season<select required value={feeSeasonId} onChange={e=>setFeeSeasonId(e.target.value)}><option value="">Choose season</option>{Array.from(new Map(options.map(o=>[o.season_id,o.season_name])).entries()).map(([id,name])=><option key={id} value={id}>{name}</option>)}</select></label>
    <label>Player fee (£)<input required inputMode="decimal" value={playerFee} onChange={e=>setPlayerFee(e.target.value)} placeholder="e.g. 3.00"/></label>
    <label>Effective from gameweek<input required type="number" min="1" max="100" value={feeGameweek} onChange={e=>setFeeGameweek(e.target.value)}/></label>
    <label className="finance-notes">Reason / audit note<textarea required minLength={5} maxLength={500} rows={2} value={feeReason} onChange={e=>setFeeReason(e.target.value)} placeholder="Why is this player fee being set or changed?"/></label>
    <button className="button" type="submit" disabled={saving||options.length===0}>{saving?"SAVING…":"SAVE PLAYER FEE"}</button>
   </form>
   <p className="form-note">Fee changes are effective from the selected gameweek and audit logged. Existing checkout amounts are never changed retroactively.</p>
  </section>
  <section className="finance-section">
   <div className="hub-section-heading"><span className="hub-kicker">PLAYER CARD PAYMENTS · STRIPE</span><span>{stripePayments.length} records</span></div>
   {stripePayments.length===0?<p className="form-note">No Stripe player payments have been recorded yet. This list updates from verified Stripe webhook events.</p>:<div className="finance-table-wrap"><table className="finance-table"><thead><tr><th>Player / Team</th><th>Fixture</th><th>Gross</th><th>Status</th><th>Refunded</th><th>Stripe fee</th><th>Net proceeds</th><th>Paid at</th></tr></thead><tbody>{stripePayments.map(p=><tr key={p.payment_record_id}><td><strong>{p.player_name??"Player account"}</strong><small>{p.team_name} · {p.season_name}</small></td><td>{p.gameweek?"Gameweek "+p.gameweek:"Fixture"}<small>{dateTime(p.scheduled_at)}</small></td><td>{money(p.amount_pence)}</td><td><span className={"finance-type finance-"+p.status}>{p.status.replaceAll("_"," ")}</span></td><td>{money(p.amount_refunded_pence)}</td><td>{p.stripe_fee_pence===null?"—":money(p.stripe_fee_pence)}</td><td>{p.net_amount_pence===null?"—":money(p.net_amount_pence)}</td><td>{dateTime(p.paid_at)}</td></tr>)}</tbody></table></div>}
   <p className="form-note">Stripe fees and net proceeds populate from verified Stripe balance-transaction webhook events; values remain blank until reconciliation arrives. Never treat a Checkout return URL as proof of payment.</p>
  </section>
  <section className="finance-section">
   <div className="hub-section-heading"><span className="hub-kicker">RECORD A FINANCE ENTRY</span><span>Manual only</span></div>
   <form className="finance-entry-form" onSubmit={createEntry}>
    <label>Team<select required value={teamId} onChange={e=>setTeamId(e.target.value)}><option value="">Choose team</option>{filteredOptions.map(o=><option key={o.team_id} value={o.team_id}>{o.team_name} · {o.season_name}</option>)}</select></label>
    <label>Entry type<select value={entryType} onChange={e=>setEntryType(e.target.value as FinanceEntry["entry_type"])}><option value="charge">Charge</option><option value="payment">Payment received</option><option value="fine">Fine</option><option value="refund">Refund issued</option><option value="credit">Credit</option></select></label>
    <label>Amount (£)<input required inputMode="decimal" value={amount} onChange={e=>setAmount(e.target.value)} placeholder="0.00"/></label>
    {entryType==="payment"&&<label>Payment method<select value={paymentMethod} onChange={e=>setPaymentMethod(e.target.value)}><option value="bank_transfer">Bank transfer</option><option value="cash">Cash</option><option value="card_terminal">Card terminal</option><option value="other">Other</option></select></label>}
    <label>Description<input required minLength={3} maxLength={240} value={description} onChange={e=>setDescription(e.target.value)} placeholder="e.g. Gameweek 1 match fee"/></label>
    <label>Due date (optional)<input type="date" value={dueDate} onChange={e=>setDueDate(e.target.value)}/></label>
    <label>Reference (optional)<input maxLength={120} value={reference} onChange={e=>setReference(e.target.value)} placeholder="Bank reference or receipt ID"/></label>
    <label className="finance-notes">Notes (optional)<textarea rows={2} maxLength={1000} value={notes} onChange={e=>setNotes(e.target.value)} placeholder="Internal finance note"/></label>
    <button className="button" type="submit" disabled={saving||options.length===0}>{saving?"RECORDING…":"RECORD ENTRY"} <span>↗</span></button>
   </form>
   <p className="form-note">Entries are append-only and each is audit logged. Record refunds as a separate entry; do not overwrite the original payment.</p>
  </section>
  <section className="finance-section">
   <div className="hub-section-heading"><span className="hub-kicker">FINANCE LEDGER</span><span>{entries.length} entries</span></div>
   {loading?<p className="form-note">Loading finance records…</p>:entries.length===0?<p className="form-note">No finance entries yet. No balances are assumed or fabricated.</p>:<div className="finance-table-wrap"><table className="finance-table"><thead><tr><th>Team / Season</th><th>Entry</th><th>Description</th><th>Amount</th><th>Due / recorded</th><th>Team balance</th></tr></thead><tbody>{entries.map(e=><tr key={e.id}><td><strong>{e.team_name}</strong><small>{e.season_name}</small></td><td><span className={"finance-type finance-"+e.entry_type}>{e.entry_type.replace("_"," ")}</span></td><td>{e.description}{e.payment_method&&<small>{e.payment_method.replace("_"," ")}</small>}{e.reference&&<small>Ref: {e.reference}</small>}</td><td>{money(e.amount_pence)}</td><td>{e.due_at?"Due "+dateTime(e.due_at):dateTime(e.occurred_at)}<small>Recorded {dateTime(e.created_at)}</small></td><td>{money(Number(e.team_balance_pence))}</td></tr>)}</tbody></table></div>}
  </section>
  <p className="finance-footer-note">Finance access is restricted to authorised finance and platform administrators. Player and captain accounts cannot read this ledger.</p>
  <Link className="auth-switch" to="/admin">← Back to Admin Dashboard</Link>
 </section></main>;
}
