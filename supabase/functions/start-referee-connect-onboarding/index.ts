import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{"Content-Type":"application/json"}});
async function stripeRequest(key:string,path:string,method="GET",body?:URLSearchParams,idempotencyKey?:string){
  const headers:Record<string,string>={Authorization:`Bearer ${key}`};
  if(body)headers["Content-Type"]="application/x-www-form-urlencoded";
  if(idempotencyKey)headers["Idempotency-Key"]=idempotencyKey;
  const response=await fetch("https://api.stripe.com/v1/"+path,{method,headers,body});
  const data=await response.json().catch(()=>({}));
  return {ok:response.ok,status:response.status,data:data as Record<string,unknown>};
}
Deno.serve(async(req)=>{
  if(req.method!=="POST")return json({error:"Method not allowed"},405);
  const origin=req.headers.get("origin");
  const appOrigin=Deno.env.get("APP_ORIGIN")??"";
  if(origin&&origin!==appOrigin)return json({error:"Origin not allowed"},403);
  const stripeKey=Deno.env.get("STRIPE_SECRET_KEY");
  const supabaseUrl=Deno.env.get("SUPABASE_URL");
  const anonKey=Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if(!stripeKey?.startsWith("sk_test_")||!supabaseUrl||!anonKey||!serviceKey||!appOrigin){
    return json({error:"Stripe Connect is not configured for test mode"},503);
  }
  const token=(req.headers.get("authorization")??"").replace(/^Bearer\s+/i,"");
  if(!token)return json({error:"Sign in to continue"},401);
  const userClient=createClient(supabaseUrl,anonKey,{global:{headers:{Authorization:`Bearer ${token}`}},auth:{persistSession:false,autoRefreshToken:false}});
  const {data:authData,error:authError}=await userClient.auth.getUser(token);
  if(authError||!authData.user)return json({error:"Your session is invalid or expired"},401);
  const user=authData.user;
  const admin=createClient(supabaseUrl,serviceKey,{auth:{persistSession:false,autoRefreshToken:false}});
  const {data:membership,error:membershipError}=await admin.from("referee_memberships")
    .select("status").eq("user_id",user.id).maybeSingle();
  if(membershipError||membership?.status!=="active")return json({error:"An active referee membership is required"},403);

  let accountId="";
  let account:Record<string,unknown>={};
  const {data:existing,error:existingError}=await admin.from("referee_stripe_connect_accounts")
    .select("stripe_account_id").eq("referee_user_id",user.id).maybeSingle();
  if(existingError)return json({error:"Could not load your Stripe account"},500);
  if(existing?.stripe_account_id){
    accountId=existing.stripe_account_id;
    const retrieved=await stripeRequest(stripeKey,`accounts/${encodeURIComponent(accountId)}`);
    if(!retrieved.ok)return json({error:"Stripe could not retrieve your connected account"},502);
    account=retrieved.data;
  }else{
    const form=new URLSearchParams({
      type:"express",country:"GB",business_type:"individual",
      "capabilities[transfers][requested]":"true",
      "metadata[openplay_referee_user_id]":user.id,
    });
    if(user.email)form.set("email",user.email);
    const created=await stripeRequest(stripeKey,"accounts","POST",form,`openplay-referee-connect-${user.id}`);
    if(!created.ok)return json({error:String(created.data.error??"Stripe could not create a connected account")},502);
    account=created.data;
    accountId=String(account.id??"");
    if(!/^acct_[A-Za-z0-9]+$/.test(accountId))return json({error:"Stripe returned an invalid connected account"},502);
  }
  const requirements=account.requirements as Record<string,unknown>|undefined;
  const {error:syncError}=await admin.rpc("sync_referee_stripe_connect_account",{
    p_referee_user_id:user.id,
    p_stripe_account_id:accountId,
    p_details_submitted:Boolean(account.details_submitted),
    p_charges_enabled:Boolean(account.charges_enabled),
    p_payouts_enabled:Boolean(account.payouts_enabled),
    p_requirements_currently_due:Array.isArray(requirements?.currently_due)?requirements.currently_due:[],
    p_requirements_past_due:Array.isArray(requirements?.past_due)?requirements.past_due:[],
    p_disabled_reason:requirements?.disabled_reason??null,
  });
  if(syncError)return json({error:"Connected account was created but its status could not be saved"},500);

  const linkForm=new URLSearchParams({
    account:accountId,
    type:Boolean(account.details_submitted)?"account_update":"account_onboarding",
    refresh_url:`${appOrigin.replace(/\/$/,"")}/referee?stripe=refresh`,
    return_url:`${appOrigin.replace(/\/$/,"")}/referee?stripe=return`,
  });
  const link=await stripeRequest(stripeKey,"account_links","POST",linkForm);
  if(!link.ok||typeof link.data.url!=="string")return json({error:"Stripe could not create an onboarding link"},502);
  return json({url:link.data.url});
});
