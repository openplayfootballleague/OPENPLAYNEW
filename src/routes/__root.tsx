import {
  HeadContent,
  Outlet,
  Scripts,
  createRootRoute,
} from "@tanstack/react-router";
import { useEffect } from "react";
import type { ReactNode } from "react";
import { getSupabaseClient } from "../lib/supabase/client";
import "../styles.css";

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
  useEffect(() => {
    if (!import.meta.env.PROD || !("serviceWorker" in navigator)) return;

    void navigator.serviceWorker.register("/sw.js").catch((error: unknown) => {
      console.error("Open Play service worker registration failed.", error);
    });
  }, []);

  useEffect(() => {
    const supabase = getSupabaseClient();
    let active = true;
    let checking = false;

    async function enforceAccountStatus(userId: string | null) {
      if (!userId || checking) return;
      checking = true;
      try {
        const { data: profile, error } = await supabase
          .from("profiles")
          .select("account_retention_status")
          .eq("id", userId)
          .maybeSingle();
        if (!active || error || !profile) return;
        if (profile.account_retention_status !== "active") {
          await supabase.auth.signOut();
          if (active && window.location.pathname !== "/sign-in") {
            window.location.assign("/sign-in");
          }
        }
      } finally {
        checking = false;
      }
    }

    void supabase.auth.getSession().then(({ data: { session } }) => {
      void enforceAccountStatus(session?.user.id ?? null);
    });
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      if (session?.user.id) queueMicrotask(() => void enforceAccountStatus(session.user.id));
    });

    return () => {
      active = false;
      subscription.unsubscribe();
    };
  }, []);

  return (
    <RootDocument>
      <Outlet />
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
