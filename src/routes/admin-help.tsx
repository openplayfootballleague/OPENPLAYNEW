import { useEffect,useState } from "react";
import { Link,createFileRoute } from "@tanstack/react-router";
import { getSupabaseClient } from "../lib/supabase/client";

export const Route=createFileRoute("/admin-help")({component:AdminHelpPage});
function AdminHelpPage(){
 const [allowed,setAllowed]=useState<boolean|null>(null);
 const [error,setError]=useState("");
 useEffect(()=>{let active=true;void getSupabaseClient().rpc("has_platform_role").then(({data,error:rpcError})=>{if(!active)return;if(rpcError){setError(rpcError.message);setAllowed(false);}else setAllowed(Boolean(data));});return()=>{active=false;};},[]);
 if(allowed===null)return <main className="notice-page"><section className="notice-panel"><p className="eyebrow eyebrow-dark">ADMIN HELP</p><h1>Loading<br/><em>guide.</em></h1></section></main>;
 if(!allowed)return <main className="notice-page"><section className="notice-panel"><Link className="notice-brand" to="/">OPEN PLAY</Link><p className="eyebrow eyebrow-dark">RESTRICTED</p><h1>Admin<br/><em>access.</em></h1><p className="form-error">{error||"This guide is available to approved platform administrators only."}</p><Link className="auth-switch" to="/sign-in">Sign in</Link></section></main>;
 const steps=[
  ["01","Set up a competition","Create or confirm the location, league, season and season-specific teams. Keep new leagues unpublished and seasons private until the owner has checked the details and registration rules."],
  ["02","Review registrations","Treat player registration and team registration as separate decisions. Check the submitted details and required declarations; approve only when the record is complete. An account alone is not a registered player."],
  ["03","Manage teams and players","Use the Player Database and team registers to find the correct permanent player identity. Correct personal details only with a clear reason. Never create a second player just to change a team."],
  ["04","Approve join requests","Check that a membership request belongs to the right season team. Approval grants membership in that team only; pending or declined requests do not grant captain access."],
  ["05","Schedule matchday","Create fixtures against teams in the same season, choose the correct gameweek and venue, then verify the scheduled date/time. Use fixture status changes for postponements or cancellations and record a reason."],
  ["06","Team sheets and results","Captains submit a locked team sheet with the required number of starters, a goalkeeper and permitted substitutes. Both teams must submit before you can publish a result. Attribute every goal to an eligible player on that team's submitted sheet."],
  ["07","Correct results safely","Use the result correction workflow rather than editing scores elsewhere. Give a clear reason. Previous goal records remain in the audit trail as voided history."],
  ["08","Review player transfers","A transfer request must be reviewed by an administrator. Confirm the destination and eligibility; the approval operation moves the active membership atomically. Do not simulate a transfer by deleting a player's history."],
  ["09","Record team finances","Use the Finance Ledger for manual charges, payments received, fines, refunds and credits. It does not collect card payments. Entries are append-only; record a correcting entry instead of editing history."],
  ["10","Monitor notifications","The outbox records delivery attempts and failures. The fixture reminder scheduler queues reminders; it does not itself send email or SMS. Provider credentials and an automatic delivery invocation must be configured before relying on external delivery."],
  ["11","Use the audit history","Search the audit history by action, record ID or reason. The page shows metadata only; private before/after payloads are intentionally not exposed there."],
 ];
 return <main className="notice-page admin-help-page"><section className="notice-panel admin-help-panel">
  <Link className="notice-brand" to="/admin">OPEN PLAY · ADMIN</Link>
  <p className="eyebrow eyebrow-dark">OPERATIONS GUIDE</p><h1>Run the<br/><em>league.</em></h1>
  <p className="admin-help-intro">A practical guide to the main administration workflows. Use the protected workflows in the dashboard; do not bypass them with direct database edits.</p>
  <div className="admin-help-grid">{steps.map(([number,title,body])=><article className="admin-help-card" key={number}><span>{number}</span><div><h2>{title}</h2><p>{body}</p></div></article>)}</div>
  <section className="admin-help-warning"><h2>Before going live</h2><p>Do not publish privacy notices, create production test accounts, send real email/SMS, grant new administrator roles or seed Bideford records without the required owner approval. Keep Barnstaple and Torrington inactive until separately approved.</p></section>
  <div className="captain-actions"><Link className="button" to="/admin">BACK TO ADMIN DASHBOARD <span>↗</span></Link><Link className="auth-switch" to="/finance">Open Finance Ledger</Link></div>
 </section></main>;
}
