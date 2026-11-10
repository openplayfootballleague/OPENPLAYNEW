import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const config = readFileSync("supabase/config.toml", "utf8");

function verifyJwtSetting(functionName, expected) {
  const escaped = functionName.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const match = config.match(new RegExp(`\\[functions\\.${escaped}\\]([^\\[]*)`));
  assert.ok(match, `Missing Supabase function config for ${functionName}`);
  const setting = match[1].match(/verify_jwt\s*=\s*(true|false)/);
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
  ["create-team-fixture-checkout", true],
  ["team-stripe-webhook", false],
  ["process-team-payment-deadlines", false],
  ["create-referee-connect-account", true],
  ["pay-referee-payout", true],
  ["referee-connect-webhook", false],
]) {
  verifyJwtSetting(name, expected);
}

const guardian = readFileSync("supabase/functions/guardian-consent/index.ts", "utf8");
assert.ok(guardian.includes("userClient.auth.getUser()"), "Guardian requests must validate the signed-in player");
assert.ok(guardian.includes("verify_player_guardian_consent") && guardian.includes("withdraw_player_guardian_consent"), "Guardian actions must use the single-use token RPCs");
assert.ok(!guardian.includes("Their date of birth is"), "Guardian email must not disclose the player date of birth to an unverified address");

const retention = readFileSync("supabase/functions/player-account-retention/index.ts", "utf8");
assert.ok(retention.includes('req.headers.get("x-account-retention-secret")'), "Retention worker must validate its cron secret");
assert.ok(retention.includes("get_player_account_reactivation_target") && retention.includes("complete_player_account_reactivation"), "Reactivation must use the token-bound database lifecycle");
const retentionMigration = readFileSync("supabase/migrations/20261109150000_retry_failed_player_account_erasure.sql", "utf8");
assert.ok(retentionMigration.includes("account_retention_status in ('closed','erasure_due')"), "Expired archive listing must retry accounts already marked erasure_due");
assert.ok(retentionMigration.includes("payment_records") && retentionMigration.includes("partially_refunded") && retentionMigration.includes("player_transfer_requests") && retentionMigration.includes("location_admin_assignments"), "Retention eligibility must preserve unresolved payment, transfer and administrator exclusions");
assert.ok(retentionMigration.includes("if v_previous_status = 'closed' then"), "Repeated erasure queue processing must not duplicate the initial erasure_due audit event");
const reactivationHandler = retention.slice(retention.indexOf('if (req.method === "POST" && mode === "reactivate")'), retention.indexOf('if (req.method !== "POST")'));
assert.ok(!reactivationHandler.includes('updateUserById(userId, { ban_duration: "876000h" })'), "A failed concurrent reactivation attempt must not re-ban an account another request may have successfully reactivated");

const assignmentAudit = readFileSync("supabase/migrations/20261109160000_audit_location_admin_assignments.sql", "utf8");
assert.ok(assignmentAudit.includes("location_admin.assignment_granted") && assignmentAudit.includes("location_admin.assignment_revoked"), "Location administrator grants and revocations must be audited");
assert.ok(assignmentAudit.includes("if p_assigned and not exists") && assignmentAudit.includes("delete from public.location_admin_assignments"), "Stale location assignments must remain revocable after the league_admin role is removed");
assert.ok(assignmentAudit.includes("role in ('admin', 'super_admin')"), "Location assignment mutations must remain global-admin-only");

const gallery = readFileSync("supabase/functions/public-gallery/index.ts", "utf8");
assert.ok(gallery.includes('.eq("is_active", true)') && gallery.includes('.eq("is_published", true)'), "Public gallery must expose only active locations and published items");

const webhook = readFileSync("supabase/functions/stripe-webhook/index.ts", "utf8");
assert.ok(webhook.includes('req.headers.get("stripe-signature")') && webhook.includes("verifySignature(raw, signature, webhookSecret)"), "Stripe webhook must verify the raw-body Stripe signature");

const notifications = readFileSync("supabase/functions/deliver-notifications/index.ts", "utf8");
assert.ok(notifications.includes('rpc("has_global_admin_role")'), "Manual notification dispatch must require a global administrator");
assert.ok(!notifications.includes('rpc("get_admin_dashboard")'), "Do not rely on the revoked legacy admin dashboard RPC");
const deliveryErrors = readFileSync("supabase/functions/deliver-notifications/shared/delivery-errors.ts", "utf8");
assert.ok(!deliveryErrors.includes("JSON.stringify(body)"), "Notification provider errors must not persist raw recipient details");

const checkout = readFileSync("supabase/functions/create-player-checkout/index.ts", "utf8");
assert.ok(checkout.includes("userClient.auth.getUser(token)"), "Checkout must validate the signed-in user");
assert.ok(!checkout.includes("lovable.app"), "Open Play New must not fall back to the retired Lovable origin");

