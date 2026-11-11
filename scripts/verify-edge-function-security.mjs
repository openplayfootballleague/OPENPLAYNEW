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
  ["process-referee-payout-queue", false],
  ["admin-postpone-gameweek", true],
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

const weatherPostponement = readFileSync("supabase/functions/admin-postpone-gameweek/index.ts", "utf8");
assert.ok(weatherPostponement.includes("userClient.auth.getUser(token)"), "Weather postponement must validate the signed-in administrator");
assert.ok(weatherPostponement.includes('rpc("get_admin_postponable_gameweeks"') && weatherPostponement.includes('rpc("admin_postpone_gameweek"'), "Weather postponement must use location-scoped eligibility and stable gameweek identity RPCs");
assert.ok(weatherPostponement.includes('stripeKey?.startsWith("sk_test_")'), "Weather postponement must remain test-mode only");
assert.ok(weatherPostponement.includes("36*60*60*1000"), "Replacement kickoff must preserve the 36-hour payment window");
assert.ok(weatherPostponement.includes("checkout/sessions/") && weatherPostponement.includes("payment_intents/"), "Weather postponement must reconcile Stripe checkout and completed payment state before changing fixtures");

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
assert.ok(refereePayout.includes("userClient!.auth.getUser()") && refereePayout.includes('req.headers.get("x-referee-payout-cron-secret")'), "Referee payout transfers must validate the signed-in administrator or protected cron worker");
assert.ok(refereePayout.includes('rpc("claim_referee_payout_transfer",'), "Referee payout transfers must be claimed through the location-scoped approval RPC");
assert.ok(refereePayout.includes("Idempotency-Key") && refereePayout.includes("openplay-referee-"), "Referee payout transfers must use attempt-scoped Stripe idempotency keys");
assert.ok(refereePayout.includes('stripeKey?.startsWith("sk_test_")'), "Referee payout transfers must remain test-mode only");
assert.ok(refereePayout.includes("if(!transferCreated&&canMarkFailed)"), "Ambiguous or already-created transfers must remain in reconciliation instead of becoming retryable");

const refereeConnectWebhook = readFileSync("supabase/functions/referee-connect-webhook/index.ts", "utf8");
assert.ok(refereeConnectWebhook.includes('req.headers.get("stripe-signature")') && refereeConnectWebhook.includes("verifyStripeSignature(rawBody,signature,secret)"), "Connect webhook must verify the raw-body Stripe signature");
assert.ok(refereeConnectWebhook.includes("event.livemode!==false"), "Connect webhook must reject live-mode events");
assert.ok(refereeConnectWebhook.includes("referee_connect_webhook_events") && refereeConnectWebhook.includes("processed_at"), "Connect webhook processing must be idempotent and retryable");



assert.ok(connectOnboarding.includes('controller[stripe_dashboard][type]","express"') && connectOnboarding.includes('controller[fees][payer]","application"') && connectOnboarding.includes('controller[losses][payments]","application"'), "New referee Connect accounts must use Stripe controller properties with platform fee and loss responsibility");
assert.ok(!connectOnboarding.includes('params.set("type","express")'), "New referee Connect accounts must not use deprecated legacy account-type creation");
assert.ok(connectOnboarding.includes('sessionParams.set("components[account_onboarding][enabled]","true")') && connectOnboarding.includes('stripeRequest("account_sessions","POST"'), "Referee onboarding must use a Stripe Account Session for embedded onboarding");
assert.ok(connectOnboarding.includes('sessionParams.set("components[account_onboarding][features][external_account_collection]","true")'), "Embedded referee onboarding must collect a bank account for payouts");
assert.ok(connectOnboarding.includes("account_session_client_secret") && !connectOnboarding.includes('stripeRequest("account_links"'), "Referee onboarding must return an embedded session secret, not a hosted Account Link");
assert.ok(connectOnboarding.includes('p_stripe_event_created_at:new Date((typeof account.created==="number"?account.created:Math.floor(Date.now()/1000))*1000).toISOString()'), "Initial Connect sync must use Stripe account creation time so later verification webhooks are not rejected as stale");
assert.ok(connectOnboarding.includes("if(transfersEnabled){") && !connectOnboarding.includes("if(transfersEnabled&&account.payouts_enabled)"), "Connected-balance transfer readiness must not be blocked by later bank-payout enablement");

const refereeWorkspace = readFileSync("src/routes/referee.tsx", "utf8");
assert.ok(refereeWorkspace.includes("https://connect-js.stripe.com/v1.0/connect.js") && refereeWorkspace.includes('instance.create("account-onboarding")'), "Referee workspace must mount Stripe's embedded account onboarding component");
assert.ok(refereeWorkspace.includes("VITE_STRIPE_PUBLISHABLE_KEY") && refereeWorkspace.includes('locale: "en-GB"'), "Embedded onboarding must use the configured publishable key and UK locale");
assert.ok(!refereeWorkspace.includes("window.location.assign(data.onboarding_url)"), "Referee onboarding must not redirect to Stripe-hosted onboarding");

