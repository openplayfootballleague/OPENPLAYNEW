import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

function constantTimeEqual(a:Uint8Array,b:Uint8Array){
  if(a.length!==b.length)return false;
  let diff=0;for(let i=0;i<a.length;i++)diff|=a[i]^b[i];
  return diff===0;
}
function hexBytes(hex:string):Uint8Array|null{
  if(!/^[a-f0-9]+$/i.test(hex)||hex.length%2)return null;
  const out=new Uint8Array(hex.length/2);
  for(let i=0;i<out.length;i++)out[i]=parseInt(hex.slice(i*2,i*2+2),16);
  return out;
}
async function verifySignature(raw:string,header:string,secret:string){
  const parts=header.split(",").map(part=>part.split("=",2));
  const timestamp=parts.find(([key])=>key==="t")?.[1];
  const signatures=parts.filter(([key])=>key==="v1").map(([,value])=>value);
  if(!timestamp||!/^\d+$/.test(timestamp)||Math.abs(Date.now()/1000-Number(timestamp))>300)return false;
  const key=await crypto.subtle.importKey("raw",new TextEncoder().encode(secret),{name:"HMAC",hash:"SHA-256"},false,["sign"]);
  const expected=new Uint8Array(await crypto.subtle.sign("HMAC",key,new TextEncoder().encode(`${timestamp}.${raw}`)));
  return signatures.some(signature=>{
    const candidate=hexBytes(signature);
    return candidate!==null&&constantTimeEqual(expected,candidate);
  });
}

Deno.serve(async(req)=>{
  if(req.method!=="POST")return new Response("Method not allowed",{status:405});
  const stripeKey=Deno.env.get("STRIPE_SECRET_KEY");
  const webhookSecret=Deno.env.get("TEAM_STRIPE_WEBHOOK_SECRET");
  const supabaseUrl=Deno.env.get("SUPABASE_URL");
  const serviceKey=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if(!stripeKey?.startsWith("sk_test_")||!webhookSecret||!supabaseUrl||!serviceKey){
    return new Response("Team Stripe webhook is not configured for test mode",{status:503});
  }
  const raw=await req.text();
  if(!await verifySignature(raw,req.headers.get("stripe-signature")??"",webhookSecret)){
    return new Response("Invalid Stripe signature",{status:400});
  }
  let event:Record<string,unknown>;
  try{event=JSON.parse(raw);}catch{return new Response("Invalid event payload",{status:400});}
  if(event.livemode!==false)return new Response("Live-mode events are disabled",{status:400});
  const eventId=String(event.id??"");
  const eventType=String(event.type??"");
  const created=Number(event.created);
  if(!eventId||!eventType||!Number.isSafeInteger(created)||created<=0){
    return new Response("Incomplete event metadata",{status:400});
  }

  const admin=createClient(supabaseUrl,serviceKey,{auth:{persistSession:false,autoRefreshToken:false}});
  const object=(event.data as Record<string,unknown>|undefined)?.object as Record<string,unknown>|undefined;
  const metadata=object?.metadata as Record<string,unknown>|undefined;
  const obligationId=String(metadata?.team_fixture_payment_obligation_id??"");
  const sessionId=String(object?.id??"");
  const supported=new Set([
    "checkout.session.completed",
    "checkout.session.async_payment_succeeded",
    "checkout.session.async_payment_failed",
    "checkout.session.expired",
  ]);
  if(!supported.has(eventType))return Response.json({received:true,ignored:true});

  const {error:insertError}=await admin.from("team_stripe_webhook_events")
    .insert({id:eventId,event_type:eventType,obligation_id:obligationId||null});
  if(insertError){
    if(insertError.code!=="23505")return new Response("Could not record webhook event",{status:500});
    const {data:prior,error:priorError}=await admin.from("team_stripe_webhook_events")
      .select("processed_at,processing_started_at").eq("id",eventId).maybeSingle();
    if(priorError)return new Response("Could not inspect webhook retry state",{status:500});
    if(prior?.processed_at)return Response.json({received:true,duplicate:true});
    const leaseCutoff=new Date(Date.now()-5*60*1000).toISOString();
    const {data:claim,error:claimError}=await admin.from("team_stripe_webhook_events")
      .update({processing_started_at:new Date().toISOString(),processing_error:null})
      .eq("id",eventId).is("processed_at",null)
      .or(`processing_started_at.is.null,processing_started_at.lt.${leaseCutoff}`)
      .select("id").maybeSingle();
    if(claimError)return new Response("Could not claim webhook event",{status:500});
    if(!claim)return new Response("Webhook event is already being processed",{status:409});
  }else{
    await admin.from("team_stripe_webhook_events")
      .update({processing_started_at:new Date().toISOString()}).eq("id",eventId);
  }

  try{
    if(!obligationId||!sessionId)throw new Error("Team payment metadata is missing");
    const {data:obligation,error:obligationError}=await admin.from("team_fixture_payment_obligations")
      .select("id,amount_pence,currency,status,stripe_checkout_session_id")
      .eq("id",obligationId).single();
    if(obligationError||!obligation)throw new Error("Team payment obligation could not be found");
    if(obligation.stripe_checkout_session_id!==sessionId)throw new Error("Checkout session does not match the stored payment attempt");

    if(eventType==="checkout.session.completed"||eventType==="checkout.session.async_payment_succeeded"){
      if(object?.payment_status==="paid"){
        const amount=Number(object.amount_total);
        const currency=String(object.currency??"").toLowerCase();
        const paymentIntent=typeof object.payment_intent==="string"?object.payment_intent:"";
        if(amount!==obligation.amount_pence||currency!==obligation.currency||!paymentIntent){
          throw new Error("Stripe amount, currency or PaymentIntent does not match the server-side obligation");
        }
        const {error:paymentError}=await admin.rpc("record_team_fixture_payment_success",{
          p_obligation_id:obligationId,
          p_stripe_payment_intent_id:paymentIntent,
          p_paid_at:new Date(created*1000).toISOString(),
        });
        if(paymentError)throw new Error(paymentError.message);
      }else if(eventType==="checkout.session.async_payment_succeeded"){
        throw new Error("Stripe reported asynchronous success without a paid Checkout session");
      }
    }else if(eventType==="checkout.session.expired"||eventType==="checkout.session.async_payment_failed"){
      await admin.rpc("clear_team_fixture_payment_checkout_session",{
        p_obligation_id:obligationId,p_session_id:sessionId,
      });
    }

    const {error:finishError}=await admin.from("team_stripe_webhook_events")
      .update({processed_at:new Date().toISOString(),processing_started_at:null,processing_error:null})
      .eq("id",eventId);
    if(finishError)throw new Error("Could not mark the webhook event as processed");
    return Response.json({received:true});
  }catch(cause){
    const message=cause instanceof Error?cause.message:"Team payment webhook failed";
    await admin.from("team_stripe_webhook_events")
      .update({processing_error:message.slice(0,500),processing_started_at:null})
      .eq("id",eventId);
    return new Response(message,{status:500});
  }
});
