import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

type EventRow = {
  id: string;
  user_id: string;
  channel: "email" | "sms";
  event_type: string;
  payload: Record<string, unknown>;
};

type RenderedMessage = { subject: string; text: string };

function jwtRole(token: string): string | null {
  try {
    const part = token.split(".")[1];
    if (!part) return null;
    const normalized = part.replace(/-/g, "+").replace(/_/g, "/");
    const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=");
    return JSON.parse(atob(padded)).role ?? null;
  } catch {
    return null;
  }
}

function renderMessage(event: EventRow): RenderedMessage {
  const p = event.payload ?? {};
  const home = String(p.home_team_name ?? "Home team");
  const away = String(p.away_team_name ?? "Away team");
  const gameweek = p.gameweek ? `Gameweek ${p.gameweek}` : "Fixture update";
  const when = p.scheduled_at
    ? new Date(String(p.scheduled_at)).toLocaleString("en-GB", {
        dateStyle: "medium",
        timeStyle: "short",
        timeZone: "Europe/London",
      })
    : "Time to be confirmed";
  const score = `${p.home_score ?? "–"}–${p.away_score ?? "–"}`;

  switch (event.event_type) {
    case "team.membership_approved":
      return { subject: "Open Play – team request approved", text: `Your request to join ${p.team_name ?? "the team"} has been approved.` };
    case "team.membership_rejected":
      return { subject: "Open Play – team request update", text: `Your request to join ${p.team_name ?? "the team"} was not approved. Contact Open Play if you need help.` };
    case "team.registration_approved":
      return { subject: "Open Play – team approved", text: `Your team ${p.team_name ?? ""} has been approved for Open Play.` };
    case "team.registration_rejected":
      return { subject: "Open Play – team registration update", text: `Your team registration for ${p.team_name ?? "Open Play"} was not approved. Contact Open Play if you need help.` };
    case "fixture.scheduled":
      return { subject: `Open Play – ${gameweek} fixture scheduled`, text: `${gameweek}: ${home} v ${away}. ${when}.` };
    case "fixture.reminder_24h":
      return { subject: `Open Play – ${gameweek} fixture tomorrow`, text: `Reminder: ${gameweek}: ${home} v ${away} is scheduled for ${when}, about 24 hours from now.` };
    case "fixture.reminder_3h":
      return { subject: `Open Play – ${gameweek} fixture in 3 hours`, text: `Reminder: ${gameweek}: ${home} v ${away} is scheduled for ${when}, about 3 hours from now.` };
    case "fixture.rescheduled":
      return { subject: `Open Play – ${gameweek} fixture rescheduled`, text: `${gameweek}: ${home} v ${away} has been rescheduled. New time: ${when}.` };
    case "fixture.status_changed":
      return { subject: `Open Play – ${gameweek} fixture update`, text: `${gameweek}: ${home} v ${away} is now ${p.status ?? "updated"}. ${when}.` };
    case "fixture.result_published":
      return { subject: `Open Play – result: ${home} ${score} ${away}`, text: `Full-time result – ${gameweek}: ${home} ${score} ${away}.` };
    case "fixture.result_corrected":
      return { subject: `Open Play – corrected result: ${home} ${score} ${away}`, text: `The result has been corrected – ${gameweek}: ${home} ${score} ${away}.` };
    default:
      throw new Error(`Unsupported notification template: ${event.event_type}`);
  }
}

function normaliseUkPhone(value: string): string | null {
  let phone = value.replace(/[\s().-]/g, "");
  if (phone.startsWith("00")) phone = `+${phone.slice(2)}`;
  else if (phone.startsWith("0")) phone = `+44${phone.slice(1)}`;
  else if (phone.startsWith("44")) phone = `+${phone}`;
  if (!/^\+[1-9]\d{7,14}$/.test(phone)) return null;
  return phone;
}

async function sendEmail(apiKey: string, from: string, to: string, message: RenderedMessage) {
  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" },
    body: JSON.stringify({ from, to: [to], subject: message.subject, text: message.text }),
  });
  const body = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(`Resend returned ${response.status}: ${JSON.stringify(body).slice(0, 800)}`);
  return String(body.id ?? "");
}

