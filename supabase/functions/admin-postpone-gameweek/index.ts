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
async function stripeGet(key:string,path:string){
  const res=await fetch("https://api.stripe.com/v1/"+path,{headers:{Authorization:`Bearer ${key}`}});
  const data=await res.json().catch(()=>({}));
  return {ok:res.ok,status:res.status,data:data as Record<string,unknown>};
}

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
    return json({error:"Weather postponement service is not configured for test mode"},503,headers);
  }
  const token=(req.headers.get("authorization")??"").replace(/^Bearer\s+/i,"");
  if(!token)return json({error:"Sign in to continue"},401,headers);
  const userClient=createClient(supabaseUrl,anonKey,{
    global:{headers:{Authorization:`Bearer ${token}`}},
    auth:{persistSession:false,autoRefreshToken:false},
  });
  const {data:authData,error:authError}=await userClient.auth.getUser(token);
  if(authError||!authData.user)return json({error:"Your session is invalid or expired"},401,headers);

  let input:{gameweek_id?:string;replacement_at?:string;reason?:string};
  try{input=await req.json();}catch{return json({error:"Invalid request body"},400,headers);}
  if(!input.gameweek_id||!input.replacement_at||!input.reason?.trim()){
    return json({error:"Gameweek, replacement date and reason are required"},400,headers);
  }
  const replacementAt=new Date(input.replacement_at);
  if(!Number.isFinite(replacementAt.getTime())||replacementAt.getTime()<=Date.now()+36*60*60*1000){
    return json({error:"Choose a replacement kickoff at least 36 hours in the future"},400,headers);
  }
  if(input.reason.trim().length<5||input.reason.trim().length>500){
    return json({error:"Enter a reason between 5 and 500 characters"},400,headers);
  }

  const {data:availableWeeks,error:permissionError}=await userClient.rpc("get_admin_postponable_gameweeks",{p_season_id:null});
  if(permissionError)return json({error:permissionError.message},403,headers);
  if(!(availableWeeks??[]).some((week:{gameweek_id:string})=>week.gameweek_id===input.gameweek_id)){
    return json({error:"You do not have permission to postpone this gameweek, or it is not eligible"},403,headers);
  }

  const admin=createClient(supabaseUrl,serviceKey,{auth:{persistSession:false,autoRefreshToken:false}});
  const {data:fixtures,error:fixtureError}=await admin.from("fixtures")
    .select("id").eq("gameweek_id",input.gameweek_id);
  if(fixtureError||!fixtures?.length)return json({error:"Gameweek fixtures could not be loaded"},500,headers);
  const fixtureIds=fixtures.map(f=>f.id);
  const {data:obligations,error:obligationError}=await admin.from("team_fixture_payment_obligations")
    .select("id,status,amount_pence,currency,stripe_checkout_session_id,stripe_payment_intent_id")
    .in("fixture_id",fixtureIds).in("status",["due","grace_period","paid","late_paid","admin_review"]);
  if(obligationError)return json({error:"Team payment records could not be loaded"},500,headers);

  for(const obligation of obligations??[]){
    const sessionId=obligation.stripe_checkout_session_id as string|null;
    if(!sessionId)continue;
    const sessionResult=await stripeGet(stripeKey,`checkout/sessions/${encodeURIComponent(sessionId)}`);
    if(!sessionResult.ok)return json({error:"A Stripe checkout could not be reconciled; gameweek was not changed"},409,headers);
    const session=sessionResult.data;
    if(session.status==="open"){
      const expired=await fetch(`https://api.stripe.com/v1/checkout/sessions/${encodeURIComponent(sessionId)}/expire`,{
        method:"POST",headers:{Authorization:`Bearer ${stripeKey}`},
      });
      if(!expired.ok)return json({error:"An active checkout could not be expired; gameweek was not changed"},409,headers);
      const {error}=await admin.rpc("clear_team_fixture_payment_checkout_session",{
        p_obligation_id:obligation.id,p_session_id:sessionId,
      });
      if(error)return json({error:"Checkout was expired but its payment record needs administrator review"},500,headers);
      continue;
    }
    if(session.status==="expired"){
      const {error}=await admin.rpc("clear_team_fixture_payment_checkout_session",{
        p_obligation_id:obligation.id,p_session_id:sessionId,
      });
      if(error)return json({error:"Expired checkout could not be reconciled"},500,headers);
      continue;
    }
    const sessionMetadata=session.metadata as Record<string,unknown>|undefined;
    if(sessionMetadata?.team_fixture_payment_obligation_id!==obligation.id){
      return json({error:"Stripe Checkout metadata does not match the payment record"},409,headers);
    }
    if(session.status==="complete"&&session.payment_status==="paid"){
      const paymentIntentId=typeof session.payment_intent==="string"?session.payment_intent:"";
      if(!paymentIntentId)return json({error:"Completed checkout has no PaymentIntent; gameweek was not changed"},409,headers);
      const intentResult=await stripeGet(stripeKey,`payment_intents/${encodeURIComponent(paymentIntentId)}?expand[]=latest_charge`);
      if(!intentResult.ok)return json({error:"Completed payment could not be verified"},409,headers);
      const intent=intentResult.data;
      const metadata=intent.metadata as Record<string,unknown>|undefined;
      const latest=intent.latest_charge as Record<string,unknown>|string|null;
      const charge=typeof latest==="object"&&latest!==null?latest:null;
      const paidAt=Number(charge?.created);
      if(Number(intent.amount_received)!==obligation.amount_pence||
        String(intent.currency??"").toLowerCase()!==obligation.currency||
        metadata?.team_fixture_payment_obligation_id!==obligation.id||
        !Number.isSafeInteger(paidAt)){
        return json({error:"Completed payment details do not match the obligation; gameweek was not changed"},409,headers);
      }
      const {error}=await admin.rpc("record_team_fixture_payment_success",{
        p_obligation_id:obligation.id,
        p_stripe_payment_intent_id:paymentIntentId,
        p_paid_at:new Date(paidAt*1000).toISOString(),
      });
      if(error)return json({error:"Completed payment could not be reconciled; gameweek was not changed"},409,headers);
      continue;
    }
    return json({error:"A checkout is still processing; gameweek was not changed"},409,headers);
  }

  const {data:result,error:postponeError}=await userClient.rpc("admin_postpone_gameweek",{
    p_gameweek_id:input.gameweek_id,
    p_replacement_at:replacementAt.toISOString(),
    p_reason:input.reason.trim(),
  });
  if(postponeError)return json({error:postponeError.message},400,headers);
  return json({success:true,result},200,headers);
});
