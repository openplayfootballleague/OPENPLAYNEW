import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
function equal(a:Uint8Array,b:Uint8Array){if(a.length!==b.length)return false;let d=0;for(let i=0;i<a.length;i++)d|=a[i]^b[i];return d===0;}
function hexBytes(hex:string):Uint8Array|null{if(!/^[a-f0-9]+$/i.test(hex)||hex.length%2)return null;const out=new Uint8Array(hex.length/2);for(let i=0;i<out.length;i++)out[i]=parseInt(hex.slice(i*2,i*2+2),16);return out;}
async function verify(raw:string,header:string,secret:string){
  const parts=header.split(",").map(part=>part.split("=",2));
  const timestamp=parts.find(([key])=>key==="t")?.[1];
  const signatures=parts.filter(([key])=>key==="v1").map(([,value])=>value);
  if(!timestamp||!/^\d+$/.test(timestamp)||Math.abs(Date.now()/1000-Number(timestamp))>300)return false;
  const key=await crypto.subtle.importKey("raw",new TextEncoder().encode(secret),{name:"HMAC",hash:"SHA-256"},false,["sign"]);
  const expected=new Uint8Array(await crypto.subtle.sign("HMAC",key,new TextEncoder().encode(`${timestamp}.${raw}`)));
  return signatures.some(signature=>{const candidate=hexBytes(signature);return candidate!==null&&equal(expected,candidate);});
}
Deno.serve(async(req)=>{
  if(req.method!=="POST")return new Response("Method not allowed",{status:405});
  const stripeKey=Deno.env.get("STRIPE_SECRET_KEY");
  const webhookSecret=Deno.env.get("REFEREE_CONNECT_WEBHOOK_SECRET");
  const url=Deno.env.get("SUPABASE_URL");
  const service=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if(!stripeKey?.startsWith("sk_test_")||!webhookSecret||!url||!service){
    return new Response("Referee Connect webhook is not configured for test mode",{status:503});
  }
  const raw=await req.text();
  if(!await verify(raw,req.headers.get("stripe-signature")??"",webhookSecret)){
    return new Response("Invalid Stripe signature",{status:400});
  }
  let event:Record<string,unknown>;
  try{event=JSON.parse(raw);}catch{return new Response("Invalid event payload",{status:400});}
  if(event.livemode!==false)return new Response("Live-mode events are disabled",{status:400});
  const eventId=String(event.id??""),eventType=String(event.type??"");
  if(!eventId||!eventType||!Number.isSafeInteger(event.created)||Number(event.created)<=0){
    return new Response("Incomplete event metadata",{status:400});
  }
  const admin=createClient(url,service,{auth:{persistSession:false,autoRefreshToken:false}});
  const {error:insertError}=await admin.from("referee_stripe_webhook_events")
    .insert({id:eventId,event_type:eventType,processing_started_at:new Date().toISOString()});
  if(insertError){
    if(insertError.code!=="23505")return new Response("Could not record webhook event",{status:500});
    const {data:prior,error:priorError}=await admin.from("referee_stripe_webhook_events")
      .select("processed_at").eq("id",eventId).maybeSingle();
    if(priorError)return new Response("Could not inspect webhook retry state",{status:500});
    if(prior?.processed_at)return Response.json({received:true,duplicate:true});
    await admin.from("referee_stripe_webhook_events")
      .update({processing_started_at:new Date().toISOString(),processing_error:null})
      .eq("id",eventId).is("processed_at",null);
  }
  const object=(event.data as Record<string,unknown>|undefined)?.object as Record<string,unknown>|undefined;
  try{
    if(eventType==="account.updated"){
      const accountId=String(object?.id??"");
      if(!/^acct_[A-Za-z0-9]+$/.test(accountId))throw new Error("Invalid connected account event");
      const {data:stored,error:lookupError}=await admin.from("referee_stripe_connect_accounts")
        .select("referee_user_id").eq("stripe_account_id",accountId).maybeSingle();
      if(lookupError||!stored?.referee_user_id)throw new Error("Connected account is not linked to an Open Play referee");
      const requirements=object?.requirements as Record<string,unknown>|undefined;
      const {error}=await admin.rpc("sync_referee_stripe_connect_account",{
        p_referee_user_id:stored.referee_user_id,p_stripe_account_id:accountId,
        p_details_submitted:Boolean(object?.details_submitted),
        p_charges_enabled:Boolean(object?.charges_enabled),
        p_payouts_enabled:Boolean(object?.payouts_enabled),
        p_requirements_currently_due:Array.isArray(requirements?.currently_due)?requirements.currently_due:[],
        p_requirements_past_due:Array.isArray(requirements?.past_due)?requirements.past_due:[],
        p_disabled_reason:requirements?.disabled_reason??null,
      });
      if(error)throw new Error("Could not synchronize connected account status");
    }else if(eventType==="transfer.paid"||eventType==="transfer.failed"){
      const transferId=String(object?.id??"");
      const metadata=object?.metadata as Record<string,unknown>|undefined;
      const reportId=String(metadata?.openplay_referee_report_payout_id??"");
      const milestoneId=String(metadata?.openplay_referee_milestone_reward_id??"");
      const success=eventType==="transfer.paid";
      if(reportId){
        const {data:payout,error:lookupError}=await admin.from("referee_report_payouts").select("status,stripe_transfer_id").eq("id",reportId).maybeSingle();
        if(lookupError)throw new Error("Could not load referee report payout");
        if(payout?.status==="processing"||(success&&payout?.status==="transferred"&&payout.stripe_transfer_id===transferId)){
          const {error}=await admin.rpc("record_referee_report_transfer_result",{
            p_payout_id:reportId,p_success:success,p_stripe_transfer_id:success?transferId:null,
            p_failure_reason:success?null:String(object?.failure_message??object?.failure_code??"Stripe transfer failed"),
          });
          if(error)throw new Error("Could not reconcile referee report transfer");
        }
      }else if(milestoneId){
        const {data:payout,error:lookupError}=await admin.from("referee_milestone_rewards").select("status,stripe_transfer_id").eq("id",milestoneId).maybeSingle();
        if(lookupError)throw new Error("Could not load referee milestone payout");
        if(payout?.status==="processing"||(success&&payout?.status==="transferred"&&payout.stripe_transfer_id===transferId)){
          const {error}=await admin.rpc("record_referee_milestone_transfer_result",{
            p_payout_id:milestoneId,p_success:success,p_stripe_transfer_id:success?transferId:null,
            p_failure_reason:success?null:String(object?.failure_message??object?.failure_code??"Stripe transfer failed"),
          });
          if(error)throw new Error("Could not reconcile referee milestone transfer");
        }
      }
    }
    const {error:processedError}=await admin.from("referee_stripe_webhook_events")
      .update({processed_at:new Date().toISOString(),processing_error:null}).eq("id",eventId);
    if(processedError)throw new Error("Could not mark webhook event processed");
    return Response.json({received:true});
  }catch(cause){
    const reason=cause instanceof Error?cause.message:"Unknown Connect webhook error";
    await admin.from("referee_stripe_webhook_events").update({processing_error:reason}).eq("id",eventId);
    return new Response(reason,{status:500});
  }
});
