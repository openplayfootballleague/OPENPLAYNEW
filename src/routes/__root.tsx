import {
  HeadContent,
  Outlet,
  Scripts,
  createRootRoute,
} from "@tanstack/react-router";
import { PostHogProvider, usePostHog } from "posthog-js/react";
import { useEffect, useRef, type ReactNode } from "react";
import {
  getSupabaseClient,
  isSupabaseConfigured,
} from "../lib/supabase/client";
import "../styles.css";

const posthogKey = import.meta.env.VITE_PUBLIC_POSTHOG_KEY;
const posthogHost = import.meta.env.VITE_PUBLIC_POSTHOG_HOST;

export const Route = createRootRoute({
  head: () => ({
    links: [{ rel: "icon", href: "/favicon.svg", type: "image/svg+xml" }],
    meta: [
      { charSet: "utf-8" },
      { name: "viewport", content: "width=device-width, initial-scale=1" },
      {
        title: "Open Play | Football, organised",
      },
      {
        name: "description",
        content:
          "The home of Open Play — fixtures, results, teams and league management.",
      },
      { name: "theme-color", content: "#111411" },
    ],
  }),
  component: RootComponent,
});

function RootComponent() {
  const missingPostHogVariable = !posthogKey
    ? "VITE_PUBLIC_POSTHOG_KEY"
    : !posthogHost
      ? "VITE_PUBLIC_POSTHOG_HOST"
      : null;

  if (missingPostHogVariable) {
    if (!import.meta.env.SSR && import.meta.env.DEV) {
      throw new Error(
        `${missingPostHogVariable} variable required by PostHog is missing or un-configured, this causes events to be silently missed. This error stops appearing once ${missingPostHogVariable} is configured`,
      );
    }

    return (
      <RootDocument>
        <Outlet />
      </RootDocument>
    );
  }

  return (
    <RootDocument>
      <PostHogProvider
        apiKey={posthogKey}
        options={{
          api_host: posthogHost,
          defaults: "2025-05-24",
          capture_exceptions: true,
          debug: import.meta.env.DEV,
          logs: {
            serviceName: "open-play-web",
            environment: import.meta.env.MODE,
          },
        }}
      >
        <PostHogAuthIdentification />
        <Outlet />
      </PostHogProvider>
    </RootDocument>
  );
}

function PostHogAuthIdentification() {
  const posthog = usePostHog();
  const identifiedUserId = useRef<string | null>(null);

  useEffect(() => {
    if (!isSupabaseConfigured()) return;

    const supabase = getSupabaseClient();

    const identifyUser = (user: { id: string; email?: string } | null) => {
      if (!user || identifiedUserId.current === user.id) return;

      if (identifiedUserId.current) posthog.reset();

      posthog.identify(
        user.id,
        user.email ? { email: user.email } : undefined,
      );
      identifiedUserId.current = user.id;
    };

    void supabase.auth.getSession().then(({ data }) => {
      identifyUser(data.session?.user ?? null);
    });

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((event, session) => {
      if (event === "SIGNED_OUT") {
        posthog.reset();
        identifiedUserId.current = null;
        return;
      }

      identifyUser(session?.user ?? null);
    });

    return () => subscription.unsubscribe();
  }, [posthog]);

  return null;
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
