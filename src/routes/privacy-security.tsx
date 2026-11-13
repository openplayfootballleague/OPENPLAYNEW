import { useEffect, useState } from "react";
import { getSupabaseClient } from "../lib/supabase/client";
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

type NotificationCategoryPreferences = {
  team_updates_enabled: boolean;
  fixture_updates_enabled: boolean;
  result_updates_enabled: boolean;
  messages_enabled: boolean;
  referee_updates_enabled: boolean;
};
type NotificationCategoryKey = keyof NotificationCategoryPreferences;

const notificationCategoryLabels: Array<{ key: NotificationCategoryKey; label: string; description: string }> = [
  { key: "team_updates_enabled", label: "Team and membership updates", description: "Team approvals, membership changes and transfer decisions." },
  { key: "fixture_updates_enabled", label: "Fixture updates and reminders", description: "Scheduled fixtures, changes and match reminders." },
  { key: "result_updates_enabled", label: "Published results", description: "New and corrected match results." },
  { key: "messages_enabled", label: "New messages", description: "Email and in-app alerts when someone messages you." },
  { key: "referee_updates_enabled", label: "Referee updates", description: "Match report decisions and referee workflow updates." },
];

function PrivacySecurityPage() {
  const [consent, setConsent] = useState<AnalyticsConsent>("unset");
  const [globalPrivacyControl, setGlobalPrivacyControl] = useState(false);
  const [message, setMessage] = useState("");
  const [signedIn, setSignedIn] = useState(false);
  const [sessionsBusy, setSessionsBusy] = useState(false);
  const [sessionsMessage, setSessionsMessage] = useState("");
  const [sessionsError, setSessionsError] = useState("");
  const [notificationCategories, setNotificationCategories] = useState<NotificationCategoryPreferences | null>(null);
  const [notificationCategoriesLoading, setNotificationCategoriesLoading] = useState(false);
  const [notificationCategoriesSaving, setNotificationCategoriesSaving] = useState(false);
  const [notificationCategoriesError, setNotificationCategoriesError] = useState("");
  const [notificationCategoriesMessage, setNotificationCategoriesMessage] = useState("");

  useEffect(() => {
    const supabase = getSupabaseClient();
    let alive = true;
    void supabase.auth.getSession().then(({ data }) => {
      if (alive) setSignedIn(Boolean(data.session));
    }).catch(() => {
      if (alive) setSignedIn(false);
    });
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      if (alive) setSignedIn(Boolean(session));
    });
    return () => {
      alive = false;
      subscription.unsubscribe();
    };
  }, []);

  useEffect(() => {
    let alive = true;
    if (!signedIn) {
      setNotificationCategories(null);
      setNotificationCategoriesError("");
      return () => { alive = false; };
    }
    setNotificationCategoriesLoading(true);
    void getSupabaseClient().rpc("get_my_notification_preferences").then(({ data, error }) => {
      if (!alive) return;
      if (error) {
        setNotificationCategoriesError("Notification preferences are temporarily unavailable. Please try again.");
      } else if (data) {
        setNotificationCategories(data as NotificationCategoryPreferences);
      }
      setNotificationCategoriesLoading(false);
    }).catch(() => {
      if (!alive) return;
      setNotificationCategoriesError("Notification preferences are temporarily unavailable. Please try again.");
      setNotificationCategoriesLoading(false);
    });
    return () => { alive = false; };
  }, [signedIn]);

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

  async function signOutOtherDevices() {
    if (!signedIn || sessionsBusy) return;
    if (!window.confirm("Sign out of all other Open Play sessions? This session will remain signed in.")) return;
    setSessionsBusy(true);
    setSessionsMessage("");
    setSessionsError("");
    try {
      const { error } = await getSupabaseClient().auth.signOut({ scope: "others" });
      if (error) throw error;
      setSessionsMessage("Other active sessions have been signed out. This session remains signed in.");
    } catch (cause) {
      setSessionsError(cause instanceof Error ? cause.message : "Unable to sign out other sessions. Please try again.");
    } finally {
      setSessionsBusy(false);
    }
  }

  function changeNotificationCategory(key: NotificationCategoryKey, enabled: boolean) {
    setNotificationCategoriesMessage("");
    setNotificationCategoriesError("");
    setNotificationCategories((current) => current ? { ...current, [key]: enabled } : current);
  }

  async function saveNotificationCategories() {
    if (!notificationCategories || notificationCategoriesSaving) return;
    setNotificationCategoriesSaving(true);
    setNotificationCategoriesMessage("");
    setNotificationCategoriesError("");
    try {
      const { data, error } = await getSupabaseClient().rpc("update_my_notification_category_preferences", {
        p_team_updates_enabled: notificationCategories.team_updates_enabled,
        p_fixture_updates_enabled: notificationCategories.fixture_updates_enabled,
        p_result_updates_enabled: notificationCategories.result_updates_enabled,
        p_messages_enabled: notificationCategories.messages_enabled,
        p_referee_updates_enabled: notificationCategories.referee_updates_enabled,
      });
      if (error) throw error;
      if (data) setNotificationCategories(data as NotificationCategoryPreferences);
      setNotificationCategoriesMessage("Your notification category preferences have been saved.");
    } catch {
      setNotificationCategoriesError("We couldn't save your notification preferences. Please try again.");
    } finally {
      setNotificationCategoriesSaving(false);
    }
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
        <section className="account-security-section">
          <h2>Active sessions</h2>
          <p>Sign out of other sessions if you no longer recognise one. This does not sign out the session you are using now. A per-device session list and individual revocation controls are not yet available.</p>
          {signedIn ? (
            <button className="auth-text-button" type="button" onClick={() => void signOutOtherDevices()} disabled={sessionsBusy}>
              {sessionsBusy ? "SIGNING OUT OTHER DEVICES…" : "SIGN OUT OTHER SESSIONS"}
            </button>
          ) : (
            <Link className="auth-switch" to="/sign-in">Sign in to manage active sessions</Link>
          )}
          {sessionsMessage && <p className="form-success" role="status">{sessionsMessage}</p>}
          {sessionsError && <p className="form-error" role="alert">{sessionsError}</p>}
        </section>
        <section className="account-security-section">
          <h2>Notification categories</h2>
          <p>Choose which optional Open Play updates you receive. These settings apply across available notification channels. Essential account, security, safeguarding and eligibility notices remain enabled.</p>
          {!signedIn ? (
            <Link className="auth-switch" to="/sign-in">Sign in to manage notification preferences</Link>
          ) : notificationCategoriesLoading ? (
            <p className="form-note" role="status">Loading notification preferences…</p>
          ) : notificationCategories ? (
            <>
              <div className="notification-category-preferences">
                {notificationCategoryLabels.map(({ key, label, description }) => (
                  <label className="notification-category-option" key={key}>
                    <span>
                      <strong>{label}</strong>
                      <small>{description}</small>
                    </span>
                    <input
                      type="checkbox"
                      checked={notificationCategories[key]}
                      disabled={notificationCategoriesSaving}
                      onChange={(event) => changeNotificationCategory(key, event.target.checked)}
                    />
                  </label>
                ))}
              </div>
              <button className="button" type="button" onClick={() => void saveNotificationCategories()} disabled={notificationCategoriesSaving}>
                {notificationCategoriesSaving ? "SAVING PREFERENCES…" : "SAVE NOTIFICATION PREFERENCES"}
              </button>
            </>
          ) : null}
          {notificationCategoriesError && <p className="form-error" role="alert">{notificationCategoriesError}</p>}
          {notificationCategoriesMessage && <p className="form-success" role="status">{notificationCategoriesMessage}</p>}
        </section>
        <Link className="auth-switch" to="/player">Back to Player Hub</Link>
        <Link className="auth-switch" to="/">Back to Open Play</Link>
      </section>
    </main>
  );
}
