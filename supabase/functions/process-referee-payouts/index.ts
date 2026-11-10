import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
function equalSecret(a:string,b:string){
  if(a.length!==b.length)return false;
  let diff=0;for(let i=0;i<a.length;i++)diff|=a.charCodeAt(i)^b.charCodeAt(i);
  return diff===0;
}
async function createTransfer(key:string,accountId:string,amount:number,kind:"report"|"milestone",payoutId:string,userId:string){
  const idempotencyKey=`openplay-referee-${kind}-${payoutId}`;
  const form=new URLSearchParams({
    amount:String(amount),currency:"gbp",destination:accountId,
    transfer_group:`openplay-referee-${kind}-${payoutId}`,
    "metadata[openplay_referee_user_id]":userId,
    [`metadata[openplay_referee_${kind}_payout_id]`]:payoutId,
  });
  const response=await fetch("https://api.stripe.com/v1/transfers",{
    method:"POST",
    headers:{Authorization:`Bearer ${key}`,"Content-Type":"application/x-www-form-urlencoded","Idempotency-Key":idempotencyKey},
    body:form,
  });
  const data=await response.json().catch(()=>({})) as Record<string,unknown>;
  if(!response.ok)throw new Error(String((data.error as Record<string,unknown>|undefined)?.message??"Stripe transfer failed"));
  const id=String(data.id??"");
  if(!/^tr_[A-Za-z0-9]+$/.test(id))throw new Error("Stripe returned an invalid transfer ID");
  return {id,idempotencyKey};
}
Deno.serve(async(req)=>{
  if(req.method!=="POST")return new Response("Method not allowed",{status:405});
  const secret=Deno.env.get("REFEREE_PAYOUT_CRON_SECRET");
  const provided=req.headers.get("x-referee-payout-cron-secret")??"";
  if(!secret||!equalSecret(provided,secret))return new Response("Unauthorized",{status:401});
  const stripeKey=Deno.env.get("STRIPE_SECRET_KEY");
  const url=Deno.env.get("SUPABASE_URL");
  const service=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if(!stripeKey?.startsWith("sk_test_")||!url||!service)return new Response("Payout worker is not configured for test mode",{status:503});
  const admin=createClient(url,service,{auth:{persistSession:false,autoRefreshToken:false}});
  const reportClaim=await admin.rpc("claim_referee_report_payout_transfers",{p_limit:25});
  if(reportClaim.error)return new Response("Could not claim referee report payouts",{status:500});
  const milestoneClaim=await admin.rpc("claim_referee_milestone_reward_transfers",{p_limit:25});
  if(milestoneClaim.error)return new Response("Could not claim referee milestone rewards",{status:500});
  let transferred=0,failed=0;
  for(const item of reportClaim.data??[]){
    try{
      const transfer=await createTransfer(stripeKey,item.stripe_account_id,item.amount_pence,"report",item.payout_id,item.referee_user_id);
      const {error}=await admin.rpc("record_referee_report_transfer_result",{
        p_payout_id:item.payout_id,p_success:true,p_stripe_transfer_id:transfer.id,p_failure_reason:null,
      });
      if(error)throw new Error("Transfer created but payout ledger update failed; safe retry will use the same Stripe idempotency key");
      transferred++;
    }catch(cause){
      const reason=cause instanceof Error?cause.message:"Unknown Stripe transfer error";
      const {error}=await admin.rpc("record_referee_report_transfer_result",{
        p_payout_id:item.payout_id,p_success:false,p_stripe_transfer_id:null,p_failure_reason:reason,
      });
      if(error)return new Response("A failed report transfer could not be recorded",{status:500});
      failed++;
    }
  }
  for(const item of milestoneClaim.data??[]){
    try{
      const transfer=await createTransfer(stripeKey,item.stripe_account_id,item.amount_pence,"milestone",item.payout_id,item.referee_user_id);
      const {error}=await admin.rpc("record_referee_milestone_transfer_result",{
        p_payout_id:item.payout_id,p_success:true,p_stripe_transfer_id:transfer.id,p_failure_reason:null,
      });
      if(error)throw new Error("Transfer created but milestone ledger update failed; safe retry will use the same Stripe idempotency key");
      transferred++;
    }catch(cause){
      const reason=cause instanceof Error?cause.message:"Unknown Stripe transfer error";
      const {error}=await admin.rpc("record_referee_milestone_transfer_result",{
        p_payout_id:item.payout_id,p_success:false,p_stripe_transfer_id:null,p_failure_reason:reason,
      });
      if(error)return new Response("A failed milestone transfer could not be recorded",{status:500});
      failed++;
    }
  }
  return Response.json({claimed:(reportClaim.data?.length??0)+(milestoneClaim.data?.length??0),transferred,failed});
});
