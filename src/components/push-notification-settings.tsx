import { useCallback, useEffect, useState } from "react";
import { getSupabaseClient } from "../lib/supabase/client";
import { isOneSignalConfigured, loadOneSignal } from "../lib/onesignal/client";

type CategoryKey = "match_updates" | "team_updates" | "club_messages" | "competition_announcements" | "support_updates";
type Preferences = {
  email_enabled: boolean;
  sms_enabled: boolean;
  in_app_enabled: boolean;
  push_enabled: boolean;
  category_preferences: Partial<Record<CategoryKey, boolean>>;
};
type PushDevice = {
  subscriptionId: string;
  type: string;
  enabled: boolean;
  deviceModel: string | null;
  deviceOs: string | null;
  createdAt: string | null;
  lastActive: string | null;
};

const CATEGORY_LABELS: Array<{ key: CategoryKey; label: string; description: string }> = [
  { key: "match_updates", label: "Match & referee updates", description: "Fixture changes, reminders, results and referee report updates." },
  { key: "team_updates", label: "Team & membership updates", description: "Team applications, membership requests and transfers." },
  { key: "club_messages", label: "Club messages", description: "New private messages from your club or team." },
  { key: "competition_announcements", label: "Competition announcements", description: "League and competition-wide announcements." },
  { key: "support_updates", label: "Support updates", description: "Replies and changes to protected support requests." },
];

function formatDeviceDate(value: string | null) {
  if (!value) return "Not available";
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? "Not available" : date.toLocaleString("en-GB", { dateStyle: "medium", timeStyle: "short" });
}

