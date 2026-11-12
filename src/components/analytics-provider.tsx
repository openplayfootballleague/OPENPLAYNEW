import { createContext, useCallback, useContext, useEffect, useState } from "react";
import type { ReactNode } from "react";
import { PostHogProvider, usePostHog } from "@posthog/react";
import posthog from "posthog-js";
import { useLocation } from "@tanstack/react-router";
import {
  isGlobalPrivacyControlEnabled,
  readBrowserAnalyticsConsent,
  writeBrowserAnalyticsConsent,
  shouldMountPostHog,
  subscribeToBrowserAnalyticsConsent,
} from "../lib/analytics/consent";
import {
  captureOpenPlayEvent,
  type AnalyticsActor,
  type AnalyticsCaptureClient,
  type AnalyticsProperties,
  type OpenPlayAnalyticsEvent,
} from "../lib/analytics/events";
import { getSupabaseClient, isSupabaseConfigured } from "../lib/supabase/client";
import { resolveAnalyticsActorSafely } from "../lib/analytics/actor";

const POSTHOG_OPTIONS = {
  defaults: "2026-08-30",
  autocapture: false,
  rageclick: false,
  capture_dead_clicks: false,
  capture_pageview: false,
  capture_pageleave: false,
  capture_exceptions: false,
  capture_heatmaps: false,
  capture_performance: false,
  disable_session_recording: true,
  opt_out_capturing_by_default: true,
  advanced_disable_flags: true,
  disable_surveys: true,
  disable_product_tours: true,
  disable_conversations: true,
  logs: { captureConsoleLogs: false },
  // Flush the single synthetic probe immediately in browser acceptance tests;
  // production keeps the SDK defaults and never enables the probe.
  ...(import.meta.env.VITE_OPENPLAY_ANALYTICS_E2E === "true"
    ? {
        request_batching: false,
        api_transport: "XHR" as const,
        // Playwright headless Chromium is classified as a bot by the SDK.
        // Allow only this synthetic test environment to exercise event delivery.
        opt_out_useragent_filter: true,
      }
    : {}),
} as const;

type AnalyticsCapture = (
  event: OpenPlayAnalyticsEvent,
  properties?: AnalyticsProperties,
) => boolean;

const noOpCapture: AnalyticsCapture = () => false;
const AnalyticsCaptureContext = createContext<AnalyticsCapture>(noOpCapture);

export function useOpenPlayAnalytics() {
  return useContext(AnalyticsCaptureContext);
}

function routeCategory(pathname: string): string {
  if (pathname === "/") return "home";
  if (pathname.startsWith("/player") || pathname.startsWith("/player-hub")) return "player_hub";
  if (pathname.startsWith("/fixtures") || pathname.startsWith("/results") || pathname.startsWith("/match-centre")) return "match_centre";
  if (pathname.startsWith("/team")) return "teams";
  if (pathname.startsWith("/register") || pathname.startsWith("/registration") || pathname.startsWith("/onboarding")) return "registration";
  if (pathname.startsWith("/notification")) return "notifications";
  if (pathname.startsWith("/referee")) return "referee";
  if (pathname.startsWith("/gallery")) return "gallery";
  if (pathname.startsWith("/account") || pathname.startsWith("/profile") || pathname.startsWith("/settings") || pathname.startsWith("/privacy")) return "account";
  return "other";
}

function routeFeature(category: string): string | null {
  const features: Record<string, string> = {
    home: "player_hub",
    player_hub: "player_hub",
    match_centre: "match_centre",
    teams: "team_directory",
    registration: "player_registration",
    notifications: "notifications",
    gallery: "gallery",
    account: "profile",
    referee: "referee_workspace",
  };
  return features[category] ?? null;
}

