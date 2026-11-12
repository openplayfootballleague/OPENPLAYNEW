import {
  HeadContent,
  Outlet,
  Scripts,
  createRootRoute,
} from "@tanstack/react-router";
import { useEffect, useState } from "react";
import type { ReactNode } from "react";
import { getSupabaseClient } from "../lib/supabase/client";
import { ConsentAwareAnalytics } from "../components/analytics-provider";
import "../styles.css";
import "../app-visual-system.css";

type AccountGateStatus = "checking" | "public" | "active" | "unavailable" | "blocked";

export const Route = createRootRoute({
  head: () => ({
    links: [
      { rel: "icon", href: "/favicon.png", type: "image/png" },
      {
        rel: "icon",
        href: "/icons/open-play-192.png",
        type: "image/png",
        sizes: "192x192",
      },
      {
        rel: "apple-touch-icon",
        href: "/apple-touch-icon.png",
        sizes: "180x180",
      },
      { rel: "manifest", href: "/manifest.webmanifest" },
    ],
    meta: [
      { charSet: "utf-8" },
      {
        name: "viewport",
        content: "width=device-width, initial-scale=1, viewport-fit=cover",
      },
      { title: "Open Play | Football, organised" },
      {
        name: "description",
        content:
          "The home of Open Play — fixtures, results, teams and league management.",
      },
      { name: "theme-color", content: "#111411" },
      { name: "mobile-web-app-capable", content: "yes" },
      { name: "apple-mobile-web-app-capable", content: "yes" },
      { name: "apple-mobile-web-app-title", content: "Open Play" },
      {
        name: "apple-mobile-web-app-status-bar-style",
        content: "black-translucent",
      },
    ],
  }),
  component: RootComponent,
});

function RootComponent() {
  const [accountGate, setAccountGate] = useState<AccountGateStatus>("checking");
  const [retryCount, setRetryCount] = useState(0);

  useEffect(() => {
    if (!import.meta.env.PROD || !("serviceWorker" in navigator)) return;

    void navigator.serviceWorker.register("/sw.js").catch((error: unknown) => {
      console.error("Open Play service worker registration failed.", error);
    });
  }, []);

  useEffect(() => {
    const supabase = getSupabaseClient();
    let active = true;
    let checkSequence = 0;
    let redirectingClosedAccount = false;

    async function enforceAccountStatus(userId: string | null) {
      const sequence = ++checkSequence;
      if (!userId) {
        setAccountGate("public");
        return;
      }

      setAccountGate("checking");
      try {
        const { data: profile, error } = await supabase
          .from("profiles")
          .select("account_retention_status")
          .eq("id", userId)
          .maybeSingle();

        if (!active || sequence !== checkSequence) return;
        if (error) {
          // Do not render private pages when the account's retention state
          // cannot be verified. The user can retry without losing their session.
          setAccountGate("unavailable");
          return;
        }

        if (!profile || profile.account_retention_status !== "active") {
          redirectingClosedAccount = true;
          setAccountGate("blocked");
          await supabase.auth.signOut();
          if (active) window.location.assign("/sign-in");
          return;
        }

        setAccountGate("active");
      } catch {
        if (active && sequence === checkSequence) {
          setAccountGate("unavailable");
        }
      }
    }

    void supabase.auth.getSession().then(({ data: { session }, error }) => {
      if (error) {
        if (active && checkSequence === 0) setAccountGate("unavailable");
        return;
      }
      void enforceAccountStatus(session?.user.id ?? null);
    }).catch(() => {
      if (active && checkSequence === 0) setAccountGate("unavailable");
    });

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, session) => {
      queueMicrotask(() => {
        if (!active || (redirectingClosedAccount && !session)) return;
        void enforceAccountStatus(session?.user.id ?? null);
      });
    });

    return () => {
      active = false;
      subscription.unsubscribe();
    };
  }, [retryCount]);

  let gateContent: ReactNode = null;
  if (accountGate === "checking") {
    gateContent = (
      <main className="notice-page player-facing">
        <section className="notice-panel auth-panel" role="status" aria-live="polite">
          <p className="eyebrow eyebrow-dark">OPEN PLAY ACCOUNT</p>
          <h1>Checking<br /><em>access.</em></h1>
          <p>Please wait while we verify your account status.</p>
        </section>
      </main>
    );
  } else if (accountGate === "unavailable") {
    gateContent = (
      <main className="notice-page player-facing">
        <section className="notice-panel auth-panel" role="alert">
          <p className="eyebrow eyebrow-dark">ACCOUNT CHECK REQUIRED</p>
          <h1>Access<br /><em>paused.</em></h1>
          <p>We could not verify your account status. Private Open Play pages are paused until the check succeeds. Your session has not been signed out.</p>
          <button className="button" type="button" onClick={() => setRetryCount((count) => count + 1)}>
            RETRY ACCOUNT CHECK
          </button>
        </section>
      </main>
    );
  } else if (accountGate === "blocked") {
    gateContent = (
      <main className="notice-page player-facing">
        <section className="notice-panel auth-panel" role="status">
          <p className="eyebrow eyebrow-dark">ACCOUNT STATUS</p>
          <h1>Sign-in<br /><em>required.</em></h1>
          <p>This account is not currently active. Sign in or request reactivation if the account was previously closed.</p>
          <a className="button" href="/sign-in">GO TO SIGN IN <span aria-hidden="true">↗</span></a>
        </section>
      </main>
    );
  }

  return (
    <RootDocument>
      <ConsentAwareAnalytics>
        {accountGate === "public" || accountGate === "active" ? <Outlet /> : gateContent}
      </ConsentAwareAnalytics>
    </RootDocument>
  );
}

function RootDocument({ children }: Readonly<{ children: ReactNode }>) {
  return (
    <html lang="en">
      <head>
        <HeadContent />
      </head>
      <body>
        {children}
        <Scripts />
      </body>
    </html>
  );
}
