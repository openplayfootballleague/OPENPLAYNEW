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
  const allowedOrigin=Deno.env.get("APP_ORIGIN")??"";
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
    return json({error:"Team payment service is not configured for test mode"},503,headers);
  }
  const token=(req.headers.get("authorization")??"").replace(/^Bearer\s+/i,"");
  if(!token)return json({error:"Sign in to continue"},401,headers);
  const userClient=createClient(supabaseUrl,anonKey,{
    global:{headers:{Authorization:`Bearer ${token}`}},
    auth:{persistSession:false,autoRefreshToken:false},
  });
  const {data:authData,error:authError}=await userClient.auth.getUser(token);
  if(authError||!authData.user)return json({error:"Your session is invalid or expired"},401,headers);

  let input:{fixture_id?:string;season_team_id?:string};
  try{input=await req.json();}catch{return json({error:"Invalid request body"},400,headers);}
  if(!input.fixture_id||!input.season_team_id)return json({error:"Fixture and team are required"},400,headers);

  const {data:obligationRows,error:obligationError}=await userClient.rpc("create_team_fixture_payment_obligation",{
    p_fixture_id:input.fixture_id,p_season_team_id:input.season_team_id,
  });
  if(obligationError)return json({error:obligationError.message},403,headers);
  const obligation=Array.isArray(obligationRows)?obligationRows[0]:obligationRows;
  if(!obligation?.obligation_id||!Number.isSafeInteger(obligation.amount_pence)){
    return json({error:"Unable to prepare the team payment"},500,headers);
  }

  const admin=createClient(supabaseUrl,serviceKey,{auth:{persistSession:false,autoRefreshToken:false}});
  const {data:record,error:recordError}=await admin.from("team_fixture_payment_obligations")
    .select("id,amount_pence,currency,status,grace_ends_at,stripe_checkout_session_id,checkout_attempt")
    .eq("id",obligation.obligation_id).single();
  if(recordError||!record)return json({error:"Team payment record could not be loaded"},500,headers);
  if(["paid","late_paid","paid_after_cancellation","refund_pending","refunded"].includes(record.status)){
    return json({already_paid:true,message:"This team's fixture fee has already been paid."},200,headers);
  }
  if(!["due","grace_period","defaulted"].includes(record.status)||(record.status!=="defaulted"&&Date.now()>=new Date(record.grace_ends_at).getTime())){
    return json({error:"The payment window has closed. Contact an administrator."},409,headers);
  }

  let expectedSessionId:string|null=record.stripe_checkout_session_id;
  if(expectedSessionId){
    const existingResponse=await fetch(`https://api.stripe.com/v1/checkout/sessions/${encodeURIComponent(expectedSessionId)}`,{
      headers:{Authorization:`Bearer ${stripeKey}`},
    });
    const existing=await existingResponse.json().catch(()=>({}));
    if(!existingResponse.ok)return json({error:"Existing Checkout session could not be verified"},502,headers);
    if(existing.status==="open"&&typeof existing.url==="string"){
      return json({checkout_url:existing.url,obligation_id:record.id},200,headers);
    }
    if(existing.status==="complete"){
      return json({error:"Stripe is processing this payment. Refresh the Captain Hub shortly."},409,headers);
    }
  }

  const {data:attempt,error:attemptError}=await admin.rpc("claim_team_fixture_payment_checkout_attempt",{
    p_obligation_id:record.id,p_expected_session_id:expectedSessionId,
  });
  if(attemptError||!Number.isInteger(attempt)){
    return json({error:attemptError?.message??"Checkout retry could not be prepared"},409,headers);
  }

  const form=new URLSearchParams();
  form.set("mode","payment");
  form.set("payment_method_types[0]","card");
  form.set("success_url",`${allowedOrigin}/captain?team_payment=success`);
  form.set("cancel_url",`${allowedOrigin}/captain?team_payment=cancelled`);
  form.set("client_reference_id",record.id);
  form.set("line_items[0][quantity]","1");
  form.set("line_items[0][price_data][currency]",record.currency);
  form.set("line_items[0][price_data][unit_amount]",String(record.amount_pence));
  form.set("line_items[0][price_data][product_data][name]","Open Play weekly team fixture fee");
  form.set("line_items[0][price_data][product_data][description]","One-off team match fee");
  form.set("metadata[team_fixture_payment_obligation_id]",record.id);
  form.set("payment_intent_data[metadata][team_fixture_payment_obligation_id]",record.id);

  const stripeResponse=await fetch("https://api.stripe.com/v1/checkout/sessions",{
    method:"POST",
    headers:{
      Authorization:`Bearer ${stripeKey}`,
      "Content-Type":"application/x-www-form-urlencoded",
      "Idempotency-Key":`openplay-team-fixture-${record.id}-attempt-${attempt}`,
    },
    body:form,
  });
  const session=await stripeResponse.json().catch(()=>({}));
  if(!stripeResponse.ok||typeof session.id!=="string"||typeof session.url!=="string"){
    return json({error:"Stripe could not create the team Checkout session"},502,headers);
  }
  const {data:saved,error:saveError}=await admin.rpc("set_team_fixture_payment_checkout_session",{
    p_obligation_id:record.id,p_attempt:attempt,p_session_id:session.id,
  });
  if(saveError||saved!==true){
    await fetch(`https://api.stripe.com/v1/checkout/sessions/${encodeURIComponent(session.id)}/expire`,{
      method:"POST",headers:{Authorization:`Bearer ${stripeKey}`},
    }).catch(()=>undefined);
    return json({error:"Checkout could not be safely attached to the payment record. Refresh and retry."},409,headers);
  }
  return json({checkout_url:session.url,obligation_id:record.id},200,headers);
});
