import { useCallback,useEffect,useMemo,useState } from "react";
import { Link,createFileRoute } from "@tanstack/react-router";
import { getSupabaseClient } from "../lib/supabase/client";

type FinanceOption={season_id:string;season_name:string;team_id:string;team_name:string;league_name:string;season_status:string};
type FinanceEntry={id:string;season_team_id:string;team_name:string;season_id:string;season_name:string;fixture_id:string|null;gameweek:number|null;entry_type:"charge"|"payment"|"refund"|"credit"|"fine";amount_pence:number;description:string;due_at:string|null;occurred_at:string;payment_method:string|null;reference:string|null;notes:string|null;created_by:string;created_at:string;team_balance_pence:number};
type FinanceSummary={season_id:string;season_name:string;teams_with_entries:number;charges_pence:number;payments_pence:number;refunds_pence:number;credits_pence:number;fines_pence:number;outstanding_pence:number};
const money=(pence:number)=>new Intl.NumberFormat("en-GB",{style:"currency",currency:"GBP"}).format(pence/100);
const dateTime=(value:string|null)=>value?new Date(value).toLocaleString("en-GB",{dateStyle:"medium",timeStyle:"short"}):"—";
function poundsToPence(value:string):number|null{if(!/^\d+(\.\d{1,2})?$/.test(value.trim()))return null;const [whole,decimal=""]=value.trim().split(".");return Number(whole)*100+Number((decimal+"00").slice(0,2));}

export const Route=createFileRoute("/finance")({component:FinancePage});
function FinancePage(){
 const [options,setOptions]=useState<FinanceOption[]>([]);
 const [entries,setEntries]=useState<FinanceEntry[]>([]);
 const [summary,setSummary]=useState<FinanceSummary[]>([]);
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
  const [{data:optionRows,error:optionError},{data:summaryRows,error:summaryError},{data:entryRows,error:entryError}]=await Promise.all([
   getSupabaseClient().rpc("get_finance_options"),
   getSupabaseClient().rpc("get_finance_summary",{p_season_id:seasonFilter||null}),
   getSupabaseClient().rpc("get_finance_ledger",{p_season_id:seasonFilter||null,p_team_id:teamFilter||null}),
  ]);
  if(optionError||summaryError||entryError){setError(optionError?.message??summaryError?.message??entryError?.message??"Unable to load finance records.");}
  else{setOptions((optionRows??[]) as unknown as FinanceOption[]);setSummary((summaryRows??[]) as unknown as FinanceSummary[]);setEntries((entryRows??[]) as unknown as FinanceEntry[]);}
  setLoading(false);
 },[seasonFilter,teamFilter]);
 useEffect(()=>{void load();},[load]);
 async function createEntry(event:React.FormEvent<HTMLFormElement>){
  event.preventDefault();const pence=poundsToPence(amount);
  if(!teamId){setError("Choose a team.");return;}
  if(pence===null||pence<=0||pence>100000000){setError("Enter a valid amount between £0.01 and £1,000,000.00.");return;}
  setSaving(true);setError("");setNotice("");
  try{
   const {error:rpcError}=await getSupabaseClient().rpc("admin_create_finance_entry",{
    p_season_team_id:teamId,p_entry_type:entryType,p_amount_pence:pence,p_description:description.trim(),
    p_due_at:dueDate?new Date(dueDate+"T00:00:00").toISOString():null,
    p_payment_method:entryType==="payment"?paymentMethod:null,
    p_reference:reference.trim()||null,p_notes:notes.trim()||null,
   });
   if(rpcError)throw rpcError;
   setNotice("Finance entry recorded and audit logged. Ledger entries cannot be edited or deleted; add a correcting entry if needed.");
   setAmount("");setDescription("");setDueDate("");setReference("");setNotes("");
   await load();
  }catch(cause){setError(cause instanceof Error?cause.message:"Unable to record finance entry.");}
  finally{setSaving(false);}
 }
 const total=(key:"charges_pence"|"payments_pence"|"refunds_pence"|"credits_pence"|"fines_pence"|"outstanding_pence")=>summary.reduce((n,s)=>n+Number(s[key]??0),0);
 return <main className="notice-page finance-page"><section className="notice-panel finance-panel">
  <Link className="notice-brand" to="/admin">OPEN PLAY · ADMIN</Link>
  <p className="eyebrow eyebrow-dark">FINANCE · MANUAL RECORD KEEPING</p>
  <h1>Money<br/><em>matters.</em></h1>
  <p className="finance-intro">Record team charges, fines, payments, refunds and credits. This is an internal ledger only — it does not take card payments or connect to Stripe.</p>
  {error&&<p className="form-error" role="alert">{error}</p>}{notice&&<p className="form-success" role="status">{notice}</p>}
  <div className="finance-filters">
   <label>Season<select value={seasonFilter} onChange={e=>{setSeasonFilter(e.target.value);setTeamFilter("");}}><option value="">All seasons</option>{Array.from(new Map(options.map(o=>[o.season_id,o.season_name])).entries()).map(([id,name])=><option key={id} value={id}>{name}</option>)}</select></label>
   <label>Team<select value={teamFilter} onChange={e=>setTeamFilter(e.target.value)}><option value="">All teams</option>{filteredOptions.map(o=><option key={o.team_id} value={o.team_id}>{o.team_name} · {o.season_name}</option>)}</select></label>
  </div>
  <div className="finance-summary-grid">
   <article><span>Charges</span><strong>{money(total("charges_pence"))}</strong></article>
   <article><span>Payments received</span><strong>{money(total("payments_pence"))}</strong></article>
   <article><span>Fines</span><strong>{money(total("fines_pence"))}</strong></article>
   <article><span>Outstanding</span><strong>{money(total("outstanding_pence"))}</strong></article>
  </div>
  <section className="finance-section">
   <div className="hub-section-heading"><span className="hub-kicker">RECORD A FINANCE ENTRY</span><span>Manual only</span></div>
   <form className="finance-entry-form" onSubmit={createEntry}>
    <label>Team<select required value={teamId} onChange={e=>setTeamId(e.target.value)}><option value="">Choose team</option>{options.map(o=><option key={o.team_id} value={o.team_id}>{o.team_name} · {o.season_name}</option>)}</select></label>
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
