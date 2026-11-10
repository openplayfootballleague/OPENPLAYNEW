import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
const appOrigin=Deno.env.get("APP_ORIGIN")??"";
const cors={"Access-Control-Allow-Origin":appOrigin,"Access-Control-Allow-Headers":"authorization, apikey, content-type, x-client-info","Access-Control-Allow-Methods":"POST, OPTIONS","Vary":"Origin"};
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{"Content-Type":"application/json",...cors}});
Deno.serve(async(req)=>{
  if(req.method==="OPTIONS")return new Response("ok",{headers:cors});
  if(req.method!=="POST")return json({error:"Method not allowed"},405);
  const origin=req.headers.get("origin");
  if(origin&&origin!==appOrigin)return json({error:"Origin not allowed"},403);
  const stripeKey=Deno.env.get("STRIPE_SECRET_KEY");
  const url=Deno.env.get("SUPABASE_URL");
  const anon=Deno.env.get("SUPABASE_ANON_KEY");
  const service=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if(!stripeKey?.startsWith("sk_test_")||!url||!anon||!service||!appOrigin)return json({error:"Stripe Connect is not configured for test mode"},503);
  const token=(req.headers.get("authorization")??"").replace(/^Bearer\s+/i,"");
  if(!token)return json({error:"Sign in to continue"},401);
  const userClient=createClient(url,anon,{global:{headers:{Authorization:`Bearer ${token}`}},auth:{persistSession:false,autoRefreshToken:false}});
  const {data:authData,error:authError}=await userClient.auth.getUser(token);
  if(authError||!authData.user)return json({error:"Your session is invalid or expired"},401);
  const admin=createClient(url,service,{auth:{persistSession:false,autoRefreshToken:false}});
  const {data:membership,error:membershipError}=await admin.from("referee_memberships").select("status").eq("user_id",authData.user.id).maybeSingle();
  if(membershipError||membership?.status!=="active")return json({error:"An active referee membership is required"},403);
  const {data:account,error:accountError}=await admin.from("referee_stripe_connect_accounts")
    .select("stripe_account_id").eq("referee_user_id",authData.user.id).maybeSingle();
  if(accountError)return json({error:"Could not load your Stripe account"},500);
  if(!account?.stripe_account_id)return json({connected:false,details_submitted:false,payouts_enabled:false,requirements_currently_due:[],requirements_past_due:[]});
  const response=await fetch(`https://api.stripe.com/v1/accounts/${encodeURIComponent(account.stripe_account_id)}`,{
    headers:{Authorization:`Bearer ${stripeKey}`},
  });
  const stripeAccount=await response.json().catch(()=>({})) as Record<string,unknown>;
  if(!response.ok)return json({error:"Stripe could not refresh your connected account"},502);
  const requirements=stripeAccount.requirements as Record<string,unknown>|undefined;
  const {error:syncError}=await admin.rpc("sync_referee_stripe_connect_account",{
    p_referee_user_id:authData.user.id,
    p_stripe_account_id:String(stripeAccount.id??""),
    p_details_submitted:Boolean(stripeAccount.details_submitted),
    p_charges_enabled:Boolean(stripeAccount.charges_enabled),
    p_payouts_enabled:Boolean(stripeAccount.payouts_enabled),
    p_requirements_currently_due:Array.isArray(requirements?.currently_due)?requirements.currently_due:[],
    p_requirements_past_due:Array.isArray(requirements?.past_due)?requirements.past_due:[],
    p_disabled_reason:requirements?.disabled_reason??null,
  });
  if(syncError)return json({error:"Stripe status could not be saved"},500);
  return json({
    connected:true,
    details_submitted:Boolean(stripeAccount.details_submitted),
    payouts_enabled:Boolean(stripeAccount.payouts_enabled),
    requirements_currently_due:Array.isArray(requirements?.currently_due)?requirements.currently_due:[],
    requirements_past_due:Array.isArray(requirements?.past_due)?requirements.past_due:[],
    disabled_reason:requirements?.disabled_reason??null,
  });
});