export function PushNotificationSettings({ userId }: { userId: string | null }) {
  const [preferences, setPreferences] = useState<Preferences | null>(null);
  const [devices, setDevices] = useState<PushDevice[]>([]);
  const [currentSubscriptionId, setCurrentSubscriptionId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");

  const refresh = useCallback(async () => {
    if (!userId) return;
    const supabase = getSupabaseClient();
    const { data, error: preferenceError } = await supabase.rpc("get_my_notification_preferences");
    if (preferenceError) throw new Error("Unable to load notification preferences.");
    setPreferences(data as unknown as Preferences);

    if (isOneSignalConfigured()) {
      const { data: deviceData, error: deviceError } = await supabase.functions.invoke("manage-push-devices", {
        body: { action: "list" },
      });
      if (deviceError || !deviceData) throw new Error("Unable to load registered push devices.");
      setDevices(Array.isArray(deviceData.devices) ? deviceData.devices as PushDevice[] : []);
      if (typeof deviceData.pushEnabled === "boolean") {
        setPreferences((current) => current ? { ...current, push_enabled: deviceData.pushEnabled } : current);
      }
      if (deviceData.pushEnabled === true) {
        try {
          const sdk = await loadOneSignal();
          setCurrentSubscriptionId(sdk.User.PushSubscription.id ?? null);
        } catch {
          setCurrentSubscriptionId(null);
        }
      } else {
        // Do not initialise the optional SDK merely to display settings for an
        // account that has not opted into push.
        setCurrentSubscriptionId(window.OneSignal?.User.PushSubscription.id ?? null);
      }
    } else {
      setDevices([]);
      setCurrentSubscriptionId(null);
    }
  }, [userId]);

  useEffect(() => {
    let active = true;
    setLoading(true);
    setError("");
    void refresh().catch((cause) => {
      if (active) setError(cause instanceof Error ? cause.message : "Unable to load notification settings.");
    }).finally(() => {
      if (active) setLoading(false);
    });
    return () => { active = false; };
  }, [refresh]);

  async function updateChannel(key: "email_enabled" | "sms_enabled" | "in_app_enabled", checked: boolean) {
    if (!preferences) return;
    setBusy(true);
    setError("");
    setNotice("");
    const next = { ...preferences, [key]: checked };
    setPreferences(next);
    try {
      const { data, error: updateError } = await getSupabaseClient().rpc("update_my_notification_preferences", {
        p_email_enabled: next.email_enabled,
        p_sms_enabled: next.sms_enabled,
        p_in_app_enabled: next.in_app_enabled,
      });
      if (updateError) throw new Error("Unable to save notification preferences.");
      setPreferences(data as unknown as Preferences);
      setNotice("Notification preferences saved.");
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "Unable to save notification preferences.");
      await refresh().catch(() => undefined);
    } finally {
      setBusy(false);
    }
  }

  async function updateCategory(key: CategoryKey, checked: boolean) {
    if (!preferences) return;
    setBusy(true);
    setError("");
    setNotice("");
    const next = { ...preferences, category_preferences: { ...preferences.category_preferences, [key]: checked } };
    setPreferences(next);
    try {
      const { data, error: updateError } = await getSupabaseClient().rpc("update_my_notification_category_preferences", {
        p_category_preferences: { [key]: checked },
      });
      if (updateError) throw new Error("Unable to save notification category preferences.");
      setPreferences(data as unknown as Preferences);
      setNotice("Notification categories saved.");
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "Unable to save notification category preferences.");
      await refresh().catch(() => undefined);
    } finally {
      setBusy(false);
    }
  }

  async function enablePush() {
    if (!userId || !isOneSignalConfigured()) return;
    setBusy(true);
    setError("");
    setNotice("");
    try {
      const sdk = await loadOneSignal();
      await sdk.login(userId);
      const permission = await sdk.Notifications.requestPermission();
      if (permission === false || permission === "denied") {
        throw new Error("Browser notification permission was denied. Enable notifications in your browser's site settings and try again.");
      }
      await sdk.User.PushSubscription.optIn();
      let subscriptionReady = false;
      for (let attempt = 0; attempt < 8; attempt += 1) {
        if (sdk.User.PushSubscription.id && sdk.User.PushSubscription.optedIn) {
          subscriptionReady = true;
          break;
        }
        await new Promise((resolve) => setTimeout(resolve, 500));
      }
      if (!subscriptionReady) throw new Error("The browser has not finished registering this device. Please try again in a moment.");

      const { data, error: enableError } = await getSupabaseClient().functions.invoke("manage-push-devices", {
        body: { action: "enable" },
      });
      if (enableError || !data || data.error) throw new Error(data?.error ?? "Unable to enable push notifications.");
      setNotice("Push notifications are enabled for this account.");
      await refresh();
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "Unable to enable push notifications.");
    } finally {
      setBusy(false);
    }
  }

  async function disablePush() {
    if (!userId || !isOneSignalConfigured()) return;
    setBusy(true);
    setError("");
    setNotice("");
    try {
      const sdk = await loadOneSignal().catch(() => null);
      if (sdk) await sdk.User.PushSubscription.optOut().catch(() => undefined);
      const { data, error: disableError } = await getSupabaseClient().functions.invoke("manage-push-devices", {
        body: { action: "disable" },
      });
      if (disableError || !data || data.error) throw new Error(data?.error ?? "Unable to disable push notifications.");
      if (sdk) await sdk.logout().catch(() => undefined);
      setNotice("Push notifications have been disabled on all registered devices.");
      await refresh();
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "Unable to disable push notifications.");
    } finally {
      setBusy(false);
    }
  }

  async function revokeDevice(device: PushDevice) {
    if (!userId) return;
    setBusy(true);
    setError("");
    setNotice("");
    try {
      if (device.subscriptionId === currentSubscriptionId) {
        const sdk = await loadOneSignal().catch(() => null);
        if (sdk) await sdk.User.PushSubscription.optOut().catch(() => undefined);
      }
      const { data, error: revokeError } = await getSupabaseClient().functions.invoke("manage-push-devices", {
        body: { action: "revoke", subscriptionId: device.subscriptionId },
      });
      if (revokeError || !data || data.error) throw new Error(data?.error ?? "Unable to remove this device.");
      if (data.pushEnabled === false) {
        const sdk = await loadOneSignal().catch(() => null);
        if (sdk) await sdk.logout().catch(() => undefined);
      }
      setNotice("Push notifications were removed from that device.");
      await refresh();
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "Unable to remove this device.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <section className="account-security-section push-notification-settings" aria-labelledby="notification-settings-heading">
      <div className="push-notification-settings-heading">
        <p className="eyebrow">NOTIFICATIONS</p>
        <h2 id="notification-settings-heading">Notification preferences</h2>
        <p>Choose how Open Play contacts you. Critical account-security alerts remain enabled.</p>
      </div>
      {loading ? <p role="status">Loading notification preferences…</p> : error && !preferences ? <p className="form-error" role="alert">{error}</p> : preferences ? <>
        <div className="push-push-settings-toggle-list">
          <label className="push-settings-toggle"><span><strong>In-app notifications</strong><small>Updates in your Open Play notification centre.</small></span><input type="checkbox" checked={preferences.in_app_enabled} disabled={busy} onChange={(event) => void updateChannel("in_app_enabled", event.target.checked)} /></label>
          <label className="push-settings-toggle"><span><strong>Email notifications</strong><small>Updates sent to your registered email address.</small></span><input type="checkbox" checked={preferences.email_enabled} disabled={busy} onChange={(event) => void updateChannel("email_enabled", event.target.checked)} /></label>
          <label className="push-settings-toggle"><span><strong>SMS notifications</strong><small>Text messages to your verified mobile number, where available.</small></span><input type="checkbox" checked={preferences.sms_enabled} disabled={busy} onChange={(event) => void updateChannel("sms_enabled", event.target.checked)} /></label>
        </div>
        <div className="push-settings-subsection">
          <h3>Notification categories</h3>
          <p>These choices apply to match, team, club, competition and support updates. Critical account-security messages cannot be switched off.</p>
          <div className="push-push-settings-toggle-list">
            {CATEGORY_LABELS.map((category) => <label className="push-settings-toggle" key={category.key}><span><strong>{category.label}</strong><small>{category.description}</small></span><input type="checkbox" checked={preferences.category_preferences?.[category.key] !== false} disabled={busy} onChange={(event) => void updateCategory(category.key, event.target.checked)} /></label>)}
          </div>
        </div>
        <div className="push-settings-subsection">
          <h3>Push notifications &amp; devices</h3>
          {!isOneSignalConfigured() ? <p className="form-note">Push notifications are not yet configured for this Open Play environment. Email, SMS and in-app preferences remain available.</p> : <>
            <p>Push is optional. Enable it on each browser you use. Open Play can send to multiple registered devices linked to this account.</p>
            <div className="push-settings-action-row">
              {preferences.push_enabled
                ? <button type="button" className="button button-secondary" disabled={busy} onClick={() => void disablePush()}>DISABLE PUSH ON ALL DEVICES</button>
                : <button type="button" className="button" disabled={busy} onClick={() => void enablePush()}>ENABLE PUSH ON THIS DEVICE</button>}
            </div>
            {devices.length > 0 ? <div className="push-device-list">{devices.map((device) => <article className="push-device" key={device.subscriptionId}>
              <div><strong>{device.deviceModel || device.type || "Web browser"}{device.subscriptionId === currentSubscriptionId ? " · This device" : ""}</strong><p>{device.deviceOs || "Web push"} · {device.enabled ? "Enabled" : "Browser permission off"} · Last active {formatDeviceDate(device.lastActive)}</p></div>
              <button type="button" className="auth-text-button" disabled={busy} onClick={() => void revokeDevice(device)}>REMOVE</button>
            </article>)}</div> : <p className="form-note">No push-enabled devices are currently registered.</p>}
          </>}
        </div>
        {error && <p className="form-error" role="alert">{error}</p>}
        {notice && <p className="form-note" role="status">{notice}</p>}
      </> : null}
    </section>
  );
}