function PostHogCaptureProvider({ children }: { children: ReactNode }) {
  const posthog = usePostHog();
  const location = useLocation();
  const [actor, setActor] = useState<AnalyticsActor>("unknown");
  const [userId, setUserId] = useState<string | null>(null);

  useEffect(() => {
    let alive = true;

    // Analytics must remain inert when account services are not configured.
    // Do not let an optional PostHog setup crash the app in that environment.
    if (!isSupabaseConfigured()) {
      setActor("unknown");
      return;
    }

    let supabase: ReturnType<typeof getSupabaseClient>;
    try {
      supabase = getSupabaseClient();
    } catch {
      setActor("unknown");
      return;
    }

    let identitySequence = 0;

    async function resolveIdentity(): Promise<{ actor: AnalyticsActor; userId: string | null }> {
      let resolvedUserId: string | null = null;
      const actor = await resolveAnalyticsActorSafely(true, async () => {
        const { data: { session }, error: sessionError } = await supabase.auth.getSession();
        if (sessionError) return "unknown";
        if (!session) return "anonymous";

        const { data: profile, error: profileError } = await supabase
          .from("profiles")
          .select("account_retention_status")
          .eq("id", session.user.id)
          .maybeSingle();
        if (profileError || !profile || profile.account_retention_status !== "active") return "unknown";

        const { data: roles, error: rolesError } = await supabase
          .from("user_roles")
          .select("role")
          .eq("user_id", session.user.id);
        if (rolesError) return "unknown";

        const privilegedRole = (roles ?? []).map(({ role }) => role).find((role) =>
          ["super_admin", "admin", "finance_admin", "league_admin"].includes(role),
        );
        if (privilegedRole) return privilegedRole as AnalyticsActor;

        const { data: player, error: playerError } = await supabase
          .from("players")
          .select("registration_status,is_banned,disciplinary_inactive")
          .eq("user_id", session.user.id)
          .maybeSingle();
        if (playerError || player?.is_banned || player?.disciplinary_inactive) return "unknown";

        if (player?.registration_status !== "registered") {
          resolvedUserId = session.user.id;
          return "account_user";
        }

        const { data: captainMemberships, error: captainError } = await supabase
          .from("team_memberships")
          .select("id")
          .eq("user_id", session.user.id)
          .eq("status", "active")
          .eq("is_captain", true)
          .limit(1);
        if (captainError) return "unknown";

        resolvedUserId = session.user.id;
        return (captainMemberships ?? []).length > 0 ? "captain" : "player";
      });

      const identifiable = actor === "account_user" || actor === "player" || actor === "captain";
      return { actor, userId: identifiable ? resolvedUserId : null };
    }

    const applyResolvedActor = () => {
      const sequence = ++identitySequence;
      void resolveIdentity()
        .then(({ actor: resolvedActor, userId: resolvedUserId }) => {
          if (alive && sequence === identitySequence) {
            setUserId(resolvedUserId);
            setActor(resolvedActor);
          }
        })
        .catch(() => {
          if (alive && sequence === identitySequence) {
            setUserId(null);
            setActor("unknown");
          }
        });
    };

    applyResolvedActor();

    const { data: { subscription } } = supabase.auth.onAuthStateChange((event) => {
      if (!["INITIAL_SESSION", "SIGNED_IN", "SIGNED_OUT", "USER_UPDATED"].includes(event)) return;
      setUserId(null);
      setActor("unknown");
      applyResolvedActor();
    });
    const handleForeground = () => {
      if (document.visibilityState === "visible") applyResolvedActor();
    };
    document.addEventListener("visibilitychange", handleForeground);

    return () => {
      alive = false;
      subscription.unsubscribe();
      document.removeEventListener("visibilitychange", handleForeground);
    };
  }, []);

  useEffect(() => {
    if (!posthog.__loaded) return;
    if (userId && (actor === "account_user" || actor === "player" || actor === "captain")) {
      // Use only the stable Supabase UUID. Never send email, name, phone or DOB.
      posthog.identify(userId);
      return;
    }
    // Clear a prior identity when an account switches, is signed out, becomes
    // privileged, or cannot be verified. Anonymous visitors retain no shared ID.
    posthog.reset();
  }, [actor, posthog, userId]);

  const capture = useCallback<AnalyticsCapture>((event, properties) => {
    const client: AnalyticsCaptureClient = {
      capture: (capturedEvent, safeProperties) => posthog.capture(capturedEvent, safeProperties),
    };
    return captureOpenPlayEvent(
      client,
      readBrowserAnalyticsConsent(),
      isGlobalPrivacyControlEnabled(),
      actor === "unknown" && location.pathname === "/sign-up" && event.startsWith("account_signup_")
        ? "anonymous"
        : actor,
      event,
      properties,
    );
  }, [actor, location.pathname, posthog]);

  useEffect(() => {
    if (actor === "unknown") return;
    const category = routeCategory(location.pathname);
    capture("navigation_section_viewed", {
      route_category: category,
      feature: routeFeature(category),
    });
  }, [actor, capture, location.pathname]);

  return (
    <AnalyticsCaptureContext.Provider value={capture}>
      {children}
    </AnalyticsCaptureContext.Provider>
  );
}

