import { useEffect, useState } from "react";
import { PostHogProvider, usePostHog } from "@posthog/react";
import { useLocation } from "@tanstack/react-router";
import {
  ANALYTICS_CONSENT_EVENT,
  isGlobalPrivacyControlEnabled,
  isAnalyticsAllowed,
  readBrowserAnalyticsConsent,
  writeBrowserAnalyticsConsent,
} from "../lib/analytics/consent";
import {
  captureOpenPlayEvent,
  type AnalyticsActor,
  type AnalyticsCaptureClient,
} from "../lib/analytics/events";
import { getSupabaseClient } from "../lib/supabase/client";

const POSTHOG_OPTIONS = {
  api_host: import.meta.env.VITE_POSTHOG_HOST,
  defaults: "2026-08-30",
  autocapture: false,
  capture_pageview: false,
  capture_pageleave: false,
  disable_session_recording: true,
  opt_out_capturing_by_default: true,
} as const;

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
    window.addEventListener(ANALYTICS_CONSENT_EVENT, syncConsent);
    window.addEventListener("storage", syncConsent);
    document.addEventListener("visibilitychange", syncConsent);
    return () => {
      window.removeEventListener(ANALYTICS_CONSENT_EVENT, syncConsent);
      window.removeEventListener("storage", syncConsent);
      document.removeEventListener("visibilitychange", syncConsent);
    };
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

function AnalyticsRouteTracker() {
  const posthog = usePostHog();
  const location = useLocation();
  const [actor, setActor] = useState<AnalyticsActor>("unknown");

  useEffect(() => {
    let alive = true;
    const supabase = getSupabaseClient();

    async function resolveActor(): Promise<AnalyticsActor> {
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
      return player?.registration_status === "registered" && !player.is_banned
        ? "player"
        : "unknown";
    }

    void resolveActor().then((resolved) => {
      if (alive) setActor(resolved);
    });

    const { data: { subscription } } = supabase.auth.onAuthStateChange(() => {
      setActor("unknown");
      void resolveActor().then((resolved) => {
        if (alive) setActor(resolved);
      });
    });

    return () => {
      alive = false;
      subscription.unsubscribe();
    };
  }, []);

  useEffect(() => {
    if (actor === "unknown") return;
    const category = routeCategory(location.pathname);
    const client: AnalyticsCaptureClient = {
      capture: (event, properties) => posthog.capture(event, properties),
    };
    captureOpenPlayEvent(
      client,
      "granted",
      isGlobalPrivacyControlEnabled(),
      actor,
      "navigation_section_viewed",
      {
        route_category: category,
        feature: routeFeature(category),
      },
    );
  }, [actor, location.pathname, posthog]);

  return null;
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
    window.addEventListener(ANALYTICS_CONSENT_EVENT, refresh);
    window.addEventListener("storage", refresh);
    document.addEventListener("visibilitychange", refresh);
    return () => {
      window.removeEventListener(ANALYTICS_CONSENT_EVENT, refresh);
      window.removeEventListener("storage", refresh);
      document.removeEventListener("visibilitychange", refresh);
    };
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

export function ConsentAwareAnalytics({ children }: { children: React.ReactNode }) {
  const [allowed, setAllowed] = useState(false);
  const projectToken = import.meta.env.VITE_POSTHOG_PROJECT_TOKEN?.trim();
  const projectHost = import.meta.env.VITE_POSTHOG_HOST?.trim();
  const configured = Boolean(projectToken && projectHost);

  useEffect(() => {
    const refresh = () => {
      setAllowed(isAnalyticsAllowed(
        readBrowserAnalyticsConsent(),
        isGlobalPrivacyControlEnabled(),
      ));
    };
    refresh();
    window.addEventListener(ANALYTICS_CONSENT_EVENT, refresh);
    window.addEventListener("storage", refresh);
    document.addEventListener("visibilitychange", refresh);
    return () => {
      window.removeEventListener(ANALYTICS_CONSENT_EVENT, refresh);
      window.removeEventListener("storage", refresh);
      document.removeEventListener("visibilitychange", refresh);
    };
  }, []);

  return (
    <>
      {configured && allowed ? (
        <PostHogProvider apiKey={projectToken!} options={{ ...POSTHOG_OPTIONS, api_host: projectHost! }}>
          <PostHogConsentInitializer />
          <AnalyticsRouteTracker />
          {children}
        </PostHogProvider>
      ) : children}
      <AnalyticsConsentBanner enabled={configured} />
    </>
  );
}
