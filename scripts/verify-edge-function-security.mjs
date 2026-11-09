import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const config = readFileSync("supabase/config.toml", "utf8");

function verifyJwtSetting(functionName, expected) {
  const escaped = functionName.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const match = config.match(new RegExp(`\\[functions\\.${escaped}\\]([^\\[]*)`));
  assert.ok(match, `Missing Supabase function config for ${functionName}`);
  const setting = match[1].match(/verify_jwt\\s*=\\s*(true|false)/);
  assert.ok(setting, `Missing explicit verify_jwt setting for ${functionName}`);
  assert.equal(setting[1] === "true", expected, `Unexpected verify_jwt setting for ${functionName}`);
}

for (const [name, expected] of [
  ["guardian-consent", false],
  ["player-account-retention", false],
  ["public-gallery", false],
  ["stripe-webhook", false],
  ["deliver-notifications", true],
  ["create-player-checkout", true],
]) {
  verifyJwtSetting(name, expected);
}

const guardian = readFileSync("supabase/functions/guardian-consent/index.ts", "utf8");
assert.ok(guardian.includes("userClient.auth.getUser()"), "Guardian requests must validate the signed-in player");
assert.ok(guardian.includes("verify_player_guardian_consent") && guardian.includes("withdraw_player_guardian_consent"), "Guardian actions must use the single-use token RPCs");

const retention = readFileSync("supabase/functions/player-account-retention/index.ts", "utf8");
assert.ok(retention.includes('req.headers.get("x-account-retention-secret")'), "Retention worker must validate its cron secret");
assert.ok(retention.includes("get_player_account_reactivation_target") && retention.includes("complete_player_account_reactivation"), "Reactivation must use the token-bound database lifecycle");

const gallery = readFileSync("supabase/functions/public-gallery/index.ts", "utf8");
assert.ok(gallery.includes('.eq("is_active", true)') && gallery.includes('.eq("is_published", true)'), "Public gallery must expose only active locations and published items");

const webhook = readFileSync("supabase/functions/stripe-webhook/index.ts", "utf8");
assert.ok(webhook.includes('req.headers.get("stripe-signature")') && webhook.includes("verifySignature(raw, signature, webhookSecret)"), "Stripe webhook must verify the raw-body Stripe signature");

const notifications = readFileSync("supabase/functions/deliver-notifications/index.ts", "utf8");
assert.ok(notifications.includes('rpc("has_global_admin_role")'), "Manual notification dispatch must require a global administrator");
assert.ok(!notifications.includes('rpc("get_admin_dashboard")'), "Do not rely on the revoked legacy admin dashboard RPC");

const checkout = readFileSync("supabase/functions/create-player-checkout/index.ts", "utf8");
assert.ok(checkout.includes("userClient.auth.getUser(token)"), "Checkout must validate the signed-in user");
assert.ok(!checkout.includes("lovable.app"), "Open Play New must not fall back to the retired Lovable origin");

console.log("Edge Function security configuration and boundary assertions passed.");