export function AnalyticsConsentBanner({ enabled }: { enabled: boolean }) {
  const [visible, setVisible] = useState(false);
  const [message, setMessage] = useState("");

  useEffect(() => {
    const refresh = () => {
      const gpc = isGlobalPrivacyControlEnabled();
      const consent = readBrowserAnalyticsConsent(gpc);
      setVisible(enabled && !gpc && consent === "unset");
    };
    refresh();
    return subscribeToBrowserAnalyticsConsent(refresh);
  }, [enabled]);

  function choose(consent: "granted" | "denied") {
    const result = writeBrowserAnalyticsConsent(consent);
    if (result.persisted) {
      setVisible(false);
      setMessage("");
    } else {
      setVisible(true);
      setMessage("Your browser could not save this choice. Optional analytics remain off.");
    }
  }

  if (!visible) return null;

  return (
    <aside className="analytics-consent-banner" aria-label="Optional analytics preferences">
      <div className="analytics-consent-copy">
        <strong>Help improve Open Play?</strong>
        <p>Allow optional, privacy-minimised product analytics. This is not required to use the app. We do not send passwords, contact details, private messages or payment information.</p>
        {message && <p className="form-error" role="alert">{message}</p>}
      </div>
      <div className="analytics-consent-actions">
        <button type="button" className="button" onClick={() => choose("granted")}>ALLOW OPTIONAL ANALYTICS</button>
        <button type="button" className="auth-text-button" onClick={() => choose("denied")}>NO THANKS</button>
      </div>
    </aside>
  );
}

function AnalyticsE2EDiagnostics({
  configured,
  allowed,
  sdkReady,
  tokenConfigured,
  host,
  error,
}: {
  configured: boolean;
  allowed: boolean;
  sdkReady: boolean;
  tokenConfigured: boolean;
  host: string | undefined;
  error: string | null;
}) {
  const [captureCalled, setCaptureCalled] = useState(false);
  const [captureResult, setCaptureResult] = useState("not-called");
  if (import.meta.env.VITE_OPENPLAY_ANALYTICS_E2E !== "true") return null;

  return (
    <div
      data-testid="analytics-e2e-diagnostics"
      data-posthog-configured={String(configured)}
      data-consent-allowed={String(allowed)}
      data-sdk-ready={String(sdkReady)}
      data-posthog-loaded={String(posthog.__loaded)}
      data-posthog-capturing={String(allowed && sdkReady)}
      data-posthog-opted-in={String(allowed && sdkReady)}
      data-posthog-token={tokenConfigured ? "present" : "missing"}
      data-posthog-host={host ?? "missing"}
      data-posthog-error={error ?? ""}
      data-posthog-capture-called={String(captureCalled)}
      data-posthog-capture-result={captureResult}
    >
      <button
        type="button"
        data-testid="analytics-e2e-probe"
        onClick={() => {
          setCaptureCalled(true);
          const result = posthog.capture(
            "openplay_e2e_consent_probe",
            { test_mode: true },
            { send_instantly: true, transport: "XHR" },
          );
          setCaptureResult(String(result ?? "undefined"));
        }}
      >
        Send analytics test probe
      </button>
    </div>
  );
}