const captainHub = readFileSync("src/routes/captain.tsx", "utf8");
assert.ok(captainHub.includes("fixtures[0].fixture_id") && captainHub.includes("!fixtures.some(f=>f.fixture_id===selectedFixture)"), "Captains Hub must preselect the earliest scheduled fixture and restore its saved or submitted sheet");


const teamCheckout = readFileSync("supabase/functions/create-team-fixture-checkout/index.ts", "utf8");
assert.ok(teamCheckout.includes('userClient.auth.getUser(token)'), "Team checkout must validate the signed-in captain");
assert.ok(teamCheckout.includes('rpc("create_team_fixture_payment_obligation"'), "Team checkout must obtain the fee and obligation from the database");
assert.ok(teamCheckout.includes('Idempotency-Key') && teamCheckout.includes("openplay-team-fixture-"), "Team checkout must use an idempotency key per obligation attempt");
assert.ok(teamCheckout.includes('stripeKey?.startsWith("sk_test_")'), "Team checkout must remain test-mode only");

const teamWebhook = readFileSync("supabase/functions/team-stripe-webhook/index.ts", "utf8");
assert.ok(teamWebhook.includes('req.headers.get("stripe-signature")') && teamWebhook.includes("verifySignature(raw"), "Team Stripe webhook must verify the raw-body signature");
assert.ok(teamWebhook.includes("event.livemode!==false"), "Team Stripe webhook must reject live-mode events");
assert.ok(teamWebhook.includes('rpc("record_team_fixture_payment_success"'), "Team payment state must be driven by the signed webhook");

const teamDeadlineWorker = readFileSync("supabase/functions/process-team-payment-deadlines/index.ts", "utf8");
assert.ok(teamDeadlineWorker.includes('req.headers.get("x-team-payment-cron-secret")'), "Team payment scheduler must validate its dedicated cron secret");
assert.ok(teamDeadlineWorker.includes('Idempotency-Key') && teamDeadlineWorker.includes("openplay-team-refund-"), "Team refunds must be idempotent at the provider");
assert.ok(teamDeadlineWorker.includes('stripeKey?.startsWith("sk_test_")'), "Team payment scheduler must remain test-mode only");

const connectOnboarding = readFileSync("supabase/functions/create-referee-connect-account/index.ts", "utf8");
assert.ok(connectOnboarding.includes("userClient.auth.getUser()"), "Connect onboarding must validate the signed-in referee");
assert.ok(connectOnboarding.includes('stripeKey?.startsWith("sk_test_")'), "Connect onboarding must remain test-mode only");
assert.ok(connectOnboarding.includes('rpc("get_my_referee_connect_status")') && connectOnboarding.includes('rpc("sync_referee_connect_account",'), "Connect onboarding must require active referee membership and synchronize verified account state");
assert.ok(connectOnboarding.includes("metadata[openplay_referee_user_id]"), "Connect accounts must retain the internal referee identity mapping");

const refereePayout = readFileSync("supabase/functions/pay-referee-payout/index.ts", "utf8");
assert.ok(refereePayout.includes("userClient.auth.getUser()"), "Referee payout transfers must validate the signed-in administrator");
assert.ok(refereePayout.includes('rpc("claim_referee_payout_transfer",'), "Referee payout transfers must be claimed through the scoped finance RPC");
assert.ok(refereePayout.includes("Idempotency-Key") && refereePayout.includes("openplay-referee-"), "Referee payout transfers must use attempt-scoped Stripe idempotency keys");
assert.ok(refereePayout.includes('stripeKey?.startsWith("sk_test_")'), "Referee payout transfers must remain test-mode only");
assert.ok(refereePayout.includes("if(!transferCreated&&canMarkFailed)"), "Ambiguous or already-created transfers must remain in reconciliation instead of becoming retryable");

const refereeConnectWebhook = readFileSync("supabase/functions/referee-connect-webhook/index.ts", "utf8");
assert.ok(refereeConnectWebhook.includes('req.headers.get("stripe-signature")') && refereeConnectWebhook.includes("verifyStripeSignature(rawBody,signature,secret)"), "Connect webhook must verify the raw-body Stripe signature");
assert.ok(refereeConnectWebhook.includes("event.livemode!==false"), "Connect webhook must reject live-mode events");
assert.ok(refereeConnectWebhook.includes("referee_connect_webhook_events") && refereeConnectWebhook.includes("processed_at"), "Connect webhook processing must be idempotent and retryable");

console.log("Edge Function security configuration and Phase 1 workflow boundary assertions passed.");
