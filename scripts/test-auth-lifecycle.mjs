import { createClient } from "@supabase/supabase-js";
import { randomUUID } from "node:crypto";

const supabaseUrl = process.env.SUPABASE_URL;
const anonKey = process.env.SUPABASE_ANON_KEY;
const mailpitUrl = process.env.MAILPIT_URL ?? "http://127.0.0.1:54324";
if (!supabaseUrl || !anonKey) throw new Error("SUPABASE_URL and SUPABASE_ANON_KEY are required");

const supabase = createClient(supabaseUrl, anonKey, {
  auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
});
const email = `openplay-ci-${randomUUID()}@example.com`;
const initialPassword = `OpenPlay-CI-${randomUUID()}-A1!`;
const replacementPassword = `OpenPlay-CI-${randomUUID()}-B2!`;
const mailbox = email.split("@")[0];

async function requestJson(url, init) {
  const response = await fetch(url, init);
  const body = await response.text();
  if (!response.ok) throw new Error(`HTTP ${response.status} from ${url}: ${body.slice(0, 500)}`);
  return body ? JSON.parse(body) : null;
}

async function waitForEmail(predicate, description) {
  const deadline = Date.now() + 25_000;
  let lastMessages = [];
  while (Date.now() < deadline) {
    const result = await requestJson(`${mailpitUrl}/api/v1/search?query=${encodeURIComponent(`to:${email}`)}`);
    lastMessages = result?.messages ?? [];
    const match = lastMessages.find(predicate);
    if (match) return await requestJson(`${mailpitUrl}/api/v1/message/${encodeURIComponent(match.ID)}`);
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
  throw new Error(`Timed out waiting for ${description}; received ${lastMessages.length} message(s)`);
}

function extractTokenHash(message) {
  const source = [message.Text, message.HTML, message.text, message.html, message.body, message].map((value) =>
    typeof value === "string" ? value : JSON.stringify(value),
  ).join("\n").replaceAll("&amp;", "&").replaceAll("&#x3D;", "=");
  const match = source.match(/[?&]token=([^&"'<>\s]+)/i) ?? source.match(/[?&]token_hash=([^&"'<>\s]+)/i);
  if (!match) throw new Error("Verification email did not contain a token URL");
  return decodeURIComponent(match[1]);
}

const { data: signUpData, error: signUpError } = await supabase.auth.signUp({
  email,
  password: initialPassword,
  options: { emailRedirectTo: "http://127.0.0.1:3000/register-player" },
});
if (signUpError) throw signUpError;
if (!signUpData.user?.id) throw new Error("Signup did not create an Auth user");
if (signUpData.session) throw new Error("Signup returned a session before email verification");

const confirmationEmail = await waitForEmail(
  (message) => String(message.Subject ?? "").toLowerCase().includes("confirm") || String(message.Subject ?? "").toLowerCase().includes("verify"),
  "signup confirmation email",
);
const confirmationToken = extractTokenHash(confirmationEmail);
const { data: verifiedData, error: verifyError } = await supabase.auth.verifyOtp({
  token_hash: confirmationToken,
  type: "signup",
});
if (verifyError) throw verifyError;
if (!verifiedData.user?.email_confirmed_at) throw new Error("Email verification did not confirm the Auth user");

const { data: signedInData, error: signInError } = await supabase.auth.signInWithPassword({
  email,
  password: initialPassword,
});
if (signInError) throw signInError;
if (!signedInData.session) throw new Error("Verified account could not sign in");

const { data: playerRows, error: playerReadError } = await supabase
  .from("players").select("id").eq("user_id", signedInData.user.id);
if (playerReadError) throw playerReadError;
if ((playerRows ?? []).length !== 0) throw new Error("Account creation unexpectedly created a player record");

const { data: roleRows, error: roleReadError } = await supabase
  .from("user_roles").select("role").eq("user_id", signedInData.user.id);
if (roleReadError) throw roleReadError;
if ((roleRows ?? []).length !== 0) throw new Error("Account creation unexpectedly assigned a privileged role");

const registrationPhone = `+4477009${randomUUID().replaceAll("-", "").slice(0, 5)}`;
const { data: registrationData, error: registrationError } = await supabase.rpc("register_player", {
  p_full_name: `Open Play CI ${randomUUID().slice(0, 8)}`,
  p_phone: registrationPhone,
  p_email: email,
  p_date_of_birth: "1994-05-17",
});
if (registrationError) throw registrationError;
const registration = Array.isArray(registrationData) ? registrationData[0] : registrationData;
if (!registration || registration.registration_status !== "registered") {
  throw new Error("Verified Auth user could not complete the separate player-registration step");
}
const { data: registeredPlayers, error: registeredPlayerReadError } = await supabase
  .from("players").select("id,registration_status").eq("user_id", signedInData.user.id);
if (registeredPlayerReadError) throw registeredPlayerReadError;
if (registeredPlayers?.length !== 1 || registeredPlayers[0].registration_status !== "registered") {
  throw new Error("Player registration did not persist exactly one approved player record");
}
const { error: duplicateRegistrationError } = await supabase.rpc("register_player", {
  p_full_name: "Duplicate CI Registration",
  p_phone: registrationPhone,
  p_email: email,
  p_date_of_birth: "1994-05-17",
});
if (!duplicateRegistrationError) throw new Error("A second player registration for the same Auth user unexpectedly succeeded");

const { error: resetError } = await supabase.auth.resetPasswordForEmail(email, {
  redirectTo: "http://127.0.0.1:3000/reset-password",
});
if (resetError) throw resetError;
const recoveryEmail = await waitForEmail(
  (message) => String(message.Subject ?? "").toLowerCase().includes("password") || String(message.Subject ?? "").toLowerCase().includes("reset"),
  "password recovery email",
);
const recoveryToken = extractTokenHash(recoveryEmail);
const { error: recoveryVerifyError } = await supabase.auth.verifyOtp({
  token_hash: recoveryToken,
  type: "recovery",
});
if (recoveryVerifyError) throw recoveryVerifyError;

const { error: updateError } = await supabase.auth.updateUser({ password: replacementPassword });
if (updateError) throw updateError;
const { data: replacementSignIn, error: replacementSignInError } = await supabase.auth.signInWithPassword({
  email,
  password: replacementPassword,
});
if (replacementSignInError) throw replacementSignInError;
if (!replacementSignIn.session) throw new Error("Updated password did not authenticate");

const { error: signOutError } = await supabase.auth.signOut();
if (signOutError) throw signOutError;

console.log("Auth lifecycle integration passed: signup, confirmation email, verified sign-in, account/player separation, player registration, one-registration-per-account, password recovery, password update and sign-out.");
