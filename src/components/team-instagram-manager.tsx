import { useCallback,useEffect,useState } from "react";
import { getSupabaseClient } from "../lib/supabase/client";
import { normalizeInstagramProfileUrl } from "../lib/teams/instagram";
import { normalizeInstagramHandle } from "../lib/teams/instagram-handle";

type SocialProfile={
  season_team_id:string;
  team_name:string;
  instagram_profile_url:string|null;
  instagram_handle:string|null;
  season_name?:string;
  location_name?:string;
};
type RpcClient={
  rpc(name:string,args?:Record<string,unknown>):Promise<{data:unknown;error:{message:string}|null}>;
};

export function TeamInstagramManager({mode}:{mode:"captain"|"admin"}){
  const [rows,setRows]=useState<SocialProfile[]>([]);
  const [urls,setUrls]=useState<Record<string,string>>({});
  const [handles,setHandles]=useState<Record<string,string>>({});
  const [loading,setLoading]=useState(true);
  const [busy,setBusy]=useState("");
  const [error,setError]=useState("");
  const [notice,setNotice]=useState("");

  const load=useCallback(async()=>{
    setLoading(true);setError("");
    try{
      const client=getSupabaseClient() as unknown as RpcClient;
      const {data,error:rpcError}=await client.rpc(
        mode==="admin"?"admin_get_team_social_profiles":"get_captain_team_social_profiles",
        {}
      );
      if(rpcError)throw new Error(rpcError.message);
      const profiles=(data??[]) as SocialProfile[];
      setRows(profiles);
      setUrls(Object.fromEntries(profiles.map(row=>[row.season_team_id,row.instagram_profile_url??""])));
      setHandles(Object.fromEntries(profiles.map(row=>[row.season_team_id,row.instagram_handle??""])));
    }catch(cause){
      setRows([]);
      setError(cause instanceof Error?cause.message:"Unable to load team Instagram profiles.");
    }finally{setLoading(false);}
  },[mode]);

  useEffect(()=>{void load();},[load]);

  async function save(row:SocialProfile){
    setBusy(row.season_team_id);setError("");setNotice("");
    try{
      const url=normalizeInstagramProfileUrl(urls[row.season_team_id]??"");
      const handle=normalizeInstagramHandle(handles[row.season_team_id]??"");
      const client=getSupabaseClient() as unknown as RpcClient;
      const {error:rpcError}=await client.rpc("update_team_instagram_details",{
        p_season_team_id:row.season_team_id,
        p_instagram_profile_url:url,
        p_instagram_handle:handle,
      });
      if(rpcError)throw new Error(rpcError.message);
      setNotice("Team Instagram details updated.");
      await load();
    }catch(cause){
      setError(cause instanceof Error?cause.message:"Unable to update this Instagram profile.");
    }finally{setBusy("");}
  }

  return <section className="hub-memberships team-instagram-manager">
    <div className="hub-section-heading"><span className="hub-kicker">TEAM INSTAGRAM</span><span>{rows.length} teams</span></div>
    <p className="form-note">The profile link is optional. Only a direct, valid Instagram profile URL creates a public Instagram icon; the handle remains separate.</p>
    {error&&<p className="form-error" role="alert">{error}</p>}
    {notice&&<p className="form-success" role="status">{notice}</p>}
    {loading?<p className="form-note" role="status">Loading team profiles…</p>:rows.length===0?
      <p className="form-note">{mode==="admin"?"No team profiles are available in your assigned locations.":"No active captain teams are available."}</p>:
      rows.map(row=><article className="team-instagram-editor" key={row.season_team_id}>
        <div><strong>{row.team_name}</strong><span>{[row.location_name,row.season_name].filter(Boolean).join(" · ")}</span>{row.instagram_handle&&<small>Handle: @{row.instagram_handle}</small>}</div>
        <label>Instagram handle<input type="text" maxLength={31} autoCapitalize="none" autoCorrect="off" spellCheck={false} placeholder="@yourteam" value={handles[row.season_team_id]??""} onChange={event=>setHandles(current=>({...current,[row.season_team_id]:event.target.value}))}/></label>
        <label>Instagram profile link<input type="url" maxLength={200} autoCapitalize="none" autoCorrect="off" spellCheck={false} placeholder="https://www.instagram.com/yourteam/" value={urls[row.season_team_id]??""} onChange={event=>setUrls(current=>({...current,[row.season_team_id]:event.target.value}))}/></label>
        <button type="button" disabled={busy===row.season_team_id||normalizeDetailsUnchanged(urls[row.season_team_id],row.instagram_profile_url,handles[row.season_team_id],row.instagram_handle)} onClick={()=>void save(row)}>
          {busy===row.season_team_id?"SAVING…":"SAVE INSTAGRAM DETAILS"}
        </button>
      </article>)
    }
    <button type="button" className="draft-save" disabled={loading||busy!==""} onClick={()=>void load()}>REFRESH TEAM PROFILES</button>
  </section>;
}

function normalizeDetailsUnchanged(url:string|undefined,currentUrl:string|null,handle:string|undefined,currentHandle:string|null){
  try{
    return normalizeInstagramProfileUrl(url??"")===currentUrl
      && normalizeInstagramHandle(handle??"")===currentHandle;
  }catch{return false;}
}
