import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const response=(body:unknown,status=200)=>Response.json(body,{status});

Deno.serve(async(req)=>{
  if(req.method!=="POST")return response({error:"Method not allowed"},405);
  const cronSecret=Deno.env.get("REFEREE_PAYOUT_CRON_SECRET");
  const stripeKey=Deno.env.get("STRIPE_SECRET_KEY");
  const supabaseUrl=Deno.env.get("SUPABASE_URL");
  const serviceKey=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const appOrigin=Deno.env.get("APP_ORIGIN");
  if(!cronSecret||!stripeKey?.startsWith("sk_test_")||!supabaseUrl||!serviceKey||!appOrigin){
    return response({error:"Referee payout worker is not configured for test mode"},503);
  }
  if(req.headers.get("x-referee-payout-cron-secret")!==cronSecret){
    return response({error:"Unauthorised"},401);
  }

  let batchSize=10;
  try{
    const body=await req.json();
    if(Number.isInteger(body?.batch_size))batchSize=Math.max(1,Math.min(25,body.batch_size));
  }catch{
    // The scheduled caller may omit a body; use the safe default batch.
  }

  const admin=createClient(supabaseUrl,serviceKey,{auth:{persistSession:false,autoRefreshToken:false}});
  const {data:jobs,error:claimError}=await admin.rpc("claim_referee_payout_transfer_jobs",{
    p_limit:batchSize,
  });
  if(claimError)return response({error:"Unable to claim referee payout jobs"},500);

  let transferred=0,processing=0,released=0,failed=0;
  for(const job of jobs??[]){
    try{
      const transferResponse=await fetch(supabaseUrl.replace(/\/+$/,"")+"/functions/v1/pay-referee-payout",{
        method:"POST",
        headers:{
          "Authorization":`Bearer ${serviceKey}`,
          "apikey":serviceKey,
          "Content-Type":"application/json",
          "x-referee-payout-cron-secret":cronSecret,
        },
        body:JSON.stringify({
          payout_type:"match_report",
          payout_id:job.payout_id,
          job_id:job.job_id,
          lock_token:job.lock_token,
        }),
      });
      const result=await transferResponse.json().catch(()=>({})) as Record<string,unknown>;
      if(transferResponse.ok&&result.success===true&&result.status==="transferred"){
        transferred++;
      }else if(transferResponse.ok&&result.status==="processing"){
        // A Stripe timeout or unconfirmed result must remain leased/processing.
        // The signed transfer webhook or an explicit reconciliation resolves it.
        processing++;
      }else if(transferResponse.status>=400&&transferResponse.status<500&&transferResponse.status!==402){
        // The payout claim did not reach a Stripe transfer. Release the job with
        // a delay; the RPC refuses to release it if the payout is already processing.
        const {data:didRelease,error:releaseError}=await admin.rpc("release_referee_payout_transfer_job",{
          p_job_id:job.job_id,
          p_lock_token:job.lock_token,
          p_reason:String(result.error??"The payout worker could not claim the transfer"),
          p_delay_seconds:900,
        });
        if(!releaseError&&didRelease)released++;
        else failed++;
      }else if(transferResponse.status===402){
        // A definitive Stripe rejection is recorded as failed by pay-referee-payout.
        failed++;
      }else{
        // Unknown 5xx/network outcomes are deliberately not retried blindly.
        processing++;
      }
    }catch{
      // We cannot know whether Stripe received the request. Preserve the lease
      // and wait for webhook reconciliation instead of risking a duplicate.
      processing++;
    }
  }

  return response({
    claimed:jobs?.length??0,
    transferred,
    processing,
    released_for_retry:released,
    failed,
  });
});
