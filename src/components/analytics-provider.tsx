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
  if (pathname.startsWith("/gallery")) return "gallery";
  if (pathname.startsWith("/account") || pathname.startsWith("/profile") || pathname.startsWith("/settings")) return "account";
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

    async function resolveActor(): Promise<AnalyticsActor> {
      return resolveAnalyticsActorSafely(true, async () => {
        const { data: { session }, error: sessionError } = await supabase.auth.getSession();
        if (sessionError) {
          setUserId(null);
          return "unknown";
        }
        if (!session) {
          setUserId(null);
          return "anonymous";
        }

        const { data: profile, error: profileError } = await supabase
          .from("profiles")
          .select("account_retention_status")
          .eq("id", session.user.id)
          .maybeSingle();
        if (profileError || !profile || profile.account_retention_status !== "active") {
          setUserId(null);
          return "unknown";
        }

        const { data: roles, error: rolesError } = await supabase
          .from("user_roles")
          .select("role")
          .eq("user_id", session.user.id);
        if (rolesError) {
          setUserId(null);
          return "unknown";
        }

        const privilegedRole = (roles ?? []).map(({ role }) => role).find((role) =>
          ["super_admin", "admin", "finance_admin", "league_admin"].includes(role),
        );
        if (privilegedRole) {
          setUserId(null);
          return privilegedRole as AnalyticsActor;
        }

        const { data: player, error: playerError } = await supabase
          .from("players")
          .select("registration_status,is_banned,disciplinary_inactive")
          .eq("user_id", session.user.id)
          .maybeSingle();
        if (playerError || player?.is_banned || player?.disciplinary_inactive) {
          setUserId(null);
          return "unknown";
        }

        if (player?.registration_status !== "registered") {
          setUserId(session.user.id);
          return "account_user";
        }

        const { data: captainMemberships, error: captainError } = await supabase
          .from("team_memberships")
          .select("id")
          .eq("user_id", session.user.id)
          .eq("status", "active")
          .eq("is_captain", true)
          .limit(1);
        if (captainError) {
          setUserId(null);
          return "unknown";
        }

        setUserId(session.user.id);
        return (captainMemberships ?? []).length > 0 ? "captain" : "player";
      });
    }

    const applyResolvedActor = () => {
      void resolveActor()
        .then((resolved) => {
          if (alive) setActor(resolved);
        })
        .catch(() => {
          if (alive) setActor("unknown");
        });
    };

    applyResolvedActor();

    const { data: { subscription } } = supabase.auth.onAuthStateChange((event) => {
      if (event === "SIGNED_IN" || event === "SIGNED_OUT") setUserId(null);
      setActor("unknown");
      applyResolvedActor();
    });

    return () => {
      alive = false;
      subscription.unsubscribe();
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
      actor,
      event,
      properties,
    );
  }, [actor, posthog]);

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
