import {
  HeadContent,
  Outlet,
  Scripts,
  createRootRoute,
} from "@tanstack/react-router";
import type { ReactNode } from "react";
import "../styles.css";

export const Route = createRootRoute({
  head: () => ({
    links: [{ rel: "icon", href: "/favicon.png", type: "image/png" }],
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
