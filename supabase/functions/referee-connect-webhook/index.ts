import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const encoder=new TextEncoder();
const hex=(bytes:Uint8Array)=>Array.from(bytes).map((byte)=>byte.toString(16).padStart(2,"0")).join("");
const safeEqual=(a:string,b:string)=>{
  if(a.length!==b.length)return false;
  let diff=0;for(let i=0;i<a.length;i++)diff|=a.charCodeAt(i)^b.charCodeAt(i);
  return diff===0;
};
async function verifyStripeSignature(rawBody:string,header:string,secret:string){
  const parts=header.split(",").map((part)=>part.trim());
  const timestamp=parts.find((part)=>part.startsWith("t="))?.slice(2);
  const signatures=parts.filter((part)=>part.startsWith("v1=")).map((part)=>part.slice(3));
  if(!timestamp||signatures.length===0)return false;
  const seconds=Number(timestamp);
  if(!Number.isFinite(seconds)||Math.abs(Date.now()/1000-seconds)>300)return false;
  const key=await crypto.subtle.importKey("raw",encoder.encode(secret),{name:"HMAC",hash:"SHA-256"},false,["sign"]);
  const digest=new Uint8Array(await crypto.subtle.sign("HMAC",key,encoder.encode(`${timestamp}.${rawBody}`)));
  const expected=hex(digest);
  return signatures.some((signature)=>safeEqual(signature,expected));
}
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{"Content-Type":"application/json"}});

Deno.serve(async(req)=>{
  if(req.method!=="POST")return json({error:"Method not allowed"},405);
  const secret=Deno.env.get("REFEREE_CONNECT_WEBHOOK_SECRET");
  const supabaseUrl=Deno.env.get("SUPABASE_URL");
  const serviceKey=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if(!secret||!supabaseUrl||!serviceKey)return json({error:"Referee Connect webhook is not configured"},503);

  const rawBody=await req.text();
  const signature=req.headers.get("stripe-signature")??"";
  if(!await verifyStripeSignature(rawBody,signature,secret))return json({error:"Invalid Stripe signature"},400);

  let event:any;
  try{event=JSON.parse(rawBody);}catch{return json({error:"Invalid event payload"},400);}
  if(event.livemode!==false)return json({error:"Live-mode Connect events are disabled"},400);
  if(typeof event.id!=="string"||typeof event.type!=="string")return json({error:"Invalid Stripe event"},400);

  const serviceClient=createClient(supabaseUrl,serviceKey,{auth:{persistSession:false}});
  const {error:insertError}=await serviceClient.from("referee_connect_webhook_events")
    .insert({stripe_event_id:event.id,event_type:event.type});
  if(insertError&&insertError.code!=="23505")return json({error:"Unable to record Stripe event"},500);
  if(insertError?.code==="23505"){
    const {data:existing,error:readError}=await serviceClient.from("referee_connect_webhook_events")
      .select("processed_at").eq("stripe_event_id",event.id).maybeSingle();
    if(readError)return json({error:"Unable to reconcile Stripe event"},500);
    if(existing?.processed_at)return json({received:true,duplicate:true});
  }

  try{
    const object=event.data?.object??{};
    if(event.type==="account.updated"){
      let refereeUserId=object.metadata?.openplay_referee_user_id;
      if(!refereeUserId){
        const {data:existing}=await serviceClient.from("referee_connect_accounts")
          .select("referee_user_id").eq("stripe_account_id",object.id).maybeSingle();
        refereeUserId=existing?.referee_user_id;
      }
      if(refereeUserId){
        const {error}=await serviceClient.rpc("sync_referee_connect_account",{
          p_referee_user_id:refereeUserId,
          p_stripe_account_id:object.id,
          p_details_submitted:!!object.details_submitted,
          p_transfers_enabled:object.capabilities?.transfers==="active",
          p_payouts_enabled:!!object.payouts_enabled,
          p_charges_enabled:!!object.charges_enabled,
          p_requirements_due:object.requirements??{},
          p_disabled_reason:object.requirements?.disabled_reason??null,
        });
        if(error)throw new Error(error.message);
      }
    }else if(event.type==="transfer.created"||event.type==="transfer.reversed"){
      const payoutType=object.metadata?.openplay_payout_type;
      const payoutId=object.metadata?.openplay_payout_id;
      if(payoutType&&payoutId){
        if(event.type==="transfer.created"){
          const {error}=await serviceClient.rpc("record_referee_payout_transfer_success",{
            p_payout_type:payoutType,p_payout_id:payoutId,p_stripe_transfer_id:object.id,
            p_destination_account_id:object.destination,p_amount_pence:object.amount,p_currency:object.currency,
          });
          if(error)throw new Error(error.message);
        }else{
          const {error}=await serviceClient.rpc("record_referee_payout_transfer_failure",{
            p_payout_type:payoutType,p_payout_id:payoutId,
            p_failure_reason:"Stripe reported that the referee transfer was reversed",
            p_transfer_reversed:true,
          });
          if(error)throw new Error(error.message);
        }
      }
    }
    const {error:processedError}=await serviceClient.from("referee_connect_webhook_events")
      .update({processed_at:new Date().toISOString()}).eq("stripe_event_id",event.id);
    if(processedError)throw new Error(processedError.message);
    return json({received:true});
  }catch(error){
    return json({error:error instanceof Error?error.message:"Unable to process Stripe Connect event"},500);
  }
});
