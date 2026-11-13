import {
  buildOneSignalPayload,
  renderPushMessage,
  sanitisePushDevice,
} from "./push-policy.ts";

Deno.test("push content is generic and does not expose notification payload details", () => {
  const sensitive = renderPushMessage("player.guardian_consent.captain_review_required");
  if (sensitive.heading !== "Open Play account update" ||
      sensitive.body.includes("16") || sensitive.body.includes("Player reference")) {
    throw new Error("Sensitive account event details must not appear on a lock screen");
  }

  const message = renderPushMessage("team.membership_rejected");
  if (message.body.includes("team name") || message.body.includes("reason")) {
    throw new Error("Team rejection push must not disclose private reason details");
  }
});

Deno.test("push routes use safe deep links for supported event categories", () => {
  const expected = new Map([
    ["message.new", "/messages"],
    ["fixture.rescheduled", "/match-centre"],
    ["team.membership_approved", "/player"],
    ["referee.report_rejected", "/referee"],
    ["support.case_updated", "/messages"],
    ["unrecognised.event", "/notifications"],
  ]);
  for (const [eventType, path] of expected) {
    if (renderPushMessage(eventType).path !== path) {
      throw new Error(`Unexpected deep link for ${eventType}`);
    }
  }
});

Deno.test("OneSignal payload targets all of the user's devices with an idempotency key", () => {
  const message = renderPushMessage("fixture.rescheduled");
  const payload = buildOneSignalPayload(
    "11111111-1111-4111-8111-111111111111",
    "22222222-2222-4222-8222-222222222222",
    "33333333-3333-4333-8333-333333333333",
    message,
    "https://openplay.example",
  );
  if (payload.target_channel !== "push" ||
      payload.include_aliases.external_id[0] !== "22222222-2222-4222-8222-222222222222" ||
      payload.idempotency_key !== "33333333-3333-4333-8333-333333333333" ||
      payload.url !== "https://openplay.example/match-centre") {
    throw new Error("OneSignal push targeting or idempotency payload is invalid");
  }
  const serialised = JSON.stringify(payload);
  if (serialised.includes("email") || serialised.includes("phone") || serialised.includes("date_of_birth")) {
    throw new Error("OneSignal payload must not contain personal contact or DOB fields");
  }
});

Deno.test("OneSignal app origin must use HTTPS outside local development", () => {
  let denied = false;
  try {
    buildOneSignalPayload(
      "11111111-1111-4111-8111-111111111111",
      "22222222-2222-4222-8222-222222222222",
      "33333333-3333-4333-8333-333333333333",
      renderPushMessage("message.new"),
      "http://openplay.example",
    );
  } catch {
    denied = true;
  }
  if (!denied) throw new Error("Insecure push deep-link origin was accepted");
});

Deno.test("push origin rejects paths and query strings", () => {
  for (const origin of ["https://openplay.example/app", "https://openplay.example/?redirect=other"]) {
    let denied = false;
    try {
      buildOneSignalPayload(
        "11111111-1111-4111-8111-111111111111",
        "22222222-2222-4222-8222-222222222222",
        "33333333-3333-4333-8333-333333333333",
        renderPushMessage("message.new"),
        origin,
      );
    } catch {
      denied = true;
    }
    if (!denied) throw new Error("Non-origin APP_ORIGIN was accepted");
  }
});

Deno.test("device responses are reduced to safe display fields", () => {
  const device = sanitisePushDevice({
    id: "44444444-4444-4444-8444-444444444444",
    type: "Chrome",
    enabled: true,
    device_model: "Desktop",
    device_os: "Windows",
    created_at: "2026-11-13T10:00:00Z",
    last_active: "2026-11-13T11:00:00Z",
    identifier: "push-token-must-not-leak",
    email: "private@example.com",
  });
  if (!device || device.subscriptionId !== "44444444-4444-4444-8444-444444444444" ||
      device.deviceModel !== "Desktop" || "identifier" in device || "email" in device) {
    throw new Error("Push device sanitisation failed");
  }
  if (sanitisePushDevice({ id: "not-a-uuid", identifier: "secret" }) !== null) {
    throw new Error("Invalid subscription identifiers must be rejected");
  }
});
