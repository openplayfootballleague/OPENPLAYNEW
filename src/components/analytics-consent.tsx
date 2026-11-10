import { useEffect, useState } from "react";
import {
  getAnalyticsConsent,
  setAnalyticsConsent,
} from "../lib/analytics/posthog";

export function AnalyticsConsentBanner() {
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    setVisible(getAnalyticsConsent() === null);
  }, []);

  if (!visible) return null;

  function choose(allowed: boolean) {
    setAnalyticsConsent(allowed);
    setVisible(false);
  }

  return (
    <aside className="analytics-consent-banner" aria-label="Analytics preferences">
      <div className="analytics-consent-copy">
        <strong>Help improve Open Play</strong>
        <p>Optional, privacy-conscious analytics help us understand which parts of the service are useful. We do not use session replay or automatic interaction tracking.</p>
      </div>
      <div className="analytics-consent-actions">
        <button type="button" className="analytics-consent-accept" onClick={() => choose(true)}>ALLOW ANALYTICS</button>
        <button type="button" className="analytics-consent-reject" onClick={() => choose(false)}>NO THANKS</button>
      </div>
    </aside>
  );
}

export function AnalyticsConsentSettings() {
  const [choice, setChoice] = useState<"granted" | "denied" | null>(null);

  useEffect(() => {
    setChoice(getAnalyticsConsent());
  }, []);

  function choose(allowed: boolean) {
    setAnalyticsConsent(allowed);
    setChoice(allowed ? "granted" : "denied");
  }

  return (
    <section className="analytics-consent-settings" aria-labelledby="analytics-consent-heading">
      <div>
        <p className="hub-kicker">PRIVACY</p>
        <h2 id="analytics-consent-heading">Analytics preferences</h2>
        <p>
          {choice === "granted"
            ? "Optional analytics are enabled. You can withdraw consent at any time."
            : choice === "denied"
              ? "Optional analytics are disabled. You can change your choice at any time."
              : "No choice has been saved. Optional analytics remain off until you opt in."}
        </p>
      </div>
      <div className="analytics-consent-actions">
        <button type="button" className="analytics-consent-accept" onClick={() => choose(true)}>ALLOW ANALYTICS</button>
        <button type="button" className="analytics-consent-reject" onClick={() => choose(false)}>DISABLE ANALYTICS</button>
      </div>
    </section>
  );
}
