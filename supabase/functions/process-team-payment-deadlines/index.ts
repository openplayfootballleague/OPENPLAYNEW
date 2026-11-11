import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

type StripeObject=Record<string,unknown>;
const response=(body:unknown,status=200)=>Response.json(body,{status});

async function stripeGet(key:string,path:string){
  const res=await fetch("https://api.stripe.com/v1/"+path,{headers:{Authorization:`Bearer ${key}`}});
  const data=await res.json().catch(()=>({}));
  return {ok:res.ok,status:res.status,data:data as StripeObject};
}

Deno.serve(async(req)=>{
  if(req.method!=="POST")return response({error:"Method not allowed"},405);
  const cronSecret=Deno.env.get("TEAM_PAYMENT_CRON_SECRET");
  const stripeKey=Deno.env.get("STRIPE_SECRET_KEY");
  const supabaseUrl=Deno.env.get("SUPABASE_URL");
  const serviceKey=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if(!cronSecret||!stripeKey?.startsWith("sk_test_")||!supabaseUrl||!serviceKey){
    return response({error:"Team payment deadline worker is not configured for test mode"},503);
  }
  if(req.headers.get("x-team-payment-cron-secret")!==cronSecret){
    return response({error:"Unauthorised"},401);
  }

  const admin=createClient(supabaseUrl,serviceKey,{auth:{persistSession:false,autoRefreshToken:false}});
  const now=new Date();
  const nowIso=now.toISOString();
  const obligations:Array<Record<string,unknown>>=[];
  for(let offset=0;;offset+=500){
    const {data:page,error:loadError}=await admin.from("team_fixture_payment_obligations")
      .select("id,status,amount_pence,currency,deadline_at,grace_ends_at,stripe_checkout_session_id")
      .in("status",["due","grace_period","admin_review"])
      .order("id").range(offset,offset+499);
    if(loadError)return response({error:"Could not load team payment deadlines"},500);
    obligations.push(...(page??[]));
    if((page??[]).length<500)break;
  }

  let reconciled=0,expired=0,refundsSucceeded=0,refundsFailed=0,refundsPending=0;
  for(const obligation of obligations){
    const sessionId=obligation.stripe_checkout_session_id as string|null;
    if(!sessionId)continue;
    const weatherCancelled=obligation.status==="weather_cancelled";
    if(!weatherCancelled&&new Date(String(obligation.deadline_at)).getTime()>now.getTime())continue;
    if(!weatherCancelled&&new Date(String(obligation.grace_ends_at)).getTime()>now.getTime())continue;

    const sessionResult=await stripeGet(stripeKey,`checkout/sessions/${encodeURIComponent(sessionId)}`);
    if(!sessionResult.ok)continue;
    const session=sessionResult.data;
    if(session.status==="complete"&&session.payment_status==="paid"){
      const paymentIntentId=typeof session.payment_intent==="string"?session.payment_intent:"";
      if(!paymentIntentId)continue;
      const intentResult=await stripeGet(stripeKey,`payment_intents/${encodeURIComponent(paymentIntentId)}?expand[]=latest_charge`);
      if(!intentResult.ok)continue;
      const intent=intentResult.data;
      const latestCharge=intent.latest_charge as StripeObject|string|null;
      let charge=typeof latestCharge==="object"&&latestCharge!==null?latestCharge:null;
      if(typeof latestCharge==="string"){
        const chargeResult=await stripeGet(stripeKey,`charges/${encodeURIComponent(latestCharge)}`);
        if(chargeResult.ok)charge=chargeResult.data;
      }
      const paidAt=Number(charge?.created);
      const amountReceived=Number(intent.amount_received);
      const currency=String(intent.currency??"").toLowerCase();
      const metadata=intent.metadata as Record<string,unknown>|undefined;
      const expectedAmount=Number(obligation.amount_pence);
      const expectedCurrency=String(obligation.currency??"").toLowerCase();
      const intentAmount=Number(intent.amount);
      const sessionAmount=Number(session.amount_total);
      const sessionCurrency=String(session.currency??"").toLowerCase();
      const sessionMetadata=session.metadata as Record<string,unknown>|undefined;
      if(!Number.isSafeInteger(paidAt)||!Number.isSafeInteger(expectedAmount)||expectedAmount<=0||
        amountReceived!==expectedAmount||intentAmount!==expectedAmount||sessionAmount!==expectedAmount||
        currency!==expectedCurrency||sessionCurrency!==expectedCurrency||
        metadata?.team_fixture_payment_obligation_id!==obligation.id||
        sessionMetadata?.team_fixture_payment_obligation_id!==obligation.id)continue;
      const {error:paymentError}=await admin.rpc("record_team_fixture_payment_success",{
        p_obligation_id:obligation.id,
        p_stripe_payment_intent_id:paymentIntentId,
        p_paid_at:new Date(paidAt*1000).toISOString(),
      });
      if(!paymentError)reconciled++;
    }else if(session.status==="open"){
      const expireResponse=await fetch(`https://api.stripe.com/v1/checkout/sessions/${encodeURIComponent(sessionId)}/expire`,{
        method:"POST",headers:{Authorization:`Bearer ${stripeKey}`},
      });
      if(expireResponse.ok){
        await admin.rpc("clear_team_fixture_payment_checkout_session",{
          p_obligation_id:obligation.id,p_session_id:sessionId,
        });
        expired++;
      }
    }else if(session.status==="expired"){
      await admin.rpc("clear_team_fixture_payment_checkout_session",{
        p_obligation_id:obligation.id,p_session_id:sessionId,
      });
      expired++;
    }
    // A completed but unpaid session remains in admin_review. It is never
    // cancelled or charged until its provider state can be reconciled safely.
  }

  const {data:processed,error:processError}=await admin.rpc("process_team_fixture_payment_deadlines",{
    p_as_of:nowIso,
  });
  if(processError)return response({error:"Could not process team payment deadlines"},500);

  const refundRows:Array<Record<string,unknown>>=[];
  for(let offset=0;;offset+=500){
    const {data:page,error:refundLoadError}=await admin.from("team_fixture_payment_refunds")
      .select("id,amount_pence,stripe_payment_intent_id")
      .eq("status","pending").order("id").range(offset,offset+499);
    if(refundLoadError)return response({error:"Could not load opponent refunds"},500);
    refundRows.push(...(page??[]));
    if((page??[]).length<500)break;
  }
  for(const refund of refundRows){
    const form=new URLSearchParams();
    form.set("payment_intent",String(refund.stripe_payment_intent_id));
    form.set("amount",String(refund.amount_pence));
    const stripeResponse=await fetch("https://api.stripe.com/v1/refunds",{
      method:"POST",
      headers:{
        Authorization:`Bearer ${stripeKey}`,
        "Content-Type":"application/x-www-form-urlencoded",
        "Idempotency-Key":`openplay-team-refund-${refund.id}`,
      },
      body:form,
    });
    const result=await stripeResponse.json().catch(()=>({})) as StripeObject;
    if(stripeResponse.ok&&result.status==="succeeded"&&typeof result.id==="string"&&
      result.payment_intent===refund.stripe_payment_intent_id&&
      Number(result.amount)===Number(refund.amount_pence)&&
      String(result.currency??"").toLowerCase()==="gbp"){
      const {error}=await admin.rpc("record_team_fixture_payment_refund_result",{
        p_refund_id:refund.id,p_succeeded:true,p_stripe_refund_id:result.id,
      });
      if(!error)refundsSucceeded++;
    }else if(stripeResponse.ok&&(result.status==="pending"||result.status==="requires_action")){
      refundsPending++;
    }else if(stripeResponse.ok&&(result.status==="failed"||result.status==="canceled")){
      const {error}=await admin.rpc("record_team_fixture_payment_refund_result",{
        p_refund_id:refund.id,p_succeeded:false,
        p_failure_reason:String((result.failure_reason as string|undefined)??"Stripe confirmed that the refund failed"),
      });
      if(!error)refundsFailed++;
      else refundsPending++;
    }else if(!stripeResponse.ok&&[400,402,404,422].includes(stripeResponse.status)){
      const {error}=await admin.rpc("record_team_fixture_payment_refund_result",{
        p_refund_id:refund.id,p_succeeded:false,
        p_failure_reason:String((result.error as Record<string,unknown>|undefined)?.message??"Stripe rejected the refund"),
      });
      if(!error)refundsFailed++;
      else refundsPending++;
    }else{
      // Rate limits, authentication/configuration errors and server/network
      // failures are not proof that the refund failed. Keep them reconcilable.
      refundsPending++;
    }
  }

  return response({
    processed_obligations:Number(processed??0),
    provider_payments_reconciled:reconciled,
    checkout_sessions_expired:expired,
    refunds_succeeded:refundsSucceeded,
    refunds_failed:refundsFailed,
    refunds_pending:refundsPending,
  });
});
