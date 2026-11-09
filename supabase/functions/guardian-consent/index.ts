import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function page(title: string, message: string, token: string, action: "verify" | "withdraw") {
  const safeToken = token.replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/</g, "&lt;");
  const label = action === "verify" ? "Confirm guardian consent" : "Withdraw guardian consent";
  return new Response(
    `<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${title} – Open Play</title><body style="font-family:system-ui;max-width:560px;margin:12vh auto;padding:24px;color:#171c18"><p style="color:#f36b32;font-weight:700;letter-spacing:.12em">OPEN PLAY</p><h1>${title}</h1><p>${message}</p><form method="post"><input type="hidden" name="token" value="${safeToken}"><button style="background:#f36b32;color:#171c18;border:0;padding:14px 20px;font-weight:700;cursor:pointer" type="submit">${label}</button></form></body></html>`,
    { status: 200, headers: { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "no-store" } },
  );
}

function resultPage(title: string, message: string, status = 200) {
  return new Response(
    `<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${title} – Open Play</title><body style="font-family:system-ui;max-width:560px;margin:12vh auto;padding:24px;color:#171c18"><p style="color:#f36b32;font-weight:700;letter-spacing:.12em">OPEN PLAY</p><h1>${title}</h1><p>${message}</p></body></html>`,
    { status, headers: { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "no-store" } },
  );
}

function randomToken() {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return [...bytes].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

async function hashToken(token: string) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(token));
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

async function sendConsentEmail(apiKey: string, from: string, to: string, guardianName: string, playerDob: string, verifyUrl: string, withdrawUrl: string) {
  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      from,
      to: [to],
      subject: "Open Play – parent or legal-guardian consent required",
      text: `Hello ${guardianName},

A player has asked Open Play to verify your consent for them to register as a player. Their date of birth is ${playerDob}.

Please review the request and confirm that you are their parent or legal guardian:
${verifyUrl}

After confirmation, Open Play administrators will review the consent before player registration can proceed.

If you do not wish to provide consent, take no action. If you later need to withdraw consent, use this private link:
${withdrawUrl}

If you did not expect this email, you can ignore it. Do not forward these links.

Open Play`,
    }),
  });
  const body = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(`Consent email provider returned ${response.status}: ${JSON.stringify(body).slice(0, 500)}`);
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  const url = new URL(req.url);
  const action = url.pathname.split("/").filter(Boolean).at(-1);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceKey) return json({ error: "Consent service configuration is incomplete" }, 503);
  const service = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });

  if (action === "request" && req.method === "POST") {
    const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\\s+/i, "");
    if (!token || !anonKey) return json({ error: "Sign in before requesting guardian consent" }, 401);
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: `Bearer ${token}` } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: userData, error: userError } = await userClient.auth.getUser();
    if (userError || !userData.user?.email_confirmed_at) return json({ error: "A verified Open Play account is required" }, 401);

    let body: Record<string, unknown>;
    try { body = await req.json(); } catch { return json({ error: "Invalid request body" }, 400); }
    const dob = String(body.date_of_birth ?? "");
    const guardianName = String(body.guardian_full_name ?? "").trim();
    const guardianEmail = String(body.guardian_email ?? "").trim().toLowerCase();
    if (!/^\\d{4}-\\d{2}-\\d{2}$/.test(dob) || guardianName.length < 2 || guardianName.length > 120 || guardianEmail.length > 254) {
      return json({ error: "Enter a valid date of birth, guardian name and guardian email address" }, 400);
    }
    const verifyToken = randomToken();
    const withdrawalToken = randomToken();
    const { error: requestError } = await userClient.rpc("request_player_guardian_consent", {
      p_player_date_of_birth: dob,
      p_guardian_full_name: guardianName,
      p_guardian_email: guardianEmail,
      p_verification_token_hash: await hashToken(verifyToken),
      p_withdrawal_token_hash: await hashToken(withdrawalToken),
    });
    if (requestError) return json({ error: requestError.message }, 400);

    const resendKey = Deno.env.get("RESEND_API_KEY");
    const resendFrom = Deno.env.get("RESEND_FROM_EMAIL");
    if (!resendKey || !resendFrom) return json({ error: "Guardian consent email is not configured. Contact Open Play support." }, 503);
    const base = `${supabaseUrl}/functions/v1/guardian-consent`;
    try {
      await sendConsentEmail(resendKey, resendFrom, guardianEmail, guardianName, dob,
        `${base}/verify?token=${encodeURIComponent(verifyToken)}`,
        `${base}/withdraw?token=${encodeURIComponent(withdrawalToken)}`);
    } catch (cause) {
      return json({ error: cause instanceof Error ? cause.message : "Unable to send guardian consent email" }, 502);
    }
    return json({ status: "pending_verification", message: "A consent email has been sent to the parent or legal guardian." });
  }

  if ((action === "verify" || action === "withdraw") && req.method === "GET") {
    const token = url.searchParams.get("token") ?? "";
    if (!/^[0-9a-f]{64}$/.test(token)) return resultPage("Invalid link", "This link is invalid or incomplete.", 400);
    return action === "verify"
      ? page("Confirm consent", "Please confirm that you are the parent or legal guardian and consent to this 16- or 17-year-old registering as an Open Play player. Open Play administrators will also review the request.", token, "verify")
      : page("Withdraw consent", "If you withdraw consent, the player's Open Play registration and active team memberships will be suspended.", token, "withdraw");
  }

  if ((action === "verify" || action === "withdraw") && req.method === "POST") {
    let token = "";
    try {
      const form = await req.formData();
      token = String(form.get("token") ?? "");
    } catch {
      try { token = String((await req.json()).token ?? ""); } catch { /* invalid body */ }
    }
    if (!/^[0-9a-f]{64}$/.test(token)) return resultPage("Invalid link", "This link is invalid or incomplete.", 400);
    const rpc = action === "verify" ? "verify_player_guardian_consent" : "withdraw_player_guardian_consent";
    const { error } = await service.rpc(rpc, { p_token: token });
    if (error) return resultPage("Link unavailable", "This link may have expired, already been used, or been withdrawn. Please contact Open Play for help.", 400);
    return action === "verify"
      ? resultPage("Consent confirmed", "Thank you. Your confirmation has been recorded. Open Play administrators will review it before the player can register.")
      : resultPage("Consent withdrawn", "Your withdrawal has been recorded. The player's registration and active team memberships have been suspended.");
  }

  return json({ error: "Not found" }, 404);
});
