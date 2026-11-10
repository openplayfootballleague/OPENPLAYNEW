import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const cors=(origin:string)=>({
  "Access-Control-Allow-Origin":origin,
  "Access-Control-Allow-Headers":"authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods":"POST, OPTIONS",
  "Vary":"Origin",
});
const json=(body:unknown,status=200,headers:Record<string,string>={})=>
  new Response(JSON.stringify(body),{status,headers:{"Content-Type":"application/json",...headers}});

Deno.serve(async(req)=>{
  const allowedOrigin=(Deno.env.get("APP_ORIGIN")??"").replace(/\/+$/,"");
  const headers=cors(allowedOrigin);
  if(req.method==="OPTIONS")return new Response("ok",{headers});
  if(req.method!=="POST")return json({error:"Method not allowed"},405,headers);
  const origin=req.headers.get("origin");
  if(origin&&origin!==allowedOrigin)return json({error:"Origin not allowed"},403,headers);

  const stripeKey=Deno.env.get("STRIPE_SECRET_KEY");
  const supabaseUrl=Deno.env.get("SUPABASE_URL");
  const anonKey=Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if(!stripeKey?.startsWith("sk_test_")||!supabaseUrl||!anonKey||!serviceKey||!allowedOrigin){
    return json({error:"Referee payout transfers are not configured for test mode"},503,headers);
  }
  const token=(req.headers.get("authorization")??"").replace(/^Bearer\s+/i,"");
  if(!token)return json({error:"Sign in to continue"},401,headers);

  const userClient=createClient(supabaseUrl,anonKey,{global:{headers:{Authorization:`Bearer ${token}`}},auth:{persistSession:false}});
  const serviceClient=createClient(supabaseUrl,serviceKey,{auth:{persistSession:false}});
  const {data:{user},error:userError}=await userClient.auth.getUser();
  if(userError||!user)return json({error:"Your session could not be verified"},401,headers);

  let body:any;
  try{body=await req.json();}catch{return json({error:"A valid payout request is required"},400,headers);}
  const payoutType=body?.payout_type;
  let payoutId=body?.payout_id;
  const reportId=body?.report_id;
  if(!["match_report","milestone"].includes(payoutType)||
     (typeof payoutId!=="string" && !(payoutType==="match_report"&&typeof reportId==="string"))){
    return json({error:"A valid referee payout type and ID are required"},400,headers);
  }
  // Approval callers identify the report, not an internal payout row. Resolve it
  // server-side; the caller's location permission is still checked by the claim RPC.
  if(!payoutId&&payoutType==="match_report"){
    const {data:obligation,error:lookupError}=await serviceClient.from("referee_report_payouts")
      .select("id").eq("report_id",reportId).maybeSingle();
    if(lookupError)return json({error:"Unable to locate the approved referee payment obligation"},500,headers);
    payoutId=obligation?.id;
  }
  if(typeof payoutId!=="string")return json({error:"No referee payment obligation exists for this approved report"},409,headers);

  const {data:payout,error:claimError}=await userClient.rpc("claim_referee_payout_transfer",{
    p_payout_type:payoutType,p_payout_id:payoutId,
  });
  if(claimError)return json({error:claimError.message},403,headers);
  if(!payout?.stripe_account_id||!payout?.amount_pence||!payout?.attempt){
    return json({error:"The payout could not be prepared for transfer"},409,headers);
  }

  let transferCreated=false;
  let canMarkFailed=false;
  let createdTransfer:any=null;
  try{
    const params=new URLSearchParams();
    params.set("amount",String(payout.amount_pence));
    params.set("currency","gbp");
    params.set("destination",payout.stripe_account_id);
    params.set("transfer_group",`openplay-referee-${payoutType}-${payoutId}`);
    params.set("metadata[openplay_payout_type]",payoutType);
    params.set("metadata[openplay_payout_id]",payoutId);
    params.set("metadata[referee_user_id]",payout.referee_user_id);
    if(payout.report_id)params.set("metadata[report_id]",payout.report_id);

    const response=await fetch("https://api.stripe.com/v1/transfers",{
      method:"POST",
      headers:{
        "Authorization":`Bearer ${stripeKey}`,
        "Content-Type":"application/x-www-form-urlencoded",
        "Idempotency-Key":`openplay-referee-${payoutType}-${payoutId}-attempt-${payout.attempt}`,
      },
      body:params.toString(),
    });
    const transfer=await response.json();
    if(!response.ok){
      canMarkFailed=response.status<500;
      throw new Error(transfer?.error?.message??"Stripe transfer failed");
    }
    if(transfer.livemode!==false)throw new Error("Live-mode transfers are disabled for this workflow");
    transferCreated=true;
    createdTransfer=transfer;

    const {error:recordError}=await serviceClient.rpc("record_referee_payout_transfer_success",{
      p_payout_type:payoutType,
      p_payout_id:payoutId,
      p_stripe_transfer_id:transfer.id,
      p_destination_account_id:transfer.destination,
      p_amount_pence:transfer.amount,
      p_currency:transfer.currency,
    });
    if(recordError){
      // The transfer already exists at Stripe. Leave the payout in processing;
      // the signed transfer.created webhook will reconcile it. Never make it retryable here.
      return json({
        error:"Stripe created the transfer, but database confirmation is pending. Do not retry this payout.",
        transfer_id:transfer.id,status:"processing",
      },200,headers);
    }
    return json({success:true,payout_type:payoutType,payout_id:payoutId,transfer_id:transfer.id,status:"transferred"},200,headers);
  }catch(error){
    const reason=error instanceof Error?error.message:"Stripe transfer failed";
    if(!transferCreated&&canMarkFailed){
      await serviceClient.rpc("record_referee_payout_transfer_failure",{
        p_payout_type:payoutType,p_payout_id:payoutId,p_failure_reason:reason,p_transfer_reversed:false,
      });
    }
    if(transferCreated||!canMarkFailed){
      return json({
        success:false,error:reason,status:"processing",
        ...(createdTransfer?.id?{transfer_id:createdTransfer.id}:{}),
      },200,headers);
    }
    return json({error:reason},402,headers);
  }
});