async function sendSms(accountSid: string, authToken: string, from: string, to: string, body: string) {
  const payload = new URLSearchParams({ To: to, From: from, Body: body });
  const response = await fetch(`https://api.twilio.com/2010-04-01/Accounts/${accountSid}/Messages.json`, {
    method: "POST",
    headers: {
      Authorization: `Basic ${btoa(`${accountSid}:${authToken}`)}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: payload,
  });
  const result = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(`Twilio returned ${response.status}: ${JSON.stringify(result).slice(0, 800)}`);
  return String(result.sid ?? "");
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405, headers: corsHeaders });

  const authorization = req.headers.get("Authorization") ?? "";
  const token = authorization.replace(/^Bearer\s+/i, "");
  if (!token) return jsonResponse({ error: "Authentication required" }, 401);

  const role = jwtRole(token);
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceKey) return jsonResponse({ error: "Worker service configuration is incomplete" }, 503);

  if (role !== "service_role") {
    if (!anonKey) return jsonResponse({ error: "Admin verification is unavailable" }, 503);
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: `Bearer ${token}` } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { error: adminError } = await userClient.rpc("get_admin_dashboard");
    if (adminError) return jsonResponse({ error: "Administrator permission required" }, 403);
  }

  const resendKey = Deno.env.get("RESEND_API_KEY");
  const resendFrom = Deno.env.get("RESEND_FROM_EMAIL");
  const twilioSid = Deno.env.get("TWILIO_ACCOUNT_SID");
  const twilioToken = Deno.env.get("TWILIO_AUTH_TOKEN");
  const twilioFrom = Deno.env.get("TWILIO_FROM_NUMBER");
  const channels: string[] = [];
  if (resendKey && resendFrom) channels.push("email");
  if (twilioSid && twilioToken && twilioFrom) channels.push("sms");
  if (channels.length === 0) {
    return jsonResponse({ error: "No delivery provider is configured. Add Resend and/or Twilio secrets before processing the queue." }, 503);
  }

  let batchSize = 25;
  try {
    const body = await req.json();
    if (Number.isInteger(body?.batch_size)) batchSize = Math.min(100, Math.max(1, body.batch_size));
  } catch {
    // Empty request body uses the default batch size.
  }

  const service = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { error: staleError } = await service.rpc("mark_stale_notification_events_unconfirmed");
  if (staleError) return jsonResponse({ error: "Unable to reconcile stale notification attempts" }, 500);

  const { data: claimed, error: claimError } = await service.rpc("claim_notification_events", {
    p_limit: batchSize,
    p_channels: channels,
  });
  if (claimError) return jsonResponse({ error: "Unable to claim notification events" }, 500);

  const summary = { claimed: (claimed ?? []).length, sent: 0, failed: 0, unconfirmed: 0 };
  for (const event of (claimed ?? []) as EventRow[]) {
    let providerAccepted = false;
    try {
      const [{ data: player, error: playerError }, { data: profile, error: profileError }] = await Promise.all([
        service.from("players").select("full_name,email,phone").eq("user_id", event.user_id).maybeSingle(),
        service.from("profiles").select("phone").eq("id", event.user_id).maybeSingle(),
      ]);
      if (playerError || profileError) throw new Error("Unable to load notification recipient details");
      const message = renderMessage(event);
      let providerReference = "";

      if (event.channel === "email") {
        const email = String(player?.email ?? "").trim();
        if (!email || !resendKey || !resendFrom) throw new Error("Recipient email or Resend configuration is missing");
        providerReference = await sendEmail(resendKey, resendFrom, email, message);
        providerAccepted = true;
      } else {
        const rawPhone = String(player?.phone ?? profile?.phone ?? "").trim();
        const phone = normaliseUkPhone(rawPhone);
        if (!phone || !twilioSid || !twilioToken || !twilioFrom) throw new Error("Recipient phone or Twilio configuration is missing/invalid");
        providerReference = await sendSms(twilioSid, twilioToken, twilioFrom, phone, message.text);
        providerAccepted = true;
      }

      const { error: completeError } = await service.rpc("complete_notification_event", {
        p_event_id: event.id,
        p_provider_reference: providerReference,
      });
      if (completeError) throw new Error("Provider accepted the message but the outbox could not be marked sent");
      summary.sent += 1;
    } catch (cause) {
      const errorText = cause instanceof Error ? cause.message : "Unknown notification delivery error";
      if (providerAccepted) {
        await service.rpc("mark_notification_event_unconfirmed", { p_event_id: event.id, p_error: errorText });
        summary.unconfirmed += 1;
      } else {
        await service.rpc("fail_notification_event", { p_event_id: event.id, p_error: errorText });
        summary.failed += 1;
      }
    }
  }

  return jsonResponse(summary, 200);
});
