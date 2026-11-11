import { useState } from "react";
import { getSupabaseClient } from "../lib/supabase/client";

type Candidate={user_id:string;email:string|null;display_name:string;has_league_admin:boolean};
type RpcClient={rpc(name:string,args?:Record<string,unknown>):Promise<{data:unknown;error:{message:string}|null}>};

export function AdminLeagueAdminRoles(){
  const [query,setQuery]=useState("");
  const [reason,setReason]=useState("");
  const [rows,setRows]=useState<Candidate[]>([]);
  const [loading,setLoading]=useState(false);
  const [busy,setBusy]=useState("");
  const [error,setError]=useState("");
  const [notice,setNotice]=useState("");
  async function search(event?:React.FormEvent<HTMLFormElement>){
    event?.preventDefault();
    if(query.trim().length<2)return;
    setLoading(true);setError("");setNotice("");
    try{
      const client=getSupabaseClient() as unknown as RpcClient;
      const {data,error:rpcError}=await client.rpc("admin_search_league_admin_role_candidates",{p_query:query.trim()});
      if(rpcError)throw new Error(rpcError.message);
      setRows((data??[]) as Candidate[]);
    }catch(cause){setRows([]);setError(cause instanceof Error?cause.message:"Unable to search user accounts.");}
    finally{setLoading(false);}
  }
  async function changeRole(row:Candidate,granted:boolean){
    if(reason.trim().length<5){setError("Enter a reason of at least 5 characters before changing a role.");return;}
    setBusy(row.user_id);setError("");setNotice("");
    try{
      const client=getSupabaseClient() as unknown as RpcClient;
      const {data,error:rpcError}=await client.rpc("admin_set_league_admin_role",{
        p_user_id:row.user_id,p_granted:granted,p_reason:reason.trim(),
      });
      if(rpcError)throw new Error(rpcError.message);
      setNotice(data===false
        ?(granted?"This user already has the league administrator role.":"This user did not have the league administrator role.")
        :(granted?"League administrator role granted. Assign one or more locations separately.":"League administrator role revoked and all location assignments removed."));
      setReason("");
      await search();
    }catch(cause){setError(cause instanceof Error?cause.message:"Unable to change this role.");}
    finally{setBusy("");}
  }
  return <section className="admin-queue admin-league-admin-roles">
    <div className="hub-section-heading"><span className="hub-kicker">LEAGUE ADMINISTRATOR ROLES</span><span>Global admin only</span></div>
    <p className="form-note">Granting this role does not grant access to any location. Assign locations separately in Location Administrators. Revoking the role also removes and audits every location assignment. Platform-admin and finance-admin roles cannot be changed here.</p>
    {error&&<p className="form-error" role="alert">{error}</p>}
    {notice&&<p className="form-success" role="status">{notice}</p>}
    <form className="admin-player-search" onSubmit={search}>
      <label>Find an existing account by name or email<input minLength={2} value={query} onChange={event=>setQuery(event.target.value)} placeholder="Name or email address"/></label>
      <button type="submit" disabled={loading||query.trim().length<2}>{loading?"SEARCHING…":"SEARCH ACCOUNTS"}</button>
    </form>
    {rows.map(row=><article className="admin-queue-row" key={row.user_id}>
      <div><strong>{row.display_name}</strong><span>{row.email??"No email address"}</span><small>{row.has_league_admin?"League administrator role assigned":"No league administrator role"}</small></div>
      <div className="admin-sheet-editor">
        <label>Reason (required)<textarea rows={2} minLength={5} maxLength={500} value={reason} onChange={event=>setReason(event.target.value)} placeholder="Explain this access change."/></label>
        <button type="button" className={row.has_league_admin?"reject":""} disabled={busy===row.user_id||reason.trim().length<5} onClick={()=>void changeRole(row,!row.has_league_admin)}>
          {busy===row.user_id?"SAVING…":row.has_league_admin?"REVOKE LEAGUE ADMIN":"GRANT LEAGUE ADMIN"}
        </button>
      </div>
    </article>)}
    {!loading&&query.trim().length>=2&&rows.length===0&&!error&&<p className="form-note">No eligible accounts matched that search.</p>}
  </section>;
}