export function ConsentAwareAnalytics({ children }: { children: ReactNode }) {
  const [allowed, setAllowed] = useState(false);
  const [sdkReady, setSdkReady] = useState(false);
  const [sdkError, setSdkError] = useState<string | null>(null);
  const projectToken = import.meta.env.VITE_POSTHOG_PROJECT_TOKEN?.trim();
  const projectHost = import.meta.env.VITE_POSTHOG_HOST?.trim();
  const privacySettingsVerified = import.meta.env.VITE_POSTHOG_PRIVACY_SETTINGS_VERIFIED === "true";
  const configured = Boolean(projectToken && projectHost && privacySettingsVerified);

  useEffect(() => {
    const refresh = () => {
      setAllowed(shouldMountPostHog(
        configured,
        readBrowserAnalyticsConsent(),
        isGlobalPrivacyControlEnabled(),
      ));
    };
    refresh();
    return subscribeToBrowserAnalyticsConsent(refresh);
  }, [configured]);

  // Initialise the singleton only after explicit consent and verified project
  // privacy settings. On revocation, opt out before unmounting the provider.
  useEffect(() => {
    if (!configured || !allowed || !projectToken || !projectHost) {
      if (posthog.__loaded) {
        posthog.opt_out_capturing();
        posthog.reset();
      }
      setSdkReady(false);
      setSdkError(null);
      return;
    }

    try {
      if (!posthog.__loaded) {
        posthog.init(projectToken, {
          ...POSTHOG_OPTIONS,
          api_host: projectHost,
          // Do not advertise analytics as ready until the SDK has completed
          // initialization. Consent may be revoked while initialization is pending.
          loaded: (client) => {
            const consentStillAllowsCapture = shouldMountPostHog(
              configured,
              readBrowserAnalyticsConsent(),
              isGlobalPrivacyControlEnabled(),
            );
            if (!consentStillAllowsCapture) {
              client.opt_out_capturing();
              setSdkReady(false);
              return;
            }
            client.opt_in_capturing();
            setSdkReady(true);
            setSdkError(null);
          },
        });
      } else {
        posthog.opt_in_capturing();
        setSdkReady(true);
        setSdkError(null);
      }
    } catch (error) {
      setSdkReady(false);
      setSdkError(error instanceof Error ? error.message : String(error));
    }
  }, [allowed, configured, projectHost, projectToken]);

  return (
    <AnalyticsCaptureContext.Provider value={noOpCapture}>
      {configured && allowed && sdkReady ? (
        <PostHogProvider client={posthog}>
          <PostHogCaptureProvider>{children}</PostHogCaptureProvider>
        </PostHogProvider>
      ) : children}
      <AnalyticsConsentBanner enabled={configured} />
      <AnalyticsE2EDiagnostics
        configured={configured}
        allowed={allowed}
        sdkReady={sdkReady}
        tokenConfigured={Boolean(projectToken)}
        host={projectHost}
        error={sdkError}
      />
    </AnalyticsCaptureContext.Provider>
  );
}


/** Account settings for reviewing or withdrawing optional product-analytics consent. */
export function AnalyticsConsentSettings() {
  const [consent, setConsent] = useState<"unset" | "granted" | "denied">("unset");
  const [enabled, setEnabled] = useState(false);
  const [gpc, setGpc] = useState(false);
  const [notice, setNotice] = useState("");

  useEffect(() => {
    const refresh = () => {
      const privacySignal = isGlobalPrivacyControlEnabled();
      setGpc(privacySignal);
      setConsent(readBrowserAnalyticsConsent(privacySignal));
      setEnabled(Boolean(
        import.meta.env.VITE_POSTHOG_PROJECT_TOKEN?.trim()
        && import.meta.env.VITE_POSTHOG_HOST?.trim()
        && import.meta.env.VITE_POSTHOG_PRIVACY_SETTINGS_VERIFIED === "true"
      ));
    };
    refresh();
    return subscribeToBrowserAnalyticsConsent(refresh);
  }, []);

  function choose(choice: "granted" | "denied") {
    const result = writeBrowserAnalyticsConsent(choice);
    setConsent(result.consent);
    setNotice(result.persisted
      ? choice === "granted" && !gpc
        ? "Your analytics preference has been saved."
        : "Optional analytics are disabled."
      : "Your browser could not save this preference. Analytics remain disabled.");
  }

  return (
    <section className="analytics-consent-settings hub-memberships" aria-labelledby="analytics-consent-settings-title">
      <div className="hub-section-heading"><span className="hub-kicker">PRIVACY</span><span>Optional</span></div>
      <h2 id="analytics-consent-settings-title">Analytics preferences</h2>
      <p className="form-note">
        {!enabled
          ? "Optional analytics are currently disabled by Open Play. No analytics events are sent."
          : gpc
            ? "Your browser's Global Privacy Control signal is active, so optional analytics stay disabled."
            : consent === "granted"
              ? "You have allowed optional, privacy-minimised product analytics. You can withdraw consent at any time."
              : consent === "denied"
                ? "Optional analytics are disabled. You can change your choice at any time."
                : "No choice has been saved. Optional analytics remain off until you opt in."}
      </p>
      {enabled && !gpc && (
        <div className="analytics-consent-actions">
          <button type="button" className="button" onClick={() => choose("granted")}>ALLOW OPTIONAL ANALYTICS</button>
          <button type="button" className="auth-text-button" onClick={() => choose("denied")}>DISABLE ANALYTICS</button>
        </div>
      )}
      {notice && <p className="form-note" role="status">{notice}</p>}
    </section>
  );
}