const refereeConnectSql = readFileSync("supabase/drafts/referee_connect_payouts.sql", "utf8");
const reportClaim = refereeConnectSql.slice(refereeConnectSql.indexOf("create or replace function public.claim_referee_payout_transfer"), refereeConnectSql.indexOf("create or replace function public.record_referee_payout_transfer_success"));
assert.ok(reportClaim.includes("public.can_administer_location(v_location_id)"), "Match-report transfers must remain scoped to the approving administrator's location");
assert.ok(reportClaim.includes("not public.has_platform_role() or not public.has_finance_access()"), "Milestone transfers must remain restricted to global finance administrators");
assert.ok(refereeConnectSql.includes("onboarding_status<>'enabled' or (details_submitted and transfers_enabled)"), "Transfer readiness must not depend on bank-payout enablement");
assert.ok(reportClaim.includes("not v_account.transfers_enabled then") && !reportClaim.includes("not v_account.payouts_enabled"), "Match transfers must require the transfers capability, not bank-payout enablement");

const adminReferees = readFileSync("src/routes/admin/referees.tsx", "utf8");
const reportReview = adminReferees.slice(adminReferees.indexOf("async function reviewReport"), adminReferees.indexOf("async function decide("));
assert.ok(reportReview.includes('functions.invoke("pay-referee-payout"'), "Approving a referee match report must invoke the referee transfer workflow");
assert.ok(reportReview.includes("report_id:report.report_id"), "The approval trigger must identify the report, not trust a browser-supplied payout amount or destination");
assert.ok(adminReferees.includes("payout.transfers_enabled") && !adminReferees.includes("payout.transfers_enabled&&payout.payouts_enabled"), "Match-report transfer controls must not require bank-payout enablement");
assert.ok(adminReferees.includes("reward.transfers_enabled") && !adminReferees.includes("reward.transfers_enabled&&reward.payouts_enabled"), "Milestone transfer controls must not require bank-payout enablement");

const refereePayoutWorker = readFileSync("supabase/functions/process-referee-payout-queue/index.ts", "utf8");
assert.ok(refereePayoutWorker.includes('req.headers.get("x-referee-payout-cron-secret")'), "Referee payout queue worker must validate its dedicated cron secret");
assert.ok(refereePayoutWorker.includes('stripeKey?.startsWith("sk_test_")'), "Referee payout queue worker must remain test-mode only");
assert.ok(refereePayoutWorker.includes('rpc("claim_referee_payout_transfer_jobs"') && refereePayoutWorker.includes('rpc("release_referee_payout_transfer_job"'), "Referee payout worker must use leased outbox claims and safe release logic");

const refereePayoutOutbox = readFileSync("supabase/drafts/referee_payout_transfer_outbox.sql", "utf8");
assert.ok(refereePayoutOutbox.includes("after insert or update of status on public.referee_report_payouts"), "Referee payout creation must atomically enqueue its transfer job");
assert.ok(refereePayoutOutbox.includes("for update of job skip locked"), "Concurrent referee payout workers must claim jobs without duplicate leases");
assert.ok(refereePayoutOutbox.includes("first_attempt_at") && refereePayoutOutbox.includes("now()-interval '23 hours'"), "Ambiguous payout recovery must reuse the original attempt only within Stripe's idempotency retention window");
assert.ok(refereePayoutOutbox.includes("security invoker") && refereePayoutOutbox.includes("grant execute on function public.claim_referee_payout_transfer_jobs(integer) to service_role") && refereePayoutOutbox.includes("grant execute on function public.claim_referee_payout_transfer_worker(uuid,uuid,uuid) to service_role"), "Referee payout worker RPCs must use invoker security and service-role-only execution grants");
assert.ok(refereePayoutOutbox.includes("pg_cron") && refereePayoutOutbox.includes("pg_net") && refereePayoutOutbox.includes("referee_payout_cron_secret"), "Referee payout outbox must include a Vault-backed scheduled dispatcher");

console.log("Edge Function security configuration and Phase 1 workflow boundary assertions passed.");

const adminRoute = readFileSync("src/routes/admin.tsx", "utf8");
for (const rpc of [
  "get_admin_dashboard_contextual",
  "get_admin_team_sheets_contextual",
  "get_admin_player_register_contextual",
  "admin_get_transfer_requests_contextual",
]) {
  assert.ok(adminRoute.includes(`rpc("${rpc}"`), `Admin Dashboard must use the authorised contextual RPC: ${rpc}`);
}
for (const legacyRpc of [
  "get_admin_dashboard",
  "get_admin_team_sheets",
  "get_admin_player_register",
  "admin_get_transfer_requests",
]) {
  assert.ok(!new RegExp(`rpc\\(["']${legacyRpc}["']`).test(adminRoute), `Admin Dashboard must not call revoked legacy RPC: ${legacyRpc}`);
}
