import { useEffect, useState } from "react";
import { createFileRoute, Link } from "@tanstack/react-router";
import {
  isGlobalPrivacyControlEnabled,
  readBrowserAnalyticsConsent,
  writeBrowserAnalyticsConsent,
  subscribeToBrowserAnalyticsConsent,
  type AnalyticsConsent,
} from "../lib/analytics/consent";

export const Route = createFileRoute("/privacy-security")({
  component: PrivacySecurityPage,
});

function PrivacySecurityPage() {
  const [consent, setConsent] = useState<AnalyticsConsent>("unset");
  const [globalPrivacyControl, setGlobalPrivacyControl] = useState(false);
  const [message, setMessage] = useState("");

  useEffect(() => {
    const refresh = () => {
      const gpc = isGlobalPrivacyControlEnabled();
      setGlobalPrivacyControl(gpc);
      setConsent(readBrowserAnalyticsConsent(gpc));
    };
    refresh();
    return subscribeToBrowserAnalyticsConsent(refresh);
  }, []);

  function updatePreference(next: "granted" | "denied") {
    setMessage("");
    const result = writeBrowserAnalyticsConsent(next, globalPrivacyControl);
    setConsent(result.consent);
    setMessage(
      !result.persisted
        ? "Your browser could not save this preference. Optional analytics remain off."
        : result.consent === "granted"
          ? "Your optional analytics preference is saved on this device. Analytics only run when the deployment privacy settings have been verified."
          : "Optional analytics are turned off on this device.",
    );
  }

  const status = globalPrivacyControl
    ? "Blocked by Global Privacy Control"
    : consent === "granted"
      ? "Allowed on this device"
      : consent === "denied"
        ? "Declined on this device"
        : "No choice saved";

  return (
    <main className="notice-page">
      <section className="notice-panel auth-panel">
        <Link className="notice-brand" to="/">OPEN PLAY</Link>
        <p className="eyebrow eyebrow-dark">ACCOUNT SETTINGS</p>
        <h1>PRIVACY &amp; <em>SECURITY</em></h1>
        <p>Control optional product analytics stored in this browser. This preference is not required to use Open Play and does not change your player registration, team membership or account details.</p>
        <section className="account-security-section">
          <h2>Optional product analytics</h2>
          <p>Current preference: <strong>{status}</strong></p>
          <p>Open Play uses privacy-minimised, allow-listed product events to understand which features are useful. We do not send passwords, contact details, private messages or payment information. Analytics stay off unless you explicitly allow them and the deployment privacy settings have been verified.</p>
          {globalPrivacyControl ? (
            <p className="form-note" role="status">Your browser has Global Privacy Control enabled. Open Play will respect that signal and keep optional analytics off.</p>
          ) : (
            <div className="analytics-consent-actions">
              <button className="button" type="button" onClick={() => updatePreference("granted")}>ALLOW OPTIONAL ANALYTICS</button>
              <button className="auth-text-button" type="button" onClick={() => updatePreference("denied")}>TURN OFF OPTIONAL ANALYTICS</button>
            </div>
          )}
          {message && <p className="form-success" role="status">{message}</p>}
        </section>
        <Link className="auth-switch" to="/player">Back to Player Hub</Link>
        <Link className="auth-switch" to="/">Back to Open Play</Link>
      </section>
    </main>
  );
}
