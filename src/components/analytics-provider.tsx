import { createContext, useCallback, useContext, useEffect, useState } from "react";
import type { ReactNode } from "react";
import { PostHogProvider, usePostHog } from "@posthog/react";
import { useLocation } from "@tanstack/react-router";
import {
  ANALYTICS_CONSENT_EVENT,
  isGlobalPrivacyControlEnabled,
  isAnalyticsAllowed,
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

function PostHogConsentInitializer() {
  const posthog = usePostHog();

  useEffect(() => {
    const syncConsent = () => {
      const allowed = isAnalyticsAllowed(
        readBrowserAnalyticsConsent(),
        isGlobalPrivacyControlEnabled(),
      );
      if (allowed) posthog.opt_in_capturing();
      else posthog.opt_out_capturing();
    };

    syncConsent();
    return subscribeToBrowserAnalyticsConsent(syncConsent);
  }, [posthog]);

  return null;
}

function routeCategory(pathname: string) {
  if (pathname === "/") return "home";
  if (pathname === "/player" || pathname.startsWith("/player/")) return "player_hub";
  if (pathname.startsWith("/match-centre")) return "match_centre";
  if (pathname === "/teams" || pathname.startsWith("/teams/")) return "teams";
  if (pathname === "/join" || pathname === "/register-player") return "registration";
  if (pathname.startsWith("/notifications")) return "notifications";
  if (pathname.startsWith("/gallery")) return "gallery";
  if (pathname === "/account" || pathname === "/edit-profile" || pathname === "/privacy-security") return "account";
  return "other";
}

function routeFeature(category: ReturnType<typeof routeCategory>) {
  switch (category) {
    case "player_hub": return "player_hub";
    case "match_centre": return "match_centre";
    case "teams": return "team_directory";
    case "registration": return "player_registration";
    case "notifications": return "notifications";
    case "gallery": return "gallery";
    case "account": return "profile";
    default: return undefined;
  }
}

function PostHogCaptureProvider({ children }: { children: ReactNode }) {
  const posthog = usePostHog();
  const location = useLocation();
  const [actor, setActor] = useState<AnalyticsActor>("unknown");

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
        if (sessionError) return "unknown";
        if (!session) return "anonymous";

        const { data: roles, error: rolesError } = await supabase
          .from("user_roles")
          .select("role")
          .eq("user_id", session.user.id);
        if (rolesError) return "unknown";

        if ((roles ?? []).some(({ role }) =>
          ["admin", "super_admin", "finance_admin", "league_admin"].includes(role),
        )) return "admin";

        const { data: player, error: playerError } = await supabase
          .from("players")
          .select("registration_status,is_banned")
          .eq("user_id", session.user.id)
          .maybeSingle();
        if (playerError) return "unknown";
        if (player?.is_banned) return "unknown";
        return player?.registration_status === "registered" ? "player" : "account_user";
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

    const { data: { subscription } } = supabase.auth.onAuthStateChange(() => {
      setActor("unknown");
      applyResolvedActor();
    });

    return () => {
      alive = false;
      subscription.unsubscribe();
    };
  }, []);

  const capture = useCallback<AnalyticsCapture>((event, properties) => {
    const client: AnalyticsCaptureClient = {
      capture: (capturedEvent, safeProperties) => posthog.capture(capturedEvent, safeProperties),
    };
    return captureOpenPlayEvent(
      client,
      "granted",
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

export function ConsentAwareAnalytics({ children }: { children: ReactNode }) {
  const [allowed, setAllowed] = useState(false);
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

  return (
    <AnalyticsCaptureContext.Provider value={noOpCapture}>
      {configured && allowed ? (
        <PostHogProvider apiKey={projectToken!} options={{ ...POSTHOG_OPTIONS, api_host: projectHost! }}>
          <PostHogConsentInitializer />
          <PostHogCaptureProvider>{children}</PostHogCaptureProvider>
        </PostHogProvider>
      ) : children}
      <AnalyticsConsentBanner enabled={configured} />
    </AnalyticsCaptureContext.Provider>
  );
}
