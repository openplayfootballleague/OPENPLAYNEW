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
    headers: { ...corsHeaders, "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

function html(title: string, message: string, form = false) {
  const content = form
    ? `<p>Confirm that you want to reopen your Open Play registered-player account.</p><form method="post"><input type="hidden" name="token" value=""><button type="submit">REACTIVATE ACCOUNT</button></form><script>(()=>{const token=new URLSearchParams(location.hash.slice(1)).get("token")??"";const field=document.querySelector('input[name="token"]');if(field instanceof HTMLInputElement&&/^[0-9a-f]{64}$/.test(token))field.value=token;history.replaceState(null,"",location.pathname+location.search);})();</script>`
    : `<p>${message}</p>`;
  return new Response(
    `<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${title} – Open Play</title><body style="font-family:system-ui;max-width:560px;margin:12vh auto;padding:24px;color:#171c18"><p style="color:#f36b32;font-weight:700;letter-spacing:.12em">OPEN PLAY</p><h1>${title}</h1>${content}<style>button{background:#f36b32;color:#171c18;border:0;padding:14px 20px;font-weight:700;cursor:pointer}</style></body></html>`,
    { status: 200, headers: { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "no-store", "Referrer-Policy": "no-referrer", "X-Content-Type-Options": "nosniff" } },
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

async function sendReactivationEmail(apiKey: string, from: string, to: string, url: string) {
  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      from,
      to: [to],
      subject: "Open Play – reactivate your player account",
      text: `You requested to reactivate your Open Play registered-player account.

Use this single-use link within 24 hours:
${url}

Reactivating restores your registered-player account, but does not restore any previous team membership, pending request, captaincy or squad permissions. You return as a registered player without a club and can request to join a team again.

If you did not request this, ignore this email.

Open Play`,
    }),
  });
  if (!response.ok) throw new Error(`Reactivation email provider returned ${response.status}`);
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceKey) return json({ error: "Account retention service is not configured" }, 503);

  const service = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const url = new URL(req.url);
  const mode = url.searchParams.get("mode");

  if (req.method === "GET" && mode === "reactivate") {
    return html("Reactivate your account", "", true);
  }

  if (req.method === "POST" && mode === "reactivate") {
    let token = "";
    const type = req.headers.get("content-type") ?? "";
    if (type.includes("application/x-www-form-urlencoded")) {
      token = String(new URLSearchParams(await req.text()).get("token") ?? "");
    } else {
      try { token = String((await req.json()).token ?? ""); } catch { return html("Link invalid", "This reactivation link is invalid or expired."); }
    }
    if (!/^[0-9a-f]{64}$/.test(token)) return html("Link invalid", "This reactivation link is invalid or expired.");

    const tokenHash = await hashToken(token);
    const { data: userId, error: lookupError } = await service.rpc("get_player_account_reactivation_target", {
      p_token_hash: tokenHash,
    });
    if (lookupError || !userId) return html("Link expired", "This reactivation link is invalid, expired or has already been used.");

    const { error: unbanError } = await service.auth.admin.updateUserById(userId, { ban_duration: "none" });
    if (unbanError) return html("Please try again", "We could not reactivate your account just now. Please request a new link or contact Open Play.");

    const { data: completed, error: completeError } = await service.rpc("complete_player_account_reactivation", {
      p_user_id: userId,
      p_token_hash: tokenHash,
    });
    if (completeError || completed !== true) {
      await service.auth.admin.updateUserById(userId, { ban_duration: "876000h" });
      return html("Link expired", "This reactivation link is invalid, expired or has already been used.");
    }

    return html("Account reactivated", "Your registered-player account is active again. You can now return to Open Play and sign in. You will not be attached to a club or team automatically.");
  }

  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return json({ error: "Invalid request body" }, 400); }

  if (body.action === "request-reactivation") {
    const email = String(body.email ?? "").trim().toLowerCase();
    if (!email || email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return json({ message: "If an eligible closed account exists for that email address, a reactivation link will be sent." });
    }
    const resendKey = Deno.env.get("RESEND_API_KEY");
    const resendFrom = Deno.env.get("RESEND_FROM_EMAIL");
    if (!resendKey || !resendFrom) {
      console.error("Player account reactivation email is not configured");
      return json({ message: "If an eligible closed account exists for that email address, a reactivation link will be sent." });
    }

    const token = randomToken();
    const tokenHash = await hashToken(token);
    const { data, error } = await service.rpc("request_player_account_reactivation", {
      p_email: email,
      p_token_hash: tokenHash,
    });

    if (!error && Array.isArray(data) && data[0]?.email) {
      const link = `https://${new URL(supabaseUrl).host}/functions/v1/player-account-retention?mode=reactivate#token=${token}`;
      try {
        await sendReactivationEmail(resendKey, resendFrom, data[0].email, link);
      } catch (cause) {
        // Keep the public response generic. A fresh request can replace the
        // unusable token after the database-enforced cooldown.
        console.error("Player account reactivation email failed", cause);
      }
    }
    return json({ message: "If an eligible closed account exists for that email address, a reactivation link will be sent." });
  }

  if (body.action === "process-inactivity") {
    const expectedSecret = Deno.env.get("ACCOUNT_RETENTION_CRON_SECRET");
    const suppliedSecret = req.headers.get("x-account-retention-secret");
    if (!expectedSecret || !suppliedSecret || suppliedSecret !== expectedSecret) {
      return json({ error: "Not authorised" }, 401);
    }

    const { data: candidates, error: candidatesError } = await service.rpc("admin_list_inactive_player_accounts");
    if (candidatesError) return json({ error: "Unable to load inactive player accounts" }, 500);

    let closed = 0;
    let skipped = 0;
    for (const candidate of candidates ?? []) {
      const { error: banError } = await service.auth.admin.updateUserById(candidate.user_id, { ban_duration: "876000h" });
      if (banError) { skipped++; console.error("Unable to close inactive player account", candidate.user_id, banError.message); continue; }

      const { data: didClose, error: closeError } = await service.rpc("admin_close_inactive_player_account", {
        p_user_id: candidate.user_id,
      });
      if (closeError || didClose !== true) {
        await service.auth.admin.updateUserById(candidate.user_id, { ban_duration: "none" });
        skipped++;
      } else {
        closed++;
      }
    }

    const { data: expired, error: expiredError } = await service.rpc("admin_list_expired_player_account_archives");
    if (expiredError) return json({ closed, skipped, error: "Unable to load expired archives" }, 500);

    let markedErasureDue = 0;
    for (const candidate of expired ?? []) {
      const { data: marked, error } = await service.rpc("admin_mark_player_account_erasure_due", {
        p_user_id: candidate.user_id,
      });
      if (!error && marked === true) markedErasureDue++;
    }

    return json({
      closed,
      skipped,
      markedErasureDue,
      note: "Erasure-due accounts are queued for the separately audited historical anonymisation process; this worker does not hard-delete Auth users or competition history.",
    });
  }

  return json({ error: "Unsupported action" }, 400);
});
