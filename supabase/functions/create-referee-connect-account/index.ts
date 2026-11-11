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

async function stripeRequest(path:string,method:"GET"|"POST",key:string,params?:URLSearchParams,idempotencyKey?:string){
  const response=await fetch(`https://api.stripe.com/v1/${path}`,{
    method,
    headers:{
      "Authorization":`Bearer ${key}`,
      ...(params?{"Content-Type":"application/x-www-form-urlencoded"}:{}),
      ...(idempotencyKey?{"Idempotency-Key":idempotencyKey}:{})
    },
    body:params?.toString(),
  });
  const data=await response.json();
  if(!response.ok)throw new Error(data?.error?.message??"Stripe Connect request failed");
  return data;
}

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
    return json({error:"Referee Connect is not configured for test mode"},503,headers);
  }
  const token=(req.headers.get("authorization")??"").replace(/^Bearer\s+/i,"");
  if(!token)return json({error:"Sign in to continue"},401,headers);

  const userClient=createClient(supabaseUrl,anonKey,{global:{headers:{Authorization:`Bearer ${token}`}},auth:{persistSession:false}});
  const serviceClient=createClient(supabaseUrl,serviceKey,{auth:{persistSession:false}});
  const {data:{user},error:userError}=await userClient.auth.getUser();
  if(userError||!user)return json({error:"Your session could not be verified"},401,headers);

  const {error:membershipError}=await userClient.rpc("get_my_referee_connect_status");
  if(membershipError)return json({error:membershipError.message},403,headers);

  try{
    const {data:existing,error:existingError}=await serviceClient
      .from("referee_connect_accounts")
      .select("stripe_account_id")
      .eq("referee_user_id",user.id)
      .maybeSingle();
    if(existingError)throw new Error(existingError.message);

    let account:any;
    if(existing?.stripe_account_id){
      account=await stripeRequest(`accounts/${existing.stripe_account_id}`,"GET",stripeKey);
    }else{
      const params=new URLSearchParams();
      params.set("type","express");
      params.set("country","GB");
      params.set("business_type","individual");
      if(user.email)params.set("email",user.email);
      params.set("capabilities[transfers][requested]","true");
      params.set("metadata[openplay_referee_user_id]",user.id);
      params.set("metadata[openplay_platform]","Open Play");
      account=await stripeRequest("accounts","POST",stripeKey,params,`openplay-referee-connect-account-${user.id}`);
    }

    const transfersEnabled=account.capabilities?.transfers==="active";
    const {error:syncError}=await serviceClient.rpc("sync_referee_connect_account",{
      p_referee_user_id:user.id,
      p_stripe_account_id:account.id,
      p_details_submitted:!!account.details_submitted,
      p_transfers_enabled:transfersEnabled,
      p_payouts_enabled:!!account.payouts_enabled,
      p_charges_enabled:!!account.charges_enabled,
      p_requirements_due:account.requirements??{},
      p_disabled_reason:account.requirements?.disabled_reason??null,
      // Use Stripe's immutable account creation time as the initial event watermark.
      // A verification webhook is necessarily newer and must be allowed to advance
      // readiness; using local now() here can incorrectly classify it as stale.
      p_stripe_event_created_at:new Date((typeof account.created==="number"?account.created:Math.floor(Date.now()/1000))*1000).toISOString(),
    });
    if(syncError)throw new Error(syncError.message);

    if(transfersEnabled){
      return json({connected:true,onboarding_status:"enabled",payouts_enabled:!!account.payouts_enabled},200,headers);
    }

    const linkParams=new URLSearchParams();
    linkParams.set("account",account.id);
    linkParams.set("type","account_onboarding");
    linkParams.set("return_url",`${allowedOrigin}/referee?connect=return`);
    linkParams.set("refresh_url",`${allowedOrigin}/referee?connect=refresh`);
    linkParams.set("collection_options[fields]","eventually_due");
    const link=await stripeRequest("account_links","POST",stripeKey,linkParams);
    return json({
      connected:false,
      onboarding_status:account.details_submitted?"verification_pending":"onboarding_required",
      onboarding_url:link.url,
      expires_at:link.expires_at,
    },200,headers);
  }catch(error){
    return json({error:error instanceof Error?error.message:"Unable to start Stripe Connect onboarding"},400,headers);
  }
});
