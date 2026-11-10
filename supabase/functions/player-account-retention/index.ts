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

async function sendInactivityWarningEmail(
  apiKey: string,
  from: string,
  to: string,
  warningDays: number,
  closureAt: string,
  idempotencyKey: string,
) {
  const originalClosureAt = new Date(closureAt).getTime();
  const minimumNoticeEnd = Date.now() + 7 * 24 * 60 * 60 * 1000;
  const closureDate = new Date(Math.max(originalClosureAt, minimumNoticeEnd)).toLocaleDateString("en-GB", {
    day: "numeric",
    month: "long",
    year: "numeric",
    timeZone: "Europe/London",
  });
  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
      "Idempotency-Key": idempotencyKey,
    },
    body: JSON.stringify({
      from,
      to: [to],
      subject: `Open Play – ${warningDays}-day account inactivity notice`,
      text: `You have not signed in to your Open Play registered-player account for some time.

This is the ${warningDays}-day warning stage in Open Play's 12-month inactivity process. If you do not sign in, your account may be closed no earlier than ${closureDate}. The date allows for the required final seven-day notice period, including where an earlier warning was delayed.

Sign in to Open Play before that date to keep your account active and reset the inactivity period.

If your account closes, it will remain in a restricted archive for a further 12 months. You can request reactivation during that period. Your historic fixtures, appearances and goals are preserved.

If you believe this notice is incorrect or need help, contact openplayfootballleague@gmail.com.

Open Play`,
    }),
  });
  if (!response.ok) throw new Error(`Inactivity warning email provider returned ${response.status}`);
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
      // Do not re-ban here: another concurrent request may already have
      // consumed the single-use token and successfully reactivated the account.
      // If completion did not commit, the root account-status gate still denies
      // private access while the profile remains closed. A compensating Auth ban
      // here could undo a successful concurrent reactivation.
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
        console.error("Player account reactivation email delivery failed");
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

    const resendKey = Deno.env.get("RESEND_API_KEY");
    const resendFrom = Deno.env.get("RESEND_FROM_EMAIL");
    if (!resendKey || !resendFrom) {
      return json({ error: "Inactivity warning email delivery is not configured; no accounts were processed" }, 503);
    }

    const { data: warnings, error: warningClaimError } = await service.rpc("admin_claim_player_account_inactivity_warnings");
    if (warningClaimError) return json({ error: "Unable to claim inactivity warning emails; no accounts were processed" }, 500);

    let warningsSent = 0;
    let warningFailures = 0;
    for (const warning of warnings ?? []) {
      const idempotencyHash = await hashToken(
        `${warning.user_id}:${warning.inactivity_started_at}:${warning.warning_days}`,
      );
      try {
        await sendInactivityWarningEmail(
          resendKey,
          resendFrom,
          warning.email,
          Number(warning.warning_days),
          warning.closure_at,
          `openplay-inactivity-${idempotencyHash}`,
        );
      } catch {
        await service.rpc("admin_finish_player_account_inactivity_warning", {
          p_user_id: warning.user_id,
          p_inactivity_started_at: warning.inactivity_started_at,
          p_warning_days: warning.warning_days,
          p_delivered: false,
        });
        warningFailures++;
        console.error("Player inactivity warning delivery failed");
        continue;
      }

      const { data: recorded, error: recordError } = await service.rpc(
        "admin_finish_player_account_inactivity_warning",
        {
          p_user_id: warning.user_id,
          p_inactivity_started_at: warning.inactivity_started_at,
          p_warning_days: warning.warning_days,
          p_delivered: true,
        },
      );
      if (recordError || recorded !== true) {
        warningFailures++;
        console.error("Unable to record successful inactivity warning delivery");
      } else {
        warningsSent++;
      }
    }

    // Fail closed: do not close or erase accounts during a run where a due
    // warning could not be delivered or recorded. The SQL closure trigger also
    // requires all three stages and a full seven-day grace period after stage 7.
    if (warningFailures > 0) {
      return json({ warningsSent, warningFailures, error: "Warning delivery incomplete; no account closure or erasure was attempted" }, 503);
    }

    const { data: candidates, error: candidatesError } = await service.rpc("admin_list_inactive_player_accounts");
    if (candidatesError) return json({ warningsSent, warningFailures, error: "Unable to load inactive player accounts" }, 500);

    let closed = 0;
    let skipped = 0;
    for (const candidate of candidates ?? []) {
      const { error: banError } = await service.auth.admin.updateUserById(candidate.user_id, { ban_duration: "876000h" });
      if (banError) { skipped++; console.error("Unable to close inactive player account", banError.code ?? "unknown"); continue; }

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
    let erasedAccounts = 0;
    let erasureFailures = 0;
    for (const candidate of expired ?? []) {
      const userId = String(candidate.user_id);
      const { data: marked, error: markError } = await service.rpc("admin_mark_player_account_erasure_due", {
        p_user_id: userId,
      });
      if (markError || marked !== true) {
        erasureFailures++;
        console.error("Unable to mark player archive erasure due", markError?.code ?? "unknown");
        continue;
      }
      markedErasureDue++;

      // Remove the public avatar object before clearing its path from the profile.
      // If storage deletion fails, leave the account record intact and retry tomorrow.
      const { data: profile, error: profileError } = await service
        .from("profiles")
        .select("avatar_path")
        .eq("id", userId)
        .maybeSingle();
      if (profileError || !profile) {
        erasureFailures++;
        console.error("Unable to load player avatar for erasure", profileError?.code ?? "unknown");
        continue;
      }
      if (profile.avatar_path) {
        const { error: avatarError } = await service.storage
          .from("profile-avatars")
          .remove([profile.avatar_path]);
        if (avatarError) {
          erasureFailures++;
          console.error("Unable to remove player avatar before erasure", avatarError.name ?? "unknown");
          continue;
        }
      }

      const { data: prepared, error: prepareError } = await service.rpc("admin_prepare_player_account_erasure", {
        p_user_id: userId,
      });
      if (prepareError || prepared !== true) {
        erasureFailures++;
        console.error("Unable to anonymise player competition identity", prepareError?.code ?? "unknown");
        continue;
      }

      // The database transaction has removed personal links from competition history,
      // scrubbed profile/contact data and detached restrictive historical foreign keys.
      // Auth deletion now cascades only the live account/profile/player records.
      const { error: deleteError } = await service.auth.admin.deleteUser(userId);
      if (deleteError) {
        erasureFailures++;
        console.error("Unable to delete anonymised Auth account; it remains banned for retry", deleteError.name ?? "unknown");
        continue;
      }
      erasedAccounts++;
    }

    return json({
      warningsSent,
      warningFailures,
      closed,
      skipped,
      markedErasureDue,
      erasedAccounts,
      erasureFailures,
      note: "Competition history is retained against a random account-independent identity labelled Former player. Live profile, registration and Auth account data are deleted after archive expiry; payment records remain subject to their separate retention schedule.",
    });
  }

  return json({ error: "Unsupported action" }, 400);
});
